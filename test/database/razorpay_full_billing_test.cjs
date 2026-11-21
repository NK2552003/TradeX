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

const migrationSql = readFileSync(
  resolve(
    __dirname,
    '../../supabase/migrations/20261121010000_razorpay_full_monthly_yearly_billing.sql',
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

const prepareClientConfigSource = readFileSync(
  resolve(__dirname, '../../scripts/prepare_client_config.py'),
  'utf8',
);

const razorpayWebBridgeSource = readFileSync(
  resolve(__dirname, '../../web/razorpay_checkout.js'),
  'utf8',
);

test('Razorpay Edge Functions and client config enforce multi-tier monthly/yearly security', () => {
  // 1. Both Basic ('premium') and Pro ('enterprise') monthly and yearly plan IDs are supported
  assert.match(checkoutEdgeSource, /RAZORPAY_BASIC_MONTHLY_PLAN_ID/);
  assert.match(checkoutEdgeSource, /RAZORPAY_BASIC_YEARLY_PLAN_ID/);
  assert.match(checkoutEdgeSource, /RAZORPAY_PRO_MONTHLY_PLAN_ID/);
  assert.match(checkoutEdgeSource, /RAZORPAY_PRO_YEARLY_PLAN_ID/);
  assert.match(checkoutEdgeSource, /RAZORPAY_BUSINESS_MONTHLY_PLAN_ID/);
  assert.match(checkoutEdgeSource, /RAZORPAY_BUSINESS_YEARLY_PLAN_ID/);

  // 2. Plan period, interval, amount, and INR currency verification against Razorpay API
  assert.match(
    checkoutEdgeSource,
    /remotePlan\.period !== \(cycle === 'annual' \? 'yearly' : 'monthly'\)/,
  );
  assert.match(checkoutEdgeSource, /remotePlan\.interval !== 1/);
  assert.match(checkoutEdgeSource, /remotePlan\.item\?\.amount !== expectedPaise/);
  assert.match(checkoutEdgeSource, /remotePlan\.item\?\.currency !== 'INR'/);

  // 3. Self-serve period-end cancellation and client return verification are supported
  assert.match(checkoutEdgeSource, /body\.action === 'cancel'/);
  assert.match(checkoutEdgeSource, /cancel_at_cycle_end:\s*1/);
  assert.match(checkoutEdgeSource, /body\.action === 'verify'/);
  assert.match(checkoutEdgeSource, /key_id:\s*keyId/);

  // 4. Web inline checkout bridge guarantees return to website on success, failure, and cancel
  assert.match(razorpayWebBridgeSource, /globalThis\.alphajournalRazorpay/);
  assert.match(razorpayWebBridgeSource, /payment\.failed/);
  assert.match(razorpayWebBridgeSource, /ondismiss/);
  assert.match(razorpayWebBridgeSource, /← Return to AlphaJournal/);

  // 5. Webhook reconciles intent.tier ('premium' or 'enterprise') rather than hardcoding enterprise
  assert.match(webhookEdgeSource, /resolvedIntentTier/);
  assert.match(webhookEdgeSource, /p_tier:\s*paidAccess\s*\?\s*resolvedIntentTier\s*:\s*'free'/);

  // 6. Server secrets are never allowlisted in client config
  assert.match(prepareClientConfigSource, /'RAZORPAY_KEY_ID'/);
  assert.doesNotMatch(prepareClientConfigSource, /RAZORPAY_SECRET_KEY/);
  assert.doesNotMatch(prepareClientConfigSource, /RAZORPAY_KEY_SECRET/);
  assert.doesNotMatch(prepareClientConfigSource, /RAZORPAY_WEBHOOK_SECRET/);
});

test('SQL migration defines multi-tier checkout intents, invoices RLS, reconciliation precedence, and purchasable Basic & Pro plans', () => {
  assert.match(
    migrationSql,
    /ADD CONSTRAINT billing_checkout_intents_tier_check[\s\S]+CHECK \(tier IN \('premium', 'enterprise'\)\)/,
  );
  assert.match(
    migrationSql,
    /ADD CONSTRAINT billing_checkout_intents_cycle_check[\s\S]+CHECK \(billing_cycle IN \('monthly', 'annual'\)\)/,
  );
  assert.match(
    migrationSql,
    /ALTER TABLE public\.billing_checkout_intents ENABLE ROW LEVEL SECURITY/,
  );
  assert.match(
    migrationSql,
    /ALTER TABLE public\.invoices ENABLE ROW LEVEL SECURITY/,
  );
  assert.match(
    migrationSql,
    /v_rp_valid := v_rp\.user_id IS NOT NULL[\s\S]+AND v_rp\.tier IN \('premium', 'enterprise'\)/,
  );
  assert.match(
    migrationSql,
    /WHEN 'premium' THEN plan \|\| jsonb_build_object\([\s\S]+'is_purchasable', true[\s\S]+'monthly_amount', 299\.0[\s\S]+'annual_monthly_amount', 239\.0/,
  );
  assert.match(
    migrationSql,
    /WHEN 'enterprise' THEN plan \|\| jsonb_build_object\([\s\S]+'is_purchasable', true[\s\S]+'monthly_amount', 499\.0[\s\S]+'annual_monthly_amount', 399\.0/,
  );
  assert.match(
    migrationSql,
    /REVOKE ALL ON FUNCTION public\.reconcile_billing_entitlement[\s\S]+FROM PUBLIC, anon, authenticated/,
  );
  assert.match(
    migrationSql,
    /GRANT EXECUTE ON FUNCTION public\.reconcile_billing_entitlement[\s\S]+TO service_role/,
  );
});

test(
  'PGlite execution of Razorpay Basic & Pro monthly/yearly SQL migration',
  { skip: !PGlite },
  async () => {
    const db = new PGlite();
    const alice = '00000000-0000-0000-0000-000000000001';
    const bob = '00000000-0000-0000-0000-000000000002';

    await db.exec(`
      CREATE EXTENSION IF NOT EXISTS pgcrypto;
      DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon NOLOGIN; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role NOLOGIN BYPASSRLS; END IF;
      END $$;

      CREATE SCHEMA IF NOT EXISTS auth;
      GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;

      CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
        SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
      $$;
      GRANT EXECUTE ON FUNCTION auth.uid() TO PUBLIC, anon, authenticated, service_role;

      CREATE TABLE public.profiles (
        id uuid PRIMARY KEY,
        role text NOT NULL DEFAULT 'customer',
        status text NOT NULL DEFAULT 'active',
        subscription_tier text NOT NULL DEFAULT 'free',
        updated_at timestamptz NOT NULL DEFAULT now()
      );

      CREATE OR REPLACE FUNCTION public.is_user_admin() RETURNS boolean LANGUAGE sql STABLE AS $$
        SELECT EXISTS (
          SELECT 1 FROM public.profiles
          WHERE id = auth.uid() AND role = 'user_admin' AND status = 'active'
        );
      $$;
      GRANT EXECUTE ON FUNCTION public.is_user_admin() TO PUBLIC, anon, authenticated, service_role;

      CREATE TABLE public.subscriptions (
        user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
        tier text NOT NULL DEFAULT 'free',
        status text NOT NULL DEFAULT 'active',
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
        tier text NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'premium', 'enterprise')),
        status text NOT NULL DEFAULT 'canceled' CHECK (status IN ('active', 'canceled', 'expired', 'authenticated', 'created')),
        provider_subscription_id text,
        revenuecat_id text,
        billing_cycle text CHECK (billing_cycle IS NULL OR billing_cycle IN ('monthly', 'annual')),
        renewed_at timestamptz,
        expires_at timestamptz,
        updated_at timestamptz NOT NULL DEFAULT now(),
        PRIMARY KEY (user_id, provider)
      );

      CREATE TABLE public.billing_webhook_receipts (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        provider text NOT NULL CHECK (provider IN ('razorpay', 'revenuecat')),
        event_id text NOT NULL,
        user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
        event_type text NOT NULL DEFAULT 'UNKNOWN',
        processed_at timestamptz NOT NULL DEFAULT now(),
        UNIQUE (provider, event_id)
      );

      CREATE TABLE public.pricing_catalogues (
        id text PRIMARY KEY,
        catalogue jsonb NOT NULL,
        published boolean NOT NULL DEFAULT true,
        updated_at timestamptz NOT NULL DEFAULT now()
      );

      INSERT INTO public.pricing_catalogues (id, catalogue, published)
      VALUES (
        'default',
        '{"plans":[{"id":"tier_free","tier":"free","name":"Free","monthly_amount":0,"annual_monthly_amount":0,"is_purchasable":true},{"id":"tier_pro","tier":"premium","name":"Basic","monthly_amount":299,"annual_monthly_amount":239,"is_purchasable":false},{"id":"tier_enterprise","tier":"enterprise","name":"Pro","monthly_amount":499,"annual_monthly_amount":399,"is_purchasable":false}]}'::jsonb,
        true
      );

      INSERT INTO public.profiles (id, role, status, subscription_tier) VALUES
        ('${alice}', 'customer', 'active', 'free'),
        ('${bob}', 'customer', 'active', 'free');

      GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
      GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
    `);

    await db.exec(migrationSql);
    await db.exec(migrationSql);
    await db.close();
  },
);
