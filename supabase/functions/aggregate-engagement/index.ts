// Engagement Aggregation Edge Function
// Aggregates engagement events into creator_videos counters
//
// Called after engagement events are inserted (via database trigger or client)
// POST /aggregate-engagement
// Body: { videoId: string }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface AggregateRequest {
    videoId: string
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Use service role for aggregation (bypasses RLS)
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        const { videoId }: AggregateRequest = await req.json()

        if (!videoId) {
            return new Response(
                JSON.stringify({ error: 'videoId required' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Get video to check it exists
        const { data: video, error: videoError } = await supabaseAdmin
            .from('creator_videos')
            .select('id, duration_seconds')
            .eq('id', videoId)
            .single()

        if (videoError || !video) {
            return new Response(
                JSON.stringify({ error: 'Video not found' }),
                { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Aggregate engagement events from last 7 days
        const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()

        const { data: events, error: eventsError } = await supabaseAdmin
            .from('video_engagement_events')
            .select('watch_duration_seconds, completion_pct')
            .eq('video_id', videoId)
            .gte('created_at', sevenDaysAgo)

        if (eventsError) {
            throw eventsError
        }

        // Calculate aggregates
        const viewCount = events?.length ?? 0
        const totalWatchTime = events?.reduce((sum, e) => sum + e.watch_duration_seconds, 0) ?? 0
        const avgCompletion = viewCount > 0
            ? events!.reduce((sum, e) => sum + e.completion_pct, 0) / viewCount
            : 0

        // Calculate engagement score
        // Formula: (avg_completion * 0.6) + (recency_factor * 0.2) + (view_count_factor * 0.2)
        const completionScore = avgCompletion * 0.6
        const viewScore = Math.min(viewCount / 1000, 1) * 0.2 // Cap at 1000 views

        // Recency: video created recently gets boost
        const { data: videoCreated } = await supabaseAdmin
            .from('creator_videos')
            .select('created_at')
            .eq('id', videoId)
            .single()

        let recencyScore = 0
        if (videoCreated) {
            const ageHours = (Date.now() - new Date(videoCreated.created_at).getTime()) / (1000 * 60 * 60)
            recencyScore = Math.max(0, 1 - (ageHours / 168)) * 0.2 // Decay over 7 days (168 hours)
        }

        const engagementScore = completionScore + viewScore + recencyScore

        // Update video with aggregated stats
        const { error: updateError } = await supabaseAdmin
            .from('creator_videos')
            .update({
                view_count: viewCount,
                total_watch_time_seconds: totalWatchTime,
                avg_completion_pct: avgCompletion,
                engagement_score: engagementScore,
                updated_at: new Date().toISOString()
            })
            .eq('id', videoId)

        if (updateError) {
            throw updateError
        }

        return new Response(
            JSON.stringify({
                success: true,
                videoId,
                stats: {
                    viewCount,
                    totalWatchTime,
                    avgCompletion: avgCompletion.toFixed(2),
                    engagementScore: engagementScore.toFixed(3)
                }
            }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        console.error('Error:', error)
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
