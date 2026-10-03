-- 025_entity_ticker_links.sql
--
-- Dedicated Relational Link Table for Tickers:
-- Stores persistent links whenever a market ticker is referenced across:
-- 1. Trader Notes (trader_notes)
-- 2. Trade Journal (journal_entries)
-- 3. Strategy Playbooks (strategies)
-- 4. Community Posts (community_posts / posts)
-- 5. Direct Messages (chat_messages)
--
-- Rationale:
-- Market tickers undergo daily quote refreshes, price adjustments, splits, and
-- symbol updates. Storing ticker associations in a dedicated junction/tracking
-- table guarantees that daily ticker updates do not cause irregularities,
-- broken references, or historical desynchronization.

BEGIN;

CREATE TABLE IF NOT EXISTS entity_ticker_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    entity_type TEXT NOT NULL
        CHECK (entity_type IN ('note', 'journal', 'strategy', 'community_post', 'message')),
    entity_id TEXT NOT NULL,
    ticker VARCHAR(20) NOT NULL,
    context_source TEXT NOT NULL DEFAULT 'inline', -- 'inline', 'manual', 'tag', 'setup', 'shared_ref', 'attachment'
    price_at_link NUMERIC, -- snapshot of price at the time of linking
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, entity_type, entity_id, ticker)
);

-- Fast lookup indexes
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

-- Enable Row Level Security (RLS)
ALTER TABLE entity_ticker_links ENABLE ROW LEVEL SECURITY;

-- Read policy: users can read their own links or links for public entities
DROP POLICY IF EXISTS entity_ticker_links_select ON entity_ticker_links;
CREATE POLICY entity_ticker_links_select ON entity_ticker_links
    FOR SELECT TO authenticated
    USING (
        auth.uid() = user_id
        OR entity_type = 'community_post'
    );

-- Write policies: authenticated users manage their own links
DROP POLICY IF EXISTS entity_ticker_links_insert ON entity_ticker_links;
CREATE POLICY entity_ticker_links_insert ON entity_ticker_links
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS entity_ticker_links_update ON entity_ticker_links;
CREATE POLICY entity_ticker_links_update ON entity_ticker_links
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS entity_ticker_links_delete ON entity_ticker_links;
CREATE POLICY entity_ticker_links_delete ON entity_ticker_links
    FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- Stored Function: Upsert Entity Ticker Link
CREATE OR REPLACE FUNCTION record_entity_ticker_link(
    p_entity_type TEXT,
    p_entity_id TEXT,
    p_ticker TEXT,
    p_context_source TEXT DEFAULT 'inline',
    p_price_at_link NUMERIC DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
    v_user UUID := auth.uid();
    v_ticker VARCHAR(20) := upper(trim(replace(p_ticker, '$', '')));
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF v_ticker = '' THEN
        RETURN;
    END IF;

    INSERT INTO entity_ticker_links (
        user_id, entity_type, entity_id, ticker, context_source, price_at_link, metadata, updated_at
    )
    VALUES (
        v_user, p_entity_type, p_entity_id, v_ticker, p_context_source, p_price_at_link, p_metadata, now()
    )
    ON CONFLICT (user_id, entity_type, entity_id, ticker)
    DO UPDATE SET
        context_source = EXCLUDED.context_source,
        price_at_link = COALESCE(EXCLUDED.price_at_link, entity_ticker_links.price_at_link),
        metadata = entity_ticker_links.metadata || EXCLUDED.metadata,
        updated_at = now();
END;
$$;

-- Stored Function: Delete Entity Ticker Link
CREATE OR REPLACE FUNCTION delete_entity_ticker_links(
    p_entity_type TEXT,
    p_entity_id TEXT,
    p_ticker TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
    v_user UUID := auth.uid();
    v_ticker VARCHAR(20) := upper(trim(replace(COALESCE(p_ticker, ''), '$', '')));
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF v_ticker = '' THEN
        DELETE FROM entity_ticker_links
        WHERE user_id = v_user
          AND entity_type = p_entity_type
          AND entity_id = p_entity_id;
    ELSE
        DELETE FROM entity_ticker_links
        WHERE user_id = v_user
          AND entity_type = p_entity_type
          AND entity_id = p_entity_id
          AND ticker = v_ticker;
    END IF;
END;
$$;

-- Stored Function: Query Links by Ticker
CREATE OR REPLACE FUNCTION get_entity_ticker_links_for_ticker(p_ticker TEXT)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    entity_type TEXT,
    entity_id TEXT,
    ticker VARCHAR(20),
    context_source TEXT,
    price_at_link NUMERIC,
    metadata JSONB,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
    SELECT 
        l.id,
        l.user_id,
        l.entity_type,
        l.entity_id,
        l.ticker,
        l.context_source,
        l.price_at_link,
        l.metadata,
        l.created_at,
        l.updated_at
    FROM entity_ticker_links l
    WHERE l.ticker = upper(trim(replace(p_ticker, '$', '')))
      AND (l.user_id = auth.uid() OR l.entity_type = 'community_post')
    ORDER BY l.created_at DESC;
$$;

COMMIT;
