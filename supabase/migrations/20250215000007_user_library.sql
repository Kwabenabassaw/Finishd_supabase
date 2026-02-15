-- ============================================================================
-- V3 Migration 7/10: User Library
-- ============================================================================

-- ── User Titles (Tracking) ──────────────────────────────────────────────────

CREATE TABLE public.user_titles (
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title_id      TEXT NOT NULL,
  media_type    TEXT NOT NULL REFERENCES public.media_types(value),
  title         TEXT NOT NULL,
  poster_path   TEXT,
  genre         TEXT,
  rating        INT,
  status        TEXT REFERENCES public.user_title_statuses(value),
  is_favorite   BOOLEAN DEFAULT false,
  rated_at      TIMESTAMPTZ,
  updated_at    TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, title_id, media_type)
);

CREATE INDEX idx_ut_user_status ON public.user_titles(user_id, status);
CREATE INDEX idx_ut_title       ON public.user_titles(title_id, media_type);

CREATE TRIGGER handle_ut_updated_at
  BEFORE UPDATE ON public.user_titles FOR EACH ROW EXECUTE PROCEDURE extensions.moddatetime(updated_at);

ALTER TABLE public.user_titles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read user titles" ON public.user_titles FOR SELECT USING (true);
CREATE POLICY "Users manage own titles" ON public.user_titles FOR ALL USING (auth.uid() = user_id);

-- ── User Ratings (ML Training History) ──────────────────────────────────────

CREATE TABLE public.user_ratings (
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title_id    TEXT NOT NULL,
  rating      INT NOT NULL CHECK (rating BETWEEN 1 AND 10),
  source      TEXT,
  created_at  TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, title_id, created_at)
);

CREATE INDEX idx_ur_user    ON public.user_ratings(user_id, created_at DESC);
CREATE INDEX idx_ur_title   ON public.user_ratings(title_id);

ALTER TABLE public.user_ratings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read ratings"  ON public.user_ratings FOR SELECT USING (true);
CREATE POLICY "Users manage ratings" ON public.user_ratings FOR ALL USING (auth.uid() = user_id);

-- ── Recommendations ─────────────────────────────────────────────────────────

CREATE TABLE public.recommendations (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  to_user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  movie_id      TEXT NOT NULL,
  media_type    TEXT REFERENCES public.media_types(value),
  title         TEXT,
  poster_path   TEXT,
  message       TEXT,
  status        TEXT DEFAULT 'unread',
  created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_rec_to_user ON public.recommendations(to_user_id, created_at DESC);

ALTER TABLE public.recommendations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own recommendations" ON public.recommendations FOR SELECT
  USING (auth.uid() = to_user_id OR auth.uid() = from_user_id);
CREATE POLICY "Users send recommendations" ON public.recommendations FOR INSERT
  WITH CHECK (auth.uid() = from_user_id);
CREATE POLICY "Users update received" ON public.recommendations FOR UPDATE
  USING (auth.uid() = to_user_id);

-- ── Seen History ────────────────────────────────────────────────────────────

CREATE TABLE public.seen_history (
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title_id    TEXT NOT NULL,
  media_type  TEXT NOT NULL REFERENCES public.media_types(value),
  seen_at     TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, title_id, media_type)
);

ALTER TABLE public.seen_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage seen" ON public.seen_history FOR ALL USING (auth.uid() = user_id);

-- ── Feed Cache ──────────────────────────────────────────────────────────────

CREATE TABLE public.feed_cache (
  user_id       UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  videos        JSONB NOT NULL,
  last_updated  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.feed_cache ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own cache"   ON public.feed_cache FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own cache" ON public.feed_cache FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own cache" ON public.feed_cache FOR UPDATE USING (auth.uid() = user_id);
