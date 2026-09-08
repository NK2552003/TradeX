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

-- A playbook is markdown, not structured data: `content` is TEXT. The
-- performance figures a playbook displays (win rate, average R, net P&L) are
-- deliberately NOT columns here — they are derived from the journal entries
-- filed under it, by the strategy_performance view below. Storing them would
-- mean every journal write has to remember to update its parent.
-- Column rationale: migrations/010_strategy_notes.sql
CREATE TABLE IF NOT EXISTS strategies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  title TEXT NOT NULL,
  summary TEXT,
  content TEXT NOT NULL DEFAULT '',
  category TEXT,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'testing', 'live', 'retired')),
  is_favorite BOOLEAN NOT NULL DEFAULT false,
  visibility TEXT NOT NULL DEFAULT 'private'
    CHECK (visibility IN ('private', 'public')),
  tags TEXT[] NOT NULL DEFAULT '{}',
  linked_tickers TEXT[] NOT NULL DEFAULT '{}',
  -- Mirrors, rebuilt by trigger from journal_entries.strategy_id and
  -- trader_notes.strategy_id. Never written by a client.
  linked_note_ids UUID[] NOT NULL DEFAULT '{}',
  linked_journal_ids UUID[] NOT NULL DEFAULT '{}',
  version_count INTEGER NOT NULL DEFAULT 1 CHECK (version_count >= 0),
  word_count INTEGER NOT NULL DEFAULT 0 CHECK (word_count >= 0),
  checklist_done INTEGER NOT NULL DEFAULT 0 CHECK (checklist_done >= 0),
  checklist_total INTEGER NOT NULL DEFAULT 0 CHECK (checklist_total >= checklist_done),
  has_images BOOLEAN NOT NULL DEFAULT false,
  has_code BOOLEAN NOT NULL DEFAULT false,
  ai_summary TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS strategy_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  strategy_id UUID NOT NULL REFERENCES strategies(id) ON DELETE CASCADE ON UPDATE CASCADE,
  content TEXT NOT NULL DEFAULT '',
  summary TEXT,
  note TEXT,
  version_number INTEGER NOT NULL,
  -- Nulled rather than cascaded: losing the author must not lose the revision.
  author_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  is_current BOOLEAN NOT NULL DEFAULT false,
  word_count INTEGER NOT NULL DEFAULT 0 CHECK (word_count >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (strategy_id, version_number)
);

-- Attachment metadata for the private `strategy-attachments` bucket. The bytes
-- live in storage; this row is what RLS can reason about. Object keys are
-- `<user_id>/<strategy_id>/<uuid><ext>`, which is what lets the storage owner
-- policies be prefix matches instead of joins.
CREATE TABLE IF NOT EXISTS strategy_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  strategy_id UUID NOT NULL REFERENCES strategies(id) ON DELETE CASCADE ON UPDATE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  storage_path TEXT NOT NULL UNIQUE,
  filename TEXT NOT NULL,
  mime_type TEXT,
  byte_size BIGINT CHECK (byte_size IS NULL OR byte_size BETWEEN 0 AND 10485760),
  is_image BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- A journal entry is a trade AND the write-up attached to it: one row, never
-- two. Splitting them would let one exist without the other, which is the
-- failure mode this feature exists to prevent. Column rationale:
-- migrations/009_journal_notes.sql
CREATE TABLE IF NOT EXISTS journal_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  title TEXT NOT NULL DEFAULT '',
  ticker TEXT,
  content TEXT NOT NULL,
  entry_price NUMERIC,
  exit_price NUMERIC,
  stop_loss NUMERIC,
  target NUMERIC,
  size NUMERIC,
  side TEXT CHECK (side IS NULL OR side IN ('long', 'short')),
  pnl NUMERIC,
  pnl_percent NUMERIC,
  r_multiple NUMERIC,
  opened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at TIMESTAMPTZ,
  screenshots TEXT[] DEFAULT '{}',       -- legacy, write-frozen: see 009
  psychology TEXT,                        -- legacy free text
  psychology_score INTEGER CHECK (psychology_score IS NULL OR psychology_score BETWEEN 1 AND 10),
  mistakes_made TEXT,
  lessons_learned TEXT,
  -- SET NULL, never CASCADE: deleting a playbook unfiles its trades, it does
  -- not destroy the trader's record of them.
  strategy_id UUID REFERENCES strategies(id) ON DELETE SET NULL ON UPDATE CASCADE,
  outcome TEXT CHECK (outcome IS NULL OR outcome IN ('win', 'loss', 'breakeven', 'open')),
  outcome_source TEXT NOT NULL DEFAULT 'auto' CHECK (outcome_source IN ('auto', 'manual')),
  tags TEXT[] DEFAULT '{}',
  linked_note_ids UUID[] NOT NULL DEFAULT '{}',   -- mirror of note_journal_links
  word_count INTEGER NOT NULL DEFAULT 0 CHECK (word_count >= 0),
  checklist_done INTEGER NOT NULL DEFAULT 0 CHECK (checklist_done >= 0),
  checklist_total INTEGER NOT NULL DEFAULT 0 CHECK (checklist_total >= checklist_done),
  has_images BOOLEAN NOT NULL DEFAULT false,
  has_code BOOLEAN NOT NULL DEFAULT false,
  is_public BOOLEAN NOT NULL DEFAULT false,   -- always false: no public route
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- An open trade has no exit and no close. A "closed" row with no exit price
  -- silently corrupts every playbook win rate derived from it.
  CONSTRAINT journal_entries_open_has_no_exit
    CHECK (outcome IS DISTINCT FROM 'open' OR (exit_price IS NULL AND closed_at IS NULL))
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

-- Attachment metadata for the private `journal-attachments` bucket. Unlike the
-- note and strategy equivalents this one has no public reader at any depth --
-- there is no public journal route, so there is nobody to grant.
CREATE TABLE IF NOT EXISTS journal_entry_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_id UUID NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE ON UPDATE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  storage_path TEXT NOT NULL UNIQUE,
  filename TEXT NOT NULL,
  mime_type TEXT,
  byte_size BIGINT CHECK (byte_size IS NULL OR byte_size BETWEEN 0 AND 10485760),
  is_image BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Long-form markdown notes. Column notes and rationale: migrations/007_trader_notes.sql
CREATE TABLE IF NOT EXISTS trader_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  title TEXT NOT NULL DEFAULT '',
  content TEXT NOT NULL DEFAULT '',
  note_type TEXT NOT NULL DEFAULT 'general'
    CHECK (note_type IN ('general', 'analysis', 'plan', 'review', 'idea', 'cheat_sheet')),
  tags TEXT[] NOT NULL DEFAULT '{}',
  linked_tickers TEXT[] NOT NULL DEFAULT '{}',
  strategy_id UUID REFERENCES strategies(id) ON DELETE SET NULL ON UPDATE CASCADE,
  linked_journal_ids UUID[] NOT NULL DEFAULT '{}',
  is_public BOOLEAN NOT NULL DEFAULT false,
  word_count INTEGER NOT NULL DEFAULT 0 CHECK (word_count >= 0),
  checklist_done INTEGER NOT NULL DEFAULT 0 CHECK (checklist_done >= 0),
  checklist_total INTEGER NOT NULL DEFAULT 0 CHECK (checklist_total >= checklist_done),
  has_images BOOLEAN NOT NULL DEFAULT false,
  has_code BOOLEAN NOT NULL DEFAULT false,
  view_count INTEGER NOT NULL DEFAULT 0 CHECK (view_count >= 0),
  like_count INTEGER NOT NULL DEFAULT 0 CHECK (like_count >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS trader_note_likes (
  note_id UUID NOT NULL REFERENCES trader_notes(id) ON DELETE CASCADE ON UPDATE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (note_id, user_id)
);

CREATE TABLE IF NOT EXISTS trader_note_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id UUID NOT NULL REFERENCES trader_notes(id) ON DELETE CASCADE ON UPDATE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  content TEXT NOT NULL CHECK (length(btrim(content)) BETWEEN 1 AND 2000),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS trader_note_views (
  note_id UUID NOT NULL REFERENCES trader_notes(id) ON DELETE CASCADE ON UPDATE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  viewed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (note_id, user_id)
);

CREATE TABLE IF NOT EXISTS trader_note_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id UUID NOT NULL REFERENCES trader_notes(id) ON DELETE CASCADE ON UPDATE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  storage_path TEXT NOT NULL UNIQUE,
  filename TEXT NOT NULL,
  mime_type TEXT,
  byte_size BIGINT CHECK (byte_size IS NULL OR byte_size BETWEEN 0 AND 10485760),
  is_image BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- The one genuine many-to-many edge in the link graph, and its source of truth.
-- `trader_notes.linked_journal_ids` and `journal_entries.linked_note_ids` are
-- mirrors of this table, rebuilt by trigger. The other two edge types are
-- many-to-one and need no join table: journal -> strategy is
-- `journal_entries.strategy_id`, note -> strategy is `trader_notes.strategy_id`.
-- Rationale: migrations/011_note_link_graph.sql
CREATE TABLE IF NOT EXISTS note_journal_links (
  note_id UUID NOT NULL REFERENCES trader_notes(id) ON DELETE CASCADE ON UPDATE CASCADE,
  entry_id UUID NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE ON UPDATE CASCADE,
  -- Denormalised owner. Both ends already carry one, but without it every RLS
  -- check on this table needs two subqueries -- on the hot path of every
  -- linked-records panel in the app. Assigned by trigger, never by a client.
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- Linking twice is the same as linking once: the client writes both ends of
  -- every edge, so a duplicate insert is expected traffic, not an error.
  PRIMARY KEY (note_id, entry_id)
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
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
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
-- The order the journal index actually reads: newest trade first, per owner.
-- Not created_at -- a trade backfilled today belongs where it happened.
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_sortdate
  ON journal_entries(user_id, (COALESCE(closed_at, opened_at)) DESC);
-- The prompt the journal leads with: trades with no playbook. Partial, because
-- a filed trade never needs to appear in this query again.
CREATE INDEX IF NOT EXISTS idx_journal_entries_unfiled
  ON journal_entries(user_id) WHERE strategy_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_journal_entries_notes_gin
  ON journal_entries USING GIN (linked_note_ids);
CREATE INDEX IF NOT EXISTS idx_journal_entries_search_gin
  ON journal_entries USING GIN (
    to_tsvector('english',
      coalesce(title, '') || ' ' || coalesce(ticker, '') || ' ' || content)
  );
CREATE INDEX IF NOT EXISTS idx_journal_entry_attachments_entry
  ON journal_entry_attachments(entry_id);
CREATE INDEX IF NOT EXISTS idx_journal_entry_attachments_user
  ON journal_entry_attachments(user_id);
CREATE INDEX IF NOT EXISTS idx_trader_notes_user_updated ON trader_notes(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_trader_notes_user_type ON trader_notes(user_id, note_type);
CREATE INDEX IF NOT EXISTS idx_trader_notes_user_strategy ON trader_notes(user_id, strategy_id);
CREATE INDEX IF NOT EXISTS idx_trader_notes_tags_gin ON trader_notes USING GIN (tags);
CREATE INDEX IF NOT EXISTS idx_trader_notes_tickers_gin ON trader_notes USING GIN (linked_tickers);
CREATE INDEX IF NOT EXISTS idx_trader_notes_public_updated ON trader_notes(updated_at DESC)
  WHERE is_public = true;
CREATE INDEX IF NOT EXISTS idx_trader_note_comments_note_created
  ON trader_note_comments(note_id, created_at);
CREATE INDEX IF NOT EXISTS idx_trader_notes_search_gin ON trader_notes
  USING GIN (to_tsvector('english', title || ' ' || content));
CREATE INDEX IF NOT EXISTS idx_trader_note_attachments_note ON trader_note_attachments(note_id);
CREATE INDEX IF NOT EXISTS idx_trader_note_attachments_user ON trader_note_attachments(user_id);
CREATE INDEX IF NOT EXISTS idx_note_journal_links_entry ON note_journal_links(entry_id);
CREATE INDEX IF NOT EXISTS idx_note_journal_links_user ON note_journal_links(user_id);
CREATE INDEX IF NOT EXISTS idx_strategies_user_category ON strategies(user_id, category);
CREATE INDEX IF NOT EXISTS idx_strategies_public_visibility ON strategies(visibility) WHERE visibility = 'public';
CREATE INDEX IF NOT EXISTS idx_strategies_user_updated ON strategies(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_strategies_user_status ON strategies(user_id, status);
CREATE INDEX IF NOT EXISTS idx_strategies_tags_gin ON strategies USING GIN (tags);
CREATE INDEX IF NOT EXISTS idx_strategies_tickers_gin ON strategies USING GIN (linked_tickers);
CREATE INDEX IF NOT EXISTS idx_strategies_journal_gin ON strategies USING GIN (linked_journal_ids);
CREATE INDEX IF NOT EXISTS idx_strategy_attachments_strategy ON strategy_attachments(strategy_id);
CREATE INDEX IF NOT EXISTS idx_strategy_attachments_user ON strategy_attachments(user_id);
-- Exactly one live revision per playbook. Without this, "restore v3" can leave
-- two rows claiming to be current and the history screen shows two live badges.
CREATE UNIQUE INDEX IF NOT EXISTS uq_strategy_versions_current
  ON strategy_versions(strategy_id) WHERE is_current;
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
  -- Every table with an `updated_at` column belongs in this list. Deliberately
  -- absent: note_journal_links, trader_note_likes and trader_note_views, which
  -- are append-only join rows with a created_at and nothing to touch.
  FOREACH t IN ARRAY ARRAY[
    'profiles',
    'affiliate_profiles',
    'affiliate_referrals',
    'affiliate_payouts',
    'subscriptions',
    'device_tokens',
    'strategies',
    'strategy_versions',
    'strategy_attachments',
    'journal_entries',
    'journal_entry_links',
    'journal_entry_attachments',
    'trader_notes',
    'trader_note_attachments',
    'trader_note_comments',
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

CREATE OR REPLACE FUNCTION refresh_trader_note_engagement_counts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE affected_note_id UUID;
BEGIN
  affected_note_id := COALESCE(NEW.note_id, OLD.note_id);
  UPDATE trader_notes
  SET like_count = (SELECT count(*) FROM trader_note_likes WHERE note_id = affected_note_id),
      view_count = (SELECT count(*) FROM trader_note_views WHERE note_id = affected_note_id)
  WHERE id = affected_note_id;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_trader_note_like_counts ON trader_note_likes;
CREATE TRIGGER trg_trader_note_like_counts
AFTER INSERT OR DELETE ON trader_note_likes
FOR EACH ROW EXECUTE FUNCTION refresh_trader_note_engagement_counts();

DROP TRIGGER IF EXISTS trg_trader_note_view_counts ON trader_note_views;
CREATE TRIGGER trg_trader_note_view_counts
AFTER INSERT OR DELETE ON trader_note_views
FOR EACH ROW EXECUTE FUNCTION refresh_trader_note_engagement_counts();

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

-- ---------------------------------------------------------------------------
-- Link graph maintenance. The join table and the two `strategy_id` columns are
-- the source of truth; the four `linked_*_ids` arrays are mirrors, rebuilt here
-- and never written by a client. Rationale: migrations/011_note_link_graph.sql
--
-- Two triggers on note_journal_links, because the two jobs need opposite
-- timings: ownership has to be settled BEFORE the row lands, and the mirrors
-- can only be rebuilt AFTER.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION validate_note_journal_link()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  n_owner UUID;
  e_owner UUID;
BEGIN
  SELECT user_id INTO n_owner FROM trader_notes    WHERE id = NEW.note_id;
  SELECT user_id INTO e_owner FROM journal_entries WHERE id = NEW.entry_id;
  IF n_owner IS NULL OR e_owner IS NULL OR n_owner <> e_owner THEN
    RAISE EXCEPTION 'note_journal_links: note and entry must share one owner';
  END IF;
  NEW.user_id := n_owner;   -- never trust a client-supplied owner
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION sync_note_journal_mirrors()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  n_id UUID := COALESCE(NEW.note_id,  OLD.note_id);
  e_id UUID := COALESCE(NEW.entry_id, OLD.entry_id);
BEGIN
  -- Recompute, never increment. An append that runs twice leaves a duplicate id
  -- in the array, and the client's union then renders one link as two.
  -- Both UPDATEs may match zero rows: on a cascade delete the parent is already
  -- gone. That is correct and silent -- do not look the parent up first.
  UPDATE trader_notes SET linked_journal_ids = COALESCE(
    (SELECT array_agg(entry_id ORDER BY created_at DESC)
       FROM note_journal_links WHERE note_id = n_id), '{}')
   WHERE id = n_id;

  UPDATE journal_entries SET linked_note_ids = COALESCE(
    (SELECT array_agg(note_id ORDER BY created_at DESC)
       FROM note_journal_links WHERE entry_id = e_id), '{}')
   WHERE id = e_id;

  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS trg_note_journal_links_validate ON note_journal_links;
CREATE TRIGGER trg_note_journal_links_validate
  BEFORE INSERT ON note_journal_links
  FOR EACH ROW EXECUTE FUNCTION validate_note_journal_link();

DROP TRIGGER IF EXISTS trg_note_journal_links_sync ON note_journal_links;
CREATE TRIGGER trg_note_journal_links_sync
  AFTER INSERT OR DELETE ON note_journal_links
  FOR EACH ROW EXECUTE FUNCTION sync_note_journal_mirrors();

-- The strategy mirrors work the same way, driven from the child tables.
CREATE OR REPLACE FUNCTION rebuild_strategy_mirrors(p_strategy UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF p_strategy IS NULL THEN RETURN; END IF;
  UPDATE strategies SET
    linked_journal_ids = COALESCE((
      SELECT array_agg(e.id ORDER BY COALESCE(e.closed_at, e.opened_at) DESC)
        FROM journal_entries e WHERE e.strategy_id = p_strategy), '{}'),
    linked_note_ids = COALESCE((
      SELECT array_agg(n.id ORDER BY n.updated_at DESC)
        FROM trader_notes n WHERE n.strategy_id = p_strategy), '{}')
   WHERE id = p_strategy;
END $$;

-- Rebuild for BOTH the old and the new strategy_id. Rebuilding only the new one
-- is the bug to avoid: refiling a trade would leave it listed under the playbook
-- it just left, forever.
CREATE OR REPLACE FUNCTION sync_strategy_mirrors()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF TG_OP <> 'INSERT' THEN PERFORM rebuild_strategy_mirrors(OLD.strategy_id); END IF;
  IF TG_OP <> 'DELETE' THEN PERFORM rebuild_strategy_mirrors(NEW.strategy_id); END IF;
  RETURN NULL;
END $$;

-- `UPDATE OF strategy_id` fires when the column appears in the SET list, not
-- only when its value changes. That is fine: the rebuild is idempotent.
DROP TRIGGER IF EXISTS trg_journal_entries_strategy_mirror ON journal_entries;
CREATE TRIGGER trg_journal_entries_strategy_mirror
  AFTER INSERT OR DELETE OR UPDATE OF strategy_id ON journal_entries
  FOR EACH ROW EXECUTE FUNCTION sync_strategy_mirrors();

DROP TRIGGER IF EXISTS trg_trader_notes_strategy_mirror ON trader_notes;
CREATE TRIGGER trg_trader_notes_strategy_mirror
  AFTER INSERT OR DELETE OR UPDATE OF strategy_id ON trader_notes
  FOR EACH ROW EXECUTE FUNCTION sync_strategy_mirrors();

-- ---------------------------------------------------------------------------
-- Derived reads. Nothing below stores anything.
-- Rationale: migrations/012_linked_notes_reads.sql
-- ---------------------------------------------------------------------------

-- `security_invoker = true` is load-bearing. Without it the view runs with its
-- owner's rights and bypasses RLS, which would let any authenticated user read
-- every other trader's playbook performance.
CREATE OR REPLACE VIEW strategy_performance WITH (security_invoker = true) AS
WITH closed AS (
  SELECT strategy_id, user_id, pnl, r_multiple,
         COALESCE(closed_at, opened_at) AS at
    FROM journal_entries
   WHERE strategy_id IS NOT NULL
     AND outcome IS DISTINCT FROM 'open'
)
SELECT
  s.id                                                     AS strategy_id,
  s.user_id,
  COUNT(c.*)                                               AS trades,
  COALESCE(SUM(c.pnl), 0)                                  AS net_pnl,
  CASE WHEN COUNT(c.*) = 0 THEN 0
       ELSE ROUND(100.0 * COUNT(c.*) FILTER (WHERE c.pnl > 0) / COUNT(c.*), 2)
  END                                                      AS win_rate,
  COALESCE(AVG(c.r_multiple), 0)                           AS avg_r
FROM strategies s
LEFT JOIN closed c ON c.strategy_id = s.id
GROUP BY s.id, s.user_id;

-- win_rate is 0..100 here, matching AppStrategy.winRate. AppJournalStats.winRate
-- and the two stat-row models are 0..1. Do not convert between them anywhere.

GRANT SELECT ON strategy_performance TO authenticated;

-- ---------------------------------------------------------------------------
-- Public read path. `public_document` is the ONLY entry point for an
-- unauthenticated reader. A visitor has no workspace, so a visitor cannot build
-- the link graph the app builds client-side: for an anonymous caller a
-- watch-all read would return every public record in the product to render one
-- document. One record, refs already resolved, is a different read.
-- ---------------------------------------------------------------------------

-- Aggregates over rows the caller cannot select. SECURITY DEFINER by necessity;
-- the `< 5` floor is why it is not a leak: a playbook with one closed trade
-- behind it would not report a statistic, it would report that trade's outcome.
CREATE OR REPLACE FUNCTION public_strategy_performance(p_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT CASE WHEN COUNT(*) < 5 THEN NULL ELSE jsonb_build_object(
           'total_trades', COUNT(*),
           'win_rate',     ROUND(100.0 * COUNT(*) FILTER (WHERE c.pnl > 0)
                                 / NULLIF(COUNT(*), 0), 2),
           'avg_r',        ROUND(AVG(c.r_multiple)::numeric, 2),
           'net_pnl',      ROUND(SUM(c.pnl)::numeric, 2)
         ) END
    FROM journal_entries c
   WHERE c.strategy_id = p_id
     AND c.outcome IS DISTINCT FROM 'open';
$$;

-- Which refs survive the strip. Journal entries never do -- the share contract
-- publishes a playbook's figures, not the trades behind them. Both arms
-- re-check the publish flag on BOTH ends: this is reachable by anon, so its
-- arguments are hostile input.
CREATE OR REPLACE FUNCTION public_refs(p_kind text, p_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(jsonb_agg(r ORDER BY r ->> 'title'), '[]'::jsonb)
  FROM (
    SELECT jsonb_build_object(
             'kind', 'note', 'id', n.id,
             'title', n.title, 'subtitle', n.note_type
           ) AS r
      FROM trader_notes n
      JOIN strategies s ON s.id = n.strategy_id
     WHERE p_kind = 'strategy'
       AND s.id = p_id AND s.visibility = 'public'
       AND n.is_public
    UNION ALL
    SELECT jsonb_build_object(
             'kind', 'strategy', 'id', s.id,
             'title', s.title, 'subtitle', s.summary
           )
      FROM trader_notes n
      JOIN strategies s ON s.id = n.strategy_id
     WHERE p_kind = 'note'
       AND n.id = p_id AND n.is_public
       AND s.visibility = 'public'
  ) refs;
$$;

-- A SECURITY DEFINER function bypasses RLS. That is the point, and it is also
-- why the column list below IS the security boundary: there is no second check
-- behind it. Deliberately absent: both mirror arrays, the raw user_id (handle is
-- the public identity), version_count, and every owner-scoped flag.
--
-- A missing record and a private record return the same thing: no row, hence
-- NULL. Do not raise not-found for one and forbidden for the other -- that
-- difference is an oracle a script can walk to enumerate which ids exist.
CREATE OR REPLACE FUNCTION public_document(p_kind text, p_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
           'kind', 'strategy', 'id', s.id, 'name', s.title,
           'summary', s.summary, 'body', s.content, 'status', s.status,
           'tags', s.tags, 'tickers', s.linked_tickers,
           'updated_at', s.updated_at,
           'author', jsonb_build_object('handle', p.handle,
                                        'display_name', p.display_name,
                                        'avatar_url', p.avatar_url),
           'performance', public_strategy_performance(s.id),
           'refs', public_refs('strategy', s.id)
         )
    FROM strategies s JOIN profiles p ON p.id = s.user_id
   WHERE p_kind = 'strategy' AND s.id = p_id AND s.visibility = 'public'
  UNION ALL
  SELECT jsonb_build_object(
           'kind', 'note', 'id', n.id, 'title', n.title,
           'body', n.content, 'note_type', n.note_type,
           'tags', n.tags, 'tickers', n.linked_tickers,
           'updated_at', n.updated_at,
           'like_count', n.like_count, 'view_count', n.view_count,
           'author', jsonb_build_object('handle', p.handle,
                                        'display_name', p.display_name,
                                        'avatar_url', p.avatar_url),
           'refs', public_refs('note', n.id)
         )
    FROM trader_notes n JOIN profiles p ON p.id = n.user_id
   WHERE p_kind = 'note' AND n.id = p_id AND n.is_public
   LIMIT 1;
$$;

-- One door. The two helpers are never granted: inside a SECURITY DEFINER
-- function the effective role is the owner, so the nested EXECUTE checks pass
-- against the owner and anon still cannot call them directly.
REVOKE EXECUTE ON FUNCTION public_document(text, uuid)        FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public_refs(text, uuid)            FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public_strategy_performance(uuid)  FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public_document(text, uuid)        TO anon, authenticated;

COMMIT;
BEGIN;

-- Instruments
CREATE TABLE IF NOT EXISTS instruments (
    symbol TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    exchange TEXT,
    asset_class TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Quotes
CREATE TABLE IF NOT EXISTS quotes (
    symbol TEXT PRIMARY KEY REFERENCES instruments(symbol) ON DELETE CASCADE,
    price NUMERIC NOT NULL,
    previous_close NUMERIC,
    day_high NUMERIC,
    day_low NUMERIC,
    volume BIGINT,
    change_pct NUMERIC,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- News Articles
CREATE TABLE IF NOT EXISTS news_articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    summary TEXT,
    publisher TEXT,
    url TEXT UNIQUE NOT NULL,
    thumbnail_url TEXT,
    content_type TEXT NOT NULL DEFAULT 'STORY',
    market TEXT,
    source TEXT,

    published_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_news_published ON news_articles(published_at DESC);

-- News Tickers
CREATE TABLE IF NOT EXISTS news_tickers (
    article_id UUID NOT NULL REFERENCES news_articles(id) ON DELETE CASCADE,
    symbol TEXT NOT NULL REFERENCES instruments(symbol) ON DELETE CASCADE,
    PRIMARY KEY (article_id, symbol)
);
CREATE INDEX IF NOT EXISTS idx_news_tickers_symbol ON news_tickers(symbol);

-- News Bookmarks
CREATE TABLE IF NOT EXISTS news_bookmarks (
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    article_id UUID NOT NULL REFERENCES news_articles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, article_id)
);

-- Ticker Linking with Notes (Join Table instead of relying only on TEXT[])
CREATE TABLE IF NOT EXISTS note_ticker_links (
    note_id UUID NOT NULL REFERENCES trader_notes(id) ON DELETE CASCADE,
    symbol TEXT NOT NULL REFERENCES instruments(symbol) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (note_id, symbol)
);
CREATE INDEX IF NOT EXISTS idx_note_ticker_links_symbol ON note_ticker_links(symbol);
CREATE INDEX IF NOT EXISTS idx_note_ticker_links_user ON note_ticker_links(user_id);

-- Mirror sync for note_ticker_links -> trader_notes.linked_tickers
CREATE OR REPLACE FUNCTION sync_note_ticker_mirrors()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  n_id UUID := COALESCE(NEW.note_id, OLD.note_id);
BEGIN
  UPDATE trader_notes SET linked_tickers = COALESCE(
    (SELECT array_agg(symbol ORDER BY created_at DESC)
       FROM note_ticker_links WHERE note_id = n_id), '{}')
   WHERE id = n_id;
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS trg_note_ticker_links_sync ON note_ticker_links;
CREATE TRIGGER trg_note_ticker_links_sync
  AFTER INSERT OR DELETE ON note_ticker_links
  FOR EACH ROW EXECUTE FUNCTION sync_note_ticker_mirrors();

COMMIT;
BEGIN;

CREATE TABLE IF NOT EXISTS market_history (
    symbol TEXT NOT NULL REFERENCES instruments(symbol) ON DELETE CASCADE,
    time TIMESTAMPTZ NOT NULL,
    open NUMERIC NOT NULL,
    high NUMERIC NOT NULL,
    low NUMERIC NOT NULL,
    close NUMERIC NOT NULL,
    volume BIGINT NOT NULL,
    PRIMARY KEY (symbol, time)
);

-- Timeseries hypertable if using TimescaleDB, otherwise regular B-tree index
CREATE INDEX IF NOT EXISTS idx_market_history_time ON market_history(time DESC);

COMMIT;
BEGIN;

ALTER TABLE instruments 
ADD COLUMN IF NOT EXISTS currency TEXT,
ADD COLUMN IF NOT EXISTS market TEXT,
ADD COLUMN IF NOT EXISTS sector TEXT,
ADD COLUMN IF NOT EXISTS industry TEXT,
ADD COLUMN IF NOT EXISTS market_cap BIGINT,
ADD COLUMN IF NOT EXISTS pe_ratio NUMERIC,
ADD COLUMN IF NOT EXISTS fifty_two_week_high NUMERIC,
ADD COLUMN IF NOT EXISTS fifty_two_week_low NUMERIC,
ADD COLUMN IF NOT EXISTS dividend_yield NUMERIC;

COMMIT;
