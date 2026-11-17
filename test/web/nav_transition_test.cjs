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
  storage = {},
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
      search: parsedUrl.search,
      hash: parsedUrl.hash,
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
      getItem: (k) =>
        Object.prototype.hasOwnProperty.call(storage, k) ? storage[k] : null,
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

test('resolveSurface maps subdomain destinations to exact UiSkeleton presets and QuietDock slots', () => {
  const { api } = createFakeDom();

  const commFeed = api.resolveSurface({
    url: 'https://community.alphajournal.in/community_feed',
  });
  assert.equal(commFeed.dockVariant, 'community');
  assert.equal(commFeed.activeSlot, 0);
  assert.equal(commFeed.centerActive, false);
  assert.equal(commFeed.layoutKind, 'community');

  const commExplore = api.resolveSurface({
    url: 'https://community.alphajournal.in/community_explore',
  });
  assert.equal(commExplore.dockVariant, 'community');
  assert.equal(commExplore.activeSlot, 1);
  assert.equal(commExplore.layoutKind, 'community_explore');

  const commNetwork = api.resolveSurface({
    url: 'https://community.alphajournal.in/community_network',
  });
  assert.equal(commNetwork.dockVariant, 'community');
  assert.equal(commNetwork.activeSlot, 2);
  assert.equal(commNetwork.layoutKind, 'network');

  const commProfile = api.resolveSurface({
    url: 'https://community.alphajournal.in/@nitish',
  });
  assert.equal(commProfile.dockVariant, 'community');
  assert.equal(commProfile.activeSlot, 3);
  assert.equal(commProfile.layoutKind, 'profile_preview');

  const market = api.resolveSurface({
    url: 'https://app.alphajournal.in/market',
  });
  assert.equal(market.dockVariant, 'trader');
  assert.equal(market.centerActive, true);
  assert.equal(market.centerRouteIcon, 'globe');
  assert.equal(market.layoutKind, 'market');

  const desk = api.resolveSurface({
    url: 'https://app.alphajournal.in/',
  });
  assert.equal(desk.dockVariant, 'trader');
  assert.equal(desk.activeSlot, 0);
  assert.equal(desk.centerActive, false);
  assert.equal(desk.layoutKind, 'journal');

  const partnerRefs = api.resolveSurface({
    url: 'https://affiliate.alphajournal.in/referrals',
  });
  assert.equal(partnerRefs.dockVariant, 'affiliate');
  assert.equal(partnerRefs.activeSlot, 1);
  assert.equal(partnerRefs.layoutKind, 'dashboard');

  const adminUsers = api.resolveSurface({
    url: 'https://admin.alphajournal.in/org_team',
  });
  assert.equal(adminUsers.dockVariant, 'admin');
  assert.equal(adminUsers.activeSlot, 1);
  assert.equal(adminUsers.layoutKind, 'page');
});

test('initHead and mountIncoming apply light theme, clear one-shot cookie, and render full-screen skeleton with selected QuietDock pill', () => {
  const env = createFakeDom({
    url: 'https://community.alphajournal.in/community_explore',
    cookies:
      'ax_sb_auth.n=1; ax_theme_mode=light; ax_silent_nav=1%7Ccommunity_explore%7CExplore',
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

  const dockItems = host.querySelectorAll('.aj-dock-item');
  assert.equal(dockItems.length, 4);
  assert.equal(dockItems[1].classList.contains('is-active'), true);
  assert.equal(dockItems[1].getAttribute('aria-current'), 'page');
  assert.equal(dockItems[1].querySelectorAll('.aj-dock-pill').length, 1);
  assert.equal(dockItems[0].classList.contains('is-active'), false);
});

test('startOutgoing renders QuietDock center-active pill, AppTopBar, and UiSkeleton.market mosaic in #aj-nav-veil and cleans up on pageshow', () => {
  const env = createFakeDom({
    url: 'https://app.alphajournal.in/',
    cookies: 'ax_sb_auth.n=1; ax_theme_mode=dark',
  });
  env.api.initHead();

  const veil = env.api.startOutgoing('https://app.alphajournal.in/market');
  assert.ok(veil);
  assert.ok(env.document.getElementById('aj-nav-veil'));
  const centerBtn = veil.querySelectorAll('.aj-dock-center')[0];
  assert.equal(centerBtn.classList.contains('is-active'), true);
  assert.equal(centerBtn.querySelectorAll('.aj-dock-pill').length, 1);
  assert.equal(centerBtn.querySelectorAll('.aj-dock-back').length, 1);
  assert.ok(veil.querySelectorAll('.aj-mosaic').length > 0);
  assert.ok(veil.querySelectorAll('.aj-content-frame').length > 0);

  // Back/forward cache restore removes the outgoing veil.
  const onPageShow = env.listeners.get('pageshow');
  assert.equal(typeof onPageShow, 'function');
  onPageShow();
  assert.equal(env.document.getElementById('aj-nav-veil'), null);
});

test('default loader is preserved when logged out, signed out marker is set, or route is auth/onboarding/OAuth/public', () => {
  const loggedOutOnboard = createFakeDom({
    url: 'https://app.alphajournal.in/messages',
    cookies: 'ax_onboard=1; ax_theme_mode=dark',
  });
  assert.equal(loggedOutOnboard.api.initHead().isSilent, false);
  assert.equal(
    loggedOutOnboard.document.documentElement.classList.contains('aj-silent-nav'),
    false,
  );
  assert.equal(
    loggedOutOnboard.api.startOutgoing('https://community.alphajournal.in/community_feed'),
    null,
  );

  const signedOutMarker = createFakeDom({
    url: 'https://app.alphajournal.in/messages',
    cookies: 'ax_sb_auth.n=1; ax_sb_auth_off=1',
  });
  assert.equal(signedOutMarker.api.initHead().isSilent, false);
  assert.equal(
    signedOutMarker.api.startOutgoing('https://app.alphajournal.in/market'),
    null,
  );

  for (const routeUrl of [
    'https://app.alphajournal.in/auth/login',
    'https://app.alphajournal.in/auth/signup',
    'https://app.alphajournal.in/auth/forgot-password',
    'https://app.alphajournal.in/?code=oauth_code_123',
    'https://alphajournal.in/',
  ]) {
    const authEnv = createFakeDom({
      url: routeUrl,
      cookies: 'ax_sb_auth.n=1; ax_silent_nav=1%7Cworkspace%7CWorkspace',
    });
    assert.equal(
      authEnv.api.initHead().isSilent,
      false,
      `Expected initHead().isSilent === false for ${routeUrl}`,
    );

    const originEnv = createFakeDom({
      url: 'https://app.alphajournal.in/messages',
      cookies: 'ax_sb_auth.n=1',
    });
    originEnv.api.initHead();
    assert.equal(
      originEnv.api.startOutgoing(routeUrl),
      null,
      `Expected startOutgoing() === null for ${routeUrl}`,
    );
  }
});

test('authenticated app and community cross-subdomain routes activate silent nav', () => {
  const incomingEnv = createFakeDom({
    url: 'https://app.alphajournal.in/messages',
    referrer: 'https://community.alphajournal.in/',
    cookies: 'ax_sb_auth.n=1; ax_theme_mode=dark',
  });
  assert.equal(incomingEnv.api.initHead().isSilent, true);

  const outgoingEnv = createFakeDom({
    url: 'https://app.alphajournal.in/messages',
    cookies: 'ax_sb_auth.n=1; ax_theme_mode=dark',
  });
  assert.equal(outgoingEnv.api.initHead().isSilent, false);
  const veil = outgoingEnv.api.startOutgoing(
    'https://community.alphajournal.in/community_feed',
  );
  assert.ok(veil);
  assert.equal(veil.children[0].getAttribute('data-dock-variant'), 'community');
});

test('transition chrome mirrors AppTopBar card, swap_vert, desktop/mobile titles, 17px sidebar icons, light skeleton tokens, and Material SVG icons', () => {
  const env = createFakeDom({
    url: 'https://app.alphajournal.in/workspace',
    referrer: 'https://community.alphajournal.in/',
    cookies: 'ax_sb_auth.n=1; ax_theme_mode=dark',
  });
  env.api.initHead();
  env.api.mountIncoming();

  // TopBar card wrapper + responsive desktop/mobile titles + search/calc actions
  const topbarCards = env.document.querySelectorAll('.aj-topbar-card');
  assert.equal(topbarCards.length, 1);
  const desktopTitle = env.document.querySelector('.aj-top-title-desktop');
  const mobileTitle = env.document.querySelector('.aj-top-title-mobile');
  assert.equal(desktopTitle.textContent, 'Terminal / Workspace');
  assert.equal(mobileTitle.textContent, 'Workspace');
  assert.equal(env.document.querySelectorAll('.aj-mobile-only').length, 1);
  assert.equal(env.document.querySelectorAll('.aj-desktop-only').length, 1);

  // AppWorkspaceTile header + footer carry swap_vert icons; sidebar nav icons are 17px
  assert.equal(env.document.querySelectorAll('.aj-side-swap').length, 2);
  const sideSvgs = env.document
    .querySelector('.aj-sidebar')
    .querySelectorAll('.aj-side-item-left');
  assert.ok(sideSvgs.length > 0);
  for (const left of sideSvgs) {
    const svg = left.children[0];
    assert.equal(svg.tagName, 'SVG');
    assert.equal(svg.getAttribute('width'), '17');
    assert.equal(svg.getAttribute('height'), '17');
  }

  // Light skeleton token + frosted dock backdrop filter + edge-to-edge scroll padding
  const skBase = env.document.documentElement.style.getPropertyValue('--aj-sk-base');
  assert.equal(skBase, 'rgba(250, 249, 249, 0.045)');
  const dockBg = env.document.documentElement.style.getPropertyValue('--aj-dock-bg');
  assert.equal(dockBg, 'rgba(21, 19, 18, 0.62)');

  const styleEl = env.document.getElementById('aj-transition-styles');
  assert.ok(styleEl.textContent.includes('backdrop-filter:blur(18px)'));
  assert.ok(styleEl.textContent.includes('.aj-scroll{flex:1;overflow:hidden;padding:var(--aj-pad);padding-bottom:16px;}'));

  // Filled apps/grid Material icons on dock vs outlined icons
  const dockSlots = env.document.querySelectorAll('.aj-dock-slot');
  assert.equal(dockSlots.length, 5);
  const centerSvg = dockSlots[2].querySelectorAll('.aj-dock-icon')[0].children[0];
  assert.equal(centerSvg.getAttribute('fill'), 'currentColor');
  assert.equal(centerSvg.getAttribute('width'), '22');

  const communityEnv = createFakeDom({
    url: 'https://community.alphajournal.in/community_feed',
    referrer: 'https://app.alphajournal.in/',
    cookies: 'ax_sb_auth.n=1; ax_theme_mode=dark',
  });
  communityEnv.api.initHead();
  communityEnv.api.mountIncoming();
  const commSlots = communityEnv.document.querySelectorAll('.aj-dock-slot');
  const feedSvg = commSlots[0].querySelectorAll('.aj-dock-icon')[0].children[0];
  assert.equal(feedSvg.getAttribute('fill'), 'none');
  const commCenterSvg = commSlots[2].querySelectorAll('.aj-dock-icon')[0].children[0];
  assert.equal(commCenterSvg.getAttribute('fill'), 'currentColor');
  const profileSvg = commSlots[4].querySelectorAll('.aj-dock-icon')[0].children[0];
  assert.equal(profileSvg.getAttribute('fill'), 'none');
});

test('transition chrome omits Features pill, omits market skeleton white horizontal dividers, and uses NotoSans with responsive text scaling', () => {
  const env = createFakeDom({
    url: 'https://app.alphajournal.in/market',
    referrer: 'https://community.alphajournal.in/',
    cookies: 'ax_sb_auth.n=1; ax_theme_mode=dark',
  });
  env.api.initHead();
  env.api.mountIncoming();

  // Global header omits redundant Features pill while keeping topbar actions.
  assert.equal(env.document.querySelectorAll('.aj-features-pill').length, 0);
  const styleEl = env.document.getElementById('aj-transition-styles');
  assert.equal(styleEl.textContent.includes('.aj-features-pill'), false);

  // Market skeleton renders without horizontal row dividers.
  assert.equal(env.document.querySelectorAll('.aj-hdiv').length, 0);
  assert.equal(styleEl.textContent.includes('.aj-hdiv'), false);

  // Workspace plan subtitle uses distinct .aj-side-plan class (11 base vs 13 sub-item).
  assert.equal(env.document.querySelectorAll('.aj-side-plan').length, 1);

  // Typography matches Flutter UiTypography (NotoSans + UiScaleConfig responsive scale & user text scale clamp).
  assert.ok(styleEl.textContent.includes('@font-face{font-family:"NotoSans"'));
  assert.ok(styleEl.textContent.includes('font-family:"Noto Sans","NotoSans",system-ui'));
  assert.ok(styleEl.textContent.includes('--aj-unit:clamp(0.85px,0.0625rem,1.4px)'));
  assert.ok(styleEl.textContent.includes('@media(min-width:905px){.aj-trans-host{--aj-text-scale:1.1;}}'));
  assert.ok(styleEl.textContent.includes('.aj-page-title{font-size:calc(24 * var(--aj-text-scale) * var(--aj-unit))'));
  assert.ok(styleEl.textContent.includes('.aj-page-sub{font-size:calc(14 * var(--aj-text-scale) * var(--aj-unit))'));
});

test('subdomain switcher loader respects latest cookie, SharedPreferences fallback, system mode, and live syncTheme updates', () => {
  // Duplicate host-only cookie followed by updated parent-domain cookie resolves to the latest value.
  const duplicateEnv = createFakeDom({
    url: 'https://community.alphajournal.in/community_feed',
    cookies:
      'ax_sb_auth.n=1; ax_theme_mode=dark; ax_theme_mode=light; ax_theme_density=Compact',
  });
  const dupInit = duplicateEnv.api.initHead();
  assert.equal(dupInit.theme.isLight, true);
  assert.equal(dupInit.theme.compact, true);
  assert.equal(
    duplicateEnv.document.documentElement.classList.contains('aj-light'),
    true,
  );
  assert.equal(
    duplicateEnv.document.documentElement.style.getPropertyValue('--aj-bg'),
    '#FAFAF9',
  );
  assert.equal(duplicateEnv.metaTheme.getAttribute('content'), '#FAFAF9');

  // SharedPreferences flutter.* keys work when cookies are absent (e.g. localhost or first load).
  const storageEnv = createFakeDom({
    url: 'http://localhost:5000/market',
    cookies: 'ax_sb_auth.n=1',
    storage: {
      'flutter.ax_theme_mode': '"light"',
      'flutter.ax_theme_density': '"Compact"',
    },
  });
  const spInit = storageEnv.api.initHead();
  assert.equal(spInit.theme.isLight, true);
  assert.equal(spInit.theme.compact, true);
  const spVeil = storageEnv.api.startOutgoing(
    'https://community.alphajournal.in/community_feed',
  );
  assert.ok(spVeil);
  assert.ok(spVeil.style.cssText.includes('#FAFAF9'));
  assert.equal(
    storageEnv.document.documentElement.classList.contains('aj-light'),
    true,
  );

  // Live syncTheme switches dark -> light -> system cleanly across DOM tokens and veil palette.
  const liveEnv = createFakeDom({
    url: 'https://app.alphajournal.in/settings',
    cookies: 'ax_sb_auth.n=1; ax_theme_mode=dark',
    prefersLight: true,
  });
  liveEnv.api.initHead();
  assert.equal(
    liveEnv.document.documentElement.classList.contains('aj-light'),
    false,
  );
  liveEnv.api.syncTheme('light', 'Compact', true);
  assert.equal(
    liveEnv.document.documentElement.classList.contains('aj-light'),
    true,
  );
  assert.equal(
    liveEnv.document.documentElement.style.getPropertyValue('--aj-bg'),
    '#FAFAF9',
  );
  assert.equal(
    liveEnv.document.documentElement.style.getPropertyValue('--aj-pad'),
    '12px',
  );
  assert.equal(liveEnv.metaTheme.getAttribute('content'), '#FAFAF9');

  liveEnv.api.syncTheme('system', 'Comfortable', false);
  assert.equal(
    liveEnv.document.documentElement.classList.contains('aj-light'),
    false,
  );
  assert.equal(
    liveEnv.document.documentElement.style.getPropertyValue('--aj-bg'),
    '#0D0C0B',
  );
  assert.equal(
    liveEnv.document.documentElement.style.getPropertyValue('--aj-pad'),
    '16px',
  );
});

test('clicking Community renders full Trader sidebar with expanded Community sub-tree (Feed, Explore, Network, My Profile, Bookmarks)', () => {
  const env = createFakeDom({
    url: 'https://app.alphajournal.in/workspace',
    cookies: 'ax_sb_auth.n=1; ax_theme_mode=dark',
  });
  env.api.initHead();

  const veil = env.api.startOutgoing('https://community.alphajournal.in/community');
  assert.ok(veil);

  const sectionTitles = env.document
    .querySelectorAll('.aj-side-sec-title')
    .map((n) => n.textContent);
  assert.deepEqual(sectionTitles, [
    'WORKSPACE',
    'CONNECT & INTELLIGENCE',
    'MARKETS',
    'ACCOUNT',
  ]);

  const activeItems = env.document
    .querySelectorAll('.aj-side-item')
    .filter((n) => n.classList.contains('is-active'))
    .map((n) => n.querySelectorAll('.aj-side-item-label')[0].textContent);
  assert.deepEqual(activeItems, ['Community']);

  const openChevs = env.document
    .querySelectorAll('.aj-side-chev')
    .filter((n) => n.classList.contains('is-open'));
  assert.equal(openChevs.length, 1);

  const subLabels = env.document
    .querySelectorAll('.aj-side-sub')
    .map((n) => n.textContent);
  assert.deepEqual(subLabels, [
    'Feed',
    'Explore',
    'Network',
    'My Profile',
    'Bookmarks',
  ]);

  const activeSubs = env.document
    .querySelectorAll('.aj-side-sub')
    .filter((n) => n.classList.contains('is-active'))
    .map((n) => n.textContent);
  assert.deepEqual(activeSubs, ['Feed']);

  const styleEl = env.document.getElementById('aj-transition-styles');
  assert.ok(styleEl.textContent.includes('border-left:2px solid var(--aj-border)'));
  assert.ok(
    styleEl.textContent.includes(
      '.aj-side-sub.is-active{background:var(--aj-primary-soft);color:var(--aj-fg);border:1px solid var(--aj-primary-border);font-weight:600;}',
    ),
  );

  // Also verify mountIncoming on community.alphajournal.in/community renders the exact same tree
  const incomingEnv = createFakeDom({
    url: 'https://community.alphajournal.in/community',
    cookies: 'ax_sb_auth.n=1; ax_theme_mode=dark; ax_silent_nav=1|community_feed|Community',
  });
  incomingEnv.api.initHead();
  incomingEnv.api.mountIncoming();

  assert.deepEqual(
    incomingEnv.document
      .querySelectorAll('.aj-side-sec-title')
      .map((n) => n.textContent),
    ['WORKSPACE', 'CONNECT & INTELLIGENCE', 'MARKETS', 'ACCOUNT'],
  );
  assert.deepEqual(
    incomingEnv.document
      .querySelectorAll('.aj-side-item')
      .filter((n) => n.classList.contains('is-active'))
      .map((n) => n.querySelectorAll('.aj-side-item-label')[0].textContent),
    ['Community'],
  );
  assert.deepEqual(
    incomingEnv.document
      .querySelectorAll('.aj-side-sub')
      .filter((n) => n.classList.contains('is-active'))
      .map((n) => n.textContent),
    ['Feed'],
  );
});
