BEGIN;

-- Existing subscriptions remains the effective tier record. Provider-specific
-- pending checkout data is separate so an abandoned checkout cannot grant access.
ALTER TABLE public.subscriptions
  ADD COLUMN IF NOT EXISTS billing_provider text,
  ADD COLUMN IF NOT EXISTS provider_subscription_id text;
CREATE UNIQUE INDEX IF NOT EXISTS subscriptions_provider_reference_unique
  ON public.subscriptions (billing_provider, provider_subscription_id)
  WHERE provider_subscription_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.billing_checkout_intents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  tier text NOT NULL CHECK (tier = 'enterprise'),
  billing_cycle text NOT NULL CHECK (billing_cycle IN ('monthly', 'annual')),
  razorpay_plan_id text NOT NULL,
  razorpay_subscription_id text NOT NULL UNIQUE,
  expected_amount_paise bigint NOT NULL CHECK (expected_amount_paise > 0),
  checkout_url text NOT NULL,
  status text NOT NULL DEFAULT 'created'
    CHECK (status IN ('created', 'authenticated', 'active', 'cancelled', 'expired')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS billing_checkout_intents_user_created
  ON public.billing_checkout_intents (user_id, created_at DESC);
ALTER TABLE public.billing_checkout_intents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS billing_checkout_intents_own_read ON public.billing_checkout_intents;
CREATE POLICY billing_checkout_intents_own_read ON public.billing_checkout_intents
  FOR SELECT TO authenticated USING (user_id = auth.uid() OR is_user_admin());
GRANT SELECT ON public.billing_checkout_intents TO authenticated;

-- AI Copilot writes one row before each prompt. Its INSERT trigger in 034
-- enforces the published monthly allowance, including concurrent requests.
DROP POLICY IF EXISTS ai_insight_requests_own_read ON public.ai_insight_requests;
CREATE POLICY ai_insight_requests_own_read ON public.ai_insight_requests
  FOR SELECT TO authenticated USING (user_id = auth.uid() OR is_user_admin());
DROP POLICY IF EXISTS ai_insight_requests_own_insert ON public.ai_insight_requests;
CREATE POLICY ai_insight_requests_own_insert ON public.ai_insight_requests
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
GRANT SELECT, INSERT ON public.ai_insight_requests TO authenticated;

-- Each user sees only their counters. Administrators may supply a target UUID
-- for the account-management view. The caller cannot choose another user.
CREATE OR REPLACE FUNCTION public.get_customer_quota_usage(target_user_id uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE actor_id uuid := auth.uid();
DECLARE effective_user_id uuid := COALESCE(target_user_id, auth.uid());
DECLARE effective_tier text := 'free';
DECLARE published_limits jsonb;
DECLARE note_count integer;
DECLARE trade_count integer;
DECLARE playbook_count integer;
DECLARE ai_count integer;
BEGIN
  IF actor_id IS NULL OR effective_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF effective_user_id <> actor_id AND NOT is_user_admin() THEN
    RAISE EXCEPTION 'Quota access denied' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = effective_user_id) THEN
    RAISE EXCEPTION 'Account not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT s.tier INTO effective_tier FROM public.subscriptions s
    WHERE s.user_id = effective_user_id
      AND s.status IN ('active', 'trialing', 'canceled')
      AND (s.expires_at IS NULL OR s.expires_at > now())
    LIMIT 1;
  effective_tier := COALESCE(effective_tier, 'free');
  SELECT plan->'limits' INTO published_limits
    FROM public.pricing_catalogues c,
         jsonb_array_elements(c.catalogue->'plans') plan
    WHERE c.id = 'default' AND c.published
      AND plan->>'tier' = effective_tier
    LIMIT 1;
  IF published_limits IS NULL THEN
    RAISE EXCEPTION 'Published quota limits unavailable' USING ERRCODE = 'P0002';
  END IF;

  SELECT count(*) INTO note_count FROM public.trader_notes WHERE user_id = effective_user_id;
  SELECT count(*) INTO trade_count FROM public.journal_entries WHERE user_id = effective_user_id;
  SELECT count(*) INTO playbook_count FROM public.strategies
    WHERE user_id = effective_user_id AND status = 'live';
  SELECT count(*) INTO ai_count FROM public.ai_insight_requests
    WHERE user_id = effective_user_id
      AND requested_at >= date_trunc('month', now())
      AND requested_at < date_trunc('month', now()) + interval '1 month';

  RETURN jsonb_build_object(
    'user_id', effective_user_id,
    'tier', effective_tier,
    'limits', published_limits,
    'notes_used', note_count,
    'trades_used', trade_count,
    'live_playbooks_used', playbook_count,
    'ai_queries_used', ai_count,
    'window_started_at', date_trunc('month', now())
  );
END;
$$;
REVOKE ALL ON FUNCTION public.get_customer_quota_usage(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_customer_quota_usage(uuid) TO authenticated;

COMMIT;
