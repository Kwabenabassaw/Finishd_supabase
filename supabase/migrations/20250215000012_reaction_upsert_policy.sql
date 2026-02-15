-- ============================================================================
-- V3.1 Migration 12: Add UPDATE policy for video_reactions (upsert support)
-- ============================================================================
-- The Dart client uses .upsert() on video_reactions, which requires
-- UPDATE permission when a row already exists (ON CONFLICT ... DO UPDATE).
-- Without this policy, upsert silently fails due to RLS denial.

CREATE POLICY "Users update own reactions" ON public.video_reactions
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
