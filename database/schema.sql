BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  handle CITEXT UNIQUE NOT NULL,
  email CITEXT UNIQUE,
  display_name TEXT,
  role TEXT NOT NULL DEFAULT 'customer' CHECK (role IN ('customer', 'affiliate', 'user_admin')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'pending_approval')),
  admin_key TEXT,
  referral_code TEXT UNIQUE,
  referred_by_code TEXT,
  bio TEXT,
  avatar_url TEXT,
  experience_level TEXT,
  trading_style TEXT,
  public_journals BOOLEAN NOT NULL DEFAULT false,
  subscription_tier TEXT NOT NULL DEFAULT 'free',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS affiliate_profiles (
  id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  affiliate_code TEXT UNIQUE NOT NULL,
  tier TEXT NOT NULL DEFAULT 'standard' CHECK (tier IN ('standard', 'silver', 'gold', 'platinum')),
  commission_rate NUMERIC NOT NULL DEFAULT 0.15 CHECK (commission_rate >= 0.0 AND commission_rate <= 1.0),
  total_referrals INTEGER NOT NULL DEFAULT 0 CHECK (total_referrals >= 0),
  active_referrals INTEGER NOT NULL DEFAULT 0 CHECK (active_referrals >= 0),
  total_earnings NUMERIC NOT NULL DEFAULT 0.00 CHECK (total_earnings >= 0.0),
  unpaid_balance NUMERIC NOT NULL DEFAULT 0.00 CHECK (unpaid_balance >= 0.0),
  paid_earnings NUMERIC NOT NULL DEFAULT 0.00 CHECK (paid_earnings >= 0.0),
  payout_method TEXT CHECK (payout_method IN ('bank_transfer', 'paypal', 'stripe', 'crypto')),
  payout_details JSONB NOT NULL DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('pending', 'active', 'suspended')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS affiliate_referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  referred_user_id UUID UNIQUE NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  referral_code TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'converted' CHECK (status IN ('pending', 'converted', 'churned')),
  bonus_awarded NUMERIC NOT NULL DEFAULT 50.00 CHECK (bonus_awarded >= 0.0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS affiliate_payouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  currency TEXT NOT NULL DEFAULT 'USD',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'paid', 'failed', 'cancelled')),
  payout_method TEXT,
  transaction_reference TEXT,
  notes TEXT,
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS subscriptions (
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  tier TEXT NOT NULL DEFAULT 'free',
  status TEXT NOT NULL DEFAULT 'active',
  revenuecat_id TEXT UNIQUE,
  billing_cycle TEXT,
  renewed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  token TEXT NOT NULL,
  platform TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, token)
);

CREATE TABLE IF NOT EXISTS strategies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  title TEXT NOT NULL,
  content JSONB NOT NULL,
  category TEXT,
  is_favorite BOOLEAN NOT NULL DEFAULT false,
  visibility TEXT NOT NULL DEFAULT 'private',
  ai_summary TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS strategy_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  strategy_id UUID NOT NULL REFERENCES strategies(id) ON DELETE CASCADE ON UPDATE CASCADE,
  content JSONB NOT NULL,
  version_number INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (strategy_id, version_number)
);

CREATE TABLE IF NOT EXISTS journal_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  ticker TEXT,
  content TEXT NOT NULL,
  entry_price NUMERIC,
  exit_price NUMERIC,
  stop_loss NUMERIC,
  target NUMERIC,
  size NUMERIC,
  side TEXT,
  pnl NUMERIC,
  screenshots TEXT[] DEFAULT '{}',
  psychology TEXT,
  mistakes_made TEXT,
  lessons_learned TEXT,
  strategy_id UUID REFERENCES strategies(id) ON DELETE CASCADE ON UPDATE CASCADE,
  outcome TEXT,
  outcome_source TEXT NOT NULL DEFAULT 'auto',
  tags TEXT[] DEFAULT '{}',
  is_public BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS journal_entry_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_entry_id UUID NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE ON UPDATE CASCADE,
  target_entry_id UUID NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE ON UPDATE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (source_entry_id, target_entry_id),
  CHECK (source_entry_id <> target_entry_id)
);

CREATE TABLE IF NOT EXISTS watchlists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, name)
);

CREATE TABLE IF NOT EXISTS watchlist_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  watchlist_id UUID NOT NULL REFERENCES watchlists(id) ON DELETE CASCADE ON UPDATE CASCADE,
  ticker TEXT NOT NULL,
  notes TEXT,
  category TEXT,
  price_alert_threshold NUMERIC,
  price_alert_direction TEXT,
  alert_armed BOOLEAN NOT NULL DEFAULT true,
  alert_last_triggered_at TIMESTAMPTZ,
  is_favorite BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (watchlist_id, ticker),
  CHECK (
    (price_alert_threshold IS NULL AND price_alert_direction IS NULL)
    OR (price_alert_threshold IS NOT NULL AND price_alert_direction IN ('above', 'below'))
  )
);

CREATE TABLE IF NOT EXISTS posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  content TEXT NOT NULL,
  image_url TEXT,
  ticker TEXT,
  content_type TEXT NOT NULL DEFAULT 'market_discussion',
  likes_count INTEGER NOT NULL DEFAULT 0,
  comments_count INTEGER NOT NULL DEFAULT 0,
  views_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS post_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE ON UPDATE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  viewed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS saved_posts (
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE ON UPDATE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, post_id)
);

CREATE TABLE IF NOT EXISTS comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE ON UPDATE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS follows (
  follower_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  followee_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, followee_id),
  CHECK (follower_id <> followee_id)
);

CREATE TABLE IF NOT EXISTS likes (
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE ON UPDATE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, post_id)
);

CREATE TABLE IF NOT EXISTS ai_insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticker TEXT NOT NULL,
  summary TEXT NOT NULL,
  indicators JSONB,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ai_insight_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  kind TEXT NOT NULL DEFAULT 'ai_insight',
  ticker TEXT,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS blocks (
  blocker_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  blocked_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);

CREATE OR REPLACE FUNCTION are_blocked(user_x UUID, user_y UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM blocks
    WHERE (blocker_id = user_x AND blocked_id = user_y)
       OR (blocker_id = user_y AND blocked_id = user_x)
  );
$$;

CREATE TABLE IF NOT EXISTS conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  user_b_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  last_message_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_a_id, user_b_id),
  CHECK (user_a_id <> user_b_id)
);

CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE ON UPDATE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  content TEXT NOT NULL,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  category TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT,
  deep_link TEXT,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS revenuecat_webhook_events (
  event_id TEXT PRIMARY KEY,
  event_type TEXT NOT NULL,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE VIEW portfolio_stats AS
SELECT
  user_id,
  SUM(pnl) AS total_pnl,
  AVG(CASE WHEN pnl > 0 THEN 1.0 ELSE 0.0 END) AS win_rate,
  AVG(
    CASE
      WHEN (entry_price - stop_loss) <> 0 THEN ABS(target - entry_price) / ABS(entry_price - stop_loss)
      ELSE NULL
    END
  ) AS avg_rr,
  MIN(pnl) AS worst_trade_pnl,
  MAX(pnl) AS best_trade_pnl
FROM journal_entries
WHERE pnl IS NOT NULL
GROUP BY user_id;

CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_referral_code ON profiles(referral_code);
CREATE INDEX IF NOT EXISTS idx_affiliate_profiles_code ON affiliate_profiles(affiliate_code);
CREATE INDEX IF NOT EXISTS idx_affiliate_referrals_affiliate ON affiliate_referrals(affiliate_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_referrals_referred ON affiliate_referrals(referred_user_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_payouts_affiliate ON affiliate_payouts(affiliate_id, status);
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_created ON journal_entries(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_ticker ON journal_entries(user_id, ticker);
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_strategy ON journal_entries(user_id, strategy_id);
CREATE INDEX IF NOT EXISTS idx_journal_entries_tags_gin ON journal_entries USING GIN (tags);
CREATE INDEX IF NOT EXISTS idx_strategies_user_category ON strategies(user_id, category);
CREATE INDEX IF NOT EXISTS idx_strategies_public_visibility ON strategies(visibility) WHERE visibility = 'public';
CREATE INDEX IF NOT EXISTS idx_posts_created ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_type_created ON posts(content_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_read_created ON notifications(user_id, read_at, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_insight_requests_user_kind_requested ON ai_insight_requests(user_id, kind, requested_at);
CREATE INDEX IF NOT EXISTS idx_watchlist_items_armed_threshold ON watchlist_items(alert_armed, price_alert_threshold)
  WHERE alert_armed = true AND price_alert_threshold IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_revenuecat_id ON subscriptions(revenuecat_id);
CREATE INDEX IF NOT EXISTS idx_conversations_user_a_last_message ON conversations(user_a_id, last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_user_b_last_message ON conversations(user_b_id, last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created ON messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_blocks_blocked_id ON blocks(blocked_id);
CREATE INDEX IF NOT EXISTS idx_follows_followee_id ON follows(followee_id);
CREATE INDEX IF NOT EXISTS idx_likes_post_id ON likes(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_post_created ON comments(post_id, created_at);

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'profiles',
    'affiliate_profiles',
    'affiliate_referrals',
    'affiliate_payouts',
    'subscriptions',
    'device_tokens',
    'strategies',
    'strategy_versions',
    'journal_entries',
    'journal_entry_links',
    'watchlists',
    'watchlist_items',
    'posts',
    'saved_posts',
    'comments',
    'follows',
    'likes',
    'ai_insights',
    'ai_insight_requests',
    'blocks',
    'conversations',
    'messages',
    'notifications',
    'revenuecat_webhook_events'
  ]
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%I_updated_at ON %I;', t, t);
    EXECUTE format('CREATE TRIGGER trg_%I_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION set_updated_at();', t, t);
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  recipient_id UUID;
  sender_handle TEXT;
BEGIN
  SELECT CASE WHEN user_a_id = NEW.sender_id THEN user_b_id ELSE user_a_id END
  INTO recipient_id
  FROM conversations
  WHERE id = NEW.conversation_id;

  SELECT handle INTO sender_handle
  FROM profiles
  WHERE id = NEW.sender_id;

  INSERT INTO notifications (user_id, category, title, body, deep_link)
  VALUES (
    recipient_id,
    'direct_message',
    COALESCE(sender_handle, 'A trader') || ' sent you a message',
    LEFT(NEW.content, 100),
    '/messages/' || NEW.conversation_id
  );

  UPDATE conversations
  SET last_message_at = NEW.created_at
  WHERE id = NEW.conversation_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_new_message ON messages;
CREATE TRIGGER on_new_message
AFTER INSERT ON messages
FOR EACH ROW EXECUTE FUNCTION notify_new_message();

CREATE OR REPLACE FUNCTION public.handle_new_user_signup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_role TEXT;
  v_handle TEXT;
  v_display_name TEXT;
  v_admin_key TEXT;
  v_referral_code TEXT;
  v_referred_by_code TEXT;
  v_referrer_id UUID;
BEGIN
  v_role := COALESCE(NEW.raw_user_meta_data->>'role', 'customer');
  v_handle := COALESCE(NEW.raw_user_meta_data->>'handle', LOWER(SPLIT_PART(NEW.email, '@', 1)));
  v_display_name := COALESCE(NEW.raw_user_meta_data->>'display_name', SPLIT_PART(NEW.email, '@', 1));
  v_admin_key := NEW.raw_user_meta_data->>'admin_key';
  v_referral_code := COALESCE(NEW.raw_user_meta_data->>'referral_code', 'REF-' || UPPER(SUBSTRING(gen_random_uuid()::text FROM 1 FOR 8)));
  v_referred_by_code := NEW.raw_user_meta_data->>'referred_by_code';

  INSERT INTO public.profiles (
    id,
    handle,
    email,
    display_name,
    role,
    status,
    admin_key,
    referral_code,
    referred_by_code,
    subscription_tier
  )
  VALUES (
    NEW.id,
    v_handle,
    NEW.email,
    v_display_name,
    v_role,
    'active',
    v_admin_key,
    v_referral_code,
    v_referred_by_code,
    CASE WHEN v_role = 'user_admin' THEN 'enterprise' ELSE 'free' END
  );

  IF v_role = 'affiliate' THEN
    INSERT INTO public.affiliate_profiles (
      id,
      affiliate_code,
      tier,
      commission_rate,
      status
    )
    VALUES (
      NEW.id,
      v_referral_code,
      'standard',
      0.15,
      'active'
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;

  IF v_referred_by_code IS NOT NULL AND v_referred_by_code <> '' THEN
    SELECT id INTO v_referrer_id
    FROM public.profiles
    WHERE referral_code = v_referred_by_code OR handle = v_referred_by_code;

    IF v_referrer_id IS NOT NULL THEN
      INSERT INTO public.affiliate_referrals (
        affiliate_id,
        referred_user_id,
        referral_code,
        status,
        bonus_awarded
      )
      VALUES (
        v_referrer_id,
        NEW.id,
        v_referred_by_code,
        'converted',
        50.00
      )
      ON CONFLICT (referred_user_id) DO NOTHING;

      UPDATE public.affiliate_profiles
      SET 
        total_referrals = total_referrals + 1,
        active_referrals = active_referrals + 1,
        unpaid_balance = unpaid_balance + 50.00,
        total_earnings = total_earnings + 50.00
      WHERE id = v_referrer_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_signup();

-- Trader Preferences & Risk Checklists Table
CREATE TABLE IF NOT EXISTS public.trader_preferences (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  default_position_size_pct NUMERIC NOT NULL DEFAULT 2.0 CHECK (default_position_size_pct > 0 AND default_position_size_pct <= 100),
  default_r_multiple NUMERIC NOT NULL DEFAULT 2.5 CHECK (default_r_multiple > 0),
  default_watchlist_symbols TEXT[] NOT NULL DEFAULT '{"NIFTY50","BANKNIFTY","RELIANCE","TCS","HDFCBANK"}'::text[],
  watchlist_refresh_interval_seconds INTEGER NOT NULL DEFAULT 15 CHECK (watchlist_refresh_interval_seconds >= 1),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.trader_checklists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  label TEXT NOT NULL,
  description TEXT,
  done BOOLEAN NOT NULL DEFAULT false,
  icon_name TEXT DEFAULT 'check_box_outline_blank',
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- SOCIAL ANALYTICS COUNTERS, TRIGGERS & DEDUPLICATED VIEWS
-- ============================================================

CREATE OR REPLACE FUNCTION update_post_likes_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    UPDATE posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
  ELSIF (TG_OP = 'DELETE') THEN
    UPDATE posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_likes_count ON likes;
CREATE TRIGGER trg_likes_count
  AFTER INSERT OR DELETE ON likes
  FOR EACH ROW EXECUTE FUNCTION update_post_likes_count();

CREATE OR REPLACE FUNCTION update_post_comments_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    UPDATE posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
  ELSIF (TG_OP = 'DELETE') THEN
    UPDATE posts SET comments_count = GREATEST(0, comments_count - 1) WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_comments_count ON comments;
CREATE TRIGGER trg_comments_count
  AFTER INSERT OR DELETE ON comments
  FOR EACH ROW EXECUTE FUNCTION update_post_comments_count();

CREATE OR REPLACE FUNCTION increment_post_views(p_post_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NOT NULL THEN
    INSERT INTO post_views (post_id, user_id)
    VALUES (p_post_id, v_user_id)
    ON CONFLICT (post_id, user_id) DO NOTHING;

    IF FOUND THEN
      UPDATE posts SET views_count = views_count + 1 WHERE id = p_post_id;
    END IF;
  ELSE
    UPDATE posts SET views_count = views_count + 1 WHERE id = p_post_id;
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_posts_trending ON posts (likes_count DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_post_views_post_user ON post_views (post_id, user_id);

-- ============================================================================
-- UNIFIED MARKET DATA TABLES (Used by Market Data Python Scripts & Postgres)
-- ============================================================================

CREATE TABLE IF NOT EXISTS tickers (
    ticker      VARCHAR(20) PRIMARY KEY,
    market      VARCHAR(10),
    exchange    VARCHAR(20),
    currency    VARCHAR(5),
    asset_type  VARCHAR(20),
    name        TEXT,
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tickers_market     ON tickers(market);
CREATE INDEX IF NOT EXISTS idx_tickers_asset_type ON tickers(asset_type);

CREATE TABLE IF NOT EXISTS stock_quotes (
    ticker         VARCHAR(20) PRIMARY KEY REFERENCES tickers(ticker) ON DELETE CASCADE,
    price          DECIMAL,
    previous_close DECIMAL,
    day_high       DECIMAL,
    day_low        DECIMAL,
    volume         BIGINT,
    change_pct     DECIMAL,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stock_fundamentals (
    ticker              VARCHAR(20) PRIMARY KEY REFERENCES tickers(ticker) ON DELETE CASCADE,
    market_cap          BIGINT,
    pe_ratio            DECIMAL,
    forward_pe          DECIMAL,
    peg_ratio           DECIMAL,
    eps                 DECIMAL,
    sector              VARCHAR(50),
    industry            VARCHAR(50),
    fifty_two_week_high DECIMAL,
    fifty_two_week_low  DECIMAL,
    fifty_day_average   DECIMAL,
    two_hundred_day_average DECIMAL,
    dividend_yield      DECIMAL,
    beta                DECIMAL,
    avg_volume          BIGINT,
    shares_outstanding  BIGINT,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stock_price_history (
    id          SERIAL PRIMARY KEY,
    ticker      VARCHAR(20) NOT NULL REFERENCES tickers(ticker) ON DELETE CASCADE,
    date        DATE NOT NULL,
    open        DECIMAL,
    high        DECIMAL,
    low         DECIMAL,
    close       DECIMAL,
    volume      BIGINT,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (ticker, date)
);

CREATE INDEX IF NOT EXISTS idx_history_ticker_date ON stock_price_history(ticker, date);

CREATE TABLE IF NOT EXISTS news_articles (
    id             SERIAL PRIMARY KEY,
    title          TEXT,
    summary        TEXT,
    link           TEXT UNIQUE,
    publisher      VARCHAR(100),
    thumbnail_url  TEXT,
    content_type   VARCHAR(30),
    published_at   TIMESTAMPTZ,
    fetched_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_news_published ON news_articles(published_at DESC);

CREATE TABLE IF NOT EXISTS news_article_tickers (
    article_id  INTEGER NOT NULL REFERENCES news_articles(id) ON DELETE CASCADE,
    ticker      VARCHAR(20) NOT NULL REFERENCES tickers(ticker) ON DELETE CASCADE,
    PRIMARY KEY (article_id, ticker)
);

CREATE INDEX IF NOT EXISTS idx_article_tickers_ticker ON news_article_tickers(ticker);

CREATE TABLE IF NOT EXISTS news_topics (
    id   SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS news_article_topics (
    article_id INTEGER NOT NULL REFERENCES news_articles(id) ON DELETE CASCADE,
    topic_id   INTEGER NOT NULL REFERENCES news_topics(id) ON DELETE CASCADE,
    PRIMARY KEY (article_id, topic_id)
);

CREATE TABLE IF NOT EXISTS screener_categories (
    id            SERIAL PRIMARY KEY,
    name          VARCHAR(50) UNIQUE NOT NULL,
    category_type VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS screener_results (
    id            SERIAL PRIMARY KEY,
    category_id   INTEGER NOT NULL REFERENCES screener_categories(id) ON DELETE CASCADE,
    ticker        VARCHAR(20) NOT NULL REFERENCES tickers(ticker) ON DELETE CASCADE,
    rank          INTEGER,
    price         DECIMAL,
    change_pct    DECIMAL,
    extra_data    JSONB,
    run_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_screener_results_category ON screener_results(category_id, rank);

CREATE TABLE IF NOT EXISTS index_metadata (
    ticker    VARCHAR(20) PRIMARY KEY REFERENCES tickers(ticker) ON DELETE CASCADE,
    continent VARCHAR(30)
);

CREATE TABLE IF NOT EXISTS sector_metadata (
    ticker      VARCHAR(20) PRIMARY KEY REFERENCES tickers(ticker) ON DELETE CASCADE,
    sector_name VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS options_expirations (
    id              SERIAL PRIMARY KEY,
    ticker          VARCHAR(20) NOT NULL REFERENCES tickers(ticker) ON DELETE CASCADE,
    expiration_date DATE NOT NULL,
    fetched_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (ticker, expiration_date)
);

CREATE TABLE IF NOT EXISTS options_contracts (
    id                SERIAL PRIMARY KEY,
    expiration_id     INTEGER NOT NULL REFERENCES options_expirations(id) ON DELETE CASCADE,
    contract_type     VARCHAR(4) NOT NULL,
    strike            DECIMAL,
    last_price        DECIMAL,
    bid               DECIMAL,
    ask               DECIMAL,
    volume            BIGINT,
    open_interest     BIGINT,
    implied_volatility DECIMAL,
    in_the_money      BOOLEAN,
    contract_symbol   VARCHAR(50)
);

CREATE INDEX IF NOT EXISTS idx_options_contracts_expiration ON options_contracts(expiration_id, contract_type);

CREATE TABLE IF NOT EXISTS dividends (
    id      SERIAL PRIMARY KEY,
    ticker  VARCHAR(20) NOT NULL REFERENCES tickers(ticker) ON DELETE CASCADE,
    ex_date DATE NOT NULL,
    amount  DECIMAL,
    UNIQUE (ticker, ex_date)
);

CREATE TABLE IF NOT EXISTS stock_splits (
    id         SERIAL PRIMARY KEY,
    ticker     VARCHAR(20) NOT NULL REFERENCES tickers(ticker) ON DELETE CASCADE,
    split_date DATE NOT NULL,
    ratio      DECIMAL,
    UNIQUE (ticker, split_date)
);

CREATE TABLE IF NOT EXISTS analyst_recommendations (
    id        SERIAL PRIMARY KEY,
    ticker    VARCHAR(20) NOT NULL REFERENCES tickers(ticker) ON DELETE CASCADE,
    period    VARCHAR(10),
    strong_buy  INTEGER,
    buy         INTEGER,
    hold        INTEGER,
    sell        INTEGER,
    strong_sell INTEGER,
    fetched_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS holders (
    id          SERIAL PRIMARY KEY,
    ticker      VARCHAR(20) NOT NULL REFERENCES tickers(ticker) ON DELETE CASCADE,
    holder_type VARCHAR(20),
    holder_name TEXT,
    shares      BIGINT,
    date_reported DATE,
    pct_out     DECIMAL,
    value       BIGINT,
    fetched_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_holders_ticker ON holders(ticker, holder_type);

COMMIT;
