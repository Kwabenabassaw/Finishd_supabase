// Creator Application Review Edge Function
// Approves or rejects creator applications
// 
// POST /creator-application-review
// Body: { applicationId: string, action: 'approve' | 'reject', reviewNotes?: string }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ReviewRequest {
    applicationId: string
    action: 'approve' | 'reject'
    reviewNotes?: string
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

        // Parse request body
        const { applicationId, action, reviewNotes }: ReviewRequest = await req.json()

        if (!applicationId || !['approve', 'reject'].includes(action)) {
            return new Response(
                JSON.stringify({ error: 'Invalid request: applicationId and action (approve/reject) required' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Fetch application
        const { data: application, error: appError } = await supabaseClient
            .from('creator_applications')
            .select('*')
            .eq('id', applicationId)
            .single()

        if (appError || !application) {
            return new Response(
                JSON.stringify({ error: 'Application not found' }),
                { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        if (application.status !== 'pending') {
            return new Response(
                JSON.stringify({ error: 'Application already reviewed' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const now = new Date().toISOString()

        // Use service role for updates that bypass RLS
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        if (action === 'approve') {
            // 1. Update application status
            const { error: updateAppError } = await supabaseAdmin
                .from('creator_applications')
                .update({
                    status: 'approved',
                    reviewed_by: user.id,
                    review_notes: reviewNotes,
                    reviewed_at: now
                })
                .eq('id', applicationId)

            if (updateAppError) {
                throw updateAppError
            }

            // 2. Update user profile to creator
            const { error: updateProfileError } = await supabaseAdmin
                .from('profiles')
                .update({
                    role: 'creator',
                    creator_status: 'approved',
                    creator_verified_at: now
                })
                .eq('id', application.user_id)

            if (updateProfileError) {
                throw updateProfileError
            }

            return new Response(
                JSON.stringify({
                    success: true,
                    message: 'Creator application approved',
                    userId: application.user_id
                }),
                { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )

        } else {
            // Reject application
            const { error: updateAppError } = await supabaseAdmin
                .from('creator_applications')
                .update({
                    status: 'rejected',
                    reviewed_by: user.id,
                    review_notes: reviewNotes,
                    reviewed_at: now
                })
                .eq('id', applicationId)

            if (updateAppError) {
                throw updateAppError
            }

            // Update profile status (optional - shows rejection in profile)
            const { error: updateProfileError } = await supabaseAdmin
                .from('profiles')
                .update({
                    creator_status: 'rejected'
                })
                .eq('id', application.user_id)

            if (updateProfileError) {
                throw updateProfileError
            }

            return new Response(
                JSON.stringify({
                    success: true,
                    message: 'Creator application rejected',
                    userId: application.user_id
                }),
                { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

    } catch (error) {
        console.error('Error:', error)
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
