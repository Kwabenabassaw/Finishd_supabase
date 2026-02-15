-- ============================================================================
-- V3 Migration 8/10: Feed & Analytics
-- ============================================================================

-- ── Feed Rankings ───────────────────────────────────────────────────────────

CREATE TABLE public.feed_rankings (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id      UUID NOT NULL REFERENCES public.creator_videos(id) ON DELETE CASCADE,
  category      TEXT DEFAULT 'for_you' REFERENCES public.feed_categories(value),
  rank_position INT NOT NULL,
  computed_at   TIMESTAMPTZ DEFAULT now(),
  UNIQUE (video_id, category)
);

CREATE INDEX idx_fr_cat_rank ON public.feed_rankings(category, rank_position);

ALTER TABLE public.feed_rankings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read rankings" ON public.feed_rankings FOR SELECT USING (true);
CREATE POLICY "Admins manage rankings" ON public.feed_rankings FOR ALL USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ── Feed Impressions (Partitioned — CTR Tracking) ───────────────────────────

CREATE TABLE public.feed_impressions (
  user_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  video_id  UUID NOT NULL REFERENCES public.creator_videos(id) ON DELETE CASCADE,
  clicked   BOOLEAN DEFAULT false,
  shown_at  TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, video_id, shown_at)
) PARTITION BY RANGE (shown_at);

CREATE TABLE public.fi_default PARTITION OF public.feed_impressions DEFAULT;
CREATE TABLE public.fi_2025_02 PARTITION OF public.feed_impressions
  FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE public.fi_2025_03 PARTITION OF public.feed_impressions
  FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE public.fi_2025_04 PARTITION OF public.feed_impressions
  FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');

CREATE INDEX idx_fi_user_shown ON public.feed_impressions(user_id, shown_at DESC);
CREATE INDEX idx_fi_video      ON public.feed_impressions(video_id);

ALTER TABLE public.feed_impressions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users insert impressions" ON public.feed_impressions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users view own impressions" ON public.feed_impressions FOR SELECT USING (auth.uid() = user_id);

-- ── Video Daily Stats (Aggregated) ──────────────────────────────────────────

CREATE TABLE public.video_daily_stats (
  video_id            UUID NOT NULL REFERENCES public.creator_videos(id) ON DELETE CASCADE,
  date                DATE NOT NULL,
  total_views         INT DEFAULT 0,
  total_watch_time    BIGINT DEFAULT 0,
  sum_completion_pct  NUMERIC(12,4) DEFAULT 0,
  PRIMARY KEY (video_id, date)
);

CREATE INDEX idx_vds_date ON public.video_daily_stats(date);

ALTER TABLE public.video_daily_stats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Creators view own stats" ON public.video_daily_stats FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.creator_videos WHERE id = video_id AND creator_id = auth.uid())
);
CREATE POLICY "Admins view all stats" ON public.video_daily_stats FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Aggregation trigger
CREATE OR REPLACE FUNCTION public.update_video_daily_stats()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.video_daily_stats (video_id, date, total_views, total_watch_time, sum_completion_pct)
  VALUES (NEW.video_id, CURRENT_DATE, 1, NEW.watch_duration_seconds, NEW.completion_pct)
  ON CONFLICT (video_id, date) DO UPDATE SET
    total_views        = public.video_daily_stats.total_views + 1,
    total_watch_time   = public.video_daily_stats.total_watch_time + EXCLUDED.total_watch_time,
    sum_completion_pct = public.video_daily_stats.sum_completion_pct + EXCLUDED.sum_completion_pct;
  -- Also bump the video-level counter
  UPDATE public.creator_videos SET view_count = view_count + 1 WHERE id = NEW.video_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_engagement_event
  AFTER INSERT ON public.video_engagement_events
  FOR EACH ROW EXECUTE FUNCTION public.update_video_daily_stats();

-- ── User Daily Stats (Retention/Monetization) ───────────────────────────────

CREATE TABLE public.user_daily_stats (
  user_id          UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  date             DATE NOT NULL,
  videos_watched   INT DEFAULT 0,
  minutes_watched  INT DEFAULT 0,
  posts_made       INT DEFAULT 0,
  PRIMARY KEY (user_id, date)
);

ALTER TABLE public.user_daily_stats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own daily stats" ON public.user_daily_stats FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Admins view daily stats" ON public.user_daily_stats FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ── Analytics Events (General) ──────────────────────────────────────────────

CREATE TABLE public.analytics_events (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users(id),
  event_name  TEXT NOT NULL,
  parameters  JSONB,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_ae_user_created ON public.analytics_events(user_id, created_at DESC);
CREATE INDEX idx_ae_event        ON public.analytics_events(event_name);

ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users insert own events" ON public.analytics_events FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users view own events"   ON public.analytics_events FOR SELECT USING (auth.uid() = user_id);
