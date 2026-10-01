-- Tables for Unified Comments & Visibility (from migration 021)

-- 1. Updates to existing tables
ALTER TABLE journal_entries 
  ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE community_posts 
  ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'public' 
    CHECK (visibility IN ('public', 'unlisted', 'private'));

-- 2. Unified Comments
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

-- 3. Unified Comment Likes & Reactions
CREATE TABLE IF NOT EXISTS unified_comment_likes (
    comment_id UUID NOT NULL REFERENCES unified_comments(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    reaction TEXT NOT NULL DEFAULT '👍' CHECK (reaction IN ('👍', '🚀', '💡', '🔥', '❤️')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (comment_id, user_id)
);
