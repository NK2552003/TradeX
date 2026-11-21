import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsPreflightResponse, withCorsHeaders } from '../_shared/cors.ts';
import { createEdgeRequestLogger, describeError } from '../_shared/logger.ts';

const headers = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const ALLOWED_CHECKOUT_HOSTS = new Set([
  'rzp.io',
  'razorpay.com',
  'www.razorpay.com',
  'api.razorpay.com',
]);

function reply(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), { status, headers });
}

function hex(bytes: Uint8Array): string {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('');
}

function equalHex(expected: string, received: string): boolean {
  if (expected.length !== received.length) return false;
  let difference = 0;
  for (let i = 0; i < expected.length; i++) {
    difference |= expected.charCodeAt(i) ^ received.charCodeAt(i);
  }
  return difference === 0;
}

export function normalizePaidTier(rawTier: unknown): 'premium' | 'enterprise' | null {
  if (rawTier === undefined || rawTier === null || String(rawTier).trim() === '') {
    return 'enterprise';
  }
  const normalized = String(rawTier).trim().toLowerCase();
  if (['premium', 'basic', 'tier_pro', 'tier_basic'].includes(normalized)) {
    return 'premium';
  }
  if (['enterprise', 'pro', 'business', 'tier_enterprise'].includes(normalized)) {
    return 'enterprise';
  }
  return null;
}

export function normalizeBillingCycle(rawCycle: unknown): 'monthly' | 'annual' | null {
  const normalized = String(rawCycle ?? '').trim().toLowerCase();
  if (normalized === 'monthly') return 'monthly';
  if (normalized === 'annual' || normalized === 'yearly') return 'annual';
  return null;
}

export function resolveRazorpayPlanId(
  tier: 'premium' | 'enterprise',
  cycle: 'monthly' | 'annual',
  env: { get(key: string): string | undefined } = Deno.env,
): string | undefined {
  if (tier === 'premium') {
    if (cycle === 'monthly') {
      return (
        env.get('RAZORPAY_BASIC_MONTHLY_PLAN_ID') ??
        env.get('RAZORPAY_PREMIUM_MONTHLY_PLAN_ID')
      );
    }
    return (
      env.get('RAZORPAY_BASIC_YEARLY_PLAN_ID') ??
      env.get('RAZORPAY_BASIC_ANNUAL_PLAN_ID') ??
      env.get('RAZORPAY_PREMIUM_YEARLY_PLAN_ID')
    );
  }
  if (cycle === 'monthly') {
    return (
      env.get('RAZORPAY_PRO_MONTHLY_PLAN_ID') ??
      env.get('RAZORPAY_BUSINESS_MONTHLY_PLAN_ID') ??
      env.get('RAZORPAY_ENTERPRISE_MONTHLY_PLAN_ID')
    );
  }
  return (
    env.get('RAZORPAY_PRO_YEARLY_PLAN_ID') ??
    env.get('RAZORPAY_BUSINESS_YEARLY_PLAN_ID') ??
    env.get('RAZORPAY_PRO_ANNUAL_PLAN_ID') ??
    env.get('RAZORPAY_ENTERPRISE_YEARLY_PLAN_ID')
  );
}

export async function handleCheckoutEntry(request: Request): Promise<Response> {
  if (request.method === 'OPTIONS') return corsPreflightResponse(request);
  const logger = createEdgeRequestLogger('create-business-checkout', request);
  try {
    return logger.finish(
      withCorsHeaders(request, await handleCheckoutRequest(request, logger)),
    );
  } catch (error) {
    logger.log('error', 'unhandled_exception', describeError(error));
    return logger.finish(
      withCorsHeaders(request, reply(500, { error: 'Checkout could not be created.' })),
    );
  }
}

export async function handleCheckoutRequest(
  request: Request,
  logger: ReturnType<typeof createEdgeRequestLogger>,
): Promise<Response> {
  if (request.method !== 'POST') return reply(405, { error: 'Method not allowed' });

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey =
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY');
  const keyId = Deno.env.get('RAZORPAY_KEY_ID');
  const keySecret =
    Deno.env.get('RAZORPAY_SECRET_KEY') ?? Deno.env.get('RAZORPAY_KEY_SECRET');

  if (!url || !anonKey || !serviceKey || !keyId || !keySecret) {
    return reply(503, { error: 'Razorpay checkout is not configured.' });
  }

  const authorization = request.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) {
    return reply(401, { error: 'Sign in required.' });
  }

  const account = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const {
    data: { user },
    error: authError,
  } = await account.auth.getUser(authorization.slice(7));
  if (authError || !user?.email) {
    return reply(401, { error: 'Signed-in account required.' });
  }

  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return reply(400, { error: 'Invalid request.' });
  }

  const service = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const razorpayHeaders = {
    Authorization: `Basic ${btoa(`${keyId}:${keySecret}`)}`,
    'Content-Type': 'application/json',
  };

  if (body.action === 'cancel') {
    return await handleCancelSubscription(user.id, service, razorpayHeaders, logger);
  }

  if (body.action === 'verify') {
    return await handleVerifySubscription(
      user.id,
      body,
      keySecret,
      service,
      razorpayHeaders,
      logger,
    );
  }

  const tier = normalizePaidTier(body.tier ?? body.tier_id);
  if (!tier) {
    return reply(400, { error: 'Choose Basic or Pro subscription plan.' });
  }

  const cycle = normalizeBillingCycle(body.billing_cycle);
  if (!cycle) {
    return reply(400, { error: 'Choose monthly or annual billing.' });
  }

  const planId = resolveRazorpayPlanId(tier, cycle);
  if (!planId) {
    return reply(503, {
      error: `${tier === 'premium' ? 'Basic' : 'Pro'} ${cycle} Razorpay plan is not configured.`,
    });
  }

  const { data: catalogue, error: catalogueError } = await service
    .from('pricing_catalogues')
    .select('catalogue')
    .eq('id', 'default')
    .eq('published', true)
    .maybeSingle();
  if (catalogueError || !catalogue) {
    return reply(503, { error: 'Published pricing is unavailable.' });
  }

  const plans = (catalogue.catalogue as { plans?: Array<Record<string, unknown>> }).plans;
  const targetPlan = plans?.find((plan) => plan.tier === tier);
  if (!targetPlan) {
    return reply(503, { error: 'Requested plan pricing is unavailable.' });
  }

  const amount =
    cycle === 'annual'
      ? Number(targetPlan.annual_monthly_amount) * 12
      : Number(targetPlan.monthly_amount);
  const expectedPaise = Math.round(amount * 100);
  if (!Number.isSafeInteger(expectedPaise) || expectedPaise <= 0) {
    return reply(503, { error: 'Published plan pricing is invalid.' });
  }

  const planResponse = await fetch(
    `https://api.razorpay.com/v1/plans/${encodeURIComponent(planId)}`,
    { headers: razorpayHeaders },
  );
  if (!planResponse.ok) {
    return reply(502, { error: 'Payment plan verification failed.' });
  }
  const remotePlan = (await planResponse.json()) as {
    period?: string;
    interval?: number;
    item?: { amount?: number; currency?: string };
  };
  if (
    remotePlan.period !== (cycle === 'annual' ? 'yearly' : 'monthly') ||
    remotePlan.interval !== 1 ||
    remotePlan.item?.amount !== expectedPaise ||
    remotePlan.item?.currency !== 'INR'
  ) {
    return reply(503, { error: 'Payment plan does not match published pricing.' });
  }

  const productSlug =
    tier === 'premium' ? 'alphajournal_basic' : 'alphajournal_pro';
  const created = await fetch('https://api.razorpay.com/v1/subscriptions', {
    method: 'POST',
    headers: razorpayHeaders,
    body: JSON.stringify({
      plan_id: planId,
      total_count: cycle === 'annual' ? 10 : 120,
      quantity: 1,
      customer_notify: true,
      notify_info: { notify_email: user.email },
      notes: {
        user_id: user.id,
        tier,
        billing_cycle: cycle,
        product: productSlug,
      },
    }),
  });
  if (!created.ok) {
    return reply(502, { error: 'Payment provider could not start checkout.' });
  }
  const subscription = (await created.json()) as { id?: string; short_url?: string };
  if (!subscription.id || !subscription.short_url) {
    return reply(502, { error: 'Payment provider returned an incomplete checkout.' });
  }

  let checkout: URL;
  try {
    checkout = new URL(subscription.short_url);
  } catch {
    return reply(502, { error: 'Payment provider returned an invalid checkout.' });
  }
  if (checkout.protocol !== 'https:' || !ALLOWED_CHECKOUT_HOSTS.has(checkout.hostname)) {
    return reply(502, { error: 'Payment provider returned an invalid checkout.' });
  }

  const { error: saveError } = await service.from('billing_checkout_intents').insert({
    user_id: user.id,
    tier,
    billing_cycle: cycle,
    razorpay_plan_id: planId,
    razorpay_subscription_id: subscription.id,
    expected_amount_paise: expectedPaise,
    checkout_url: checkout.toString(),
    status: 'created',
  });
  if (saveError) {
    logger.log('error', 'checkout_intent_save_failed', describeError(saveError));
    return reply(500, { error: 'Checkout could not be saved.' });
  }

  logger.log('info', 'checkout_created', { tier, billing_cycle: cycle });
  return reply(200, {
    subscription_id: subscription.id,
    checkout_url: checkout.toString(),
    key_id: keyId,
    tier,
    billing_cycle: cycle,
    amount_paise: expectedPaise,
    currency: 'INR',
  });
}

async function handleVerifySubscription(
  userId: string,
  body: Record<string, unknown>,
  keySecret: string,
  service: ReturnType<typeof createClient>,
  razorpayHeaders: Record<string, string>,
  logger: ReturnType<typeof createEdgeRequestLogger>,
): Promise<Response> {
  const subscriptionId = String(
    body.razorpay_subscription_id ?? body.subscription_id ?? '',
  ).trim();
  const paymentId = String(body.razorpay_payment_id ?? '').trim();
  const signature = String(body.razorpay_signature ?? '').trim().toLowerCase();

  if (!subscriptionId.startsWith('sub_')) {
    return reply(400, { error: 'Valid subscription_id is required.' });
  }

  const { data: intent, error: intentError } = await service
    .from('billing_checkout_intents')
    .select('*')
    .eq('user_id', userId)
    .eq('razorpay_subscription_id', subscriptionId)
    .maybeSingle();

  if (intentError || !intent) {
    return reply(404, { error: 'Checkout session not found for this account.' });
  }

  let signatureVerified = false;
  if (paymentId.startsWith('pay_') && /^[0-9a-f]{64}$/.test(signature)) {
    const hmacKey = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(keySecret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign'],
    );
    const digest = new Uint8Array(
      await crypto.subtle.sign(
        'HMAC',
        hmacKey,
        new TextEncoder().encode(`${paymentId}|${subscriptionId}`),
      ),
    );
    if (!equalHex(hex(digest), signature)) {
      return reply(401, { error: 'Invalid payment signature.' });
    }
    signatureVerified = true;
  }

  const providerResponse = await fetch(
    `https://api.razorpay.com/v1/subscriptions/${encodeURIComponent(subscriptionId)}`,
    { headers: razorpayHeaders },
  );
  if (!providerResponse.ok) {
    return reply(502, { error: 'Could not verify subscription with payment provider.' });
  }
  const provider = (await providerResponse.json()) as {
    id?: string;
    plan_id?: string;
    status?: string;
    current_start?: number | null;
    current_end?: number | null;
    short_url?: string | null;
  };

  if (provider.id !== subscriptionId || provider.plan_id !== intent.razorpay_plan_id) {
    return reply(409, { error: 'Subscription plan mismatch.' });
  }

  const resolvedIntentTier =
    String(intent.tier ?? 'enterprise').toLowerCase() === 'premium'
      ? 'premium'
      : 'enterprise';
  const cycle = intent.billing_cycle === 'annual' ? 'annual' : 'monthly';
  const nowMs = Date.now();
  const fallbackDays = cycle === 'annual' ? 365 : 30;
  const end =
    typeof provider.current_end === 'number' && provider.current_end * 1000 > nowMs
      ? new Date(provider.current_end * 1000)
      : new Date(nowMs + fallbackDays * 24 * 60 * 60 * 1000);

  const isActivated =
    provider.status === 'active' ||
    (signatureVerified &&
      ['active', 'authenticated', 'created'].includes(String(provider.status ?? '')));

  if (!isActivated) {
    return reply(200, {
      verified: false,
      status: String(provider.status ?? 'pending'),
      tier: 'free',
    });
  }

  const renewedAtIso =
    typeof provider.current_start === 'number'
      ? new Date(provider.current_start * 1000).toISOString()
      : new Date(nowMs).toISOString();
  const expiresAtIso = end.toISOString();

  const { error: reconcileError } = await service.rpc('reconcile_billing_entitlement', {
    p_user_id: userId,
    p_provider: 'razorpay',
    p_tier: resolvedIntentTier,
    p_status: 'active',
    p_provider_subscription_id: subscriptionId,
    p_revenuecat_id: null,
    p_billing_cycle: cycle,
    p_renewed_at: renewedAtIso,
    p_expires_at: expiresAtIso,
    p_event_id: paymentId
      ? `${subscriptionId}:client_verify:${paymentId}`
      : `${subscriptionId}:client_verify:${provider.status ?? 'active'}`,
    p_event_type: 'subscription.client_verified',
    p_intent_id: intent.id,
    p_intent_status: 'active',
  });

  if (reconcileError) {
    logger.log('error', 'verify_reconcile_failed', describeError(reconcileError));
    return reply(500, { error: 'Could not activate subscription.' });
  }

  try {
    const invoiceId = paymentId
      ? `inv_${paymentId}`
      : `inv_${subscriptionId}_${renewedAtIso.slice(0, 10)}`;
    const amountInr = Number(intent.expected_amount_paise) / 100;
    const planLabel =
      resolvedIntentTier === 'premium' ? 'AlphaJournal Basic' : 'AlphaJournal Pro';
    const cycleLabel = cycle === 'annual' ? 'Annual' : 'Monthly';
    await service.from('invoices').upsert(
      {
        id: invoiceId,
        invoice_ref: invoiceId,
        user_id: userId,
        amount: amountInr,
        currency: 'INR',
        status: 'paid',
        issued_at: renewedAtIso,
        pdf_url: provider.short_url ?? intent.checkout_url ?? '',
        provider: 'razorpay',
        provider_subscription_id: subscriptionId,
        provider_payment_id: paymentId || null,
        billing_cycle: cycle,
        tier: resolvedIntentTier,
        line_items: [
          {
            description: `${planLabel} (${cycleLabel} subscription, incl. 18% GST)`,
            amount: amountInr,
            quantity: 1,
          },
        ],
        updated_at: new Date(nowMs).toISOString(),
      },
      { onConflict: 'id' },
    );
  } catch (invoiceErr) {
    logger.log('warn', 'verify_invoice_record_skipped', describeError(invoiceErr));
  }

  logger.log('info', 'checkout_verified', {
    subscription_id: subscriptionId,
    tier: resolvedIntentTier,
    billing_cycle: cycle,
  });

  return reply(200, {
    verified: true,
    status: 'active',
    subscription_id: subscriptionId,
    tier: resolvedIntentTier,
    billing_cycle: cycle,
    expires_at: expiresAtIso,
  });
}

async function handleCancelSubscription(
  userId: string,
  service: ReturnType<typeof createClient>,
  razorpayHeaders: Record<string, string>,
  logger: ReturnType<typeof createEdgeRequestLogger>,
): Promise<Response> {
  const { data: subRow, error: subError } = await service
    .from('subscriptions')
    .select('tier, status, billing_provider, provider_subscription_id, billing_cycle, renewed_at, expires_at')
    .eq('user_id', userId)
    .maybeSingle();

  if (subError) {
    return reply(500, { error: 'Could not read current subscription.' });
  }
  const subId = subRow?.provider_subscription_id as string | undefined;
  if (!subRow || subRow.billing_provider !== 'razorpay' || !subId?.startsWith('sub_')) {
    return reply(404, { error: 'No active Razorpay subscription found on this account.' });
  }

  const cancelRes = await fetch(
    `https://api.razorpay.com/v1/subscriptions/${encodeURIComponent(subId)}/cancel`,
    {
      method: 'POST',
      headers: razorpayHeaders,
      body: JSON.stringify({ cancel_at_cycle_end: 1 }),
    },
  );

  // Fetch the authoritative state after cancellation request
  const providerRes = await fetch(
    `https://api.razorpay.com/v1/subscriptions/${encodeURIComponent(subId)}`,
    { headers: razorpayHeaders },
  );
  if (!cancelRes.ok && !providerRes.ok) {
    return reply(502, { error: 'Payment provider could not cancel the subscription.' });
  }

  const provider = providerRes.ok
    ? ((await providerRes.json()) as {
        current_start?: number | null;
        current_end?: number | null;
        status?: string;
      })
    : {};

  const expiresAt =
    typeof provider.current_end === 'number'
      ? new Date(provider.current_end * 1000).toISOString()
      : (subRow.expires_at as string | null) ?? new Date().toISOString();
  const renewedAt =
    typeof provider.current_start === 'number'
      ? new Date(provider.current_start * 1000).toISOString()
      : (subRow.renewed_at as string | null);
  const activeTier =
    new Date(expiresAt).getTime() > Date.now()
      ? String(subRow.tier ?? 'free')
      : 'free';

  const { error: reconcileError } = await service.rpc('reconcile_billing_entitlement', {
    p_user_id: userId,
    p_provider: 'razorpay',
    p_tier: activeTier,
    p_status: 'canceled',
    p_provider_subscription_id: subId,
    p_revenuecat_id: null,
    p_billing_cycle: (subRow.billing_cycle as string | null) ?? 'monthly',
    p_renewed_at: renewedAt,
    p_expires_at: expiresAt,
    p_event_id: `${subId}:user.cancel_at_cycle_end:${Date.now()}`,
    p_event_type: 'subscription.cancel_at_cycle_end',
    p_intent_id: null,
    p_intent_status: 'cancelled',
  });

  if (reconcileError) {
    logger.log('error', 'cancel_reconcile_failed', describeError(reconcileError));
    return reply(500, { error: 'Could not update subscription status.' });
  }

  logger.log('info', 'subscription_canceled_at_cycle_end', {
    subscription_id: subId,
    expires_at: expiresAt,
  });
  return reply(200, {
    status: 'canceled',
    subscription_id: subId,
    tier: activeTier,
    expires_at: expiresAt,
  });
}

if (typeof Deno !== 'undefined' && typeof Deno.serve === 'function') {
  Deno.serve(handleCheckoutEntry);
}
