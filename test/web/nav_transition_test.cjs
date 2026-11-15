const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const scriptPath = path.resolve(__dirname, '../../web/nav_transition.js');
const scriptSource = fs.readFileSync(scriptPath, 'utf8');

function createFakeDom({
  url = 'https://app.alphajournal.in/',
  referrer = '',
  cookies = '',
  prefersLight = false,
} = {}) {
  const parsedUrl = new URL(url);
  const byId = new Map();

  function makeNode(tagName, ns) {
    const attrs = new Map();
    const classes = new Set();
    const children = [];
    const styleProps = {};
    const node = {
      tagName: String(tagName).toUpperCase(),
      namespaceURI: ns || null,
      children,
      parentNode: null,
      textContent: '',
      _className: '',
      style: {
        cssText: '',
        backgroundColor: '',
        colorScheme: '',
        setProperty(k, v) {
          styleProps[k] = v;
        },
        getPropertyValue(k) {
          return styleProps[k] || '';
        },
      },
      classList: {
        add(c) {
          classes.add(c);
        },
        remove(c) {
          classes.delete(c);
        },
        contains(c) {
          return classes.has(c);
        },
      },
      set className(val) {
        this._className = val;
        classes.clear();
        String(val || '')
          .split(/\s+/)
          .filter(Boolean)
          .forEach((c) => classes.add(c));
      },
      get className() {
        return Array.from(classes).join(' ');
      },
      set id(val) {
        attrs.set('id', val);
        if (val) byId.set(val, node);
      },
      get id() {
        return attrs.get('id') || '';
      },
      setAttribute(k, v) {
        attrs.set(k, String(v));
        if (k === 'id') byId.set(String(v), node);
      },
      getAttribute(k) {
        return attrs.has(k) ? attrs.get(k) : null;
      },
      appendChild(child) {
        if (!child) return child;
        if (child.tagName === '#FRAGMENT') {
          for (const c of child.children.slice()) {
            node.appendChild(c);
          }
          return child;
        }
        child.parentNode = node;
        children.push(child);
        return child;
      },
      removeChild(child) {
        const idx = children.indexOf(child);
        if (idx >= 0) children.splice(idx, 1);
        if (child.id && byId.get(child.id) === child) {
          byId.delete(child.id);
        }
        child.parentNode = null;
        return child;
      },
      replaceChildren(...nodes) {
        children.length = 0;
        for (const n of nodes) node.appendChild(n);
      },
      querySelectorAll(sel) {
        const out = [];
        function walk(cur) {
          for (const ch of cur.children) {
            if (sel === 'meta[name="theme-color"]') {
              if (ch.tagName === 'META' && ch.getAttribute('name') === 'theme-color') {
                out.push(ch);
              }
            } else if (sel.startsWith('.')) {
              if (ch.classList.contains(sel.slice(1))) out.push(ch);
            }
            walk(ch);
          }
        }
        walk(node);
        return out;
      },
    };
    return node;
  }

  const head = makeNode('head');
  const metaTheme = makeNode('meta');
  metaTheme.setAttribute('name', 'theme-color');
  metaTheme.setAttribute('content', '#0D0C0B');
  head.appendChild(metaTheme);

  const body = makeNode('body');
  const silentShell = makeNode('div');
  silentShell.id = 'aj-silent-shell';
  body.appendChild(silentShell);

  const docEl = makeNode('html');
  docEl.appendChild(head);
  docEl.appendChild(body);

  let cookieJar = cookies;
  const cookieWrites = [];

  const document = {
    documentElement: docEl,
    head,
    body,
    referrer,
    createElement: (tag) => makeNode(tag),
    createElementNS: (ns, tag) => makeNode(tag, ns),
    createDocumentFragment: () => makeNode('#FRAGMENT'),
    getElementById: (id) => byId.get(id) || null,
    querySelector: (sel) => document.querySelectorAll(sel)[0] || null,
    querySelectorAll: (sel) => docEl.querySelectorAll(sel),
    get cookie() {
      return cookieJar;
    },
    set cookie(val) {
      cookieWrites.push(val);
      const firstSemi = val.indexOf(';');
      const pair = firstSemi >= 0 ? val.slice(0, firstSemi) : val;
      const eq = pair.indexOf('=');
      if (eq > 0) {
        const name = pair.slice(0, eq).trim();
        const rawVal = pair.slice(eq + 1).trim();
        const map = new Map();
        cookieJar
          .split(';')
          .map((p) => p.trim())
          .filter(Boolean)
          .forEach((p) => {
            const i = p.indexOf('=');
            if (i > 0) map.set(p.slice(0, i).trim(), p.slice(i + 1).trim());
          });
        if (/Max-Age=0\b/i.test(val)) {
          map.delete(name);
        } else {
          map.set(name, rawVal);
        }
        cookieJar = Array.from(map.entries())
          .map(([k, v]) => `${k}=${v}`)
          .join('; ');
      }
    },
  };

  const listeners = new Map();
  const windowObj = {
    location: {
      hostname: parsedUrl.hostname,
      pathname: parsedUrl.pathname,
      protocol: parsedUrl.protocol,
      origin: parsedUrl.origin,
    },
    matchMedia: (q) => ({
      matches: q.includes('light') ? prefersLight : false,
    }),
    addEventListener(evt, fn) {
      listeners.set(evt, fn);
    },
    localStorage: {
      getItem: () => null,
    },
  };

  const sandbox = {
    window: windowObj,
    document,
    location: windowObj.location,
    URL,
    globalThis: null,
  };
  sandbox.globalThis = sandbox;
  vm.runInNewContext(scriptSource, sandbox);

  return {
    api: sandbox.window.alphajournalTransition,
    window: sandbox.window,
    document,
    metaTheme,
    cookieWrites,
    listeners,
  };
}

test('resolveTheme aligns Light, Dark, and System modes with UiColors hex tokens', () => {
  const { api } = createFakeDom();
  const dark = api.resolveTheme({ cookieStr: 'ax_theme_mode=dark' });
  assert.equal(dark.isLight, false);
  assert.equal(dark.palette.bg, '#0D0C0B');
  assert.equal(dark.palette.surface, '#151312');

  const light = api.resolveTheme({ cookieStr: 'ax_theme_mode=light' });
  assert.equal(light.isLight, true);
  assert.equal(light.palette.bg, '#FAFAF9');
  assert.equal(light.palette.surface, '#FFFFFF');
  assert.equal(light.palette.fg, '#151312');

  const sysLight = api.resolveTheme({
    cookieStr: 'ax_theme_mode=system',
    prefersLight: true,
  });
  assert.equal(sysLight.isLight, true);

  const sysDark = api.resolveTheme({
    cookieStr: 'ax_theme_mode=system',
    prefersLight: false,
  });
  assert.equal(sysDark.isLight, false);
});

test('resolveSurface maps subdomain destinations to distinct skeletons, animations, and mobile dock active slots', () => {
  const { api } = createFakeDom();

  const commFeed = api.resolveSurface({
    url: 'https://community.alphajournal.in/community_feed',
  });
  assert.equal(commFeed.dockVariant, 'community');
  assert.equal(commFeed.activeSlot, 0);
  assert.equal(commFeed.centerActive, false);
  assert.equal(commFeed.layoutKind, 'feed');
  assert.equal(commFeed.animClass, 'aj-anim-cascade');

  const commExplore = api.resolveSurface({
    url: 'https://community.alphajournal.in/community_explore',
  });
  assert.equal(commExplore.dockVariant, 'community');
  assert.equal(commExplore.activeSlot, 1);
  assert.equal(commExplore.layoutKind, 'explore');

  const commNetwork = api.resolveSurface({
    url: 'https://community.alphajournal.in/community_network',
  });
  assert.equal(commNetwork.dockVariant, 'community');
  assert.equal(commNetwork.activeSlot, 2);
  assert.equal(commNetwork.layoutKind, 'people');
  assert.equal(commNetwork.animClass, 'aj-anim-pulse');

  const commProfile = api.resolveSurface({
    url: 'https://community.alphajournal.in/@nitish',
  });
  assert.equal(commProfile.dockVariant, 'community');
  assert.equal(commProfile.activeSlot, 3);
  assert.equal(commProfile.layoutKind, 'profile');
  assert.equal(commProfile.animClass, 'aj-anim-breath');

  const market = api.resolveSurface({
    url: 'https://app.alphajournal.in/market',
  });
  assert.equal(market.dockVariant, 'trader');
  assert.equal(market.centerActive, true);
  assert.equal(market.layoutKind, 'market');
  assert.equal(market.animClass, 'aj-anim-scan');

  const desk = api.resolveSurface({
    url: 'https://app.alphajournal.in/',
  });
  assert.equal(desk.dockVariant, 'trader');
  assert.equal(desk.activeSlot, 0);
  assert.equal(desk.centerActive, false);
  assert.equal(desk.layoutKind, 'dashboard');
  assert.equal(desk.animClass, 'aj-anim-wave');

  const partnerRefs = api.resolveSurface({
    url: 'https://affiliate.alphajournal.in/referrals',
  });
  assert.equal(partnerRefs.dockVariant, 'affiliate');
  assert.equal(partnerRefs.activeSlot, 1);
  assert.equal(partnerRefs.layoutKind, 'people');

  const adminUsers = api.resolveSurface({
    url: 'https://admin.alphajournal.in/org_team',
  });
  assert.equal(adminUsers.dockVariant, 'admin');
  assert.equal(adminUsers.activeSlot, 1);
});

test('initHead and mountIncoming apply light theme, clear one-shot cookie, and render full-screen skeleton with selected mobile dock item', () => {
  const env = createFakeDom({
    url: 'https://community.alphajournal.in/community_explore',
    cookies: 'ax_theme_mode=light; ax_silent_nav=1%7Ccommunity_explore%7CExplore',
  });

  const result = env.api.initHead();
  assert.equal(result.isSilent, true);
  assert.equal(env.document.documentElement.classList.contains('aj-light'), true);
  assert.equal(env.document.documentElement.classList.contains('aj-silent-nav'), true);
  assert.equal(env.metaTheme.getAttribute('content'), '#FAFAF9');
  assert.ok(env.cookieWrites.some((c) => c.startsWith('ax_silent_nav=;')));

  const host = env.api.mountIncoming();
  assert.ok(host);
  assert.equal(host.getAttribute('data-dock-variant'), 'community');
  assert.equal(host.getAttribute('data-active-slot'), '1');

  const activeDockItems = host.querySelectorAll('.aj-dock-item');
  assert.equal(activeDockItems.length, 4);
  assert.equal(activeDockItems[1].classList.contains('is-active'), true);
  assert.equal(activeDockItems[1].getAttribute('aria-current'), 'page');
  assert.equal(activeDockItems[0].classList.contains('is-active'), false);
});

test('startOutgoing renders persistent dock and surface skeleton in #aj-nav-veil and cleans up on pageshow', () => {
  const env = createFakeDom({
    url: 'https://app.alphajournal.in/',
    cookies: 'ax_theme_mode=dark',
  });
  env.api.initHead();

  const veil = env.api.startOutgoing('https://app.alphajournal.in/market');
  assert.ok(veil);
  assert.ok(env.document.getElementById('aj-nav-veil'));
  const centerBtn = veil.querySelectorAll('.aj-dock-center')[0];
  assert.equal(centerBtn.classList.contains('is-active'), true);
  assert.ok(veil.querySelectorAll('.aj-candle-bar').length > 0);

  // Back/forward cache restore removes the outgoing veil.
  const onPageShow = env.listeners.get('pageshow');
  assert.equal(typeof onPageShow, 'function');
  onPageShow();
  assert.equal(env.document.getElementById('aj-nav-veil'), null);
});
