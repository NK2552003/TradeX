import { readFileSync } from 'node:fs';

const envContent = readFileSync('.env', 'utf8');
const env = {};
for (const line of envContent.split('\n')) {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#') && trimmed.includes('=')) {
    const idx = trimmed.indexOf('=');
    env[trimmed.substring(0, idx).trim()] = trimmed.substring(idx + 1).trim();
  }
}

const supabaseUrl = env['NEXT_PUBLIC_SUPABASE_URL'] || env['SUPABASE_URL'];
const supabaseAnonKey = env['NEXT_PUBLIC_SUPABASE_ANON_KEY'] || env['SUPABASE_ANON_KEY'];

const headers = {
  'apikey': supabaseAnonKey,
  'Authorization': `Bearer ${supabaseAnonKey}`,
  'Content-Type': 'application/json'
};

async function inspect() {
  // Sign in as admin
  const authRes = await fetch(`${supabaseUrl}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { 'apikey': supabaseAnonKey, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'admin@tradex.ai', password: 'Admin@TradeX2026!' })
  });
  const authData = await authRes.json();
  const token = authData.access_token;
  const authHeaders = {
    'apikey': supabaseAnonKey,
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  };

  console.log('--- PROFILES ---');
  const profRes = await fetch(`${supabaseUrl}/rest/v1/profiles?select=id,handle,display_name,email,role,subscription_tier,created_at&limit=10`, { headers: authHeaders });
  const profiles = await profRes.json();
  console.log(`Found ${profiles.length} profiles:`, profiles);

  console.log('\n--- COMMUNITY POSTS ---');
  const postRes = await fetch(`${supabaseUrl}/rest/v1/community_posts?select=id,title,author_id,created_at&limit=10`, { headers: authHeaders });
  const posts = await postRes.json();
  console.log(`Found ${posts.length} posts:`, posts);

  console.log('\n--- TRADER NOTES ---');
  const noteRes = await fetch(`${supabaseUrl}/rest/v1/trader_notes?select=id,title,user_id,created_at&limit=10`, { headers: authHeaders });
  const notes = await noteRes.json();
  console.log(`Found ${notes.length} notes:`, notes);

  console.log('\n--- JOURNAL ENTRIES ---');
  const jRes = await fetch(`${supabaseUrl}/rest/v1/journal_entries?select=id,symbol,user_id,created_at&limit=10`, { headers: authHeaders });
  const journals = await jRes.json();
  console.log(`Found ${journals.length} journal entries:`, journals);

  console.log('\n--- STRATEGIES ---');
  const sRes = await fetch(`${supabaseUrl}/rest/v1/strategies?select=id,name,user_id,created_at&limit=10`, { headers: authHeaders });
  const strategies = await sRes.json();
  console.log(`Found ${strategies.length} strategies:`, strategies);

  console.log('\n--- AFFILIATE PROFILES ---');
  const affPRes = await fetch(`${supabaseUrl}/rest/v1/affiliate_profiles?select=*&limit=10`, { headers: authHeaders });
  const affProfiles = await affPRes.json();
  console.log(`Found ${affProfiles.length} affiliate profiles:`, affProfiles);

  console.log('\n--- AFFILIATE APPLICATIONS ---');
  const affAppRes = await fetch(`${supabaseUrl}/rest/v1/affiliate_applications?select=*&limit=10`, { headers: authHeaders });
  const affApps = await affAppRes.json();
  console.log(`Found ${affApps.length} affiliate applications:`, affApps);

  console.log('\n--- AFFILIATE REFERRALS ---');
  const affRefRes = await fetch(`${supabaseUrl}/rest/v1/affiliate_referrals?select=*&limit=10`, { headers: authHeaders });
  const affRefs = await affRefRes.json();
  console.log(`Found ${affRefs.length} affiliate referrals:`, affRefs);

  console.log('\n--- AFFILIATE PAYOUTS ---');
  const affPayRes = await fetch(`${supabaseUrl}/rest/v1/affiliate_payouts?select=*&limit=10`, { headers: authHeaders });
  const affPays = await affPayRes.json();
  console.log(`Found ${affPays.length} affiliate payouts:`, affPays);
}

inspect();
