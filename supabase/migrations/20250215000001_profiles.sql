-- ============================================================================
-- V3 Migration 1/10: Profiles & Identity
-- ============================================================================

-- ── Profiles ─────────────────────────────────────────────────────────────────

CREATE TABLE public.profiles (
  id                        UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  username                  TEXT UNIQUE,
  first_name                TEXT,
  last_name                 TEXT,
  avatar_url                TEXT,
  role                      TEXT DEFAULT 'user' REFERENCES public.user_roles(value),
  creator_status            TEXT REFERENCES public.application_statuses(value),
  creator_verified_at       TIMESTAMPTZ,
  is_banned                 BOOLEAN DEFAULT false,
  is_suspended              BOOLEAN DEFAULT false,
  suspension_end_timestamp  TIMESTAMPTZ,
  suspension_reason         TEXT,
  ban_reason                TEXT,
  reputation_score          NUMERIC DEFAULT 0,
  is_shadowbanned           BOOLEAN DEFAULT false,
  preferences               JSONB DEFAULT '{}'::jsonb,
  onboarding_completed      BOOLEAN DEFAULT false,
  firebase_uid              TEXT UNIQUE,
  created_at                TIMESTAMPTZ DEFAULT now(),
  updated_at                TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_profiles_role ON public.profiles(role);
CREATE INDEX idx_profiles_creator_status ON public.profiles(creator_status) WHERE creator_status IS NOT NULL;

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  _username TEXT;
  _first_name TEXT;
  _last_name TEXT;
BEGIN
  -- Try multiple metadata keys: email/password signup uses 'username',
  -- Google OAuth uses 'full_name' or 'name', Apple may use 'full_name'
  _username := COALESCE(
    NEW.raw_user_meta_data->>'username',
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    split_part(NEW.email, '@', 1)
  );

  _first_name := COALESCE(
    NEW.raw_user_meta_data->>'first_name',
    split_part(COALESCE(NEW.raw_user_meta_data->>'full_name', ''), ' ', 1)
  );
  _last_name := COALESCE(
    NEW.raw_user_meta_data->>'last_name',
    NULLIF(split_part(COALESCE(NEW.raw_user_meta_data->>'full_name', ''), ' ', 2), '')
  );

  INSERT INTO public.profiles (id, username, first_name, last_name)
  VALUES (NEW.id, _username, NULLIF(_first_name, ''), _last_name);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE TRIGGER handle_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE PROCEDURE extensions.moddatetime(updated_at);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read profiles"      ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users update own profile"   ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admins update any profile"  ON public.profiles FOR UPDATE USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ── Creator Applications ─────────────────────────────────────────────────────

CREATE TABLE public.creator_applications (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  display_name   TEXT NOT NULL,
  bio            TEXT NOT NULL,
  content_intent TEXT[],
  external_links JSONB,
  status         TEXT DEFAULT 'pending' REFERENCES public.application_statuses(value),
  reviewed_by    UUID REFERENCES public.profiles(id),
  review_notes   TEXT,
  created_at     TIMESTAMPTZ DEFAULT now(),
  reviewed_at    TIMESTAMPTZ,
  CONSTRAINT unique_pending_application UNIQUE (user_id, status)
);

-- Security-definer helper to check for pending applications (avoids RLS recursion)
CREATE OR REPLACE FUNCTION public.has_pending_application(p_user_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.creator_applications
    WHERE user_id = p_user_id AND status = 'pending'
  );
$$ LANGUAGE sql SECURITY DEFINER;

CREATE INDEX idx_creator_apps_user   ON public.creator_applications(user_id);
CREATE INDEX idx_creator_apps_status ON public.creator_applications(status);

ALTER TABLE public.creator_applications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own applications"  ON public.creator_applications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users submit applications"    ON public.creator_applications FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins view all applications" ON public.creator_applications FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'reviewer'))
);
CREATE POLICY "Admins update applications"   ON public.creator_applications FOR UPDATE USING (
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'reviewer'))
);

-- ── Appeals ──────────────────────────────────────────────────────────────────

CREATE TABLE public.appeals (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  action_type     TEXT NOT NULL,
  original_reason TEXT,
  appeal_message  TEXT NOT NULL,
  status          TEXT DEFAULT 'pending' REFERENCES public.application_statuses(value),
  admin_notes     TEXT,
  created_at      TIMESTAMPTZ DEFAULT now(),
  updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER handle_appeals_updated_at
  BEFORE UPDATE ON public.appeals
  FOR EACH ROW EXECUTE PROCEDURE extensions.moddatetime(updated_at);

ALTER TABLE public.appeals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own appeals"  ON public.appeals FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users submit appeals"    ON public.appeals FOR INSERT WITH CHECK (auth.uid() = user_id);
