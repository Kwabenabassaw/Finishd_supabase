-- ============================================================================
-- V3 Migration 9/10: Notifications & Moderation
-- ============================================================================

-- ── Notifications ───────────────────────────────────────────────────────────

CREATE TABLE public.notifications (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type          TEXT NOT NULL,
  title         TEXT,
  body          TEXT,
  image_url     TEXT,
  metadata      JSONB DEFAULT '{}'::jsonb,
  reference_id  UUID,
  reference_url TEXT,
  is_read       BOOLEAN DEFAULT false,
  created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_notif_user_read    ON public.notifications(user_id, is_read);
CREATE INDEX idx_notif_user_created ON public.notifications(user_id, created_at DESC);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own notifications"   ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users mark read"                ON public.notifications FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "System inserts notifications"   ON public.notifications FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ── Reports (Universal) ────────────────────────────────────────────────────

CREATE TABLE public.reports (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id         UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  target_id           UUID NOT NULL,
  target_type         TEXT NOT NULL REFERENCES public.report_types(value),
  reason              TEXT NOT NULL,
  additional_info     TEXT,
  content_snapshot    JSONB,
  reported_user_id    UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  severity            TEXT DEFAULT 'low',
  report_weight       NUMERIC DEFAULT 1.0,
  status              TEXT DEFAULT 'pending' REFERENCES public.report_statuses(value),
  reviewed_by         UUID REFERENCES public.profiles(id),
  review_notes        TEXT,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_reports_status ON public.reports(status);
CREATE INDEX idx_reports_target ON public.reports(target_type, target_id);
CREATE INDEX idx_reports_user   ON public.reports(reported_user_id) WHERE reported_user_id IS NOT NULL;

CREATE TRIGGER handle_reports_updated_at
  BEFORE UPDATE ON public.reports FOR EACH ROW EXECUTE PROCEDURE extensions.moddatetime(updated_at);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users submit reports"       ON public.reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);
CREATE POLICY "Users view own reports"     ON public.reports FOR SELECT USING (auth.uid() = reporter_id);
CREATE POLICY "Admins view all reports"    ON public.reports FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'reviewer'))
);
CREATE POLICY "Admins update reports"      ON public.reports FOR UPDATE USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'reviewer'))
);
