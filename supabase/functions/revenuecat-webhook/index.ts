import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Deploy without JWT verification; RevenueCat authenticates with the shared
// Authorization header configured in its webhook integration.
Deno.serve(async (request) => {
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405 });
  const webhookToken = Deno.env.get('REVENUECAT_WEBHOOK_TOKEN');
  const rcSecret = Deno.env.get('REVENUECAT_SECRET_API_KEY');
  const rcProject = Deno.env.get('REVENUECAT_PROJECT_ID');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY');
  if (!webhookToken || !rcSecret || !rcProject || !supabaseUrl || !serviceKey) {
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
  const rcBase = `https://api.revenuecat.com/v2/projects/${encodeURIComponent(rcProject)}`;
  const rcHeaders = { Authorization: `Bearer ${rcSecret}`, Accept: 'application/json' };
  const definitionsResponse = await fetch(`${rcBase}/entitlements?limit=100`, { headers: rcHeaders });
  if (!definitionsResponse.ok) return new Response('Entitlement lookup failed', { status: 502 });
  const definitions = await definitionsResponse.json() as {
    items?: Array<{ id?: string; lookup_key?: string }>;
  };
  const entitlementId = definitions.items?.find((item) => item.lookup_key === 'tradex_pro')?.id;
  if (!entitlementId) return new Response('Entitlement not configured', { status: 503 });
  const customerUrl = `${rcBase}/customers/${encodeURIComponent(userId)}`;
  const response = await fetch(`${customerUrl}/active_entitlements?limit=100`, { headers: rcHeaders });
  if (!response.ok) return new Response('RevenueCat lookup failed', { status: 502 });
  const customer = await response.json() as {
    items?: Array<{ entitlement_id?: string; expires_at?: number | null }>;
  };
  const entitlement = customer.items?.find((item) => item.entitlement_id === entitlementId);
  const expiry = typeof entitlement?.expires_at === 'number'
    ? new Date(entitlement.expires_at).toISOString() : null;
  if (entitlement && expiry == null) {
    return new Response('Unsupported non-expiring entitlement', { status: 409 });
  }
  const active = entitlement != null && (expiry == null || Date.parse(expiry) > Date.now());
  let cycle = 'monthly';
  let renewedAt: string | null = null;
  if (active && expiry != null) {
    const subscriptionsResponse = await fetch(`${customerUrl}/subscriptions?limit=100`, { headers: rcHeaders });
    if (!subscriptionsResponse.ok) return new Response('Subscription lookup failed', { status: 502 });
    const subscriptions = await subscriptionsResponse.json() as {
      items?: Array<{
        gives_access?: boolean;
        current_period_starts_at?: number;
        current_period_ends_at?: number;
      }>;
    };
    const current = subscriptions.items?.filter((item) => item.gives_access
      && typeof item.current_period_ends_at === 'number')
      .sort((a, b) => (b.current_period_ends_at ?? 0) - (a.current_period_ends_at ?? 0))[0];
    if (current?.current_period_starts_at) {
      renewedAt = new Date(current.current_period_starts_at).toISOString();
      const duration = (current.current_period_ends_at ?? 0) - current.current_period_starts_at;
      cycle = duration > 180 * 24 * 60 * 60 * 1000 ? 'annual' : 'monthly';
    }
  }
  const client = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: profile, error: profileError } = await client.from('profiles')
    .select('id').eq('id', userId).maybeSingle();
  if (profileError) return new Response('Profile lookup failed', { status: 500 });
  if (!profile) return new Response('Account not found', { status: 404 });
  const now = new Date().toISOString();
  const { data: existing, error: existingError } = await client.from('subscriptions')
    .select('tier, status, expires_at, billing_provider')
    .eq('user_id', userId).maybeSingle();
  if (existingError) return new Response('Subscription lookup failed', { status: 500 });
  // Store events cannot replace a currently paid Business subscription.
  if (existing?.billing_provider === 'razorpay' && existing.tier === 'enterprise'
      && ['active', 'canceled'].includes(existing.status)
      && existing.expires_at && Date.parse(existing.expires_at) > Date.now()) {
    return new Response('OK', { status: 200 });
  }
  const { error: subscriptionError } = await client.from('subscriptions').upsert({
    user_id: userId,
    tier: active ? 'premium' : 'free',
    status: active ? 'active' : 'canceled',
    revenuecat_id: userId,
    billing_provider: 'revenuecat',
    provider_subscription_id: null,
    billing_cycle: active ? cycle : null,
    renewed_at: active ? renewedAt : null,
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
