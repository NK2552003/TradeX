-- RLS Policies for Unified Comments & Visibility

ALTER TABLE unified_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE unified_comment_likes ENABLE ROW LEVEL SECURITY;

-- 1. Read Policy for Unified Comments
-- Anyone authenticated/anon can read comments on public entities.
-- On private entities, only the owner can read.
DROP POLICY IF EXISTS unified_comments_select ON unified_comments;
CREATE POLICY unified_comments_select ON unified_comments FOR SELECT TO authenticated, anon USING (
    CASE entity_type
        WHEN 'note' THEN
            EXISTS (SELECT 1 FROM trader_notes WHERE id = entity_id::uuid AND (is_public = true OR user_id = auth.uid()))
        WHEN 'strategy' THEN
            EXISTS (SELECT 1 FROM strategies WHERE id = entity_id::uuid AND (visibility = 'public' OR user_id = auth.uid()))
        WHEN 'journal' THEN
            EXISTS (SELECT 1 FROM journal_entries WHERE id = entity_id::uuid AND (is_public = true OR user_id = auth.uid()))
        WHEN 'post' THEN
            EXISTS (SELECT 1 FROM community_posts WHERE id = entity_id::uuid AND (is_public = true OR author_id = auth.uid()))
        ELSE false
    END
);

-- 2. Insert Policy for Unified Comments
-- Authenticated users can insert comments on public entities or on their own private entities.
DROP POLICY IF EXISTS unified_comments_insert ON unified_comments;
CREATE POLICY unified_comments_insert ON unified_comments FOR INSERT TO authenticated WITH CHECK (
    auth.uid() = author_id AND (
        CASE entity_type
            WHEN 'note' THEN
                EXISTS (SELECT 1 FROM trader_notes WHERE id = entity_id::uuid AND (is_public = true OR user_id = auth.uid()))
            WHEN 'strategy' THEN
                EXISTS (SELECT 1 FROM strategies WHERE id = entity_id::uuid AND (visibility = 'public' OR user_id = auth.uid()))
            WHEN 'journal' THEN
                EXISTS (SELECT 1 FROM journal_entries WHERE id = entity_id::uuid AND (is_public = true OR user_id = auth.uid()))
            WHEN 'post' THEN
                EXISTS (SELECT 1 FROM community_posts WHERE id = entity_id::uuid AND (is_public = true OR author_id = auth.uid()))
            ELSE false
        END
    )
);

-- 3. Manage Policy for Unified Comments (Update / Delete)
-- Author or superadmin can modify or delete comment.
DROP POLICY IF EXISTS unified_comments_manage ON unified_comments;
CREATE POLICY unified_comments_manage ON unified_comments FOR ALL TO authenticated
    USING (auth.uid() = author_id)
    WITH CHECK (auth.uid() = author_id);

-- 4. Unified Comment Likes Manage
DROP POLICY IF EXISTS unified_comment_likes_manage ON unified_comment_likes;
CREATE POLICY unified_comment_likes_manage ON unified_comment_likes FOR ALL TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
