-- ============================================================================
-- V3.4 Migration 22: Moderation RPCs
-- ============================================================================

-- ── Freeze Community (Supersedes 'suspend' logic if implemented elsewhere) ──

CREATE OR REPLACE FUNCTION public.freeze_community(p_community_id BIGINT, p_reason TEXT)
RETURNS VOID AS $$
BEGIN
  -- Verify caller is admin
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  UPDATE public.communities
  SET status = 'suspended'
  WHERE id = p_community_id;

  -- Log action
  INSERT INTO public.moderation_actions (actor_id, target_type, target_id, action, reason)
  VALUES (auth.uid(), 'community', p_community_id::text::uuid, 'suspend', p_reason); 
  -- Note: target_id is UUID in moderation_actions, but community IDs are BIGINT.
  -- To fix this properly, we should update moderation_actions to support mixed IDs or store community ID as string in metadata.
  -- For now, we cast to UUID if possible, but BIGINT won't cast to UUID directly.
  -- BETTER APPROACH: Modify moderation_actions schema or store ID in metadata.
  -- Since schema change is expensive now, let's store it in metadata and use a zero-UUID or similar for target_id if type is community.
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ── Correcting the ID mismatch issue ────────────────────────────────────────

-- The moderation_actions table uses UUID for target_id.
-- Communities use BIGINT.
-- We must ALTER moderation_actions to allow NULL target_id if we want to support non-UUID targets,
-- OR add a `target_id_int` column.

ALTER TABLE public.moderation_actions ADD COLUMN IF NOT EXISTS target_id_int BIGINT;
ALTER TABLE public.moderation_actions ALTER COLUMN target_id DROP NOT NULL;

-- Now the function again with correct logic:

CREATE OR REPLACE FUNCTION public.freeze_community(p_community_id BIGINT, p_reason TEXT)
RETURNS VOID AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  UPDATE public.communities
  SET status = 'suspended'
  WHERE id = p_community_id;

  INSERT INTO public.moderation_actions (actor_id, target_type, target_id_int, action, reason)
  VALUES (auth.uid(), 'community', p_community_id, 'suspend', p_reason);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ── Resolve Report RPC ──────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.resolve_report(
  p_report_id UUID,
  p_action TEXT, -- 'resolved', 'dismissed'
  p_notes TEXT
)
RETURNS VOID AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'reviewer')) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  UPDATE public.reports
  SET status = p_action,
      reviewed_by = auth.uid(),
      review_notes = p_notes,
      updated_at = now()
  WHERE id = p_report_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
