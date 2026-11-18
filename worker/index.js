// Cloudflare Worker:
// - Serves the Flutter web app and enforces canonical subdomain routing across
//   alphajournal.in / app. / community. / affiliate. / admin.
// - Generates dynamic edge-cached /sitemap.xml and host-aware /robots.txt
// - Injects per-subdomain, per-route, per-post, and per-profile canonical URLs,
//   SEO meta tags, Open Graph / Twitter cards, and X-Robots-Tag headers.
//
// Required vars (wrangler secrets / vars): SUPABASE_URL, SUPABASE_ANON_KEY.
// Only public, approved posts & public profiles are exposed (enforced by Supabase RLS).

const ROOT_DOMAIN = 'alphajournal.in';
const POST_PATH = /^\/(?:community\/post|p|posts?)\/([0-9a-fA-F-]{36})\/?$/;
const HANDLE_PATH = /^\/@([a-zA-Z0-9_][a-zA-Z0-9_.-]*)\/?$/;
const STATIC_EXT = /\.[a-zA-Z0-9]{1,8}$/;

const ASSET_PREFIXES = ['/assets/', '/canvaskit/', '/icons/', '/.well-known/'];
const NEUTRAL_PREFIXES = ['/auth/', '/r/', '/join/', '/help'];
const FLUTTER_RUNTIME_PATH = /^\/main\.dart\.js(?:_\d+\.part\.js)?$/;
const FRESH_RUNTIME_PATHS = new Set([
  '/assets/AssetManifest.bin',
  '/assets/AssetManifest.bin.json',
  '/assets/AssetManifest.json',
  '/assets/FontManifest.json',
  '/assets/assets/config/client.env',
  '/flutter.js',
  '/flutter_bootstrap.js',
  '/flutter_service_worker.js',
  '/manifest.json',
  '/nav_transition.js',
  '/version.json',
]);

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
const PRIVATE_APP_SEGMENTS = new Set([
  'workspace',
  'journal',
  'strategies',
  'strategy',
  'notes',
  'note',
  'calculators',
  'messages',
  'message',
  'thread',
  'ai_copilot',
  'ai',
  'copilot',
  'notifications',
  'search',
  'settings',
  'settings_profile',
  'settings_security',
  'settings_notifications',
  'settings_privacy',
  'settings_appearance',
  'settings_help',
  'settings_billing',
  'settings_affiliate_perks',
  'settings_affiliate',
  'settings_platform',
  'overview',
  'referrals',
  'marketing',
  'payouts',
]);

const DEFAULT_ROBOTS_INDEX =
  'index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1';
const NOINDEX_ROBOTS = 'noindex, nofollow';

const escXml = (s) =>
  String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');

export function isAlphajournalHost(hostname) {
  const host = String(hostname || '').toLowerCase();
  return host === ROOT_DOMAIN || host.endsWith(`.${ROOT_DOMAIN}`);
}

export function runtimeCacheControl(pathname) {
  if (FLUTTER_RUNTIME_PATH.test(pathname)) {
    return 'no-cache, max-age=0, must-revalidate';
  }
  if (FRESH_RUNTIME_PATHS.has(pathname)) {
    return 'no-cache, no-store, must-revalidate';
  }
  return null;
}

function withRuntimeCacheHeaders(response, pathname) {
  const cacheControl = runtimeCacheControl(pathname);
  if (!cacheControl) return response;
  const headers = new Headers(response.headers);
  headers.set('Cache-Control', cacheControl);
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
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

export function resolvePageSeo(url, { post = null, profile = null } = {}) {
  const host = String(url.hostname || ROOT_DOMAIN).toLowerCase();
  const pathname = url.pathname || '/';
  const lower = pathname.toLowerCase();
  const firstSegment = lower.split('/').filter(Boolean)[0] || '';
  const origin = isAlphajournalHost(host) ? `https://${host}` : url.origin;
  const fallbackImage = `${origin}/icons/Icon-512.png`;

  if (host === `admin.${ROOT_DOMAIN}` || ADMIN_SEGMENTS.has(firstSegment) || firstSegment.startsWith('admin_') || firstSegment.startsWith('org_')) {
    return {
      title: 'alphajournal Admin Console',
      description: 'Restricted administration console for alphajournal.',
      canonical: `${origin}${pathname}`,
      image: fallbackImage,
      ogType: 'website',
      robots: NOINDEX_ROBOTS,
      noindex: true,
      hasCustomImage: false,
    };
  }

  const isExplicitPublicShare =
    url.searchParams.get('public') === 'true' &&
    ['notes', 'note', 'journal', 'strategies', 'strategy'].includes(firstSegment);

  const isPrivateRoute =
    lower.startsWith('/auth/') ||
    lower.startsWith('/r/') ||
    lower.startsWith('/join/') ||
    (!isExplicitPublicShare && PRIVATE_APP_SEGMENTS.has(firstSegment));

  if (post) {
    const name = post.profiles?.display_name || post.profiles?.handle || 'A trader';
    const handle = post.profiles?.handle ? ` (@${String(post.profiles.handle).replace(/^@/, '')})` : '';
    const img = (post.community_post_attachments || []).find(
      (a) => a.kind === 'image' && /^https?:\/\//.test(a.url || ''),
    )?.url;
    const postMatch = POST_PATH.exec(pathname);
    const canonicalPath = postMatch
      ? `/community/post/${postMatch[1]}`
      : pathname;
    return {
      title: `${name}${handle} on alphajournal`,
      description: excerpt(post.body, 200) || 'Verified trade commentary on alphajournal Community.',
      canonical: `https://community.${ROOT_DOMAIN}${canonicalPath}?public=true`,
      image: img || `https://community.${ROOT_DOMAIN}/icons/Icon-512.png`,
      ogType: 'article',
      robots: DEFAULT_ROBOTS_INDEX,
      noindex: false,
      hasCustomImage: Boolean(img),
    };
  }

  if (profile) {
    const cleanHandle = String(profile.handle || '').replace(/^@/, '');
    const display = profile.display_name || `@${cleanHandle}` || 'Trader';
    const avatar = /^https?:\/\//.test(profile.avatar_url || '') ? profile.avatar_url : '';
    return {
      title: `${display} (@${cleanHandle}) — alphajournal Trader Profile`,
      description:
        excerpt(profile.bio, 200) ||
        `Follow @${cleanHandle} on alphajournal Community for trading insights, execution breakdowns, and market notes.`,
      canonical: `https://community.${ROOT_DOMAIN}/@${cleanHandle}`,
      image: avatar || `https://community.${ROOT_DOMAIN}/icons/Icon-512.png`,
      ogType: 'profile',
      robots: DEFAULT_ROBOTS_INDEX,
      noindex: false,
      hasCustomImage: Boolean(avatar),
    };
  }

  if (host === `community.${ROOT_DOMAIN}`) {
    return {
      title: 'alphajournal Community — Live Trade Ideas & Verified Traders',
      description:
        'Browse real-time trade setups, market commentary, and verified trader profiles on alphajournal Community.',
      canonical: `https://community.${ROOT_DOMAIN}${pathname === '/' ? '/' : pathname}`,
      image: `https://community.${ROOT_DOMAIN}/icons/Icon-512.png`,
      ogType: 'website',
      robots: isPrivateRoute ? NOINDEX_ROBOTS : DEFAULT_ROBOTS_INDEX,
      noindex: isPrivateRoute,
      hasCustomImage: false,
    };
  }

  if (host === `affiliate.${ROOT_DOMAIN}`) {
    return {
      title: 'alphajournal Affiliate Partner Program — Earn Recurring Commissions',
      description:
        'Partner with alphajournal. Share institutional trading journal and AI market tools with your audience and track live referrals and payouts.',
      canonical: `https://affiliate.${ROOT_DOMAIN}${pathname === '/' ? '/affiliate_application' : pathname}`,
      image: `https://affiliate.${ROOT_DOMAIN}/icons/Icon-512.png`,
      ogType: 'website',
      robots: isPrivateRoute ? NOINDEX_ROBOTS : DEFAULT_ROBOTS_INDEX,
      noindex: isPrivateRoute,
      hasCustomImage: false,
    };
  }

  if (host === `app.${ROOT_DOMAIN}`) {
    if (firstSegment === 'market' || firstSegment.startsWith('market_')) {
      const segments = pathname.split('/').filter(Boolean);
      const symbol = segments.length >= 2 ? decodeURIComponent(segments[1]).toUpperCase() : '';
      if (symbol) {
        return {
          title: `${symbol} Live Quote, Charts & Analysis — alphajournal Markets`,
          description: `View ${symbol} real-time market price, technical charts, fundamentals, and company news on alphajournal.`,
          canonical: `https://app.${ROOT_DOMAIN}/market/${encodeURIComponent(symbol)}`,
          image: `https://app.${ROOT_DOMAIN}/icons/Icon-512.png`,
          ogType: 'website',
          robots: DEFAULT_ROBOTS_INDEX,
          noindex: false,
          hasCustomImage: false,
        };
      }
      return {
        title: 'alphajournal Markets — Live Quotes, Screeners & Market Movers',
        description:
          'Track live market movers, instruments, news, and institutional screeners inside alphajournal.',
        canonical: `https://app.${ROOT_DOMAIN}${pathname}`,
        image: `https://app.${ROOT_DOMAIN}/icons/Icon-512.png`,
        ogType: 'website',
        robots: DEFAULT_ROBOTS_INDEX,
        noindex: false,
        hasCustomImage: false,
      };
    }
    if (isExplicitPublicShare) {
      const shareLabel = firstSegment.startsWith('journal')
        ? 'Shared Trade Execution'
        : firstSegment.startsWith('strateg')
          ? 'Shared Strategy Playbook'
          : 'Shared Research Note';
      return {
        title: `${shareLabel} — alphajournal`,
        description:
          'View shared trading research, execution breakdowns, and risk analytics published from alphajournal Workspace.',
        canonical: `https://app.${ROOT_DOMAIN}${pathname}?public=true`,
        image: `https://app.${ROOT_DOMAIN}/icons/Icon-512.png`,
        ogType: 'article',
        robots: DEFAULT_ROBOTS_INDEX,
        noindex: false,
        hasCustomImage: false,
      };
    }
    return {
      title: 'alphajournal Workspace — Trading Journal, Research Notes & AI Copilot',
      description:
        'Log executions, build linked strategy notes, analyze risk metrics, and run real-time AI market research on alphajournal.',
      canonical: `https://app.${ROOT_DOMAIN}${pathname === '/' ? '/' : pathname}`,
      image: `https://app.${ROOT_DOMAIN}/icons/Icon-512.png`,
      ogType: 'website',
      robots: isPrivateRoute ? NOINDEX_ROBOTS : DEFAULT_ROBOTS_INDEX,
      noindex: isPrivateRoute,
      hasCustomImage: false,
    };
  }

  if (lower === '/help' || lower.startsWith('/help/')) {
    return {
      title: 'alphajournal Help, Security & Legal Policies',
      description:
        'Documentation, end-to-end encryption overview, privacy policy, and platform guides for alphajournal.',
      canonical: `https://${ROOT_DOMAIN}${pathname}`,
      image: `https://${ROOT_DOMAIN}/icons/Icon-512.png`,
      ogType: 'website',
      robots: DEFAULT_ROBOTS_INDEX,
      noindex: false,
      hasCustomImage: false,
    };
  }

  return {
    title: 'alphajournal — Institutional Trading Journal, AI Playbooks & Market Community',
    description:
      'Log trades, write linked research notes, track strategy playbooks, and collaborate with verified traders on alphajournal. Available in Free, Basic (₹299/mo), and Pro (₹499/mo) tiers.',
    canonical: `${origin}${pathname === '/' ? '/' : pathname}`,
    image: fallbackImage,
    ogType: 'website',
    robots: isPrivateRoute ? NOINDEX_ROBOTS : DEFAULT_ROBOTS_INDEX,
    noindex: isPrivateRoute,
    hasCustomImage: false,
  };
}

async function fetchSupabaseJson(env, pathAndQuery, cacheTtl = 300) {
  if (!env?.SUPABASE_URL || !env?.SUPABASE_ANON_KEY) return null;
  const url = `${env.SUPABASE_URL}${pathAndQuery}`;
  try {
    const res = await fetch(url, {
      headers: {
        apikey: env.SUPABASE_ANON_KEY,
        Authorization: `Bearer ${env.SUPABASE_ANON_KEY}`,
      },
      cf: { cacheTtl, cacheEverything: true },
    });
    if (!res.ok) return null;
    return await res.json();
  } catch (_) {
    return null;
  }
}

export function resolvePublicStorageUrl(env, bucket, rawValue) {
  const raw = String(rawValue || '').trim();
  if (!raw || raw.startsWith('data:') || raw.startsWith('file:')) return '';

  const base = String(env?.SUPABASE_URL || '').trim().replace(/\/+$/, '');
  const marker = `/storage/v1/object/`;
  if (/^https?:\/\//i.test(raw)) {
    try {
      const u = new URL(raw);
      const idx = u.pathname.indexOf(marker);
      if (idx !== -1) {
        const tail = u.pathname.slice(idx + marker.length);
        const parts = tail.split('/').filter(Boolean);
        // Expected: <accessType>/<bucket>/<...key>
        if (parts.length >= 3 && parts[1] === bucket) {
          const objectPath = parts.slice(2).join('/');
          return `${u.origin}/storage/v1/object/public/${bucket}/${objectPath}`;
        }
      }
    } catch (_) {
      return raw;
    }
    return raw;
  }

  if (!base) return '';
  const cleanPath = raw.replace(new RegExp(`^/+|^${bucket}/+`), '').replace(/^\/+/, '');
  if (!cleanPath || cleanPath.includes('..')) return '';
  return `${base}/storage/v1/object/public/${bucket}/${cleanPath}`;
}

async function loadPost(env, id) {
  const select =
    'body,created_at,profiles!community_posts_author_id_fkey(display_name,handle),' +
    'community_post_attachments(kind,url)';
  const rows = await fetchSupabaseJson(
    env,
    `/rest/v1/community_posts?id=eq.${id}&select=${encodeURIComponent(select)}&limit=1`,
    300,
  );
  const row = Array.isArray(rows) ? rows[0] || null : null;
  if (row && Array.isArray(row.community_post_attachments)) {
    row.community_post_attachments = row.community_post_attachments.map((att) => {
      if (att && att.kind === 'image' && att.url) {
        const normalized = resolvePublicStorageUrl(env, 'community-attachments', att.url);
        return normalized ? { ...att, url: normalized } : att;
      }
      return att;
    });
  }
  return row;
}

async function loadProfile(env, rawHandle) {
  const clean = String(rawHandle || '').replace(/^@/, '');
  if (!clean) return null;
  const filter = encodeURIComponent(`(handle.eq.${clean},handle.eq.@${clean})`);
  const rows = await fetchSupabaseJson(
    env,
    `/rest/v1/profiles?select=display_name,handle,bio,avatar_url&or=${filter}&limit=1`,
    300,
  );
  const profile = Array.isArray(rows) ? rows[0] || null : null;
  if (profile && profile.avatar_url) {
    const normalized = resolvePublicStorageUrl(env, 'avatars', profile.avatar_url);
    if (normalized) profile.avatar_url = normalized;
  }
  return profile;
}

export async function buildDynamicSitemapXml(env) {
  const staticUrls = [
    { loc: `https://${ROOT_DOMAIN}/`, changefreq: 'daily', priority: '1.0' },
    { loc: `https://${ROOT_DOMAIN}/help`, changefreq: 'weekly', priority: '0.6' },
    { loc: `https://app.${ROOT_DOMAIN}/`, changefreq: 'daily', priority: '0.9' },
    { loc: `https://app.${ROOT_DOMAIN}/market`, changefreq: 'hourly', priority: '0.9' },
    { loc: `https://community.${ROOT_DOMAIN}/`, changefreq: 'hourly', priority: '0.9' },
    { loc: `https://community.${ROOT_DOMAIN}/community_feed`, changefreq: 'hourly', priority: '0.9' },
    { loc: `https://affiliate.${ROOT_DOMAIN}/affiliate_application`, changefreq: 'weekly', priority: '0.8' },
  ];

  const [posts, profiles] = await Promise.all([
    fetchSupabaseJson(
      env,
      '/rest/v1/community_posts?select=id,created_at&order=created_at.desc&limit=200',
      1800,
    ),
    fetchSupabaseJson(
      env,
      '/rest/v1/profiles?select=handle,created_at&handle=not.is.null&limit=200',
      1800,
    ),
  ]);

  const dynamicUrls = [];
  if (Array.isArray(posts)) {
    for (const p of posts) {
      if (!p?.id || !/^[0-9a-fA-F-]{36}$/.test(p.id)) continue;
      dynamicUrls.push({
        loc: `https://community.${ROOT_DOMAIN}/community/post/${p.id}?public=true`,
        lastmod: p.created_at ? String(p.created_at).slice(0, 10) : null,
        changefreq: 'daily',
        priority: '0.7',
      });
    }
  }
  if (Array.isArray(profiles)) {
    for (const pr of profiles) {
      const clean = String(pr?.handle || '').replace(/^@/, '').trim();
      if (!clean || !/^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$/.test(clean)) continue;
      dynamicUrls.push({
        loc: `https://community.${ROOT_DOMAIN}/@${encodeURIComponent(clean)}`,
        lastmod: pr.created_at ? String(pr.created_at).slice(0, 10) : null,
        changefreq: 'weekly',
        priority: '0.6',
      });
    }
  }

  const lines = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ...[...staticUrls, ...dynamicUrls].map((entry) => {
      const parts = [
        '  <url>',
        `    <loc>${escXml(entry.loc)}</loc>`,
        ...(entry.lastmod ? [`    <lastmod>${escXml(entry.lastmod)}</lastmod>`] : []),
        `    <changefreq>${entry.changefreq}</changefreq>`,
        `    <priority>${entry.priority}</priority>`,
        '  </url>',
      ];
      return parts.join('\n');
    }),
    '</urlset>',
    '',
  ];
  return lines.join('\n');
}

function applySeoRewriter(response, seo) {
  const setMeta = (attr, key, value) => ({
    element(el) {
      if (el.getAttribute(attr) === key) el.setAttribute('content', value);
    },
  });

  let rewriter = new HTMLRewriter()
    .on('title', { element: (el) => el.setInnerContent(seo.title) })
    .on('link', {
      element(el) {
        if (el.getAttribute('rel') === 'canonical') {
          el.setAttribute('href', seo.canonical);
        }
      },
    })
    .on('meta', setMeta('name', 'title', seo.title))
    .on('meta', setMeta('name', 'description', seo.description))
    .on('meta', setMeta('name', 'robots', seo.robots))
    .on('meta', setMeta('property', 'og:type', seo.ogType))
    .on('meta', setMeta('property', 'og:title', seo.title))
    .on('meta', setMeta('property', 'og:description', seo.description))
    .on('meta', setMeta('property', 'og:url', seo.canonical))
    .on('meta', setMeta('property', 'og:image', seo.image))
    .on('meta', setMeta('name', 'twitter:title', seo.title))
    .on('meta', setMeta('name', 'twitter:description', seo.description))
    .on('meta', setMeta('name', 'twitter:url', seo.canonical))
    .on('meta', setMeta('name', 'twitter:image', seo.image));

  if (seo.hasCustomImage) {
    rewriter = rewriter
      .on('meta', setMeta('property', 'og:image:width', '1200'))
      .on('meta', setMeta('property', 'og:image:height', '630'));
  }

  return rewriter.transform(response);
}

export function logWorkerEvent(level, event, details = {}) {
  const payload = {
    ts: new Date().toISOString(),
    source: 'cloudflare_worker',
    level,
    event,
    ...details,
  };
  const line = JSON.stringify(payload);
  if (level === 'error') {
    console.error(line);
  } else {
    console.log(line);
  }
}

export default {
  async fetch(request, env) {
    const startedAt = Date.now();
    const requestUrl = new URL(request.url);
    const redirectTo = resolveRedirectUrl(request.url, request.method);
    if (redirectTo) {
      logWorkerEvent('info', 'worker_redirect', {
        host: requestUrl.hostname.toLowerCase(),
        path: requestUrl.pathname,
        target_host: new URL(redirectTo).hostname.toLowerCase(),
        status: 308,
        duration_ms: Date.now() - startedAt,
      });
      return Response.redirect(redirectTo, 308);
    }

    const url = requestUrl;
    const host = url.hostname.toLowerCase();

    if (url.pathname === '/robots.txt' && host === `admin.${ROOT_DOMAIN}`) {
      return new Response('User-agent: *\nDisallow: /\n', {
        status: 200,
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
          'Cache-Control': 'public, max-age=3600',
        },
      });
    }

    if (url.pathname === '/sitemap.xml' && (request.method === 'GET' || request.method === 'HEAD')) {
      if (host === `admin.${ROOT_DOMAIN}`) {
        logWorkerEvent('info', 'worker_sitemap_blocked', {
          host,
          status: 404,
          duration_ms: Date.now() - startedAt,
        });
        return new Response('Not Found', {
          status: 404,
          headers: { 'X-Robots-Tag': NOINDEX_ROBOTS },
        });
      }
      const xml = await buildDynamicSitemapXml(env);
      const urlCount = (xml.match(/<url>/g) || []).length;
      logWorkerEvent('info', 'worker_sitemap_served', {
        host,
        status: 200,
        url_count: urlCount,
        duration_ms: Date.now() - startedAt,
      });
      return new Response(request.method === 'HEAD' ? null : xml, {
        status: 200,
        headers: {
          'Content-Type': 'application/xml; charset=utf-8',
          'Cache-Control': 'public, max-age=1800',
        },
      });
    }

    const page = withRuntimeCacheHeaders(
      await env.ASSETS.fetch(request),
      url.pathname,
    );
    const ct = page.headers.get('content-type') || '';
    if (!ct.includes('text/html') && !POST_PATH.test(url.pathname) && !HANDLE_PATH.test(url.pathname)) {
      return page;
    }

    const postMatch = POST_PATH.exec(url.pathname);
    const handleMatch = HANDLE_PATH.exec(url.pathname);

    let post = null;
    let profile = null;
    if (request.method === 'GET') {
      if (postMatch) {
        post = await loadPost(env, postMatch[1]);
      } else if (handleMatch) {
        profile = await loadProfile(env, handleMatch[1]);
      }
    }

    const seo = resolvePageSeo(url, { post, profile });
    const headers = new Headers(page.headers);
    if (!headers.has('Cache-Control')) {
      headers.set(
        'Cache-Control',
        post || profile ? 'public, max-age=300' : 'no-cache, no-store, must-revalidate',
      );
    } else if (post || profile) {
      headers.set('Cache-Control', 'public, max-age=300');
    }
    if (seo.noindex) {
      headers.set('X-Robots-Tag', NOINDEX_ROBOTS);
    }

    logWorkerEvent('info', 'worker_seo_served', {
      host,
      path: url.pathname,
      status: page.status,
      seo_kind: post ? 'post' : profile ? 'profile' : 'static',
      entity_found: post ? true : profile ? true : undefined,
      noindex: Boolean(seo.noindex),
      duration_ms: Date.now() - startedAt,
    });

    const baseResponse = new Response(page.body, {
      status: page.status,
      statusText: page.statusText,
      headers,
    });

    if (typeof HTMLRewriter === 'undefined') {
      return baseResponse;
    }
    return applySeoRewriter(baseResponse, seo);
  },
};
