-- =============================================================================
-- Migration: 20261121010000_razorpay_full_monthly_yearly_billing.sql
-- Purpose:
--   1. Enable Razorpay Monthly and Yearly (Annual) subscriptions for BOTH paid
--      tiers: Basic ('premium', ₹299/mo or ₹239/mo billed annually = ₹2,868/yr)
--      and Pro ('enterprise', ₹499/mo or ₹399/mo billed annually = ₹4,788/yr).
--   2. Harden public.billing_checkout_intents and public.invoices with RLS,
--      indexes, and multi-tier check constraints.
--   3. Upgrade public.reconcile_billing_entitlement to support both 'premium'
--      and 'enterprise' tiers from Razorpay while preserving cross-provider
--      and multi-subscription precedence.
--   4. Update public.pricing_catalogues ('default') so Basic and Pro are
--      purchasable on both monthly and annual billing cycles.
--
-- Rollback / Remediation Notes:
--   - To disable self-serve checkout temporarily, set is_purchasable = false on
--     paid plans in public.pricing_catalogues (id = 'default').
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Ensure public.billing_checkout_intents supports Basic ('premium') & Pro ('enterprise')
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.billing_checkout_intents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  tier text NOT NULL DEFAULT 'enterprise',
  billing_cycle text NOT NULL DEFAULT 'monthly',
  razorpay_plan_id text,
  razorpay_subscription_id text UNIQUE,
  expected_amount_paise bigint CHECK (expected_amount_paise IS NULL OR expected_amount_paise > 0),
  checkout_url text,
  status text NOT NULL DEFAULT 'created',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.billing_checkout_intents
  ADD COLUMN IF NOT EXISTS tier text NOT NULL DEFAULT 'enterprise',
  ADD COLUMN IF NOT EXISTS billing_cycle text NOT NULL DEFAULT 'monthly',
  ADD COLUMN IF NOT EXISTS razorpay_plan_id text,
  ADD COLUMN IF NOT EXISTS razorpay_subscription_id text,
  ADD COLUMN IF NOT EXISTS expected_amount_paise bigint,
  ADD COLUMN IF NOT EXISTS checkout_url text,
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'created',
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

DO $$
DECLARE
  c record;
BEGIN
  FOR c IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.billing_checkout_intents'::regclass
      AND contype = 'c'
      AND (
        pg_get_constraintdef(oid) ILIKE '%tier%'
        OR pg_get_constraintdef(oid) ILIKE '%billing_cycle%'
        OR pg_get_constraintdef(oid) ILIKE '%status%'
      )
  LOOP
    EXECUTE format('ALTER TABLE public.billing_checkout_intents DROP CONSTRAINT IF EXISTS %I', c.conname);
  END LOOP;
END $$;

ALTER TABLE public.billing_checkout_intents
  ADD CONSTRAINT billing_checkout_intents_tier_check
    CHECK (tier IN ('premium', 'enterprise')),
  ADD CONSTRAINT billing_checkout_intents_cycle_check
    CHECK (billing_cycle IN ('monthly', 'annual')),
  ADD CONSTRAINT billing_checkout_intents_status_check
    CHECK (status IN ('created', 'authenticated', 'active', 'cancelled', 'expired', 'halted', 'pending'));

CREATE UNIQUE INDEX IF NOT EXISTS idx_billing_checkout_intents_sub_id
  ON public.billing_checkout_intents (razorpay_subscription_id)
  WHERE razorpay_subscription_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS billing_checkout_intents_user_created
  ON public.billing_checkout_intents (user_id, created_at DESC);

ALTER TABLE public.billing_checkout_intents ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.billing_checkout_intents FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.billing_checkout_intents TO authenticated;
GRANT ALL ON public.billing_checkout_intents TO service_role;

DROP POLICY IF EXISTS billing_checkout_intents_own_read ON public.billing_checkout_intents;
CREATE POLICY billing_checkout_intents_own_read
  ON public.billing_checkout_intents
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()) OR (SELECT public.is_user_admin()));

-- -----------------------------------------------------------------------------
-- 2. Ensure public.invoices table & RLS exist for Razorpay receipts
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.invoices (
  id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  invoice_ref text NOT NULL DEFAULT '',
  amount numeric NOT NULL CHECK (amount >= 0),
  currency text NOT NULL DEFAULT 'INR',
  status text NOT NULL DEFAULT 'paid',
  issued_at timestamptz NOT NULL DEFAULT now(),
  pdf_url text NOT NULL DEFAULT '',
  line_items jsonb NOT NULL DEFAULT '[]'::jsonb,
  provider text NOT NULL DEFAULT 'razorpay',
  provider_subscription_id text,
  provider_payment_id text,
  billing_cycle text,
  tier text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- If public.invoices was created in an earlier schema with id as UUID, convert
-- id to TEXT so Razorpay invoice identifiers ('inv_pay_...', 'inv_sub_...') work.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'invoices'
      AND column_name = 'id'
      AND data_type = 'uuid'
  ) THEN
    ALTER TABLE public.invoices ALTER COLUMN id DROP DEFAULT;
    ALTER TABLE public.invoices ALTER COLUMN id TYPE text USING id::text;
    ALTER TABLE public.invoices ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;
  END IF;
END $$;

ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS invoice_ref text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS amount numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'INR',
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'paid',
  ADD COLUMN IF NOT EXISTS issued_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS pdf_url text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS line_items jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS provider text NOT NULL DEFAULT 'razorpay',
  ADD COLUMN IF NOT EXISTS provider_subscription_id text,
  ADD COLUMN IF NOT EXISTS provider_payment_id text,
  ADD COLUMN IF NOT EXISTS billing_cycle text,
  ADD COLUMN IF NOT EXISTS tier text,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.invoices
  ALTER COLUMN invoice_ref SET DEFAULT '';

CREATE OR REPLACE FUNCTION public.ensure_invoice_ref_default()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.id IS NULL OR btrim(NEW.id) = '' THEN
    NEW.id := gen_random_uuid()::text;
  END IF;
  IF NEW.invoice_ref IS NULL OR btrim(NEW.invoice_ref) = '' THEN
    NEW.invoice_ref := NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ensure_invoice_ref_default ON public.invoices;
CREATE TRIGGER trg_ensure_invoice_ref_default
  BEFORE INSERT OR UPDATE ON public.invoices
  FOR EACH ROW
  EXECUTE FUNCTION public.ensure_invoice_ref_default();

CREATE INDEX IF NOT EXISTS idx_invoices_user_issued_at
  ON public.invoices (user_id, issued_at DESC);

ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.invoices FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.invoices TO authenticated;
GRANT ALL ON public.invoices TO service_role;

DROP POLICY IF EXISTS invoices_own_read ON public.invoices;
CREATE POLICY invoices_own_read
  ON public.invoices
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()) OR (SELECT public.is_user_admin()));

-- Backfill an initial paid invoice for any active paid subscription that does
-- not yet have a receipt row in public.invoices.
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
  line_items
)
SELECT
  'inv_' || COALESCE(s.provider_subscription_id, replace(s.user_id::text, '-', '')) || '_' || to_char(COALESCE(s.renewed_at, now()), 'YYYYMMDD'),
  'inv_' || COALESCE(s.provider_subscription_id, replace(s.user_id::text, '-', '')) || '_' || to_char(COALESCE(s.renewed_at, now()), 'YYYYMMDD'),
  s.user_id,
  CASE
    WHEN s.tier IN ('enterprise', 'pro') AND COALESCE(s.billing_cycle, 'monthly') = 'annual' THEN 4788.0
    WHEN s.tier IN ('enterprise', 'pro') THEN 499.0
    WHEN COALESCE(s.billing_cycle, 'monthly') = 'annual' THEN 2868.0
    ELSE 299.0
  END,
  'INR',
  'paid',
  COALESCE(s.renewed_at, now()),
  '',
  COALESCE(s.billing_provider, 'razorpay'),
  s.provider_subscription_id,
  COALESCE(s.billing_cycle, 'monthly'),
  CASE WHEN s.tier IN ('enterprise', 'pro') THEN 'enterprise' ELSE 'premium' END,
  jsonb_build_array(
    jsonb_build_object(
      'description',
      CASE
        WHEN s.tier IN ('enterprise', 'pro') THEN 'AlphaJournal Pro (' || CASE WHEN COALESCE(s.billing_cycle, 'monthly') = 'annual' THEN 'Annual' ELSE 'Monthly' END || ' subscription, incl. 18% GST)'
        ELSE 'AlphaJournal Basic (' || CASE WHEN COALESCE(s.billing_cycle, 'monthly') = 'annual' THEN 'Annual' ELSE 'Monthly' END || ' subscription, incl. 18% GST)'
      END,
      'amount',
      CASE
        WHEN s.tier IN ('enterprise', 'pro') AND COALESCE(s.billing_cycle, 'monthly') = 'annual' THEN 4788.0
        WHEN s.tier IN ('enterprise', 'pro') THEN 499.0
        WHEN COALESCE(s.billing_cycle, 'monthly') = 'annual' THEN 2868.0
        ELSE 299.0
      END,
      'quantity',
      1
    )
  )
FROM public.subscriptions s
WHERE s.tier IN ('premium', 'enterprise', 'basic', 'pro')
  AND NOT EXISTS (
    SELECT 1 FROM public.invoices i WHERE i.user_id = s.user_id
  )
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 3. Upgrade public.reconcile_billing_entitlement for Basic ('premium') & Pro ('enterprise')
-- -----------------------------------------------------------------------------
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
  p_intent_status text DEFAULT NULL
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
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'Account user_id is required' USING ERRCODE = '22023';
  END IF;
  IF p_provider NOT IN ('razorpay', 'revenuecat') THEN
    RAISE EXCEPTION 'Unsupported billing provider: %', p_provider USING ERRCODE = '22023';
  END IF;

  -- Serialize all billing reconciliations for this account within the transaction
  PERFORM pg_advisory_xact_lock(hashtext('billing_reconcile'), hashtext(p_user_id::text));

  -- Lock the profile row to verify account existence and serialize tier writes
  PERFORM 1 FROM public.profiles WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Account not found' USING ERRCODE = 'P0002';
  END IF;

  -- Seed provider entitlements from current subscriptions row if not yet tracked
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

  -- Update checkout intent if supplied
  IF p_intent_id IS NOT NULL AND p_intent_status IS NOT NULL THEN
    UPDATE public.billing_checkout_intents
       SET status = p_intent_status,
           updated_at = v_now
     WHERE id = p_intent_id
       AND user_id = p_user_id;
  END IF;

  -- Update the provider-specific entitlement state (preventing an old inactive or lower-tier
  -- Razorpay checkout from overwriting a newer active Razorpay subscription for the same user)
  IF p_provider = 'razorpay' THEN
    SELECT * INTO v_existing_rp
      FROM public.billing_provider_entitlements
     WHERE user_id = p_user_id AND provider = 'razorpay';

    IF FOUND
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

  -- Evaluate effective entitlement across providers while holding the account lock
  SELECT * INTO v_rp
    FROM public.billing_provider_entitlements
   WHERE user_id = p_user_id AND provider = 'razorpay';

  SELECT * INTO v_rc
    FROM public.billing_provider_entitlements
   WHERE user_id = p_user_id AND provider = 'revenuecat';

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
    v_effective_tier := v_rp.tier;
    v_effective_status := v_rp.status;
    v_effective_provider := 'razorpay';
    v_effective_sub_id := v_rp.provider_subscription_id;
    v_effective_rc_id := NULL;
    v_effective_cycle := v_rp.billing_cycle;
    v_effective_renewed := v_rp.renewed_at;
    v_effective_expires := v_rp.expires_at;
  ELSIF v_rc_valid THEN
    v_effective_tier := v_rc.tier;
    v_effective_status := v_rc.status;
    v_effective_provider := 'revenuecat';
    v_effective_sub_id := NULL;
    v_effective_rc_id := v_rc.revenuecat_id;
    v_effective_cycle := v_rc.billing_cycle;
    v_effective_renewed := v_rc.renewed_at;
    v_effective_expires := v_rc.expires_at;
  ELSE
    v_effective_tier := 'free';
    v_effective_status := 'canceled';
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
      CASE
        WHEN v_norm_tier = 'enterprise' AND COALESCE(p_billing_cycle, 'monthly') = 'annual' THEN 4788.0
        WHEN v_norm_tier = 'enterprise' THEN 499.0
        WHEN COALESCE(p_billing_cycle, 'monthly') = 'annual' THEN 2868.0
        ELSE 299.0
      END,
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
          CASE
            WHEN v_norm_tier = 'enterprise' AND COALESCE(p_billing_cycle, 'monthly') = 'annual' THEN 4788.0
            WHEN v_norm_tier = 'enterprise' THEN 499.0
            WHEN COALESCE(p_billing_cycle, 'monthly') = 'annual' THEN 2868.0
            ELSE 299.0
          END,
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
    'expires_at', v_effective_expires
  );
END;
$$;

REVOKE ALL ON FUNCTION public.reconcile_billing_entitlement(
  uuid, text, text, text, text, text, text, timestamptz, timestamptz, text, text, uuid, text
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reconcile_billing_entitlement(
  uuid, text, text, text, text, text, text, timestamptz, timestamptz, text, text, uuid, text
) TO service_role;

-- -----------------------------------------------------------------------------
-- 4. Enable Monthly & Annual Razorpay Subscriptions in public.pricing_catalogues
-- -----------------------------------------------------------------------------
UPDATE public.pricing_catalogues catalogue_row
SET catalogue = catalogue_row.catalogue || jsonb_build_object(
  'plans', (
    SELECT jsonb_agg(
      CASE plan->>'tier'
        WHEN 'free' THEN plan || jsonb_build_object(
          'is_purchasable', true,
          'badge_label', 'AVAILABLE NOW',
          'cta_label', 'Continue with Free',
          'subtitle', 'Community access, core calculators, and limited ticker, news, and instrument previews',
          'tagline', 'Community access, core calculators, and limited ticker, news, and instrument previews',
          'features_summary', jsonb_build_array(
            'Up to 3 research notes and 15 logged trades',
            'Community feed and public post view access',
            'Core calculators',
            'Limited Community ticker, news and instrument previews',
            'No private Messages or full Market Intelligence'
          ),
          'features', jsonb_build_array(
            'Up to 3 research notes and 15 logged trades',
            'Community feed and public post view access',
            'Core calculators',
            'Limited Community ticker, news and instrument previews',
            'No private Messages or full Market Intelligence'
          )
        )
        WHEN 'premium' THEN plan || jsonb_build_object(
          'is_purchasable', true,
          'badge_label', 'MOST POPULAR',
          'cta_label', 'Subscribe to Basic',
          'monthly_amount', 299.0,
          'annual_monthly_amount', 239.0,
          'subtitle', 'Full Market Intelligence, private Messages, advanced calculators, and expanded workspace limits',
          'tagline', 'Full Market Intelligence, private Messages, advanced calculators, and expanded workspace limits',
          'features_summary', jsonb_build_array(
            'Up to 25 research notes and 100 logged trades',
            'Full Market Intelligence and instrument research',
            'Private Messages',
            'All advanced calculators',
            'Up to 20 AI prompts per month'
          ),
          'features', jsonb_build_array(
            'Up to 25 research notes and 100 logged trades',
            'Full Market Intelligence and instrument research',
            'Private Messages',
            'All advanced calculators',
            'Up to 20 AI prompts per month'
          )
        )
        WHEN 'enterprise' THEN plan || jsonb_build_object(
          'is_purchasable', true,
          'badge_label', 'FULL ACCESS',
          'cta_label', 'Subscribe to Pro',
          'monthly_amount', 499.0,
          'annual_monthly_amount', 399.0,
          'subtitle', 'Everything in Basic plus exports, advanced analytics, backtesting, and higher quotas',
          'tagline', 'Everything in Basic plus exports, advanced analytics, backtesting, and higher quotas',
          'features_summary', jsonb_build_array(
            'Everything in Basic, including Markets, Messages and calculators',
            'Up to 10,000 notes and 50,000 logged trades',
            'PDF and CSV exports',
            'Advanced backtesting and analytics',
            'Higher AI, watchlist, alert, and Community quotas'
          ),
          'features', jsonb_build_array(
            'Everything in Basic, including Markets, Messages and calculators',
            'Up to 10,000 notes and 50,000 logged trades',
            'PDF and CSV exports',
            'Advanced backtesting and analytics',
            'Higher AI, watchlist, alert, and Community quotas'
          )
        )
        ELSE plan
      END
      ORDER BY plan_ordinality
    )
    FROM jsonb_array_elements(catalogue_row.catalogue->'plans')
      WITH ORDINALITY AS plans(plan, plan_ordinality)
  ),
  'faqs', jsonb_build_array(
    jsonb_build_object(
      'id', 'faq_billing',
      'category', 'billing',
      'question', 'How do Monthly and Annual Razorpay subscriptions work?',
      'answer', 'You can subscribe to Basic (₹299/mo or ₹2,868/yr) or Pro (₹499/mo or ₹4,788/yr) via Razorpay using UPI AutoPay, credit/debit cards, or NetBanking. Your tier unlocks automatically as soon as Razorpay confirms payment.'
    ),
    jsonb_build_object(
      'id', 'faq_limits',
      'category', 'features',
      'question', 'Which limits are checked today?',
      'answer', 'All plans enforce saved notes (3/25/10,000), logged trades (15/100/50,000), live playbooks (1/3/250), watchlists (1/5/100), price alerts (3/25/500), daily community posts (2/15/100) and comments (10/50/500), PDF/CSV exports (Pro), and hard monthly AI quotas (5/20/5,000) across text, voice, and note refactor.'
    ),
    jsonb_build_object(
      'id', 'faq_cancel',
      'category', 'billing',
      'question', 'Can I cancel my subscription anytime?',
      'answer', 'Yes. Stopping renewal in Billing Settings cancels future charges at the end of your current paid billing cycle while keeping all paid features active until your period expires.'
    ),
    jsonb_build_object(
      'id', 'faq_tax',
      'category', 'billing',
      'question', 'Are paid prices inclusive of GST?',
      'answer', 'Yes. All INR subscription prices (Basic ₹299/mo or ₹2,868/yr; Pro ₹499/mo or ₹4,788/yr) include 18% Indian GST itemized on your billing receipts.'
    )
  ),
  'annual_discount_percent', 20,
  'annual_months_billed', 12,
  'footer_disclaimer', 'Prices in INR (₹) inclusive of 18% GST. Full Market Intelligence and Private Messages require Basic or Pro. Cancel renewal anytime.',
  'copy', COALESCE(catalogue_row.catalogue->'copy', '{}'::jsonb) || jsonb_build_object(
    'badge', 'Plans for every workspace',
    'title', 'Choose Your Trading Plan',
    'description', 'Free includes limited Community market previews. Subscribe monthly or annually via Razorpay to unlock Basic or Pro.',
    'monthly', 'Monthly',
    'annual', 'Billed annually',
    'annual_savings', 'Save 20% with annual billing'
  )
),
updated_at = now()
WHERE id = 'default';

COMMIT;
