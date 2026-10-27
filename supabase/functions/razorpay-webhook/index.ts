import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

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

Deno.serve(async (request) => {
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
    'raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const digest = new Uint8Array(await crypto.subtle.sign('HMAC', hmacKey, new TextEncoder().encode(raw)));
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
    .from('billing_checkout_intents').select('*')
    .eq('razorpay_subscription_id', subscriptionId).maybeSingle();
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
  const provider = await providerResponse.json() as {
    id?: string; plan_id?: string; status?: string;
    current_start?: number | null; current_end?: number | null;
  };
  if (!provider.plan_id || provider.id !== subscriptionId || provider.plan_id !== intent.razorpay_plan_id) {
    return new Response('Plan mismatch', { status: 409 });
  }
  const planResponse = await fetch(
    `https://api.razorpay.com/v1/plans/${encodeURIComponent(provider.plan_id)}`,
    { headers: { Authorization: authorization, Accept: 'application/json' } },
  );
  if (!planResponse.ok) return new Response('Plan lookup failed', { status: 502 });
  const plan = await planResponse.json() as { item?: { amount?: number; currency?: string } };
  if (plan.item?.amount !== intent.expected_amount_paise || plan.item?.currency !== 'INR') {
    return new Response('Amount mismatch', { status: 409 });
  }
  const end = typeof provider.current_end === 'number'
    ? new Date(provider.current_end * 1000) : null;
  const paidPeriod = end != null && Number.isFinite(end.getTime()) && end.getTime() > Date.now();
  const active = provider.status === 'active' && paidPeriod;
  const canceledWithAccess = provider.status === 'cancelled' && paidPeriod;
  const businessAccess = active || canceledWithAccess;
  const now = new Date().toISOString();
  const { data: current, error: currentError } = await service
    .from('subscriptions').select('billing_provider, provider_subscription_id')
    .eq('user_id', intent.user_id).maybeSingle();
  if (currentError) return new Response('Subscription lookup failed', { status: 500 });
  // An old Razorpay checkout cannot downgrade a newer subscription, including
  // one bought through an app store.
  if (!businessAccess && current?.provider_subscription_id !== subscriptionId) {
    await service.from('billing_checkout_intents').update({
      status: provider.status === 'cancelled' ? 'cancelled'
        : provider.status === 'authenticated' ? 'authenticated' : 'expired',
      updated_at: now,
    }).eq('id', intent.id);
    return new Response('OK', { status: 200 });
  }
  const { error: subscriptionError } = await service.from('subscriptions').upsert({
    user_id: intent.user_id,
    tier: businessAccess ? 'enterprise' : 'free',
    status: active ? 'active' : 'canceled',
    billing_provider: 'razorpay',
    provider_subscription_id: subscriptionId,
    revenuecat_id: null,
    billing_cycle: intent.billing_cycle,
    renewed_at: typeof provider.current_start === 'number'
      ? new Date(provider.current_start * 1000).toISOString() : null,
    expires_at: businessAccess ? end!.toISOString() : now,
    updated_at: now,
  }, { onConflict: 'user_id' });
  if (subscriptionError) return new Response('Subscription update failed', { status: 500 });
  const { error: profileError } = await service.from('profiles').update({
    subscription_tier: businessAccess ? 'enterprise' : 'free',
  }).eq('id', intent.user_id);
  if (profileError) return new Response('Profile update failed', { status: 500 });
  const { error: intentUpdateError } = await service.from('billing_checkout_intents').update({
    status: active ? 'active' : canceledWithAccess ? 'cancelled'
      : provider.status === 'authenticated' ? 'authenticated' : 'expired',
    updated_at: now,
  }).eq('id', intent.id);
  if (intentUpdateError) return new Response('Checkout update failed', { status: 500 });
  return new Response('OK', { status: 200 });
});
