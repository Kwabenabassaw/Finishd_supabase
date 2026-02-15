// Admin Video Moderation Edge Function
// Endpoints for moderating creator videos
//
// POST /admin-moderate-video
// Body: { action: 'approve' | 'reject' | 'remove', videoId: string, reason?: string }
// 
// GET /admin-moderate-video?status=pending&limit=50
// Returns list of videos for moderation

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ModerationAction {
    action: 'approve' | 'reject' | 'remove'
    videoId: string
    reason?: string
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

        // Use service role for updates
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // Handle GET - list videos for moderation
        if (req.method === 'GET') {
            const url = new URL(req.url)
            const status = url.searchParams.get('status') || 'pending'
            const limit = parseInt(url.searchParams.get('limit') || '50')

            const { data: videos, error: videosError } = await supabaseAdmin
                .from('creator_videos')
                .select(`
          id,
          creator_id,
          video_url,
          thumbnail_url,
          duration_seconds,
          title,
          description,
          tmdb_id,
          tmdb_title,
          status,
          created_at,
          profiles!creator_id (
            username,
            avatar_url
          )
        `)
                .eq('status', status)
                .order('created_at', { ascending: true })
                .limit(limit)

            if (videosError) {
                throw videosError
            }

            // Get report counts for each video
            const videoIds = videos?.map(v => v.id) ?? []
            const { data: reportCounts } = await supabaseAdmin
                .from('creator_video_reports')
                .select('video_id')
                .in('video_id', videoIds)
                .eq('status', 'pending')

            const reportCountMap = new Map<string, number>()
            reportCounts?.forEach(r => {
                const count = reportCountMap.get(r.video_id) || 0
                reportCountMap.set(r.video_id, count + 1)
            })

            const enrichedVideos = videos?.map(v => ({
                ...v,
                pending_reports: reportCountMap.get(v.id) || 0
            }))

            return new Response(
                JSON.stringify({ videos: enrichedVideos }),
                { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Handle POST - moderate a video
        if (req.method === 'POST') {
            const { action, videoId, reason }: ModerationAction = await req.json()

            if (!videoId || !['approve', 'reject', 'remove'].includes(action)) {
                return new Response(
                    JSON.stringify({ error: 'Invalid request: videoId and action (approve/reject/remove) required' }),
                    { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
            }

            // Get current video status
            const { data: video, error: videoError } = await supabaseAdmin
                .from('creator_videos')
                .select('status, creator_id')
                .eq('id', videoId)
                .single()

            if (videoError || !video) {
                return new Response(
                    JSON.stringify({ error: 'Video not found' }),
                    { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
            }

            // Validate state transitions
            const validTransitions: Record<string, string[]> = {
                'pending': ['approved', 'rejected'],
                'approved': ['removed'],
                'rejected': ['approved'], // Allow re-review
                'removed': [] // Terminal state
            }

            const newStatus = action === 'approve' ? 'approved' : action === 'reject' ? 'rejected' : 'removed'

            if (!validTransitions[video.status]?.includes(newStatus)) {
                return new Response(
                    JSON.stringify({ error: `Cannot ${action} a video with status '${video.status}'` }),
                    { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
            }

            const now = new Date().toISOString()

            // Update video status
            const { error: updateError } = await supabaseAdmin
                .from('creator_videos')
                .update({
                    status: newStatus,
                    reviewed_by: user.id,
                    reviewed_at: now,
                    rejection_reason: action === 'reject' || action === 'remove' ? reason : null
                })
                .eq('id', videoId)

            if (updateError) {
                throw updateError
            }

            // If video was removed due to reports, mark reports as resolved
            if (action === 'remove') {
                await supabaseAdmin
                    .from('creator_video_reports')
                    .update({
                        status: 'resolved',
                        reviewed_by: user.id,
                        reviewed_at: now
                    })
                    .eq('video_id', videoId)
                    .eq('status', 'pending')
            }

            return new Response(
                JSON.stringify({
                    success: true,
                    message: `Video ${action}d successfully`,
                    videoId,
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
