// Admin View Reports Edge Function
// Endpoints for viewing and managing video reports
//
// GET /admin-view-reports?status=pending&limit=50
// Returns list of reports for moderation
//
// POST /admin-view-reports
// Body: { reportId: string, action: 'dismiss' | 'resolve', notes?: string }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ReportAction {
    reportId: string
    action: 'dismiss' | 'resolve'
    notes?: string
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Create Supabase client with Auth context
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            {
                global: {
                    headers: { Authorization: req.headers.get('Authorization')! },
                },
            }
        )

        // Get current user
        const { data: { user }, error: authError } = await supabaseClient.auth.getUser()
        if (authError || !user) {
            return new Response(
                JSON.stringify({ error: 'Unauthorized' }),
                { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Check if user is admin/reviewer
        const { data: profile, error: profileError } = await supabaseClient
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .single()

        if (profileError || !profile || !['admin', 'reviewer'].includes(profile.role)) {
            return new Response(
                JSON.stringify({ error: 'Forbidden: Admin or reviewer role required' }),
                { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Use service role for queries
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // Handle GET - list reports
        if (req.method === 'GET') {
            const url = new URL(req.url)
            const status = url.searchParams.get('status') || 'pending'
            const limit = parseInt(url.searchParams.get('limit') || '50')

            const { data: reports, error: reportsError } = await supabaseAdmin
                .from('creator_video_reports')
                .select(`
          id,
          video_id,
          reporter_id,
          reason,
          details,
          status,
          created_at,
          creator_videos!video_id (
            id,
            title,
            thumbnail_url,
            creator_id,
            status
          ),
          profiles!reporter_id (
            username
          )
        `)
                .eq('status', status)
                .order('created_at', { ascending: true })
                .limit(limit)

            if (reportsError) {
                throw reportsError
            }

            return new Response(
                JSON.stringify({ reports }),
                { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Handle POST - update report status
        if (req.method === 'POST') {
            const { reportId, action, notes }: ReportAction = await req.json()

            if (!reportId || !['dismiss', 'resolve'].includes(action)) {
                return new Response(
                    JSON.stringify({ error: 'Invalid request: reportId and action (dismiss/resolve) required' }),
                    { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
            }

            const newStatus = action === 'dismiss' ? 'dismissed' : 'resolved'
            const now = new Date().toISOString()

            const { error: updateError } = await supabaseAdmin
                .from('creator_video_reports')
                .update({
                    status: newStatus,
                    reviewed_by: user.id,
                    review_notes: notes,
                    reviewed_at: now
                })
                .eq('id', reportId)

            if (updateError) {
                throw updateError
            }

            return new Response(
                JSON.stringify({
                    success: true,
                    message: `Report ${action}ed`,
                    reportId,
                    newStatus
                }),
                { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        return new Response(
            JSON.stringify({ error: 'Method not allowed' }),
            { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        console.error('Error:', error)
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
