-- ============================================================================
-- V3.1 Migration 14: Creator Trust Scores + Moderation Audit
-- ============================================================================

-- ── Creator Trust Scores ────────────────────────────────────────────────────
-- Tracks creator reliability. Computed async by RPC.
-- Drives: auto-approve threshold, feed rank multiplier, report sensitivity.

CREATE TABLE public.creator_trust_scores (
  creator_id              UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  trust_score             NUMERIC(5,4) DEFAULT 0.50 CHECK (trust_score BETWEEN 0 AND 1),
  approval_rate           NUMERIC(5,4) DEFAULT 1.0,     -- approved / total uploads
  total_uploads           INT DEFAULT 0,
  total_approved          INT DEFAULT 0,
  total_rejected          INT DEFAULT 0,
  total_removed           INT DEFAULT 0,
  abuse_reports_received  INT DEFAULT 0,
  avg_completion_rate     NUMERIC(5,4) DEFAULT 0,
  auto_approve_eligible   BOOLEAN DEFAULT false,         -- Trust > 0.85 + 10 uploads
  computed_at             TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.creator_trust_scores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Creators view own trust" ON public.creator_trust_scores
  FOR SELECT USING (auth.uid() = creator_id);
CREATE POLICY "Admins view all trust" ON public.creator_trust_scores
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'reviewer'))
  );

-- ── Compute trust scores RPC ────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.compute_creator_trust_scores()
RETURNS INT AS $$
DECLARE
  v_count INT := 0;
BEGIN
  INSERT INTO public.creator_trust_scores (
    creator_id, total_uploads, total_approved, total_rejected, total_removed,
    approval_rate, abuse_reports_received, avg_completion_rate,
    trust_score, auto_approve_eligible, computed_at
  )
  SELECT
    cv.creator_id,
    COUNT(*)::int AS total_uploads,
    COUNT(*) FILTER (WHERE cv.status = 'approved')::int AS total_approved,
    COUNT(*) FILTER (WHERE cv.status = 'rejected')::int AS total_rejected,
    COUNT(*) FILTER (WHERE cv.status = 'removed')::int AS total_removed,
    CASE WHEN COUNT(*) > 0
      THEN COUNT(*) FILTER (WHERE cv.status = 'approved')::numeric / COUNT(*)
      ELSE 0
    END AS approval_rate,
    COALESCE(SUM(cv.report_count), 0)::int AS abuse_reports_received,
    COALESCE(AVG(cv.avg_completion_pct) FILTER (WHERE cv.status = 'approved'), 0) AS avg_completion_rate,
    -- trust_score formula:
    -- 50% approval rate + 30% content quality + 20% safety (inverse report rate)
    LEAST(1.0, GREATEST(0.0,
      0.50 * (CASE WHEN COUNT(*) > 0
        THEN COUNT(*) FILTER (WHERE cv.status = 'approved')::numeric / COUNT(*)
        ELSE 0 END)
      + 0.30 * COALESCE(AVG(cv.avg_completion_pct) FILTER (WHERE cv.status = 'approved'), 0)
      + 0.20 * (1.0 - LEAST(1.0,
        COALESCE(SUM(cv.report_count), 0)::numeric / GREATEST(COUNT(*), 1)
      ))
    )) AS trust_score,
    -- auto-approve if trust > 0.85 and minimum 10 uploads
    (CASE WHEN COUNT(*) >= 10
      AND COUNT(*) FILTER (WHERE cv.status = 'approved')::numeric / GREATEST(COUNT(*), 1) > 0.85
      AND COALESCE(SUM(cv.report_count), 0) < 3
      THEN true ELSE false END
    ) AS auto_approve_eligible,
    now()
  FROM public.creator_videos cv
  WHERE cv.deleted_at IS NULL
  GROUP BY cv.creator_id
  ON CONFLICT (creator_id) DO UPDATE SET
    total_uploads          = EXCLUDED.total_uploads,
    total_approved         = EXCLUDED.total_approved,
    total_rejected         = EXCLUDED.total_rejected,
    total_removed          = EXCLUDED.total_removed,
    approval_rate          = EXCLUDED.approval_rate,
    abuse_reports_received = EXCLUDED.abuse_reports_received,
    avg_completion_rate    = EXCLUDED.avg_completion_rate,
    trust_score            = EXCLUDED.trust_score,
    auto_approve_eligible  = EXCLUDED.auto_approve_eligible,
    computed_at            = now();

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Moderation Audit Log ────────────────────────────────────────────────────

CREATE TABLE public.moderation_actions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id      UUID NOT NULL REFERENCES public.profiles(id),
  target_type   TEXT NOT NULL CHECK (target_type IN ('video', 'comment', 'user', 'community_post')),
  target_id     UUID NOT NULL,
  action        TEXT NOT NULL CHECK (action IN (
    'approve', 'reject', 'remove', 'suppress', 'unsuppress',
    'ban', 'unban', 'suspend', 'unsuspend', 'warn', 'escalate'
  )),
  reason        TEXT,
  metadata      JSONB DEFAULT '{}',
  created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_ma_target    ON public.moderation_actions(target_type, target_id);
CREATE INDEX idx_ma_actor     ON public.moderation_actions(actor_id, created_at DESC);
CREATE INDEX idx_ma_created   ON public.moderation_actions(created_at DESC);

ALTER TABLE public.moderation_actions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins manage mod actions" ON public.moderation_actions FOR ALL USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'reviewer'))
);
