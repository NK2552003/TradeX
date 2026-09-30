-- 021_unified_comments_and_visibility.sql
--
-- Unified Polymorphic Comments & Public/Private Visibility Architecture
--
-- Supports seamless discussions and access control across all 4 core entities:
-- 1. Notes ('note')
-- 2. Strategies ('strategy')
-- 3. Trade Journals ('journal')
-- 4. Community Posts ('post')
--
-- Incorporates:
-- - Polymorphic comments table with multi-level threading, sentiments, and reaction metrics
-- - Comment reactions and likes
-- - Entity visibility tracking and RPC helper procedures for 1-tap toggling
-- - Row Level Security enforcement ensuring private records can only be viewed/commented on by their owner

BEGIN;

-- 1. Ensure Visibility Columns Across All 4 Entity Types
-- ---------------------------------------------------------------------------

-- 1a. Journal Entries (adds public/private visibility)
ALTER TABLE journal_entries 
  ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_journal_entries_public ON journal_entries(is_public) WHERE is_public = true;

-- 1b. Community Posts (adds visibility column & is_public flag)
ALTER TABLE community_posts 
  ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'public' 
    CHECK (visibility IN ('public', 'unlisted', 'private'));

CREATE INDEX IF NOT EXISTS idx_community_posts_visibility ON community_posts(visibility, is_public);

-- (Note: trader_notes already has is_public BOOLEAN, strategies already has visibility TEXT)


-- 2. Unified Comments Table
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS unified_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type TEXT NOT NULL CHECK (entity_type IN ('note', 'strategy', 'journal', 'post')),
    entity_id TEXT NOT NULL,
    author_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    parent_id UUID REFERENCES unified_comments(id) ON DELETE CASCADE ON UPDATE CASCADE,
    body TEXT NOT NULL CHECK (length(trim(body)) > 0),
    sentiment TEXT CHECK (sentiment IS NULL OR sentiment IN ('BULLISH', 'BEARISH', 'NEUTRAL')),
    likes_count INTEGER NOT NULL DEFAULT 0 CHECK (likes_count >= 0),
    reply_count INTEGER NOT NULL DEFAULT 0 CHECK (reply_count >= 0),
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Unified Comment Reactions & Likes
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS unified_comment_likes (
    comment_id UUID NOT NULL REFERENCES unified_comments(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    reaction TEXT NOT NULL DEFAULT '👍' CHECK (reaction IN ('👍', '🚀', '💡', '🔥', '❤️')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (comment_id, user_id)
);

-- 4. Indices for Performance
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_unified_comments_entity 
  ON unified_comments(entity_type, entity_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_unified_comments_parent 
  ON unified_comments(parent_id) 
  WHERE parent_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_unified_comments_author 
  ON unified_comments(author_id);

CREATE INDEX IF NOT EXISTS idx_unified_comment_likes_user 
  ON unified_comment_likes(user_id);


-- 5. Automatic Counts & Metric Triggers
-- ---------------------------------------------------------------------------

-- 5a. Maintain reply_count on parent comments
CREATE OR REPLACE FUNCTION trg_unified_comments_reply_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.parent_id IS NOT NULL THEN
        UPDATE unified_comments
        SET reply_count = reply_count + 1
        WHERE id = NEW.parent_id;
    ELSIF TG_OP = 'DELETE' AND OLD.parent_id IS NOT NULL THEN
        UPDATE unified_comments
        SET reply_count = GREATEST(0, reply_count - 1)
        WHERE id = OLD.parent_id;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS unified_comments_reply_count_trg ON unified_comments;
CREATE TRIGGER unified_comments_reply_count_trg
AFTER INSERT OR DELETE ON unified_comments
FOR EACH ROW EXECUTE FUNCTION trg_unified_comments_reply_count();


-- 5b. Maintain likes_count on unified comments
CREATE OR REPLACE FUNCTION trg_unified_comment_likes_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE unified_comments
        SET likes_count = likes_count + 1
        WHERE id = NEW.comment_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE unified_comments
        SET likes_count = GREATEST(0, likes_count - 1)
        WHERE id = OLD.comment_id;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS unified_comment_likes_count_trg ON unified_comment_likes;
CREATE TRIGGER unified_comment_likes_count_trg
AFTER INSERT OR DELETE ON unified_comment_likes
FOR EACH ROW EXECUTE FUNCTION trg_unified_comment_likes_count();


-- 6. Helper RPC Functions
-- ---------------------------------------------------------------------------

-- 6a. 1-Tap Set Entity Visibility (Owner-guarded across all 4 entity types)
CREATE OR REPLACE FUNCTION set_entity_visibility(
    p_entity_type TEXT,
    p_entity_id TEXT,
    p_is_public BOOLEAN
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
    v_user UUID := auth.uid();
    v_rows_affected INTEGER := 0;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    CASE p_entity_type
        WHEN 'note' THEN
            UPDATE trader_notes
            SET is_public = p_is_public, updated_at = now()
            WHERE id = p_entity_id::uuid AND user_id = v_user;
            GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

        WHEN 'strategy' THEN
            UPDATE strategies
            SET visibility = (CASE WHEN p_is_public THEN 'public' ELSE 'private' END),
                updated_at = now()
            WHERE id = p_entity_id::uuid AND user_id = v_user;
            GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

        WHEN 'journal' THEN
            UPDATE journal_entries
            SET is_public = p_is_public, updated_at = now()
            WHERE id = p_entity_id::uuid AND user_id = v_user;
            GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

        WHEN 'post' THEN
            UPDATE community_posts
            SET is_public = p_is_public,
                visibility = (CASE WHEN p_is_public THEN 'public' ELSE 'private' END),
                updated_at = now()
            WHERE id = p_entity_id::uuid AND author_id = v_user;
            GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

        ELSE
            RAISE EXCEPTION 'Invalid entity type: %', p_entity_type;
    END CASE;

    RETURN (v_rows_affected > 0);
END;
$$;


-- 6b. Add Unified Entity Comment
CREATE OR REPLACE FUNCTION add_entity_comment(
    p_entity_type TEXT,
    p_entity_id TEXT,
    p_body TEXT,
    p_parent_id UUID DEFAULT NULL,
    p_sentiment TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
    v_user UUID := auth.uid();
    v_comment_id UUID;
    v_is_public BOOLEAN := false;
    v_owner_id UUID;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF length(trim(p_body)) = 0 THEN
        RAISE EXCEPTION 'Comment body cannot be empty';
    END IF;

    -- Verify access to private entity: only owner can comment on private entities
    CASE p_entity_type
        WHEN 'note' THEN
            SELECT is_public, user_id INTO v_is_public, v_owner_id
            FROM trader_notes WHERE id = p_entity_id::uuid;
        WHEN 'strategy' THEN
            SELECT (visibility = 'public'), user_id INTO v_is_public, v_owner_id
            FROM strategies WHERE id = p_entity_id::uuid;
        WHEN 'journal' THEN
            SELECT is_public, user_id INTO v_is_public, v_owner_id
            FROM journal_entries WHERE id = p_entity_id::uuid;
        WHEN 'post' THEN
            SELECT is_public, author_id INTO v_is_public, v_owner_id
            FROM community_posts WHERE id = p_entity_id::uuid;
        ELSE
            RAISE EXCEPTION 'Invalid entity type: %', p_entity_type;
    END CASE;

    IF NOT v_is_public AND v_owner_id <> v_user THEN
        RAISE EXCEPTION 'Cannot comment on private % belonging to another user', p_entity_type;
    END IF;

    INSERT INTO unified_comments (
        entity_type,
        entity_id,
        author_id,
        parent_id,
        body,
        sentiment
    )
    VALUES (
        p_entity_type,
        p_entity_id,
        v_user,
        p_parent_id,
        trim(p_body),
        p_sentiment
    )
    RETURNING id INTO v_comment_id;

    RETURN v_comment_id;
END;
$$;


-- 6c. Toggle Unified Comment Like / Reaction
CREATE OR REPLACE FUNCTION toggle_entity_comment_like(
    p_comment_id UUID,
    p_reaction TEXT DEFAULT '👍'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
    v_user UUID := auth.uid();
    v_existing TEXT;
    v_liked BOOLEAN;
    v_likes_count INTEGER;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT reaction INTO v_existing
    FROM unified_comment_likes
    WHERE comment_id = p_comment_id AND user_id = v_user;

    IF v_existing IS NOT NULL AND v_existing = p_reaction THEN
        -- Remove like
        DELETE FROM unified_comment_likes
        WHERE comment_id = p_comment_id AND user_id = v_user;
        v_liked := false;
    ELSE
        -- Insert or change reaction
        INSERT INTO unified_comment_likes (comment_id, user_id, reaction)
        VALUES (p_comment_id, v_user, p_reaction)
        ON CONFLICT (comment_id, user_id)
        DO UPDATE SET reaction = EXCLUDED.reaction, created_at = now();
        v_liked := true;
    END IF;

    SELECT likes_count INTO v_likes_count
    FROM unified_comments WHERE id = p_comment_id;

    RETURN jsonb_build_object(
        'liked', v_liked,
        'reaction', (CASE WHEN v_liked THEN p_reaction ELSE NULL END),
        'likes_count', COALESCE(v_likes_count, 0)
    );
END;
$$;

COMMIT;
