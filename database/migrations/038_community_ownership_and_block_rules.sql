-- 038_community_ownership_and_block_rules.sql
--
-- Community Hardening:
-- 1. Ensure public.profiles has trading & engagement columns (win_rate, verified, counts)
-- 2. Enforce blocked-user visibility semantics on community posts & comments read policies
-- 3. Enforce server-side author ownership independently of client filters on post/comment UPDATE & DELETE
-- 4. Disallow commenting or reading comments on posts where author and viewer are blocked

BEGIN;

-- 1. Reconcile missing profile columns on public.profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS win_rate NUMERIC;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS followers_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS following_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS posts_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS verified BOOLEAN NOT NULL DEFAULT false;

-- 2. Hardened RLS policies for community_posts
ALTER TABLE community_posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read for community posts" ON community_posts;
DROP POLICY IF EXISTS "Authors manage own posts" ON community_posts;
DROP POLICY IF EXISTS community_posts_read ON community_posts;
DROP POLICY IF EXISTS community_posts_manage ON community_posts;
DROP POLICY IF EXISTS community_posts_reviewed_read ON community_posts;
DROP POLICY IF EXISTS community_posts_author_insert ON community_posts;
DROP POLICY IF EXISTS community_posts_author_update ON community_posts;
DROP POLICY IF EXISTS community_posts_author_delete ON community_posts;

-- Read policy: unauthenticated visitors see approved public posts;
-- Authenticated users see approved public posts ONLY IF not blocked by author (and not blocking author);
-- Authors always see their own posts; Admins see all posts.
CREATE POLICY community_posts_reviewed_read ON community_posts FOR SELECT
  TO anon, authenticated USING (
    (
      (moderation_status = 'approved' AND is_public = true)
      OR (auth.uid() = author_id)
      OR is_user_admin()
    )
    AND (
      auth.uid() IS NULL
      OR auth.uid() = author_id
      OR is_user_admin()
      OR NOT are_blocked(auth.uid(), author_id)
    )
  );

-- Insert policy: authenticated user can only insert post with their own author_id
CREATE POLICY community_posts_author_insert ON community_posts FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = author_id);

-- Update policy: only author or admin can update post
CREATE POLICY community_posts_author_update ON community_posts FOR UPDATE
  TO authenticated
  USING (auth.uid() = author_id OR is_user_admin())
  WITH CHECK (auth.uid() = author_id OR is_user_admin());

-- Delete policy: only author or admin can delete post
CREATE POLICY community_posts_author_delete ON community_posts FOR DELETE
  TO authenticated
  USING (auth.uid() = author_id OR is_user_admin());

-- Drop legacy permissive policies from migration 034 if present
DROP POLICY IF EXISTS community_comments_reviewed_read ON community_comments;
DROP POLICY IF EXISTS community_comments_review_update ON community_comments;
DROP POLICY IF EXISTS community_comments_review_delete ON community_comments;

-- Helper function to check if parent post author is blocked outside caller RLS
CREATE OR REPLACE FUNCTION public.is_community_post_author_blocked(p_post_id uuid, p_viewer_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.community_posts p
    WHERE p.id = p_post_id
      AND public.are_blocked(p_viewer_id, p.author_id)
  );
$$;

REVOKE ALL ON FUNCTION public.is_community_post_author_blocked(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_community_post_author_blocked(uuid, uuid) TO anon, authenticated;

-- Helper function to validate comment parent authorization outside caller RLS
-- Does not treat missing or RLS-hidden parent as permission
CREATE OR REPLACE FUNCTION public.can_comment_on_community_post(p_post_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
DECLARE
  v_author_id uuid;
  v_is_public boolean;
  v_moderation_status text;
BEGIN
  IF p_post_id IS NULL OR p_user_id IS NULL THEN
    RETURN FALSE;
  END IF;

  IF public.is_user_admin() THEN
    RETURN TRUE;
  END IF;

  -- Look up parent post outside caller RLS
  SELECT author_id, is_public, moderation_status
  INTO v_author_id, v_is_public, v_moderation_status
  FROM public.community_posts
  WHERE id = p_post_id;

  -- Missing or inaccessible parent is NOT permission
  IF v_author_id IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Parent must be approved and public, or user is the author
  IF NOT (
    (v_moderation_status = 'approved' AND v_is_public = true)
    OR v_author_id = p_user_id
  ) THEN
    RETURN FALSE;
  END IF;

  -- Block check: if either user blocked the other, comment insertion is forbidden
  IF public.are_blocked(p_user_id, v_author_id) THEN
    RETURN FALSE;
  END IF;

  RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.can_comment_on_community_post(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_comment_on_community_post(uuid, uuid) TO anon, authenticated;

-- Trigger function for comment update: permits ordinary edits if post_id is unchanged;
-- verifies destination post authorization if reparenting is attempted
CREATE OR REPLACE FUNCTION public.check_community_comment_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.post_id IS DISTINCT FROM OLD.post_id THEN
    IF NOT public.can_comment_on_community_post(NEW.post_id, auth.uid()) THEN
      RAISE EXCEPTION 'Cannot reparent comment to destination post';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.check_community_comment_update() FROM PUBLIC, anon, authenticated;

-- 3. Hardened RLS policies for community_comments
ALTER TABLE community_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read for comments" ON community_comments;
DROP POLICY IF EXISTS "Users can create comments" ON community_comments;
DROP POLICY IF EXISTS "Authors manage own comments" ON community_comments;
DROP POLICY IF EXISTS "Authors delete own comments" ON community_comments;
DROP POLICY IF EXISTS community_comments_read ON community_comments;
DROP POLICY IF EXISTS community_comments_insert ON community_comments;
DROP POLICY IF EXISTS community_comments_manage ON community_comments;
DROP POLICY IF EXISTS community_comments_author_update ON community_comments;
DROP POLICY IF EXISTS community_comments_author_delete ON community_comments;
DROP POLICY IF EXISTS community_comments_reviewed_read ON community_comments;
DROP POLICY IF EXISTS community_comments_review_update ON community_comments;
DROP POLICY IF EXISTS community_comments_review_delete ON community_comments;

CREATE POLICY community_comments_read ON community_comments FOR SELECT
  TO anon, authenticated USING (
    (
      (moderation_status = 'approved' AND EXISTS (
        SELECT 1 FROM community_posts p
        WHERE p.id = post_id
        AND p.moderation_status = 'approved'
        AND p.is_public = true
      ))
      OR author_id = auth.uid()
      OR is_user_admin()
    )
    AND (
      auth.uid() IS NULL
      OR author_id = auth.uid()
      OR is_user_admin()
      OR NOT are_blocked(auth.uid(), author_id)
    )
    AND (
      auth.uid() IS NULL
      OR is_user_admin()
      OR NOT is_community_post_author_blocked(post_id, auth.uid())
    )
  );

CREATE POLICY community_comments_author_insert ON community_comments FOR INSERT
  TO authenticated WITH CHECK (
    auth.uid() = author_id
    AND can_comment_on_community_post(post_id, auth.uid())
  );

CREATE POLICY community_comments_author_update ON community_comments FOR UPDATE
  TO authenticated
  USING (auth.uid() = author_id OR is_user_admin())
  WITH CHECK (auth.uid() = author_id OR is_user_admin());

CREATE POLICY community_comments_author_delete ON community_comments FOR DELETE
  TO authenticated
  USING (auth.uid() = author_id OR is_user_admin());

DROP TRIGGER IF EXISTS trg_check_community_comment_update ON public.community_comments;
CREATE TRIGGER trg_check_community_comment_update
BEFORE UPDATE ON public.community_comments
FOR EACH ROW EXECUTE FUNCTION public.check_community_comment_update();


COMMIT;
