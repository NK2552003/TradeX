import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsPreflightResponse, withCorsHeaders } from '../_shared/cors.ts';
import { createEdgeRequestLogger, describeError } from '../_shared/logger.ts';

const headers = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function reply(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), { status, headers });
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return corsPreflightResponse(request);
  const logger = createEdgeRequestLogger('create-business-checkout', request);
  try {
    return logger.finish(withCorsHeaders(
      request,
      await handleCheckoutRequest(request, logger),
    ));
  } catch (error) {
    logger.log('error', 'unhandled_exception', describeError(error));
    return logger.finish(withCorsHeaders(
      request,
      reply(500, { error: 'Checkout could not be created.' }),
    ));
  }
});

async function handleCheckoutRequest(
  request: Request,
  logger: ReturnType<typeof createEdgeRequestLogger>,
): Promise<Response> {
  if (request.method !== 'POST') return reply(405, { error: 'Method not allowed' });

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY');
  const keyId = Deno.env.get('RAZORPAY_KEY_ID');
  const keySecret = Deno.env.get('RAZORPAY_SECRET_KEY') ?? Deno.env.get('RAZORPAY_KEY_SECRET');
  const monthlyPlan = Deno.env.get('RAZORPAY_BUSINESS_MONTHLY_PLAN_ID');
  const annualPlan = Deno.env.get('RAZORPAY_BUSINESS_YEARLY_PLAN_ID');
  if (!url || !anonKey || !serviceKey || !keyId || !keySecret || !monthlyPlan || !annualPlan) {
    return reply(503, { error: 'Business checkout is not configured.' });
  }
  const authorization = request.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) return reply(401, { error: 'Sign in required.' });
  const account = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: { user }, error: authError } = await account.auth.getUser(authorization.slice(7));
  if (authError || !user?.email) return reply(401, { error: 'Signed-in account required.' });

  let cycle: string;
  try {
    const body = await request.json() as Record<string, unknown>;
    cycle = String(body.billing_cycle ?? '');
  } catch {
    return reply(400, { error: 'Invalid request.' });
  }
  if (cycle !== 'monthly' && cycle !== 'annual') {
    return reply(400, { error: 'Choose monthly or annual billing.' });
  }
  const service = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: catalogue, error: catalogueError } = await service
    .from('pricing_catalogues').select('catalogue').eq('id', 'default')
    .eq('published', true).maybeSingle();
  if (catalogueError || !catalogue) return reply(503, { error: 'Published pricing is unavailable.' });
  const plans = (catalogue.catalogue as { plans?: Array<Record<string, unknown>> }).plans;
  const business = plans?.find((plan) => plan.tier === 'enterprise');
  if (!business) return reply(503, { error: 'Business pricing is unavailable.' });
  const amount = cycle === 'annual'
    ? Number(business.annual_monthly_amount) * 12
    : Number(business.monthly_amount);
  const expectedPaise = Math.round(amount * 100);
  if (!Number.isSafeInteger(expectedPaise) || expectedPaise <= 0) {
    return reply(503, { error: 'Business pricing is invalid.' });
  }

  const planId = cycle === 'annual' ? annualPlan : monthlyPlan;
  const razorpayHeaders = {
    Authorization: `Basic ${btoa(`${keyId}:${keySecret}`)}`,
    'Content-Type': 'application/json',
  };
  const planResponse = await fetch(
    `https://api.razorpay.com/v1/plans/${encodeURIComponent(planId)}`,
    { headers: razorpayHeaders },
  );
  if (!planResponse.ok) return reply(502, { error: 'Payment plan verification failed.' });
  const plan = await planResponse.json() as {
    period?: string; interval?: number; item?: { amount?: number; currency?: string };
  };
  if (plan.period !== (cycle === 'annual' ? 'yearly' : 'monthly') ||
      plan.interval !== 1 || plan.item?.amount !== expectedPaise ||
      plan.item?.currency !== 'INR') {
    return reply(503, { error: 'Payment plan does not match published pricing.' });
  }

  const created = await fetch('https://api.razorpay.com/v1/subscriptions', {
    method: 'POST', headers: razorpayHeaders,
    body: JSON.stringify({
      plan_id: planId,
      total_count: cycle === 'annual' ? 10 : 120,
      customer_notify: true,
      notify_info: { notify_email: user.email },
      notes: { user_id: user.id, product: 'alphajournal_business' },
    }),
  });
  if (!created.ok) return reply(502, { error: 'Payment provider could not start checkout.' });
  const subscription = await created.json() as { id?: string; short_url?: string };
  if (!subscription.id || !subscription.short_url) {
    return reply(502, { error: 'Payment provider returned an incomplete checkout.' });
  }
  let checkout: URL;
  try {
    checkout = new URL(subscription.short_url);
  } catch {
    return reply(502, { error: 'Payment provider returned an invalid checkout.' });
  }
  if (checkout.protocol !== 'https:' ||
      !['rzp.io', 'razorpay.com', 'www.razorpay.com'].includes(checkout.hostname)) {
    return reply(502, { error: 'Payment provider returned an invalid checkout.' });
  }
  const { error: saveError } = await service.from('billing_checkout_intents').insert({
    user_id: user.id,
    tier: 'enterprise',
    billing_cycle: cycle,
    razorpay_plan_id: planId,
    razorpay_subscription_id: subscription.id,
    expected_amount_paise: expectedPaise,
    checkout_url: checkout.toString(),
  });
  if (saveError) {
    logger.log('error', 'checkout_intent_save_failed', describeError(saveError));
    return reply(500, { error: 'Checkout could not be saved.' });
  }
  logger.log('info', 'checkout_created', { billing_cycle: cycle });
  return reply(200, { subscription_id: subscription.id, checkout_url: checkout.toString() });
}
