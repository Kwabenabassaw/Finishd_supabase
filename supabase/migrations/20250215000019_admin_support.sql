-- ============================================================================
-- V3.2 Migration 19: Admin Panel Support & Missing Schema Elements
-- ============================================================================

-- ── Admin Settings ──────────────────────────────────────────────────────────

CREATE TABLE public.admin_settings (
  key         TEXT PRIMARY KEY,
  value       JSONB NOT NULL,
  updated_at  TIMESTAMPTZ DEFAULT now(),
  updated_by  UUID REFERENCES public.profiles(id)
);

ALTER TABLE public.admin_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins manage settings" ON public.admin_settings FOR ALL USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Seed default settings
INSERT INTO public.admin_settings (key, value) VALUES
  ('maintenance_mode', 'false'::jsonb),
  ('enable_v2_feed', 'true'::jsonb),
  ('max_upload_size_mb', '100'::jsonb),
  ('auto_moderation_enabled', 'true'::jsonb),
  ('feed_algorithm', '{"trending_weight": 0.4, "personalized_weight": 0.4, "friend_weight": 0.2, "ad_frequency": 0.1}'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- ── Communities Enhancements ────────────────────────────────────────────────

ALTER TABLE public.communities ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active' CHECK (status IN ('active', 'flagged', 'suspended'));
ALTER TABLE public.communities ADD COLUMN IF NOT EXISTS toxicity_score NUMERIC(5,2) DEFAULT 0;

-- ── Admin Dashboard Stats RPC ───────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_admin_dashboard_stats()
RETURNS JSONB AS $$
DECLARE
  v_dau INT;
  v_new_users INT;
  v_uploads INT;
  v_pending_reports INT;
BEGIN
  -- Daily Active Users (approx from daily stats)
  SELECT COUNT(DISTINCT user_id) INTO v_dau FROM public.user_daily_stats WHERE date = CURRENT_DATE;

  -- New Users Today
  SELECT COUNT(*) INTO v_new_users FROM public.profiles WHERE created_at::date = CURRENT_DATE;

  -- Videos Uploaded Today
  SELECT COUNT(*) INTO v_uploads FROM public.creator_videos WHERE created_at::date = CURRENT_DATE;

  -- Pending Reports
  SELECT COUNT(*) INTO v_pending_reports FROM public.reports WHERE status = 'pending';

  RETURN jsonb_build_object(
    'daily_active_users', COALESCE(v_dau, 0),
    'new_users_today', COALESCE(v_new_users, 0),
    'videos_uploaded_today', COALESCE(v_uploads, 0),
    'pending_reports', COALESCE(v_pending_reports, 0)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Creator Application Management RPCs ─────────────────────────────────────

CREATE OR REPLACE FUNCTION public.approve_creator_application(p_app_id UUID)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Get user_id from application
  SELECT user_id INTO v_user_id FROM public.creator_applications WHERE id = p_app_id;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Application not found';
  END IF;

  -- Update application status
  UPDATE public.creator_applications
  SET status = 'approved', reviewed_by = auth.uid(), reviewed_at = now()
  WHERE id = p_app_id;

  -- Update user profile
  UPDATE public.profiles
  SET role = 'creator', creator_status = 'approved', creator_verified_at = now()
  WHERE id = v_user_id;

  -- Log action
  INSERT INTO public.moderation_actions (actor_id, target_type, target_id, action, reason)
  VALUES (auth.uid(), 'user', v_user_id, 'approve', 'Application Approved');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.reject_creator_application(p_app_id UUID, p_reason TEXT)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID;
BEGIN
  SELECT user_id INTO v_user_id FROM public.creator_applications WHERE id = p_app_id;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Application not found';
  END IF;

  UPDATE public.creator_applications
  SET status = 'rejected', reviewed_by = auth.uid(), review_notes = p_reason, reviewed_at = now()
  WHERE id = p_app_id;

  INSERT INTO public.moderation_actions (actor_id, target_type, target_id, action, reason)
  VALUES (auth.uid(), 'user', v_user_id, 'reject', p_reason);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Admin Users Query (with Email) ──────────────────────────────────────────

-- Since we can't easily join auth.users in a view due to security restrictions,
-- we use a secure RPC to fetch user details including email for admins only.

CREATE OR REPLACE FUNCTION public.get_admin_users(
  p_page INT DEFAULT 1,
  p_limit INT DEFAULT 20,
  p_search TEXT DEFAULT ''
)
RETURNS TABLE (
  id UUID,
  username TEXT,
  email VARCHAR(255),
  role TEXT,
  status TEXT, -- Derived
  avatar_url TEXT,
  created_at TIMESTAMPTZ,
  report_count BIGINT
) AS $$
BEGIN
  -- Check if caller is admin
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'reviewer')) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.username,
    au.email,
    p.role,
    CASE
      WHEN p.is_banned THEN 'Banned'
      WHEN p.is_suspended THEN 'Suspended'
      WHEN p.is_shadowbanned THEN 'Shadowbanned'
      ELSE 'Active'
    END AS status,
    p.avatar_url,
    p.created_at,
    (SELECT COUNT(*) FROM public.reports r WHERE r.reported_user_id = p.id) AS report_count
  FROM public.profiles p
  JOIN auth.users au ON au.id = p.id
  WHERE (p_search = '' OR p.username ILIKE '%' || p_search || '%' OR au.email ILIKE '%' || p_search || '%')
  ORDER BY p.created_at DESC
  LIMIT p_limit OFFSET (p_page - 1) * p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
