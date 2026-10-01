-- tables.sql (Universal Link Graph)
-- Schema definition for universal bidirectional link graph edges.

CREATE TABLE IF NOT EXISTS universal_link_edges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    source_kind TEXT NOT NULL
        CHECK (source_kind IN ('note', 'journal', 'strategy', 'aiCopilot', 'communityPost', 'messageThread', 'ticker', 'trader')),
    source_id TEXT NOT NULL,
    target_kind TEXT NOT NULL
        CHECK (target_kind IN ('note', 'journal', 'strategy', 'aiCopilot', 'communityPost', 'messageThread', 'ticker', 'trader')),
    target_id TEXT NOT NULL,
    label TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, source_kind, source_id, target_kind, target_id)
);
