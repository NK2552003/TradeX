-- alphajournal Master Demo Seed Script for Testing & Local Development
-- Populates demo profiles, journal entries, quant strategies, strategy versions, watchlists, watchlist notes, community posts/comments, chat messages, trading preferences/checklists, and affiliate partner profiles.

BEGIN;

-- 0. Ensure Demo Users Exist in auth.users & auth.identities
-- Satisfies foreign key constraints (profiles.id -> auth.users.id) in Supabase
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'users') THEN
    INSERT INTO auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at
    )
    VALUES
    (
      '00000000-0000-0000-0000-000000000000',
      '00000000-0000-0000-0000-000000000001',
      'authenticated',
      'authenticated',
      'demo@tradex.ai',
      crypt('demo123456', gen_salt('bf')),
      now(),
      '{"provider": "email", "providers": ["email"]}'::jsonb,
      '{"display_name": "Nitish Kumar", "handle": "demo_trader", "role": "customer"}'::jsonb,
      now(),
      now()
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      '00000000-0000-0000-0000-000000000002',
      'authenticated',
      'authenticated',
      'alex.vance@alphatrading.io',
      crypt('demo123456', gen_salt('bf')),
      now(),
      '{"provider": "email", "providers": ["email"]}'::jsonb,
      '{"display_name": "Alex Vance", "handle": "alex_vance", "role": "customer"}'::jsonb,
      now(),
      now()
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      '00000000-0000-0000-0000-000000000003',
      'authenticated',
      'authenticated',
      'sarah.quant@alphatrading.io',
      crypt('demo123456', gen_salt('bf')),
      now(),
      '{"provider": "email", "providers": ["email"]}'::jsonb,
      '{"display_name": "Sarah Jenkins", "handle": "sarah_quant", "role": "customer"}'::jsonb,
      now(),
      now()
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$;

-- 1. Demo User Profiles (Fallback UUIDs for local testing)
INSERT INTO profiles (
  id,
  handle,
  email,
  display_name,
  role,
  status,
  experience_level,
  trading_style,
  bio,
  location,
  website,
  avg_hold_duration,
  primary_market,
  top_strategy,
  risk_mantra,
  public_journals,
  subscription_tier
)
VALUES
(
  '00000000-0000-0000-0000-000000000001',
  'demo_trader',
  'demo@tradex.ai',
  'Nitish Kumar',
  'customer',
  'active',
  'intermediate',
  'swing',
  'Quantitative momentum trader focused on US Equities and Crypto breakouts.',
  'Mumbai, IN',
  'tradex.io/@nitish_trader',
  '45 mins',
  'Equities & Index Options',
  'ORB Breakout',
  'Focus on risk management over FOMO',
  true,
  'premium'
),
(
  '00000000-0000-0000-0000-000000000002',
  'alex_vance',
  'alex.vance@alphatrading.io',
  'Alex Vance',
  'customer',
  'active',
  'advanced',
  'scalper',
  'Prop Desk Quantitative Trader specializing in high-frequency order flow.',
  'London, UK',
  'alphatrading.io/alex',
  '15 mins',
  'Index Futures & FX Options',
  'VWAP Liquidity Sweep',
  'Cut losses quickly and let winners run',
  true,
  'pro'
),
(
  '00000000-0000-0000-0000-000000000003',
  'sarah_quant',
  'sarah.quant@alphatrading.io',
  'Sarah Jenkins',
  'customer',
  'active',
  'advanced',
  'algorithmic',
  'Quantitative researcher designing systematic volatility arbitrage models.',
  'New York, US',
  'sarahquant.dev',
  '2 hours',
  'US Tech & Volatility Indices',
  'EMA Trend Continuation',
  'Trust the backtested mathematical edge',
  true,
  'elite'
)
ON CONFLICT (id) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  experience_level = EXCLUDED.experience_level,
  trading_style = EXCLUDED.trading_style,
  bio = EXCLUDED.bio,
  location = EXCLUDED.location,
  website = EXCLUDED.website,
  avg_hold_duration = EXCLUDED.avg_hold_duration,
  primary_market = EXCLUDED.primary_market,
  top_strategy = EXCLUDED.top_strategy,
  risk_mantra = EXCLUDED.risk_mantra,
  public_journals = EXCLUDED.public_journals,
  subscription_tier = EXCLUDED.subscription_tier;

-- 2. Quant Strategies
INSERT INTO strategies (
  id,
  user_id,
  title,
  content,
  category,
  is_favorite,
  visibility,
  ai_summary
)
VALUES
(
  '11111111-1111-1111-1111-111111111111',
  '00000000-0000-0000-0000-000000000001',
  'ORB 15-Min Breakout',
  '{"timeframe": "15m", "filter": "200 EMA", "target_rr": 2.5, "summary": "Opening Range Breakout with 200 EMA trend filter and 1:2.5 risk-to-reward target."}'::jsonb,
  'Breakout',
  true,
  'public',
  'Opening Range Breakout with 200 EMA trend filter and 1:2.5 risk-to-reward target.'
),
(
  '22222222-2222-2222-2222-222222222222',
  '00000000-0000-0000-0000-000000000001',
  'VWAP Liquidity Sweep',
  '{"timeframe": "5m", "filter": "Prior Day Low", "target_rr": 2.0, "summary": "Mean reversion entry on 5-min chart following liquidity grab beneath prior day low."}'::jsonb,
  'Reversal',
  false,
  'private',
  'Mean reversion entry on 5-min chart following liquidity grab beneath prior day low.'
),
(
  '33333333-3333-3333-3333-333333333333',
  '00000000-0000-0000-0000-000000000001',
  'EMA Trend Continuation',
  '{"timeframe": "1h", "filter": "21 EMA Pullback", "target_rr": 3.0, "summary": "Pullback entry to 21 EMA during confirmed 1H uptrend."}'::jsonb,
  'Trend',
  true,
  'public',
  'Pullback entry to 21 EMA during confirmed 1H uptrend.'
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  ai_summary = EXCLUDED.ai_summary;

-- 3. Strategy Versions
INSERT INTO strategy_versions (
  id,
  strategy_id,
  version_number,
  content
)
VALUES
(
  '11111111-1111-1111-1111-000000000001',
  '11111111-1111-1111-1111-111111111111',
  1,
  '{"note": "Initial strategy release", "stop_loss_mode": "Fixed 1%"}'::jsonb
),
(
  '11111111-1111-1111-1111-000000000002',
  '11111111-1111-1111-1111-111111111111',
  2,
  '{"note": "Added 200 EMA 4-hour trend filter", "stop_loss_mode": "15m Swing Low"}'::jsonb
),
(
  '22222222-2222-2222-2222-000000000001',
  '22222222-2222-2222-2222-222222222222',
  1,
  '{"note": "Base VWAP sweep model", "target_rr": 2.0}'::jsonb
)
ON CONFLICT (strategy_id, version_number) DO UPDATE SET
  content = EXCLUDED.content;

-- 4. Journal Entries
INSERT INTO journal_entries (
  id,
  user_id,
  strategy_id,
  ticker,
  side,
  entry_price,
  exit_price,
  stop_loss,
  target,
  size,
  pnl,
  outcome,
  outcome_source,
  tags,
  content,
  psychology,
  mistakes_made,
  lessons_learned,
  is_public
)
VALUES
(
  '44444444-4444-4444-4444-444444444441',
  '00000000-0000-0000-0000-000000000001',
  '11111111-1111-1111-1111-111111111111',
  'NIFTY50',
  'LONG',
  22450.00,
  22620.00,
  22380.00,
  22650.00,
  50.00,
  8500.00,
  'win',
  'auto',
  ARRAY['Breakout', 'Momentum'],
  'Strong morning volume sweep above 22450 high. High conviction trade.',
  'Calm and disciplined. Waited for 15m candle close.',
  'None. Followed plan perfectly.',
  'Patience on breakout confirmation pays off.',
  true
),
(
  '44444444-4444-4444-4444-444444444442',
  '00000000-0000-0000-0000-000000000001',
  '22222222-2222-2222-2222-222222222222',
  'RELIANCE',
  'LONG',
  2980.00,
  2950.00,
  2950.00,
  3040.00,
  100.00,
  -3000.00,
  'loss',
  'auto',
  ARRAY['Reversal'],
  'Failed to hold VWAP support during afternoon selloff.',
  'Slightly anxious as market shifted trend.',
  'Entered slightly early before full liquidity sweep reversal candle confirmed.',
  'Wait for reversal pin bar trigger on 5m chart.',
  false
),
(
  '44444444-4444-4444-4444-444444444443',
  '00000000-0000-0000-0000-000000000001',
  '11111111-1111-1111-1111-111111111111',
  'AAPL',
  'LONG',
  220.50,
  228.00,
  218.00,
  229.00,
  200.00,
  1500.00,
  'win',
  'auto',
  ARRAY['Earnings', 'Breakout'],
  'Post-earnings momentum continuation with high volume.',
  'Confident in Tech sector strength.',
  'None.',
  'Earnings momentum can carry over multiple sessions.',
  true
),
(
  '44444444-4444-4444-4444-444444444444',
  '00000000-0000-0000-0000-000000000001',
  '33333333-3333-3333-3333-333333333333',
  'NVDA',
  'LONG',
  125.00,
  132.50,
  122.00,
  133.00,
  150.00,
  1125.00,
  'win',
  'auto',
  ARRAY['Trend', 'Tech'],
  'Bounced cleanly off 21 EMA on 1H chart with bullish engulfing candle.',
  'Highly focused on key levels.',
  'None.',
  'Trend continuation setups have high probability.',
  true
)
ON CONFLICT (id) DO UPDATE SET
  ticker = EXCLUDED.ticker,
  content = EXCLUDED.content,
  entry_price = EXCLUDED.entry_price,
  exit_price = EXCLUDED.exit_price,
  pnl = EXCLUDED.pnl,
  outcome = EXCLUDED.outcome;

-- 5. Watchlists
INSERT INTO watchlists (
  id,
  user_id,
  name
)
VALUES
(
  '55555555-5555-5555-5555-555555555551',
  '00000000-0000-0000-0000-000000000001',
  'Default Watchlist'
),
(
  '55555555-5555-5555-5555-555555555552',
  '00000000-0000-0000-0000-000000000001',
  'Options Tracker'
),
(
  '55555555-5555-5555-5555-555555555553',
  '00000000-0000-0000-0000-000000000001',
  'Crypto Favorites'
)
ON CONFLICT (user_id, name) DO NOTHING;

-- 6. Watchlist Items & Notes
INSERT INTO watchlist_items (
  id,
  watchlist_id,
  ticker,
  notes,
  category,
  price_alert_threshold,
  price_alert_direction,
  alert_armed,
  is_favorite
)
VALUES
(
  '66666666-6666-6666-6666-666666666661',
  '55555555-5555-5555-5555-555555555551',
  'RELIANCE',
  'Key resistance at 3000 level. Watch for 15m breakout candle above 2980.',
  'Energy',
  3000.00,
  'above',
  true,
  true
),
(
  '66666666-6666-6666-6666-666666666662',
  '55555555-5555-5555-5555-555555555551',
  'HDFCBANK',
  'Consolidating near 1680 support zone. Good risk-reward for swing buy.',
  'Financials',
  1650.00,
  'below',
  true,
  true
),
(
  '66666666-6666-6666-6666-666666666663',
  '55555555-5555-5555-5555-555555555551',
  'NIFTY50',
  'Major psychological resistance at 24500. Monitor institutional option chain interest.',
  'Index',
  24500.00,
  'above',
  true,
  true
),
(
  '66666666-6666-6666-6666-666666666664',
  '55555555-5555-5555-5555-555555555552',
  'TCS',
  'Q2 earnings announcement approaching. Implied volatility crush setup.',
  'IT',
  4000.00,
  'above',
  true,
  false
)
ON CONFLICT (watchlist_id, ticker) DO UPDATE SET
  notes = EXCLUDED.notes,
  price_alert_threshold = EXCLUDED.price_alert_threshold,
  price_alert_direction = EXCLUDED.price_alert_direction;

-- 7. Community Posts
INSERT INTO posts (
  id,
  user_id,
  content,
  ticker,
  content_type,
  likes_count,
  comments_count,
  views_count
)
VALUES
(
  '77777777-7777-7777-7777-777777777771',
  '00000000-0000-0000-0000-000000000001',
  'NIFTY50 breaking above 22450 with strong institutional volume. Target 22650 on 15m ORB setup.',
  'NIFTY50',
  'market_discussion',
  14,
  3,
  142
),
(
  '77777777-7777-7777-7777-777777777772',
  '00000000-0000-0000-0000-000000000002',
  'NVDA trend continuation setup on 1H chart. Bounced off 21 EMA with tight 1:3 risk reward.',
  'NVDA',
  'trade_setup',
  28,
  5,
  310
)
ON CONFLICT (id) DO UPDATE SET
  content = EXCLUDED.content,
  likes_count = EXCLUDED.likes_count,
  comments_count = EXCLUDED.comments_count;

-- 8. Post Comments
INSERT INTO comments (
  id,
  post_id,
  user_id,
  content
)
VALUES
(
  '88888888-8888-8888-8888-888888888881',
  '77777777-7777-7777-7777-777777777771',
  '00000000-0000-0000-0000-000000000002',
  'Great setup! What is your stop loss level for this NIFTY trade?'
),
(
  '88888888-8888-8888-8888-888888888882',
  '77777777-7777-7777-7777-777777777771',
  '00000000-0000-0000-0000-000000000001',
  'Stop loss set tightly below 22380 swing low.'
)
ON CONFLICT (id) DO UPDATE SET
  content = EXCLUDED.content;

-- 9. Direct Messaging & Conversations
INSERT INTO conversations (
  id,
  user_a_id,
  user_b_id,
  last_message_at
)
VALUES
(
  '99999999-9999-9999-9999-999999999991',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000002',
  now() - INTERVAL '10 minutes'
),
(
  '99999999-9999-9999-9999-999999999992',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000003',
  now() - INTERVAL '1 hour'
)
ON CONFLICT (user_a_id, user_b_id) DO UPDATE SET
  last_message_at = EXCLUDED.last_message_at;

-- 10. Chat Messages
INSERT INTO messages (
  id,
  conversation_id,
  sender_id,
  content,
  created_at
)
VALUES
(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
  '99999999-9999-9999-9999-999999999991',
  '00000000-0000-0000-0000-000000000002',
  'Hey Nitish, did you review the NIFTY breakout setup?',
  now() - INTERVAL '15 minutes'
),
(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
  '99999999-9999-9999-9999-999999999991',
  '00000000-0000-0000-0000-000000000001',
  'Yes Alex, logged at 22450. Target is 22650.',
  now() - INTERVAL '10 minutes'
),
(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3',
  '99999999-9999-9999-9999-999999999992',
  '00000000-0000-0000-0000-000000000003',
  'Hi Nitish, what timeframe filter do you recommend for VWAP sweeps?',
  now() - INTERVAL '1 hour'
)
ON CONFLICT (id) DO UPDATE SET
  content = EXCLUDED.content;

-- 11. Trader Preferences
INSERT INTO trader_preferences (
  user_id,
  default_position_size_pct,
  default_r_multiple,
  default_watchlist_symbols,
  watchlist_refresh_interval_seconds
)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  2.0,
  2.5,
  ARRAY['NIFTY50', 'BANKNIFTY', 'RELIANCE', 'TCS', 'HDFCBANK'],
  15
)
ON CONFLICT (user_id) DO UPDATE SET
  default_position_size_pct = EXCLUDED.default_position_size_pct,
  default_r_multiple = EXCLUDED.default_r_multiple;

-- 12. Trader Pre-Trade Checklists
INSERT INTO trader_checklists (
  id,
  user_id,
  label,
  description,
  done,
  sort_order
)
VALUES
(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
  '00000000-0000-0000-0000-000000000001',
  'Trend alignment verified on higher timeframe (Daily/4H)',
  'Ensure 200 EMA slope agrees with trade direction',
  true,
  0
),
(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2',
  '00000000-0000-0000-0000-000000000001',
  'Key support/resistance level identified and tested',
  'Check for volume confluence and liquidity sweep',
  true,
  1
),
(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb3',
  '00000000-0000-0000-0000-000000000001',
  'Calculated stop-loss and 1:2+ risk-to-reward ratio',
  'Max risk capped at 2% account equity',
  false,
  2
),
(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb4',
  '00000000-0000-0000-0000-000000000001',
  'High-impact economic news checked (FOMC, CPI, NFP)',
  'Avoid entering positions within 30 min of red-folder events',
  false,
  3
)
ON CONFLICT (id) DO UPDATE SET
  label = EXCLUDED.label,
  description = EXCLUDED.description,
  done = EXCLUDED.done;

-- 13. Affiliate Profiles
INSERT INTO affiliate_profiles (
  id,
  affiliate_code,
  custom_slug,
  tier,
  commission_rate,
  total_referrals,
  active_referrals,
  total_earnings,
  unpaid_balance,
  paid_earnings,
  minimum_payout_threshold,
  auto_payout_enabled,
  payout_method,
  payout_details,
  status
)
VALUES
(
  '00000000-0000-0000-0000-000000000001',
  'TRADEX-ALPHA-2026',
  'nitish_alpha',
  'gold',
  0.30,
  48,
  36,
  84500.00,
  14200.00,
  70300.00,
  2500.00,
  true,
  'upi',
  '{"payout_vpa": "nitish@okhdfcbank"}'::jsonb,
  'active'
)
ON CONFLICT (id) DO UPDATE SET
  custom_slug = EXCLUDED.custom_slug,
  commission_rate = EXCLUDED.commission_rate,
  unpaid_balance = EXCLUDED.unpaid_balance;

-- 14. Affiliate Referrals
INSERT INTO affiliate_referrals (
  id,
  affiliate_id,
  referred_user_id,
  referral_code,
  status,
  bonus_awarded
)
VALUES
(
  'cccccccc-cccc-cccc-cccc-cccccccccc11',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000002',
  'TRADEX-ALPHA-2026',
  'converted',
  50.00
),
(
  'cccccccc-cccc-cccc-cccc-cccccccccc12',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000003',
  'TRADEX-ALPHA-2026',
  'converted',
  50.00
)
ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status;

-- 15. Organizations
INSERT INTO organizations (
  id,
  name,
  slug,
  owner_id,
  settings
)
VALUES
(
  'e0000000-0000-0000-0000-000000000001',
  'alphajournal Institutional Alpha',
  'tradex-institutional-alpha',
  '00000000-0000-0000-0000-000000000001',
  '{"logo_url": null, "primary_color": "#00F0FF"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  settings = EXCLUDED.settings;

-- 16. Organization Members
INSERT INTO organization_members (
  id,
  organization_id,
  user_id,
  role
)
VALUES
(
  'e1000000-0000-0000-0000-000000000001',
  'e0000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'owner'
),
(
  'e1000000-0000-0000-0000-000000000002',
  'e0000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000002',
  'admin'
),
(
  'e1000000-0000-0000-0000-000000000003',
  'e0000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000003',
  'trader'
)
ON CONFLICT (id) DO UPDATE SET
  role = EXCLUDED.role;

-- 17. Desk Risk Policies
INSERT INTO desk_risk_policies (
  id,
  organization_id,
  admin_id,
  max_firm_drawdown_percent,
  max_position_per_trader,
  enforce_pre_trade_checklist,
  manager_approval_threshold,
  audit_logging_enabled,
  allowed_asset_classes
)
VALUES
(
  'e2000000-0000-0000-0000-000000000001',
  'e0000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  5.0,
  5000000.0,
  true,
  1000000.0,
  true,
  '{"NSE Equities","F&O Derivatives","Commodities (MCX)","Currency Pairs"}'
)
ON CONFLICT (admin_id) DO UPDATE SET
  max_firm_drawdown_percent = EXCLUDED.max_firm_drawdown_percent,
  max_position_per_trader = EXCLUDED.max_position_per_trader,
  enforce_pre_trade_checklist = EXCLUDED.enforce_pre_trade_checklist,
  manager_approval_threshold = EXCLUDED.manager_approval_threshold,
  audit_logging_enabled = EXCLUDED.audit_logging_enabled,
  allowed_asset_classes = EXCLUDED.allowed_asset_classes;

-- 18. Subscriptions
INSERT INTO subscriptions (
  user_id,
  tier,
  status,
  billing_cycle,
  renewed_at,
  expires_at
)
VALUES
(
  '00000000-0000-0000-0000-000000000001',
  'pro',
  'active',
  'monthly',
  now() - INTERVAL '10 days',
  now() + INTERVAL '20 days'
)
ON CONFLICT (user_id) DO UPDATE SET
  tier = EXCLUDED.tier,
  status = EXCLUDED.status,
  billing_cycle = EXCLUDED.billing_cycle;

-- 19. Invoices
INSERT INTO invoices (
  id,
  user_id,
  invoice_ref,
  amount,
  currency,
  status,
  pdf_url,
  line_items,
  issued_at
)
VALUES
(
  'f0000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '2026_09',
  2499.0,
  'INR',
  'paid',
  'https://tradex.ai/invoices/2026_09.pdf',
  '[{"description": "Pro Plan (Monthly subscription)", "amount": 2499.0, "quantity": 1}]'::jsonb,
  now() - INTERVAL '10 days'
),
(
  'f0000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  '2026_08',
  2499.0,
  'INR',
  'paid',
  'https://tradex.ai/invoices/2026_08.pdf',
  '[{"description": "Pro Plan (Monthly subscription)", "amount": 2499.0, "quantity": 1}]'::jsonb,
  now() - INTERVAL '40 days'
)
ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status;

-- 20. Data Export Requests
INSERT INTO data_export_requests (
  id,
  user_id,
  status,
  download_url,
  requested_at,
  completed_at,
  expires_at
)
VALUES
(
  'f1000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'ready',
  'https://tradex.ai/exports/tradex_export_usr_mock_01.zip',
  now() - INTERVAL '2 hours',
  now() - INTERVAL '1 hour',
  now() + INTERVAL '7 days'
)
ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status;

-- 21. AI Insights
INSERT INTO ai_insights (
  id,
  ticker,
  summary,
  indicators,
  generated_at
)
VALUES
(
  'a0000000-0000-0000-0000-000000000001',
  'NIFTY50',
  'Bollinger Band width on NIFTY50 daily chart hit a 6-month low. Breakout expected towards 24,600 within 3-5 sessions.',
  '{"confidence": 0.88, "sentiment_score": 0.75}'::jsonb,
  now() - INTERVAL '1 hour'
),
(
  'a0000000-0000-0000-0000-000000000002',
  'RELIANCE',
  'Large block transactions detected on RELIANCE at 2,900 support level coinciding with positive RSI divergence.',
  '{"confidence": 0.82, "sentiment_score": 0.68}'::jsonb,
  now() - INTERVAL '4 hours'
)
ON CONFLICT (id) DO UPDATE SET
  summary = EXCLUDED.summary;

-- 22. AI Insight Requests
INSERT INTO ai_insight_requests (
  id,
  user_id,
  kind,
  ticker,
  requested_at
)
VALUES
(
  'a1000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'ai_insight',
  'NIFTY50',
  now() - INTERVAL '1 hour'
)
ON CONFLICT (id) DO UPDATE SET
  kind = EXCLUDED.kind;

COMMIT;
