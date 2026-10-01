BEGIN;

-- Editorial catalogue: JSON matches PricingCatalogueResponse.fromJson exactly.
-- Prices live only in this published document; entitlement/payment records remain
-- in subscriptions and are never written through a public catalogue endpoint.
CREATE TABLE IF NOT EXISTS pricing_catalogues (
    id TEXT PRIMARY KEY,
    catalogue JSONB NOT NULL CHECK (
        catalogue ?& ARRAY['plans', 'categories', 'faqs', 'copy']
        AND jsonb_typeof(catalogue) = 'object'
        AND jsonb_typeof(catalogue->'plans') = 'array'
        AND jsonb_typeof(catalogue->'categories') = 'array'
        AND jsonb_typeof(catalogue->'faqs') = 'array'
        AND jsonb_typeof(catalogue->'copy') = 'object'
    ),
    published BOOLEAN NOT NULL DEFAULT false,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public_site_pages (
    id TEXT PRIMARY KEY,
    content JSONB NOT NULL CHECK (jsonb_typeof(content) = 'object'),
    published BOOLEAN NOT NULL DEFAULT false,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Retains the complete export (options, holders, recommendations, company
-- details and chart) while existing normalized quote/history/news tables remain
-- canonical. This is not a second article schema.
CREATE TABLE IF NOT EXISTS stock_details (
    ticker VARCHAR(20) PRIMARY KEY REFERENCES tickers(ticker) ON DELETE CASCADE,
    detail JSONB NOT NULL CHECK (jsonb_typeof(detail) = 'object' AND detail->>'ticker' = ticker),
    fetched_at TIMESTAMPTZ NOT NULL
);

ALTER TABLE pricing_catalogues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public_site_pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_details ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pricing_catalogues_public_read ON pricing_catalogues;
CREATE POLICY pricing_catalogues_public_read ON pricing_catalogues
    FOR SELECT TO anon, authenticated USING (published);
DROP POLICY IF EXISTS public_site_pages_public_read ON public_site_pages;
CREATE POLICY public_site_pages_public_read ON public_site_pages
    FOR SELECT TO anon, authenticated USING (published);
DROP POLICY IF EXISTS stock_details_read ON stock_details;
CREATE POLICY stock_details_read ON stock_details FOR SELECT TO authenticated USING (true);
GRANT SELECT ON pricing_catalogues, public_site_pages TO anon, authenticated;
GRANT SELECT ON stock_details TO authenticated;
-- No public write policies. Publish via trusted administration/service role.
COMMIT;
