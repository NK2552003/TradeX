-- tables.sql (Entity Ticker Links)
-- Schema definition for persistent relational ticker reference table.
--
-- Tickers undergo daily updates (quotes, corporate actions, splits, symbol changes).
-- Storing references in this dedicated table prevents desynchronization across
-- Notes, Journal, Strategies, Community Posts, and Direct Messages.

CREATE TABLE IF NOT EXISTS entity_ticker_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    entity_type TEXT NOT NULL
        CHECK (entity_type IN ('note', 'journal', 'strategy', 'community_post', 'message')),
    entity_id TEXT NOT NULL,
    ticker VARCHAR(20) NOT NULL,
    context_source TEXT NOT NULL DEFAULT 'inline', -- 'inline', 'manual', 'tag', 'setup', 'shared_ref', 'attachment'
    price_at_link NUMERIC, -- snapshot of price at the moment of linking
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, entity_type, entity_id, ticker)
);

CREATE INDEX IF NOT EXISTS idx_entity_ticker_links_ticker
    ON entity_ticker_links(ticker);

CREATE INDEX IF NOT EXISTS idx_entity_ticker_links_user
    ON entity_ticker_links(user_id);

CREATE INDEX IF NOT EXISTS idx_entity_ticker_links_entity
    ON entity_ticker_links(entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_entity_ticker_links_user_ticker
    ON entity_ticker_links(user_id, ticker);

CREATE INDEX IF NOT EXISTS idx_entity_ticker_links_created
    ON entity_ticker_links(created_at DESC);
