/**
 * Shared cross-subdomain silent transition & full-screen skeleton shell.
 *
 * Used identically by:
 *   1. Outgoing navigation (`navigateBrowserUrl` -> `window.alphajournalTransition.startOutgoing(url)`),
 *      showing an instant full-screen skeleton + persistent mobile dock before leaving the page.
 *   2. Incoming page boot (`web/index.html` -> `initHead()` & `mountIncoming()`),
 *      matching pixel coordinates, palette, dock slot selection, and surface shimmer
 *      until Flutter invokes `window.alphajournalReady()`.
 */
(function (root) {
  'use strict';

  var STYLE_ID = 'aj-transition-styles';
  var VEIL_ID = 'aj-nav-veil';
  var VALID_TOKEN_RE = /^[a-zA-Z0-9_-]{1,32}$/;
  var VALID_LABEL_RE = /^[a-zA-Z0-9 &_-]{1,28}$/;

  var THEMES = {
    dark: {
      bg: '#0D0C0B',
      surface: '#151312',
      surfaceMuted: '#1B1918',
      surfaceHover: '#232120',
      border: '#262322',
      borderStrong: '#3A3734',
      fg: '#FAFAF9',
      fgMuted: '#A8A29E',
      fgSubtle: '#78716C',
      primary: '#FAFAF9',
      primarySoft: 'rgba(250, 249, 249, 0.12)',
      primaryBorder: 'rgba(250, 249, 249, 0.30)',
      brand: '#8B9FE8',
      bullish: '#4EB57F',
      bullishSoft: 'rgba(78, 181, 127, 0.14)',
      bearish: '#D9695F',
      bearishSoft: 'rgba(217, 105, 95, 0.14)',
      dockBg: 'rgba(21, 19, 18, 0.86)',
      shimmerA: '#1B1918',
      shimmerB: '#2A2725',
      shadow: '0 12px 32px rgba(0, 0, 0, 0.45)',
    },
    light: {
      bg: '#FAFAF9',
      surface: '#FFFFFF',
      surfaceMuted: '#F5F5F4',
      surfaceHover: '#EFEEEC',
      border: '#E7E5E4',
      borderStrong: '#D6D3D1',
      fg: '#151312',
      fgMuted: '#78716C',
      fgSubtle: '#A8A29E',
      primary: '#151312',
      primarySoft: 'rgba(21, 19, 18, 0.10)',
      primaryBorder: 'rgba(21, 19, 18, 0.28)',
      brand: '#6B7FD7',
      bullish: '#237A50',
      bullishSoft: 'rgba(35, 122, 80, 0.12)',
      bearish: '#A23B35',
      bearishSoft: 'rgba(162, 59, 53, 0.12)',
      dockBg: 'rgba(255, 255, 255, 0.88)',
      shimmerA: '#EFEEEC',
      shimmerB: '#FAFAF9',
      shadow: '0 10px 28px rgba(21, 19, 18, 0.10)',
    },
  };

  var DOCKS = {
    trader: {
      centerIcon: 'grid',
      centerLabel: 'More tools',
      items: [
        { id: 'overview', label: 'Desk', icon: 'dashboard' },
        { id: 'community', label: 'Community', icon: 'feed' },
        { id: 'calculators', label: 'Calculators', icon: 'calc' },
        { id: 'settings', label: 'Settings', icon: 'settings' },
      ],
      sidebar: [
        { id: 'overview', label: 'Overview', icon: 'dashboard' },
        { id: 'journal', label: 'Journal', icon: 'journal' },
        { id: 'strategies', label: 'Strategies', icon: 'layers' },
        { id: 'notes', label: 'Notes', icon: 'doc' },
        { id: 'market', label: 'Markets', icon: 'candle' },
        { id: 'community', label: 'Community', icon: 'feed' },
        { id: 'ai_copilot', label: 'AI Copilot', icon: 'spark' },
        { id: 'messages', label: 'Messages', icon: 'chat' },
        { id: 'calculators', label: 'Calculators', icon: 'calc' },
        { id: 'settings', label: 'Settings', icon: 'settings' },
      ],
    },
    community: {
      centerIcon: 'apps',
      centerLabel: 'App',
      items: [
        { id: 'community_feed', label: 'Feed', icon: 'feed' },
        { id: 'community_explore', label: 'Explore', icon: 'compass' },
        { id: 'community_network', label: 'Network', icon: 'users' },
        { id: 'community_profile', label: 'Profile', icon: 'user' },
      ],
      sidebar: [
        { id: 'community_feed', label: 'Feed', icon: 'feed' },
        { id: 'community_explore', label: 'Explore', icon: 'compass' },
        { id: 'community_network', label: 'Network', icon: 'users' },
        { id: 'community_profile', label: 'Profile', icon: 'user' },
        { id: 'overview', label: 'Trading Desk', icon: 'dashboard' },
        { id: 'market', label: 'Markets', icon: 'candle' },
        { id: 'messages', label: 'Messages', icon: 'chat' },
        { id: 'settings', label: 'Settings', icon: 'settings' },
      ],
    },
    affiliate: {
      centerIcon: 'grid',
      centerLabel: 'More tools',
      items: [
        { id: 'overview', label: 'Hub', icon: 'dashboard' },
        { id: 'referrals', label: 'Referrals', icon: 'trend' },
        { id: 'marketing', label: 'Media Kit', icon: 'campaign' },
        { id: 'settings', label: 'Settings', icon: 'settings' },
      ],
      sidebar: [
        { id: 'overview', label: 'Partner Hub', icon: 'dashboard' },
        { id: 'referrals', label: 'Referrals', icon: 'trend' },
        { id: 'marketing', label: 'Media Kit', icon: 'campaign' },
        { id: 'payouts', label: 'Payouts', icon: 'wallet' },
        { id: 'ai_copilot', label: 'AI Assistant', icon: 'spark' },
        { id: 'messages', label: 'Messages', icon: 'chat' },
        { id: 'settings', label: 'Settings', icon: 'settings' },
      ],
    },
    admin: {
      centerIcon: 'grid',
      centerLabel: 'More tools',
      items: [
        { id: 'overview', label: 'Overview', icon: 'dashboard' },
        { id: 'org_team', label: 'Users', icon: 'users' },
        { id: 'affiliate_reviews', label: 'Affiliates', icon: 'handshake' },
        { id: 'settings', label: 'Settings', icon: 'settings' },
      ],
      sidebar: [
        { id: 'overview', label: 'Overview', icon: 'dashboard' },
        { id: 'org_team', label: 'Users', icon: 'users' },
        { id: 'affiliate_reviews', label: 'Affiliates', icon: 'handshake' },
        { id: 'org_publishing', label: 'Reviews', icon: 'layers' },
        { id: 'org_analytics', label: 'Analytics', icon: 'candle' },
        { id: 'admin_ai', label: 'AI Control', icon: 'spark' },
        { id: 'settings', label: 'Settings', icon: 'settings' },
      ],
    },
  };

  function safeStorageGet(key) {
    try {
      if (typeof window !== 'undefined' && window.localStorage) {
        return window.localStorage.getItem(key) || '';
      }
    } catch (_) {}
    return '';
  }

  function readCookie(name, cookieStr) {
    var raw = cookieStr;
    if (typeof raw !== 'string') {
      try {
        raw = (typeof document !== 'undefined' && document.cookie) || '';
      } catch (_) {
        raw = '';
      }
    }
    var prefix = name + '=';
    var parts = raw.split(';');
    for (var i = 0; i < parts.length; i++) {
      var part = parts[i].trim();
      if (part.indexOf(prefix) === 0) {
        var val = part.slice(prefix.length);
        try {
          return decodeURIComponent(val);
        } catch (_) {
          return val;
        }
      }
    }
    return '';
  }

  function readFlag(name, opts) {
    opts = opts || {};
    var fromCookie = readCookie(name, opts.cookieStr);
    if (fromCookie) return fromCookie;
    return safeStorageGet(name);
  }

  function resolveTheme(opts) {
    opts = opts || {};
    var mode = opts.themeMode || readFlag('ax_theme_mode', opts);
    var prefersLight =
      typeof opts.prefersLight === 'boolean'
        ? opts.prefersLight
        : typeof window !== 'undefined' &&
          typeof window.matchMedia === 'function' &&
          window.matchMedia('(prefers-color-scheme: light)').matches;
    var isLight = mode === 'light' || (mode === 'system' && prefersLight);
    var density = opts.density || readFlag('ax_theme_density', opts);
    return {
      mode: mode || 'dark',
      isLight: isLight,
      compact: density === 'Compact',
      palette: isLight ? THEMES.light : THEMES.dark,
    };
  }

  function inferRoleFromCookie(roleRaw) {
    if (!roleRaw || typeof roleRaw !== 'string') return '';
    var parts = roleRaw.split(':');
    var roleId = (parts[parts.length - 1] || '').trim();
    if (roleId === 'userAffiliate' || roleId === 'affiliate') return 'affiliate';
    if (roleId === 'userAdmin' || roleId === 'admin') return 'admin';
    if (roleId === 'userTrader' || roleId === 'trader') return 'trader';
    return '';
  }

  function parseSilentCookie(silentRaw) {
    if (!silentRaw || typeof silentRaw !== 'string') {
      return { hasFlag: false, surfaceKey: '', label: '' };
    }
    if (silentRaw === '1') {
      return { hasFlag: true, surfaceKey: '', label: '' };
    }
    if (silentRaw.indexOf('1|') !== 0) {
      return { hasFlag: false, surfaceKey: '', label: '' };
    }
    var rest = silentRaw.slice(2).split('|');
    if (rest.length >= 2) {
      var key = rest[0].trim();
      var lbl = rest[1].trim();
      return {
        hasFlag: true,
        surfaceKey: VALID_TOKEN_RE.test(key) ? key : '',
        label: VALID_LABEL_RE.test(lbl) ? lbl : '',
      };
    }
    var onlyLabel = rest[0].trim();
    return {
      hasFlag: true,
      surfaceKey: '',
      label: VALID_LABEL_RE.test(onlyLabel) ? onlyLabel : '',
    };
  }

  function resolveSurfaceKeyFromLocation(host, path) {
    host = (host || '').toLowerCase();
    path = (path || '').toLowerCase();
    var seg = '';
    var parts = path.split('/');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i]) {
        seg = parts[i];
        break;
      }
    }

    if (seg === 'community_explore' || seg === 'explore') {
      return 'community_explore';
    }
    if (seg === 'community_network' || seg === 'community_follow' || seg === 'network') {
      return 'community_network';
    }
    if (seg === 'community_profile' || seg === 'profile' || seg.indexOf('@') === 0) {
      return 'community_profile';
    }
    if (seg === 'community_feed') {
      return 'community_feed';
    }
    if (seg === 'market' || seg.indexOf('market_') === 0) return 'market';
    if (seg === 'journal') return 'journal';
    if (seg === 'strategies' || seg === 'strategy') return 'strategies';
    if (seg === 'notes' || seg === 'note') return 'notes';
    if (seg === 'calculators' || seg === 'calculator') return 'calculators';
    if (seg === 'messages' || seg === 'message' || seg === 'thread') return 'messages';
    if (seg === 'ai_copilot' || seg === 'ai' || seg === 'copilot') return 'ai_copilot';
    if (seg.indexOf('settings') === 0) return 'settings';
    if (seg === 'referrals') return 'referrals';
    if (seg === 'marketing') return 'marketing';
    if (seg === 'payouts') return 'payouts';
    if (seg === 'org_team') return 'org_team';
    if (seg === 'affiliate_reviews') return 'affiliate_reviews';
    if (seg.indexOf('org_') === 0 || seg.indexOf('admin') === 0) return 'admin_console';
    if (
      host.indexOf('community.') === 0 ||
      seg.indexOf('community') === 0 ||
      seg === 'p' ||
      seg === 'posts' ||
      seg === 'post'
    ) {
      return 'community_feed';
    }
    if (host.indexOf('affiliate.') === 0 || seg.indexOf('affiliate') === 0) {
      return 'partner_hub';
    }
    if (host.indexOf('admin.') === 0) return 'admin_console';
    if (host.indexOf('app.') === 0 || seg === 'workspace' || seg === 'overview') {
      return 'workspace';
    }
    return '';
  }

  function resolveSurface(opts) {
    opts = opts || {};
    var host = opts.hostname || '';
    var path = opts.pathname || '';
    if (opts.url) {
      try {
        var base =
          typeof window !== 'undefined' && window.location && window.location.origin
            ? window.location.origin
            : 'https://app.alphajournal.in';
        var parsed = new URL(opts.url, base);
        host = parsed.hostname || host;
        path = parsed.pathname || path;
      } catch (_) {}
    } else if (typeof window !== 'undefined' && window.location) {
      if (!host) host = window.location.hostname || '';
      if (!path) path = window.location.pathname || '';
    }

    var silent = parseSilentCookie(opts.silentRaw || '');
    var inferredKey = resolveSurfaceKeyFromLocation(host, path);
    var key = silent.surfaceKey || inferredKey;
    var role = opts.role || inferRoleFromCookie(opts.roleRaw || readFlag('ax_role', opts));

    // Map optional plain labels (if only label was provided in cookie)
    if (!key && silent.label) {
      var lbl = silent.label.toLowerCase();
      if (lbl === 'markets') key = 'market';
      else if (lbl === 'journal') key = 'journal';
      else if (lbl === 'strategies') key = 'strategies';
      else if (lbl === 'notes') key = 'notes';
      else if (lbl === 'messages') key = 'messages';
      else if (lbl === 'ai copilot') key = 'ai_copilot';
      else if (lbl === 'calculators') key = 'calculators';
      else if (lbl === 'settings') key = 'settings';
      else if (lbl === 'explore') key = 'community_explore';
      else if (lbl === 'network') key = 'community_network';
      else if (lbl === 'profile') key = 'community_profile';
      else if (lbl === 'community' || lbl === 'feed') key = 'community_feed';
      else if (lbl === 'partner hub') key = 'partner_hub';
      else if (lbl === 'admin console') key = 'admin_console';
      else if (lbl === 'workspace') key = 'workspace';
    }

    if (!key) {
      if (role === 'affiliate') key = 'partner_hub';
      else if (role === 'admin') key = 'admin_console';
      else key = 'workspace';
    }

    var dockVariant = 'trader';
    if (key.indexOf('community') === 0 || host.toLowerCase().indexOf('community.') === 0) {
      dockVariant = 'community';
    } else if (
      key === 'partner_hub' ||
      key === 'referrals' ||
      key === 'marketing' ||
      key === 'payouts' ||
      role === 'affiliate' ||
      host.toLowerCase().indexOf('affiliate.') === 0
    ) {
      dockVariant = 'affiliate';
    } else if (
      key === 'admin_console' ||
      key === 'org_team' ||
      key === 'affiliate_reviews' ||
      role === 'admin' ||
      host.toLowerCase().indexOf('admin.') === 0
    ) {
      dockVariant = 'admin';
    }

    var specs = {
      workspace: {
        label: 'Workspace',
        subtitle: 'Live portfolio & equity pulse',
        layoutKind: 'dashboard',
        animClass: 'aj-anim-wave',
        activeSlot: 0,
        centerActive: false,
        activeNavId: 'overview',
      },
      community_feed: {
        label: 'Community',
        subtitle: 'Trader setups & market discussions',
        layoutKind: 'feed',
        animClass: 'aj-anim-cascade',
        activeSlot: dockVariant === 'community' ? 0 : 1,
        centerActive: false,
        activeNavId: dockVariant === 'community' ? 'community_feed' : 'community',
      },
      community_explore: {
        label: 'Explore',
        subtitle: 'Discover verified setups & analysts',
        layoutKind: 'explore',
        animClass: 'aj-anim-cascade',
        activeSlot: 1,
        centerActive: false,
        activeNavId: 'community_explore',
      },
      community_network: {
        label: 'Network',
        subtitle: 'Connected traders & following feed',
        layoutKind: 'people',
        animClass: 'aj-anim-pulse',
        activeSlot: 2,
        centerActive: false,
        activeNavId: 'community_network',
      },
      community_profile: {
        label: 'Profile',
        subtitle: 'Track record & published insights',
        layoutKind: 'profile',
        animClass: 'aj-anim-breath',
        activeSlot: 3,
        centerActive: false,
        activeNavId: 'community_profile',
      },
      market: {
        label: 'Markets',
        subtitle: 'Screeners, indices & price depth',
        layoutKind: 'market',
        animClass: 'aj-anim-scan',
        activeSlot: -1,
        centerActive: true,
        activeNavId: 'market',
      },
      journal: {
        label: 'Journal',
        subtitle: 'Executions, expectancy & review log',
        layoutKind: 'journal',
        animClass: 'aj-anim-wave',
        activeSlot: -1,
        centerActive: true,
        activeNavId: 'journal',
      },
      strategies: {
        label: 'Strategies',
        subtitle: 'Playbooks, rules & backtest stats',
        layoutKind: 'grid',
        animClass: 'aj-anim-cascade',
        activeSlot: -1,
        centerActive: true,
        activeNavId: 'strategies',
      },
      notes: {
        label: 'Notes',
        subtitle: 'Linked market theses & prep briefs',
        layoutKind: 'grid',
        animClass: 'aj-anim-breath',
        activeSlot: -1,
        centerActive: true,
        activeNavId: 'notes',
      },
      calculators: {
        label: 'Calculators',
        subtitle: 'Position sizing, risk & R:R matrix',
        layoutKind: 'grid',
        animClass: 'aj-anim-wave',
        activeSlot: 2,
        centerActive: false,
        activeNavId: 'calculators',
      },
      messages: {
        label: 'Messages',
        subtitle: 'Encrypted trader threads',
        layoutKind: 'chat',
        animClass: 'aj-anim-chat',
        activeSlot: -1,
        centerActive: true,
        activeNavId: 'messages',
      },
      ai_copilot: {
        label: 'AI Copilot',
        subtitle: 'Execution review & pattern synthesis',
        layoutKind: 'chat',
        animClass: 'aj-anim-chat',
        activeSlot: -1,
        centerActive: true,
        activeNavId: 'ai_copilot',
      },
      settings: {
        label: 'Settings',
        subtitle: 'Security, appearance & preferences',
        layoutKind: 'settings',
        animClass: 'aj-anim-breath',
        activeSlot: 3,
        centerActive: false,
        activeNavId: 'settings',
      },
      partner_hub: {
        label: 'Partner Hub',
        subtitle: 'Attributed conversions & revenue',
        layoutKind: 'dashboard',
        animClass: 'aj-anim-wave',
        activeSlot: 0,
        centerActive: false,
        activeNavId: 'overview',
      },
      referrals: {
        label: 'Referrals',
        subtitle: 'Clicks, signups & attribution funnel',
        layoutKind: 'people',
        animClass: 'aj-anim-pulse',
        activeSlot: 1,
        centerActive: false,
        activeNavId: 'referrals',
      },
      marketing: {
        label: 'Media Kit',
        subtitle: 'Approved creatives & referral links',
        layoutKind: 'grid',
        animClass: 'aj-anim-cascade',
        activeSlot: 2,
        centerActive: false,
        activeNavId: 'marketing',
      },
      payouts: {
        label: 'Payouts',
        subtitle: 'Settlements & payout statements',
        layoutKind: 'dashboard',
        animClass: 'aj-anim-wave',
        activeSlot: -1,
        centerActive: true,
        activeNavId: 'payouts',
      },
      admin_console: {
        label: 'Admin Console',
        subtitle: 'Governance, telemetry & moderation',
        layoutKind: 'dashboard',
        animClass: 'aj-anim-wave',
        activeSlot: 0,
        centerActive: false,
        activeNavId: 'overview',
      },
      org_team: {
        label: 'Users',
        subtitle: 'Accounts, roles & tier access',
        layoutKind: 'people',
        animClass: 'aj-anim-pulse',
        activeSlot: 1,
        centerActive: false,
        activeNavId: 'org_team',
      },
      affiliate_reviews: {
        label: 'Affiliates',
        subtitle: 'Partner applications & reviews',
        layoutKind: 'people',
        animClass: 'aj-anim-pulse',
        activeSlot: 2,
        centerActive: false,
        activeNavId: 'affiliate_reviews',
      },
    };

    var chosen = specs[key] || specs.workspace;
    return {
      surfaceKey: key,
      label: silent.label || chosen.label,
      subtitle: chosen.subtitle,
      layoutKind: chosen.layoutKind,
      animClass: chosen.animClass,
      dockVariant: dockVariant,
      activeSlot: chosen.activeSlot,
      centerActive: chosen.centerActive,
      activeNavId: chosen.activeNavId,
    };
  }

  function applyThemeVariables(theme, doc) {
    doc = doc || (typeof document !== 'undefined' ? document : null);
    if (!doc) return;
    var rootEl = doc.documentElement;
    var p = theme.palette;
    if (rootEl) {
      if (theme.isLight) rootEl.classList.add('aj-light');
      else rootEl.classList.remove('aj-light');
      rootEl.style.colorScheme = theme.isLight ? 'light' : 'dark';
      var vars = {
        '--aj-bg': p.bg,
        '--aj-surface': p.surface,
        '--aj-surface-muted': p.surfaceMuted,
        '--aj-surface-hover': p.surfaceHover,
        '--aj-border': p.border,
        '--aj-border-strong': p.borderStrong,
        '--aj-fg': p.fg,
        '--aj-fg-muted': p.fgMuted,
        '--aj-fg-subtle': p.fgSubtle,
        '--aj-primary': p.primary,
        '--aj-primary-soft': p.primarySoft,
        '--aj-primary-border': p.primaryBorder,
        '--aj-brand': p.brand,
        '--aj-bullish': p.bullish,
        '--aj-bullish-soft': p.bullishSoft,
        '--aj-bearish': p.bearish,
        '--aj-bearish-soft': p.bearishSoft,
        '--aj-dock-bg': p.dockBg,
        '--aj-shimmer-a': p.shimmerA,
        '--aj-shimmer-b': p.shimmerB,
        '--aj-shadow': p.shadow,
        '--aj-pad': theme.compact ? '12px' : '16px',
        '--aj-gap': theme.compact ? '10px' : '14px',
      };
      for (var k in vars) {
        if (Object.prototype.hasOwnProperty.call(vars, k)) {
          rootEl.style.setProperty(k, vars[k]);
        }
      }
    }
    if (doc.body) {
      doc.body.style.backgroundColor = p.bg;
    }
    if (typeof doc.querySelector === 'function') {
      var metas = doc.querySelectorAll('meta[name="theme-color"]');
      for (var i = 0; i < metas.length; i++) {
        metas[i].setAttribute('content', p.bg);
      }
    }
  }

  function ensureStyles(doc) {
    doc = doc || (typeof document !== 'undefined' ? document : null);
    if (!doc || doc.getElementById(STYLE_ID)) return;
    var style = doc.createElement('style');
    style.id = STYLE_ID;
    style.textContent = [
      '.aj-trans-host{position:fixed;inset:0;display:flex;background:var(--aj-bg);color:var(--aj-fg);font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;pointer-events:auto;overflow:hidden;-webkit-font-smoothing:antialiased;}',
      '.aj-progress-bar{position:fixed;top:0;left:0;right:0;height:2px;z-index:10;background:linear-gradient(90deg,transparent 0%,var(--aj-brand) 50%,transparent 100%);background-size:42% 100%;background-repeat:no-repeat;animation:aj-top-beam 1.05s cubic-bezier(.4,0,.2,1) infinite;}',
      '@keyframes aj-top-beam{0%{background-position:-45% 0}100%{background-position:145% 0}}',
      '.aj-sidebar{display:none;flex-direction:column;width:72px;flex-shrink:0;background:var(--aj-bg);border-right:1px solid var(--aj-border);padding:14px 10px;gap:14px;}',
      '@media(min-width:1024px){.aj-sidebar{width:244px;padding:16px 14px;}}',
      '@media(min-width:768px){.aj-sidebar{display:flex;}}',
      '.aj-side-head{display:flex;align-items:center;gap:10px;padding:4px 6px;}',
      '.aj-logo-badge{width:30px;height:30px;border-radius:8px;background:var(--aj-primary);color:var(--aj-bg);display:grid;place-items:center;font-weight:800;font-size:13px;letter-spacing:-.02em;flex-shrink:0;}',
      '.aj-side-brand{display:none;flex-direction:column;gap:5px;min-width:0;flex:1;}',
      '@media(min-width:1024px){.aj-side-brand{display:flex;}}',
      '.aj-side-nav{display:flex;flex-direction:column;gap:4px;flex:1;overflow:hidden;padding-top:4px;}',
      '.aj-side-item{display:flex;align-items:center;justify-content:center;gap:10px;height:38px;border-radius:10px;padding:0 10px;color:var(--aj-fg-muted);font-size:13px;font-weight:500;white-space:nowrap;}',
      '@media(min-width:1024px){.aj-side-item{justify-content:flex-start;}}',
      '.aj-side-item.is-active{background:var(--aj-surface);color:var(--aj-fg);border:1px solid var(--aj-border);font-weight:600;}',
      '.aj-side-item-label{display:none;}',
      '@media(min-width:1024px){.aj-side-item-label{display:inline;}}',
      '.aj-side-foot{display:none;padding:12px;border-radius:12px;background:var(--aj-surface);border:1px solid var(--aj-border);flex-direction:column;gap:8px;}',
      '@media(min-width:1024px){.aj-side-foot{display:flex;}}',
      '.aj-workspace{flex:1;min-width:0;display:flex;flex-direction:column;height:100%;overflow:hidden;}',
      '.aj-topbar{height:56px;flex-shrink:0;display:flex;align-items:center;justify-content:space-between;padding:0 var(--aj-pad);border-bottom:1px solid var(--aj-border);background:var(--aj-bg);gap:12px;}',
      '.aj-top-left{display:flex;align-items:center;gap:10px;min-width:0;}',
      '.aj-top-title-wrap{display:flex;flex-direction:column;gap:2px;min-width:0;}',
      '.aj-top-title-row{display:flex;align-items:center;gap:8px;}',
      '.aj-top-title{font-size:15px;font-weight:600;letter-spacing:-.01em;color:var(--aj-fg);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}',
      '.aj-live-dot{width:7px;height:7px;border-radius:50%;background:var(--aj-brand);box-shadow:0 0 0 3px rgba(139,159,232,0.18);animation:aj-dot-pulse 1.4s ease-in-out infinite;flex-shrink:0;}',
      '@keyframes aj-dot-pulse{0%,100%{transform:scale(.85);opacity:.6}50%{transform:scale(1.1);opacity:1}}',
      '.aj-top-sub{font-size:11px;color:var(--aj-fg-muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}',
      '.aj-top-right{display:flex;align-items:center;gap:8px;flex-shrink:0;}',
      '.aj-search-stub{display:none;align-items:center;gap:8px;width:220px;height:34px;padding:0 12px;border-radius:10px;background:var(--aj-surface);border:1px solid var(--aj-border);}',
      '@media(min-width:768px){.aj-search-stub{display:flex;}}',
      '.aj-icon-btn{width:34px;height:34px;border-radius:10px;background:var(--aj-surface);border:1px solid var(--aj-border);display:grid;place-items:center;color:var(--aj-fg-muted);}',
      '.aj-avatar-stub{width:32px;height:32px;border-radius:50%;background:var(--aj-surface-muted);border:1px solid var(--aj-border);}',
      '.aj-scroll{flex:1;overflow:hidden;padding:var(--aj-pad);padding-bottom:92px;}',
      '@media(min-width:768px){.aj-scroll{padding:20px 24px 28px;}}',
      '.aj-container{max-width:1180px;margin:0 auto;display:flex;flex-direction:column;gap:var(--aj-gap);}',
      '.aj-card{background:var(--aj-surface);border:1px solid var(--aj-border);border-radius:14px;padding:var(--aj-pad);display:flex;flex-direction:column;gap:12px;animation-delay:calc(var(--stagger,0) * 55ms);}',
      '.aj-sk{position:relative;overflow:hidden;background:var(--aj-shimmer-a);border-radius:8px;flex-shrink:0;}',
      '.aj-sk-circle{border-radius:999px;}',
      '.aj-sk-pill{border-radius:999px;height:28px;}',
      '.aj-sk::after{content:"";position:absolute;inset:0;transform:translateX(-100%);background:linear-gradient(105deg,transparent 0%,var(--aj-shimmer-b) 48%,transparent 100%);}',
      /* Animation 1: Wave sweep (Dashboard, Journal, Calculators) */
      '.aj-anim-wave .aj-sk::after{animation:aj-sweep 1.3s cubic-bezier(.4,0,.2,1) infinite;animation-delay:calc(var(--stagger,0) * 70ms);}',
      /* Animation 2: Cascade rise + diagonal sweep (Community Feed, Explore, Strategies, Media Kit) */
      '.aj-anim-cascade .aj-card{animation:aj-rise .38s cubic-bezier(.22,1,.36,1) both;animation-delay:calc(var(--stagger,0) * 55ms);}',
      '.aj-anim-cascade .aj-sk::after{animation:aj-sweep 1.25s cubic-bezier(.4,0,.2,1) infinite;animation-delay:calc(var(--stagger,0) * 80ms);}',
      /* Animation 3: Market candlestick scan (Markets) */
      '.aj-anim-scan .aj-sk::after{animation:aj-sweep 1.05s linear infinite;}',
      '.aj-anim-scan .aj-candle-bar{animation:aj-candle-breathe 1.3s ease-in-out infinite alternate;animation-delay:calc(var(--stagger,0) * 65ms);}',
      /* Animation 4: Pulse rhythm (People, Referrals, Users) */
      '.aj-anim-pulse .aj-sk::after{display:none;}',
      '.aj-anim-pulse .aj-sk{animation:aj-pulse-block 1.35s ease-in-out infinite alternate;animation-delay:calc(var(--stagger,0) * 85ms);}',
      /* Animation 5: Calm ambient breath (Settings, Profile, Notes) */
      '.aj-anim-breath .aj-sk::after{animation:aj-sweep 1.9s ease-in-out infinite;}',
      '.aj-anim-breath .aj-card{animation:aj-pulse-soft 2.0s ease-in-out infinite alternate;animation-delay:calc(var(--stagger,0) * 90ms);}',
      /* Animation 6: Chat bubbles + typing dots (AI Copilot, Messages) */
      '.aj-anim-chat .aj-chat-bubble{animation:aj-rise .34s cubic-bezier(.22,1,.36,1) both;animation-delay:calc(var(--stagger,0) * 75ms);}',
      '.aj-anim-chat .aj-sk::after{animation:aj-sweep 1.4s ease-in-out infinite;}',
      '@keyframes aj-sweep{0%{transform:translateX(-100%)}100%{transform:translateX(120%)}}',
      '@keyframes aj-rise{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:none}}',
      '@keyframes aj-pulse-block{from{opacity:.48}to{opacity:.96}}',
      '@keyframes aj-pulse-soft{from{opacity:.76}to{opacity:1}}',
      '@keyframes aj-candle-breathe{from{transform:scaleY(.88);opacity:.65}to{transform:scaleY(1.04);opacity:1}}',
      /* Responsive skeleton grids */
      '.aj-row{display:flex;align-items:center;gap:10px;}',
      '.aj-row-between{display:flex;align-items:center;justify-content:space-between;gap:10px;}',
      '.aj-col{display:flex;flex-direction:column;gap:8px;min-width:0;}',
      '.aj-chips{display:flex;align-items:center;gap:8px;overflow:hidden;flex-wrap:nowrap;}',
      '.aj-kpi-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:var(--aj-gap);}',
      '@media(min-width:900px){.aj-kpi-grid{grid-template-columns:repeat(4,minmax(0,1fr));}}',
      '.aj-bento{display:grid;grid-template-columns:1fr;gap:var(--aj-gap);}',
      '@media(min-width:960px){.aj-bento{grid-template-columns:minmax(0,2fr) minmax(0,1fr);}}',
      '.aj-cards-2{display:grid;grid-template-columns:1fr;gap:var(--aj-gap);}',
      '@media(min-width:768px){.aj-cards-2{grid-template-columns:repeat(2,minmax(0,1fr));}}',
      '.aj-cards-3{display:grid;grid-template-columns:1fr;gap:var(--aj-gap);}',
      '@media(min-width:768px){.aj-cards-3{grid-template-columns:repeat(2,minmax(0,1fr));}}',
      '@media(min-width:1120px){.aj-cards-3{grid-template-columns:repeat(3,minmax(0,1fr));}}',
      '.aj-feed-grid{display:grid;grid-template-columns:1fr;gap:var(--aj-gap);}',
      '@media(min-width:1024px){.aj-feed-grid{grid-template-columns:minmax(0,1.7fr) minmax(260px,.9fr);}}',
      '.aj-delta-up{padding:3px 8px;border-radius:999px;background:var(--aj-bullish-soft);color:var(--aj-bullish);font-size:11px;font-weight:600;}',
      '.aj-delta-dn{padding:3px 8px;border-radius:999px;background:var(--aj-bearish-soft);color:var(--aj-bearish);font-size:11px;font-weight:600;}',
      '.aj-donut-ring{width:132px;height:132px;border-radius:50%;margin:8px auto;background:conic-gradient(var(--aj-brand) 0 38%,var(--aj-bullish) 38% 68%,var(--aj-border-strong) 68% 100%);display:grid;place-items:center;}',
      '.aj-donut-hole{width:84px;height:84px;border-radius:50%;background:var(--aj-surface);}',
      '.aj-candles{height:176px;display:flex;align-items:flex-end;justify-content:space-between;gap:8px;padding:12px 6px 4px;}',
      '.aj-candle-col{flex:1;height:100%;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;gap:4px;}',
      '.aj-candle-wick{width:2px;flex:1;max-height:24px;border-radius:2px;background:var(--aj-border-strong);}',
      '.aj-candle-bar{width:100%;max-width:18px;border-radius:4px;transform-origin:bottom center;}',
      '.aj-heatmap{display:grid;grid-template-columns:repeat(7,minmax(0,1fr));gap:6px;}',
      '.aj-heat-cell{height:24px;border-radius:6px;background:var(--aj-shimmer-a);}',
      '.aj-chat-stack{display:flex;flex-direction:column;gap:14px;max-width:820px;width:100%;margin:0 auto;}',
      '.aj-chat-bubble{padding:14px 16px;border-radius:16px;border:1px solid var(--aj-border);background:var(--aj-surface);display:flex;flex-direction:column;gap:8px;max-width:84%;}',
      '.aj-chat-bubble.is-user{align-self:flex-end;background:var(--aj-surface-muted);}',
      '.aj-typing-dots{display:inline-flex;gap:5px;padding:4px 0;}',
      '.aj-typing-dots i{width:6px;height:6px;border-radius:50%;background:var(--aj-brand);animation:aj-dot-pulse 1.1s ease-in-out infinite;}',
      '.aj-typing-dots i:nth-child(2){animation-delay:.18s;}',
      '.aj-typing-dots i:nth-child(3){animation-delay:.36s;}',
      /* Persistent Mobile Bottom Floating Dock (matches QuietDockScaffold 56px + 16px margin) */
      '.aj-dock-wrap{position:fixed;left:16px;right:16px;bottom:calc(16px + env(safe-area-inset-bottom,0px));z-index:20;display:flex;justify-content:center;pointer-events:none;}',
      '@media(min-width:768px){.aj-dock-wrap{display:none;}}',
      '.aj-dock{width:100%;max-width:440px;height:56px;padding:4px 6px;border-radius:28px;background:var(--aj-dock-bg);backdrop-filter:blur(20px) saturate(1.4);-webkit-backdrop-filter:blur(20px) saturate(1.4);border:1px solid var(--aj-border);box-shadow:var(--aj-shadow);display:grid;grid-template-columns:1fr 1fr 48px 1fr 1fr;align-items:center;gap:4px;}',
      '.aj-dock-item{height:46px;border-radius:22px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px;color:var(--aj-fg-muted);font-size:10px;font-weight:500;letter-spacing:.01em;border:1px solid transparent;transition:background-color .16s ease,color .16s ease,border-color .16s ease;}',
      '.aj-dock-item.is-active{background:var(--aj-primary-soft);border-color:var(--aj-primary-border);color:var(--aj-primary);font-weight:600;}',
      '.aj-dock-center{width:42px;height:42px;margin:0 auto;border-radius:21px;background:var(--aj-surface-muted);border:1px solid var(--aj-border);display:grid;place-items:center;color:var(--aj-fg-muted);}',
      '.aj-dock-center.is-active{background:var(--aj-primary-soft);border-color:var(--aj-primary-border);color:var(--aj-primary);}',
      '.aj-dock-label{max-width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;padding:0 2px;line-height:1.1;}',
      /* Veil animations */
      '#' + VEIL_ID + '{z-index:2147483647;animation:aj-veil-in .14s cubic-bezier(.22,1,.36,1) both;}',
      '@keyframes aj-veil-in{from{opacity:0}to{opacity:1}}',
      '@media(prefers-reduced-motion:reduce){.aj-progress-bar,.aj-live-dot,.aj-sk::after,.aj-sk,.aj-card,.aj-candle-bar,.aj-chat-bubble,.aj-typing-dots i,#' + VEIL_ID + '{animation:none !important;transition:none !important;}}',
    ].join('\n');
    (doc.head || doc.documentElement).appendChild(style);
  }

  function svgIcon(doc, name, size) {
    size = size || 20;
    var ns = 'http://www.w3.org/2000/svg';
    var svg = doc.createElementNS(ns, 'svg');
    svg.setAttribute('width', String(size));
    svg.setAttribute('height', String(size));
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('stroke', 'currentColor');
    svg.setAttribute('stroke-width', '1.85');
    svg.setAttribute('stroke-linecap', 'round');
    svg.setAttribute('stroke-linejoin', 'round');
    svg.setAttribute('aria-hidden', 'true');

    var paths = {
      dashboard: [
        'M4 5a1 1 0 0 1 1-1h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5Z',
        'M13 5a1 1 0 0 1 1-1h5a1 1 0 0 1 1 1v3a1 1 0 0 1-1 1h-5a1 1 0 0 1-1-1V5Z',
        'M13 13a1 1 0 0 1 1-1h5a1 1 0 0 1 1 1v6a1 1 0 0 1-1 1h-5a1 1 0 0 1-1-1v-6Z',
        'M4 15a1 1 0 0 1 1-1h5a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-4Z',
      ],
      feed: [
        'M4 5h16M4 11h16M4 17h10',
      ],
      compass: [
        'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Z',
        'M15.2 8.8l-2 5.2-5.2 2 2-5.2 5.2-2Z',
      ],
      users: [
        'M16 19v-1a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v1',
        'M9.5 10a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Z',
        'M21 19v-1a3.5 3.5 0 0 0-2.6-3.4',
        'M16.5 3.3a3.5 3.5 0 0 1 0 6.7',
      ],
      user: [
        'M19 20v-1.5A4.5 4.5 0 0 0 14.5 14h-5A4.5 4.5 0 0 0 5 18.5V20',
        'M12 10.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Z',
      ],
      calc: [
        'M6 3h12a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Z',
        'M8 7h8M8 12h2M12 12h2M16 12h0M8 16h2M12 16h2M16 16h0',
      ],
      settings: [
        'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z',
        'M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09a1.65 1.65 0 0 0-1-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09a1.65 1.65 0 0 0 1.51-1 1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1Z',
      ],
      grid: [
        'M4 5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5Z',
        'M14 5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1h-4a1 1 0 0 1-1-1V5Z',
        'M4 15a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-4Z',
        'M14 15a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1h-4a1 1 0 0 1-1-1v-4Z',
      ],
      apps: [
        'M5 5h2v2H5zM11 5h2v2h-2zM17 5h2v2h-2zM5 11h2v2H5zM11 11h2v2h-2zM17 11h2v2h-2zM5 17h2v2H5zM11 17h2v2h-2zM17 17h2v2h-2z',
      ],
      journal: [
        'M5 4h11a2 2 0 0 1 2 2v13a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1Z',
        'M8 8h6M8 12h6M8 16h4',
      ],
      layers: [
        'M12 3l8 4.5-8 4.5-8-4.5L12 3Z',
        'M4 12l8 4.5 8-4.5',
        'M4 16.5l8 4.5 8-4.5',
      ],
      doc: [
        'M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8l-5-5Z',
        'M14 3v5h5M9 13h6M9 17h4',
      ],
      candle: [
        'M6 5v14M6 9h0M4 9h4v6H4V9Z',
        'M12 3v18M10 7h4v8h-4V7Z',
        'M18 6v12M16 10h4v5h-4v-5Z',
      ],
      spark: [
        'M12 3l1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9L12 3Z',
      ],
      chat: [
        'M5 6h14a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H9l-4 3v-3H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2Z',
      ],
      trend: [
        'M3 17l6-6 4 4 8-8',
        'M15 7h6v6',
      ],
      campaign: [
        'M3 11v2a2 2 0 0 0 2 2h2l5 4V5L7 9H5a2 2 0 0 0-2 2Z',
        'M16 9a5 5 0 0 1 0 6',
      ],
      wallet: [
        'M4 7a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V7Z',
        'M16 12h4',
      ],
      handshake: [
        'M7 11l5-5 5 5',
        'M4 14l4 4 4-3 4 3 4-4',
      ],
      search: [
        'M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16Z',
        'M21 21l-4.3-4.3',
      ],
      bell: [
        'M18 8a6 6 0 1 0-12 0c0 7-3 8-3 8h18s-3-1-3-8',
        'M13.7 20a2 2 0 0 1-3.4 0',
      ],
    };

    var list = paths[name] || paths.dashboard;
    for (var i = 0; i < list.length; i++) {
      var p = doc.createElementNS(ns, 'path');
      p.setAttribute('d', list[i]);
      svg.appendChild(p);
    }
    return svg;
  }

  function el(doc, tag, className, styleCss) {
    var node = doc.createElement(tag);
    if (className) node.className = className;
    if (styleCss) node.style.cssText = styleCss;
    return node;
  }

  function sk(doc, w, h, extraClass, stagger) {
    var cls = 'aj-sk' + (extraClass ? ' ' + extraClass : '');
    var node = el(doc, 'div', cls, 'width:' + w + ';height:' + h + ';');
    if (typeof stagger === 'number') {
      node.style.setProperty('--stagger', String(stagger));
    }
    return node;
  }

  function card(doc, stagger) {
    var c = el(doc, 'div', 'aj-card');
    if (typeof stagger === 'number') {
      c.style.setProperty('--stagger', String(stagger));
    }
    return c;
  }

  function buildDashboardBody(doc, spec) {
    var frag = doc.createDocumentFragment();

    // Chip filter bar + timeframe toggle
    var bar = el(doc, 'div', 'aj-row-between');
    var leftChips = el(doc, 'div', 'aj-chips');
    leftChips.appendChild(sk(doc, '86px', '30px', 'aj-sk-pill', 0));
    leftChips.appendChild(sk(doc, '74px', '30px', 'aj-sk-pill', 1));
    leftChips.appendChild(sk(doc, '92px', '30px', 'aj-sk-pill', 2));
    bar.appendChild(leftChips);
    bar.appendChild(sk(doc, '112px', '30px', 'aj-sk-pill', 2));
    frag.appendChild(bar);

    // 4 KPI Metric Cards
    var kpis = el(doc, 'div', 'aj-kpi-grid');
    var kpiLabels = [
      { w: '56%', valW: '72%', up: true, text: '+4.8%' },
      { w: '62%', valW: '64%', up: true, text: '68.4%' },
      { w: '48%', valW: '58%', up: false, text: '-1.2%' },
      { w: '66%', valW: '76%', up: true, text: '+12.1%' },
    ];
    for (var i = 0; i < 4; i++) {
      var k = card(doc, i);
      var kTop = el(doc, 'div', 'aj-row-between');
      kTop.appendChild(sk(doc, kpiLabels[i].w, '11px', '', i));
      var badge = el(doc, 'span', kpiLabels[i].up ? 'aj-delta-up' : 'aj-delta-dn');
      badge.textContent = kpiLabels[i].text;
      kTop.appendChild(badge);
      k.appendChild(kTop);
      k.appendChild(sk(doc, kpiLabels[i].valW, '24px', '', i + 1));
      k.appendChild(sk(doc, '100%', '18px', '', i + 2));
      kpis.appendChild(k);
    }
    frag.appendChild(kpis);

    // Bento row: Area Chart + Donut Ring
    var bento = el(doc, 'div', 'aj-bento');
    var chartCard = card(doc, 3);
    var chHead = el(doc, 'div', 'aj-row-between');
    var chTitle = el(doc, 'div', 'aj-col');
    chTitle.appendChild(sk(doc, '140px', '14px', '', 3));
    chTitle.appendChild(sk(doc, '96px', '22px', '', 4));
    chHead.appendChild(chTitle);
    chHead.appendChild(sk(doc, '124px', '28px', 'aj-sk-pill', 4));
    chartCard.appendChild(chHead);
    chartCard.appendChild(sk(doc, '100%', '168px', '', 4));
    bento.appendChild(chartCard);

    var sideCard = card(doc, 4);
    sideCard.appendChild(sk(doc, '132px', '14px', '', 4));
    var ring = el(doc, 'div', 'aj-donut-ring');
    ring.appendChild(el(doc, 'div', 'aj-donut-hole'));
    sideCard.appendChild(ring);
    sideCard.appendChild(sk(doc, '100%', '12px', '', 5));
    sideCard.appendChild(sk(doc, '82%', '12px', '', 6));
    bento.appendChild(sideCard);
    frag.appendChild(bento);

    // Activity table skeleton
    var tbl = card(doc, 5);
    tbl.appendChild(sk(doc, '168px', '14px', '', 5));
    for (var r = 0; r < 3; r++) {
      var row = el(doc, 'div', 'aj-row-between');
      var rl = el(doc, 'div', 'aj-row');
      rl.appendChild(sk(doc, '28px', '28px', 'aj-sk-circle', 5 + r));
      rl.appendChild(sk(doc, '118px', '13px', '', 5 + r));
      row.appendChild(rl);
      row.appendChild(sk(doc, '74px', '22px', 'aj-sk-pill', 6 + r));
      tbl.appendChild(row);
    }
    frag.appendChild(tbl);
    return frag;
  }

  function buildMarketBody(doc) {
    var frag = doc.createDocumentFragment();

    // Live ticker strip
    var ticker = el(doc, 'div', 'aj-kpi-grid');
    var upFlags = [true, true, false, true];
    for (var t = 0; t < 4; t++) {
      var tc = card(doc, t);
      var tr = el(doc, 'div', 'aj-row-between');
      tr.appendChild(sk(doc, '54px', '13px', '', t));
      var d = el(doc, 'span', upFlags[t] ? 'aj-delta-up' : 'aj-delta-dn');
      d.textContent = upFlags[t] ? '+1.8%' : '-0.6%';
      tr.appendChild(d);
      tc.appendChild(tr);
      tc.appendChild(sk(doc, '78%', '20px', '', t + 1));
      ticker.appendChild(tc);
    }
    frag.appendChild(ticker);

    // Candlestick chart card
    var candleCard = card(doc, 2);
    var head = el(doc, 'div', 'aj-row-between');
    head.appendChild(sk(doc, '156px', '18px', '', 2));
    head.appendChild(sk(doc, '140px', '28px', 'aj-sk-pill', 2));
    candleCard.appendChild(head);

    var plot = el(doc, 'div', 'aj-candles');
    var heights = [48, 72, 60, 88, 96, 68, 78, 108, 92, 118, 84, 126];
    var bull = [true, true, false, true, true, false, true, true, false, true, false, true];
    for (var c = 0; c < heights.length; c++) {
      var col = el(doc, 'div', 'aj-candle-col');
      col.appendChild(el(doc, 'div', 'aj-candle-wick'));
      var bar = el(
        doc,
        'div',
        'aj-candle-bar',
        'height:' + heights[c] + 'px;background:' + (bull[c] ? 'var(--aj-bullish)' : 'var(--aj-bearish)') + ';opacity:.72;'
      );
      bar.style.setProperty('--stagger', String(c));
      col.appendChild(bar);
      col.appendChild(el(doc, 'div', 'aj-candle-wick'));
      plot.appendChild(col);
    }
    candleCard.appendChild(plot);
    frag.appendChild(candleCard);

    // Screener list rows
    var listCard = card(doc, 4);
    for (var r = 0; r < 4; r++) {
      var row = el(doc, 'div', 'aj-row-between');
      var left = el(doc, 'div', 'aj-row');
      left.appendChild(sk(doc, '32px', '32px', 'aj-sk-circle', r + 2));
      var tx = el(doc, 'div', 'aj-col');
      tx.appendChild(sk(doc, '82px', '13px', '', r + 2));
      tx.appendChild(sk(doc, '124px', '10px', '', r + 3));
      left.appendChild(tx);
      row.appendChild(left);
      row.appendChild(sk(doc, '68px', '24px', 'aj-sk-pill', r + 3));
      listCard.appendChild(row);
    }
    frag.appendChild(listCard);
    return frag;
  }

  function buildFeedBody(doc) {
    var frag = doc.createDocumentFragment();

    // Topic chips
    var chips = el(doc, 'div', 'aj-chips');
    var chipWidths = ['68px', '84px', '76px', '92px', '68px'];
    for (var ci = 0; ci < chipWidths.length; ci++) {
      chips.appendChild(sk(doc, chipWidths[ci], '30px', 'aj-sk-pill', ci));
    }
    frag.appendChild(chips);

    var grid = el(doc, 'div', 'aj-feed-grid');
    var stream = el(doc, 'div', 'aj-col', 'gap:var(--aj-gap);');
    for (var p = 0; p < 3; p++) {
      var post = card(doc, p);
      var author = el(doc, 'div', 'aj-row');
      author.appendChild(sk(doc, '38px', '38px', 'aj-sk-circle', p));
      var meta = el(doc, 'div', 'aj-col');
      meta.appendChild(sk(doc, '128px', '13px', '', p));
      meta.appendChild(sk(doc, '78px', '10px', '', p + 1));
      author.appendChild(meta);
      post.appendChild(author);

      post.appendChild(sk(doc, '96%', '12px', '', p + 1));
      post.appendChild(sk(doc, p % 2 === 0 ? '82%' : '90%', '12px', '', p + 2));
      if (p < 2) {
        post.appendChild(sk(doc, '100%', '156px', '', p + 2));
      }
      var footer = el(doc, 'div', 'aj-chips');
      footer.appendChild(sk(doc, '58px', '24px', 'aj-sk-pill', p + 3));
      footer.appendChild(sk(doc, '58px', '24px', 'aj-sk-pill', p + 3));
      footer.appendChild(sk(doc, '58px', '24px', 'aj-sk-pill', p + 4));
      post.appendChild(footer);
      stream.appendChild(post);
    }
    grid.appendChild(stream);

    // Desktop discovery rail
    var rail = card(doc, 2);
    rail.appendChild(sk(doc, '130px', '14px', '', 2));
    for (var t = 0; t < 4; t++) {
      var tr = el(doc, 'div', 'aj-row');
      tr.appendChild(sk(doc, '30px', '30px', 'aj-sk-circle', t + 2));
      var col = el(doc, 'div', 'aj-col', 'flex:1;');
      col.appendChild(sk(doc, '72%', '12px', '', t + 2));
      col.appendChild(sk(doc, '48%', '10px', '', t + 3));
      tr.appendChild(col);
      rail.appendChild(tr);
    }
    grid.appendChild(rail);
    frag.appendChild(grid);
    return frag;
  }

  function buildExploreBody(doc) {
    var frag = doc.createDocumentFragment();
    frag.appendChild(sk(doc, '100%', '42px', 'aj-sk-pill', 0));
    var chips = el(doc, 'div', 'aj-chips');
    for (var ci = 0; ci < 4; ci++) {
      chips.appendChild(sk(doc, (72 + ci * 12) + 'px', '28px', 'aj-sk-pill', ci));
    }
    frag.appendChild(chips);

    var cards = el(doc, 'div', 'aj-cards-3');
    for (var i = 0; i < 6; i++) {
      var c = card(doc, i);
      c.appendChild(sk(doc, '100%', i % 2 === 0 ? '132px' : '104px', '', i));
      c.appendChild(sk(doc, '78%', '14px', '', i + 1));
      c.appendChild(sk(doc, '54%', '11px', '', i + 2));
      cards.appendChild(c);
    }
    frag.appendChild(cards);
    return frag;
  }

  function buildPeopleBody(doc) {
    var frag = doc.createDocumentFragment();
    var bar = el(doc, 'div', 'aj-row-between');
    bar.appendChild(sk(doc, '65%', '38px', 'aj-sk-pill', 0));
    bar.appendChild(sk(doc, '94px', '38px', 'aj-sk-pill', 1));
    frag.appendChild(bar);

    var cards = el(doc, 'div', 'aj-cards-2');
    for (var i = 0; i < 6; i++) {
      var c = card(doc, i);
      var row = el(doc, 'div', 'aj-row-between');
      var left = el(doc, 'div', 'aj-row');
      left.appendChild(sk(doc, '42px', '42px', 'aj-sk-circle', i));
      var meta = el(doc, 'div', 'aj-col');
      meta.appendChild(sk(doc, '118px', '14px', '', i));
      meta.appendChild(sk(doc, '86px', '11px', '', i + 1));
      left.appendChild(meta);
      row.appendChild(left);
      row.appendChild(sk(doc, '74px', '30px', 'aj-sk-pill', i + 2));
      c.appendChild(row);
      var tags = el(doc, 'div', 'aj-chips');
      tags.appendChild(sk(doc, '62px', '22px', 'aj-sk-pill', i + 2));
      tags.appendChild(sk(doc, '76px', '22px', 'aj-sk-pill', i + 3));
      c.appendChild(tags);
      cards.appendChild(c);
    }
    frag.appendChild(cards);
    return frag;
  }

  function buildProfileBody(doc) {
    var frag = doc.createDocumentFragment();
    var hero = card(doc, 0);
    hero.appendChild(sk(doc, '100%', '88px', '', 0));
    var top = el(doc, 'div', 'aj-row-between');
    var id = el(doc, 'div', 'aj-row');
    id.appendChild(sk(doc, '58px', '58px', 'aj-sk-circle', 1));
    var names = el(doc, 'div', 'aj-col');
    names.appendChild(sk(doc, '142px', '16px', '', 1));
    names.appendChild(sk(doc, '96px', '12px', '', 2));
    id.appendChild(names);
    top.appendChild(id);
    top.appendChild(sk(doc, '88px', '34px', 'aj-sk-pill', 2));
    hero.appendChild(top);
    hero.appendChild(sk(doc, '88%', '12px', '', 3));
    frag.appendChild(hero);

    var stats = el(doc, 'div', 'aj-cards-2');
    for (var s = 0; s < 4; s++) {
      var sc = card(doc, s + 2);
      sc.appendChild(sk(doc, '52%', '12px', '', s + 2));
      sc.appendChild(sk(doc, '74%', '18px', '', s + 3));
      sc.appendChild(sk(doc, '92%', '12px', '', s + 4));
      stats.appendChild(sc);
    }
    frag.appendChild(stats);
    return frag;
  }

  function buildJournalGridBody(doc, spec) {
    var frag = doc.createDocumentFragment();

    // Top summary + activity heatmap for Journal
    if (spec.surfaceKey === 'journal') {
      var hmCard = card(doc, 0);
      var hmHead = el(doc, 'div', 'aj-row-between');
      hmHead.appendChild(sk(doc, '144px', '15px', '', 0));
      hmHead.appendChild(sk(doc, '88px', '26px', 'aj-sk-pill', 1));
      hmCard.appendChild(hmHead);
      var hm = el(doc, 'div', 'aj-heatmap');
      for (var cell = 0; cell < 14; cell++) {
        var box = el(
          doc,
          'div',
          'aj-heat-cell',
          cell % 5 === 0
            ? 'background:var(--aj-bullish-soft);'
            : cell % 7 === 0
              ? 'background:var(--aj-bearish-soft);'
              : ''
        );
        hm.appendChild(box);
      }
      hmCard.appendChild(hm);
      frag.appendChild(hmCard);
    } else {
      var bar = el(doc, 'div', 'aj-row-between');
      bar.appendChild(sk(doc, '180px', '34px', 'aj-sk-pill', 0));
      bar.appendChild(sk(doc, '104px', '34px', 'aj-sk-pill', 1));
      frag.appendChild(bar);
    }

    var cards = el(doc, 'div', 'aj-cards-2');
    for (var i = 0; i < 4; i++) {
      var c = card(doc, i + 1);
      var head = el(doc, 'div', 'aj-row-between');
      head.appendChild(sk(doc, '112px', '15px', '', i + 1));
      head.appendChild(sk(doc, '64px', '22px', 'aj-sk-pill', i + 2));
      c.appendChild(head);
      c.appendChild(sk(doc, '94%', '12px', '', i + 2));
      c.appendChild(sk(doc, '78%', '12px', '', i + 3));
      c.appendChild(sk(doc, '100%', '64px', '', i + 3));
      cards.appendChild(c);
    }
    frag.appendChild(cards);
    return frag;
  }

  function buildChatBody(doc) {
    var frag = doc.createDocumentFragment();
    var stack = el(doc, 'div', 'aj-chat-stack');

    var b1 = el(doc, 'div', 'aj-chat-bubble');
    b1.style.setProperty('--stagger', '0');
    b1.appendChild(sk(doc, '120px', '12px', '', 0));
    b1.appendChild(sk(doc, '260px', '13px', '', 1));
    b1.appendChild(sk(doc, '210px', '13px', '', 2));
    stack.appendChild(b1);

    var b2 = el(doc, 'div', 'aj-chat-bubble is-user');
    b2.style.setProperty('--stagger', '1');
    b2.appendChild(sk(doc, '180px', '14px', '', 2));
    stack.appendChild(b2);

    var b3 = el(doc, 'div', 'aj-chat-bubble');
    b3.style.setProperty('--stagger', '2');
    var dots = el(doc, 'div', 'aj-typing-dots');
    dots.appendChild(doc.createElement('i'));
    dots.appendChild(doc.createElement('i'));
    dots.appendChild(doc.createElement('i'));
    b3.appendChild(dots);
    b3.appendChild(sk(doc, '290px', '13px', '', 3));
    b3.appendChild(sk(doc, '240px', '13px', '', 4));
    b3.appendChild(sk(doc, '160px', '13px', '', 5));
    stack.appendChild(b3);

    stack.appendChild(sk(doc, '100%', '46px', 'aj-sk-pill', 4));
    frag.appendChild(stack);
    return frag;
  }

  function buildSettingsBody(doc) {
    var frag = doc.createDocumentFragment();
    for (var g = 0; g < 2; g++) {
      var grp = card(doc, g);
      grp.appendChild(sk(doc, '140px', '14px', '', g));
      for (var r = 0; r < 3; r++) {
        var row = el(doc, 'div', 'aj-row-between');
        var left = el(doc, 'div', 'aj-row');
        left.appendChild(sk(doc, '32px', '32px', '', g + r));
        var col = el(doc, 'div', 'aj-col');
        col.appendChild(sk(doc, '132px', '13px', '', g + r));
        col.appendChild(sk(doc, '184px', '10px', '', g + r + 1));
        left.appendChild(col);
        row.appendChild(left);
        row.appendChild(sk(doc, '44px', '24px', 'aj-sk-pill', g + r + 1));
        grp.appendChild(row);
      }
      frag.appendChild(grp);
    }
    return frag;
  }

  function buildBodyForSurface(doc, spec) {
    switch (spec.layoutKind) {
      case 'market':
        return buildMarketBody(doc);
      case 'feed':
        return buildFeedBody(doc);
      case 'explore':
        return buildExploreBody(doc);
      case 'people':
        return buildPeopleBody(doc);
      case 'profile':
        return buildProfileBody(doc);
      case 'journal':
      case 'grid':
        return buildJournalGridBody(doc, spec);
      case 'chat':
        return buildChatBody(doc);
      case 'settings':
        return buildSettingsBody(doc);
      case 'dashboard':
      default:
        return buildDashboardBody(doc, spec);
    }
  }

  function renderInto(container, spec, theme, doc) {
    doc = doc || (typeof document !== 'undefined' ? document : null);
    if (!container || !doc) return;

    ensureStyles(doc);
    applyThemeVariables(theme, doc);

    var dockCfg = DOCKS[spec.dockVariant] || DOCKS.trader;
    var host = el(doc, 'div', 'aj-trans-host ' + spec.animClass);
    host.setAttribute('data-surface', spec.surfaceKey);
    host.setAttribute('data-dock-variant', spec.dockVariant);
    host.setAttribute('data-active-slot', String(spec.activeSlot));

    // Top indeterminate beam
    host.appendChild(el(doc, 'div', 'aj-progress-bar'));

    // Desktop / Tablet Sidebar
    var sidebar = el(doc, 'aside', 'aj-sidebar');
    var sHead = el(doc, 'div', 'aj-side-head');
    var badge = el(doc, 'div', 'aj-logo-badge');
    badge.textContent = 'A';
    sHead.appendChild(badge);
    var sBrand = el(doc, 'div', 'aj-side-brand');
    sBrand.appendChild(sk(doc, '104px', '12px', '', 0));
    sBrand.appendChild(sk(doc, '72px', '9px', '', 1));
    sHead.appendChild(sBrand);
    sidebar.appendChild(sHead);

    var sNav = el(doc, 'div', 'aj-side-nav');
    for (var si = 0; si < dockCfg.sidebar.length; si++) {
      var navItem = dockCfg.sidebar[si];
      var activeNav = navItem.id === spec.activeNavId;
      var itemEl = el(doc, 'div', 'aj-side-item' + (activeNav ? ' is-active' : ''));
      itemEl.appendChild(svgIcon(doc, navItem.icon, 18));
      var lblEl = el(doc, 'span', 'aj-side-item-label');
      lblEl.textContent = navItem.label;
      itemEl.appendChild(lblEl);
      sNav.appendChild(itemEl);
    }
    sidebar.appendChild(sNav);

    var foot = el(doc, 'div', 'aj-side-foot');
    foot.appendChild(sk(doc, '86px', '11px', '', 2));
    foot.appendChild(sk(doc, '100%', '26px', 'aj-sk-pill', 3));
    sidebar.appendChild(foot);
    host.appendChild(sidebar);

    // Main workspace column
    var workspace = el(doc, 'div', 'aj-workspace');
    var topbar = el(doc, 'header', 'aj-topbar');
    var tLeft = el(doc, 'div', 'aj-top-left');
    var tWrap = el(doc, 'div', 'aj-top-title-wrap');
    var tRow = el(doc, 'div', 'aj-top-title-row');
    var titleEl = el(doc, 'span', 'aj-top-title');
    titleEl.textContent = spec.label;
    tRow.appendChild(titleEl);
    tRow.appendChild(el(doc, 'span', 'aj-live-dot'));
    tWrap.appendChild(tRow);
    var subEl = el(doc, 'span', 'aj-top-sub');
    subEl.textContent = spec.subtitle;
    tWrap.appendChild(subEl);
    tLeft.appendChild(tWrap);
    topbar.appendChild(tLeft);

    var tRight = el(doc, 'div', 'aj-top-right');
    var searchStub = el(doc, 'div', 'aj-search-stub');
    searchStub.appendChild(svgIcon(doc, 'search', 15));
    searchStub.appendChild(sk(doc, '124px', '10px', '', 0));
    tRight.appendChild(searchStub);
    var aiBtn = el(doc, 'div', 'aj-icon-btn');
    aiBtn.appendChild(svgIcon(doc, 'spark', 16));
    tRight.appendChild(aiBtn);
    var bellBtn = el(doc, 'div', 'aj-icon-btn');
    bellBtn.appendChild(svgIcon(doc, 'bell', 16));
    tRight.appendChild(bellBtn);
    tRight.appendChild(el(doc, 'div', 'aj-avatar-stub'));
    topbar.appendChild(tRight);
    workspace.appendChild(topbar);

    var scroll = el(doc, 'div', 'aj-scroll');
    var inner = el(doc, 'div', 'aj-container');
    inner.appendChild(buildBodyForSurface(doc, spec));
    scroll.appendChild(inner);
    workspace.appendChild(scroll);
    host.appendChild(workspace);

    // Persistent Mobile Floating Dock (always visible on <768px with active feature selected)
    var dockWrap = el(doc, 'div', 'aj-dock-wrap');
    var dock = el(doc, 'nav', 'aj-dock');
    dock.setAttribute('aria-label', 'Primary Navigation');

    for (var di = 0; di < dockCfg.items.length; di++) {
      if (di === 2) {
        var centerBtn = el(
          doc,
          'div',
          'aj-dock-center' + (spec.centerActive ? ' is-active' : '')
        );
        centerBtn.setAttribute('aria-label', dockCfg.centerLabel);
        if (spec.centerActive) centerBtn.setAttribute('aria-current', 'page');
        centerBtn.appendChild(svgIcon(doc, dockCfg.centerIcon, 20));
        dock.appendChild(centerBtn);
      }
      var dItem = dockCfg.items[di];
      var isSelected = !spec.centerActive && di === spec.activeSlot;
      var dBtn = el(doc, 'div', 'aj-dock-item' + (isSelected ? ' is-active' : ''));
      if (isSelected) dBtn.setAttribute('aria-current', 'page');
      dBtn.appendChild(svgIcon(doc, dItem.icon, 19));
      var dLbl = el(doc, 'span', 'aj-dock-label');
      dLbl.textContent = dItem.label;
      dBtn.appendChild(dLbl);
      dock.appendChild(dBtn);
    }

    dockWrap.appendChild(dock);
    host.appendChild(dockWrap);

    if (typeof container.replaceChildren === 'function') {
      container.replaceChildren(host);
    } else {
      container.innerHTML = '';
      container.appendChild(host);
    }
    return host;
  }

  function initHead() {
    if (typeof document === 'undefined' || typeof location === 'undefined') {
      return { isSilent: false };
    }
    var theme = resolveTheme();
    applyThemeVariables(theme, document);

    var silentRaw = readCookie('ax_silent_nav');
    var silent = parseSilentCookie(silentRaw);
    var refHost = '';
    try {
      if (document.referrer) refHost = new URL(document.referrer).hostname.toLowerCase();
    } catch (_) {}
    var sameRootRef = refHost === 'alphajournal.in' || refHost.endsWith('.alphajournal.in');
    var curHost = String(location.hostname || '').toLowerCase();
    var sameRootCur = curHost === 'alphajournal.in' || curHost.endsWith('.alphajournal.in');
    var hasSessionOrConsent = Boolean(readCookie('ax_sb_auth.n') || readCookie('ax_onboard'));
    var isSilent =
      silent.hasFlag ||
      (sameRootRef && sameRootCur && hasSessionOrConsent && Boolean(refHost) && refHost !== curHost);

    var rootEl = document.documentElement;
    if (isSilent && rootEl) {
      rootEl.classList.add('aj-silent-nav');
      window.__ajSilentNav = true;
      window.__ajSilentRaw = silentRaw;
      window.__ajSilentLabel = silent.label;
    }

    if (silent.hasFlag) {
      try {
        var secure = location.protocol === 'https:' ? '; Secure' : '';
        var domain = sameRootCur ? '; Domain=.alphajournal.in' : '';
        document.cookie = 'ax_silent_nav=; Path=/; Max-Age=0; SameSite=Lax' + domain + secure;
      } catch (_) {}
    }

    if (typeof window !== 'undefined' && typeof window.addEventListener === 'function') {
      window.addEventListener('pageshow', function () {
        var veil = document.getElementById(VEIL_ID);
        if (veil && veil.parentNode) veil.parentNode.removeChild(veil);
      });
    }

    return { isSilent: isSilent, theme: theme };
  }

  function mountIncoming() {
    if (typeof document === 'undefined' || !window.__ajSilentNav) return null;
    var shell = document.getElementById('aj-silent-shell');
    if (!shell) return null;
    var theme = resolveTheme();
    var spec = resolveSurface({
      silentRaw: window.__ajSilentRaw || '',
      hostname: typeof location !== 'undefined' ? location.hostname : '',
      pathname: typeof location !== 'undefined' ? location.pathname : '',
    });
    return renderInto(shell, spec, theme, document);
  }

  function startOutgoing(url) {
    if (typeof document === 'undefined' || !document.documentElement) return null;
    var theme = resolveTheme();
    applyThemeVariables(theme, document);
    var spec = resolveSurface({ url: url || '' });

    var existing = document.getElementById(VEIL_ID);
    if (existing && existing.parentNode) {
      existing.parentNode.removeChild(existing);
    }
    var veil = document.createElement('div');
    veil.id = VEIL_ID;
    veil.setAttribute('aria-hidden', 'true');
    veil.style.cssText = 'position:fixed;inset:0;z-index:2147483647;background:' + theme.palette.bg + ';';
    document.documentElement.appendChild(veil);
    renderInto(veil, spec, theme, document);
    return veil;
  }

  var api = {
    THEMES: THEMES,
    DOCKS: DOCKS,
    resolveTheme: resolveTheme,
    parseSilentCookie: parseSilentCookie,
    resolveSurface: resolveSurface,
    applyThemeVariables: applyThemeVariables,
    renderInto: renderInto,
    initHead: initHead,
    mountIncoming: mountIncoming,
    startOutgoing: startOutgoing,
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  }
  if (root && typeof root === 'object') {
    root.alphajournalTransition = api;
  }
})(typeof window !== 'undefined' ? window : globalThis);
