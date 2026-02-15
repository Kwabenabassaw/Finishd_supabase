-- ============================================================================
-- V3.1 Migration 11: Decoupled Counter Events
-- ============================================================================
-- Problem: Synchronous triggers on video_reactions/video_comments do
--          UPDATE creator_videos SET like_count = like_count + 1
--          This takes an exclusive row lock per write. At 10K writes/sec
--          the hot row becomes a bottleneck causing cascading lock waits.
--
-- Solution: INSERT-only counter events table. A periodic RPC flushes
--           accumulated deltas into creator_videos in bulk.
-- ============================================================================

-- ── Counter Events (Write-Optimized) ────────────────────────────────────────

CREATE TABLE public.video_counter_events (
  id         BIGINT GENERATED ALWAYS AS IDENTITY,
  video_id   UUID NOT NULL,
  counter    TEXT NOT NULL CHECK (counter IN ('like','comment','view','share')),
  delta      INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Unlogged-style: no FK constraint on video_id for write speed.
-- Orphan rows are harmless — they reference deleted videos and get
-- cleaned up during flush.

CREATE INDEX idx_vce_unflushed ON public.video_counter_events(video_id);

-- RLS: auth insert only, no direct reads (flushed by SECURITY DEFINER RPC)
ALTER TABLE public.video_counter_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Auth insert counter events" ON public.video_counter_events
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- ── Flush RPC ───────────────────────────────────────────────────────────────
-- Called by pg_cron every 30 seconds or by Edge Function on a schedule.
-- Aggregates all pending deltas, applies them to creator_videos, then deletes.

CREATE OR REPLACE FUNCTION public.flush_counter_events()
RETURNS JSONB AS $$
DECLARE
  v_flushed INT := 0;
  v_max_id  BIGINT;
BEGIN
  -- Snapshot the current max id to avoid flushing rows that arrive mid-flush
  SELECT MAX(id) INTO v_max_id FROM public.video_counter_events;
  IF v_max_id IS NULL THEN
    RETURN jsonb_build_object('flushed', 0);
  END IF;

  -- Aggregate and apply like deltas
  UPDATE public.creator_videos cv SET
    like_count = like_count + agg.total_delta
  FROM (
    SELECT video_id, SUM(delta) AS total_delta
    FROM public.video_counter_events
    WHERE counter = 'like' AND id <= v_max_id
    GROUP BY video_id
  ) agg
  WHERE cv.id = agg.video_id;

  -- Aggregate and apply comment deltas
  UPDATE public.creator_videos cv SET
    comment_count = comment_count + agg.total_delta
  FROM (
    SELECT video_id, SUM(delta) AS total_delta
    FROM public.video_counter_events
    WHERE counter = 'comment' AND id <= v_max_id
    GROUP BY video_id
  ) agg
  WHERE cv.id = agg.video_id;

  -- Aggregate and apply view deltas
  UPDATE public.creator_videos cv SET
    view_count = view_count + agg.total_delta
  FROM (
    SELECT video_id, SUM(delta) AS total_delta
    FROM public.video_counter_events
    WHERE counter = 'view' AND id <= v_max_id
    GROUP BY video_id
  ) agg
  WHERE cv.id = agg.video_id;

  -- Delete flushed rows
  DELETE FROM public.video_counter_events WHERE id <= v_max_id;
  GET DIAGNOSTICS v_flushed = ROW_COUNT;

  RETURN jsonb_build_object('flushed', v_flushed, 'max_id', v_max_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule: uncomment when pg_cron is available
-- SELECT cron.schedule('flush-counters', '30 seconds', 'SELECT public.flush_counter_events()');
