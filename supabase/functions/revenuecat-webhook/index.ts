import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createEdgeRequestLogger, describeError } from '../_shared/logger.ts';

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

// Deploy without JWT verification; RevenueCat authenticates with the shared
// Authorization header configured in its webhook integration.
export async function handleRevenueCatWebhook(request: Request): Promise<Response> {
  const logger = createEdgeRequestLogger('revenuecat-webhook', request);
  try {
    return logger.finish(await executeRevenueCatWebhook(request, logger));
  } catch (error) {
    logger.log('error', 'unhandled_exception', describeError(error));
    return logger.finish(new Response('Webhook processing failed', { status: 500 }));
  }
}

async function executeRevenueCatWebhook(
  request: Request,
  logger: ReturnType<typeof createEdgeRequestLogger>,
): Promise<Response> {
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
  if (
    typeof userId !== 'string' ||
    !/^[0-9a-f]{8}-[0-9a-f-]{27,36}$/i.test(userId) ||
    typeof eventId !== 'string' ||
    eventId.trim().length === 0
  ) {
    return new Response('Invalid event identity', { status: 400 });
  }

  // Always reconcile against RevenueCat's current customer state. Event order
  // can differ from purchase order, and a cancellation can retain access until
  // expiry. The webhook payload alone must not grant a paid tier.
  const rcBase = `https://api.revenuecat.com/v2/projects/${encodeURIComponent(rcProject)}`;
  const rcHeaders = { Authorization: `Bearer ${rcSecret}`, Accept: 'application/json' };
  const definitionsResponse = await fetch(`${rcBase}/entitlements?limit=100`, { headers: rcHeaders });
  if (!definitionsResponse.ok) return new Response('Entitlement lookup failed', { status: 502 });
  const definitions = (await definitionsResponse.json()) as {
    items?: Array<{ id?: string; lookup_key?: string }>;
  };
  const entitlementId =
    definitions.items?.find((item) => item.lookup_key === 'alphajournal_pro')?.id ??
    definitions.items?.find((item) => item.lookup_key === 'tradex_pro')?.id;
  if (!entitlementId) return new Response('Entitlement not configured', { status: 503 });
  const customerUrl = `${rcBase}/customers/${encodeURIComponent(userId)}`;
  const response = await fetch(`${customerUrl}/active_entitlements?limit=100`, { headers: rcHeaders });
  if (!response.ok) return new Response('RevenueCat lookup failed', { status: 502 });
  const customer = (await response.json()) as {
    items?: Array<{ entitlement_id?: string; expires_at?: number | null }>;
  };
  const entitlement = customer.items?.find((item) => item.entitlement_id === entitlementId);
  const expiry =
    typeof entitlement?.expires_at === 'number'
      ? new Date(entitlement.expires_at).toISOString()
      : null;
  if (entitlement && expiry == null) {
    return new Response('Unsupported non-expiring entitlement', { status: 409 });
  }
  const active = entitlement != null && (expiry == null || Date.parse(expiry) > Date.now());
  let cycle = 'monthly';
  let renewedAt: string | null = null;
  if (active && expiry != null) {
    const subscriptionsResponse = await fetch(`${customerUrl}/subscriptions?limit=100`, {
      headers: rcHeaders,
    });
    if (!subscriptionsResponse.ok) return new Response('Subscription lookup failed', { status: 502 });
    const subscriptions = (await subscriptionsResponse.json()) as {
      items?: Array<{
        gives_access?: boolean;
        current_period_starts_at?: number;
        current_period_ends_at?: number;
      }>;
    };
    const current = subscriptions.items
      ?.filter((item) => item.gives_access && typeof item.current_period_ends_at === 'number')
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
  const now = new Date().toISOString();

  // Atomically lock the account, record RevenueCat's provider entitlement state,
  // re-evaluate cross-provider precedence (Business > Pro > Free), and update
  // subscriptions, profiles, and webhook receipts in a single database transaction.
  const { error: reconcileError } = await callReconcileWithRetry(client, {
    p_user_id: userId,
    p_provider: 'revenuecat',
    p_tier: active ? 'premium' : 'free',
    p_status: active ? 'active' : 'canceled',
    p_provider_subscription_id: null,
    p_revenuecat_id: userId,
    p_billing_cycle: active ? cycle : null,
    p_renewed_at: active ? renewedAt : null,
    p_expires_at: active ? expiry : now,
    p_event_id: eventId,
    p_event_type: String(event?.type ?? 'UNKNOWN'),
    p_intent_id: null,
    p_intent_status: null,
  });

  if (reconcileError) {
    logger.log('error', 'revenuecat_reconcile_failed', {
      event_id: eventId,
      event_type: String(event?.type ?? 'UNKNOWN'),
      ...describeError(reconcileError),
    });
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

  logger.log('info', 'revenuecat_reconcile_succeeded', {
    event_id: eventId,
    event_type: String(event?.type ?? 'UNKNOWN'),
    active,
    cycle: active ? cycle : null,
  });
  return new Response('OK', { status: 200 });
}

if (typeof Deno !== 'undefined' && typeof Deno.serve === 'function') {
  Deno.serve(handleRevenueCatWebhook);
}
