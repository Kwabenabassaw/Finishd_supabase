// Feed Ranking Job Edge Function
// Scheduled job to compute feed rankings hourly
//
// Called by Supabase cron or external scheduler
// POST /compute-feed-rankings (no body required)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const MAX_RANKINGS = 500 // Top 500 videos per category

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Use service role for ranking computation
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        console.log('[Feed Ranking] Starting ranking computation...')

        // 1. First, aggregate engagement for all videos with recent activity
        const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()

        // Get videos with recent engagement
        const { data: videosWithEvents, error: eventsQueryError } = await supabaseAdmin
            .from('video_engagement_events')
            .select('video_id')
            .gte('created_at', sevenDaysAgo)

        if (eventsQueryError) {
            console.error('Error fetching engagement:', eventsQueryError)
        }

        // Aggregate each video (deduplicate video IDs)
        const uniqueVideoIds = [...new Set(videosWithEvents?.map(v => v.video_id) ?? [])]
        console.log(`[Feed Ranking] Aggregating ${uniqueVideoIds.length} videos with recent engagement`)

        for (const videoId of uniqueVideoIds) {
            try {
                // Aggregate events for this video
                const { data: events } = await supabaseAdmin
                    .from('video_engagement_events')
                    .select('watch_duration_seconds, completion_pct')
                    .eq('video_id', videoId)
                    .gte('created_at', sevenDaysAgo)

                if (events && events.length > 0) {
                    const viewCount = events.length
                    const totalWatchTime = events.reduce((sum, e) => sum + e.watch_duration_seconds, 0)
                    const avgCompletion = events.reduce((sum, e) => sum + e.completion_pct, 0) / viewCount

                    // Get video creation time for recency
                    const { data: videoData } = await supabaseAdmin
                        .from('creator_videos')
                        .select('created_at')
                        .eq('id', videoId)
                        .single()

                    // Calculate engagement score
                    const completionScore = avgCompletion * 0.6
                    const viewScore = Math.min(viewCount / 1000, 1) * 0.2

                    let recencyScore = 0
                    if (videoData) {
                        const ageHours = (Date.now() - new Date(videoData.created_at).getTime()) / (1000 * 60 * 60)
                        recencyScore = Math.max(0, 1 - (ageHours / 168)) * 0.2
                    }

                    const engagementScore = completionScore + viewScore + recencyScore

                    await supabaseAdmin
                        .from('creator_videos')
                        .update({
                            view_count: viewCount,
                            total_watch_time_seconds: totalWatchTime,
                            avg_completion_pct: avgCompletion,
                            engagement_score: engagementScore,
                            updated_at: new Date().toISOString()
                        })
                        .eq('id', videoId)
                }
            } catch (e) {
                console.error(`Error aggregating video ${videoId}:`, e)
            }
        }

        // 2. Compute "for_you" rankings (global, by engagement score)
        console.log('[Feed Ranking] Computing for_you rankings...')

        const { data: topVideos, error: topVideosError } = await supabaseAdmin
            .from('creator_videos')
            .select('id, engagement_score')
            .eq('status', 'approved')
            .order('engagement_score', { ascending: false })
            .limit(MAX_RANKINGS)

        if (topVideosError) {
            throw topVideosError
        }

        // Clear existing for_you rankings
        await supabaseAdmin
            .from('feed_rankings')
            .delete()
            .eq('category', 'for_you')

        // Insert new rankings
        const forYouRankings = topVideos?.map((video, index) => ({
            video_id: video.id,
            category: 'for_you',
            rank_position: index + 1,
            computed_at: new Date().toISOString()
        })) ?? []

        if (forYouRankings.length > 0) {
            const { error: insertError } = await supabaseAdmin
                .from('feed_rankings')
                .insert(forYouRankings)

            if (insertError) {
                throw insertError
            }
        }

        // 3. Compute "trending" rankings (recent + high engagement)
        console.log('[Feed Ranking] Computing trending rankings...')

        const threeDaysAgo = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString()

        const { data: trendingVideos, error: trendingError } = await supabaseAdmin
            .from('creator_videos')
            .select('id, engagement_score')
            .eq('status', 'approved')
            .gte('created_at', threeDaysAgo)
            .order('engagement_score', { ascending: false })
            .limit(MAX_RANKINGS)

        if (trendingError) {
            throw trendingError
        }

        // Clear existing trending rankings
        await supabaseAdmin
            .from('feed_rankings')
            .delete()
            .eq('category', 'trending')

        // Insert new rankings
        const trendingRankings = trendingVideos?.map((video, index) => ({
            video_id: video.id,
            category: 'trending',
            rank_position: index + 1,
            computed_at: new Date().toISOString()
        })) ?? []

        if (trendingRankings.length > 0) {
            const { error: insertError } = await supabaseAdmin
                .from('feed_rankings')
                .insert(trendingRankings)

            if (insertError) {
                throw insertError
            }
        }

        // 4. Purge old engagement events (older than 7 days)
        console.log('[Feed Ranking] Purging old engagement events...')

        const { error: purgeError } = await supabaseAdmin
            .from('video_engagement_events')
            .delete()
            .lt('created_at', sevenDaysAgo)

        if (purgeError) {
            console.error('Error purging old events:', purgeError)
        }

        console.log('[Feed Ranking] Completed successfully')

        return new Response(
            JSON.stringify({
                success: true,
                message: 'Feed rankings computed',
                stats: {
                    videosAggregated: uniqueVideoIds.length,
                    forYouRankings: forYouRankings.length,
                    trendingRankings: trendingRankings.length
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
