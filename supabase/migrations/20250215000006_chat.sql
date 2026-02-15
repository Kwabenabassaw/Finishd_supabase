-- ============================================================================
-- V3 Migration 6/10: Chat System
-- ============================================================================

-- ── Chats ────────────────────────────────────────────────────────────────────

CREATE TABLE public.chats (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  is_group      BOOLEAN DEFAULT false,
  group_name    TEXT,
  last_message  TEXT,
  last_message_at TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER handle_chats_updated_at
  BEFORE UPDATE ON public.chats FOR EACH ROW EXECUTE PROCEDURE extensions.moddatetime(updated_at);

-- ── Chat Participants ───────────────────────────────────────────────────────

CREATE TABLE public.chat_participants (
  chat_id       UUID NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  unread_count  INT DEFAULT 0,
  last_read_at  TIMESTAMPTZ,
  joined_at     TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (chat_id, user_id)
);

CREATE INDEX idx_cp_user ON public.chat_participants(user_id);

-- ── Messages (Partitioned by Month) ─────────────────────────────────────────

CREATE TABLE public.messages (
  id          UUID DEFAULT gen_random_uuid(),
  chat_id     UUID NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  sender_id   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  type        TEXT DEFAULT 'text' REFERENCES public.message_types(value),
  content     TEXT,
  media_url   TEXT,
  metadata    JSONB DEFAULT '{}'::jsonb,
  deleted_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE public.msg_default PARTITION OF public.messages DEFAULT;
CREATE TABLE public.msg_2025_02 PARTITION OF public.messages
  FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE public.msg_2025_03 PARTITION OF public.messages
  FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE public.msg_2025_04 PARTITION OF public.messages
  FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');

CREATE INDEX idx_msg_chat_created ON public.messages(chat_id, created_at DESC);
CREATE INDEX idx_msg_sender       ON public.messages(sender_id);

-- ── Chat Helper Function ────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.is_chat_participant(p_chat_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.chat_participants WHERE chat_id = p_chat_id AND user_id = auth.uid()
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- ── Chat RLS ────────────────────────────────────────────────────────────────

ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Participants view chats" ON public.chats FOR SELECT
  USING (public.is_chat_participant(id));

ALTER TABLE public.chat_participants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Participants view participants" ON public.chat_participants FOR SELECT
  USING (public.is_chat_participant(chat_id));
CREATE POLICY "Users manage own participation" ON public.chat_participants FOR ALL
  USING (auth.uid() = user_id);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Participants read messages" ON public.messages FOR SELECT
  USING (public.is_chat_participant(chat_id) AND deleted_at IS NULL);
CREATE POLICY "Participants send messages" ON public.messages FOR INSERT
  WITH CHECK (public.is_chat_participant(chat_id) AND auth.uid() = sender_id);
