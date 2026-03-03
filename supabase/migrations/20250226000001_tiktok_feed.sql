-- ============================================================================
-- TikTok Feed Enhancement Migration
-- Adds: feed sessions, atomic RPCs, ranked feed function
-- Does NOT modify existing tables — only adds new capabilities
-- ============================================================================

-- ── Feed Sessions (Tracks seen videos per user to prevent duplicates) ───────

CREATE TABLE IF NOT EXISTS public.feed_sessions (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  seen_video_ids UUID[] DEFAULT '{}',
  last_cursor UUID,
  updated_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id)
);

ALTER TABLE public.feed_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own sessions"
  ON public.feed_sessions FOR ALL
  USING (auth.uid() = user_id);

-- ── Feed Ranking Index on creator_videos ─────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_creator_videos_feed
  ON public.creator_videos (status, created_at DESC, engagement_score DESC)
  WHERE status = 'approved' AND deleted_at IS NULL;

-- ── Atomic View Increment ────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.increment_video_views(p_video_id UUID)
RETURNS void AS $$
  UPDATE public.creator_videos
  SET view_count = view_count + 1
  WHERE id = p_video_id;
$$ LANGUAGE sql SECURITY DEFINER;

-- ── Atomic Like Increment ────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.increment_video_likes(p_video_id UUID)
RETURNS void AS $$
  UPDATE public.creator_videos
  SET like_count = like_count + 1
  WHERE id = p_video_id;
$$ LANGUAGE sql SECURITY DEFINER;

-- ── Atomic Like Decrement ────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.decrement_video_likes(p_video_id UUID)
RETURNS void AS $$
  UPDATE public.creator_videos
  SET like_count = GREATEST(like_count - 1, 0)
  WHERE id = p_video_id;
$$ LANGUAGE sql SECURITY DEFINER;

-- ── Append Seen Videos to Session ────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.append_seen_videos(
  p_session_id UUID,
  p_new_ids UUID[]
) RETURNS void AS $$
  UPDATE public.feed_sessions
  SET seen_video_ids = (
    SELECT array_agg(DISTINCT unnested)
    FROM unnest(seen_video_ids || p_new_ids) AS unnested
  ),
  updated_at = now()
  WHERE id = p_session_id;
$$ LANGUAGE sql SECURITY DEFINER;

-- ── Ranked Feed Function ─────────────────────────────────────────────────────
-- Returns creator_videos ranked by engagement, excluding already-seen videos.
-- Uses cursor-based pagination via p_cursor_created_at.

CREATE OR REPLACE FUNCTION public.get_ranked_feed(
  p_session_id UUID DEFAULT NULL,
  p_limit INT DEFAULT 15,
  p_cursor_created_at TIMESTAMPTZ DEFAULT NULL
) RETURNS TABLE (
  id UUID,
  creator_id UUID,
  video_url TEXT,
  thumbnail_url TEXT,
  title TEXT,
  description TEXT,
  like_count INT,
  comment_count INT,
  view_count INT,
  engagement_score DOUBLE PRECISION,
  created_at TIMESTAMPTZ,
  creator_username TEXT,
  creator_avatar_url TEXT
) AS $$
DECLARE
  v_seen_ids UUID[] := '{}';
BEGIN
  -- Load seen video IDs from session
  IF p_session_id IS NOT NULL THEN
    SELECT COALESCE(fs.seen_video_ids, '{}') INTO v_seen_ids
    FROM public.feed_sessions fs WHERE fs.id = p_session_id;
  END IF;

  RETURN QUERY
  SELECT
    v.id,
    v.creator_id,
    v.video_url,
    v.thumbnail_url,
    v.title,
    v.description,
    v.like_count,
    v.comment_count,
    v.view_count,
    v.engagement_score,
    v.created_at,
    p.username AS creator_username,
    p.avatar_url AS creator_avatar_url
  FROM public.creator_videos v
  LEFT JOIN public.profiles p ON p.id = v.creator_id
  WHERE v.status = 'approved'
    AND v.deleted_at IS NULL
    AND NOT (v.id = ANY(v_seen_ids))
    AND (p_cursor_created_at IS NULL OR v.created_at < p_cursor_created_at)
  ORDER BY
    v.engagement_score DESC,
    v.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;
