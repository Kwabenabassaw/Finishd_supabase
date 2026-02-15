-- ============================================================================
-- V3 Migration 17/10: Chat RPCs (Missing Functionality)
-- ============================================================================

-- ── Create Chat RPC ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.create_chat_with_participants(
  user_a UUID,
  user_b UUID
) RETURNS UUID AS $$
DECLARE
  v_chat_id UUID;
BEGIN
  -- 1. Check if a private chat already exists between these two users
  SELECT cp1.chat_id INTO v_chat_id
  FROM public.chat_participants cp1
  JOIN public.chat_participants cp2 ON cp1.chat_id = cp2.chat_id
  JOIN public.chats c ON c.id = cp1.chat_id
  WHERE cp1.user_id = user_a
    AND cp2.user_id = user_b
    AND c.is_group = false;

  -- 2. If it exists, return it
  IF v_chat_id IS NOT NULL THEN
    RETURN v_chat_id;
  END IF;

  -- 3. If not, create a new chat
  INSERT INTO public.chats (is_group, last_message_at)
  VALUES (false, now())
  RETURNING id INTO v_chat_id;

  -- 4. Add participants
  INSERT INTO public.chat_participants (chat_id, user_id, joined_at)
  VALUES
    (v_chat_id, user_a, now()),
    (v_chat_id, user_b, now());

  RETURN v_chat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Mark Chat Read RPC ──────────────────────────────────────────────────────
-- Efficiently marks a chat as read for a user

CREATE OR REPLACE FUNCTION public.mark_chat_read(
  p_chat_id UUID
) RETURNS VOID AS $$
BEGIN
  UPDATE public.chat_participants
  SET 
    unread_count = 0,
    last_read_at = now()
  WHERE chat_id = p_chat_id
    AND user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
