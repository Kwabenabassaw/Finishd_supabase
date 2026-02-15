-- ============================================================================
-- V3 Migration 2/10: Content Graph (Titles, People, Cast, Streaming)
-- ============================================================================

-- ── Titles (Centralized TMDB Cache) ─────────────────────────────────────────

CREATE TABLE public.titles (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tmdb_id       INT UNIQUE NOT NULL,
  media_type    TEXT NOT NULL REFERENCES public.media_types(value),
  title         TEXT NOT NULL,
  overview      TEXT,
  poster_url    TEXT,
  backdrop_url  TEXT,
  release_date  DATE,
  popularity    NUMERIC,
  vote_average  NUMERIC,
  genre_ids     INT[],
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_titles_tmdb        ON public.titles(tmdb_id);
CREATE INDEX idx_titles_popularity  ON public.titles(popularity DESC NULLS LAST);
CREATE INDEX idx_titles_media_type  ON public.titles(media_type);
CREATE INDEX idx_titles_release     ON public.titles(release_date DESC NULLS LAST);

CREATE TRIGGER handle_titles_updated_at
  BEFORE UPDATE ON public.titles FOR EACH ROW EXECUTE PROCEDURE extensions.moddatetime(updated_at);

ALTER TABLE public.titles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read titles" ON public.titles FOR SELECT USING (true);
CREATE POLICY "Admins manage titles" ON public.titles FOR ALL USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ── Title Similarities (ML Recommendation Graph) ────────────────────────────

CREATE TABLE public.title_similarities (
  title_id         UUID NOT NULL REFERENCES public.titles(id) ON DELETE CASCADE,
  similar_title_id UUID NOT NULL REFERENCES public.titles(id) ON DELETE CASCADE,
  score            NUMERIC(5,4) DEFAULT 0,
  PRIMARY KEY (title_id, similar_title_id),
  CHECK (title_id != similar_title_id)
);

CREATE INDEX idx_similarities_score ON public.title_similarities(title_id, score DESC);

ALTER TABLE public.title_similarities ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read similarities" ON public.title_similarities FOR SELECT USING (true);

-- ── People (Cast & Crew) ────────────────────────────────────────────────────

CREATE TABLE public.people (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tmdb_person_id  INT UNIQUE,
  name            TEXT NOT NULL,
  profile_url     TEXT,
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_people_tmdb ON public.people(tmdb_person_id);

ALTER TABLE public.people ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read people" ON public.people FOR SELECT USING (true);

-- ── Title Cast ──────────────────────────────────────────────────────────────

CREATE TABLE public.title_cast (
  title_id        UUID NOT NULL REFERENCES public.titles(id) ON DELETE CASCADE,
  person_id       UUID NOT NULL REFERENCES public.people(id) ON DELETE CASCADE,
  character_name  TEXT,
  order_index     INT,
  PRIMARY KEY (title_id, person_id)
);

CREATE INDEX idx_cast_person ON public.title_cast(person_id);

ALTER TABLE public.title_cast ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read cast" ON public.title_cast FOR SELECT USING (true);

-- ── Streaming Platforms ─────────────────────────────────────────────────────

CREATE TABLE public.streaming_platforms (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name      TEXT NOT NULL UNIQUE,
  slug      TEXT NOT NULL UNIQUE,
  logo_url  TEXT
);

ALTER TABLE public.streaming_platforms ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read platforms" ON public.streaming_platforms FOR SELECT USING (true);
CREATE POLICY "Admins manage platforms" ON public.streaming_platforms FOR ALL USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ── Title Streaming Availability ────────────────────────────────────────────

CREATE TABLE public.title_streaming_availability (
  title_id       UUID NOT NULL REFERENCES public.titles(id) ON DELETE CASCADE,
  platform_id    UUID NOT NULL REFERENCES public.streaming_platforms(id) ON DELETE CASCADE,
  country_code   TEXT NOT NULL DEFAULT 'US',
  deep_link_url  TEXT,
  web_url        TEXT,
  created_at     TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (title_id, platform_id, country_code)
);

CREATE INDEX idx_streaming_country ON public.title_streaming_availability(country_code);

ALTER TABLE public.title_streaming_availability ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read availability" ON public.title_streaming_availability FOR SELECT USING (true);
CREATE POLICY "Admins manage availability" ON public.title_streaming_availability FOR ALL USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);
