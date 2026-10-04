-- reads.sql (Entity Ticker Links)
-- Queries for retrieving entity ticker associations and backlink indices.

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

CREATE OR REPLACE FUNCTION get_entity_ticker_links_for_entity(
    p_entity_type TEXT,
    p_entity_id TEXT
)
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
    WHERE l.entity_type = p_entity_type
      AND l.entity_id = p_entity_id
      AND (l.user_id = auth.uid() OR l.entity_type = 'community_post')
    ORDER BY l.created_at ASC;
$$;
