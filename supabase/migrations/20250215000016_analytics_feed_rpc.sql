-- ============================================================================
-- V3.1 Migration 16: Creator Analytics + Retention + Optimized Feed Queries
-- ============================================================================

-- ── Creator Daily Stats ─────────────────────────────────────────────────────
-- Aggregated daily metrics for creator analytics dashboard.
-- Populated by compute_feed_rankings() or a dedicated cron job.

CREATE TABLE public.creator_daily_stats (
  creator_id          UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  date                DATE NOT NULL,
  new_followers       INT DEFAULT 0,
  total_views         INT DEFAULT 0,
  total_watch_time    BIGINT DEFAULT 0,       -- seconds
  total_likes         INT DEFAULT 0,
  total_comments      INT DEFAULT 0,
  total_shares        INT DEFAULT 0,
  videos_uploaded     INT DEFAULT 0,
  avg_completion_rate NUMERIC(5,4) DEFAULT 0,
  estimated_cpm       NUMERIC(10,4) DEFAULT 0,    -- future monetization
  PRIMARY KEY (creator_id, date)
);

CREATE INDEX idx_cds_date ON public.creator_daily_stats(date);

ALTER TABLE public.creator_daily_stats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Creators view own daily stats" ON public.creator_daily_stats
  FOR SELECT USING (auth.uid() = creator_id);
CREATE POLICY "Admins view all daily stats" ON public.creator_daily_stats
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ── Video Retention Buckets ─────────────────────────────────────────────────
-- Heatmap showing where viewers drop off.
-- Updated by aggregation job from video_engagement_events.

CREATE TABLE public.video_retention_buckets (
  video_id         UUID NOT NULL REFERENCES public.creator_videos(id) ON DELETE CASCADE,
  bucket_pct       INT NOT NULL CHECK (bucket_pct IN (10, 20, 30, 40, 50, 60, 70, 80, 90, 100)),
  viewer_count     INT DEFAULT 0,
  avg_rewatch      NUMERIC(5,2) DEFAULT 1.0,
  PRIMARY KEY (video_id, bucket_pct)
);

ALTER TABLE public.video_retention_buckets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Creators view own retention" ON public.video_retention_buckets
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.creator_videos WHERE id = video_id AND creator_id = auth.uid())
  );
CREATE POLICY "Admins view all retention" ON public.video_retention_buckets
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ── Compute Creator Daily Stats ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.compute_creator_daily_stats(p_date DATE DEFAULT CURRENT_DATE)
RETURNS INT AS $$
DECLARE
  v_count INT := 0;
BEGIN
  INSERT INTO public.creator_daily_stats (
    creator_id, date, total_views, total_watch_time,
    total_likes, total_comments, videos_uploaded, avg_completion_rate
  )
  SELECT
    cv.creator_id,
    p_date,
    COALESCE(SUM(vds.total_views), 0)::int,
    COALESCE(SUM(vds.total_watch_time), 0),
    SUM(cv.like_count)::int,
    SUM(cv.comment_count)::int,
    COUNT(*) FILTER (WHERE cv.created_at::date = p_date)::int,
    COALESCE(AVG(cv.avg_completion_pct) FILTER (WHERE cv.view_count > 0), 0)
  FROM public.creator_videos cv
  LEFT JOIN public.video_daily_stats vds
    ON vds.video_id = cv.id AND vds.date = p_date
  WHERE cv.deleted_at IS NULL AND cv.status = 'approved'
  GROUP BY cv.creator_id
  ON CONFLICT (creator_id, date) DO UPDATE SET
    total_views         = EXCLUDED.total_views,
    total_watch_time    = EXCLUDED.total_watch_time,
    total_likes         = EXCLUDED.total_likes,
    total_comments      = EXCLUDED.total_comments,
    videos_uploaded     = EXCLUDED.videos_uploaded,
    avg_completion_rate = EXCLUDED.avg_completion_rate;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Optimized Feed RPC ──────────────────────────────────────────────────────
-- Single-call feed hydration with cursor pagination.
-- Returns fully joined feed data — no N+1 queries.

CREATE OR REPLACE FUNCTION public.get_ranked_feed(
  p_category    TEXT DEFAULT 'for_you',
  p_cursor      INT DEFAULT 0,          -- last seen rank_position
  p_limit       INT DEFAULT 20,
  p_user_id     UUID DEFAULT NULL       -- for "following" filter
)
RETURNS TABLE (
  video_id         UUID,
  rank_position    INT,
  title            TEXT,
  description      TEXT,
  video_url        TEXT,
  thumbnail_url    TEXT,
  tags             TEXT[],
  tmdb_id          INT,
  tmdb_type        TEXT,
  tmdb_title       TEXT,
  spoiler          BOOLEAN,
  duration_seconds INT,
  like_count       INT,
  comment_count    INT,
  view_count       INT,
  share_count      INT,
  engagement_score NUMERIC,
  creator_id       UUID,
  creator_username TEXT,
  creator_avatar   TEXT,
  alt_title        TEXT,
  alt_thumbnail    TEXT,
  created_at       TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    cv.id AS video_id,
    fr.rank_position,
    cv.title,
    cv.description,
    cv.video_url,
    cv.thumbnail_url,
    cv.tags,
    cv.tmdb_id,
    cv.tmdb_type,
    cv.tmdb_title,
    cv.spoiler,
    cv.duration_seconds,
    cv.like_count,
    cv.comment_count,
    cv.view_count,
    cv.share_count,
    cv.engagement_score,
    cv.creator_id,
    p.username AS creator_username,
    p.avatar_url AS creator_avatar,
    cv.alt_title,
    cv.alt_thumbnail_url AS alt_thumbnail,
    cv.created_at
  FROM public.feed_rankings fr
  JOIN public.creator_videos cv ON cv.id = fr.video_id
  JOIN public.profiles p ON p.id = cv.creator_id
  WHERE fr.category = p_category
    AND fr.rank_position > p_cursor
    -- For "following" category, filter by followed creators
    AND (p_category != 'following' OR p_user_id IS NULL OR EXISTS (
      SELECT 1 FROM public.follows f
      WHERE f.follower_id = p_user_id AND f.following_id = cv.creator_id
    ))
  ORDER BY fr.rank_position
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ── Profile Grid RPC (Cursor-based) ─────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_creator_videos_page(
  p_creator_id UUID,
  p_cursor     TIMESTAMPTZ DEFAULT NULL,  -- created_at of last seen video
  p_limit      INT DEFAULT 18             -- 3-column × 6 rows
)
RETURNS TABLE (
  video_id         UUID,
  title            TEXT,
  thumbnail_url    TEXT,
  view_count       INT,
  like_count       INT,
  duration_seconds INT,
  created_at       TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    cv.id, cv.title, cv.thumbnail_url,
    cv.view_count, cv.like_count, cv.duration_seconds,
    cv.created_at
  FROM public.creator_videos cv
  WHERE cv.creator_id = p_creator_id
    AND cv.status = 'approved'
    AND cv.deleted_at IS NULL
    AND (p_cursor IS NULL OR cv.created_at < p_cursor)
  ORDER BY cv.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ── Additional Index Optimizations ──────────────────────────────────────────

-- Profile grid cursor (already partially covered, but this is exact)
CREATE INDEX IF NOT EXISTS idx_cv_creator_cursor
  ON public.creator_videos(creator_id, created_at DESC, id)
  WHERE status = 'approved' AND deleted_at IS NULL;

-- Engagement events: composite for per-video stats queries
CREATE INDEX IF NOT EXISTS idx_vee_video_created
  ON public.video_engagement_events(video_id, created_at DESC);
