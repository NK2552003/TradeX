-- =============================================================================
-- Migration: 20261121020000_affiliate_referral_subscription_system.sql
-- Purpose:
--   1. Connect the Affiliate Program end-to-end with Razorpay & Supabase
--      subscriptions under Revision 2026.2-INR:
--        - Subscriber referral discount (Monthly plans only, Month 1 only):
--            * Basic Monthly: ₹299 -> ₹239 (-₹60 off Month 1, then ₹299/mo)
--            * Pro Monthly:   ₹499 -> ₹399 (-₹100 off Month 1, then ₹499/mo)
--            * Annual plans:  already reflect the 20% discounted rate; referral
--              codes still attribute the partner with ₹0 extra stacked discount.
--        - Affiliate commission schedule (per verified paid Basic/Pro user):
--            * Conversions #1–50: ₹10 INR per verified paid user
--            * Conversions #51+:  ₹30 INR per verified paid user
--        - One user at a time / single-use lifetime redemption lock per user.
--        - Strict affiliate coupon ban: affiliates cannot redeem their own or
--          any other affiliate's referral code or coupon.
--        - 50-paid-user milestone for complimentary Pro: affiliates receive NO
--          free Basic or Pro access until 50 distinct referred users complete
--          verified Basic or Pro payments; complimentary Pro auto-unlocks at 50
--          and auto-revokes if refunds/reversals drop verified count below 50.
--   2. Support safe subscription plan/cycle switching (replaces_subscription_id)
--      across Basic <-> Pro and Monthly <-> Annual without double-billing or
--      double-awarding referral commissions.
--
-- Rollback / Remediation Notes:
--   - All DDL changes are additive; to pause referral discounts temporarily,
--     set offer_valid_until = now() on affected affiliate_profiles rows.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Extend public.affiliate_profiles with milestone, validity, and terms fields
-- -----------------------------------------------------------------------------
ALTER TABLE public.affiliate_profiles
  ADD COLUMN IF NOT EXISTS paid_referrals_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS complimentary_pro_unlocked boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS complimentary_pro_unlocked_at timestamptz,
  ADD COLUMN IF NOT EXISTS terms_version_accepted text NOT NULL DEFAULT '2026.2-INR',
  ADD COLUMN IF NOT EXISTS terms_accepted_at timestamptz,
  ADD COLUMN IF NOT EXISTS offer_valid_from timestamptz,
  ADD COLUMN IF NOT EXISTS offer_valid_until timestamptz;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.affiliate_profiles'::regclass
      AND conname = 'affiliate_profiles_paid_referrals_nonneg'
  ) THEN
    ALTER TABLE public.affiliate_profiles
      ADD CONSTRAINT affiliate_profiles_paid_referrals_nonneg
      CHECK (paid_referrals_count >= 0);
  END IF;
END $$;

-- Backfill paid_referrals_count from existing converted referrals (never auto-granting
-- complimentary Pro unless >= 50 verified conversions exist).
UPDATE public.affiliate_profiles a
SET paid_referrals_count = COALESCE((
      SELECT count(*)::integer
      FROM public.affiliate_referrals r
      WHERE r.affiliate_id = a.id
        AND r.status = 'converted'
    ), 0),
    complimentary_pro_unlocked = (
      a.status = 'active'
      AND COALESCE((
        SELECT count(*)::integer
        FROM public.affiliate_referrals r
        WHERE r.affiliate_id = a.id
          AND r.status = 'converted'
      ), 0) >= 50
    ),
    updated_at = now();

-- -----------------------------------------------------------------------------
-- 2. Extend public.affiliate_referrals with subscription, discount & TDS tracking
-- -----------------------------------------------------------------------------
ALTER TABLE public.affiliate_referrals
  ADD COLUMN IF NOT EXISTS plan_tier text,
  ADD COLUMN IF NOT EXISTS billing_cycle text,
  ADD COLUMN IF NOT EXISTS subscription_amount_inr numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS discount_amount_inr numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS commission_tier_slot integer,
  ADD COLUMN IF NOT EXISTS tds_deducted_inr numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS net_commission_inr numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS provider_subscription_id text,
  ADD COLUMN IF NOT EXISTS provider_payment_id text,
  ADD COLUMN IF NOT EXISTS converted_at timestamptz,
  ADD COLUMN IF NOT EXISTS reversed_at timestamptz;

CREATE UNIQUE INDEX IF NOT EXISTS idx_affiliate_referrals_unique_referred_user
  ON public.affiliate_referrals (referred_user_id)
  WHERE referred_user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_affiliate_referrals_sub_id
  ON public.affiliate_referrals (provider_subscription_id)
  WHERE provider_subscription_id IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 3. Extend public.billing_checkout_intents for referral offers & plan switches
-- -----------------------------------------------------------------------------
ALTER TABLE public.billing_checkout_intents
  ADD COLUMN IF NOT EXISTS referral_code text,
  ADD COLUMN IF NOT EXISTS affiliate_id uuid REFERENCES public.affiliate_profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS razorpay_offer_id text,
  ADD COLUMN IF NOT EXISTS discount_amount_paise bigint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS payable_amount_paise bigint,
  ADD COLUMN IF NOT EXISTS affiliate_reward_inr numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS replaces_subscription_id text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.billing_checkout_intents'::regclass
      AND conname = 'billing_checkout_intents_discount_nonneg'
  ) THEN
    ALTER TABLE public.billing_checkout_intents
      ADD CONSTRAINT billing_checkout_intents_discount_nonneg
      CHECK (discount_amount_paise >= 0);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_billing_checkout_intents_affiliate_id
  ON public.billing_checkout_intents (affiliate_id)
  WHERE affiliate_id IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 4. Create public.affiliate_referral_redemptions (1-per-user lifetime lock)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.affiliate_referral_redemptions (
  user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  affiliate_id uuid NOT NULL REFERENCES public.affiliate_profiles(id) ON DELETE RESTRICT,
  referral_code text NOT NULL,
  checkout_intent_id uuid REFERENCES public.billing_checkout_intents(id) ON DELETE SET NULL,
  provider_subscription_id text,
  provider_payment_id text,
  plan_tier text NOT NULL CHECK (plan_tier IN ('premium', 'enterprise')),
  billing_cycle text NOT NULL CHECK (billing_cycle IN ('monthly', 'annual')),
  discount_inr numeric NOT NULL DEFAULT 0 CHECK (discount_inr IN (0, 60, 100)),
  commission_inr numeric NOT NULL DEFAULT 10 CHECK (commission_inr IN (10, 30)),
  conversion_slot integer CHECK (conversion_slot IS NULL OR conversion_slot >= 1),
  status text NOT NULL DEFAULT 'reserved' CHECK (status IN ('reserved', 'converted', 'reversed', 'expired')),
  reserved_at timestamptz NOT NULL DEFAULT now(),
  converted_at timestamptz,
  reversed_at timestamptz,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 minutes'),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_affiliate_redemptions_affiliate_status
  ON public.affiliate_referral_redemptions (affiliate_id, status);

CREATE INDEX IF NOT EXISTS idx_affiliate_redemptions_sub_id
  ON public.affiliate_referral_redemptions (provider_subscription_id)
  WHERE provider_subscription_id IS NOT NULL;

ALTER TABLE public.affiliate_referral_redemptions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.affiliate_referral_redemptions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.affiliate_referral_redemptions TO authenticated;
GRANT ALL ON public.affiliate_referral_redemptions TO service_role;

DROP POLICY IF EXISTS affiliate_redemptions_own_read ON public.affiliate_referral_redemptions;
CREATE POLICY affiliate_redemptions_own_read
  ON public.affiliate_referral_redemptions
  FOR SELECT
  TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR affiliate_id = (SELECT auth.uid())
    OR (SELECT public.is_user_admin())
  );

-- -----------------------------------------------------------------------------
-- 5. Helper: Check whether a user is an affiliate account (banned from coupons)
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS tradex_private;

CREATE OR REPLACE FUNCTION tradex_private.is_affiliate_account(p_user uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT p_user IS NOT NULL AND (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = p_user AND p.role = 'affiliate'
    )
    OR EXISTS (
      SELECT 1 FROM public.affiliate_profiles a
      WHERE a.id = p_user
    )
    OR EXISTS (
      SELECT 1 FROM public.affiliate_applications app
      WHERE app.user_id = p_user
        AND app.status IN ('pending', 'pending_review', 'approved', 'active', 'suspended')
    )
  );
$$;

REVOKE ALL ON FUNCTION tradex_private.is_affiliate_account(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION tradex_private.is_affiliate_account(uuid) TO service_role;

-- -----------------------------------------------------------------------------
-- 6. Upgrade tradex_private.effective_tier: Free Pro ONLY at >= 50 paid referrals
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tradex_private.effective_tier(p_user uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT COALESCE(
    (SELECT p.admin_controls->'subscription_override'->>'tier'
       FROM public.profiles p
      WHERE p.id = p_user
        AND p.admin_controls->'subscription_override'->>'tier' IN ('free', 'premium', 'enterprise')
        AND (p.admin_controls->'subscription_override'->>'expires_at')::timestamptz > now()),
    (SELECT 'enterprise'
       FROM public.affiliate_profiles a
      WHERE a.id = p_user
        AND a.status = 'active'
        AND a.paid_referrals_count >= 50
        AND a.complimentary_pro_unlocked = true),
    (SELECT CASE
              WHEN s.tier IN ('pro', 'enterprise') THEN 'enterprise'
              WHEN s.tier IN ('basic', 'premium') THEN 'premium'
              ELSE 'free'
            END
       FROM public.subscriptions s
      WHERE s.user_id = p_user
        AND s.status IN ('active', 'trialing', 'canceled')
        AND (s.expires_at IS NULL OR s.expires_at > now())),
    'free'
  );
$$;

REVOKE ALL ON FUNCTION tradex_private.effective_tier(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION tradex_private.effective_tier(uuid) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 7. Sync affiliate 50-paid-referral Pro milestone into profiles & subscriptions
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_affiliate_milestone_entitlement(p_affiliate_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_now timestamptz := now();
  v_aff public.affiliate_profiles%ROWTYPE;
  v_should_unlock boolean := false;
  v_effective_tier text := 'free';
BEGIN
  IF p_affiliate_id IS NULL THEN
    RAISE EXCEPTION 'affiliate_id is required' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('billing_reconcile'), hashtext(p_affiliate_id::text));

  SELECT * INTO v_aff
    FROM public.affiliate_profiles
   WHERE id = p_affiliate_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('affiliate_id', p_affiliate_id, 'complimentary_pro_unlocked', false);
  END IF;

  v_should_unlock := (v_aff.status = 'active' AND v_aff.paid_referrals_count >= 50);

  UPDATE public.affiliate_profiles
     SET complimentary_pro_unlocked = v_should_unlock,
         complimentary_pro_unlocked_at = CASE
           WHEN v_should_unlock AND complimentary_pro_unlocked_at IS NULL THEN v_now
           WHEN NOT v_should_unlock THEN NULL
           ELSE complimentary_pro_unlocked_at
         END,
         tier = CASE WHEN v_aff.paid_referrals_count >= 50 THEN 'milestone' ELSE 'starter' END,
         updated_at = v_now
   WHERE id = p_affiliate_id;

  -- Compute authoritative tier across paid subscriptions + 50-referral milestone
  IF v_should_unlock THEN
    v_effective_tier := 'enterprise';
  ELSE
    SELECT CASE
             WHEN s.tier IN ('pro', 'enterprise') THEN 'enterprise'
             WHEN s.tier IN ('basic', 'premium') THEN 'premium'
             ELSE 'free'
           END
      INTO v_effective_tier
      FROM public.subscriptions s
     WHERE s.user_id = p_affiliate_id
       AND s.status IN ('active', 'trialing', 'canceled')
       AND (s.expires_at IS NULL OR s.expires_at > v_now)
     LIMIT 1;
    v_effective_tier := COALESCE(v_effective_tier, 'free');
  END IF;

  UPDATE public.profiles
     SET subscription_tier = v_effective_tier,
         updated_at = v_now
   WHERE id = p_affiliate_id;

  RETURN jsonb_build_object(
    'affiliate_id', p_affiliate_id,
    'paid_referrals_count', v_aff.paid_referrals_count,
    'complimentary_pro_unlocked', v_should_unlock,
    'effective_tier', v_effective_tier
  );
END;
$$;

REVOKE ALL ON FUNCTION public.sync_affiliate_milestone_entitlement(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sync_affiliate_milestone_entitlement(uuid) TO service_role;

-- -----------------------------------------------------------------------------
-- 8. Server-side Referral Code Validation RPC (for Flutter & Edge Functions)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_referral_code(
  p_code text,
  p_tier text,
  p_billing_cycle text,
  p_target_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_now timestamptz := now();
  v_caller uuid := COALESCE(auth.uid(), p_target_user_id);
  v_clean_code text := upper(trim(COALESCE(p_code, '')));
  v_norm_tier text;
  v_norm_cycle text;
  v_aff public.affiliate_profiles%ROWTYPE;
  v_redemption public.affiliate_referral_redemptions%ROWTYPE;
  v_has_paid_history boolean := false;
  v_list_inr numeric := 0;
  v_discount_inr numeric := 0;
  v_payable_inr numeric := 0;
  v_renewal_inr numeric := 0;
  v_offer_slot text := 'none';
  v_commission_inr numeric := 10;
  v_commission_tier text := 'starter_10';
BEGIN
  -- Authenticated callers may only validate for themselves; service_role may pass p_target_user_id.
  IF auth.uid() IS NOT NULL AND p_target_user_id IS NOT NULL AND p_target_user_id <> auth.uid() THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;

  IF v_caller IS NULL THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error_code', 'auth_required',
      'message', 'Sign in to validate a referral code.'
    );
  END IF;

  v_norm_tier := CASE lower(trim(COALESCE(p_tier, '')))
    WHEN 'basic' THEN 'premium'
    WHEN 'premium' THEN 'premium'
    WHEN 'tier_pro' THEN 'premium'
    WHEN 'tier_basic' THEN 'premium'
    WHEN 'pro' THEN 'enterprise'
    WHEN 'enterprise' THEN 'enterprise'
    WHEN 'business' THEN 'enterprise'
    WHEN 'tier_enterprise' THEN 'enterprise'
    ELSE NULL
  END;

  v_norm_cycle := CASE lower(trim(COALESCE(p_billing_cycle, '')))
    WHEN 'monthly' THEN 'monthly'
    WHEN 'annual' THEN 'annual'
    WHEN 'yearly' THEN 'annual'
    ELSE NULL
  END;

  IF v_norm_tier IS NULL OR v_norm_cycle IS NULL THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error_code', 'invalid_plan',
      'message', 'Choose Basic or Pro with Monthly or Annual billing.'
    );
  END IF;

  -- Rule 1: Strict affiliate coupon ban (own OR any other affiliate's code)
  IF tradex_private.is_affiliate_account(v_caller) THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error_code', 'affiliate_coupon_prohibited',
      'is_affiliate_blocked', true,
      'message', 'Affiliate accounts cannot redeem their own or other partners'' referral or coupon codes.'
    );
  END IF;

  IF v_clean_code = '' OR length(v_clean_code) < 3 OR length(v_clean_code) > 80 THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error_code', 'invalid_code',
      'message', 'Enter a valid referral code.'
    );
  END IF;

  -- Rule 2: One referral redemption per user lifetime (and first paid checkout only)
  SELECT * INTO v_redemption
    FROM public.affiliate_referral_redemptions
   WHERE user_id = v_caller;

  IF FOUND AND v_redemption.status = 'converted' THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error_code', 'already_redeemed',
      'message', 'This account has already redeemed a referral offer. Referral offers are limited to one per user.'
    );
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.invoices
    WHERE user_id = v_caller AND status = 'paid'
  ) OR EXISTS (
    SELECT 1 FROM public.billing_checkout_intents
    WHERE user_id = v_caller AND status IN ('active', 'authenticated')
  ) INTO v_has_paid_history;

  IF v_has_paid_history THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error_code', 'existing_subscriber',
      'message', 'Referral offers apply only to your first paid Basic or Pro subscription.'
    );
  END IF;

  -- Rule 3: Lookup active affiliate by affiliate_code or custom_slug
  SELECT * INTO v_aff
    FROM public.affiliate_profiles
   WHERE upper(affiliate_code) = v_clean_code
      OR upper(COALESCE(custom_slug, '')) = v_clean_code
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error_code', 'invalid_code',
      'message', 'Referral code not found. Check the code and try again.'
    );
  END IF;

  IF v_aff.id = v_caller THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error_code', 'self_referral',
      'message', 'You cannot apply your own referral code.'
    );
  END IF;

  IF v_aff.status <> 'active' THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error_code', 'inactive_code',
      'message', 'This partner referral code is currently inactive.'
    );
  END IF;

  IF (v_aff.offer_valid_from IS NOT NULL AND v_now < v_aff.offer_valid_from)
     OR (v_aff.offer_valid_until IS NOT NULL AND v_now > v_aff.offer_valid_until) THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error_code', 'expired_code',
      'message', 'This referral offer is outside its validity window.'
    );
  END IF;

  -- Canonical INR pricing
  IF v_norm_tier = 'premium' THEN
    v_list_inr := CASE WHEN v_norm_cycle = 'annual' THEN 2868 ELSE 299 END;
    v_renewal_inr := v_list_inr;
    IF v_norm_cycle = 'monthly' THEN
      v_discount_inr := 60; -- ₹299 -> ₹239 for Month 1 only
      v_offer_slot := 'basic_monthly_60';
    END IF;
  ELSE
    v_list_inr := CASE WHEN v_norm_cycle = 'annual' THEN 4788 ELSE 499 END;
    v_renewal_inr := v_list_inr;
    IF v_norm_cycle = 'monthly' THEN
      v_discount_inr := 100; -- ₹499 -> ₹399 for Month 1 only
      v_offer_slot := 'pro_monthly_100';
    END IF;
  END IF;

  v_payable_inr := GREATEST(1, v_list_inr - v_discount_inr);

  -- Affiliate payout tier (₹10 for first 50 paid users, ₹30 for user #51+)
  IF v_aff.paid_referrals_count >= 50 THEN
    v_commission_inr := 30;
    v_commission_tier := 'milestone_30';
  ELSE
    v_commission_inr := 10;
    v_commission_tier := 'starter_10';
  END IF;

  RETURN jsonb_build_object(
    'valid', true,
    'code', v_aff.affiliate_code,
    'affiliate_id', v_aff.id,
    'tier', v_norm_tier,
    'billing_cycle', v_norm_cycle,
    'list_amount_inr', v_list_inr,
    'discount_inr', v_discount_inr,
    'discount_paise', (v_discount_inr * 100)::bigint,
    'payable_amount_inr', v_payable_inr,
    'payable_amount_paise', (v_payable_inr * 100)::bigint,
    'renewal_amount_inr', v_renewal_inr,
    'applies_discount', (v_discount_inr > 0),
    'offer_slot', v_offer_slot,
    'affiliate_commission_inr', v_commission_inr,
    'affiliate_tier_slot', v_commission_tier,
    'valid_until', v_aff.offer_valid_until,
    'message', CASE
      WHEN v_norm_cycle = 'monthly' AND v_norm_tier = 'premium' THEN
        'Referral applied: ₹239 for Month 1 (₹60 off), then ₹299/mo from Month 2.'
      WHEN v_norm_cycle = 'monthly' AND v_norm_tier = 'enterprise' THEN
        'Referral applied: ₹399 for Month 1 (₹100 off), then ₹499/mo from Month 2.'
      ELSE
        'Referral code verified! Annual plans already include the 20% discounted rate; your partner will be credited on activation.'
    END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.validate_referral_code(text, text, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.validate_referral_code(text, text, text, uuid) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 9. Reserve a one-time referral redemption during checkout creation
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reserve_affiliate_referral_redemption(
  p_user_id uuid,
  p_affiliate_id uuid,
  p_referral_code text,
  p_checkout_intent_id uuid,
  p_provider_subscription_id text,
  p_tier text,
  p_billing_cycle text,
  p_discount_inr numeric,
  p_commission_inr numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_now timestamptz := now();
  v_existing public.affiliate_referral_redemptions%ROWTYPE;
BEGIN
  IF p_user_id IS NULL OR p_affiliate_id IS NULL THEN
    RAISE EXCEPTION 'user_id and affiliate_id are required' USING ERRCODE = '22023';
  END IF;

  IF tradex_private.is_affiliate_account(p_user_id) THEN
    RAISE EXCEPTION 'Affiliate accounts cannot redeem referral codes' USING ERRCODE = '42501';
  END IF;

  IF p_user_id = p_affiliate_id THEN
    RAISE EXCEPTION 'Self-referral is prohibited' USING ERRCODE = '42501';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('referral_redeem'), hashtext(p_user_id::text));

  SELECT * INTO v_existing
    FROM public.affiliate_referral_redemptions
   WHERE user_id = p_user_id
   FOR UPDATE;

  IF FOUND AND v_existing.status = 'converted' THEN
    RAISE EXCEPTION 'User has already redeemed a referral code' USING ERRCODE = '23505';
  END IF;

  INSERT INTO public.affiliate_referral_redemptions (
    user_id,
    affiliate_id,
    referral_code,
    checkout_intent_id,
    provider_subscription_id,
    plan_tier,
    billing_cycle,
    discount_inr,
    commission_inr,
    status,
    reserved_at,
    expires_at,
    updated_at
  ) VALUES (
    p_user_id,
    p_affiliate_id,
    upper(trim(p_referral_code)),
    p_checkout_intent_id,
    p_provider_subscription_id,
    p_tier,
    p_billing_cycle,
    p_discount_inr,
    p_commission_inr,
    'reserved',
    v_now,
    v_now + interval '30 minutes',
    v_now
  )
  ON CONFLICT (user_id) DO UPDATE SET
    affiliate_id = EXCLUDED.affiliate_id,
    referral_code = EXCLUDED.referral_code,
    checkout_intent_id = EXCLUDED.checkout_intent_id,
    provider_subscription_id = EXCLUDED.provider_subscription_id,
    plan_tier = EXCLUDED.plan_tier,
    billing_cycle = EXCLUDED.billing_cycle,
    discount_inr = EXCLUDED.discount_inr,
    commission_inr = EXCLUDED.commission_inr,
    status = 'reserved',
    reserved_at = v_now,
    expires_at = v_now + interval '30 minutes',
    updated_at = v_now
  WHERE public.affiliate_referral_redemptions.status <> 'converted';

  -- Ensure a pending referral row exists for this user (1 per user lifetime)
  INSERT INTO public.affiliate_referrals (
    affiliate_id,
    referred_user_id,
    referral_code,
    status,
    channel,
    plan_tier,
    billing_cycle,
    discount_amount_inr,
    provider_subscription_id,
    created_at,
    updated_at
  ) VALUES (
    p_affiliate_id,
    p_user_id,
    upper(trim(p_referral_code)),
    'pending',
    'checkout',
    p_tier,
    p_billing_cycle,
    p_discount_inr,
    p_provider_subscription_id,
    v_now,
    v_now
  )
  ON CONFLICT (referred_user_id) WHERE referred_user_id IS NOT NULL DO UPDATE SET
    affiliate_id = EXCLUDED.affiliate_id,
    referral_code = EXCLUDED.referral_code,
    plan_tier = EXCLUDED.plan_tier,
    billing_cycle = EXCLUDED.billing_cycle,
    discount_amount_inr = EXCLUDED.discount_amount_inr,
    provider_subscription_id = EXCLUDED.provider_subscription_id,
    updated_at = v_now
  WHERE public.affiliate_referrals.status = 'pending';
END;
$$;

REVOKE ALL ON FUNCTION public.reserve_affiliate_referral_redemption(uuid, uuid, text, uuid, text, text, text, numeric, numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_affiliate_referral_redemption(uuid, uuid, text, uuid, text, text, text, numeric, numeric) TO service_role;

-- -----------------------------------------------------------------------------
-- 10. Finalize verified paid referral conversion (₹10 for #1–50, ₹30 for #51+,
--     auto-unlocks complimentary Pro at 50 verified Basic/Pro conversions)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.finalize_affiliate_referral_conversion(
  p_user_id uuid,
  p_affiliate_id uuid,
  p_referral_code text,
  p_tier text,
  p_billing_cycle text,
  p_subscription_amount_inr numeric,
  p_discount_amount_inr numeric DEFAULT 0,
  p_provider_subscription_id text DEFAULT NULL,
  p_provider_payment_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_now timestamptz := now();
  v_aff public.affiliate_profiles%ROWTYPE;
  v_redemption public.affiliate_referral_redemptions%ROWTYPE;
  v_slot integer;
  v_commission_inr numeric;
  v_tds_inr numeric;
  v_net_inr numeric;
  v_norm_tier text;
  v_norm_cycle text;
  v_milestone jsonb;
BEGIN
  IF p_user_id IS NULL OR p_affiliate_id IS NULL THEN
    RETURN jsonb_build_object('converted', false, 'reason', 'missing_ids');
  END IF;

  IF p_user_id = p_affiliate_id OR tradex_private.is_affiliate_account(p_user_id) THEN
    RETURN jsonb_build_object('converted', false, 'reason', 'ineligible_buyer');
  END IF;

  v_norm_tier := CASE lower(trim(COALESCE(p_tier, '')))
    WHEN 'premium' THEN 'premium'
    WHEN 'basic' THEN 'premium'
    WHEN 'enterprise' THEN 'enterprise'
    WHEN 'pro' THEN 'enterprise'
    ELSE NULL
  END;
  v_norm_cycle := CASE lower(trim(COALESCE(p_billing_cycle, 'monthly')))
    WHEN 'annual' THEN 'annual'
    WHEN 'yearly' THEN 'annual'
    ELSE 'monthly'
  END;

  IF v_norm_tier IS NULL THEN
    RETURN jsonb_build_object('converted', false, 'reason', 'non_paid_tier');
  END IF;

  -- Serialize on both buyer and affiliate rows (lock in deterministic UUID order to prevent deadlocks)
  PERFORM pg_advisory_xact_lock(hashtext('referral_finalize'), hashtext(LEAST(p_user_id::text, p_affiliate_id::text)));
  PERFORM pg_advisory_xact_lock(hashtext('referral_finalize'), hashtext(GREATEST(p_user_id::text, p_affiliate_id::text)));

  SELECT * INTO v_redemption
    FROM public.affiliate_referral_redemptions
   WHERE user_id = p_user_id
   FOR UPDATE;

  IF FOUND AND v_redemption.status = 'converted' THEN
    -- Already converted once (idempotent on retries / renewals / plan switches)
    RETURN jsonb_build_object(
      'converted', true,
      'already_converted', true,
      'conversion_slot', v_redemption.conversion_slot,
      'commission_inr', v_redemption.commission_inr
    );
  END IF;

  SELECT * INTO v_aff
    FROM public.affiliate_profiles
   WHERE id = p_affiliate_id
   FOR UPDATE;

  IF NOT FOUND OR v_aff.status <> 'active' THEN
    RETURN jsonb_build_object('converted', false, 'reason', 'affiliate_not_active');
  END IF;

  -- Authoritative conversion slot: #1–50 => ₹10, #51+ => ₹30
  v_slot := v_aff.paid_referrals_count + 1;
  v_commission_inr := CASE WHEN v_slot <= 50 THEN 10.00 ELSE 30.00 END;
  v_tds_inr := round(v_commission_inr * 0.05, 2);
  v_net_inr := round(v_commission_inr - v_tds_inr, 2);

  -- Update affiliate balances and verified paid referral counter
  UPDATE public.affiliate_profiles
     SET unpaid_balance = unpaid_balance + v_commission_inr,
         total_earnings = total_earnings + v_commission_inr,
         active_referrals = active_referrals + 1,
         paid_referrals_count = paid_referrals_count + 1,
         tier = CASE WHEN (paid_referrals_count + 1) >= 50 THEN 'milestone' ELSE 'starter' END,
         updated_at = v_now
   WHERE id = p_affiliate_id;

  -- Upsert authoritative converted referral row
  INSERT INTO public.affiliate_referrals (
    affiliate_id,
    referred_user_id,
    referral_code,
    status,
    bonus_awarded,
    channel,
    plan_tier,
    billing_cycle,
    subscription_amount_inr,
    discount_amount_inr,
    commission_tier_slot,
    tds_deducted_inr,
    net_commission_inr,
    provider_subscription_id,
    provider_payment_id,
    converted_at,
    created_at,
    updated_at
  ) VALUES (
    p_affiliate_id,
    p_user_id,
    upper(trim(COALESCE(p_referral_code, v_aff.affiliate_code))),
    'converted',
    v_commission_inr,
    'checkout',
    v_norm_tier,
    v_norm_cycle,
    GREATEST(0, COALESCE(p_subscription_amount_inr, 0)),
    GREATEST(0, COALESCE(p_discount_amount_inr, 0)),
    v_slot,
    v_tds_inr,
    v_net_inr,
    p_provider_subscription_id,
    p_provider_payment_id,
    v_now,
    v_now,
    v_now
  )
  ON CONFLICT (referred_user_id) WHERE referred_user_id IS NOT NULL DO UPDATE SET
    affiliate_id = EXCLUDED.affiliate_id,
    referral_code = EXCLUDED.referral_code,
    status = 'converted',
    bonus_awarded = EXCLUDED.bonus_awarded,
    plan_tier = EXCLUDED.plan_tier,
    billing_cycle = EXCLUDED.billing_cycle,
    subscription_amount_inr = EXCLUDED.subscription_amount_inr,
    discount_amount_inr = EXCLUDED.discount_amount_inr,
    commission_tier_slot = EXCLUDED.commission_tier_slot,
    tds_deducted_inr = EXCLUDED.tds_deducted_inr,
    net_commission_inr = EXCLUDED.net_commission_inr,
    provider_subscription_id = EXCLUDED.provider_subscription_id,
    provider_payment_id = EXCLUDED.provider_payment_id,
    converted_at = v_now,
    updated_at = v_now;

  -- Lock lifetime redemption row as converted
  INSERT INTO public.affiliate_referral_redemptions (
    user_id,
    affiliate_id,
    referral_code,
    provider_subscription_id,
    provider_payment_id,
    plan_tier,
    billing_cycle,
    discount_inr,
    commission_inr,
    conversion_slot,
    status,
    reserved_at,
    converted_at,
    expires_at,
    updated_at
  ) VALUES (
    p_user_id,
    p_affiliate_id,
    upper(trim(COALESCE(p_referral_code, v_aff.affiliate_code))),
    p_provider_subscription_id,
    p_provider_payment_id,
    v_norm_tier,
    v_norm_cycle,
    CASE WHEN COALESCE(p_discount_amount_inr, 0) IN (60, 100) THEN p_discount_amount_inr ELSE 0 END,
    v_commission_inr,
    v_slot,
    'converted',
    v_now,
    v_now,
    v_now,
    v_now
  )
  ON CONFLICT (user_id) DO UPDATE SET
    affiliate_id = EXCLUDED.affiliate_id,
    referral_code = EXCLUDED.referral_code,
    provider_subscription_id = EXCLUDED.provider_subscription_id,
    provider_payment_id = EXCLUDED.provider_payment_id,
    plan_tier = EXCLUDED.plan_tier,
    billing_cycle = EXCLUDED.billing_cycle,
    discount_inr = EXCLUDED.discount_inr,
    commission_inr = EXCLUDED.commission_inr,
    conversion_slot = EXCLUDED.conversion_slot,
    status = 'converted',
    converted_at = v_now,
    updated_at = v_now;

  -- Check & sync 50-paid-user complimentary Pro milestone
  v_milestone := public.sync_affiliate_milestone_entitlement(p_affiliate_id);

  RETURN jsonb_build_object(
    'converted', true,
    'already_converted', false,
    'conversion_slot', v_slot,
    'commission_inr', v_commission_inr,
    'tds_inr', v_tds_inr,
    'net_commission_inr', v_net_inr,
    'milestone', v_milestone
  );
END;
$$;

REVOKE ALL ON FUNCTION public.finalize_affiliate_referral_conversion(uuid, uuid, text, text, text, numeric, numeric, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_affiliate_referral_conversion(uuid, uuid, text, text, text, numeric, numeric, text, text) TO service_role;

-- -----------------------------------------------------------------------------
-- 11. Reverse referral conversion on refund / chargeback (re-checks 50-user Pro)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reverse_affiliate_referral_conversion(
  p_provider_subscription_id text DEFAULT NULL,
  p_provider_payment_id text DEFAULT NULL,
  p_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_now timestamptz := now();
  v_redemption public.affiliate_referral_redemptions%ROWTYPE;
  v_milestone jsonb;
BEGIN
  SELECT * INTO v_redemption
    FROM public.affiliate_referral_redemptions
   WHERE status = 'converted'
     AND (
       (p_provider_payment_id IS NOT NULL AND provider_payment_id = p_provider_payment_id)
       OR (p_provider_subscription_id IS NOT NULL AND provider_subscription_id = p_provider_subscription_id)
       OR (p_user_id IS NOT NULL AND user_id = p_user_id)
     )
   LIMIT 1
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('reversed', false, 'reason', 'not_found');
  END IF;

  UPDATE public.affiliate_profiles
     SET unpaid_balance = GREATEST(0, unpaid_balance - v_redemption.commission_inr),
         total_earnings = GREATEST(0, total_earnings - v_redemption.commission_inr),
         active_referrals = GREATEST(0, active_referrals - 1),
         paid_referrals_count = GREATEST(0, paid_referrals_count - 1),
         updated_at = v_now
   WHERE id = v_redemption.affiliate_id;

  UPDATE public.affiliate_referral_redemptions
     SET status = 'reversed',
         reversed_at = v_now,
         updated_at = v_now
   WHERE user_id = v_redemption.user_id;

  UPDATE public.affiliate_referrals
     SET status = 'reversed',
         reversed_at = v_now,
         updated_at = v_now
   WHERE referred_user_id = v_redemption.user_id
     AND affiliate_id = v_redemption.affiliate_id;

  v_milestone := public.sync_affiliate_milestone_entitlement(v_redemption.affiliate_id);

  RETURN jsonb_build_object(
    'reversed', true,
    'user_id', v_redemption.user_id,
    'affiliate_id', v_redemption.affiliate_id,
    'reversed_commission_inr', v_redemption.commission_inr,
    'milestone', v_milestone
  );
END;
$$;

REVOKE ALL ON FUNCTION public.reverse_affiliate_referral_conversion(text, text, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reverse_affiliate_referral_conversion(text, text, uuid) TO service_role;

-- -----------------------------------------------------------------------------
-- 12. Upgrade public.reconcile_billing_entitlement for plan switches & milestone Pro
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.reconcile_billing_entitlement(
  uuid, text, text, text, text, text, text, timestamptz, timestamptz, text, text, uuid, text
);

CREATE OR REPLACE FUNCTION public.reconcile_billing_entitlement(
  p_user_id uuid,
  p_provider text,
  p_tier text,
  p_status text,
  p_provider_subscription_id text DEFAULT NULL,
  p_revenuecat_id text DEFAULT NULL,
  p_billing_cycle text DEFAULT NULL,
  p_renewed_at timestamptz DEFAULT NULL,
  p_expires_at timestamptz DEFAULT NULL,
  p_event_id text DEFAULT NULL,
  p_event_type text DEFAULT 'UNKNOWN',
  p_intent_id uuid DEFAULT NULL,
  p_intent_status text DEFAULT NULL,
  p_replaces_subscription_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_now timestamptz := now();
  v_norm_tier text;
  v_norm_status text;
  v_existing_rp public.billing_provider_entitlements%ROWTYPE;
  v_rp public.billing_provider_entitlements%ROWTYPE;
  v_rc public.billing_provider_entitlements%ROWTYPE;
  v_rp_valid boolean := false;
  v_rc_valid boolean := false;
  v_aff_pro boolean := false;
  v_rp_rank integer := 0;
  v_rc_rank integer := 0;
  v_effective_tier text := 'free';
  v_effective_status text := 'canceled';
  v_effective_provider text;
  v_effective_sub_id text;
  v_effective_rc_id text;
  v_effective_cycle text;
  v_effective_renewed timestamptz;
  v_effective_expires timestamptz;
  v_is_intentional_switch boolean := false;
  v_intent_discount_paise bigint := 0;
  v_intent_expected_paise bigint := NULL;
  v_invoice_amount_inr numeric := 0;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'Account user_id is required' USING ERRCODE = '22023';
  END IF;
  IF p_provider NOT IN ('razorpay', 'revenuecat') THEN
    RAISE EXCEPTION 'Unsupported billing provider: %', p_provider USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('billing_reconcile'), hashtext(p_user_id::text));

  PERFORM 1 FROM public.profiles WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Account not found' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.billing_provider_entitlements (
    user_id, provider, tier, status, provider_subscription_id, revenuecat_id,
    billing_cycle, renewed_at, expires_at, updated_at
  )
  SELECT
    s.user_id,
    s.billing_provider,
    CASE
      WHEN s.tier IN ('pro', 'enterprise') THEN 'enterprise'
      WHEN s.tier IN ('basic', 'premium') THEN 'premium'
      ELSE 'free'
    END,
    CASE
      WHEN s.status IN ('active', 'canceled', 'expired', 'authenticated', 'created') THEN s.status
      ELSE 'active'
    END,
    s.provider_subscription_id,
    s.revenuecat_id,
    CASE WHEN s.billing_cycle IN ('monthly', 'annual') THEN s.billing_cycle ELSE NULL END,
    s.renewed_at,
    s.expires_at,
    COALESCE(s.updated_at, v_now)
  FROM public.subscriptions s
  WHERE s.user_id = p_user_id
    AND s.billing_provider IN ('razorpay', 'revenuecat')
  ON CONFLICT (user_id, provider) DO NOTHING;

  v_norm_tier := CASE
    WHEN p_tier IN ('pro', 'enterprise') THEN 'enterprise'
    WHEN p_tier IN ('basic', 'premium') THEN 'premium'
    ELSE 'free'
  END;

  v_norm_status := CASE
    WHEN p_status IN ('active', 'canceled', 'expired', 'authenticated', 'created') THEN p_status
    ELSE 'canceled'
  END;

  IF p_intent_id IS NOT NULL THEN
    SELECT COALESCE(discount_amount_paise, 0), expected_amount_paise
      INTO v_intent_discount_paise, v_intent_expected_paise
      FROM public.billing_checkout_intents
     WHERE id = p_intent_id AND user_id = p_user_id;

    IF p_intent_status IS NOT NULL THEN
      UPDATE public.billing_checkout_intents
         SET status = p_intent_status,
             updated_at = v_now
       WHERE id = p_intent_id
         AND user_id = p_user_id;
    END IF;
  END IF;

  IF p_provider = 'razorpay' THEN
    SELECT * INTO v_existing_rp
      FROM public.billing_provider_entitlements
     WHERE user_id = p_user_id AND provider = 'razorpay';

    v_is_intentional_switch := (
      p_replaces_subscription_id IS NOT NULL
      AND v_existing_rp.provider_subscription_id = p_replaces_subscription_id
      AND v_norm_status = 'active'
      AND v_norm_tier IN ('premium', 'enterprise')
    );

    IF FOUND
       AND NOT v_is_intentional_switch
       AND v_existing_rp.provider_subscription_id IS DISTINCT FROM p_provider_subscription_id
       AND v_existing_rp.tier IN ('premium', 'enterprise')
       AND v_existing_rp.status IN ('active', 'canceled')
       AND v_existing_rp.expires_at IS NOT NULL
       AND v_existing_rp.expires_at > v_now
       AND (
         v_norm_tier = 'free'
         OR (v_existing_rp.tier = 'enterprise' AND v_norm_tier = 'premium')
       ) THEN
      -- Preserve the newer/higher active Razorpay subscription
      NULL;
    ELSE
      INSERT INTO public.billing_provider_entitlements (
        user_id, provider, tier, status, provider_subscription_id, revenuecat_id,
        billing_cycle, renewed_at, expires_at, updated_at
      ) VALUES (
        p_user_id, 'razorpay', v_norm_tier, v_norm_status, p_provider_subscription_id, NULL,
        CASE WHEN p_billing_cycle IN ('monthly', 'annual') THEN p_billing_cycle ELSE NULL END,
        p_renewed_at, COALESCE(p_expires_at, v_now), v_now
      )
      ON CONFLICT (user_id, provider) DO UPDATE SET
        tier = EXCLUDED.tier,
        status = EXCLUDED.status,
        provider_subscription_id = EXCLUDED.provider_subscription_id,
        billing_cycle = EXCLUDED.billing_cycle,
        renewed_at = EXCLUDED.renewed_at,
        expires_at = EXCLUDED.expires_at,
        updated_at = v_now;
    END IF;
  ELSE
    INSERT INTO public.billing_provider_entitlements (
      user_id, provider, tier, status, provider_subscription_id, revenuecat_id,
      billing_cycle, renewed_at, expires_at, updated_at
    ) VALUES (
      p_user_id, 'revenuecat', v_norm_tier, v_norm_status, NULL, COALESCE(p_revenuecat_id, p_user_id::text),
      CASE WHEN p_billing_cycle IN ('monthly', 'annual') THEN p_billing_cycle ELSE NULL END,
      p_renewed_at, COALESCE(p_expires_at, v_now), v_now
    )
    ON CONFLICT (user_id, provider) DO UPDATE SET
      tier = EXCLUDED.tier,
      status = EXCLUDED.status,
      revenuecat_id = EXCLUDED.revenuecat_id,
      billing_cycle = EXCLUDED.billing_cycle,
      renewed_at = EXCLUDED.renewed_at,
      expires_at = EXCLUDED.expires_at,
      updated_at = v_now;
  END IF;

  SELECT * INTO v_rp
    FROM public.billing_provider_entitlements
   WHERE user_id = p_user_id AND provider = 'razorpay';

  SELECT * INTO v_rc
    FROM public.billing_provider_entitlements
   WHERE user_id = p_user_id AND provider = 'revenuecat';

  SELECT EXISTS (
    SELECT 1 FROM public.affiliate_profiles a
    WHERE a.id = p_user_id
      AND a.status = 'active'
      AND a.paid_referrals_count >= 50
      AND a.complimentary_pro_unlocked = true
  ) INTO v_aff_pro;

  v_rp_valid := v_rp.user_id IS NOT NULL
    AND v_rp.tier IN ('premium', 'enterprise')
    AND v_rp.status IN ('active', 'canceled')
    AND v_rp.expires_at IS NOT NULL
    AND v_rp.expires_at > v_now;

  v_rc_valid := v_rc.user_id IS NOT NULL
    AND v_rc.tier IN ('premium', 'enterprise')
    AND v_rc.status IN ('active', 'canceled')
    AND v_rc.expires_at IS NOT NULL
    AND v_rc.expires_at > v_now;

  IF v_rp_valid THEN
    v_rp_rank := CASE WHEN v_rp.tier = 'enterprise' THEN 2 ELSE 1 END;
  END IF;
  IF v_rc_valid THEN
    v_rc_rank := CASE WHEN v_rc.tier = 'enterprise' THEN 2 ELSE 1 END;
  END IF;

  IF v_rp_valid AND v_rp_rank >= v_rc_rank THEN
    v_effective_tier := CASE WHEN v_aff_pro THEN 'enterprise' ELSE v_rp.tier END;
    v_effective_status := v_rp.status;
    v_effective_provider := 'razorpay';
    v_effective_sub_id := v_rp.provider_subscription_id;
    v_effective_rc_id := NULL;
    v_effective_cycle := v_rp.billing_cycle;
    v_effective_renewed := v_rp.renewed_at;
    v_effective_expires := v_rp.expires_at;
  ELSIF v_rc_valid THEN
    v_effective_tier := CASE WHEN v_aff_pro THEN 'enterprise' ELSE v_rc.tier END;
    v_effective_status := v_rc.status;
    v_effective_provider := 'revenuecat';
    v_effective_sub_id := NULL;
    v_effective_rc_id := v_rc.revenuecat_id;
    v_effective_cycle := v_rc.billing_cycle;
    v_effective_renewed := v_rc.renewed_at;
    v_effective_expires := v_rc.expires_at;
  ELSE
    v_effective_tier := CASE WHEN v_aff_pro THEN 'enterprise' ELSE 'free' END;
    v_effective_status := CASE WHEN v_aff_pro THEN 'active' ELSE 'canceled' END;
    v_effective_provider := p_provider;
    v_effective_sub_id := CASE WHEN p_provider = 'razorpay' THEN p_provider_subscription_id ELSE NULL END;
    v_effective_rc_id := CASE WHEN p_provider = 'revenuecat' THEN COALESCE(p_revenuecat_id, p_user_id::text) ELSE NULL END;
    v_effective_cycle := CASE WHEN p_billing_cycle IN ('monthly', 'annual') THEN p_billing_cycle ELSE NULL END;
    v_effective_renewed := NULL;
    v_effective_expires := v_now;
  END IF;

  INSERT INTO public.subscriptions (
    user_id,
    tier,
    status,
    billing_provider,
    provider_subscription_id,
    revenuecat_id,
    billing_cycle,
    renewed_at,
    expires_at,
    updated_at
  ) VALUES (
    p_user_id,
    v_effective_tier,
    v_effective_status,
    v_effective_provider,
    v_effective_sub_id,
    v_effective_rc_id,
    v_effective_cycle,
    v_effective_renewed,
    v_effective_expires,
    v_now
  )
  ON CONFLICT (user_id) DO UPDATE SET
    tier = EXCLUDED.tier,
    status = EXCLUDED.status,
    billing_provider = EXCLUDED.billing_provider,
    provider_subscription_id = EXCLUDED.provider_subscription_id,
    revenuecat_id = EXCLUDED.revenuecat_id,
    billing_cycle = EXCLUDED.billing_cycle,
    renewed_at = EXCLUDED.renewed_at,
    expires_at = EXCLUDED.expires_at,
    updated_at = v_now;

  UPDATE public.profiles
     SET subscription_tier = v_effective_tier,
         updated_at = v_now
   WHERE id = p_user_id;

  IF v_norm_tier IN ('premium', 'enterprise')
     AND v_norm_status = 'active'
     AND EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'invoices') THEN
    v_invoice_amount_inr := CASE
      WHEN v_intent_expected_paise IS NOT NULL AND v_intent_expected_paise > 0 THEN
        GREATEST(1.0, (v_intent_expected_paise - v_intent_discount_paise)::numeric / 100.0)
      WHEN v_norm_tier = 'enterprise' AND COALESCE(p_billing_cycle, 'monthly') = 'annual' THEN 4788.0
      WHEN v_norm_tier = 'enterprise' THEN 499.0
      WHEN COALESCE(p_billing_cycle, 'monthly') = 'annual' THEN 2868.0
      ELSE 299.0
    END;

    INSERT INTO public.invoices (
      id,
      invoice_ref,
      user_id,
      amount,
      currency,
      status,
      issued_at,
      pdf_url,
      provider,
      provider_subscription_id,
      billing_cycle,
      tier,
      line_items,
      updated_at
    ) VALUES (
      'inv_' || COALESCE(p_provider_subscription_id, p_revenuecat_id, replace(p_user_id::text, '-', '')) || '_' || to_char(COALESCE(p_renewed_at, v_now), 'YYYYMMDD'),
      'inv_' || COALESCE(p_provider_subscription_id, p_revenuecat_id, replace(p_user_id::text, '-', '')) || '_' || to_char(COALESCE(p_renewed_at, v_now), 'YYYYMMDD'),
      p_user_id,
      v_invoice_amount_inr,
      'INR',
      'paid',
      COALESCE(p_renewed_at, v_now),
      '',
      p_provider,
      p_provider_subscription_id,
      COALESCE(p_billing_cycle, 'monthly'),
      v_norm_tier,
      jsonb_build_array(
        jsonb_build_object(
          'description',
          CASE
            WHEN v_norm_tier = 'enterprise' THEN 'AlphaJournal Pro (' || CASE WHEN COALESCE(p_billing_cycle, 'monthly') = 'annual' THEN 'Annual' ELSE 'Monthly' END || ' subscription, incl. 18% GST)'
            ELSE 'AlphaJournal Basic (' || CASE WHEN COALESCE(p_billing_cycle, 'monthly') = 'annual' THEN 'Annual' ELSE 'Monthly' END || ' subscription, incl. 18% GST)'
          END,
          'amount',
          v_invoice_amount_inr,
          'quantity',
          1
        )
      ),
      v_now
    )
    ON CONFLICT (id) DO UPDATE SET
      amount = EXCLUDED.amount,
      status = EXCLUDED.status,
      line_items = EXCLUDED.line_items,
      updated_at = v_now;
  END IF;

  IF p_event_id IS NOT NULL AND btrim(p_event_id) <> '' THEN
    INSERT INTO public.billing_webhook_receipts (provider, event_id, user_id, event_type, processed_at)
    VALUES (p_provider, p_event_id, p_user_id, COALESCE(p_event_type, 'UNKNOWN'), v_now)
    ON CONFLICT (provider, event_id) DO UPDATE SET
      processed_at = EXCLUDED.processed_at;

    IF p_provider = 'revenuecat' AND EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'revenuecat_webhook_events') THEN
      INSERT INTO public.revenuecat_webhook_events (event_id, event_type, processed_at)
      VALUES (p_event_id, COALESCE(p_event_type, 'UNKNOWN'), v_now)
      ON CONFLICT (event_id) DO UPDATE SET
        event_type = EXCLUDED.event_type,
        processed_at = EXCLUDED.processed_at;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'user_id', p_user_id,
    'tier', v_effective_tier,
    'status', v_effective_status,
    'billing_provider', v_effective_provider,
    'expires_at', v_effective_expires,
    'complimentary_pro_unlocked', v_aff_pro
  );
END;
$$;

REVOKE ALL ON FUNCTION public.reconcile_billing_entitlement(
  uuid, text, text, text, text, text, text, timestamptz, timestamptz, text, text, uuid, text, text
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reconcile_billing_entitlement(
  uuid, text, text, text, text, text, text, timestamptz, timestamptz, text, text, uuid, text, text
) TO service_role;

-- -----------------------------------------------------------------------------
-- 13. Upgrade public.affiliate_workspace() with 50-user milestone & ₹10/₹30 data
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.affiliate_workspace()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'profile', (
      SELECT to_jsonb(p) || jsonb_build_object(
        'free_pro_threshold', 50,
        'current_commission_inr', CASE WHEN COALESCE(p.paid_referrals_count, 0) >= 50 THEN 30 ELSE 10 END,
        'monthly_basic_discount_inr', 60,
        'monthly_pro_discount_inr', 100
      )
      FROM public.affiliate_profiles p
      WHERE p.id = (SELECT auth.uid())
    ),
    'campaigns', COALESCE((
      SELECT jsonb_agg(to_jsonb(c) ORDER BY c.created_at DESC)
      FROM public.affiliate_campaigns c
      WHERE c.affiliate_id = (SELECT auth.uid())
    ), '[]'::jsonb),
    'referrals', COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', r.id,
          'referral_code', r.referral_code,
          'status', r.status,
          'bonus_awarded', r.bonus_awarded,
          'channel', r.channel,
          'campaign_id', r.campaign_id,
          'plan_tier', r.plan_tier,
          'billing_cycle', r.billing_cycle,
          'subscription_amount_inr', r.subscription_amount_inr,
          'discount_amount_inr', r.discount_amount_inr,
          'commission_tier_slot', r.commission_tier_slot,
          'tds_deducted_inr', r.tds_deducted_inr,
          'net_commission_inr', r.net_commission_inr,
          'converted_at', r.converted_at,
          'created_at', r.created_at
        ) ORDER BY r.created_at DESC
      )
      FROM public.affiliate_referrals r
      WHERE r.affiliate_id = (SELECT auth.uid())
    ), '[]'::jsonb),
    'payouts', COALESCE((
      SELECT jsonb_agg(to_jsonb(p) ORDER BY p.created_at DESC)
      FROM public.affiliate_payouts p
      WHERE p.affiliate_id = (SELECT auth.uid())
    ), '[]'::jsonb),
    'assets', COALESCE((
      SELECT jsonb_agg(to_jsonb(a) ORDER BY a.created_at)
      FROM public.affiliate_assets a
      WHERE a.published
    ), '[]'::jsonb)
  );
$$;

REVOKE ALL ON FUNCTION public.affiliate_workspace() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.affiliate_workspace() TO authenticated;

-- -----------------------------------------------------------------------------
-- 14. Update private.provision_profile_for_user to store referral attribution
--     (blocking affiliate-role signups & self-referrals) and use AlphaJournal prefix
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS private;

CREATE OR REPLACE FUNCTION private.provision_profile_for_user(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_email text;
  v_meta jsonb;
  v_display_name text;
  v_avatar text;
  v_raw_handle text;
  v_base_handle text;
  v_candidate_handle text;
  v_suffix text;
  v_referral_code text;
  v_referred_by_raw text;
  v_affiliate_requested boolean := false;
  v_aff_id uuid;
  v_aff_code text;
  v_campaign_slug text;
  v_campaign_id uuid;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
    RETURN;
  END IF;

  SELECT u.email, COALESCE(u.raw_user_meta_data, '{}'::jsonb)
  INTO v_email, v_meta
  FROM auth.users u
  WHERE u.id = p_user_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  v_email := COALESCE(lower(trim(v_email)), '');
  v_display_name := COALESCE(
    NULLIF(trim(v_meta->>'full_name'), ''),
    NULLIF(trim(v_meta->>'name'), ''),
    NULLIF(split_part(v_email, '@', 1), ''),
    'Trader'
  );
  v_avatar := COALESCE(
    NULLIF(trim(v_meta->>'avatar_url'), ''),
    NULLIF(trim(v_meta->>'picture'), '')
  );

  v_raw_handle := COALESCE(
    NULLIF(trim(v_meta->>'handle'), ''),
    NULLIF(trim(v_meta->>'user_name'), ''),
    NULLIF(trim(v_meta->>'preferred_username'), ''),
    NULLIF(split_part(v_email, '@', 1), ''),
    ''
  );
  v_base_handle := regexp_replace(lower(regexp_replace(v_raw_handle, '^@+', '')), '[^a-z0-9_]+', '_', 'g');
  v_base_handle := trim(both '_' from v_base_handle);
  v_suffix := lower(substr(replace(p_user_id::text, '-', ''), 1, 6));
  IF length(v_base_handle) < 3 THEN
    v_base_handle := 'trader_' || v_suffix;
  END IF;

  v_candidate_handle := '@' || v_base_handle;
  IF EXISTS (
    SELECT 1 FROM public.profiles WHERE lower(handle) = lower(v_candidate_handle)
  ) THEN
    v_candidate_handle := '@' || left(v_base_handle, 20) || '_' || v_suffix;
  END IF;

  v_referral_code := 'REF-ALPHAJOURNAL-' || upper(v_suffix);
  v_affiliate_requested := COALESCE((v_meta->>'affiliate_application_requested')::boolean, false);
  v_referred_by_raw := upper(trim(COALESCE(v_meta->>'referred_by_code', '')));
  v_campaign_slug := lower(trim(COALESCE(v_meta->>'utm_campaign', '')));

  -- Only record referral attribution for standard non-affiliate signups
  IF NOT v_affiliate_requested AND v_referred_by_raw <> '' THEN
    SELECT a.id, a.affiliate_code
      INTO v_aff_id, v_aff_code
      FROM public.affiliate_profiles a
     WHERE a.status = 'active'
       AND a.id <> p_user_id
       AND (upper(a.affiliate_code) = v_referred_by_raw OR upper(COALESCE(a.custom_slug, '')) = v_referred_by_raw)
       AND (a.offer_valid_from IS NULL OR now() >= a.offer_valid_from)
       AND (a.offer_valid_until IS NULL OR now() <= a.offer_valid_until)
     LIMIT 1;
  END IF;

  INSERT INTO public.profiles (
    id,
    handle,
    email,
    display_name,
    role,
    status,
    referral_code,
    referred_by_code,
    avatar_url,
    created_at,
    updated_at
  )
  VALUES (
    p_user_id,
    v_candidate_handle,
    v_email,
    v_display_name,
    'customer',
    'active',
    v_referral_code,
    v_aff_code,
    v_avatar,
    now(),
    now()
  )
  ON CONFLICT (id) DO NOTHING;

  IF v_aff_id IS NOT NULL THEN
    IF v_campaign_slug <> '' THEN
      SELECT id INTO v_campaign_id
        FROM public.affiliate_campaigns
       WHERE affiliate_id = v_aff_id AND slug = v_campaign_slug AND status = 'active'
       LIMIT 1;
    END IF;

    INSERT INTO public.affiliate_referrals (
      affiliate_id,
      referred_user_id,
      referral_code,
      status,
      channel,
      campaign_id,
      created_at,
      updated_at
    ) VALUES (
      v_aff_id,
      p_user_id,
      v_aff_code,
      'pending',
      COALESCE(NULLIF(v_campaign_slug, ''), 'signup'),
      v_campaign_id,
      now(),
      now()
    )
    ON CONFLICT (referred_user_id) WHERE referred_user_id IS NOT NULL DO NOTHING;
  END IF;
EXCEPTION WHEN unique_violation THEN
  v_candidate_handle := '@' || left(v_base_handle, 16) || '_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  INSERT INTO public.profiles (
    id,
    handle,
    email,
    display_name,
    role,
    status,
    referral_code,
    referred_by_code,
    avatar_url,
    created_at,
    updated_at
  )
  VALUES (
    p_user_id,
    v_candidate_handle,
    v_email,
    v_display_name,
    'customer',
    'active',
    v_referral_code,
    v_aff_code,
    v_avatar,
    now(),
    now()
  )
  ON CONFLICT (id) DO NOTHING;
END $$;

REVOKE ALL ON FUNCTION private.provision_profile_for_user(uuid) FROM PUBLIC, anon, authenticated;

COMMIT;
