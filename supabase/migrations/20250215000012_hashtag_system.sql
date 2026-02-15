-- ============================================================================
-- V3.1 Migration 12: Hashtag & Discovery System
-- ============================================================================
-- Problem: tags TEXT[] on creator_videos has no GIN index and no normalized
--          table. Hashtag search requires a full table scan, trending
--          hashtags are impossible, and tag analytics don't exist.
--
-- Solution: Normalized hashtag tables + GIN index + trending score.
-- ============================================================================

-- ── GIN Index on existing tags column (immediate win) ───────────────────────

CREATE INDEX IF NOT EXISTS idx_cv_tags_gin
  ON public.creator_videos USING GIN (tags)
  WHERE tags IS NOT NULL AND deleted_at IS NULL;

-- ── Hashtags (Normalized) ───────────────────────────────────────────────────

CREATE TABLE public.hashtags (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tag             TEXT NOT NULL,
  tag_normalized  TEXT NOT NULL UNIQUE,  -- lowercase, no #
  usage_count     INT DEFAULT 0,
  trending_score  NUMERIC(10,4) DEFAULT 0,
  is_banned       BOOLEAN DEFAULT false,
  first_used_at   TIMESTAMPTZ DEFAULT now(),
  last_used_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_ht_trending ON public.hashtags(trending_score DESC) WHERE NOT is_banned;
CREATE INDEX idx_ht_usage    ON public.hashtags(usage_count DESC) WHERE NOT is_banned;
CREATE INDEX idx_ht_search   ON public.hashtags USING GIN (tag_normalized extensions.gin_trgm_ops);

ALTER TABLE public.hashtags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read hashtags" ON public.hashtags FOR SELECT USING (true);
CREATE POLICY "Admins manage hashtags" ON public.hashtags FOR ALL USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ── Video ↔ Hashtag Junction ────────────────────────────────────────────────

CREATE TABLE public.video_hashtags (
  video_id    UUID NOT NULL REFERENCES public.creator_videos(id) ON DELETE CASCADE,
  hashtag_id  UUID NOT NULL REFERENCES public.hashtags(id) ON DELETE CASCADE,
  PRIMARY KEY (video_id, hashtag_id)
);

CREATE INDEX idx_vh_hashtag ON public.video_hashtags(hashtag_id);

ALTER TABLE public.video_hashtags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read video hashtags" ON public.video_hashtags FOR SELECT USING (true);

-- ── Sync Trigger: Extract tags on video insert/update ───────────────────────

CREATE OR REPLACE FUNCTION public.sync_video_hashtags()
RETURNS TRIGGER AS $$
DECLARE
  raw_tag TEXT;
  clean_tag TEXT;
  ht_id UUID;
BEGIN
  -- Only process if tags changed
  IF TG_OP = 'UPDATE' AND NEW.tags IS NOT DISTINCT FROM OLD.tags THEN
    RETURN NEW;
  END IF;

  -- Remove old junction rows for this video
  DELETE FROM public.video_hashtags WHERE video_id = NEW.id;

  -- Decrement old tag counts (on UPDATE only)
  IF TG_OP = 'UPDATE' AND OLD.tags IS NOT NULL THEN
    FOREACH raw_tag IN ARRAY OLD.tags LOOP
      clean_tag := lower(regexp_replace(raw_tag, '^#', ''));
      UPDATE public.hashtags SET usage_count = GREATEST(usage_count - 1, 0)
        WHERE tag_normalized = clean_tag;
    END LOOP;
  END IF;

  -- Process new tags
  IF NEW.tags IS NOT NULL THEN
    FOREACH raw_tag IN ARRAY NEW.tags LOOP
      clean_tag := lower(regexp_replace(raw_tag, '^#', ''));
      IF length(clean_tag) < 2 THEN CONTINUE; END IF;

      -- Upsert hashtag
      INSERT INTO public.hashtags (tag, tag_normalized, usage_count, last_used_at)
      VALUES (raw_tag, clean_tag, 1, now())
      ON CONFLICT (tag_normalized) DO UPDATE SET
        usage_count = public.hashtags.usage_count + 1,
        last_used_at = now()
      RETURNING id INTO ht_id;

      -- Create junction
      INSERT INTO public.video_hashtags (video_id, hashtag_id)
      VALUES (NEW.id, ht_id)
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_video_tags_change
  AFTER INSERT OR UPDATE OF tags ON public.creator_videos
  FOR EACH ROW EXECUTE FUNCTION public.sync_video_hashtags();

-- ── Trending Score RPC ──────────────────────────────────────────────────────
-- Call via pg_cron every 15 minutes.
-- trending_score = recent_24h_usage / (avg_7d_usage + 1)

CREATE OR REPLACE FUNCTION public.compute_trending_hashtags()
RETURNS VOID AS $$
BEGIN
  UPDATE public.hashtags h SET
    trending_score = COALESCE(recent.cnt, 0)::numeric / (COALESCE(weekly.avg_cnt, 0) + 1)
  FROM (
    SELECT vh.hashtag_id, COUNT(*) AS cnt
    FROM public.video_hashtags vh
    JOIN public.creator_videos cv ON cv.id = vh.video_id
    WHERE cv.created_at >= now() - interval '24 hours'
      AND cv.status = 'approved' AND cv.deleted_at IS NULL
    GROUP BY vh.hashtag_id
  ) recent
  LEFT JOIN (
    SELECT vh.hashtag_id, COUNT(*)::numeric / 7 AS avg_cnt
    FROM public.video_hashtags vh
    JOIN public.creator_videos cv ON cv.id = vh.video_id
    WHERE cv.created_at >= now() - interval '7 days'
      AND cv.status = 'approved' AND cv.deleted_at IS NULL
    GROUP BY vh.hashtag_id
  ) weekly ON weekly.hashtag_id = recent.hashtag_id
  WHERE h.id = recent.hashtag_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
