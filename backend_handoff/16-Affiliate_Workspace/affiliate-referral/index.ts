// Deploy as Supabase Edge Function affiliate-referral with JWT verification disabled.
// This public telemetry endpoint never awards commission or modifies balances.
import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
const origin = Deno.env.get('APP_ORIGIN') ?? 'https://alphajournal.in';
const headers = { 'Access-Control-Allow-Origin': origin, 'Access-Control-Allow-Headers': 'authorization,x-client-info,apikey,content-type', 'Access-Control-Allow-Methods': 'POST,OPTIONS', 'Content-Type': 'application/json' };
Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response(null, { headers });
  if (request.method !== 'POST') return new Response('{}', { status: 405, headers });
  try {
    const { code, campaign, visitor } = await request.json();
    if (typeof code !== 'string' || !/^[a-zA-Z0-9_-]{3,80}$/.test(code) || typeof campaign !== 'string' || !/^[a-z0-9][a-z0-9-]{2,39}$/.test(campaign) || typeof visitor !== 'string' || !/^[a-f0-9]{48}$/.test(visitor)) return new Response('{}', { status: 400, headers });
    const client = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } });
    // Resolve code and slug separately; never interpolate an untrusted PostgREST filter.
    const byCode = await client.from('affiliate_profiles').select('id').eq('status', 'active').eq('affiliate_code', code).maybeSingle();
    if (byCode.error) throw byCode.error;
    const bySlug = byCode.data ? byCode : await client.from('affiliate_profiles').select('id').eq('status', 'active').eq('custom_slug', code).maybeSingle();
    if (bySlug.error) throw bySlug.error;
    if (!bySlug.data) return new Response('{}', { status: 404, headers });
    const result = await client.from('affiliate_campaigns').select('id').eq('affiliate_id', bySlug.data.id).eq('slug', campaign).eq('status', 'active').maybeSingle();
    if (result.error) throw result.error;
    if (!result.data) return new Response('{}', { status: 404, headers });
    const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`${result.data.id}:${visitor}:${new Date().toISOString().slice(0, 10)}`));
    const key = Array.from(new Uint8Array(digest), x => x.toString(16).padStart(2, '0')).join('');
    const { error } = await client.rpc('record_affiliate_click', { p_campaign_id: result.data.id, p_event_key: key });
    if (error) throw error;
    return new Response('{"recorded":true}', { headers });
  } catch (_) { return new Response('{"error":"Click could not be recorded"}', { status: 503, headers }); }
});
