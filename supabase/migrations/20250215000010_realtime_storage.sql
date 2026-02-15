-- ============================================================================
-- V3 Migration 10/10: Realtime, Storage & Security Hardening
-- ============================================================================

-- ── Realtime Subscriptions ──────────────────────────────────────────────────

ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chats;
ALTER PUBLICATION supabase_realtime ADD TABLE public.community_posts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.community_comments;
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_titles;

-- ── Storage Buckets ─────────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public)
VALUES ('creator-videos', 'creator-videos', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('creator-thumbnails', 'creator-thumbnails', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Storage Policies: Creator Videos
CREATE POLICY "Creators upload videos" ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'creator-videos' AND
    auth.uid()::text = (storage.foldername(name))[1] AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'creator' AND creator_status = 'approved')
  );

CREATE POLICY "Public read videos" ON storage.objects FOR SELECT
  USING (bucket_id = 'creator-videos');

CREATE POLICY "Creators delete own videos" ON storage.objects FOR DELETE
  USING (bucket_id = 'creator-videos' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Storage Policies: Thumbnails
CREATE POLICY "Creators upload thumbnails" ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'creator-thumbnails' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Public read thumbnails" ON storage.objects FOR SELECT
  USING (bucket_id = 'creator-thumbnails');

-- Storage Policies: Avatars
CREATE POLICY "Users upload avatars" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Public read avatars" ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

CREATE POLICY "Users delete own avatars" ON storage.objects FOR DELETE
  USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- ── Ban/Suspension Write Guard ──────────────────────────────────────────────
-- Prevents banned/suspended/shadowbanned users from posting.

CREATE OR REPLACE FUNCTION public.guard_active_user()
RETURNS TRIGGER AS $$
DECLARE
  v_banned BOOLEAN; v_suspended BOOLEAN; v_shadow BOOLEAN;
BEGIN
  SELECT is_banned, is_suspended, is_shadowbanned
    INTO v_banned, v_suspended, v_shadow
    FROM public.profiles WHERE id = auth.uid();

  IF v_banned THEN RAISE EXCEPTION 'Account is banned'; END IF;
  IF v_suspended THEN RAISE EXCEPTION 'Account is suspended'; END IF;
  -- Shadowbanned users can still write, but content won't show to others (handled in read policies)
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply guard to write-heavy tables
CREATE TRIGGER guard_posts    BEFORE INSERT ON public.community_posts    FOR EACH ROW EXECUTE FUNCTION public.guard_active_user();
CREATE TRIGGER guard_comments BEFORE INSERT ON public.community_comments FOR EACH ROW EXECUTE FUNCTION public.guard_active_user();
CREATE TRIGGER guard_vc       BEFORE INSERT ON public.video_comments     FOR EACH ROW EXECUTE FUNCTION public.guard_active_user();
CREATE TRIGGER guard_react    BEFORE INSERT ON public.video_reactions    FOR EACH ROW EXECUTE FUNCTION public.guard_active_user();
CREATE TRIGGER guard_msg      BEFORE INSERT ON public.messages           FOR EACH ROW EXECUTE FUNCTION public.guard_active_user();
