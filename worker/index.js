// Cloudflare Worker: serves the Flutter web app and injects per-post Open Graph /
// Twitter card metadata for shared community-post links, so WhatsApp, X, LinkedIn,
// Telegram, Slack etc. render a rich card (author, excerpt, image) instead of
// the generic site logo.
//
// Required vars (wrangler secrets / vars): SUPABASE_URL, SUPABASE_ANON_KEY.
// Only public, approved posts are exposed (enforced by Supabase RLS for anon).

const POST_PATH = /^\/community\/post\/([0-9a-fA-F-]{36})\/?$/;

const esc = (s) =>
  String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

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
    const url = new URL(request.url);
    // Clipboard and Web Share require a secure browser context. Preserve the
    // exact shared path/query while upgrading old http:// links.
    if (url.protocol === 'http:' &&
        (url.hostname === 'alphajournal.in' || url.hostname.endsWith('.alphajournal.in'))) {
      url.protocol = 'https:';
      return Response.redirect(url.toString(), 308);
    }
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
