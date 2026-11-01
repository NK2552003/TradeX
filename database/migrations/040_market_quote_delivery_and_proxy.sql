-- Migration 040: Market Quote Delivery, Proxy, and Freshness Contracts
-- Replaces client-side scraping with authenticated backend quote delivery,
-- establishes explicit freshness tiers (live, cached, snapshot), and configures
-- canonical table access permissions.

BEGIN;

-- 1. Ensure canonical market tables have explicit read grants for authenticated and anonymous users
DO $$
DECLARE
  tbl text;
  market_tables text[] := ARRAY[
    'tickers',
    'stock_quotes',
    'stock_fundamentals',
    'stock_price_history',
    'news_articles',
    'news_article_tickers',
    'news_topics',
    'news_article_topics',
    'screener_categories',
    'screener_results',
    'market_screener_snapshots',
    'stock_details'
  ];
BEGIN
  FOREACH tbl IN ARRAY market_tables LOOP
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = tbl) THEN
      EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', tbl);
      EXECUTE format('DROP POLICY IF EXISTS %I_public_read ON %I;', tbl, tbl);
      EXECUTE format('CREATE POLICY %I_public_read ON %I FOR SELECT USING (true);', tbl, tbl);
      EXECUTE format('GRANT SELECT ON %I TO anon, authenticated;', tbl);
    END IF;
  END LOOP;
END $$;

-- 2. Audit table for server-side quote proxy requests and rate limits
CREATE TABLE IF NOT EXISTS quote_proxy_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    action VARCHAR(20) NOT NULL DEFAULT 'quotes',
    symbols TEXT[] NOT NULL,
    freshness VARCHAR(20) NOT NULL DEFAULT 'live',
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE quote_proxy_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS quote_proxy_requests_owner ON quote_proxy_requests;
CREATE POLICY quote_proxy_requests_owner ON quote_proxy_requests
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

GRANT SELECT, INSERT ON quote_proxy_requests TO authenticated;
GRANT SELECT ON quote_proxy_requests TO anon;

COMMENT ON TABLE quote_proxy_requests IS 'Audit trail for authenticated backend market quote proxy requests.';

COMMIT;

