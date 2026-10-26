import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Deploy without JWT verification; RevenueCat authenticates with the shared
// Authorization header configured in its webhook integration.
Deno.serve(async (request) => {
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });
  const webhookToken = Deno.env.get('REVENUECAT_WEBHOOK_TOKEN');
  const rcSecret = Deno.env.get('REVENUECAT_SECRET_API_KEY');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!webhookToken || !rcSecret || !supabaseUrl || !serviceKey) {
    return new Response('Server configuration incomplete', { status: 503 });
  }
  if (request.headers.get('authorization') !== `Bearer ${webhookToken}`) {
    return new Response('Unauthorized', { status: 401 });
  }

  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch {
    return new Response('Invalid JSON', { status: 400 });
  }
  const event = payload.event as Record<string, unknown> | undefined;
  const userId = event?.app_user_id;
  const eventId = event?.id;
  if (typeof userId !== 'string' || !/^[0-9a-f]{8}-[0-9a-f-]{27,36}$/i.test(userId)
      || typeof eventId !== 'string') {
    return new Response('Invalid event identity', { status: 400 });
  }

  // Always reconcile against RevenueCat's current customer state. Event order
  // can differ from purchase order, and a cancellation can retain access until
  // expiry. The webhook payload alone must not grant a paid tier.
  const response = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`,
    { headers: { Authorization: `Bearer ${rcSecret}`, Accept: 'application/json' } },
  );
  if (!response.ok) return new Response('RevenueCat lookup failed', { status: 502 });
  const customer = await response.json() as {
    subscriber?: { entitlements?: Record<string, {
      expires_date?: string | null;
      purchase_date?: string | null;
      product_identifier?: string | null;
    }> };
  };
  const entitlement = customer.subscriber?.entitlements?.tradex_pro;
  const expiry = entitlement?.expires_date ?? null;
  const active = entitlement != null && (expiry == null || Date.parse(expiry) > Date.now());
  const product = entitlement?.product_identifier?.toLowerCase() ?? '';
  const cycle = product.includes('lifetime') ? 'lifetime'
    : product.includes('year') ? 'annual' : 'monthly';
  const client = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: profile, error: profileError } = await client.from('profiles')
    .select('id').eq('id', userId).maybeSingle();
  if (profileError) return new Response('Profile lookup failed', { status: 500 });
  if (!profile) return new Response('Account not found', { status: 404 });
  const now = new Date().toISOString();
  const { error: subscriptionError } = await client.from('subscriptions').upsert({
    user_id: userId,
    tier: active ? 'premium' : 'free',
    status: active ? 'active' : 'canceled',
    revenuecat_id: userId,
    billing_cycle: active ? cycle : null,
    renewed_at: active ? entitlement?.purchase_date ?? now : null,
    expires_at: active ? expiry : now,
    updated_at: now,
  }, { onConflict: 'user_id' });
  if (subscriptionError) return new Response('Subscription update failed', { status: 500 });
  const { error: tierError } = await client.from('profiles')
    .update({ subscription_tier: active ? 'premium' : 'free' }).eq('id', userId);
  if (tierError) return new Response('Profile tier update failed', { status: 500 });
  await client.from('revenuecat_webhook_events').upsert({
    event_id: eventId,
    event_type: String(event?.type ?? 'UNKNOWN'),
    processed_at: now,
  }, { onConflict: 'event_id' });
  return new Response('OK', { status: 200 });
});
