-- ============================================================================
-- Feed Interactions & Impressions Migration
-- Adds: video_interactions (unified per-user-video state),
--        feed_impressions (tracks served videos),
--        share_count column on creator_videos,
--        atomic share increment RPC,
--        upsert interaction RPC
-- ============================================================================

-- ── Video Interactions (Unified per-user-video state) ────────────────────────
-- Unlike video_engagement_events (append-only logs per watch session),
-- this table maintains ONE row per (user, video) with the latest aggregate
-- state: total watch time, best completion, liked/shared/skipped flags.

CREATE TABLE IF NOT EXISTS public.video_interactions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  video_id    UUID NOT NULL REFERENCES public.creator_videos(id) ON DELETE CASCADE,
  -- Watch metrics
  watch_time_ms   INT DEFAULT 0,
  duration_ms     INT DEFAULT 0,
  completed       BOOLEAN DEFAULT FALSE,
  -- Engagement flags
  liked           BOOLEAN DEFAULT FALSE,
  commented       BOOLEAN DEFAULT FALSE,
  shared          BOOLEAN DEFAULT FALSE,
  -- Negative signals
  skipped         BOOLEAN DEFAULT FALSE,
  -- Positive signals
  rewatched       BOOLEAN DEFAULT FALSE,
  -- Timestamps
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, video_id)
);

CREATE INDEX idx_vi_user     ON public.video_interactions(user_id);
CREATE INDEX idx_vi_video    ON public.video_interactions(video_id);
CREATE INDEX idx_vi_user_liked ON public.video_interactions(user_id) WHERE liked = TRUE;

ALTER TABLE public.video_interactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own interactions"
  ON public.video_interactions FOR ALL
  USING (auth.uid() = user_id);

CREATE POLICY "Creators view interactions on their videos"
  ON public.video_interactions FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.creator_videos
    WHERE id = video_id AND creator_id = auth.uid()
  ));

-- ── Feed Impressions ────────────────────────────────────────────────────────
-- Tracks which videos were served to each user and from which source.

CREATE TABLE IF NOT EXISTS public.feed_impressions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  video_id    UUID NOT NULL REFERENCES public.creator_videos(id) ON DELETE CASCADE,
  position    INT NOT NULL,
  feed_source TEXT NOT NULL CHECK (feed_source IN (
    'personalized', 'trending', 'social', 'explore'
  )),
  served_at   TIMESTAMPTZ DEFAULT NOW(),
  watched     BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_fi_user_served ON public.feed_impressions(user_id, served_at DESC);
CREATE INDEX idx_fi_video       ON public.feed_impressions(video_id);

ALTER TABLE public.feed_impressions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own impressions"
  ON public.feed_impressions FOR ALL
  USING (auth.uid() = user_id);

-- ── Add share_count to creator_videos ────────────────────────────────────────

ALTER TABLE public.creator_videos
  ADD COLUMN IF NOT EXISTS share_count INT DEFAULT 0;

-- ── Atomic Share Increment RPC ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.increment_video_shares(p_video_id UUID)
RETURNS void AS $$
  UPDATE public.creator_videos
  SET share_count = share_count + 1
  WHERE id = p_video_id;
$$ LANGUAGE sql SECURITY DEFINER;

-- ── Upsert Video Interaction RPC ────────────────────────────────────────────
-- Called from the client when the user swipes away from a video.
-- Upserts the (user_id, video_id) row with the latest watch metrics.

CREATE OR REPLACE FUNCTION public.upsert_video_interaction(
  p_video_id     UUID,
  p_watch_time_ms INT,
  p_duration_ms   INT,
  p_completed     BOOLEAN DEFAULT FALSE,
  p_skipped       BOOLEAN DEFAULT FALSE,
  p_rewatched     BOOLEAN DEFAULT FALSE
) RETURNS void AS $$
BEGIN
  INSERT INTO public.video_interactions (
    user_id, video_id, watch_time_ms, duration_ms,
    completed, skipped, rewatched
  ) VALUES (
    auth.uid(), p_video_id, p_watch_time_ms, p_duration_ms,
    p_completed, p_skipped, p_rewatched
  )
  ON CONFLICT (user_id, video_id) DO UPDATE SET
    watch_time_ms = GREATEST(video_interactions.watch_time_ms, EXCLUDED.watch_time_ms),
    duration_ms   = EXCLUDED.duration_ms,
    completed     = video_interactions.completed OR EXCLUDED.completed,
    skipped       = EXCLUDED.skipped,  -- latest swipe-away state
    rewatched     = video_interactions.rewatched OR EXCLUDED.rewatched,
    updated_at    = NOW();

  -- Update feed_impressions if watched > 2s
  IF p_watch_time_ms > 2000 THEN
    UPDATE public.feed_impressions
    SET watched = TRUE
    WHERE user_id = auth.uid() AND video_id = p_video_id AND watched = FALSE;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Batch Insert Feed Impressions RPC ───────────────────────────────────────
-- Called from client when a batch of videos is served.

CREATE OR REPLACE FUNCTION public.batch_insert_impressions(
  p_impressions JSONB
) RETURNS void AS $$
BEGIN
  INSERT INTO public.feed_impressions (user_id, video_id, position, feed_source)
  SELECT
    auth.uid(),
    (item->>'video_id')::UUID,
    (item->>'position')::INT,
    item->>'feed_source'
  FROM jsonb_array_elements(p_impressions) AS item
  ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
