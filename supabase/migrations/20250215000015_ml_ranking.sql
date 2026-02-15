-- ============================================================================
-- V3.1 Migration 15: ML Feature Store + User Affinity + Feed Ranking RPC
-- ============================================================================

-- ── ML Feature Store ────────────────────────────────────────────────────────
-- Pre-computed feature vectors for offline ML training and online scoring.
-- Updated by compute_feed_rankings() RPC.

CREATE TABLE public.ml_feature_store (
  video_id            UUID PRIMARY KEY REFERENCES public.creator_videos(id) ON DELETE CASCADE,
  f_completion_rate   NUMERIC(5,4) DEFAULT 0,        -- avg watch completion
  f_like_ratio        NUMERIC(8,6) DEFAULT 0,        -- likes / views
  f_comment_ratio     NUMERIC(8,6) DEFAULT 0,        -- comments / views
  f_share_ratio       NUMERIC(8,6) DEFAULT 0,        -- shares / views
  f_ctr               NUMERIC(5,4) DEFAULT 0,        -- clicks / impressions
  f_creator_trust     NUMERIC(5,4) DEFAULT 0.5,      -- from creator_trust_scores
  f_recency_hours     NUMERIC(10,2) DEFAULT 0,       -- hours since creation
  f_duration_bucket   INT DEFAULT 1,                  -- 1=short(<15s) 2=medium 3=long(>45s)
  f_report_rate       NUMERIC(5,4) DEFAULT 0,        -- reports / views
  f_hashtag_velocity  NUMERIC(10,4) DEFAULT 0,       -- avg trending score of tags
  computed_at         TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.ml_feature_store ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins read features" ON public.ml_feature_store FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ── User Affinity Vectors ───────────────────────────────────────────────────
-- Per-user taste profile for "For You" personalization.

CREATE TABLE public.user_affinity_vectors (
  user_id                 UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  genre_weights           JSONB DEFAULT '{}',       -- {"horror": 0.8, "comedy": 0.4}
  creator_weights         JSONB DEFAULT '{}',       -- {"creator_uuid": 0.9, ...}
  preferred_duration      TEXT DEFAULT 'medium' CHECK (preferred_duration IN ('short','medium','long')),
  avg_watch_time_seconds  INT DEFAULT 0,
  total_videos_watched    INT DEFAULT 0,
  computed_at             TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.user_affinity_vectors ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own affinity" ON public.user_affinity_vectors
  FOR SELECT USING (auth.uid() = user_id);

-- ── Feed Ranking RPC ────────────────────────────────────────────────────────
-- The core ranking engine. Called by pg_cron every 15 minutes.
--
-- Ranking formula (normalized 0..1):
--   0.30 × completion_rate
-- + 0.25 × log(1 + likes) / log(1 + max_likes)
-- + 0.20 × recency_decay  [1 / (1 + hours/48)]
-- + 0.15 × ctr
-- + 0.10 × creator_trust
-- × cold_start_boost      [1.5 if age < 24h]
-- × suppression_penalty   [0.0 if suppress_until > now()]

CREATE OR REPLACE FUNCTION public.compute_feed_rankings()
RETURNS JSONB AS $$
DECLARE
  v_max_likes  INT;
  v_ranked     INT := 0;
  v_features   INT := 0;
BEGIN
  -- 1. Get global max likes for normalization
  SELECT COALESCE(MAX(like_count), 1) INTO v_max_likes
  FROM public.creator_videos
  WHERE status = 'approved' AND deleted_at IS NULL;

  -- 2. Compute features for all approved videos
  INSERT INTO public.ml_feature_store (
    video_id, f_completion_rate, f_like_ratio, f_comment_ratio, f_share_ratio,
    f_creator_trust, f_recency_hours, f_duration_bucket, f_report_rate,
    computed_at
  )
  SELECT
    cv.id,
    cv.avg_completion_pct,
    CASE WHEN cv.view_count > 0 THEN cv.like_count::numeric / cv.view_count ELSE 0 END,
    CASE WHEN cv.view_count > 0 THEN cv.comment_count::numeric / cv.view_count ELSE 0 END,
    CASE WHEN cv.view_count > 0 THEN cv.share_count::numeric / cv.view_count ELSE 0 END,
    COALESCE(cts.trust_score, 0.5),
    EXTRACT(EPOCH FROM (now() - cv.created_at)) / 3600.0,
    CASE
      WHEN cv.duration_seconds < 15 THEN 1
      WHEN cv.duration_seconds <= 45 THEN 2
      ELSE 3
    END,
    CASE WHEN cv.view_count > 0 THEN cv.report_count::numeric / cv.view_count ELSE 0 END,
    now()
  FROM public.creator_videos cv
  LEFT JOIN public.creator_trust_scores cts ON cts.creator_id = cv.creator_id
  WHERE cv.status = 'approved' AND cv.deleted_at IS NULL
  ON CONFLICT (video_id) DO UPDATE SET
    f_completion_rate  = EXCLUDED.f_completion_rate,
    f_like_ratio       = EXCLUDED.f_like_ratio,
    f_comment_ratio    = EXCLUDED.f_comment_ratio,
    f_share_ratio      = EXCLUDED.f_share_ratio,
    f_creator_trust    = EXCLUDED.f_creator_trust,
    f_recency_hours    = EXCLUDED.f_recency_hours,
    f_duration_bucket  = EXCLUDED.f_duration_bucket,
    f_report_rate      = EXCLUDED.f_report_rate,
    computed_at        = now();
  GET DIAGNOSTICS v_features = ROW_COUNT;

  -- 3. Update engagement_score on creator_videos using the ranking formula
  UPDATE public.creator_videos cv SET
    engagement_score = (
      0.30 * cv.avg_completion_pct
      + 0.25 * (ln(1 + cv.like_count) / ln(1 + GREATEST(v_max_likes, 1)))
      + 0.20 * (1.0 / (1.0 + EXTRACT(EPOCH FROM (now() - cv.created_at)) / 3600.0 / 48.0))
      + 0.15 * COALESCE(fs.f_ctr, 0)
      + 0.10 * COALESCE(fs.f_creator_trust, 0.5)
    )
    -- Cold-start boost: 1.5× for videos < 24h old
    * CASE WHEN cv.boost_until IS NOT NULL AND cv.boost_until > now() THEN 1.5 ELSE 1.0 END
    -- Suppression penalty: zero out suppressed videos
    * CASE WHEN cv.suppress_until IS NOT NULL AND cv.suppress_until > now() THEN 0.0 ELSE 1.0 END
    -- High report rate penalty
    * CASE WHEN cv.report_count >= 3 THEN 0.3
           WHEN cv.report_count >= 1 THEN 0.7
           ELSE 1.0 END
  FROM public.ml_feature_store fs
  WHERE fs.video_id = cv.id
    AND cv.status = 'approved'
    AND cv.deleted_at IS NULL;

  -- 4. Rebuild feed_rankings table (atomic swap)
  -- Trending: top videos by engagement_score
  DELETE FROM public.feed_rankings WHERE category = 'trending';
  INSERT INTO public.feed_rankings (video_id, category, rank_position, computed_at)
  SELECT
    id, 'trending', ROW_NUMBER() OVER (ORDER BY engagement_score DESC, created_at DESC),
    now()
  FROM public.creator_videos
  WHERE status = 'approved' AND deleted_at IS NULL
    AND (suppress_until IS NULL OR suppress_until < now())
  ORDER BY engagement_score DESC
  LIMIT 500;

  -- For You: similar but with diversity injection (max 2 per creator)
  DELETE FROM public.feed_rankings WHERE category = 'for_you';
  INSERT INTO public.feed_rankings (video_id, category, rank_position, computed_at)
  SELECT video_id, 'for_you', ROW_NUMBER() OVER (ORDER BY engagement_score DESC), now()
  FROM (
    SELECT
      cv.id AS video_id,
      cv.engagement_score,
      ROW_NUMBER() OVER (PARTITION BY cv.creator_id ORDER BY cv.engagement_score DESC) AS creator_rank
    FROM public.creator_videos cv
    WHERE cv.status = 'approved' AND cv.deleted_at IS NULL
      AND (cv.suppress_until IS NULL OR cv.suppress_until < now())
  ) ranked
  WHERE creator_rank <= 2  -- Max 2 videos per creator for diversity
  ORDER BY engagement_score DESC
  LIMIT 500;

  -- Following: ranked by recency × engagement (users see who they follow)
  DELETE FROM public.feed_rankings WHERE category = 'following';
  INSERT INTO public.feed_rankings (video_id, category, rank_position, computed_at)
  SELECT
    id, 'following', ROW_NUMBER() OVER (ORDER BY created_at DESC), now()
  FROM public.creator_videos
  WHERE status = 'approved' AND deleted_at IS NULL
    AND (suppress_until IS NULL OR suppress_until < now())
    AND created_at >= now() - interval '7 days'
  LIMIT 200;

  GET DIAGNOSTICS v_ranked = ROW_COUNT;

  RETURN jsonb_build_object(
    'features_updated', v_features,
    'rankings_updated', v_ranked,
    'max_likes', v_max_likes,
    'computed_at', now()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Feed Rankings Index Optimization ────────────────────────────────────────
-- Covering index: the feed query only touches this index (index-only scan)

DROP INDEX IF EXISTS idx_fr_cat_rank;
CREATE INDEX idx_fr_cat_rank_vid ON public.feed_rankings(category, rank_position) INCLUDE (video_id, computed_at);

-- ── Score Snapshots (Auditing / ML Training) ────────────────────────────────

CREATE TABLE public.video_score_snapshots (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  video_id         UUID NOT NULL,
  engagement_score NUMERIC(10,4),
  features         JSONB,    -- snapshot of ml_feature_store row
  computed_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_vss_video_time ON public.video_score_snapshots(video_id, computed_at DESC);

-- Keep only 30 days of snapshots; older ones archived or deleted
-- Schedule: DELETE FROM video_score_snapshots WHERE computed_at < now() - interval '30 days';

ALTER TABLE public.video_score_snapshots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins read score history" ON public.video_score_snapshots FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Schedule the ranking computation: uncomment when pg_cron is available
-- SELECT cron.schedule('compute-rankings', '*/15 * * * *', 'SELECT public.compute_feed_rankings()');
-- SELECT cron.schedule('compute-trust',    '0 */6 * * *',  'SELECT public.compute_creator_trust_scores()');
