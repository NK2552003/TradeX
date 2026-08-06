-- Replace these UUIDs with real auth.users IDs before executing.
-- This seed is optional and meant only for local demo/testing.

-- INSERT INTO profiles (id, handle, experience_level, trading_style, public_journals, subscription_tier)
-- VALUES
--   ('00000000-0000-0000-0000-000000000001', 'demo_trader', 'intermediate', 'swing', true, 'premium')
-- ON CONFLICT (id) DO NOTHING;

-- INSERT INTO watchlists (user_id, name)
-- VALUES
--   ('00000000-0000-0000-0000-000000000001', 'Growth')
-- ON CONFLICT (user_id, name) DO NOTHING;

-- INSERT INTO watchlist_items (watchlist_id, ticker, category, price_alert_threshold, price_alert_direction)
-- SELECT w.id, 'AAPL', 'earnings', 230, 'above'
-- FROM watchlists w
-- WHERE w.user_id = '00000000-0000-0000-0000-000000000001'::uuid AND w.name = 'Growth';
