-- ============================================================================
-- V3 Migration 0/10: Extensions & Lookup Tables
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS moddatetime SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_trgm     SCHEMA extensions;

-- ── Lookup Tables ────────────────────────────────────────────────────────────

CREATE TABLE public.media_types           (value TEXT PRIMARY KEY);
CREATE TABLE public.user_title_statuses   (value TEXT PRIMARY KEY);
CREATE TABLE public.reaction_types        (value TEXT PRIMARY KEY);
CREATE TABLE public.report_types          (value TEXT PRIMARY KEY);
CREATE TABLE public.report_statuses       (value TEXT PRIMARY KEY);
CREATE TABLE public.application_statuses  (value TEXT PRIMARY KEY);
CREATE TABLE public.feed_categories       (value TEXT PRIMARY KEY);
CREATE TABLE public.message_types         (value TEXT PRIMARY KEY);
CREATE TABLE public.user_roles            (value TEXT PRIMARY KEY);
CREATE TABLE public.community_roles       (value TEXT PRIMARY KEY);

-- ── Seed Data ────────────────────────────────────────────────────────────────

INSERT INTO public.media_types          VALUES ('movie'), ('tv');
INSERT INTO public.user_title_statuses  VALUES ('watchlist'), ('watching'), ('finished'), ('dropped');
INSERT INTO public.reaction_types       VALUES ('heart'), ('laugh'), ('wow'), ('sad'), ('angry');
INSERT INTO public.report_types         VALUES ('community_post'), ('community_comment'), ('chat_message'), ('video_comment'), ('user_profile'), ('creator_video');
INSERT INTO public.report_statuses      VALUES ('pending'), ('reviewed'), ('resolved'), ('ignored'), ('dismissed');
INSERT INTO public.application_statuses VALUES ('pending'), ('approved'), ('rejected'), ('suspended');
INSERT INTO public.feed_categories      VALUES ('for_you'), ('trending'), ('following');
INSERT INTO public.message_types        VALUES ('text'), ('image'), ('video'), ('video_link'), ('recommendation');
INSERT INTO public.user_roles           VALUES ('user'), ('creator'), ('reviewer'), ('admin');
INSERT INTO public.community_roles      VALUES ('member'), ('moderator'), ('admin');

-- ── RLS (public read-only) ──────────────────────────────────────────────────

DO $$ 
DECLARE t TEXT;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'media_types','user_title_statuses','reaction_types','report_types',
    'report_statuses','application_statuses','feed_categories',
    'message_types','user_roles','community_roles'
  ]) LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('CREATE POLICY "Public read %s" ON public.%I FOR SELECT USING (true)', t, t);
  END LOOP;
END $$;
