-- ============================================================================
-- V3.1 Migration 13: Creator Videos Enhancements
-- ============================================================================
-- Additive-only changes to creator_videos. No columns dropped.
-- ============================================================================

-- ── New columns ─────────────────────────────────────────────────────────────

-- Moderation intelligence
ALTER TABLE public.creator_videos ADD COLUMN IF NOT EXISTS
  moderation_flags    JSONB DEFAULT '{}';              -- {"nudity": 0.1, "violence": 0.3}
ALTER TABLE public.creator_videos ADD COLUMN IF NOT EXISTS
  auto_quality_score  NUMERIC(5,4);                    -- ML-assigned 0..1
ALTER TABLE public.creator_videos ADD COLUMN IF NOT EXISTS
  report_count        INT DEFAULT 0;

-- Feed control
ALTER TABLE public.creator_videos ADD COLUMN IF NOT EXISTS
  suppress_until      TIMESTAMPTZ;                     -- Soft moderation hide
ALTER TABLE public.creator_videos ADD COLUMN IF NOT EXISTS
  boost_until         TIMESTAMPTZ DEFAULT (now() + interval '24 hours');  -- Cold-start

-- A/B testing
ALTER TABLE public.creator_videos ADD COLUMN IF NOT EXISTS
  alt_title           TEXT;
ALTER TABLE public.creator_videos ADD COLUMN IF NOT EXISTS
  alt_thumbnail_url   TEXT;

-- Share counter
ALTER TABLE public.creator_videos ADD COLUMN IF NOT EXISTS
  share_count         INT DEFAULT 0;

-- ── New indexes ─────────────────────────────────────────────────────────────

-- Feed query: approved, not deleted, not suppressed, ordered by score
CREATE INDEX IF NOT EXISTS idx_cv_ranked_feed
  ON public.creator_videos(engagement_score DESC, created_at DESC)
  WHERE status = 'approved'
    AND deleted_at IS NULL;

-- Moderation queue: pending videos ordered by age
CREATE INDEX IF NOT EXISTS idx_cv_moderation_queue
  ON public.creator_videos(created_at ASC)
  WHERE status = 'pending' AND deleted_at IS NULL;

-- Report count threshold for auto-suppress
CREATE INDEX IF NOT EXISTS idx_cv_reported
  ON public.creator_videos(report_count DESC)
  WHERE report_count > 0 AND status = 'approved';

-- ── Report-count sync trigger ───────────────────────────────────────────────
-- Keeps creator_videos.report_count in sync with creator_video_reports.

CREATE OR REPLACE FUNCTION public.sync_report_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.creator_videos
    SET report_count = report_count + 1
    WHERE id = NEW.video_id;

    -- Auto-suppress if threshold reached
    IF (SELECT report_count FROM public.creator_videos WHERE id = NEW.video_id) >= 3 THEN
      UPDATE public.creator_videos
      SET suppress_until = GREATEST(
        COALESCE(suppress_until, now()),
        now() + interval '24 hours'
      )
      WHERE id = NEW.video_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_video_report
  AFTER INSERT ON public.creator_video_reports
  FOR EACH ROW EXECUTE FUNCTION public.sync_report_count();

-- ── Auto-partition creator for engagement events ────────────────────────────
-- Creates next month's partition if it doesn't exist.

CREATE OR REPLACE FUNCTION public.ensure_engagement_partition()
RETURNS VOID AS $$
DECLARE
  v_start DATE := date_trunc('month', now() + interval '1 month');
  v_end   DATE := v_start + interval '1 month';
  v_name  TEXT := 'vee_' || to_char(v_start, 'YYYY_MM');
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class WHERE relname = v_name
  ) THEN
    EXECUTE format(
      'CREATE TABLE public.%I PARTITION OF public.video_engagement_events FOR VALUES FROM (%L) TO (%L)',
      v_name, v_start, v_end
    );
    RAISE NOTICE 'Created partition %', v_name;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Also for feed_impressions
CREATE OR REPLACE FUNCTION public.ensure_impressions_partition()
RETURNS VOID AS $$
DECLARE
  v_start DATE := date_trunc('month', now() + interval '1 month');
  v_end   DATE := v_start + interval '1 month';
  v_name  TEXT := 'fi_' || to_char(v_start, 'YYYY_MM');
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class WHERE relname = v_name
  ) THEN
    EXECUTE format(
      'CREATE TABLE public.%I PARTITION OF public.feed_impressions FOR VALUES FROM (%L) TO (%L)',
      v_name, v_start, v_end
    );
    RAISE NOTICE 'Created partition %', v_name;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Schedule monthly: uncomment when pg_cron is available
-- SELECT cron.schedule('create-vee-partition', '0 0 25 * *', 'SELECT public.ensure_engagement_partition()');
-- SELECT cron.schedule('create-fi-partition',  '0 0 25 * *', 'SELECT public.ensure_impressions_partition()');
