-- ============================================================================
-- V3 Migration 5/10: Creator Video System
-- ============================================================================

-- ── Creator Videos ──────────────────────────────────────────────────────────

CREATE TABLE public.creator_videos (
  id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id                UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  -- Media
  video_url                 TEXT NOT NULL,
  thumbnail_url             TEXT,
  duration_seconds          INT NOT NULL CHECK (duration_seconds BETWEEN 5 AND 180),
  aspect_ratio              TEXT DEFAULT '9:16',
  -- TMDB Linking
  tmdb_id                   INT,
  tmdb_type                 TEXT CHECK (tmdb_type IS NULL OR tmdb_type IN ('movie', 'tv')),
  tmdb_title                TEXT,
  -- Metadata
  title                     TEXT,
  description               TEXT,
  tags                      TEXT[],
  spoiler                   BOOLEAN DEFAULT false,
  -- Moderation
  status                    TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','removed')),
  reviewed_by               UUID REFERENCES public.profiles(id),
  reviewed_at               TIMESTAMPTZ,
  rejection_reason          TEXT,
  -- Counters (denormalized)
  view_count                INT DEFAULT 0,
  total_watch_time_seconds  INT DEFAULT 0,
  avg_completion_pct        NUMERIC(5,4) DEFAULT 0 CHECK (avg_completion_pct BETWEEN 0 AND 1),
  like_count                INT DEFAULT 0,
  comment_count             INT DEFAULT 0,
  -- Scoring
  engagement_score          NUMERIC(10,4) DEFAULT 0,
  quality_score             NUMERIC(10,4),
  -- Soft delete & timestamps
  deleted_at                TIMESTAMPTZ,
  created_at                TIMESTAMPTZ DEFAULT now(),
  updated_at                TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_cv_creator           ON public.creator_videos(creator_id, created_at DESC);
CREATE INDEX idx_cv_status            ON public.creator_videos(status);
CREATE INDEX idx_cv_approved_score    ON public.creator_videos(engagement_score DESC) WHERE status = 'approved' AND deleted_at IS NULL;
CREATE INDEX idx_cv_tmdb              ON public.creator_videos(tmdb_id, tmdb_type) WHERE tmdb_id IS NOT NULL;

CREATE TRIGGER handle_cv_updated_at
  BEFORE UPDATE ON public.creator_videos FOR EACH ROW EXECUTE PROCEDURE extensions.moddatetime(updated_at);

ALTER TABLE public.creator_videos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public view approved videos"  ON public.creator_videos FOR SELECT USING (status = 'approved' AND deleted_at IS NULL);
CREATE POLICY "Creators view own videos"     ON public.creator_videos FOR SELECT USING (auth.uid() = creator_id);
CREATE POLICY "Creators upload videos"       ON public.creator_videos FOR INSERT WITH CHECK (
  auth.uid() = creator_id AND EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'creator' AND creator_status = 'approved'
  )
);
CREATE POLICY "Creators update pending"      ON public.creator_videos FOR UPDATE USING (
  auth.uid() = creator_id AND status IN ('pending', 'rejected')
);
CREATE POLICY "Creators delete pending"      ON public.creator_videos FOR DELETE USING (
  auth.uid() = creator_id AND status IN ('pending', 'rejected')
);
CREATE POLICY "Admins view all videos"       ON public.creator_videos FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'reviewer'))
);
CREATE POLICY "Admins moderate videos"       ON public.creator_videos FOR UPDATE USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'reviewer'))
);

-- ── Video Engagement Events (Partitioned by Month) ──────────────────────────

CREATE TABLE public.video_engagement_events (
  id                      UUID DEFAULT gen_random_uuid(),
  video_id                UUID NOT NULL REFERENCES public.creator_videos(id) ON DELETE CASCADE,
  user_id                 UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  watch_duration_seconds  INT NOT NULL CHECK (watch_duration_seconds >= 0),
  completion_pct          NUMERIC(5,4) NOT NULL CHECK (completion_pct BETWEEN 0 AND 1),
  created_at              TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Default + initial partitions
CREATE TABLE public.vee_default PARTITION OF public.video_engagement_events DEFAULT;
CREATE TABLE public.vee_2025_02 PARTITION OF public.video_engagement_events
  FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE public.vee_2025_03 PARTITION OF public.video_engagement_events
  FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE public.vee_2025_04 PARTITION OF public.video_engagement_events
  FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');

CREATE INDEX idx_vee_video   ON public.video_engagement_events(video_id);
CREATE INDEX idx_vee_user    ON public.video_engagement_events(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_vee_created ON public.video_engagement_events(created_at DESC);

ALTER TABLE public.video_engagement_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Auth insert engagement"       ON public.video_engagement_events FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Users view own engagement"    ON public.video_engagement_events FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Creators view video stats"    ON public.video_engagement_events FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.creator_videos WHERE id = video_id AND creator_id = auth.uid())
);
CREATE POLICY "Admins view all engagement"   ON public.video_engagement_events FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'reviewer'))
);

-- ── Video Reactions ─────────────────────────────────────────────────────────

CREATE TABLE public.video_reactions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id        UUID NOT NULL REFERENCES public.creator_videos(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reaction_type   TEXT NOT NULL REFERENCES public.reaction_types(value),
  created_at      TIMESTAMPTZ DEFAULT now(),
  UNIQUE(video_id, user_id)
);

ALTER TABLE public.video_reactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read reactions"  ON public.video_reactions FOR SELECT USING (true);
CREATE POLICY "Users react"            ON public.video_reactions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users unreact"          ON public.video_reactions FOR DELETE USING (auth.uid() = user_id);

-- Like counter trigger
CREATE OR REPLACE FUNCTION public.handle_reaction_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.reaction_type = 'heart' THEN
    UPDATE public.creator_videos SET like_count = like_count + 1 WHERE id = NEW.video_id;
  ELSIF TG_OP = 'DELETE' AND OLD.reaction_type = 'heart' THEN
    UPDATE public.creator_videos SET like_count = like_count - 1 WHERE id = OLD.video_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_reaction_change
  AFTER INSERT OR DELETE ON public.video_reactions
  FOR EACH ROW EXECUTE FUNCTION public.handle_reaction_count();

-- ── Video Comments ──────────────────────────────────────────────────────────

CREATE TABLE public.video_comments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id    UUID NOT NULL REFERENCES public.creator_videos(id) ON DELETE CASCADE,
  author_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content     TEXT NOT NULL,
  parent_id   UUID REFERENCES public.video_comments(id) ON DELETE CASCADE,
  deleted_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_vc_video_created ON public.video_comments(video_id, created_at DESC);
CREATE INDEX idx_vc_parent        ON public.video_comments(parent_id) WHERE parent_id IS NOT NULL;

CREATE TRIGGER handle_vc_updated_at
  BEFORE UPDATE ON public.video_comments FOR EACH ROW EXECUTE PROCEDURE extensions.moddatetime(updated_at);

ALTER TABLE public.video_comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read video comments" ON public.video_comments FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "Users post comments"        ON public.video_comments FOR INSERT WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Users delete own comments"  ON public.video_comments FOR DELETE USING (auth.uid() = author_id);

-- Comment counter trigger
CREATE OR REPLACE FUNCTION public.handle_video_comment_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.creator_videos SET comment_count = comment_count + 1 WHERE id = NEW.video_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.creator_videos SET comment_count = comment_count - 1 WHERE id = OLD.video_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_video_comment_change
  AFTER INSERT OR DELETE ON public.video_comments
  FOR EACH ROW EXECUTE FUNCTION public.handle_video_comment_count();

-- ── Creator Video Reports ───────────────────────────────────────────────────

CREATE TABLE public.creator_video_reports (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id     UUID NOT NULL REFERENCES public.creator_videos(id) ON DELETE CASCADE,
  reporter_id  UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  reason       TEXT NOT NULL CHECK (reason IN (
    'inappropriate','harassment','spam','misinformation','copyright','violence','hate_speech','other'
  )),
  details       TEXT,
  status        TEXT DEFAULT 'pending' CHECK (status IN ('pending','reviewed','resolved','dismissed')),
  reviewed_by   UUID REFERENCES public.profiles(id),
  review_notes  TEXT,
  reviewed_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (video_id, reporter_id)
);

CREATE INDEX idx_cvr_video   ON public.creator_video_reports(video_id);
CREATE INDEX idx_cvr_status  ON public.creator_video_reports(status);

ALTER TABLE public.creator_video_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users report videos"       ON public.creator_video_reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);
CREATE POLICY "Users view own reports"    ON public.creator_video_reports FOR SELECT USING (reporter_id = auth.uid());
CREATE POLICY "Admins view all reports"   ON public.creator_video_reports FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'reviewer'))
);
CREATE POLICY "Admins update reports"     ON public.creator_video_reports FOR UPDATE USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'reviewer'))
);
