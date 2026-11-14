-- Migration 028: Consolidated Supabase Schema Synchronization & Bug Fixes
-- Resolves:
-- 1. Infinite recursion in chat_participants RLS (PGRST / code 42P17)
-- 2. Missing affiliate_workspace() RPC & affiliate_campaigns / affiliate_assets (PGRST202 / PGRST205)
-- 3. Missing desk_risk_breaches, admin_audit_logs, desk_order_approvals, desk_risk_configs (PGRST205)
-- 4. Missing account_deletion_requests, affiliate_commission_tiers, affiliate_program_terms
-- 5. Safe 100% INR defaults & TDS / GST column additions across affiliate profiles & payouts

-- ============================================================================
-- 1. FIX INFINITE RECURSION IN CHAT PARTICIPANTS & REALTIME MESSAGING RLS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.user_is_chat_participant(p_thread_id uuid, p_user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT auth.uid() IS NOT NULL
    AND p_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.chat_participants
      WHERE thread_id = p_thread_id AND user_id = auth.uid()
    );
$$;

REVOKE ALL ON FUNCTION public.user_is_chat_participant(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.user_is_chat_participant(uuid, uuid) TO authenticated, service_role;

DROP POLICY IF EXISTS "Users can view threads they belong to" ON public.chat_threads;
DROP POLICY IF EXISTS chat_threads_select ON public.chat_threads;
CREATE POLICY chat_threads_select ON public.chat_threads FOR SELECT
  USING (created_by = auth.uid() OR public.user_is_chat_participant(id, auth.uid()));

DROP POLICY IF EXISTS "Users can update threads they belong to" ON public.chat_threads;
DROP POLICY IF EXISTS chat_threads_update ON public.chat_threads;
CREATE POLICY chat_threads_update ON public.chat_threads FOR UPDATE
  USING (created_by = auth.uid() OR public.user_is_chat_participant(id, auth.uid()));

DROP POLICY IF EXISTS "Users can view participants of their threads" ON public.chat_participants;
DROP POLICY IF EXISTS chat_participants_select ON public.chat_participants;
CREATE POLICY chat_participants_select ON public.chat_participants FOR SELECT
  USING (user_id = auth.uid() OR public.user_is_chat_participant(thread_id, auth.uid()));

DROP POLICY IF EXISTS "Users can add/leave thread participants" ON public.chat_participants;
DROP POLICY IF EXISTS chat_participants_manage ON public.chat_participants;
CREATE POLICY chat_participants_manage ON public.chat_participants FOR ALL
  USING (auth.uid() = user_id OR public.user_is_chat_participant(thread_id, auth.uid()))
  WITH CHECK (auth.uid() = user_id OR public.user_is_chat_participant(thread_id, auth.uid()));

DROP POLICY IF EXISTS "Users can view messages in their threads" ON public.chat_messages;
DROP POLICY IF EXISTS chat_messages_select ON public.chat_messages;
CREATE POLICY chat_messages_select ON public.chat_messages FOR SELECT
  USING (sender_id = auth.uid() OR public.user_is_chat_participant(thread_id, auth.uid()));


-- ============================================================================
-- 2. AFFILIATE PROGRAM: INR ENHANCEMENTS, CAMPAIGNS, TIERS & PROGRAM TERMS
-- ============================================================================

-- Safe column additions to affiliate_profiles
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS custom_slug text UNIQUE;
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS minimum_payout_threshold numeric NOT NULL DEFAULT 1000;
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS auto_payout_enabled boolean NOT NULL DEFAULT false;
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'INR';
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS tds_rate numeric NOT NULL DEFAULT 0.05 CHECK (tds_rate >= 0 AND tds_rate <= 0.30);
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS gst_registered boolean NOT NULL DEFAULT false;
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS gstin text;
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS pan_number text;
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS terms_version_accepted text NOT NULL DEFAULT '2026.1-INR';
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS terms_accepted_at timestamptz DEFAULT now();

ALTER TABLE public.affiliate_profiles DROP CONSTRAINT IF EXISTS affiliate_profiles_payout_method_check;
ALTER TABLE public.affiliate_profiles ADD CONSTRAINT affiliate_profiles_payout_method_check
  CHECK (payout_method IN ('upi', 'bank_neft', 'bank_imps', 'bank_rtgs', 'bank_transfer', 'bank_wire', 'razorpay', 'paypal', 'stripe', 'crypto'));

-- Affiliate campaigns table
CREATE TABLE IF NOT EXISTS public.affiliate_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id uuid NOT NULL REFERENCES public.affiliate_profiles(id) ON DELETE CASCADE,
  name text NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 80),
  slug text NOT NULL CHECK (slug ~ '^[a-z0-9][a-z0-9-]{2,39}$'),
  channel text NOT NULL CHECK (channel IN ('youtube', 'newsletter', 'instagram', 'website', 'other')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused')),
  clicks bigint NOT NULL DEFAULT 0 CHECK (clicks >= 0),
  conversions_count bigint NOT NULL DEFAULT 0 CHECK (conversions_count >= 0),
  revenue_generated_inr numeric NOT NULL DEFAULT 0 CHECK (revenue_generated_inr >= 0),
  target_path text NOT NULL DEFAULT '/signup',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (affiliate_id, slug)
);

-- Affiliate assets table
CREATE TABLE IF NOT EXISTS public.affiliate_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  format text NOT NULL,
  body text NOT NULL,
  published boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Affiliate click receipts
CREATE TABLE IF NOT EXISTS public.affiliate_click_receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid REFERENCES public.affiliate_campaigns(id) ON DELETE CASCADE,
  visitor_hash text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (campaign_id, visitor_hash)
);

-- Safe column additions to affiliate_referrals
ALTER TABLE public.affiliate_referrals ADD COLUMN IF NOT EXISTS channel text NOT NULL DEFAULT 'direct';
ALTER TABLE public.affiliate_referrals ADD COLUMN IF NOT EXISTS campaign_id uuid REFERENCES public.affiliate_campaigns(id) ON DELETE SET NULL;
ALTER TABLE public.affiliate_referrals ADD COLUMN IF NOT EXISTS plan_tier text NOT NULL DEFAULT 'pro';
ALTER TABLE public.affiliate_referrals ADD COLUMN IF NOT EXISTS subscription_amount_inr numeric NOT NULL DEFAULT 2499.00;
ALTER TABLE public.affiliate_referrals ADD COLUMN IF NOT EXISTS commission_rate numeric NOT NULL DEFAULT 0.25;
ALTER TABLE public.affiliate_referrals ADD COLUMN IF NOT EXISTS tds_deducted_inr numeric NOT NULL DEFAULT 0.00;
ALTER TABLE public.affiliate_referrals ADD COLUMN IF NOT EXISTS net_commission_inr numeric NOT NULL DEFAULT 0.00;

-- Safe column additions to affiliate_payouts
ALTER TABLE public.affiliate_payouts ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'INR';
ALTER TABLE public.affiliate_payouts ADD COLUMN IF NOT EXISTS payout_destination jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE public.affiliate_payouts ADD COLUMN IF NOT EXISTS balance_reserved boolean NOT NULL DEFAULT false;
ALTER TABLE public.affiliate_payouts ADD COLUMN IF NOT EXISTS gross_amount_inr numeric;
ALTER TABLE public.affiliate_payouts ADD COLUMN IF NOT EXISTS tds_amount_inr numeric NOT NULL DEFAULT 0.00;
ALTER TABLE public.affiliate_payouts ADD COLUMN IF NOT EXISTS net_amount_inr numeric;
ALTER TABLE public.affiliate_payouts ADD COLUMN IF NOT EXISTS utr_number text;

-- Dynamic commission tiers table
CREATE TABLE IF NOT EXISTS public.affiliate_commission_tiers (
  tier_code text PRIMARY KEY CHECK (tier_code IN ('standard', 'silver', 'gold', 'platinum')),
  display_name text NOT NULL,
  commission_rate numeric NOT NULL CHECK (commission_rate > 0 AND commission_rate <= 1.0),
  min_active_referrals integer NOT NULL DEFAULT 0 CHECK (min_active_referrals >= 0),
  min_monthly_volume_inr numeric NOT NULL DEFAULT 0 CHECK (min_monthly_volume_inr >= 0),
  min_payout_threshold_inr numeric NOT NULL DEFAULT 1000 CHECK (min_payout_threshold_inr >= 100),
  tds_rate numeric NOT NULL DEFAULT 0.05 CHECK (tds_rate >= 0 AND tds_rate <= 0.30),
  settlement_cycle text NOT NULL DEFAULT 'T+2 Bank NEFT / Instant UPI',
  perks text[] NOT NULL DEFAULT '{}'::text[],
  sort_order integer NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.affiliate_commission_tiers (
  tier_code, display_name, commission_rate, min_active_referrals,
  min_monthly_volume_inr, min_payout_threshold_inr, tds_rate, settlement_cycle, perks, sort_order
) VALUES
  ('standard', 'Tier 1 · Standard Partner', 0.15, 0, 0, 1000, 0.05, 'Weekly NEFT / UPI (Min ₹1,000)', ARRAY['15% recurring INR revenue share', 'Custom referral slug & UTM builder', 'UPI & NEFT payouts in INR (₹)', 'Standard creator media kit'], 1),
  ('silver', 'Tier 2 · Silver Growth Partner', 0.20, 10, 25000, 1000, 0.05, 'Bi-weekly IMPS / UPI (Min ₹1,000)', ARRAY['20% recurring INR revenue share', 'Complimentary TradeX Pro workspace (₹2,499/mo value)', 'Priority partner verification badge', 'Co-branded landing page banner'], 2),
  ('gold', 'Tier 3 · Gold Pro Partner', 0.25, 25, 75000, 1000, 0.05, 'T+2 Priority IMPS / UPI (Min ₹1,000)', ARRAY['25% recurring INR revenue share', '20% referral discount code for audience', 'Dedicated partner manager & custom creatives', 'Automated monthly GST & Form 16A TDS statements'], 3),
  ('platinum', 'Tier 4 · Institutional Desk Partner', 0.35, 50, 200000, 1000, 0.05, 'Instant UPI / RTGS Desk Settlement', ARRAY['35% recurring INR revenue share', 'Complimentary Enterprise Desk seat (₹7,999/mo value)', 'Custom webinar & workshop sponsorship in INR', 'Direct API attribution & bespoke rev-share splits'], 4)
ON CONFLICT (tier_code) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  commission_rate = EXCLUDED.commission_rate,
  min_active_referrals = EXCLUDED.min_active_referrals,
  min_monthly_volume_inr = EXCLUDED.min_monthly_volume_inr,
  min_payout_threshold_inr = EXCLUDED.min_payout_threshold_inr,
  tds_rate = EXCLUDED.tds_rate,
  settlement_cycle = EXCLUDED.settlement_cycle,
  perks = EXCLUDED.perks,
  sort_order = EXCLUDED.sort_order,
  updated_at = now();

-- Dynamic affiliate program terms
CREATE TABLE IF NOT EXISTS public.affiliate_program_terms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clause_code text UNIQUE NOT NULL,
  version text NOT NULL DEFAULT '2026.1-INR',
  title text NOT NULL,
  category text NOT NULL CHECK (category IN ('payouts_tax', 'attribution', 'compliance_sebi', 'conduct', 'termination')),
  summary text NOT NULL,
  body text NOT NULL,
  mandatory boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 1,
  effective_from timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.affiliate_program_terms (
  clause_code, version, title, category, summary, body, mandatory, sort_order
) VALUES
  ('INR-SETTLEMENT-01', '2026.1-INR', '100% INR (₹) Settlement & Minimum Threshold', 'payouts_tax', 'All commissions, bonuses, and settlements are denominated and paid exclusively in Indian Rupees (₹ INR).', 'Commissions are calculated as a percentage of net qualifying subscription revenue collected in INR (excluding 18% GST). Minimum withdrawal threshold is ₹1,000 INR. Supported payout rails are NPCI UPI (VPA), Bank NEFT, IMPS, and RTGS with verified IFSC.', true, 1),
  ('TDS-GST-02', '2026.1-INR', 'Indian Tax Deduction at Source (TDS u/s 194H) & GST Compliance', 'payouts_tax', '5% statutory TDS applies under Section 194H of the Income Tax Act; GST-registered partners may submit GSTIN.', 'In accordance with Section 194H of the Indian Income Tax Act, 1961, TradeX deducts 5% TDS on gross affiliate commission payouts where applicable and issues quarterly Form 16A certificates against your verified PAN.', true, 2),
  ('ATTRIBUTION-COOKIE-03', '2026.1-INR', '30-Day First-Party Referral Attribution & Qualifying Conversions', 'attribution', '30-day attribution window on /r/:slug links with UTM campaign tracking.', 'When a prospective trader visits your referral link (/r/:code?utm_campaign=:slug), attribution is persisted for 30 days. Commissions credit to unpaid INR balance once the referred subscriber completes a verified subscription.', true, 3),
  ('SEBI-ASCI-COMPLIANCE-04', '2026.1-INR', 'SEBI & ASCI Finfluencer Disclosure Mandate', 'compliance_sebi', 'Mandatory affiliate disclosure and prohibition on guaranteed return claims or unregistered investment advice.', 'Partners must clearly disclose that their link is a commercial referral link in accordance with ASCI Guidelines. Partners must never promise guaranteed trading profits or represent TradeX as SEBI-registered advisory tips.', true, 4),
  ('ANTI-ABUSE-05', '2026.1-INR', 'Prohibition of Self-Referrals, Brand Bidding & Coupon Spoofing', 'conduct', 'Self-referrals, paid search bidding on TradeX brand keywords, and coupon spoofing are strictly prohibited.', 'Accounts found referring their own trading seats or running search ads targeting TradeX brand terms without authorization will have pending commissions forfeited.', true, 5)
ON CONFLICT (clause_code) DO UPDATE SET
  version = EXCLUDED.version,
  title = EXCLUDED.title,
  category = EXCLUDED.category,
  summary = EXCLUDED.summary,
  body = EXCLUDED.body,
  mandatory = EXCLUDED.mandatory,
  sort_order = EXCLUDED.sort_order,
  updated_at = now();

-- Enable RLS and grants for affiliate workspace tables
ALTER TABLE public.affiliate_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.affiliate_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.affiliate_click_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.affiliate_commission_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.affiliate_program_terms ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.affiliate_campaigns, public.affiliate_assets, public.affiliate_commission_tiers, public.affiliate_program_terms TO authenticated, anon;
GRANT INSERT, UPDATE, DELETE ON public.affiliate_campaigns TO authenticated;
GRANT ALL ON public.affiliate_campaigns, public.affiliate_assets, public.affiliate_click_receipts, public.affiliate_commission_tiers, public.affiliate_program_terms TO service_role;

DROP POLICY IF EXISTS affiliate_campaign_read ON public.affiliate_campaigns;
CREATE POLICY affiliate_campaign_read ON public.affiliate_campaigns FOR SELECT TO authenticated
  USING (affiliate_id = auth.uid());

DROP POLICY IF EXISTS affiliate_campaign_insert ON public.affiliate_campaigns;
CREATE POLICY affiliate_campaign_insert ON public.affiliate_campaigns FOR INSERT TO authenticated
  WITH CHECK (affiliate_id = auth.uid());

DROP POLICY IF EXISTS affiliate_campaign_update ON public.affiliate_campaigns;
CREATE POLICY affiliate_campaign_update ON public.affiliate_campaigns FOR UPDATE TO authenticated
  USING (affiliate_id = auth.uid()) WITH CHECK (affiliate_id = auth.uid());

DROP POLICY IF EXISTS affiliate_assets_read ON public.affiliate_assets;
CREATE POLICY affiliate_assets_read ON public.affiliate_assets FOR SELECT TO authenticated, anon
  USING (published OR auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS affiliate_commission_tiers_read ON public.affiliate_commission_tiers;
CREATE POLICY affiliate_commission_tiers_read ON public.affiliate_commission_tiers FOR SELECT TO authenticated, anon
  USING (true);

DROP POLICY IF EXISTS affiliate_program_terms_read ON public.affiliate_program_terms;
CREATE POLICY affiliate_program_terms_read ON public.affiliate_program_terms FOR SELECT TO authenticated, anon
  USING (true);

-- The affiliate_workspace() RPC Function
CREATE OR REPLACE FUNCTION public.affiliate_workspace() RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$
  SELECT jsonb_build_object(
    'profile', (SELECT to_jsonb(p) FROM public.affiliate_profiles p WHERE p.id = (SELECT auth.uid())),
    'campaigns', COALESCE((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.created_at DESC) FROM public.affiliate_campaigns c WHERE c.affiliate_id = (SELECT auth.uid())), '[]'::jsonb),
    'referrals', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', r.id, 'referral_code', r.referral_code, 'status', r.status, 'bonus_awarded', r.bonus_awarded, 'channel', r.channel, 'campaign_id', r.campaign_id, 'plan_tier', r.plan_tier, 'created_at', r.created_at) ORDER BY r.created_at DESC) FROM public.affiliate_referrals r WHERE r.affiliate_id = (SELECT auth.uid())), '[]'::jsonb),
    'payouts', COALESCE((SELECT jsonb_agg(to_jsonb(p) ORDER BY p.created_at DESC) FROM public.affiliate_payouts p WHERE p.affiliate_id = (SELECT auth.uid())), '[]'::jsonb),
    'assets', COALESCE((SELECT jsonb_agg(to_jsonb(a) ORDER BY a.created_at) FROM public.affiliate_assets a WHERE a.published), '[]'::jsonb),
    'tiers', COALESCE((SELECT jsonb_agg(to_jsonb(t) ORDER BY t.sort_order) FROM public.affiliate_commission_tiers t), '[]'::jsonb),
    'terms', COALESCE((SELECT jsonb_agg(to_jsonb(tm) ORDER BY tm.sort_order) FROM public.affiliate_program_terms tm), '[]'::jsonb)
  );
$$;

REVOKE ALL ON FUNCTION public.affiliate_workspace() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.affiliate_workspace() TO authenticated, service_role;


-- ============================================================================
-- 3. INSTITUTIONAL ADMIN CONSOLE & RISK GOVERNANCE TABLES
-- ============================================================================

-- Desk risk configurations table
CREATE TABLE IF NOT EXISTS public.desk_risk_configs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_name text NOT NULL DEFAULT 'TradeX Institutional Trading Desk',
  base_currency text NOT NULL DEFAULT 'INR',
  max_firm_leverage numeric NOT NULL DEFAULT 5.0 CHECK (max_firm_leverage >= 1.0 AND max_firm_leverage <= 100.0),
  max_daily_loss_percent numeric NOT NULL DEFAULT 3.0 CHECK (max_daily_loss_percent > 0 AND max_daily_loss_percent <= 50.0),
  max_total_drawdown_percent numeric NOT NULL DEFAULT 8.0 CHECK (max_total_drawdown_percent > 0 AND max_total_drawdown_percent <= 90.0),
  circuit_breaker_threshold_percent numeric NOT NULL DEFAULT 5.0 CHECK (circuit_breaker_threshold_percent > 0),
  auto_freeze_on_breach boolean NOT NULL DEFAULT true,
  allow_crypto boolean NOT NULL DEFAULT false,
  allow_options boolean NOT NULL DEFAULT true,
  require_manager_order_approval boolean NOT NULL DEFAULT true,
  approval_threshold_inr numeric NOT NULL DEFAULT 250000 CHECK (approval_threshold_inr >= 0),
  updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Pre-trade order approval queue
CREATE TABLE IF NOT EXISTS public.desk_order_approvals (
  id text PRIMARY KEY,
  trader_user_id text NOT NULL,
  trader_handle text NOT NULL,
  trader_name text NOT NULL,
  desk_division text NOT NULL DEFAULT 'Options & Derivatives',
  symbol text NOT NULL,
  exchange text NOT NULL DEFAULT 'NSE',
  side text NOT NULL CHECK (side IN ('BUY', 'SELL')),
  quantity integer NOT NULL CHECK (quantity > 0),
  order_price_inr numeric NOT NULL CHECK (order_price_inr >= 0),
  notional_value_inr numeric NOT NULL CHECK (notional_value_inr >= 0),
  leverage_x numeric NOT NULL DEFAULT 1.0,
  stop_loss_inr numeric NOT NULL DEFAULT 0,
  target_price_inr numeric NOT NULL DEFAULT 0,
  strategy_name text NOT NULL DEFAULT 'Discretionary Momentum',
  reason_flagged text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by text,
  reviewer_notes text,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Risk breaches incident log
CREATE TABLE IF NOT EXISTS public.desk_risk_breaches (
  id text PRIMARY KEY,
  trader_user_id text NOT NULL,
  trader_handle text NOT NULL,
  trader_name text NOT NULL,
  desk_division text NOT NULL DEFAULT 'Equities & Derivatives',
  breach_type text NOT NULL,
  severity text NOT NULL DEFAULT 'warning' CHECK (severity IN ('info', 'warning', 'critical')),
  symbol text NOT NULL,
  metric_value_inr numeric NOT NULL DEFAULT 0,
  threshold_value_inr numeric NOT NULL DEFAULT 0,
  description text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'acknowledged', 'resolved', 'waived')),
  resolution_notes text,
  resolved_by text,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Admin governance & execution audit log
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
  id text PRIMARY KEY,
  actor_id text NOT NULL DEFAULT 'system',
  actor_handle text NOT NULL DEFAULT 'system',
  actor_role text NOT NULL DEFAULT 'user_admin',
  category text NOT NULL,
  action text NOT NULL,
  target_type text NOT NULL,
  target_label text NOT NULL,
  severity text NOT NULL DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'critical')),
  details text NOT NULL,
  ip_address text,
  user_agent text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Account deletion requests & conditional data purge engine
CREATE TABLE IF NOT EXISTS public.account_deletion_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  user_handle text NOT NULL,
  user_email text,
  user_role text NOT NULL DEFAULT 'customer' CHECK (user_role IN ('customer', 'affiliate', 'user_admin')),
  reason text NOT NULL,
  feedback text,
  data_purge_condition text NOT NULL DEFAULT 'immediate_purge'
    CHECK (data_purge_condition IN ('immediate_purge', 'after_30_day_grace', 'purge_personal_keep_tax_ledger')),
  purge_journals_notes_strategies boolean NOT NULL DEFAULT true,
  purge_community_messages boolean NOT NULL DEFAULT true,
  purge_ai_workspace boolean NOT NULL DEFAULT true,
  purge_affiliate_campaigns boolean NOT NULL DEFAULT true,
  export_requested_before_delete boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'grace_period', 'data_purged', 'completed', 'cancelled')),
  scheduled_purge_at timestamptz NOT NULL DEFAULT now(),
  data_purged_at timestamptz,
  purged_tables_summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  review_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_desk_order_approvals_status ON public.desk_order_approvals(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_desk_risk_breaches_status ON public.desk_risk_breaches(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created ON public.admin_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_account_deletion_requests_status ON public.account_deletion_requests(status, created_at DESC);

-- Enable RLS and permissions on admin console tables
ALTER TABLE public.desk_risk_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.desk_order_approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.desk_risk_breaches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.desk_risk_configs FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.desk_risk_configs TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.desk_order_approvals TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.desk_risk_breaches TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE ON public.admin_audit_logs TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.account_deletion_requests TO authenticated, anon;

GRANT ALL ON
  public.desk_risk_configs,
  public.desk_order_approvals,
  public.desk_risk_breaches,
  public.admin_audit_logs,
  public.account_deletion_requests
TO service_role;

DROP POLICY IF EXISTS desk_risk_configs_read ON public.desk_risk_configs;
DROP POLICY IF EXISTS desk_risk_configs_write ON public.desk_risk_configs;
DROP POLICY IF EXISTS desk_risk_configs_read_policy ON public.desk_risk_configs;
CREATE POLICY desk_risk_configs_read_policy ON public.desk_risk_configs FOR SELECT TO authenticated
  USING (
    public.is_admin_caller()
    OR EXISTS (
      SELECT 1 FROM public.organization_members m
      WHERE m.user_id = (SELECT auth.uid())
        AND m.status = 'active'
    )
  );

DROP POLICY IF EXISTS desk_risk_configs_admin_write_policy ON public.desk_risk_configs;
CREATE POLICY desk_risk_configs_admin_write_policy ON public.desk_risk_configs FOR ALL TO authenticated
  USING (public.is_admin_caller())
  WITH CHECK (public.is_admin_caller());

DROP POLICY IF EXISTS desk_order_approvals_all ON public.desk_order_approvals;
CREATE POLICY desk_order_approvals_all ON public.desk_order_approvals FOR ALL TO authenticated, anon
  USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS desk_risk_breaches_all ON public.desk_risk_breaches;
CREATE POLICY desk_risk_breaches_all ON public.desk_risk_breaches FOR ALL TO authenticated, anon
  USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS admin_audit_logs_read ON public.admin_audit_logs;
CREATE POLICY admin_audit_logs_read ON public.admin_audit_logs FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS admin_audit_logs_insert ON public.admin_audit_logs;
CREATE POLICY admin_audit_logs_insert ON public.admin_audit_logs FOR INSERT TO authenticated, anon WITH CHECK (true);

DROP POLICY IF EXISTS account_deletion_requests_all ON public.account_deletion_requests;
CREATE POLICY account_deletion_requests_all ON public.account_deletion_requests FOR ALL TO authenticated, anon
  USING (true) WITH CHECK (true);

-- Insert default firm risk config row if not exists
INSERT INTO public.desk_risk_configs (
  firm_name, base_currency, max_firm_leverage, max_daily_loss_percent,
  max_total_drawdown_percent, circuit_breaker_threshold_percent, auto_freeze_on_breach,
  allow_crypto, allow_options, require_manager_order_approval, approval_threshold_inr
) VALUES (
  'TradeX Institutional Desk (NSE / BSE)', 'INR', 5.0, 3.0, 8.0, 5.0, true, false, true, true, 250000
) ON CONFLICT DO NOTHING;
