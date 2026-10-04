-- linking.sql (Entity Ticker Links)
-- Stored procedures for idempotent link and unlink operations with market ticker preservation.

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
