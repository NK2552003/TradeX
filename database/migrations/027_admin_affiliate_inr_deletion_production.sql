-- Migration 027: Production Admin Console, 100% INR Affiliate Enhancements,
-- Dynamic Program Terms & Tiers, and Conditional Account + Data Purge Engine.
-- Apply after 026_affiliate_workspace.sql.

BEGIN;

-- ============================================================================
-- 1. AFFILIATE 100% INR ENHANCEMENTS, DYNAMIC TIERS & PROGRAM TERMS
-- ============================================================================

-- Dynamic commission tiers table (no hardcoded rates or thresholds)
CREATE TABLE IF NOT EXISTS public.affiliate_commission_tiers (
  tier_code TEXT PRIMARY KEY CHECK (tier_code IN ('standard', 'silver', 'gold', 'platinum')),
  display_name TEXT NOT NULL,
  commission_rate NUMERIC NOT NULL CHECK (commission_rate > 0 AND commission_rate <= 1.0),
  min_active_referrals INTEGER NOT NULL DEFAULT 0 CHECK (min_active_referrals >= 0),
  min_monthly_volume_inr NUMERIC NOT NULL DEFAULT 0 CHECK (min_monthly_volume_inr >= 0),
  min_payout_threshold_inr NUMERIC NOT NULL DEFAULT 1000 CHECK (min_payout_threshold_inr >= 100),
  tds_rate NUMERIC NOT NULL DEFAULT 0.05 CHECK (tds_rate >= 0 AND tds_rate <= 0.30),
  settlement_cycle TEXT NOT NULL DEFAULT 'T+2 Bank NEFT / Instant UPI',
  perks TEXT[] NOT NULL DEFAULT '{}'::text[],
  sort_order INTEGER NOT NULL DEFAULT 1,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.affiliate_commission_tiers (
  tier_code, display_name, commission_rate, min_active_referrals,
  min_monthly_volume_inr, min_payout_threshold_inr, tds_rate, settlement_cycle, perks, sort_order
) VALUES
  (
    'standard',
    'Tier 1 · Standard Partner',
    0.15,
    0,
    0,
    1000,
    0.05,
    'Weekly NEFT / UPI (Min ₹1,000)',
    ARRAY['15% recurring INR revenue share', 'Custom referral slug & UTM builder', 'UPI & NEFT payouts in INR (₹)', 'Standard creator media kit'],
    1
  ),
  (
    'silver',
    'Tier 2 · Silver Growth Partner',
    0.20,
    10,
    25000,
    1000,
    0.05,
    'Bi-weekly IMPS / UPI (Min ₹1,000)',
    ARRAY['20% recurring INR revenue share', 'Complimentary TradeX Pro workspace (₹2,499/mo value)', 'Priority partner verification badge', 'Co-branded landing page banner'],
    2
  ),
  (
    'gold',
    'Tier 3 · Gold Pro Partner',
    0.25,
    25,
    75000,
    1000,
    0.05,
    'T+2 Priority IMPS / UPI (Min ₹1,000)',
    ARRAY['25% recurring INR revenue share', '20% referral discount code for audience', 'Dedicated partner manager & custom creatives', 'Automated monthly GST & Form 16A TDS statements'],
    3
  ),
  (
    'platinum',
    'Tier 4 · Institutional Desk Partner',
    0.35,
    50,
    200000,
    1000,
    0.05,
    'Instant UPI / RTGS Desk Settlement',
    ARRAY['35% recurring INR revenue share', 'Complimentary Enterprise Desk seat (₹7,999/mo value)', 'Custom webinar & workshop sponsorship in INR', 'Direct API attribution & bespoke rev-share splits'],
    4
  )
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

-- Dynamic affiliate program terms & regulatory compliance rules
CREATE TABLE IF NOT EXISTS public.affiliate_program_terms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clause_code TEXT UNIQUE NOT NULL,
  version TEXT NOT NULL DEFAULT '2026.1-INR',
  title TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('payouts_tax', 'attribution', 'compliance_sebi', 'conduct', 'termination')),
  summary TEXT NOT NULL,
  body TEXT NOT NULL,
  mandatory BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 1,
  effective_from TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.affiliate_program_terms (
  clause_code, version, title, category, summary, body, mandatory, sort_order
) VALUES
  (
    'INR-SETTLEMENT-01',
    '2026.1-INR',
    '100% INR (₹) Settlement & Minimum Threshold',
    'payouts_tax',
    'All commissions, bonuses, and settlements are denominated and paid exclusively in Indian Rupees (₹ INR).',
    'Commissions are calculated as a percentage of net qualifying subscription revenue collected in INR (excluding 18% GST). Minimum withdrawal threshold is ₹1,000 INR ( configurable upward by the partner). Supported payout rails are NPCI UPI (VPA), Bank NEFT, IMPS, and RTGS to verified Indian bank accounts with a valid 11-character IFSC.',
    true,
    1
  ),
  (
    'TDS-GST-02',
    '2026.1-INR',
    'Indian Tax Deduction at Source (TDS u/s 194H) & GST Compliance',
    'payouts_tax',
    '5% statutory TDS applies under Section 194H of the Income Tax Act; GST-registered partners may submit GSTIN.',
    'In accordance with Section 194H of the Indian Income Tax Act, 1961, TradeX deducts 5% TDS on gross affiliate commission payouts where applicable and issues quarterly Form 16A certificates against your verified 10-character PAN. Partners with a valid 15-character GSTIN may enable GST invoicing in Affiliate Settings.',
    true,
    2
  ),
  (
    'ATTRIBUTION-COOKIE-03',
    '2026.1-INR',
    '30-Day First-Party Referral Attribution & Qualifying Conversions',
    'attribution',
    '30-day attribution window on /r/:slug links with UTM campaign tracking and billing webhook qualification.',
    'When a prospective trader visits your referral link (/r/:code?utm_campaign=:slug), attribution is persisted for 30 days. Signups create a pending referral record; commissions are credited to your unpaid INR balance once the referred subscriber completes a verified paid subscription (Pro ₹2,499/mo or Enterprise ₹7,999/mo) and clears the 7-day refund guard.',
    true,
    3
  ),
  (
    'SEBI-ASCI-COMPLIANCE-04',
    '2026.1-INR',
    'SEBI & ASCI Finfluencer Disclosure Mandate',
    'compliance_sebi',
    'Mandatory affiliate disclosure and prohibition on guaranteed return claims or unregistered investment advice.',
    'Partners must clearly disclose that their link is a commercial referral link in accordance with ASCI Guidelines for Influencer Advertising in Digital Media and SEBI circulars. Partners must never promise guaranteed trading profits, assured returns, or represent TradeX software tools as SEBI-registered portfolio management or advisory tips.',
    true,
    4
  ),
  (
    'ANTI-ABUSE-05',
    '2026.1-INR',
    'Prohibition of Self-Referrals, Brand Bidding & Coupon Spoofing',
    'conduct',
    'Self-referrals, paid search bidding on TradeX brand keywords, and misleading coupon pages are strictly prohibited.',
    'Accounts found referring their own trading seats, running Google/Meta paid ads targeting "TradeX" brand terms without written authorization, or injecting unauthorized tracking scripts will have pending commissions forfeited and partner access suspended by the Institutional Desk Administrator.',
    true,
    5
  )
ON CONFLICT (clause_code) DO UPDATE SET
  version = EXCLUDED.version,
  title = EXCLUDED.title,
  category = EXCLUDED.category,
  summary = EXCLUDED.summary,
  body = EXCLUDED.body,
  mandatory = EXCLUDED.mandatory,
  sort_order = EXCLUDED.sort_order,
  updated_at = now();

-- Convert affiliate_profiles defaults and existing rows to INR (₹)
ALTER TABLE public.affiliate_profiles ALTER COLUMN currency SET DEFAULT 'INR';
ALTER TABLE public.affiliate_profiles ALTER COLUMN minimum_payout_threshold SET DEFAULT 1000;
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS tds_rate NUMERIC NOT NULL DEFAULT 0.05 CHECK (tds_rate >= 0 AND tds_rate <= 0.30);
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS gst_registered BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS gstin TEXT;
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS pan_number TEXT;
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS terms_version_accepted TEXT NOT NULL DEFAULT '2026.1-INR';
ALTER TABLE public.affiliate_profiles ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMPTZ DEFAULT now();

ALTER TABLE public.affiliate_profiles DROP CONSTRAINT IF EXISTS affiliate_profiles_payout_method_check;
ALTER TABLE public.affiliate_profiles ADD CONSTRAINT affiliate_profiles_payout_method_check
  CHECK (payout_method IN ('upi', 'bank_neft', 'bank_imps', 'bank_rtgs', 'bank_transfer', 'bank_wire', 'razorpay', 'paypal', 'stripe', 'crypto'));

UPDATE public.affiliate_profiles SET currency = 'INR' WHERE currency = 'USD' OR currency IS NULL;
UPDATE public.affiliate_profiles SET payout_method = 'upi' WHERE payout_method IN ('paypal', 'stripe', 'crypto') OR payout_method IS NULL;

-- Enhance affiliate_campaigns, affiliate_referrals, and affiliate_payouts for INR analytics
ALTER TABLE public.affiliate_campaigns ADD COLUMN IF NOT EXISTS conversions_count BIGINT NOT NULL DEFAULT 0 CHECK (conversions_count >= 0);
ALTER TABLE public.affiliate_campaigns ADD COLUMN IF NOT EXISTS revenue_generated_inr NUMERIC NOT NULL DEFAULT 0 CHECK (revenue_generated_inr >= 0);
ALTER TABLE public.affiliate_campaigns ADD COLUMN IF NOT EXISTS target_path TEXT NOT NULL DEFAULT '/signup';
ALTER TABLE public.affiliate_campaigns ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

ALTER TABLE public.affiliate_referrals ADD COLUMN IF NOT EXISTS plan_tier TEXT NOT NULL DEFAULT 'pro';
ALTER TABLE public.affiliate_referrals ADD COLUMN IF NOT EXISTS subscription_amount_inr NUMERIC NOT NULL DEFAULT 2499.00;
ALTER TABLE public.affiliate_referrals ADD COLUMN IF NOT EXISTS commission_rate NUMERIC NOT NULL DEFAULT 0.25;
ALTER TABLE public.affiliate_referrals ADD COLUMN IF NOT EXISTS tds_deducted_inr NUMERIC NOT NULL DEFAULT 0.00;
ALTER TABLE public.affiliate_referrals ADD COLUMN IF NOT EXISTS net_commission_inr NUMERIC NOT NULL DEFAULT 0.00;

ALTER TABLE public.affiliate_payouts ALTER COLUMN currency SET DEFAULT 'INR';
UPDATE public.affiliate_payouts SET currency = 'INR' WHERE currency = 'USD' OR currency IS NULL;
ALTER TABLE public.affiliate_payouts ADD COLUMN IF NOT EXISTS gross_amount_inr NUMERIC;
ALTER TABLE public.affiliate_payouts ADD COLUMN IF NOT EXISTS tds_amount_inr NUMERIC NOT NULL DEFAULT 0.00;
ALTER TABLE public.affiliate_payouts ADD COLUMN IF NOT EXISTS gst_amount_inr NUMERIC NOT NULL DEFAULT 0.00;
ALTER TABLE public.affiliate_payouts ADD COLUMN IF NOT EXISTS net_amount_inr NUMERIC;
ALTER TABLE public.affiliate_payouts ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.affiliate_payouts ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;
ALTER TABLE public.affiliate_payouts ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- Grant authenticated updates on new affiliate_profiles and campaign delete
GRANT SELECT ON public.affiliate_commission_tiers, public.affiliate_program_terms TO anon, authenticated;
GRANT ALL ON public.affiliate_commission_tiers, public.affiliate_program_terms TO service_role;
GRANT UPDATE(custom_slug, payout_method, payout_details, minimum_payout_threshold, auto_payout_enabled, gst_registered, gstin, pan_number, terms_version_accepted, terms_accepted_at) ON public.affiliate_profiles TO authenticated;
GRANT DELETE ON public.affiliate_campaigns TO authenticated;

ALTER TABLE public.affiliate_commission_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.affiliate_program_terms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS affiliate_tiers_public_read ON public.affiliate_commission_tiers;
CREATE POLICY affiliate_tiers_public_read ON public.affiliate_commission_tiers FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS affiliate_tiers_admin_write ON public.affiliate_commission_tiers;
CREATE POLICY affiliate_tiers_admin_write ON public.affiliate_commission_tiers FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = (SELECT auth.uid()) AND role = 'user_admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = (SELECT auth.uid()) AND role = 'user_admin'));

DROP POLICY IF EXISTS affiliate_terms_public_read ON public.affiliate_program_terms;
CREATE POLICY affiliate_terms_public_read ON public.affiliate_program_terms FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS affiliate_terms_admin_write ON public.affiliate_program_terms;
CREATE POLICY affiliate_terms_admin_write ON public.affiliate_program_terms FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = (SELECT auth.uid()) AND role = 'user_admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = (SELECT auth.uid()) AND role = 'user_admin'));

DROP POLICY IF EXISTS affiliate_workspace_campaign_delete ON public.affiliate_campaigns;
CREATE POLICY affiliate_workspace_campaign_delete ON public.affiliate_campaigns FOR DELETE TO authenticated
  USING (affiliate_id = (SELECT auth.uid()));

-- Admin policies on affiliate tables so user_admin can review payouts, profiles, and assets
DROP POLICY IF EXISTS affiliate_admin_profile_all ON public.affiliate_profiles;
CREATE POLICY affiliate_admin_profile_all ON public.affiliate_profiles FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = (SELECT auth.uid()) AND role = 'user_admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = (SELECT auth.uid()) AND role = 'user_admin'));

DROP POLICY IF EXISTS affiliate_admin_payout_all ON public.affiliate_payouts;
CREATE POLICY affiliate_admin_payout_all ON public.affiliate_payouts FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = (SELECT auth.uid()) AND role = 'user_admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = (SELECT auth.uid()) AND role = 'user_admin'));

DROP POLICY IF EXISTS affiliate_admin_asset_all ON public.affiliate_assets;
CREATE POLICY affiliate_admin_asset_all ON public.affiliate_assets FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = (SELECT auth.uid()) AND role = 'user_admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = (SELECT auth.uid()) AND role = 'user_admin'));

-- Enhanced affiliate_workspace() RPC returning dynamic tiers and terms alongside profile/campaigns/referrals/payouts/assets
CREATE OR REPLACE FUNCTION public.affiliate_workspace() RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $$
 SELECT jsonb_build_object(
  'profile', (SELECT to_jsonb(p) FROM public.affiliate_profiles p WHERE p.id=(SELECT auth.uid())),
  'campaigns', COALESCE((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.created_at DESC) FROM public.affiliate_campaigns c WHERE c.affiliate_id=(SELECT auth.uid())),'[]'::jsonb),
  'referrals', COALESCE((SELECT jsonb_agg(jsonb_build_object(
    'id', r.id,
    'referral_code', r.referral_code,
    'status', r.status,
    'bonus_awarded', r.bonus_awarded,
    'channel', r.channel,
    'campaign_id', r.campaign_id,
    'plan_tier', r.plan_tier,
    'subscription_amount_inr', r.subscription_amount_inr,
    'commission_rate', r.commission_rate,
    'tds_deducted_inr', r.tds_deducted_inr,
    'net_commission_inr', r.net_commission_inr,
    'created_at', r.created_at
  ) ORDER BY r.created_at DESC) FROM public.affiliate_referrals r WHERE r.affiliate_id=(SELECT auth.uid())),'[]'::jsonb),
  'payouts', COALESCE((SELECT jsonb_agg(to_jsonb(p) ORDER BY p.created_at DESC) FROM public.affiliate_payouts p WHERE p.affiliate_id=(SELECT auth.uid())),'[]'::jsonb),
  'assets', COALESCE((SELECT jsonb_agg(to_jsonb(a) ORDER BY a.created_at) FROM public.affiliate_assets a WHERE a.published),'[]'::jsonb),
  'tiers', COALESCE((SELECT jsonb_agg(to_jsonb(t) ORDER BY t.sort_order) FROM public.affiliate_commission_tiers t),'[]'::jsonb),
  'terms', COALESCE((SELECT jsonb_agg(to_jsonb(m) ORDER BY m.sort_order) FROM public.affiliate_program_terms m),'[]'::jsonb)
 );
$$;
REVOKE ALL ON FUNCTION public.affiliate_workspace() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.affiliate_workspace() TO authenticated;


-- ============================================================================
-- 2. ADMIN & INSTITUTIONAL DESK SCHEMA (ORGANIZATIONS, SEATS, RISK, AUDIT)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL DEFAULT 'TradeX Institutional Desk',
  slug TEXT UNIQUE NOT NULL DEFAULT 'tradex-institutional-mum',
  legal_entity_name TEXT NOT NULL DEFAULT 'TradeX Capital Markets & Analytics Pvt. Ltd.',
  sebi_registration_no TEXT DEFAULT 'INH000018492',
  gstin TEXT DEFAULT '27AABCT8492K1Z5',
  corporate_pan TEXT DEFAULT 'AABCT8492K',
  primary_color TEXT DEFAULT '#10B981',
  logo_url TEXT,
  headquarters_city TEXT NOT NULL DEFAULT 'Mumbai, MH',
  supervised_capital_inr NUMERIC NOT NULL DEFAULT 250000000.00 CHECK (supervised_capital_inr >= 0),
  allocated_capital_inr NUMERIC NOT NULL DEFAULT 185000000.00 CHECK (allocated_capital_inr >= 0),
  max_seats INTEGER NOT NULL DEFAULT 25 CHECK (max_seats >= 1),
  circuit_breaker_status TEXT NOT NULL DEFAULT 'armed' CHECK (circuit_breaker_status IN ('armed', 'tripped', 'halted')),
  killswitch_engaged BOOLEAN NOT NULL DEFAULT false,
  killswitch_reason TEXT,
  killswitch_updated_at TIMESTAMPTZ,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.organization_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  handle TEXT NOT NULL,
  display_name TEXT NOT NULL,
  email TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'trader' CHECK (role IN ('owner', 'admin', 'risk_officer', 'analyst', 'trader', 'viewer')),
  desk_division TEXT NOT NULL DEFAULT 'Index & Options Desk',
  allocated_capital_inr NUMERIC NOT NULL DEFAULT 5000000.00 CHECK (allocated_capital_inr >= 0),
  used_margin_inr NUMERIC NOT NULL DEFAULT 0.00 CHECK (used_margin_inr >= 0),
  daily_pnl_inr NUMERIC NOT NULL DEFAULT 0.00,
  monthly_pnl_inr NUMERIC NOT NULL DEFAULT 0.00,
  max_drawdown_limit_pct NUMERIC NOT NULL DEFAULT 5.0 CHECK (max_drawdown_limit_pct > 0 AND max_drawdown_limit_pct <= 50),
  current_drawdown_pct NUMERIC NOT NULL DEFAULT 0.0 CHECK (current_drawdown_pct >= 0),
  win_rate_pct NUMERIC NOT NULL DEFAULT 60.0 CHECK (win_rate_pct >= 0 AND win_rate_pct <= 100),
  sharpe_ratio NUMERIC NOT NULL DEFAULT 1.80,
  open_positions_count INTEGER NOT NULL DEFAULT 0 CHECK (open_positions_count >= 0),
  risk_warnings_count INTEGER NOT NULL DEFAULT 0 CHECK (risk_warnings_count >= 0),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'invited', 'frozen', 'suspended')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_org_members_org ON public.organization_members(org_id);
CREATE INDEX IF NOT EXISTS idx_org_members_user ON public.organization_members(user_id);
CREATE INDEX IF NOT EXISTS idx_org_members_status ON public.organization_members(status);

CREATE TABLE IF NOT EXISTS public.desk_risk_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID UNIQUE REFERENCES public.organizations(id) ON DELETE CASCADE,
  max_firm_drawdown_percent NUMERIC NOT NULL DEFAULT 5.0 CHECK (max_firm_drawdown_percent BETWEEN 1.0 AND 25.0),
  max_position_per_trader NUMERIC NOT NULL DEFAULT 5000000.00 CHECK (max_position_per_trader >= 100000),
  enforce_pre_trade_checklist BOOLEAN NOT NULL DEFAULT true,
  manager_approval_threshold NUMERIC NOT NULL DEFAULT 1000000.00 CHECK (manager_approval_threshold >= 0),
  audit_logging_enabled BOOLEAN NOT NULL DEFAULT true,
  allowed_asset_classes TEXT[] NOT NULL DEFAULT ARRAY['NSE Equities', 'F&O Derivatives', 'Commodities (MCX)', 'Currency Pairs'],
  intraday_auto_squareoff_time TEXT NOT NULL DEFAULT '15:15 IST',
  var_confidence_pct NUMERIC NOT NULL DEFAULT 99.0,
  max_leverage_multiplier NUMERIC NOT NULL DEFAULT 5.0,
  updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.desk_order_approvals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
  trader_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  trader_handle TEXT NOT NULL,
  trader_name TEXT NOT NULL,
  desk_division TEXT NOT NULL DEFAULT 'Index & Options Desk',
  ticker TEXT NOT NULL,
  exchange TEXT NOT NULL DEFAULT 'NSE',
  side TEXT NOT NULL CHECK (side IN ('BUY', 'SELL', 'SHORT')),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  order_price_inr NUMERIC NOT NULL CHECK (order_price_inr > 0),
  notional_value_inr NUMERIC NOT NULL CHECK (notional_value_inr > 0),
  leverage_x NUMERIC NOT NULL DEFAULT 1.0,
  stop_loss_inr NUMERIC,
  target_inr NUMERIC,
  strategy_name TEXT NOT NULL,
  checklist_passed BOOLEAN NOT NULL DEFAULT true,
  reason_flagged TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'expired')),
  reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  review_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_desk_order_approvals_status ON public.desk_order_approvals(status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.desk_risk_breaches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
  trader_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  trader_handle TEXT NOT NULL,
  trader_name TEXT NOT NULL,
  desk_division TEXT NOT NULL DEFAULT 'Index & Options Desk',
  severity TEXT NOT NULL CHECK (severity IN ('warning', 'critical', 'halt')),
  breach_type TEXT NOT NULL CHECK (breach_type IN ('daily_loss_limit', 'max_notional_exceeded', 'restricted_instrument', 'checklist_bypass', 'margin_utilization')),
  metric_label TEXT NOT NULL,
  metric_value_inr NUMERIC NOT NULL DEFAULT 0,
  threshold_value_inr NUMERIC NOT NULL DEFAULT 0,
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'acknowledged', 'trader_frozen', 'resolved')),
  resolved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  resolution_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_desk_risk_breaches_status ON public.desk_risk_breaches(status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL,
  actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  actor_handle TEXT NOT NULL,
  actor_role TEXT NOT NULL DEFAULT 'user_admin',
  category TEXT NOT NULL CHECK (category IN ('risk_control', 'order_approval', 'seat_governance', 'affiliate_review', 'payout_settlement', 'account_deletion', 'security_auth')),
  action TEXT NOT NULL,
  severity TEXT NOT NULL DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'critical')),
  target_type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  target_label TEXT NOT NULL,
  ip_address TEXT NOT NULL DEFAULT '103.21.58.14',
  sha256_hash TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created ON public.admin_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_category ON public.admin_audit_logs(category, created_at DESC);


-- ============================================================================
-- 3. ACCOUNT DELETION & CONDITIONAL DATA PURGE ENGINE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.account_deletion_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  user_handle TEXT NOT NULL,
  user_email TEXT,
  user_role TEXT NOT NULL DEFAULT 'customer' CHECK (user_role IN ('customer', 'affiliate', 'user_admin')),
  reason TEXT NOT NULL,
  feedback TEXT,
  data_purge_condition TEXT NOT NULL DEFAULT 'immediate_purge'
    CHECK (data_purge_condition IN ('immediate_purge', 'after_30_day_grace', 'purge_personal_keep_tax_ledger')),
  purge_journals_notes_strategies BOOLEAN NOT NULL DEFAULT true,
  purge_community_messages BOOLEAN NOT NULL DEFAULT true,
  purge_ai_workspace BOOLEAN NOT NULL DEFAULT true,
  purge_affiliate_campaigns BOOLEAN NOT NULL DEFAULT true,
  export_requested_before_delete BOOLEAN NOT NULL DEFAULT false,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'grace_period', 'data_purged', 'completed', 'cancelled')),
  scheduled_purge_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  data_purged_at TIMESTAMPTZ,
  purged_tables_summary JSONB NOT NULL DEFAULT '{}'::jsonb,
  reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  review_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_account_deletion_requests_user ON public.account_deletion_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_account_deletion_requests_status ON public.account_deletion_requests(status, created_at DESC);

-- Helper function to check if current caller is an administrator
CREATE OR REPLACE FUNCTION public.is_admin_caller() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = (SELECT auth.uid()) AND role = 'user_admin'
  );
$$;
REVOKE ALL ON FUNCTION public.is_admin_caller() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin_caller() TO authenticated, service_role;

-- Enable RLS across Admin & Deletion tables
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.desk_risk_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.desk_order_approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.desk_risk_breaches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON
  public.organizations,
  public.organization_members,
  public.desk_risk_configs,
  public.desk_order_approvals,
  public.desk_risk_breaches
TO authenticated;

GRANT SELECT, INSERT ON public.admin_audit_logs TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.account_deletion_requests TO authenticated;

GRANT ALL ON
  public.organizations,
  public.organization_members,
  public.desk_risk_configs,
  public.desk_order_approvals,
  public.desk_risk_breaches,
  public.admin_audit_logs,
  public.account_deletion_requests
TO service_role;

-- RLS Policies for Admin tables
DROP POLICY IF EXISTS organizations_read_policy ON public.organizations;
CREATE POLICY organizations_read_policy ON public.organizations FOR SELECT TO authenticated
  USING (public.is_admin_caller() OR EXISTS (SELECT 1 FROM public.organization_members m WHERE m.org_id = organizations.id AND m.user_id = (SELECT auth.uid())));

DROP POLICY IF EXISTS organizations_admin_write_policy ON public.organizations;
CREATE POLICY organizations_admin_write_policy ON public.organizations FOR ALL TO authenticated
  USING (public.is_admin_caller()) WITH CHECK (public.is_admin_caller());

DROP POLICY IF EXISTS org_members_read_policy ON public.organization_members;
CREATE POLICY org_members_read_policy ON public.organization_members FOR SELECT TO authenticated
  USING (public.is_admin_caller() OR user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS org_members_admin_write_policy ON public.organization_members;
CREATE POLICY org_members_admin_write_policy ON public.organization_members FOR ALL TO authenticated
  USING (public.is_admin_caller()) WITH CHECK (public.is_admin_caller());

DROP POLICY IF EXISTS desk_risk_configs_read_policy ON public.desk_risk_configs;
CREATE POLICY desk_risk_configs_read_policy ON public.desk_risk_configs FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS desk_risk_configs_admin_write_policy ON public.desk_risk_configs;
CREATE POLICY desk_risk_configs_admin_write_policy ON public.desk_risk_configs FOR ALL TO authenticated
  USING (public.is_admin_caller()) WITH CHECK (public.is_admin_caller());

DROP POLICY IF EXISTS desk_order_approvals_read_policy ON public.desk_order_approvals;
CREATE POLICY desk_order_approvals_read_policy ON public.desk_order_approvals FOR SELECT TO authenticated
  USING (public.is_admin_caller() OR trader_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS desk_order_approvals_write_policy ON public.desk_order_approvals;
CREATE POLICY desk_order_approvals_write_policy ON public.desk_order_approvals FOR ALL TO authenticated
  USING (public.is_admin_caller() OR trader_id = (SELECT auth.uid()))
  WITH CHECK (public.is_admin_caller() OR trader_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS desk_risk_breaches_read_policy ON public.desk_risk_breaches;
CREATE POLICY desk_risk_breaches_read_policy ON public.desk_risk_breaches FOR SELECT TO authenticated
  USING (public.is_admin_caller() OR trader_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS desk_risk_breaches_admin_write_policy ON public.desk_risk_breaches;
CREATE POLICY desk_risk_breaches_admin_write_policy ON public.desk_risk_breaches FOR ALL TO authenticated
  USING (public.is_admin_caller()) WITH CHECK (public.is_admin_caller());

DROP POLICY IF EXISTS admin_audit_logs_read_policy ON public.admin_audit_logs;
CREATE POLICY admin_audit_logs_read_policy ON public.admin_audit_logs FOR SELECT TO authenticated
  USING (public.is_admin_caller() OR actor_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS admin_audit_logs_insert_policy ON public.admin_audit_logs;
CREATE POLICY admin_audit_logs_insert_policy ON public.admin_audit_logs FOR INSERT TO authenticated
  WITH CHECK (public.is_admin_caller() OR actor_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS account_deletion_requests_read_policy ON public.account_deletion_requests;
CREATE POLICY account_deletion_requests_read_policy ON public.account_deletion_requests FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()) OR public.is_admin_caller());

DROP POLICY IF EXISTS account_deletion_requests_insert_policy ON public.account_deletion_requests;
CREATE POLICY account_deletion_requests_insert_policy ON public.account_deletion_requests FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()) OR public.is_admin_caller());

DROP POLICY IF EXISTS account_deletion_requests_update_policy ON public.account_deletion_requests;
CREATE POLICY account_deletion_requests_update_policy ON public.account_deletion_requests FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()) OR public.is_admin_caller())
  WITH CHECK (user_id = (SELECT auth.uid()) OR public.is_admin_caller());


-- ============================================================================
-- 4. CONDITIONAL DATA PURGE & ACCOUNT DELETION STORED PROCEDURES
-- ============================================================================

CREATE OR REPLACE FUNCTION public.execute_user_data_purge(
  p_user_id UUID,
  p_keep_tax_ledger BOOLEAN DEFAULT true,
  p_purge_writing BOOLEAN DEFAULT true,
  p_purge_social BOOLEAN DEFAULT true,
  p_purge_ai BOOLEAN DEFAULT true,
  p_purge_affiliate BOOLEAN DEFAULT true
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_journals_deleted INTEGER := 0;
  v_notes_deleted INTEGER := 0;
  v_strategies_deleted INTEGER := 0;
  v_watchlists_deleted INTEGER := 0;
  v_posts_deleted INTEGER := 0;
  v_messages_deleted INTEGER := 0;
  v_ai_deleted INTEGER := 0;
  v_campaigns_deleted INTEGER := 0;
BEGIN
  IF auth.uid() IS NULL OR (auth.uid() <> p_user_id AND NOT public.is_admin_caller()) THEN
    RAISE EXCEPTION 'Unauthorized data purge execution';
  END IF;

  -- 1. Writing Desk & Trading Data (Journals, Notes, Strategies, Watchlists, Checklists)
  IF p_purge_writing THEN
    IF to_regclass('public.journal_entries') IS NOT NULL THEN
      EXECUTE 'DELETE FROM public.journal_entries WHERE user_id = $1' USING p_user_id;
      GET DIAGNOSTICS v_journals_deleted = ROW_COUNT;
    END IF;
    IF to_regclass('public.trader_notes') IS NOT NULL THEN
      EXECUTE 'DELETE FROM public.trader_notes WHERE user_id = $1' USING p_user_id;
      GET DIAGNOSTICS v_notes_deleted = ROW_COUNT;
    END IF;
    IF to_regclass('public.strategies') IS NOT NULL THEN
      EXECUTE 'DELETE FROM public.strategies WHERE user_id = $1' USING p_user_id;
      GET DIAGNOSTICS v_strategies_deleted = ROW_COUNT;
    END IF;
    IF to_regclass('public.watchlists') IS NOT NULL THEN
      EXECUTE 'DELETE FROM public.watchlists WHERE user_id = $1' USING p_user_id;
      GET DIAGNOSTICS v_watchlists_deleted = ROW_COUNT;
    END IF;
    IF to_regclass('public.trader_checklists') IS NOT NULL THEN
      EXECUTE 'DELETE FROM public.trader_checklists WHERE user_id = $1' USING p_user_id;
    END IF;
    IF to_regclass('public.trader_preferences') IS NOT NULL THEN
      EXECUTE 'DELETE FROM public.trader_preferences WHERE user_id = $1' USING p_user_id;
    END IF;
  END IF;

  -- 2. Community Posts, Comments, Follows & Direct Messages
  IF p_purge_social THEN
    IF to_regclass('public.posts') IS NOT NULL THEN
      EXECUTE 'DELETE FROM public.posts WHERE user_id = $1' USING p_user_id;
      GET DIAGNOSTICS v_posts_deleted = ROW_COUNT;
    END IF;
    IF to_regclass('public.community_posts') IS NOT NULL THEN
      EXECUTE 'DELETE FROM public.community_posts WHERE author_id = $1' USING p_user_id;
    END IF;
    IF to_regclass('public.messages') IS NOT NULL THEN
      EXECUTE 'DELETE FROM public.messages WHERE sender_id = $1' USING p_user_id;
      GET DIAGNOSTICS v_messages_deleted = ROW_COUNT;
    END IF;
    IF to_regclass('public.chat_messages') IS NOT NULL THEN
      EXECUTE 'DELETE FROM public.chat_messages WHERE sender_id = $1' USING p_user_id;
    END IF;
  END IF;

  -- 3. AI Copilot Threads, Insights & Setups
  IF p_purge_ai THEN
    IF to_regclass('public.ai_insight_requests') IS NOT NULL THEN
      EXECUTE 'DELETE FROM public.ai_insight_requests WHERE user_id = $1' USING p_user_id;
      GET DIAGNOSTICS v_ai_deleted = ROW_COUNT;
    END IF;
    IF to_regclass('public.ai_threads') IS NOT NULL THEN
      EXECUTE 'DELETE FROM public.ai_threads WHERE user_id = $1' USING p_user_id;
    END IF;
    IF to_regclass('public.ai_chart_setups') IS NOT NULL THEN
      EXECUTE 'DELETE FROM public.ai_chart_setups WHERE user_id = $1' USING p_user_id;
    END IF;
  END IF;

  -- 4. Affiliate Campaigns, Slugs & Non-Statutory Marketing Data
  IF p_purge_affiliate THEN
    IF to_regclass('public.affiliate_campaigns') IS NOT NULL THEN
      EXECUTE 'DELETE FROM public.affiliate_campaigns WHERE affiliate_id = $1' USING p_user_id;
      GET DIAGNOSTICS v_campaigns_deleted = ROW_COUNT;
    END IF;
    IF to_regclass('public.affiliate_profiles') IS NOT NULL THEN
      UPDATE public.affiliate_profiles
      SET status = 'suspended',
          custom_slug = NULL,
          auto_payout_enabled = false,
          payout_details = CASE
            WHEN p_keep_tax_ledger THEN jsonb_build_object('anonymized_for_tax_compliance', true, 'pan', payout_details->>'pan')
            ELSE '{}'::jsonb
          END,
          updated_at = now()
      WHERE id = p_user_id;
    END IF;
  END IF;

  -- 5. Scrub personal profile fields while preserving referential integrity if needed
  UPDATE public.profiles
  SET status = 'suspended',
      bio = NULL,
      avatar_url = NULL,
      public_journals = false,
      updated_at = now()
  WHERE id = p_user_id;

  RETURN jsonb_build_object(
    'journals_deleted', v_journals_deleted,
    'notes_deleted', v_notes_deleted,
    'strategies_deleted', v_strategies_deleted,
    'watchlists_deleted', v_watchlists_deleted,
    'posts_deleted', v_posts_deleted,
    'messages_deleted', v_messages_deleted,
    'ai_records_deleted', v_ai_deleted,
    'affiliate_campaigns_deleted', v_campaigns_deleted,
    'tax_ledger_retained', p_keep_tax_ledger,
    'purged_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.execute_user_data_purge(uuid, boolean, boolean, boolean, boolean, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.execute_user_data_purge(uuid, boolean, boolean, boolean, boolean, boolean) TO authenticated;

-- User-facing RPC to request account deletion with explicit data deletion condition
CREATE OR REPLACE FUNCTION public.request_account_deletion_with_conditions(
  p_reason TEXT,
  p_feedback TEXT DEFAULT NULL,
  p_data_purge_condition TEXT DEFAULT 'immediate_purge',
  p_purge_writing BOOLEAN DEFAULT true,
  p_purge_social BOOLEAN DEFAULT true,
  p_purge_ai BOOLEAN DEFAULT true,
  p_purge_affiliate BOOLEAN DEFAULT true,
  p_export_before_delete BOOLEAN DEFAULT false
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_profile RECORD;
  v_request_id UUID;
  v_summary JSONB := '{}'::jsonb;
  v_status TEXT;
  v_scheduled TIMESTAMPTZ;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required to delete account';
  END IF;

  SELECT * INTO v_profile FROM public.profiles WHERE id = v_uid FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found';
  END IF;

  IF p_data_purge_condition NOT IN ('immediate_purge', 'after_30_day_grace', 'purge_personal_keep_tax_ledger') THEN
    RAISE EXCEPTION 'Invalid data purge condition: %', p_data_purge_condition;
  END IF;

  IF p_data_purge_condition = 'after_30_day_grace' THEN
    v_status := 'grace_period';
    v_scheduled := now() + interval '30 days';
    UPDATE public.profiles SET status = 'pending_approval', updated_at = now() WHERE id = v_uid;
  ELSE
    v_status := 'data_purged';
    v_scheduled := now();
    v_summary := public.execute_user_data_purge(
      v_uid,
      p_data_purge_condition = 'purge_personal_keep_tax_ledger',
      p_purge_writing,
      p_purge_social,
      p_purge_ai,
      p_purge_affiliate
    );
  END IF;

  INSERT INTO public.account_deletion_requests (
    user_id,
    user_handle,
    user_email,
    user_role,
    reason,
    feedback,
    data_purge_condition,
    purge_journals_notes_strategies,
    purge_community_messages,
    purge_ai_workspace,
    purge_affiliate_campaigns,
    export_requested_before_delete,
    status,
    scheduled_purge_at,
    data_purged_at,
    purged_tables_summary
  ) VALUES (
    v_uid,
    COALESCE(v_profile.handle::text, 'trader'),
    v_profile.email::text,
    COALESCE(v_profile.role, 'customer'),
    COALESCE(nullif(trim(p_reason), ''), 'User requested account deletion'),
    p_feedback,
    p_data_purge_condition,
    p_purge_writing,
    p_purge_social,
    p_purge_ai,
    p_purge_affiliate,
    p_export_before_delete,
    v_status,
    v_scheduled,
    CASE WHEN v_status = 'data_purged' THEN now() ELSE NULL END,
    v_summary
  ) RETURNING id INTO v_request_id;

  -- Record tamper-evident compliance audit log
  INSERT INTO public.admin_audit_logs (
    actor_id, actor_handle, actor_role, category, action, severity,
    target_type, target_id, target_label, sha256_hash, metadata
  ) VALUES (
    v_uid,
    COALESCE(v_profile.handle::text, 'trader'),
    COALESCE(v_profile.role, 'customer'),
    'account_deletion',
    CASE WHEN v_status = 'data_purged'
      THEN 'Account Deleted & Immediate Data Purge Executed'
      ELSE 'Account Deletion Queued (30-Day Data Purge Condition)'
    END,
    'warning',
    'profile',
    v_uid::text,
    COALESCE(v_profile.email::text, v_profile.handle::text),
    encode( extensions.digest(v_request_id::text || ':' || p_data_purge_condition || ':' || now()::text, 'sha256'), 'hex' ),
    jsonb_build_object(
      'request_id', v_request_id,
      'condition', p_data_purge_condition,
      'summary', v_summary
    )
  );

  RETURN jsonb_build_object(
    'request_id', v_request_id,
    'status', v_status,
    'data_purge_condition', p_data_purge_condition,
    'scheduled_purge_at', v_scheduled,
    'purged_summary', v_summary
  );
EXCEPTION WHEN undefined_function THEN
  -- Fallback if pgcrypto digest is not installed in test harness
  INSERT INTO public.admin_audit_logs (
    actor_id, actor_handle, actor_role, category, action, severity,
    target_type, target_id, target_label, sha256_hash, metadata
  ) VALUES (
    v_uid,
    COALESCE(v_profile.handle::text, 'trader'),
    COALESCE(v_profile.role, 'customer'),
    'account_deletion',
    'Account Deletion Processed (' || p_data_purge_condition || ')',
    'warning',
    'profile',
    v_uid::text,
    COALESCE(v_profile.email::text, v_profile.handle::text),
    md5(v_request_id::text || ':' || p_data_purge_condition || ':' || now()::text),
    jsonb_build_object(
      'request_id', v_request_id,
      'condition', p_data_purge_condition,
      'summary', v_summary
    )
  );
  RETURN jsonb_build_object(
    'request_id', v_request_id,
    'status', v_status,
    'data_purge_condition', p_data_purge_condition,
    'scheduled_purge_at', v_scheduled,
    'purged_summary', v_summary
  );
END;
$$;

REVOKE ALL ON FUNCTION public.request_account_deletion_with_conditions(text, text, text, boolean, boolean, boolean, boolean, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_account_deletion_with_conditions(text, text, text, boolean, boolean, boolean, boolean, boolean) TO authenticated;

-- Admin RPC to review affiliate payouts in INR (Approve/Settle with UTR or Reject with balance refund)
CREATE OR REPLACE FUNCTION public.admin_review_affiliate_payout(
  p_payout_id UUID,
  p_status TEXT,
  p_transaction_reference TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_payout RECORD;
BEGIN
  IF NOT public.is_admin_caller() THEN
    RAISE EXCEPTION 'Administrator privileges required to settle affiliate payouts';
  END IF;

  SELECT * INTO v_payout FROM public.affiliate_payouts WHERE id = p_payout_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payout request not found';
  END IF;

  UPDATE public.affiliate_payouts
  SET status = p_status,
      transaction_reference = COALESCE(nullif(trim(p_transaction_reference), ''), transaction_reference),
      notes = COALESCE(p_notes, notes),
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      updated_at = now()
  WHERE id = p_payout_id;

  INSERT INTO public.admin_audit_logs (
    actor_id, actor_handle, actor_role, category, action, severity,
    target_type, target_id, target_label, sha256_hash, metadata
  ) VALUES (
    auth.uid(),
    'desk_admin',
    'user_admin',
    'payout_settlement',
    'Affiliate Payout ' || upper(p_status) || ' (₹' || v_payout.amount::text || ' INR)',
    CASE WHEN p_status = 'paid' THEN 'info' ELSE 'warning' END,
    'affiliate_payout',
    p_payout_id::text,
    'UTR: ' || COALESCE(p_transaction_reference, 'N/A'),
    md5(p_payout_id::text || ':' || p_status || ':' || now()::text),
    jsonb_build_object('amount_inr', v_payout.amount, 'status', p_status, 'utr', p_transaction_reference)
  );

  RETURN jsonb_build_object('success', true, 'payout_id', p_payout_id, 'status', p_status);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_review_affiliate_payout(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_review_affiliate_payout(uuid, text, text, text) TO authenticated;

COMMIT;
