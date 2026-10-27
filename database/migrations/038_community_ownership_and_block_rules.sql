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

-- Read policy: approved comments on approved public posts;
-- Authenticated users cannot read comments by authors they are blocked by / blocking;
-- Cannot read comments on posts where post author and viewer are blocked.
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
      OR NOT EXISTS (
        SELECT 1 FROM community_posts p
        WHERE p.id = post_id
        AND are_blocked(auth.uid(), p.author_id)
      )
    )
  );

-- Insert policy: user creates their own comment, and cannot comment on posts of blocked authors
CREATE POLICY community_comments_author_insert ON community_comments FOR INSERT
  TO authenticated WITH CHECK (
    auth.uid() = author_id
    AND NOT EXISTS (
      SELECT 1 FROM community_posts p
      WHERE p.id = post_id
      AND are_blocked(auth.uid(), p.author_id)
    )
  );

-- Update policy: only comment author or admin can update comment
CREATE POLICY community_comments_author_update ON community_comments FOR UPDATE
  TO authenticated
  USING (auth.uid() = author_id OR is_user_admin())
  WITH CHECK (auth.uid() = author_id OR is_user_admin());

-- Delete policy: only comment author or admin can delete comment
CREATE POLICY community_comments_author_delete ON community_comments FOR DELETE
  TO authenticated
  USING (auth.uid() = author_id OR is_user_admin());

COMMIT;
