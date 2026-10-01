BEGIN;
-- Preserve Yahoo counts, nested index/sector payloads and fields in the exact
-- asset contract. Normalized screener_results remain the ranked query interface.
CREATE TABLE IF NOT EXISTS market_screener_snapshots (
    category_id INTEGER PRIMARY KEY REFERENCES screener_categories(id) ON DELETE CASCADE,
    payload JSONB NOT NULL,
    exported_at TIMESTAMPTZ NOT NULL,
    CHECK (jsonb_typeof(payload) IN ('object', 'array'))
);
ALTER TABLE market_screener_snapshots ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS market_screener_snapshots_read ON market_screener_snapshots;
CREATE POLICY market_screener_snapshots_read ON market_screener_snapshots
    FOR SELECT TO authenticated USING (true);
GRANT SELECT ON market_screener_snapshots TO authenticated;
COMMIT;
