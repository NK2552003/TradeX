-- Query reads for Unified Comments & Visibility

-- 1. Fetch comments with author profile information and user reactions
CREATE OR REPLACE FUNCTION get_entity_comments(
    p_entity_type TEXT,
    p_entity_id TEXT
)
RETURNS TABLE (
    id UUID,
    parent_id UUID,
    author_id UUID,
    author_display_name TEXT,
    author_handle TEXT,
    author_avatar_url TEXT,
    author_role TEXT,
    author_verified BOOLEAN,
    author_win_rate NUMERIC,
    body TEXT,
    sentiment TEXT,
    likes_count INTEGER,
    reply_count INTEGER,
    is_pinned BOOLEAN,
    liked_by_me BOOLEAN,
    my_reaction TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
    SELECT 
        c.id,
        c.parent_id,
        c.author_id,
        p.display_name AS author_display_name,
        p.handle AS author_handle,
        p.avatar_url AS author_avatar_url,
        p.role::TEXT AS author_role,
        p.verified AS author_verified,
        p.win_rate AS author_win_rate,
        c.body,
        c.sentiment,
        c.likes_count,
        c.reply_count,
        c.is_pinned,
        (l.user_id IS NOT NULL) AS liked_by_me,
        l.reaction AS my_reaction,
        c.created_at
    FROM unified_comments c
    JOIN profiles p ON p.id = c.author_id
    LEFT JOIN unified_comment_likes l 
      ON l.comment_id = c.id AND l.user_id = auth.uid()
    WHERE c.entity_type = p_entity_type
      AND c.entity_id = p_entity_id
    ORDER BY c.is_pinned DESC, c.created_at ASC;
$$;
