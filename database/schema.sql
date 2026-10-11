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
  location TEXT,
  website TEXT,
  avg_hold_duration TEXT,
  primary_market TEXT,
  top_strategy TEXT,
  risk_mantra TEXT,
  public_journals BOOLEAN NOT NULL DEFAULT false,
  subscription_tier TEXT NOT NULL DEFAULT 'free',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Idempotent column additions for existing installations
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS website TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS avg_hold_duration TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS primary_market TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS top_strategy TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS risk_mantra TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS public_stats BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notification_settings JSONB NOT NULL DEFAULT '{}'::jsonb;

CREATE TABLE IF NOT EXISTS affiliate_profiles (
  id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  affiliate_code TEXT UNIQUE NOT NULL,
  custom_slug TEXT UNIQUE,
  tier TEXT NOT NULL DEFAULT 'standard' CHECK (tier IN ('standard', 'silver', 'gold', 'platinum')),
  commission_rate NUMERIC NOT NULL DEFAULT 0.15 CHECK (commission_rate >= 0.0 AND commission_rate <= 1.0),
  total_referrals INTEGER NOT NULL DEFAULT 0 CHECK (total_referrals >= 0),
  active_referrals INTEGER NOT NULL DEFAULT 0 CHECK (active_referrals >= 0),
  total_earnings NUMERIC NOT NULL DEFAULT 0.00 CHECK (total_earnings >= 0.0),
  unpaid_balance NUMERIC NOT NULL DEFAULT 0.00 CHECK (unpaid_balance >= 0.0),
  paid_earnings NUMERIC NOT NULL DEFAULT 0.00 CHECK (paid_earnings >= 0.0),
  minimum_payout_threshold NUMERIC NOT NULL DEFAULT 100.0 CHECK (minimum_payout_threshold >= 0.0),
  auto_payout_enabled BOOLEAN NOT NULL DEFAULT true,
  payout_method TEXT CHECK (payout_method IN ('bank_transfer', 'bank_wire', 'paypal', 'stripe', 'crypto', 'upi')),
  payout_details JSONB NOT NULL DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('pending', 'active', 'suspended')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Idempotent column additions for existing affiliate installations
ALTER TABLE affiliate_profiles ADD COLUMN IF NOT EXISTS custom_slug TEXT UNIQUE;
ALTER TABLE affiliate_profiles ADD COLUMN IF NOT EXISTS minimum_payout_threshold NUMERIC NOT NULL DEFAULT 100.0;
ALTER TABLE affiliate_profiles ADD COLUMN IF NOT EXISTS auto_payout_enabled BOOLEAN NOT NULL DEFAULT true;
DO $$
BEGIN
  ALTER TABLE affiliate_profiles DROP CONSTRAINT IF EXISTS affiliate_profiles_payout_method_check;
  ALTER TABLE affiliate_profiles ADD CONSTRAINT affiliate_profiles_payout_method_check 
    CHECK (payout_method IN ('bank_transfer', 'bank_wire', 'paypal', 'stripe', 'crypto', 'upi'));
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

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

-- Idempotent column additions for existing subscriptions installations
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS revenuecat_id TEXT;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS billing_cycle TEXT;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS renewed_at TIMESTAMPTZ;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  invoice_ref TEXT NOT NULL,
  amount NUMERIC NOT NULL,
  currency TEXT NOT NULL DEFAULT 'INR',
  status TEXT NOT NULL DEFAULT 'paid',
  pdf_url TEXT,
  line_items JSONB NOT NULL DEFAULT '[]'::jsonb,
  issued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS data_export_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending',
  download_url TEXT,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
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

-- Idempotent column additions for existing strategies installations
ALTER TABLE strategies ADD COLUMN IF NOT EXISTS summary TEXT;
ALTER TABLE strategies ADD COLUMN IF NOT EXISTS content TEXT NOT NULL DEFAULT '';
ALTER TABLE strategies ADD COLUMN IF NOT EXISTS category TEXT;
ALTER TABLE strategies ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'draft';
ALTER TABLE strategies ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE strategies ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'private';
ALTER TABLE strategies ADD COLUMN IF NOT EXISTS tags TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE strategies ADD COLUMN IF NOT EXISTS linked_tickers TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE strategies ADD COLUMN IF NOT EXISTS linked_note_ids UUID[] NOT NULL DEFAULT '{}';
ALTER TABLE strategies ADD COLUMN IF NOT EXISTS linked_journal_ids UUID[] NOT NULL DEFAULT '{}';
ALTER TABLE strategies ADD COLUMN IF NOT EXISTS version_count INTEGER NOT NULL DEFAULT 1;
ALTER TABLE strategies ADD COLUMN IF NOT EXISTS word_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE strategies ADD COLUMN IF NOT EXISTS checklist_done INTEGER NOT NULL DEFAULT 0;
ALTER TABLE strategies ADD COLUMN IF NOT EXISTS checklist_total INTEGER NOT NULL DEFAULT 0;
ALTER TABLE strategies ADD COLUMN IF NOT EXISTS has_images BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE strategies ADD COLUMN IF NOT EXISTS has_code BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE strategies ADD COLUMN IF NOT EXISTS ai_summary TEXT;

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

-- Idempotent column additions for existing strategy_versions installations
ALTER TABLE strategy_versions ADD COLUMN IF NOT EXISTS note TEXT;
ALTER TABLE strategy_versions ADD COLUMN IF NOT EXISTS author_id UUID REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE strategy_versions ADD COLUMN IF NOT EXISTS is_current BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE strategy_versions ADD COLUMN IF NOT EXISTS summary TEXT;
ALTER TABLE strategy_versions ADD COLUMN IF NOT EXISTS word_count INTEGER NOT NULL DEFAULT 0;

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

-- Idempotent column additions for existing journal_entries installations
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS title TEXT NOT NULL DEFAULT '';
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS ticker TEXT;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS content TEXT NOT NULL DEFAULT '';
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS entry_price NUMERIC;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS exit_price NUMERIC;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS stop_loss NUMERIC;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS target NUMERIC;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS size NUMERIC;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS side TEXT;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS pnl NUMERIC;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS pnl_percent NUMERIC;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS r_multiple NUMERIC;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS opened_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS closed_at TIMESTAMPTZ;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS screenshots TEXT[] DEFAULT '{}';
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS psychology TEXT;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS psychology_score INTEGER;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS mistakes_made TEXT;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS lessons_learned TEXT;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS strategy_id UUID REFERENCES strategies(id) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS outcome TEXT;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS outcome_source TEXT NOT NULL DEFAULT 'auto';
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS linked_note_ids UUID[] NOT NULL DEFAULT '{}';
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS word_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS checklist_done INTEGER NOT NULL DEFAULT 0;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS checklist_total INTEGER NOT NULL DEFAULT 0;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS has_images BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS has_code BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT false;


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

-- Idempotent column additions for existing trader_notes installations
ALTER TABLE trader_notes ADD COLUMN IF NOT EXISTS title TEXT NOT NULL DEFAULT '';
ALTER TABLE trader_notes ADD COLUMN IF NOT EXISTS content TEXT NOT NULL DEFAULT '';
ALTER TABLE trader_notes ADD COLUMN IF NOT EXISTS note_type TEXT NOT NULL DEFAULT 'general';
ALTER TABLE trader_notes ADD COLUMN IF NOT EXISTS tags TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE trader_notes ADD COLUMN IF NOT EXISTS linked_tickers TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE trader_notes ADD COLUMN IF NOT EXISTS strategy_id UUID REFERENCES strategies(id) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE trader_notes ADD COLUMN IF NOT EXISTS linked_journal_ids UUID[] NOT NULL DEFAULT '{}';
ALTER TABLE trader_notes ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE trader_notes ADD COLUMN IF NOT EXISTS word_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE trader_notes ADD COLUMN IF NOT EXISTS checklist_done INTEGER NOT NULL DEFAULT 0;
ALTER TABLE trader_notes ADD COLUMN IF NOT EXISTS checklist_total INTEGER NOT NULL DEFAULT 0;
ALTER TABLE trader_notes ADD COLUMN IF NOT EXISTS has_images BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE trader_notes ADD COLUMN IF NOT EXISTS has_code BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE trader_notes ADD COLUMN IF NOT EXISTS view_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE trader_notes ADD COLUMN IF NOT EXISTS like_count INTEGER NOT NULL DEFAULT 0;

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

-- Idempotent column additions for existing watchlist_items installations
ALTER TABLE watchlist_items ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE watchlist_items ADD COLUMN IF NOT EXISTS category TEXT;
ALTER TABLE watchlist_items ADD COLUMN IF NOT EXISTS price_alert_threshold NUMERIC;
ALTER TABLE watchlist_items ADD COLUMN IF NOT EXISTS price_alert_direction TEXT;
ALTER TABLE watchlist_items ADD COLUMN IF NOT EXISTS alert_armed BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE watchlist_items ADD COLUMN IF NOT EXISTS alert_last_triggered_at TIMESTAMPTZ;
ALTER TABLE watchlist_items ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  content TEXT NOT NULL,
  image_url TEXT,
  ticker TEXT,
  content_type TEXT NOT NULL DEFAULT 'market_discussion',
  -- A post can stand alone or carry exactly one Writing Desk record. SET NULL
  -- preserves the conversation if its source is later deleted.
  note_id UUID REFERENCES trader_notes(id) ON DELETE SET NULL ON UPDATE CASCADE,
  journal_entry_id UUID REFERENCES journal_entries(id) ON DELETE SET NULL ON UPDATE CASCADE,
  strategy_id UUID REFERENCES strategies(id) ON DELETE SET NULL ON UPDATE CASCADE,
  likes_count INTEGER NOT NULL DEFAULT 0,
  comments_count INTEGER NOT NULL DEFAULT 0,
  views_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT posts_one_writing_attachment CHECK (
    num_nonnulls(note_id, journal_entry_id, strategy_id) <= 1
  )
);

-- Idempotent column additions for existing posts installations
ALTER TABLE posts ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS ticker TEXT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS content_type TEXT NOT NULL DEFAULT 'market_discussion';
ALTER TABLE posts ADD COLUMN IF NOT EXISTS note_id UUID REFERENCES trader_notes(id) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS journal_entry_id UUID REFERENCES journal_entries(id) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS strategy_id UUID REFERENCES strategies(id) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS likes_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS comments_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS views_count INTEGER NOT NULL DEFAULT 0;

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
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  ticker TEXT,
  summary TEXT,
  indicators JSONB,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  title TEXT NOT NULL DEFAULT '',
  body TEXT NOT NULL DEFAULT '',
  confidence NUMERIC(5, 4) DEFAULT 0.8500,
  sentiment_score NUMERIC(5, 4) DEFAULT 0.0000,
  tickers TEXT[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Idempotent column additions for existing ai_insights installations
ALTER TABLE ai_insights ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE ai_insights ADD COLUMN IF NOT EXISTS ticker TEXT;
ALTER TABLE ai_insights ADD COLUMN IF NOT EXISTS summary TEXT;
ALTER TABLE ai_insights ADD COLUMN IF NOT EXISTS indicators JSONB;
ALTER TABLE ai_insights ADD COLUMN IF NOT EXISTS generated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE ai_insights ADD COLUMN IF NOT EXISTS title TEXT NOT NULL DEFAULT '';
ALTER TABLE ai_insights ADD COLUMN IF NOT EXISTS body TEXT NOT NULL DEFAULT '';
ALTER TABLE ai_insights ADD COLUMN IF NOT EXISTS confidence NUMERIC(5, 4) DEFAULT 0.8500;
ALTER TABLE ai_insights ADD COLUMN IF NOT EXISTS sentiment_score NUMERIC(5, 4) DEFAULT 0.0000;
ALTER TABLE ai_insights ADD COLUMN IF NOT EXISTS tickers TEXT[] NOT NULL DEFAULT '{}';

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

CREATE TABLE IF NOT EXISTS trader_preferences (
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  default_position_size_pct NUMERIC NOT NULL DEFAULT 2.0 CHECK (default_position_size_pct >= 0.1 AND default_position_size_pct <= 100.0),
  default_r_multiple NUMERIC NOT NULL DEFAULT 2.5 CHECK (default_r_multiple >= 0.1),
  default_watchlist_symbols TEXT[] NOT NULL DEFAULT '{"NIFTY50","BANKNIFTY","RELIANCE","TCS","HDFCBANK"}',
  watchlist_refresh_interval_seconds INTEGER NOT NULL DEFAULT 15 CHECK (watchlist_refresh_interval_seconds >= 1),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS trader_checklists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  label TEXT NOT NULL,
  description TEXT,
  done BOOLEAN NOT NULL DEFAULT false,
  icon_name TEXT DEFAULT 'check_box_outline_blank',
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE trader_checklists ADD COLUMN IF NOT EXISTS icon_name TEXT DEFAULT 'check_box_outline_blank';

CREATE TABLE IF NOT EXISTS organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  settings JSONB NOT NULL DEFAULT '{}'::jsonb,
  api_keys JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS organization_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE ON UPDATE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  role TEXT NOT NULL DEFAULT 'trader' CHECK (role IN ('owner', 'admin', 'trader', 'viewer')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (organization_id, user_id)
);

CREATE TABLE IF NOT EXISTS desk_risk_policies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE ON UPDATE CASCADE,
  admin_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
  max_firm_drawdown_percent NUMERIC NOT NULL DEFAULT 5.0,
  max_position_per_trader NUMERIC NOT NULL DEFAULT 5000000.0,
  enforce_pre_trade_checklist BOOLEAN NOT NULL DEFAULT true,
  manager_approval_threshold NUMERIC NOT NULL DEFAULT 1000000.0,
  audit_logging_enabled BOOLEAN NOT NULL DEFAULT true,
  allowed_asset_classes TEXT[] NOT NULL DEFAULT '{"NSE Equities","F&O Derivatives","Commodities (MCX)","Currency Pairs"}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (admin_id)
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
CREATE INDEX IF NOT EXISTS idx_posts_note ON posts(note_id) WHERE note_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_posts_journal_entry ON posts(journal_entry_id) WHERE journal_entry_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_posts_strategy ON posts(strategy_id) WHERE strategy_id IS NOT NULL;
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
    'revenuecat_webhook_events',
    'trader_preferences',
    'trader_checklists'
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

-- A post may reference only an owned, already-public Writing Desk record.
-- This validates the privacy boundary without making publication a side effect
-- of post creation. See migrations/016_post_writing_attachments.sql.
CREATE OR REPLACE FUNCTION validate_post_writing_attachment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  source_owner UUID;
  source_public BOOLEAN;
BEGIN
  IF NEW.note_id IS NOT NULL THEN
    SELECT user_id, is_public INTO source_owner, source_public
      FROM trader_notes WHERE id = NEW.note_id;
  ELSIF NEW.journal_entry_id IS NOT NULL THEN
    SELECT e.user_id, e.is_public AND p.public_journals
      INTO source_owner, source_public
      FROM journal_entries e
      JOIN profiles p ON p.id = e.user_id
      WHERE e.id = NEW.journal_entry_id;
  ELSIF NEW.strategy_id IS NOT NULL THEN
    SELECT user_id, visibility = 'public' INTO source_owner, source_public
      FROM strategies WHERE id = NEW.strategy_id;
  ELSE
    RETURN NEW;
  END IF;

  IF source_owner IS NULL OR source_owner <> NEW.user_id THEN
    RAISE EXCEPTION 'A post attachment must belong to the post author';
  END IF;
  IF source_public IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'A post attachment must be public before it is posted';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_posts_validate_writing_attachment ON posts;
CREATE TRIGGER trg_posts_validate_writing_attachment
  BEFORE INSERT OR UPDATE OF user_id, note_id, journal_entry_id, strategy_id
  ON posts
  FOR EACH ROW EXECUTE FUNCTION validate_post_writing_attachment();

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

-- News Tickers
CREATE TABLE IF NOT EXISTS news_tickers (
    article_id INTEGER NOT NULL REFERENCES news_articles(id) ON DELETE CASCADE,
    symbol TEXT NOT NULL REFERENCES instruments(symbol) ON DELETE CASCADE,
    PRIMARY KEY (article_id, symbol)
);
CREATE INDEX IF NOT EXISTS idx_news_tickers_symbol ON news_tickers(symbol);

-- News Bookmarks
CREATE TABLE IF NOT EXISTS news_bookmarks (
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    article_id INTEGER NOT NULL REFERENCES news_articles(id) ON DELETE CASCADE,
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

-- ============================================================================
-- 017: AI Copilot & Assistant
-- ============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS ai_chart_setups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    title TEXT NOT NULL DEFAULT '',
    symbol TEXT NOT NULL,
    timeframe TEXT NOT NULL DEFAULT '15m',
    pattern TEXT NOT NULL DEFAULT '',
    direction TEXT NOT NULL CHECK (direction IN ('long', 'short')),
    entry NUMERIC(16, 4) NOT NULL,
    stop_loss NUMERIC(16, 4) NOT NULL,
    target1 NUMERIC(16, 4) NOT NULL,
    target2 NUMERIC(16, 4) NOT NULL,
    confidence INTEGER NOT NULL DEFAULT 80 CHECK (confidence >= 0 AND confidence <= 100),
    rationale TEXT NOT NULL DEFAULT '',
    preview_url TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ai_threads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    title TEXT NOT NULL DEFAULT 'New Conversation',
    persona TEXT NOT NULL DEFAULT 'swing'
        CHECK (persona IN ('swing', 'scalp', 'options', 'macro', 'risk')),
    pinned BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ai_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    thread_id UUID NOT NULL REFERENCES ai_threads(id) ON DELETE CASCADE ON UPDATE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    body TEXT NOT NULL DEFAULT '',
    pending BOOLEAN NOT NULL DEFAULT false,
    error TEXT,
    sources TEXT[] NOT NULL DEFAULT '{}',
    attachments TEXT[] NOT NULL DEFAULT '{}',
    chart_setup_id UUID REFERENCES ai_chart_setups(id) ON DELETE SET NULL ON UPDATE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);



CREATE TABLE IF NOT EXISTS ai_quotas (
    user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    daily_limit INTEGER NOT NULL DEFAULT 50,
    daily_used INTEGER NOT NULL DEFAULT 0 CHECK (daily_used >= 0),
    reset_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '1 day'),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_threads_user_updated ON ai_threads(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_messages_thread_created ON ai_messages(thread_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_ai_chart_setups_user_symbol ON ai_chart_setups(user_id, symbol);
CREATE INDEX IF NOT EXISTS idx_ai_insights_user_created ON ai_insights(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_insights_tickers ON ai_insights USING GIN(tickers);

COMMIT;

-- ============================================================================
-- 018: Realtime Messaging
-- ============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS chat_threads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL DEFAULT 'direct' CHECK (type IN ('direct', 'group', 'desk')),
    title TEXT,
    created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    is_archived BOOLEAN NOT NULL DEFAULT false,
    is_request BOOLEAN NOT NULL DEFAULT false,
    last_message_preview TEXT NOT NULL DEFAULT '',
    last_message_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS chat_participants (
    thread_id UUID NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member')),
    last_read_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (thread_id, user_id)
);

CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    thread_id UUID NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE ON UPDATE CASCADE,
    sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    body TEXT NOT NULL DEFAULT '',
    reply_to_id UUID REFERENCES chat_messages(id) ON DELETE SET NULL ON UPDATE CASCADE,
    system_notice BOOLEAN NOT NULL DEFAULT false,
    status TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sending', 'sent', 'delivered', 'read', 'failed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS chat_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE ON UPDATE CASCADE,
    kind TEXT NOT NULL CHECK (kind IN ('image', 'chart', 'document', 'tradeSetup', 'voice')),
    url TEXT NOT NULL,
    title TEXT NOT NULL DEFAULT '',
    file_size_bytes BIGINT,
    duration_seconds INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS chat_shared_refs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE ON UPDATE CASCADE,
    ref_id TEXT NOT NULL,
    kind TEXT NOT NULL,
    title TEXT NOT NULL,
    subtitle TEXT,
    ticker TEXT,
    tags TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS chat_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    emoji TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (message_id, user_id, emoji)
);

CREATE TABLE IF NOT EXISTS chat_user_presence (
    user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    status TEXT NOT NULL DEFAULT 'offline' CHECK (status IN ('online', 'away', 'busy', 'offline')),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chat_participants_user ON chat_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_thread_created ON chat_messages(thread_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_chat_attachments_msg ON chat_attachments(message_id);
CREATE INDEX IF NOT EXISTS idx_chat_shared_refs_msg ON chat_shared_refs(message_id);
CREATE INDEX IF NOT EXISTS idx_chat_reactions_msg ON chat_reactions(message_id);

CREATE OR REPLACE FUNCTION update_chat_thread_last_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE chat_threads
    SET last_message_preview = CASE 
            WHEN NEW.body <> '' THEN SUBSTRING(NEW.body FROM 1 FOR 120)
            ELSE 'Attachment'
        END,
        last_message_at = NEW.created_at,
        updated_at = NEW.created_at
    WHERE id = NEW.thread_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_chat_thread_last_message ON chat_messages;
CREATE TRIGGER trigger_chat_thread_last_message
    AFTER INSERT ON chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_chat_thread_last_message();

COMMIT;

-- ============================================================================
-- 019: Social Trading Community
-- ============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS community_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    title TEXT NOT NULL DEFAULT '',
    body TEXT NOT NULL,
    excerpt TEXT,
    kind TEXT NOT NULL DEFAULT 'standard'
        CHECK (kind IN ('standard', 'analysis', 'playbook', 'signal', 'poll')),
    channel_id TEXT NOT NULL DEFAULT 'general',
    tickers TEXT[] NOT NULL DEFAULT '{}',
    tags TEXT[] NOT NULL DEFAULT '{}',
    views_count INTEGER NOT NULL DEFAULT 0 CHECK (views_count >= 0),
    likes_count INTEGER NOT NULL DEFAULT 0 CHECK (likes_count >= 0),
    comments_count INTEGER NOT NULL DEFAULT 0 CHECK (comments_count >= 0),
    reposts_count INTEGER NOT NULL DEFAULT 0 CHECK (reposts_count >= 0),
    bookmarks_count INTEGER NOT NULL DEFAULT 0 CHECK (bookmarks_count >= 0),
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    is_featured BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS community_post_trade_setups (
    post_id UUID PRIMARY KEY REFERENCES community_posts(id) ON DELETE CASCADE ON UPDATE CASCADE,
    ticker TEXT NOT NULL,
    side TEXT NOT NULL CHECK (side IN ('long', 'short')),
    entry NUMERIC(16, 4) NOT NULL,
    stop_loss NUMERIC(16, 4) NOT NULL,
    target1 NUMERIC(16, 4) NOT NULL,
    target2 NUMERIC(16, 4),
    timeframe TEXT NOT NULL DEFAULT '15m',
    chart_url TEXT
);

CREATE TABLE IF NOT EXISTS community_post_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE ON UPDATE CASCADE,
    kind TEXT NOT NULL,
    ref_id TEXT NOT NULL,
    title TEXT NOT NULL,
    url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS community_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE ON UPDATE CASCADE,
    author_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    parent_id UUID REFERENCES community_comments(id) ON DELETE CASCADE ON UPDATE CASCADE,
    body TEXT NOT NULL,
    likes_count INTEGER NOT NULL DEFAULT 0 CHECK (likes_count >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS community_likes (
    post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS community_bookmarks (
    post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS community_reposts (
    post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    commentary TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS community_follows (
    follower_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    following_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (follower_id, following_id),
    CHECK (follower_id <> following_id)
);

CREATE TABLE IF NOT EXISTS community_polls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID UNIQUE NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE ON UPDATE CASCADE,
    question TEXT NOT NULL,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS community_poll_options (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id UUID NOT NULL REFERENCES community_polls(id) ON DELETE CASCADE ON UPDATE CASCADE,
    option_text TEXT NOT NULL,
    votes_count INTEGER NOT NULL DEFAULT 0 CHECK (votes_count >= 0)
);

CREATE TABLE IF NOT EXISTS community_poll_votes (
    poll_id UUID NOT NULL REFERENCES community_polls(id) ON DELETE CASCADE ON UPDATE CASCADE,
    option_id UUID NOT NULL REFERENCES community_poll_options(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (poll_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_community_posts_channel_created ON community_posts(channel_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_posts_author ON community_posts(author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_posts_tickers ON community_posts USING GIN(tickers);
CREATE INDEX IF NOT EXISTS idx_community_posts_tags ON community_posts USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_community_comments_post_created ON community_comments(post_id, created_at ASC);

CREATE OR REPLACE FUNCTION update_community_post_likes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE community_posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE community_posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_community_post_likes ON community_likes;
CREATE TRIGGER trigger_community_post_likes
    AFTER INSERT OR DELETE ON community_likes
    FOR EACH ROW EXECUTE FUNCTION update_community_post_likes();

CREATE OR REPLACE FUNCTION update_community_post_comments()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE community_posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE community_posts SET comments_count = GREATEST(0, comments_count - 1) WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_community_post_comments ON community_comments;
CREATE TRIGGER trigger_community_post_comments
    AFTER INSERT OR DELETE ON community_comments
    FOR EACH ROW EXECUTE FUNCTION update_community_post_comments();

COMMIT;

-- ============================================================================
-- 020: Universal Bidirectional Link Graph
-- ============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS universal_link_edges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    source_kind TEXT NOT NULL
        CHECK (source_kind IN ('note', 'journal', 'strategy', 'aiCopilot', 'communityPost', 'messageThread', 'ticker', 'trader')),
    source_id TEXT NOT NULL,
    target_kind TEXT NOT NULL
        CHECK (target_kind IN ('note', 'journal', 'strategy', 'aiCopilot', 'communityPost', 'messageThread', 'ticker', 'trader')),
    target_id TEXT NOT NULL,
    label TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, source_kind, source_id, target_kind, target_id)
);

CREATE INDEX IF NOT EXISTS idx_universal_links_source 
    ON universal_link_edges(user_id, source_kind, source_id);

CREATE INDEX IF NOT EXISTS idx_universal_links_target 
    ON universal_link_edges(user_id, target_kind, target_id);

CREATE OR REPLACE FUNCTION create_universal_link(
    p_src_kind TEXT,
    p_src_id TEXT,
    p_tgt_kind TEXT,
    p_tgt_id TEXT,
    p_label TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
    v_user UUID := auth.uid();
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_src_kind = p_tgt_kind AND p_src_id = p_tgt_id THEN
        RETURN;
    END IF;

    INSERT INTO universal_link_edges (user_id, source_kind, source_id, target_kind, target_id, label, metadata)
    VALUES (v_user, p_src_kind, p_src_id, p_tgt_kind, p_tgt_id, p_label, p_metadata)
    ON CONFLICT (user_id, source_kind, source_id, target_kind, target_id) DO NOTHING;

    INSERT INTO universal_link_edges (user_id, source_kind, source_id, target_kind, target_id, label, metadata)
    VALUES (v_user, p_tgt_kind, p_tgt_id, p_src_kind, p_src_id, p_label, p_metadata)
    ON CONFLICT (user_id, source_kind, source_id, target_kind, target_id) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION delete_universal_link(
    p_src_kind TEXT,
    p_src_id TEXT,
    p_tgt_kind TEXT,
    p_tgt_id TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
    v_user UUID := auth.uid();
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    DELETE FROM universal_link_edges
    WHERE user_id = v_user
      AND ((source_kind = p_src_kind AND source_id = p_src_id AND target_kind = p_tgt_kind AND target_id = p_tgt_id)
        OR (source_kind = p_tgt_kind AND source_id = p_tgt_id AND target_kind = p_src_kind AND target_id = p_src_id));
END;
$$;

CREATE OR REPLACE FUNCTION get_universal_links(
    p_kind TEXT,
    p_id TEXT
)
RETURNS TABLE (
    id UUID,
    target_kind TEXT,
    target_id TEXT,
    label TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
    SELECT 
        id,
        target_kind,
        target_id,
        label,
        metadata,
        created_at
    FROM universal_link_edges
    WHERE user_id = auth.uid()
      AND source_kind = p_kind
      AND source_id = p_id
    ORDER BY created_at DESC;
$$;

-- ============================================================================
-- 021 Unified Comments & Visibility
-- ============================================================================

ALTER TABLE journal_entries 
  ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_journal_entries_public ON journal_entries(is_public) WHERE is_public = true;

ALTER TABLE community_posts 
  ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'public' 
    CHECK (visibility IN ('public', 'unlisted', 'private'));

CREATE INDEX IF NOT EXISTS idx_community_posts_visibility ON community_posts(visibility, is_public);

CREATE TABLE IF NOT EXISTS unified_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type TEXT NOT NULL CHECK (entity_type IN ('note', 'strategy', 'journal', 'post')),
    entity_id TEXT NOT NULL,
    author_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    parent_id UUID REFERENCES unified_comments(id) ON DELETE CASCADE ON UPDATE CASCADE,
    body TEXT NOT NULL CHECK (length(trim(body)) > 0),
    sentiment TEXT CHECK (sentiment IS NULL OR sentiment IN ('BULLISH', 'BEARISH', 'NEUTRAL')),
    likes_count INTEGER NOT NULL DEFAULT 0 CHECK (likes_count >= 0),
    reply_count INTEGER NOT NULL DEFAULT 0 CHECK (reply_count >= 0),
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS unified_comment_likes (
    comment_id UUID NOT NULL REFERENCES unified_comments(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    reaction TEXT NOT NULL DEFAULT '👍' CHECK (reaction IN ('👍', '🚀', '💡', '🔥', '❤️')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (comment_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_unified_comments_entity 
  ON unified_comments(entity_type, entity_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_unified_comments_parent 
  ON unified_comments(parent_id) 
  WHERE parent_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_unified_comments_author 
  ON unified_comments(author_id);

CREATE INDEX IF NOT EXISTS idx_unified_comment_likes_user 
  ON unified_comment_likes(user_id);

CREATE OR REPLACE FUNCTION trg_unified_comments_reply_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.parent_id IS NOT NULL THEN
        UPDATE unified_comments
        SET reply_count = reply_count + 1
        WHERE id = NEW.parent_id;
    ELSIF TG_OP = 'DELETE' AND OLD.parent_id IS NOT NULL THEN
        UPDATE unified_comments
        SET reply_count = GREATEST(0, reply_count - 1)
        WHERE id = OLD.parent_id;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS unified_comments_reply_count_trg ON unified_comments;
CREATE TRIGGER unified_comments_reply_count_trg
AFTER INSERT OR DELETE ON unified_comments
FOR EACH ROW EXECUTE FUNCTION trg_unified_comments_reply_count();

CREATE OR REPLACE FUNCTION trg_unified_comment_likes_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE unified_comments
        SET likes_count = likes_count + 1
        WHERE id = NEW.comment_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE unified_comments
        SET likes_count = GREATEST(0, likes_count - 1)
        WHERE id = OLD.comment_id;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS unified_comment_likes_count_trg ON unified_comment_likes;
CREATE TRIGGER unified_comment_likes_count_trg
AFTER INSERT OR DELETE ON unified_comment_likes
FOR EACH ROW EXECUTE FUNCTION trg_unified_comment_likes_count();

CREATE OR REPLACE FUNCTION set_entity_visibility(
    p_entity_type TEXT,
    p_entity_id TEXT,
    p_is_public BOOLEAN
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
    v_user UUID := auth.uid();
    v_rows_affected INTEGER := 0;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    CASE p_entity_type
        WHEN 'note' THEN
            UPDATE trader_notes
            SET is_public = p_is_public, updated_at = now()
            WHERE id = p_entity_id::uuid AND user_id = v_user;
            GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

        WHEN 'strategy' THEN
            UPDATE strategies
            SET visibility = (CASE WHEN p_is_public THEN 'public' ELSE 'private' END),
                updated_at = now()
            WHERE id = p_entity_id::uuid AND user_id = v_user;
            GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

        WHEN 'journal' THEN
            UPDATE journal_entries
            SET is_public = p_is_public, updated_at = now()
            WHERE id = p_entity_id::uuid AND user_id = v_user;
            GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

        WHEN 'post' THEN
            UPDATE community_posts
            SET is_public = p_is_public,
                visibility = (CASE WHEN p_is_public THEN 'public' ELSE 'private' END),
                updated_at = now()
            WHERE id = p_entity_id::uuid AND author_id = v_user;
            GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

        ELSE
            RAISE EXCEPTION 'Invalid entity type: %', p_entity_type;
    END CASE;

    RETURN (v_rows_affected > 0);
END;
$$;

CREATE OR REPLACE FUNCTION add_entity_comment(
    p_entity_type TEXT,
    p_entity_id TEXT,
    p_body TEXT,
    p_parent_id UUID DEFAULT NULL,
    p_sentiment TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
    v_user UUID := auth.uid();
    v_comment_id UUID;
    v_is_public BOOLEAN := false;
    v_owner_id UUID;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF length(trim(p_body)) = 0 THEN
        RAISE EXCEPTION 'Comment body cannot be empty';
    END IF;

    CASE p_entity_type
        WHEN 'note' THEN
            SELECT is_public, user_id INTO v_is_public, v_owner_id
            FROM trader_notes WHERE id = p_entity_id::uuid;
        WHEN 'strategy' THEN
            SELECT (visibility = 'public'), user_id INTO v_is_public, v_owner_id
            FROM strategies WHERE id = p_entity_id::uuid;
        WHEN 'journal' THEN
            SELECT is_public, user_id INTO v_is_public, v_owner_id
            FROM journal_entries WHERE id = p_entity_id::uuid;
        WHEN 'post' THEN
            SELECT is_public, author_id INTO v_is_public, v_owner_id
            FROM community_posts WHERE id = p_entity_id::uuid;
        ELSE
            RAISE EXCEPTION 'Invalid entity type: %', p_entity_type;
    END CASE;

    IF NOT v_is_public AND v_owner_id <> v_user THEN
        RAISE EXCEPTION 'Cannot comment on private % belonging to another user', p_entity_type;
    END IF;

    INSERT INTO unified_comments (
        entity_type,
        entity_id,
        author_id,
        parent_id,
        body,
        sentiment
    )
    VALUES (
        p_entity_type,
        p_entity_id,
        v_user,
        p_parent_id,
        trim(p_body),
        p_sentiment
    )
    RETURNING id INTO v_comment_id;

    RETURN v_comment_id;
END;
$$;

CREATE OR REPLACE FUNCTION toggle_entity_comment_like(
    p_comment_id UUID,
    p_reaction TEXT DEFAULT '👍'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
    v_user UUID := auth.uid();
    v_existing TEXT;
    v_liked BOOLEAN;
    v_likes_count INTEGER;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT reaction INTO v_existing
    FROM unified_comment_likes
    WHERE comment_id = p_comment_id AND user_id = v_user;

    IF v_existing IS NOT NULL AND v_existing = p_reaction THEN
        DELETE FROM unified_comment_likes
        WHERE comment_id = p_comment_id AND user_id = v_user;
        v_liked := false;
    ELSE
        INSERT INTO unified_comment_likes (comment_id, user_id, reaction)
        VALUES (p_comment_id, v_user, p_reaction)
        ON CONFLICT (comment_id, user_id)
        DO UPDATE SET reaction = EXCLUDED.reaction, created_at = now();
        v_liked := true;
    END IF;

    SELECT likes_count INTO v_likes_count
    FROM unified_comments WHERE id = p_comment_id;

    RETURN jsonb_build_object(
        'liked', v_liked,
        'reaction', (CASE WHEN v_liked THEN p_reaction ELSE NULL END),
        'likes_count', COALESCE(v_likes_count, 0)
    );
END;
$$;

-- ---------------------------------------------------------------------------
-- 022 Live Audio Spaces & Trading Floors
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS community_live_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    host_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    title TEXT NOT NULL CHECK (length(trim(title)) > 0),
    topic TEXT NOT NULL DEFAULT '',
    category TEXT NOT NULL DEFAULT 'Options Trading',
    status TEXT NOT NULL DEFAULT 'live' CHECK (status IN ('live', 'scheduled', 'ended')),
    listener_count INTEGER NOT NULL DEFAULT 1 CHECK (listener_count >= 0),
    speaker_count INTEGER NOT NULL DEFAULT 1 CHECK (speaker_count >= 1),
    started_at TIMESTAMPTZ,
    scheduled_for TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    recording_available BOOLEAN NOT NULL DEFAULT true,
    recording_url TEXT,
    tags TEXT[] NOT NULL DEFAULT '{}',
    pinned_ticker TEXT,
    pinned_side TEXT CHECK (pinned_side IS NULL OR pinned_side IN ('LONG', 'SHORT')),
    pinned_entry NUMERIC(16, 4),
    pinned_stop_loss NUMERIC(16, 4),
    pinned_target NUMERIC(16, 4),
    pinned_note TEXT,
    poll_bullish_votes INTEGER NOT NULL DEFAULT 0 CHECK (poll_bullish_votes >= 0),
    poll_bearish_votes INTEGER NOT NULL DEFAULT 0 CHECK (poll_bearish_votes >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS community_live_room_participants (
    room_id UUID NOT NULL REFERENCES community_live_rooms(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    role TEXT NOT NULL DEFAULT 'listener' CHECK (role IN ('host', 'cohost', 'speaker', 'listener')),
    is_muted BOOLEAN NOT NULL DEFAULT true,
    is_hand_raised BOOLEAN NOT NULL DEFAULT false,
    hand_raised_at TIMESTAMPTZ,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (room_id, user_id)
);

CREATE TABLE IF NOT EXISTS community_live_room_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES community_live_rooms(id) ON DELETE CASCADE ON UPDATE CASCADE,
    sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    message TEXT NOT NULL CHECK (length(trim(message)) > 0),
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS community_live_room_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES community_live_rooms(id) ON DELETE CASCADE ON UPDATE CASCADE,
    author_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    question TEXT NOT NULL CHECK (length(trim(question)) > 0),
    upvotes_count INTEGER NOT NULL DEFAULT 0 CHECK (upvotes_count >= 0),
    is_answered BOOLEAN NOT NULL DEFAULT false,
    answered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS community_live_room_question_upvotes (
    question_id UUID NOT NULL REFERENCES community_live_room_questions(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (question_id, user_id)
);

CREATE TABLE IF NOT EXISTS community_live_room_reminders (
    room_id UUID NOT NULL REFERENCES community_live_rooms(id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    notified BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (room_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_community_live_rooms_status ON community_live_rooms(status, scheduled_for, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_live_rooms_host ON community_live_rooms(host_id);
CREATE INDEX IF NOT EXISTS idx_community_live_room_participants_room ON community_live_room_participants(room_id, role);
CREATE INDEX IF NOT EXISTS idx_community_live_room_messages_room ON community_live_room_messages(room_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_live_room_questions_room ON community_live_room_questions(room_id, is_answered, upvotes_count DESC);
CREATE INDEX IF NOT EXISTS idx_community_live_room_reminders_user ON community_live_room_reminders(user_id);

COMMIT;



-- Public catalogue and complete asset detail contract (migration 023).
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

BEGIN;
-- ============================================================================
-- DEDICATED RELATIONAL TICKER LINK TABLE
-- ============================================================================
-- Stores persistent links whenever a market ticker is referenced across
-- Notes, Journal, Strategies, Community Posts, and Messages. Prevents
-- irregularities during daily quote updates, price refreshes, or symbol updates.
CREATE TABLE IF NOT EXISTS entity_ticker_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    entity_type TEXT NOT NULL
        CHECK (entity_type IN ('note', 'journal', 'strategy', 'community_post', 'message')),
    entity_id TEXT NOT NULL,
    ticker VARCHAR(20) NOT NULL,
    context_source TEXT NOT NULL DEFAULT 'inline',
    price_at_link NUMERIC,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, entity_type, entity_id, ticker)
);

CREATE INDEX IF NOT EXISTS idx_entity_ticker_links_ticker
    ON entity_ticker_links(ticker);
CREATE INDEX IF NOT EXISTS idx_entity_ticker_links_user
    ON entity_ticker_links(user_id);
CREATE INDEX IF NOT EXISTS idx_entity_ticker_links_entity
    ON entity_ticker_links(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_entity_ticker_links_user_ticker
    ON entity_ticker_links(user_id, ticker);
CREATE INDEX IF NOT EXISTS idx_entity_ticker_links_created
    ON entity_ticker_links(created_at DESC);

ALTER TABLE entity_ticker_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS entity_ticker_links_select ON entity_ticker_links;
CREATE POLICY entity_ticker_links_select ON entity_ticker_links
    FOR SELECT TO authenticated
    USING (
        auth.uid() = user_id
        OR entity_type = 'community_post'
    );

DROP POLICY IF EXISTS entity_ticker_links_insert ON entity_ticker_links;
CREATE POLICY entity_ticker_links_insert ON entity_ticker_links
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS entity_ticker_links_update ON entity_ticker_links;
CREATE POLICY entity_ticker_links_update ON entity_ticker_links
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS entity_ticker_links_delete ON entity_ticker_links;
CREATE POLICY entity_ticker_links_delete ON entity_ticker_links
    FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

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

COMMIT;

