-- ============================================================================
-- V3.3 Migration 21: Community Moderation Infrastructure
-- ============================================================================

-- ── 1. Community Media Storage ──────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public) 
VALUES ('community-media', 'community-media', true)
ON CONFLICT (id) DO NOTHING;

-- Policy: Members can upload if they are part of the community logic
-- Since we can't easily extract community_id from filename in SQL policies without strict naming conventions,
-- we'll rely on a path convention: `community_id/user_id/filename`
-- e.g., `123/550e8400-e29b/image.jpg`

CREATE POLICY "Members upload community media" ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'community-media' AND
  (storage.foldername(name))[2] = auth.uid()::text AND
  EXISTS (
    SELECT 1 FROM public.community_members 
    WHERE community_id = (storage.foldername(name))[1]::bigint
    AND user_id = auth.uid()
  )
);

CREATE POLICY "Public read community media" ON storage.objects FOR SELECT
USING (bucket_id = 'community-media');

CREATE POLICY "Users delete own community media" ON storage.objects FOR DELETE
USING (
  bucket_id = 'community-media' AND 
  (storage.foldername(name))[2] = auth.uid()::text
);

-- ── 2. User Trust Scores ────────────────────────────────────────────────────

CREATE TABLE public.user_trust_scores (
  user_id             UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  trust_score         NUMERIC(5,4) DEFAULT 1.0 CHECK (trust_score BETWEEN 0 AND 1),
  reports_received    INT DEFAULT 0,
  false_reports_made  INT DEFAULT 0,
  actions_taken       INT DEFAULT 0, -- number of moderation actions against them
  updated_at          TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.user_trust_scores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own trust" ON public.user_trust_scores FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Admins view all user trust" ON public.user_trust_scores FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'reviewer'))
);

-- ── 3. Community Post Locking & Mod Capabilities ────────────────────────────

ALTER TABLE public.community_posts ADD COLUMN IF NOT EXISTS is_locked BOOLEAN DEFAULT false;
ALTER TABLE public.community_posts ADD COLUMN IF NOT EXISTS pinned_at TIMESTAMPTZ;

-- Allow Community Moderators and Admins to update posts (e.g. hide, lock, pin)
CREATE POLICY "Mods update community posts" ON public.community_posts
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM public.community_members cm
    WHERE cm.community_id = public.community_posts.community_id
    AND cm.user_id = auth.uid()
    AND cm.role IN ('moderator', 'admin')
  )
);

-- Allow Community Moderators and Admins to delete posts (rare, usually just hide)
CREATE POLICY "Mods delete community posts" ON public.community_posts
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM public.community_members cm
    WHERE cm.community_id = public.community_posts.community_id
    AND cm.user_id = auth.uid()
    AND cm.role IN ('moderator', 'admin')
  )
);


-- ── 4. Blocked Terms (Automated Moderation) ─────────────────────────────────

CREATE TABLE public.blocked_terms (
  term        TEXT PRIMARY KEY,
  category    TEXT CHECK (category IN ('hate', 'spam', 'adult', 'violence')),
  severity    TEXT DEFAULT 'high',
  created_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.blocked_terms ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins manage blocked terms" ON public.blocked_terms FOR ALL USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Seed some basic categories (terms themselves should be managed via admin panel to avoid committing profanity to git)
INSERT INTO public.blocked_terms (term, category) VALUES 
('spam_link_placeholder', 'spam')
ON CONFLICT DO NOTHING;
