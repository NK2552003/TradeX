-- rls_policies.sql (Entity Ticker Links)
-- Row Level Security policies for entity_ticker_links table.

ALTER TABLE entity_ticker_links ENABLE ROW LEVEL SECURITY;

-- Select: authenticated users can read their own links or public community links
DROP POLICY IF EXISTS entity_ticker_links_select ON entity_ticker_links;
CREATE POLICY entity_ticker_links_select ON entity_ticker_links
    FOR SELECT TO authenticated
    USING (
        auth.uid() = user_id
        OR entity_type = 'community_post'
    );

-- Insert: users can only write links for their own account
DROP POLICY IF EXISTS entity_ticker_links_insert ON entity_ticker_links;
CREATE POLICY entity_ticker_links_insert ON entity_ticker_links
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- Update: users can only update their own links
DROP POLICY IF EXISTS entity_ticker_links_update ON entity_ticker_links;
CREATE POLICY entity_ticker_links_update ON entity_ticker_links
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Delete: users can only remove their own links
DROP POLICY IF EXISTS entity_ticker_links_delete ON entity_ticker_links;
CREATE POLICY entity_ticker_links_delete ON entity_ticker_links
    FOR DELETE TO authenticated
    USING (auth.uid() = user_id);
