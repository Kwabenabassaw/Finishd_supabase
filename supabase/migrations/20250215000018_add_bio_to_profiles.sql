-- ============================================================================
-- V3 Migration 18/10: Add Bio and Description to Profiles
-- ============================================================================

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS bio TEXT,
ADD COLUMN IF NOT EXISTS description TEXT;
