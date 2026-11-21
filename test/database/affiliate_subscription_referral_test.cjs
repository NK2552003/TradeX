const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');

let PGlite = null;
try {
  ({ PGlite } = require('@electric-sql/pglite'));
} catch {
  PGlite = null;
}

const migration21 = readFileSync(
  resolve(
    __dirname,
    '../../supabase/migrations/20261121010000_razorpay_full_monthly_yearly_billing.sql',
  ),
  'utf8',
);

const migrationAffiliate = readFileSync(
  resolve(
    __dirname,
    '../../supabase/migrations/20261121020000_affiliate_referral_subscription_system.sql',
  ),
  'utf8',
);

const checkoutEdgeSource = readFileSync(
  resolve(__dirname, '../../supabase/functions/create-business-checkout/index.ts'),
  'utf8',
);

const webhookEdgeSource = readFileSync(
  resolve(__dirname, '../../supabase/functions/razorpay-webhook/index.ts'),
  'utf8',
);

const publicationJson = JSON.parse(
  readFileSync(
    resolve(__dirname, '../../assets/legal/publication_library.json'),
    'utf8',
  ),
);

test('Razorpay Edge Functions enforce affiliate referral validation, Monthly Month-1 offers, plan switch cancellation, and refund clawback', () => {
  // 1. Monthly referral offers only (Basic ₹299->₹239 = ₹60 off, Pro ₹499->₹399 = ₹100 off)
  assert.match(checkoutEdgeSource, /RAZORPAY_AFFILIATE_BASIC_MONTHLY_OFFER_ID/);
  assert.match(checkoutEdgeSource, /RAZORPAY_AFFILIATE_PRO_MONTHLY_OFFER_ID/);
  assert.match(checkoutEdgeSource, /if \(cycle !== 'monthly'\) return undefined/);
  assert.match(checkoutEdgeSource, /body\.action === 'validate_referral'/);
  assert.match(checkoutEdgeSource, /validate_referral_code/);
  assert.match(checkoutEdgeSource, /reserve_affiliate_referral_redemption/);
  assert.match(checkoutEdgeSource, /finalize_affiliate_referral_conversion/);
  assert.match(checkoutEdgeSource, /subscriptionPayload\.offer_id = razorpayOfferId/);

  // 2. Plan switch safety: cancels superseded Razorpay subscription immediately on activation
  assert.match(checkoutEdgeSource, /replaces_subscription_id/);
  assert.match(checkoutEdgeSource, /cancelSupersededRazorpaySubscription/);
  assert.match(checkoutEdgeSource, /cancel_at_cycle_end:\s*0/);

  // 3. Webhook handles refund clawback + affiliate conversion finalization + superseded cancellation
  assert.match(webhookEdgeSource, /refund\.processed/);
  assert.match(webhookEdgeSource, /payment\.refunded/);
  assert.match(webhookEdgeSource, /reverse_affiliate_referral_conversion/);
  assert.match(webhookEdgeSource, /finalize_affiliate_referral_conversion/);
  assert.match(webhookEdgeSource, /p_replaces_subscription_id/);
});

test('SQL migration enforces RLS, 1-per-user redemption lock, affiliate coupon ban, ₹10/₹30 payout tiers, and 50-user Free Pro milestone', () => {
  // 1. RLS & grants on new redemption table
  assert.match(
    migrationAffiliate,
    /CREATE TABLE IF NOT EXISTS public\.affiliate_referral_redemptions[\s\S]+user_id uuid PRIMARY KEY/,
  );
  assert.match(
    migrationAffiliate,
    /ALTER TABLE public\.affiliate_referral_redemptions ENABLE ROW LEVEL SECURITY/,
  );
  assert.match(
    migrationAffiliate,
    /REVOKE ALL ON public\.affiliate_referral_redemptions FROM PUBLIC, anon, authenticated/,
  );
  assert.match(
    migrationAffiliate,
    /CREATE UNIQUE INDEX IF NOT EXISTS idx_affiliate_referrals_unique_referred_user/,
  );

  // 2. Monthly Month-1 subscriber discount: Basic ₹60 off (₹239), Pro ₹100 off (₹399)
  assert.match(migrationAffiliate, /v_discount_inr := 60;/);
  assert.match(migrationAffiliate, /v_discount_inr := 100;/);

  // 3. Affiliate payout schedule: ₹10 for slots 1–50, ₹30 for slots 51+
  assert.match(
    migrationAffiliate,
    /v_commission_inr := CASE WHEN v_slot <= 50 THEN 10\.00 ELSE 30\.00 END/,
  );

  // 4. Strict affiliate coupon ban
  assert.match(migrationAffiliate, /tradex_private\.is_affiliate_account\(v_caller\)/);
  assert.match(migrationAffiliate, /affiliate_coupon_prohibited/);

  // 5. Complimentary Pro unlocks ONLY at paid_referrals_count >= 50
  assert.match(
    migrationAffiliate,
    /a\.status = 'active'[\s\S]+a\.paid_referrals_count >= 50[\s\S]+a\.complimentary_pro_unlocked = true/,
  );
  assert.match(
    migrationAffiliate,
    /v_should_unlock := \(v_aff\.status = 'active' AND v_aff\.paid_referrals_count >= 50\)/,
  );

  // 6. Privileged RPCs locked down to service_role
  assert.match(
    migrationAffiliate,
    /REVOKE ALL ON FUNCTION public\.finalize_affiliate_referral_conversion[\s\S]+FROM PUBLIC, anon, authenticated/,
  );
  assert.match(
    migrationAffiliate,
    /REVOKE ALL ON FUNCTION public\.reverse_affiliate_referral_conversion[\s\S]+FROM PUBLIC, anon, authenticated/,
  );
  assert.match(
    migrationAffiliate,
    /REVOKE ALL ON FUNCTION public\.reserve_affiliate_referral_redemption[\s\S]+FROM PUBLIC, anon, authenticated/,
  );
  assert.match(
    migrationAffiliate,
    /REVOKE ALL ON FUNCTION public\.sync_affiliate_milestone_entitlement[\s\S]+FROM PUBLIC, anon, authenticated/,
  );
});

test('Legal publication library includes Revision 2026.2-INR rules for affiliate payouts, Monthly discounts, coupon ban, and 50-user Free Pro milestone', () => {
  const byId = new Map(publicationJson.map((doc) => [doc.id, doc]));
  const agreement = byId.get('affiliate-agreement');
  const payouts = byId.get('affiliate-payouts');
  const terms = byId.get('terms');

  assert.ok(agreement, 'affiliate-agreement missing');
  assert.ok(payouts, 'affiliate-payouts missing');
  assert.ok(terms, 'terms missing');

  assert.equal(agreement.updated, '2026-11-21');
  assert.equal(payouts.updated, '2026-11-21');
  assert.equal(terms.updated, '2026-11-21');

  const agreementText = JSON.stringify(agreement);
  assert.match(agreementText, /2026\.2-INR/);
  assert.match(agreementText, /₹10 INR/);
  assert.match(agreementText, /₹30 INR/);
  assert.match(agreementText, /₹239/);
  assert.match(agreementText, /₹399/);
  assert.match(agreementText, /50 distinct referred users/);
  assert.match(agreementText, /strictly prohibited from redeeming their own referral code, any other affiliate's referral code/i);

  const payoutsText = JSON.stringify(payouts);
  assert.match(payoutsText, /2026\.2-INR/);
  assert.match(payoutsText, /₹10 INR/);
  assert.match(payoutsText, /₹30 INR/);
});

test(
  'PGlite end-to-end execution: ₹10/₹30 affiliate tiers, Month-1 ₹239/₹399 discount, affiliate coupon ban, 1-per-user lock, and 50-user Pro unlock/revocation',
  { skip: !PGlite },
  async () => {
    const db = new PGlite();
    const aff1 = '00000000-0000-0000-0000-000000000101';
    const aff2 = '00000000-0000-0000-0000-000000000102';
    const buyer1 = '00000000-0000-0000-0000-000000000201';
    const buyer2 = '00000000-0000-0000-0000-000000000202';

    await db.exec(`
      CREATE EXTENSION IF NOT EXISTS pgcrypto;
      DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon NOLOGIN; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role NOLOGIN BYPASSRLS; END IF;
      END $$;

      CREATE SCHEMA IF NOT EXISTS auth;
      CREATE SCHEMA IF NOT EXISTS tradex_private;
      CREATE SCHEMA IF NOT EXISTS private;
      GRANT USAGE ON SCHEMA auth, tradex_private TO anon, authenticated, service_role;

      CREATE TABLE auth.users (id uuid PRIMARY KEY, email text, raw_user_meta_data jsonb DEFAULT '{}'::jsonb);
      CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
        SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
      $$;
      GRANT EXECUTE ON FUNCTION auth.uid() TO PUBLIC, anon, authenticated, service_role;

      CREATE TABLE public.profiles (
        id uuid PRIMARY KEY,
        handle text UNIQUE,
        email text,
        display_name text,
        role text NOT NULL DEFAULT 'customer',
        status text NOT NULL DEFAULT 'active',
        referral_code text,
        referred_by_code text,
        avatar_url text,
        subscription_tier text NOT NULL DEFAULT 'free',
        admin_controls jsonb NOT NULL DEFAULT '{}'::jsonb,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now()
      );

      CREATE OR REPLACE FUNCTION public.is_user_admin() RETURNS boolean LANGUAGE sql STABLE AS $$
        SELECT false;
      $$;

      CREATE TABLE public.subscriptions (
        user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
        tier text NOT NULL DEFAULT 'free',
        status text NOT NULL DEFAULT 'canceled',
        billing_provider text,
        provider_subscription_id text,
        revenuecat_id text,
        billing_cycle text,
        renewed_at timestamptz,
        expires_at timestamptz,
        updated_at timestamptz NOT NULL DEFAULT now()
      );

      CREATE TABLE public.billing_provider_entitlements (
        user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
        provider text NOT NULL CHECK (provider IN ('razorpay', 'revenuecat')),
        tier text NOT NULL CHECK (tier IN ('free', 'premium', 'enterprise')),
        status text NOT NULL CHECK (status IN ('active', 'canceled', 'expired', 'authenticated', 'created')),
        provider_subscription_id text,
        revenuecat_id text,
        billing_cycle text CHECK (billing_cycle IN ('monthly', 'annual')),
        renewed_at timestamptz,
        expires_at timestamptz,
        updated_at timestamptz NOT NULL DEFAULT now(),
        PRIMARY KEY (user_id, provider)
      );

      CREATE TABLE public.billing_webhook_receipts (
        provider text NOT NULL,
        event_id text NOT NULL,
        user_id uuid NOT NULL,
        event_type text NOT NULL,
        processed_at timestamptz NOT NULL DEFAULT now(),
        PRIMARY KEY (provider, event_id)
      );

      CREATE TABLE public.pricing_catalogues (
        id text PRIMARY KEY,
        catalogue jsonb NOT NULL,
        published boolean NOT NULL DEFAULT true,
        updated_at timestamptz NOT NULL DEFAULT now()
      );

      CREATE TABLE public.affiliate_profiles (
        id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
        affiliate_code text UNIQUE NOT NULL,
        custom_slug text UNIQUE,
        tier text NOT NULL DEFAULT 'starter',
        commission_rate numeric NOT NULL DEFAULT 0,
        total_referrals integer NOT NULL DEFAULT 0,
        active_referrals integer NOT NULL DEFAULT 0,
        total_earnings numeric NOT NULL DEFAULT 0,
        unpaid_balance numeric NOT NULL DEFAULT 0,
        paid_earnings numeric NOT NULL DEFAULT 0,
        payout_method text NOT NULL DEFAULT 'upi',
        payout_details jsonb NOT NULL DEFAULT '{}'::jsonb,
        minimum_payout_threshold numeric NOT NULL DEFAULT 1000,
        auto_payout_enabled boolean NOT NULL DEFAULT false,
        currency text NOT NULL DEFAULT 'INR',
        status text NOT NULL DEFAULT 'active',
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now()
      );

      CREATE TABLE public.affiliate_applications (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
        status text NOT NULL DEFAULT 'pending',
        created_at timestamptz NOT NULL DEFAULT now()
      );

      CREATE TABLE public.affiliate_campaigns (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        affiliate_id uuid NOT NULL REFERENCES public.affiliate_profiles(id) ON DELETE CASCADE,
        name text NOT NULL,
        slug text NOT NULL,
        channel text NOT NULL,
        status text NOT NULL DEFAULT 'active',
        clicks bigint NOT NULL DEFAULT 0,
        created_at timestamptz NOT NULL DEFAULT now()
      );

      CREATE TABLE public.affiliate_referrals (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        affiliate_id uuid NOT NULL REFERENCES public.affiliate_profiles(id) ON DELETE CASCADE,
        referred_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
        referral_code text NOT NULL,
        status text NOT NULL DEFAULT 'pending',
        bonus_awarded numeric NOT NULL DEFAULT 0,
        channel text NOT NULL DEFAULT 'direct',
        campaign_id uuid REFERENCES public.affiliate_campaigns(id) ON DELETE SET NULL,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now()
      );

      CREATE TABLE public.affiliate_payouts (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        affiliate_id uuid NOT NULL REFERENCES public.affiliate_profiles(id) ON DELETE CASCADE,
        amount numeric NOT NULL,
        currency text NOT NULL DEFAULT 'INR',
        status text NOT NULL DEFAULT 'pending',
        created_at timestamptz NOT NULL DEFAULT now()
      );

      CREATE TABLE public.affiliate_assets (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        title text NOT NULL,
        format text NOT NULL,
        body text NOT NULL,
        published boolean NOT NULL DEFAULT false,
        created_at timestamptz NOT NULL DEFAULT now()
      );

      INSERT INTO public.pricing_catalogues (id, catalogue, published)
      VALUES ('default', '{"plans":[{"tier":"free"},{"tier":"premium"},{"tier":"enterprise"}]}'::jsonb, true);
    `);

    await db.exec(migration21);
    await db.exec(migrationAffiliate);

    await db.exec(`
      INSERT INTO public.profiles (id, handle, email, role) VALUES
        ('${aff1}', '@aff1', 'aff1@example.com', 'affiliate'),
        ('${aff2}', '@aff2', 'aff2@example.com', 'affiliate'),
        ('${buyer1}', '@buyer1', 'buyer1@example.com', 'customer'),
        ('${buyer2}', '@buyer2', 'buyer2@example.com', 'customer');
      INSERT INTO public.affiliate_profiles (id, affiliate_code, custom_slug, status, paid_referrals_count) VALUES
        ('${aff1}', 'AFFONE26', 'aff-one', 'active', 49),
        ('${aff2}', 'AFFTWO26', 'aff-two', 'active', 0);
    `);

    // 1. Affiliate 1 at 49 paid referrals does NOT have complimentary Pro
    const tierAt49 = await db.query(
      `SELECT tradex_private.effective_tier('${aff1}') AS tier`,
    );
    assert.equal(tierAt49.rows[0].tier, 'free');

    // 2. Affiliate 2 is BLOCKED from using own code AND BLOCKED from using Affiliate 1's code
    const ownCodeRes = await db.query(
      `SELECT public.validate_referral_code('AFFTWO26', 'premium', 'monthly', '${aff2}') AS res`,
    );
    assert.equal(ownCodeRes.rows[0].res.valid, false);
    assert.equal(ownCodeRes.rows[0].res.error_code, 'affiliate_coupon_prohibited');

    const otherAffCodeRes = await db.query(
      `SELECT public.validate_referral_code('AFFONE26', 'premium', 'monthly', '${aff2}') AS res`,
    );
    assert.equal(otherAffCodeRes.rows[0].res.valid, false);
    assert.equal(otherAffCodeRes.rows[0].res.error_code, 'affiliate_coupon_prohibited');

    // 3. Regular buyer1 gets ₹60 off Basic Monthly (₹239 Month 1, ₹299 renewal) & ₹100 off Pro Monthly (₹399 Month 1)
    const basicMonthly = await db.query(
      `SELECT public.validate_referral_code('AFFONE26', 'premium', 'monthly', '${buyer1}') AS res`,
    );
    assert.equal(basicMonthly.rows[0].res.valid, true);
    assert.equal(basicMonthly.rows[0].res.discount_inr, 60);
    assert.equal(basicMonthly.rows[0].res.payable_amount_inr, 239);
    assert.equal(basicMonthly.rows[0].res.renewal_amount_inr, 299);
    assert.equal(basicMonthly.rows[0].res.affiliate_commission_inr, 10);

    const proMonthly = await db.query(
      `SELECT public.validate_referral_code('AFFONE26', 'enterprise', 'monthly', '${buyer1}') AS res`,
    );
    assert.equal(proMonthly.rows[0].res.discount_inr, 100);
    assert.equal(proMonthly.rows[0].res.payable_amount_inr, 399);

    const basicAnnual = await db.query(
      `SELECT public.validate_referral_code('AFFONE26', 'premium', 'annual', '${buyer1}') AS res`,
    );
    assert.equal(basicAnnual.rows[0].res.valid, true);
    assert.equal(basicAnnual.rows[0].res.discount_inr, 0);
    assert.equal(basicAnnual.rows[0].res.applies_discount, false);

    // 4. Finalizing conversion #50 awards ₹10 AND automatically unlocks complimentary Pro for aff1
    const conv50 = await db.query(
      `SELECT public.finalize_affiliate_referral_conversion('${buyer1}', '${aff1}', 'AFFONE26', 'premium', 'monthly', 239, 60, 'sub_50', 'pay_50') AS res`,
    );
    assert.equal(conv50.rows[0].res.conversion_slot, 50);
    assert.equal(conv50.rows[0].res.commission_inr, 10);
    assert.equal(conv50.rows[0].res.milestone.complimentary_pro_unlocked, true);

    const tierAt50 = await db.query(
      `SELECT tradex_private.effective_tier('${aff1}') AS tier`,
    );
    assert.equal(tierAt50.rows[0].tier, 'enterprise');

    // 5. buyer1 CANNOT redeem a second referral code (1 per user lifetime)
    const secondAttempt = await db.query(
      `SELECT public.validate_referral_code('AFFTWO26', 'enterprise', 'monthly', '${buyer1}') AS res`,
    );
    assert.equal(secondAttempt.rows[0].res.valid, false);
    assert.equal(secondAttempt.rows[0].res.error_code, 'already_redeemed');

    // 6. Conversion #51 (buyer2) awards ₹30 to aff1!
    const conv51 = await db.query(
      `SELECT public.finalize_affiliate_referral_conversion('${buyer2}', '${aff1}', 'AFFONE26', 'enterprise', 'monthly', 399, 100, 'sub_51', 'pay_51') AS res`,
    );
    assert.equal(conv51.rows[0].res.conversion_slot, 51);
    assert.equal(conv51.rows[0].res.commission_inr, 30);

    // 7. Refunding both buyer2 & buyer1 drops count to 49 and automatically REVOKES complimentary Pro
    await db.query(
      `SELECT public.reverse_affiliate_referral_conversion('sub_51', 'pay_51', NULL)`,
    );
    const rev50 = await db.query(
      `SELECT public.reverse_affiliate_referral_conversion('sub_50', 'pay_50', NULL) AS res`,
    );
    assert.equal(rev50.rows[0].res.reversed, true);
    assert.equal(rev50.rows[0].res.milestone.complimentary_pro_unlocked, false);
    const tierAfterRefund = await db.query(
      `SELECT tradex_private.effective_tier('${aff1}') AS tier`,
    );
    assert.equal(tierAfterRefund.rows[0].tier, 'free');
  },
);
