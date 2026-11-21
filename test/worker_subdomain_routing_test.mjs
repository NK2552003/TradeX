import test from 'node:test';
import assert from 'node:assert/strict';
import worker, {
  buildDynamicSitemapXml,
  canonicalSubdomainHost,
  isAlphajournalHost,
  logWorkerEvent,
  runtimeCacheControl,
  resolvePageSeo,
  resolvePublicStorageUrl,
  resolveRedirectUrl,
} from '../worker/index.js';

test('Flutter runtime files always revalidate across deployments', async () => {
  assert.equal(
    runtimeCacheControl('/main.dart.js'),
    'no-cache, max-age=0, must-revalidate',
  );
  assert.equal(
    runtimeCacheControl('/main.dart.js_12.part.js'),
    'no-cache, max-age=0, must-revalidate',
  );
  assert.equal(
    runtimeCacheControl('/assets/fonts/MaterialIcons-Regular.otf'),
    'no-cache, max-age=0, must-revalidate',
  );
  assert.equal(runtimeCacheControl('/assets/logo.svg'), null);

  for (const pathname of [
    '/main.dart.js',
    '/main.dart.js_1.part.js',
    '/flutter_bootstrap.js',
    '/flutter_service_worker.js',
    '/assets/AssetManifest.bin.json',
    '/assets/FontManifest.json',
    '/assets/fonts/MaterialIcons-Regular.otf',
    '/assets/assets/config/client.env',
    '/nav_transition.js',
  ]) {
    const response = await worker.fetch(
      new Request(`https://app.alphajournal.in${pathname}`),
      {
        ASSETS: {
          fetch: async () =>
            new Response('runtime', {
              headers: {
                'content-type': 'application/javascript',
                'Cache-Control': 'public, max-age=604800',
              },
            }),
        },
      },
    );
    assert.match(response.headers.get('Cache-Control'), /must-revalidate/);
    assert.doesNotMatch(response.headers.get('Cache-Control'), /604800/);
  }
});

test('recognizes apex and subdomains', () => {
  assert.equal(isAlphajournalHost('alphajournal.in'), true);
  assert.equal(isAlphajournalHost('app.alphajournal.in'), true);
  assert.equal(isAlphajournalHost('community.alphajournal.in'), true);
  assert.equal(isAlphajournalHost('affiliate.alphajournal.in'), true);
  assert.equal(isAlphajournalHost('admin.alphajournal.in'), true);
  assert.equal(isAlphajournalHost('localhost'), false);
  assert.equal(isAlphajournalHost('alphajournal.pages.dev'), false);
});

test('upgrades http and canonicalizes www to apex', () => {
  assert.equal(
    resolveRedirectUrl('http://alphajournal.in/auth/login'),
    'https://alphajournal.in/auth/login',
  );
  assert.equal(
    resolveRedirectUrl('https://www.alphajournal.in/r/CODE123?utm_campaign=fall'),
    'https://alphajournal.in/r/CODE123?utm_campaign=fall',
  );
});

test('canonicalizes community, affiliate, admin, and app routes', () => {
  assert.equal(
    resolveRedirectUrl('https://alphajournal.in/community_feed'),
    'https://community.alphajournal.in/community_feed',
  );
  assert.equal(
    resolveRedirectUrl(
      'https://app.alphajournal.in/community/post/12345678-1234-1234-1234-1234567890ab?public=true',
    ),
    'https://community.alphajournal.in/community/post/12345678-1234-1234-1234-1234567890ab?public=true',
  );
  assert.equal(
    resolveRedirectUrl('https://alphajournal.in/@nitish'),
    'https://community.alphajournal.in/@nitish',
  );
  assert.equal(
    resolveRedirectUrl('https://community.alphajournal.in/community_explore'),
    null,
  );
  assert.equal(
    resolveRedirectUrl('https://alphajournal.in/affiliate_application'),
    'https://affiliate.alphajournal.in/affiliate_application',
  );
  assert.equal(
    resolveRedirectUrl('https://app.alphajournal.in/referrals'),
    'https://affiliate.alphajournal.in/referrals',
  );
  assert.equal(
    resolveRedirectUrl('https://alphajournal.in/admin_console'),
    'https://admin.alphajournal.in/admin_console',
  );
  assert.equal(
    resolveRedirectUrl('https://affiliate.alphajournal.in/affiliate_reviews'),
    'https://admin.alphajournal.in/affiliate_reviews',
  );
  assert.equal(
    resolveRedirectUrl('https://alphajournal.in/workspace'),
    'https://app.alphajournal.in/workspace',
  );
  assert.equal(
    resolveRedirectUrl('https://community.alphajournal.in/messages'),
    'https://app.alphajournal.in/messages',
  );
});

test('preserves static assets, auth callbacks, referral links, root, and preview', () => {
  for (const url of [
    'https://alphajournal.in/',
    'https://alphajournal.in/auth/login?next=/workspace',
    'https://alphajournal.in/r/TRADER50',
    'https://alphajournal.in/join/TRADER50',
    'https://alphajournal.in/help/privacy',
    'https://app.alphajournal.in/flutter_bootstrap.js',
    'https://community.alphajournal.in/assets/AssetManifest.json',
    'https://community.alphajournal.in/icons/Icon-512.png',
    'https://alphajournal.in/community_feed?preview=customer',
    'http://localhost:8080/workspace',
  ]) {
    assert.equal(resolveRedirectUrl(url), null, url);
  }
  assert.equal(canonicalSubdomainHost(new URL('https://alphajournal.in/journal')), 'app.alphajournal.in');
});

test('resolves per-subdomain canonical, robots, and social metadata', () => {
  const communitySeo = resolvePageSeo(
    new URL('https://community.alphajournal.in/community_feed'),
  );
  assert.equal(communitySeo.canonical, 'https://community.alphajournal.in/community_feed');
  assert.equal(communitySeo.noindex, false);

  const marketSeo = resolvePageSeo(new URL('https://app.alphajournal.in/market'));
  assert.equal(marketSeo.canonical, 'https://app.alphajournal.in/market');
  assert.equal(marketSeo.noindex, false);

  const affiliateSeo = resolvePageSeo(new URL('https://affiliate.alphajournal.in/'));
  assert.equal(affiliateSeo.canonical, 'https://affiliate.alphajournal.in/affiliate_application');
  assert.equal(affiliateSeo.noindex, false);

  const adminSeo = resolvePageSeo(new URL('https://admin.alphajournal.in/overview'));
  assert.equal(adminSeo.noindex, true);
  assert.equal(adminSeo.robots, 'noindex, nofollow');

  const messagesSeo = resolvePageSeo(new URL('https://app.alphajournal.in/messages'));
  assert.equal(messagesSeo.noindex, true);

  const marketSymbolSeo = resolvePageSeo(
    new URL('https://app.alphajournal.in/market/RELIANCE'),
  );
  assert.equal(marketSymbolSeo.canonical, 'https://app.alphajournal.in/market/RELIANCE');
  assert.match(marketSymbolSeo.title, /^RELIANCE Live Quote/);
  assert.equal(marketSymbolSeo.noindex, false);

  const publicJournalSeo = resolvePageSeo(
    new URL('https://app.alphajournal.in/journal/j-42?public=true'),
  );
  assert.equal(publicJournalSeo.canonical, 'https://app.alphajournal.in/journal/j-42?public=true');
  assert.equal(publicJournalSeo.ogType, 'article');
  assert.equal(publicJournalSeo.noindex, false);

  const legacyPostSeo = resolvePageSeo(
    new URL('https://community.alphajournal.in/p/12345678-1234-1234-1234-1234567890ab'),
    {
      post: {
        body: 'Nifty breakout call.',
        profiles: { display_name: 'Nitish', handle: 'nitish' },
      },
    },
  );
  assert.equal(
    legacyPostSeo.canonical,
    'https://community.alphajournal.in/community/post/12345678-1234-1234-1234-1234567890ab?public=true',
  );

  const profileSeo = resolvePageSeo(
    new URL('https://community.alphajournal.in/@nitish'),
    {
      profile: {
        display_name: 'Nitish',
        handle: '@nitish',
        bio: 'Systematic index trader',
        avatar_url: 'https://cdn.alphajournal.in/a.png',
      },
    },
  );
  assert.equal(profileSeo.ogType, 'profile');
  assert.equal(profileSeo.canonical, 'https://community.alphajournal.in/@nitish');
  assert.match(profileSeo.title, /Nitish \(@nitish\)/);
  assert.equal(profileSeo.image, 'https://cdn.alphajournal.in/a.png');
});

test('serves host-aware robots.txt, noindex header on admin, and dynamic sitemap.xml', async () => {
  const adminRobots = await worker.fetch(
    new Request('https://admin.alphajournal.in/robots.txt'),
    { ASSETS: { fetch: async () => new Response('unused') } },
  );
  assert.equal(adminRobots.status, 200);
  assert.match(await adminRobots.text(), /Disallow: \//);

  const adminHtml = await worker.fetch(
    new Request('https://admin.alphajournal.in/overview'),
    {
      ASSETS: {
        fetch: async () =>
          new Response('<html></html>', {
            headers: { 'content-type': 'text/html' },
          }),
      },
    },
  );
  assert.equal(adminHtml.headers.get('X-Robots-Tag'), 'noindex, nofollow');

  const adminSitemap = await worker.fetch(
    new Request('https://admin.alphajournal.in/sitemap.xml'),
    { ASSETS: { fetch: async () => new Response('unused') } },
  );
  assert.equal(adminSitemap.status, 404);

  const origFetch = globalThis.fetch;
  globalThis.fetch = async (url) => {
    if (String(url).includes('/community_posts')) {
      return new Response(
        JSON.stringify([
          {
            id: '12345678-1234-1234-1234-1234567890ab',
            created_at: '2026-11-15T10:00:00Z',
          },
        ]),
        { status: 200, headers: { 'content-type': 'application/json' } },
      );
    }
    return new Response(
      JSON.stringify([{ handle: '@alpha_trader', created_at: '2026-11-10T10:00:00Z' }]),
      { status: 200, headers: { 'content-type': 'application/json' } },
    );
  };
  try {
    const xml = await buildDynamicSitemapXml({
      SUPABASE_URL: 'https://example.supabase.co',
      SUPABASE_ANON_KEY: 'anon-key',
    });
    assert.match(xml, /<loc>https:\/\/alphajournal\.in\/<\/loc>/);
    assert.match(xml, /<loc>https:\/\/community\.alphajournal\.in\/community_feed<\/loc>/);
    assert.match(
      xml,
      /<loc>https:\/\/community\.alphajournal\.in\/community\/post\/12345678-1234-1234-1234-1234567890ab\?public=true<\/loc>/,
    );
    assert.match(xml, /<loc>https:\/\/community\.alphajournal\.in\/@alpha_trader<\/loc>/);
  } finally {
    globalThis.fetch = origFetch;
  }
});

test('normalizes public community and avatar URLs to Smart CDN Cached Egress paths', () => {
  const env = { SUPABASE_URL: 'https://example.supabase.co' };
  assert.equal(
    resolvePublicStorageUrl(env, 'community-attachments', 'u1/p1/hash.webp'),
    'https://example.supabase.co/storage/v1/object/public/community-attachments/u1/p1/hash.webp',
  );
  assert.equal(
    resolvePublicStorageUrl(
      env,
      'avatars',
      'https://example.supabase.co/storage/v1/object/sign/avatars/u1_42.webp?token=jwt',
    ),
    'https://example.supabase.co/storage/v1/object/public/avatars/u1_42.webp',
  );
  assert.equal(
    resolvePublicStorageUrl(env, 'avatars', 'https://cdn.example.com/avatar.png'),
    'https://cdn.example.com/avatar.png',
  );
});

test('emits single-line structured JSON logs from Worker without leaking PII', () => {
  const logs = [];
  const errors = [];
  const origLog = console.log;
  const origError = console.error;
  console.log = (msg) => logs.push(msg);
  console.error = (msg) => errors.push(msg);
  try {
    logWorkerEvent('info', 'worker_seo_served', {
      host: 'community.alphajournal.in',
      path: '/@alpha_trader',
      status: 200,
    });
    logWorkerEvent('error', 'worker_upstream_error', {
      host: 'community.alphajournal.in',
      status: 502,
    });
  } finally {
    console.log = origLog;
    console.error = origError;
  }

  assert.equal(logs.length, 1);
  assert.equal(errors.length, 1);
  const infoPayload = JSON.parse(logs[0]);
  assert.equal(infoPayload.source, 'cloudflare_worker');
  assert.equal(infoPayload.level, 'info');
  assert.equal(infoPayload.event, 'worker_seo_served');
  assert.equal(infoPayload.host, 'community.alphajournal.in');
  const errPayload = JSON.parse(errors[0]);
  assert.equal(errPayload.level, 'error');
  assert.equal(errPayload.status, 502);
});
