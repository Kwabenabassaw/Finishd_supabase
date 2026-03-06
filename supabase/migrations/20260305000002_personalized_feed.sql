-- ============================================================================
-- Phase 2: Personalized Feed Pipeline
-- Creates get_personalized_feed RPC with candidate generation + ranking
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_personalized_feed(
  p_session_id UUID DEFAULT NULL,
  p_limit INT DEFAULT 15,
  p_user_id UUID DEFAULT NULL,
  p_cold_start BOOLEAN DEFAULT FALSE
) RETURNS TABLE (
  id UUID,
  creator_id UUID,
  video_url TEXT,
  thumbnail_url TEXT,
  title TEXT,
  description TEXT,
  view_count INT,
  like_count INT,
  comment_count INT,
  share_count INT,
  engagement_score DOUBLE PRECISION,
  created_at TIMESTAMPTZ,
  creator_username TEXT,
  creator_avatar_url TEXT,
  tmdb_id INT,
  tmdb_type TEXT,
  tmdb_title TEXT,
  duration_seconds INT,
  spoiler BOOLEAN,
  tags TEXT[],
  feed_source TEXT
) AS $$
DECLARE
  v_seen_ids UUID[] := '{}';
  v_resolved_user_id UUID := p_user_id;
BEGIN
  -- Load seen video IDs from session and resolve user_id
  IF p_session_id IS NOT NULL THEN
    SELECT COALESCE(fs.seen_video_ids, '{}'), fs.user_id 
    INTO v_seen_ids, v_resolved_user_id
    FROM public.feed_sessions fs 
    WHERE fs.id = p_session_id;

    -- If explicitly passed user_id, favor that, else use session user_id
    v_resolved_user_id := COALESCE(p_user_id, v_resolved_user_id);
  END IF;

  RETURN QUERY
  WITH candidates AS (
    -- 1. Personalized (from user's liked/watched titles)
    (SELECT v.*, 'personalized'::TEXT as source, 1.0::DOUBLE PRECISION as interest_score
    FROM public.creator_videos v
    JOIN public.user_titles ut ON v.tmdb_id::text = ut.title_id
    WHERE v_resolved_user_id IS NOT NULL 
      AND p_cold_start = FALSE
      AND ut.user_id = v_resolved_user_id 
      AND ut.status IN ('watching', 'planning', 'completed')
      AND v.status = 'approved' AND v.deleted_at IS NULL
      AND NOT (v.id = ANY(v_seen_ids))
    ORDER BY v.created_at DESC
    LIMIT 100)

    UNION ALL

    -- 2. Social (videos liked by friends)
    (SELECT v.*, 'social'::TEXT as source, 0.8::DOUBLE PRECISION as interest_score
    FROM public.creator_videos v
    JOIN public.video_interactions vi ON v.id = vi.video_id
    JOIN public.follows f ON vi.user_id = f.following_id
    WHERE v_resolved_user_id IS NOT NULL
      AND p_cold_start = FALSE
      AND f.follower_id = v_resolved_user_id
      AND vi.liked = TRUE
      AND v.status = 'approved' AND v.deleted_at IS NULL
      AND NOT (v.id = ANY(v_seen_ids))
    ORDER BY v.created_at DESC
    LIMIT 50)

    UNION ALL

    -- 3. Trending
    (SELECT v.*, 'trending'::TEXT as source, 0.5::DOUBLE PRECISION as interest_score
    FROM public.creator_videos v
    WHERE v.status = 'approved' AND v.deleted_at IS NULL
      AND NOT (v.id = ANY(v_seen_ids))
    ORDER BY v.engagement_score DESC
    LIMIT 100)

    UNION ALL

    -- 4. Explore (Recent global)
    (SELECT v.*, 'explore'::TEXT as source, 0.2::DOUBLE PRECISION as interest_score
    FROM public.creator_videos v
    WHERE v.status = 'approved' AND v.deleted_at IS NULL
      AND NOT (v.id = ANY(v_seen_ids))
    ORDER BY v.created_at DESC
    LIMIT 50)
  ),
  ranked_candidates AS (
    SELECT c.*,
      row_number() OVER (PARTITION BY c.id ORDER BY c.interest_score DESC) as dedup_priority,
      (COALESCE(c.engagement_score, 0) * 0.45 + 
       c.interest_score * 0.35 + 
       -- Recency score: 1.0 for now, decreasing as hours go by
       (1.0 / (EXTRACT(EPOCH FROM (now() - c.created_at))/3600.0 + 1.0)) * 0.20
      ) * (0.9 + random() * 0.2) as final_score
    FROM candidates c
  ),
  deduplicated AS (
    SELECT * FROM ranked_candidates WHERE dedup_priority = 1
  ),
  filtered_creators AS (
    SELECT d.*,
           row_number() OVER (PARTITION BY d.creator_id ORDER BY d.final_score DESC) as creator_rank
    FROM deduplicated d
  )
  SELECT 
    f.id,
    f.creator_id,
    f.video_url,
    COALESCE(f.thumbnail_url, ''),
    COALESCE(f.title, ''),
    COALESCE(f.description, ''),
    COALESCE(f.view_count, 0),
    COALESCE(f.like_count, 0),
    COALESCE(f.comment_count, 0),
    COALESCE(f.share_count, 0),
    COALESCE(f.engagement_score, 0.0::DOUBLE PRECISION),
    f.created_at,
    COALESCE(p.username, 'Unknown Creator'),
    COALESCE(p.avatar_url, ''),
    f.tmdb_id,
    f.tmdb_type,
    f.tmdb_title,
    COALESCE(f.duration_seconds, 0),
    COALESCE(f.spoiler, false),
    COALESCE(f.tags, '{}'),
    f.source
  FROM filtered_creators f
  LEFT JOIN public.profiles p ON p.id = f.creator_id
  WHERE f.creator_rank <= 10 -- Anti-spam limit relaxed (was 2) for testing/early stage with few creators
  ORDER BY f.final_score DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;
