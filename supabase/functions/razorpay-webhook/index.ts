import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

type ReconcileRpcParams = {
  p_user_id: string;
  p_provider: 'revenuecat' | 'razorpay';
  p_tier: string;
  p_status: string;
  p_provider_subscription_id?: string | null;
  p_revenuecat_id?: string | null;
  p_billing_cycle?: string | null;
  p_renewed_at?: string | null;
  p_expires_at?: string | null;
  p_event_id?: string | null;
  p_event_type?: string | null;
  p_intent_id?: string | null;
  p_intent_status?: string | null;
};

function isTransientDbError(error: { code?: string; message?: string } | null): boolean {
  if (!error) return false;
  const code = String(error.code ?? '');
  const message = String(error.message ?? '').toLowerCase();
  return (
    ['40001', '40P01', '55P03', '53300', '08006', '08000', '57014'].includes(code) ||
    message.includes('deadlock') ||
    message.includes('could not serialize') ||
    message.includes('lock timeout') ||
    message.includes('connection')
  );
}

async function callReconcileWithRetry(
  client: ReturnType<typeof createClient>,
  params: ReconcileRpcParams,
  maxAttempts = 3,
): Promise<{ data: unknown; error: { code?: string; message?: string } | null }> {
  let lastError: { code?: string; message?: string } | null = null;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const { data, error } = await client.rpc('reconcile_billing_entitlement', params);
    if (!error) {
      return { data, error: null };
    }
    lastError = error;
    if (!isTransientDbError(error) || attempt === maxAttempts) {
      break;
    }
    await new Promise((resolve) => setTimeout(resolve, 25 * attempt));
  }
  return { data: null, error: lastError };
}

// Deploy without Supabase JWT verification. Razorpay authenticates with HMAC.
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

export async function handleRazorpayWebhook(request: Request): Promise<Response> {
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });
  const secret = Deno.env.get('RAZORPAY_WEBHOOK_SECRET');
  const keyId = Deno.env.get('RAZORPAY_KEY_ID');
  const keySecret = Deno.env.get('RAZORPAY_SECRET_KEY') ?? Deno.env.get('RAZORPAY_KEY_SECRET');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY');
  if (!secret || !keyId || !keySecret || !supabaseUrl || !serviceKey) {
    return new Response('Server configuration incomplete', { status: 503 });
  }
  const signature = request.headers.get('x-razorpay-signature')?.toLowerCase() ?? '';
  if (!/^[0-9a-f]{64}$/.test(signature)) {
    return new Response('Invalid signature', { status: 401 });
  }
  const raw = await request.text();
  const hmacKey = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const digest = new Uint8Array(
    await crypto.subtle.sign('HMAC', hmacKey, new TextEncoder().encode(raw)),
  );
  if (!equalHex(hex(digest), signature)) {
    return new Response('Invalid signature', { status: 401 });
  }
  let event: {
    event?: string;
    payload?: { subscription?: { entity?: { id?: string } } };
  };
  try {
    event = JSON.parse(raw);
  } catch {
    return new Response('Invalid JSON', { status: 400 });
  }
  const subscriptionId = event.payload?.subscription?.entity?.id;
  if (!subscriptionId?.startsWith('sub_')) {
    return new Response('Ignored', { status: 200 });
  }
  const service = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: intent, error: intentError } = await service
    .from('billing_checkout_intents')
    .select('*')
    .eq('razorpay_subscription_id', subscriptionId)
    .maybeSingle();
  if (intentError) return new Response('Checkout lookup failed', { status: 500 });
  if (!intent) return new Response('Unknown checkout', { status: 404 });

  // Webhook delivery can be duplicated or out of order. Reconcile the
  // provider's current state instead of trusting an event's embedded state.
  const authorization = `Basic ${btoa(`${keyId}:${keySecret}`)}`;
  const providerResponse = await fetch(
    `https://api.razorpay.com/v1/subscriptions/${encodeURIComponent(subscriptionId)}`,
    { headers: { Authorization: authorization, Accept: 'application/json' } },
  );
  if (!providerResponse.ok) return new Response('Provider lookup failed', { status: 502 });
  const provider = (await providerResponse.json()) as {
    id?: string;
    plan_id?: string;
    status?: string;
    current_start?: number | null;
    current_end?: number | null;
  };
  if (
    !provider.plan_id ||
    provider.id !== subscriptionId ||
    provider.plan_id !== intent.razorpay_plan_id
  ) {
    return new Response('Plan mismatch', { status: 409 });
  }
  const planResponse = await fetch(
    `https://api.razorpay.com/v1/plans/${encodeURIComponent(provider.plan_id)}`,
    { headers: { Authorization: authorization, Accept: 'application/json' } },
  );
  if (!planResponse.ok) return new Response('Plan lookup failed', { status: 502 });
  const plan = (await planResponse.json()) as { item?: { amount?: number; currency?: string } };
  if (plan.item?.amount !== intent.expected_amount_paise || plan.item?.currency !== 'INR') {
    return new Response('Amount mismatch', { status: 409 });
  }
  const end =
    typeof provider.current_end === 'number' ? new Date(provider.current_end * 1000) : null;
  const paidPeriod = end != null && Number.isFinite(end.getTime()) && end.getTime() > Date.now();
  const active = provider.status === 'active' && paidPeriod;
  const canceledWithAccess = provider.status === 'cancelled' && paidPeriod;
  const businessAccess = active || canceledWithAccess;
  const now = new Date().toISOString();
  const intentStatus = active
    ? 'active'
    : canceledWithAccess
    ? 'cancelled'
    : provider.status === 'cancelled'
    ? 'cancelled'
    : provider.status === 'authenticated'
    ? 'authenticated'
    : 'expired';
  const eventId =
    request.headers.get('x-razorpay-event-id') ??
    `${subscriptionId}:${String(event.event ?? 'UNKNOWN')}:${String(provider.status ?? 'unknown')}`;

  // Atomically lock the account, update the checkout intent, record Razorpay's
  // provider entitlement state, re-evaluate cross-provider precedence (preserving
  // an active RevenueCat Pro entitlement if Razorpay Business expires), and update
  // subscriptions, profiles, and webhook receipts in a single transaction.
  const { error: reconcileError } = await callReconcileWithRetry(service, {
    p_user_id: intent.user_id,
    p_provider: 'razorpay',
    p_tier: businessAccess ? 'enterprise' : 'free',
    p_status: active ? 'active' : 'canceled',
    p_provider_subscription_id: subscriptionId,
    p_revenuecat_id: null,
    p_billing_cycle: intent.billing_cycle,
    p_renewed_at:
      typeof provider.current_start === 'number'
        ? new Date(provider.current_start * 1000).toISOString()
        : null,
    p_expires_at: businessAccess ? end!.toISOString() : now,
    p_event_id: eventId,
    p_event_type: String(event.event ?? 'UNKNOWN'),
    p_intent_id: intent.id,
    p_intent_status: intentStatus,
  });

  if (reconcileError) {
    if (
      reconcileError.code === 'P0002' ||
      String(reconcileError.message ?? '').includes('Account not found')
    ) {
      return new Response('Account not found', { status: 404 });
    }
    return new Response('Subscription reconciliation failed', {
      status: isTransientDbError(reconcileError) ? 503 : 500,
    });
  }

  return new Response('OK', { status: 200 });
}

if (typeof Deno !== 'undefined' && typeof Deno.serve === 'function') {
  Deno.serve(handleRazorpayWebhook);
}
