-- ============================================================================
-- V3 Migration 3/10: Social Graph (Follows, Blocks, Activities)
-- ============================================================================

-- ── Follows (Unified Social Graph) ──────────────────────────────────────────

CREATE TABLE public.follows (
  follower_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  following_id  UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (follower_id, following_id),
  CHECK (follower_id != following_id)
);

CREATE INDEX idx_follows_follower  ON public.follows(follower_id);
CREATE INDEX idx_follows_following ON public.follows(following_id);

ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read follows"  ON public.follows FOR SELECT USING (true);
CREATE POLICY "Users can follow"     ON public.follows FOR INSERT WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "Users can unfollow"   ON public.follows FOR DELETE USING (auth.uid() = follower_id);

-- ── User Blocks ─────────────────────────────────────────────────────────────

CREATE TABLE public.user_blocks (
  blocker_id  UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  blocked_id  UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id != blocked_id)
);

CREATE INDEX idx_blocks_blocker ON public.user_blocks(blocker_id);
CREATE INDEX idx_blocks_blocked ON public.user_blocks(blocked_id);

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own blocks" ON public.user_blocks FOR SELECT USING (auth.uid() = blocker_id);
CREATE POLICY "Users can block"       ON public.user_blocks FOR INSERT WITH CHECK (auth.uid() = blocker_id);
CREATE POLICY "Users can unblock"     ON public.user_blocks FOR DELETE USING (auth.uid() = blocker_id);

-- ── Activities (Friend Feed & Trending Signals) ─────────────────────────────

CREATE TABLE public.activities (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type          TEXT NOT NULL,
  reference_id  UUID,
  metadata      JSONB DEFAULT '{}'::jsonb,
  created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_activities_feed     ON public.activities(user_id, created_at DESC);
CREATE INDEX idx_activities_type_ref ON public.activities(type, reference_id);

ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read activities"       ON public.activities FOR SELECT USING (true);
CREATE POLICY "Users insert own activities"  ON public.activities FOR INSERT WITH CHECK (auth.uid() = user_id);
