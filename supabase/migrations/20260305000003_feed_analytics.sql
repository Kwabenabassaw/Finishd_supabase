-- ============================================================================
-- Phase 3: Feed Analytics 
-- Adds: get_user_feed_analytics RPC for creator dashboards/stats
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_feed_analytics(
  p_user_id UUID DEFAULT NULL
) RETURNS TABLE (
  total_videos_watched INT,
  total_watch_time_seconds INT,
  average_completion_rate NUMERIC,
  videos_skipped INT,
  videos_liked INT,
  videos_shared INT,
  top_genres TEXT[]
) AS $$
DECLARE
  v_uid UUID := COALESCE(p_user_id, auth.uid());
BEGIN
  RETURN QUERY
  WITH user_stats AS (
    SELECT
      count(*) as total_watched,
      sum(watch_time_ms) / 1000 as total_time_sec,
      avg(CASE WHEN duration_ms > 0 THEN least((watch_time_ms::numeric / duration_ms::numeric), 1.0) ELSE 0 END) as avg_completion,
      count(*) FILTER (WHERE skipped = TRUE) as total_skipped,
      count(*) FILTER (WHERE liked = TRUE) as total_liked,
      count(*) FILTER (WHERE shared = TRUE) as total_shared
    FROM public.video_interactions
    WHERE user_id = v_uid
  ),
  -- Determine favorite genres based on user_titles
  user_genres AS (
    SELECT unnest(string_to_array(genre, ',')) as g
    FROM public.user_titles
    WHERE user_id = v_uid AND genre IS NOT NULL
  ),
  ranked_genres AS (
    SELECT trim(g) as genre_name, count(*) as count
    FROM user_genres
    GROUP BY genre_name
    ORDER BY count DESC
    LIMIT 3
  )
  SELECT 
    us.total_watched::INT,
    COALESCE(us.total_time_sec::INT, 0),
    COALESCE(us.avg_completion, 0.0),
    us.total_skipped::INT,
    us.total_liked::INT,
    us.total_shared::INT,
    COALESCE((SELECT array_agg(genre_name) FROM ranked_genres), '{}'::TEXT[])
  FROM user_stats us;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
