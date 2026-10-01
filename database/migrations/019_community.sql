-- 019_community.sql
--
-- Social Trading Community: posts, structured trade setups, threaded comments,
-- social engagements (likes, reposts, bookmarks, follows), and community polls.
--
-- Mirrors models in lib/features/community/models/community_models.dart and
-- repository contract in lib/features/community/data/community_repository.dart.

CREATE TABLE IF NOT EXISTS community_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    title TEXT NOT NULL DEFAULT '',
    body TEXT NOT NULL,
    excerpt TEXT,
    kind TEXT NOT NULL DEFAULT 'standard'
        CHECK (kind IN ('standard', 'analysis', 'playbook', 'signal', 'poll')),
    channel_id TEXT NOT NULL DEFAULT 'general',
    tickers TEXT[] NOT NULL DEFAULT '{}',
    tags TEXT[] NOT NULL DEFAULT '{}',
    views_count INTEGER NOT NULL DEFAULT 0 CHECK (views_count >= 0),
    likes_count INTEGER NOT NULL DEFAULT 0 CHECK (likes_count >= 0),
    comments_count INTEGER NOT NULL DEFAULT 0 CHECK (comments_count >= 0),
    reposts_count INTEGER NOT NULL DEFAULT 0 CHECK (reposts_count >= 0),
    bookmarks_count INTEGER NOT NULL DEFAULT 0 CHECK (bookmarks_count >= 0),
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    is_featured BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS community_post_trade_setups (
    post_id UUID PRIMARY KEY REFERENCES community_posts(id) ON DELETE CASCADE ON UPDATE CASCADE,
    ticker TEXT NOT NULL,
    side TEXT NOT NULL CHECK (side IN ('long', 'short')),
    entry NUMERIC(16, 4) NOT NULL,
    stop_loss NUMERIC(16, 4) NOT NULL,
    target1 NUMERIC(16, 4) NOT NULL,
    target2 NUMERIC(16, 4),
    timeframe TEXT NOT NULL DEFAULT '15m',
    chart_url TEXT
);

CREATE TABLE IF NOT EXISTS community_post_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE ON UPDATE CASCADE,
    kind TEXT NOT NULL,
    ref_id TEXT NOT NULL,
    title TEXT NOT NULL,
    url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS community_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE ON UPDATE CASCADE,
    author_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    parent_id UUID REFERENCES community_comments(id) ON DELETE CASCADE ON UPDATE CASCADE,
    body TEXT NOT NULL,
    likes_count INTEGER NOT NULL DEFAULT 0 CHECK (likes_count >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS community_likes (
    post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS community_bookmarks (
    post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS community_reposts (
    post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    commentary TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS community_follows (
    follower_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    following_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (follower_id, following_id),
    CHECK (follower_id <> following_id)
);

CREATE TABLE IF NOT EXISTS community_polls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID UNIQUE NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE ON UPDATE CASCADE,
    question TEXT NOT NULL,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS community_poll_options (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id UUID NOT NULL REFERENCES community_polls(id) ON DELETE CASCADE ON UPDATE CASCADE,
    option_text TEXT NOT NULL,
    votes_count INTEGER NOT NULL DEFAULT 0 CHECK (votes_count >= 0)
);

CREATE TABLE IF NOT EXISTS community_poll_votes (
    poll_id UUID NOT NULL REFERENCES community_polls(id) ON DELETE CASCADE ON UPDATE CASCADE,
    option_id UUID NOT NULL REFERENCES community_poll_options(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (poll_id, user_id)
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_community_posts_channel_created ON community_posts(channel_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_posts_author ON community_posts(author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_posts_tickers ON community_posts USING GIN(tickers);
CREATE INDEX IF NOT EXISTS idx_community_posts_tags ON community_posts USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_community_comments_post_created ON community_comments(post_id, created_at ASC);

-- Automated Trigger Functions to Keep Counters Consistent
CREATE OR REPLACE FUNCTION update_community_post_likes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE community_posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE community_posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_community_post_likes ON community_likes;
CREATE TRIGGER trigger_community_post_likes
    AFTER INSERT OR DELETE ON community_likes
    FOR EACH ROW EXECUTE FUNCTION update_community_post_likes();

CREATE OR REPLACE FUNCTION update_community_post_comments()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE community_posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE community_posts SET comments_count = GREATEST(0, comments_count - 1) WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_community_post_comments ON community_comments;
CREATE TRIGGER trigger_community_post_comments
    AFTER INSERT OR DELETE ON community_comments
    FOR EACH ROW EXECUTE FUNCTION update_community_post_comments();

-- Enable Row Level Security (RLS)
ALTER TABLE community_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_post_trade_setups ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_post_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_reposts ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_poll_votes ENABLE ROW LEVEL SECURITY;

-- Standard Public Reads, Authenticated Mutations
CREATE POLICY "Public read for community posts"
    ON community_posts FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Authors manage own posts"
    ON community_posts FOR ALL
    USING (auth.uid() = author_id)
    WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Public read for setups and attachments"
    ON community_post_trade_setups FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Authors manage setups"
    ON community_post_trade_setups FOR ALL
    USING (EXISTS (SELECT 1 FROM community_posts WHERE id = post_id AND author_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM community_posts WHERE id = post_id AND author_id = auth.uid()));

CREATE POLICY "Public read for post attachments"
    ON community_post_attachments FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Authors manage attachments"
    ON community_post_attachments FOR ALL
    USING (EXISTS (SELECT 1 FROM community_posts WHERE id = post_id AND author_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM community_posts WHERE id = post_id AND author_id = auth.uid()));

CREATE POLICY "Public read for comments"
    ON community_comments FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Users can create comments"
    ON community_comments FOR INSERT
    WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Authors manage own comments"
    ON community_comments FOR UPDATE
    USING (auth.uid() = author_id);

CREATE POLICY "Authors delete own comments"
    ON community_comments FOR DELETE
    USING (auth.uid() = author_id);

CREATE POLICY "Users manage own likes"
    ON community_likes FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users manage own bookmarks"
    ON community_bookmarks FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users manage own reposts"
    ON community_reposts FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users manage own follows"
    ON community_follows FOR ALL
    USING (auth.uid() = follower_id)
    WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Public read for polls"
    ON community_polls FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Public read for poll options"
    ON community_poll_options FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Users manage own poll votes"
    ON community_poll_votes FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
