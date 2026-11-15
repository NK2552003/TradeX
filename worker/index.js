// Cloudflare Worker: serves the Flutter web app, enforces canonical
// subdomain routing across alphajournal.in / app. / community. / affiliate. /
// admin., and injects per-post Open Graph / Twitter card metadata for shared
// community-post links.
//
// Required vars (wrangler secrets / vars): SUPABASE_URL, SUPABASE_ANON_KEY.
// Only public, approved posts are exposed (enforced by Supabase RLS for anon).

const ROOT_DOMAIN = 'alphajournal.in';
const POST_PATH = /^\/community\/post\/([0-9a-fA-F-]{36})\/?$/;
const STATIC_EXT = /\.[a-zA-Z0-9]{1,8}$/;
const HANDLE_PATH = /^\/@[a-zA-Z0-9_][a-zA-Z0-9_.-]*\/?$/;

const ASSET_PREFIXES = ['/assets/', '/canvaskit/', '/icons/', '/.well-known/'];
const NEUTRAL_PREFIXES = ['/auth/', '/r/', '/join/', '/help'];

const COMMUNITY_PREFIXES = ['/community', '/p/', '/post/', '/posts/'];
const AFFILIATE_SEGMENTS = new Set([
  'affiliate_application',
  'referrals',
  'marketing',
  'payouts',
  'settings_affiliate',
]);
const ADMIN_SEGMENTS = new Set([
  'admin_console',
  'affiliate_reviews',
  'settings_platform',
]);
const APP_SEGMENTS = new Set([
  'workspace',
  'journal',
  'strategies',
  'strategy',
  'notes',
  'note',
  'calculators',
  'market',
  'messages',
  'message',
  'thread',
  'ai_copilot',
  'ai',
  'copilot',
  'notifications',
  'search',
  'settings_billing',
  'settings_affiliate_perks',
]);

export function isAlphajournalHost(hostname) {
  const host = String(hostname || '').toLowerCase();
  return host === ROOT_DOMAIN || host.endsWith(`.${ROOT_DOMAIN}`);
}

export function canonicalSubdomainHost(url) {
  const pathname = url.pathname || '/';
  const lower = pathname.toLowerCase();
  if (lower === '/' || STATIC_EXT.test(lower)) return null;
  if (ASSET_PREFIXES.some((prefix) => lower.startsWith(prefix))) return null;
  if (
    lower === '/help' ||
    NEUTRAL_PREFIXES.some((prefix) => lower.startsWith(prefix))
  ) {
    return null;
  }

  const firstSegment = lower.split('/').filter(Boolean)[0] || '';

  if (
    HANDLE_PATH.test(pathname) ||
    firstSegment === 'community' ||
    firstSegment.startsWith('community_') ||
    COMMUNITY_PREFIXES.some((prefix) => lower === prefix || lower.startsWith(prefix))
  ) {
    return `community.${ROOT_DOMAIN}`;
  }

  if (
    ADMIN_SEGMENTS.has(firstSegment) ||
    firstSegment.startsWith('admin_') ||
    firstSegment.startsWith('org_')
  ) {
    return `admin.${ROOT_DOMAIN}`;
  }

  if (
    AFFILIATE_SEGMENTS.has(firstSegment) ||
    (firstSegment.startsWith('affiliate_') && firstSegment !== 'affiliate_reviews')
  ) {
    return `affiliate.${ROOT_DOMAIN}`;
  }

  if (APP_SEGMENTS.has(firstSegment) || firstSegment.startsWith('market_')) {
    return `app.${ROOT_DOMAIN}`;
  }

  return null;
}

export function resolveRedirectUrl(requestUrl, method = 'GET') {
  const url = new URL(requestUrl);
  const host = url.hostname.toLowerCase();
  if (!isAlphajournalHost(host)) return null;

  const upperMethod = String(method || 'GET').toUpperCase();
  const canSubdomainRedirect =
    (upperMethod === 'GET' || upperMethod === 'HEAD') &&
    !url.searchParams.has('preview');
  const targetHost = canSubdomainRedirect ? canonicalSubdomainHost(url) : null;

  // Clipboard, cookies, and Web Share require HTTPS. Combine protocol upgrade
  // and canonical subdomain resolution into a single 308 hop when possible.
  if (url.protocol === 'http:') {
    url.protocol = 'https:';
    if (targetHost) {
      url.hostname = targetHost;
    } else if (host === `www.${ROOT_DOMAIN}`) {
      url.hostname = ROOT_DOMAIN;
    }
    return url.toString();
  }

  if (targetHost && targetHost !== host) {
    url.hostname = targetHost;
    return url.toString();
  }

  if (host === `www.${ROOT_DOMAIN}`) {
    url.hostname = ROOT_DOMAIN;
    return url.toString();
  }

  return null;
}

function excerpt(text, max) {
  const clean = String(text || '').replace(/\s+/g, ' ').trim();
  return clean.length <= max ? clean : clean.slice(0, max - 1).trimEnd() + '…';
}

async function loadPost(env, id) {
  if (!env.SUPABASE_URL || !env.SUPABASE_ANON_KEY) return null;
  const select =
    'body,created_at,profiles!community_posts_author_id_fkey(display_name,handle),' +
    'community_post_attachments(kind,url)';
  const url = `${env.SUPABASE_URL}/rest/v1/community_posts?id=eq.${id}&select=${encodeURIComponent(select)}&limit=1`;
  try {
    const res = await fetch(url, {
      headers: { apikey: env.SUPABASE_ANON_KEY, Authorization: `Bearer ${env.SUPABASE_ANON_KEY}` },
      cf: { cacheTtl: 300, cacheEverything: true },
    });
    if (!res.ok) return null;
    const rows = await res.json();
    return rows[0] || null;
  } catch (_) {
    return null;
  }
}

export default {
  async fetch(request, env) {
    const redirectTo = resolveRedirectUrl(request.url, request.method);
    if (redirectTo) {
      return Response.redirect(redirectTo, 308);
    }

    const url = new URL(request.url);
    const match = POST_PATH.exec(url.pathname);
    const page = await env.ASSETS.fetch(request);
    if (!match || request.method !== 'GET') {
      const ct = page.headers.get('content-type') || '';
      if (ct.includes('text/html') && !page.headers.has('Cache-Control')) {
        const headers = new Headers(page.headers);
        headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');
        return new Response(page.body, { status: page.status, statusText: page.statusText, headers });
      }
      return page;
    }

    const post = await loadPost(env, match[1]);
    if (!post) return page;

    const name = post.profiles?.display_name || post.profiles?.handle || 'A trader';
    const handle = post.profiles?.handle ? ` (@${String(post.profiles.handle).replace(/^@/, '')})` : '';
    const title = `${name}${handle} on alphajournal`;
    const description = excerpt(post.body, 200);
    const img = (post.community_post_attachments || []).find(
      (a) => a.kind === 'image' && /^https?:\/\//.test(a.url || ''),
    )?.url;
    const image = img || `${url.origin}/icons/Icon-512.png`;
    const canonical = `${url.origin}${url.pathname}?public=true`;

    const set = (attr, key, value) => ({
      element(el) {
        if (el.getAttribute(attr) === key) el.setAttribute('content', value);
      },
    });

    let rewriter = new HTMLRewriter()
      .on('title', { element: (el) => el.setInnerContent(title) })
      .on('meta', set('property', 'og:title', title))
      .on('meta', set('property', 'og:description', description))
      .on('meta', set('property', 'og:url', canonical))
      .on('meta', set('property', 'og:image', image))
      .on('meta', set('property', 'og:type', 'article'))
      .on('meta', set('name', 'twitter:title', title))
      .on('meta', set('name', 'twitter:description', description))
      .on('meta', set('name', 'twitter:url', canonical))
      .on('meta', set('name', 'twitter:image', image))
      .on('meta', set('name', 'description', description));
    if (img) {
      rewriter = rewriter
        .on('meta', set('property', 'og:image:width', '1200'))
        .on('meta', set('property', 'og:image:height', '630'));
    }
    const headers = new Headers(page.headers);
    headers.set('Cache-Control', 'public, max-age=300');
    return rewriter.transform(new Response(page.body, { status: page.status, headers }));
  },
};
