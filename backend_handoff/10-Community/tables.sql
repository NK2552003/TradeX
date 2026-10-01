-- tables.sql (Community)
-- Schema definitions for community posts, setups, attachments, comments, engagements, and polls.

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
