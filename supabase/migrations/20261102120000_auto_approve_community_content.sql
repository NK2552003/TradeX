-- =============================================================================
-- Migration: 20261102120000_auto_approve_community_content.sql
-- Purpose:
--   1. Set default moderation_status to 'approved' for community_posts and
--      community_comments so that admin manual review is not required.
--   2. Automatically approve all existing pending or unapproved records.
--   3. Create a BEFORE INSERT/UPDATE trigger that automatically enforces
--      moderation_status = 'approved' and sets reviewed_at to now() unless
--      explicitly set to 'rejected'.
-- =============================================================================

BEGIN;

-- 1. Update columns default to 'approved'
ALTER TABLE IF EXISTS public.community_posts
  ALTER COLUMN moderation_status SET DEFAULT 'approved';

ALTER TABLE IF EXISTS public.community_comments
  ALTER COLUMN moderation_status SET DEFAULT 'approved';

-- 2. Backfill existing records to 'approved'
UPDATE public.community_posts
SET moderation_status = 'approved',
    reviewed_at = COALESCE(reviewed_at, now())
WHERE moderation_status IS NULL 
   OR moderation_status = 'pending' 
   OR moderation_status = ''
   OR moderation_status != 'rejected';

UPDATE public.community_comments
SET moderation_status = 'approved',
    reviewed_at = COALESCE(reviewed_at, now())
WHERE moderation_status IS NULL 
   OR moderation_status = 'pending' 
   OR moderation_status = ''
   OR moderation_status != 'rejected';

-- 3. Trigger function to auto-approve community content
CREATE OR REPLACE FUNCTION public.auto_approve_community_content()
RETURNS TRIGGER AS $$
BEGIN
  -- If moderation_status is not explicitly 'rejected', auto-approve
  IF NEW.moderation_status IS NULL 
     OR NEW.moderation_status = '' 
     OR NEW.moderation_status = 'pending' THEN
    NEW.moderation_status := 'approved';
  END IF;

  -- Ensure reviewed_at is populated when approved
  IF NEW.moderation_status = 'approved' AND NEW.reviewed_at IS NULL THEN
    NEW.reviewed_at := now();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Apply triggers to community_posts and community_comments
DROP TRIGGER IF EXISTS trg_auto_approve_community_posts ON public.community_posts;
CREATE TRIGGER trg_auto_approve_community_posts
  BEFORE INSERT OR UPDATE ON public.community_posts
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_approve_community_content();

DROP TRIGGER IF EXISTS trg_auto_approve_community_comments ON public.community_comments;
CREATE TRIGGER trg_auto_approve_community_comments
  BEFORE INSERT OR UPDATE ON public.community_comments
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_approve_community_content();

COMMIT;
