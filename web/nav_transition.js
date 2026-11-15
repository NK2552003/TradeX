/**
 * Shared cross-subdomain silent transition & full-screen skeleton shell.
 *
 * Mirrors TradeX's real Flutter AppShell (AppSidebar + AppTopBar + rounded
 * content frame on desktop/tablet, AppTopBar + QuietDock on mobile) and Flutter
 * UiSkeleton presets (`UiSkeleton.dashboard`, `journal`, `strategies`,
 * `watchlists`, `market`, `community`, `profilePreview`, `messages`, `ai`,
 * `settings`, `page`) using `_UiShimmerPainter`'s synchronized 1500ms linear
 * sweep and `UiColors` / `QuietDockTheme` tokens.
 */
(function (root) {
  'use strict';

  var STYLE_ID = 'aj-transition-styles';
  var VEIL_ID = 'aj-nav-veil';
  var VALID_TOKEN_RE = /^[a-zA-Z0-9_-]{1,32}$/;
  var VALID_LABEL_RE = /^[a-zA-Z0-9 &/_-]{1,32}$/;

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
      skBase: 'rgba(250, 249, 249, 0.045)',
      skHighlight: 'rgba(250, 249, 249, 0.04)',
      dockBg: 'rgba(21, 19, 18, 0.62)',
      dockBorder: 'rgba(58, 55, 52, 0.65)',
      shadow: '0 8px 24px rgba(0, 0, 0, 0.36)',
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
      primarySoft: 'rgba(21, 19, 18, 0.12)',
      primaryBorder: 'rgba(21, 19, 18, 0.30)',
      brand: '#6B7FD7',
      skBase: 'rgba(21, 19, 18, 0.055)',
      skHighlight: 'rgba(255, 255, 255, 0.55)',
      dockBg: 'rgba(255, 255, 255, 0.74)',
      dockBorder: 'rgba(214, 211, 209, 0.75)',
      shadow: '0 8px 24px rgba(21, 19, 18, 0.10)',
    },
  };

  var DOCKS = {
    trader: {
      centerIcon: 'grid',
      centerLabel: 'More tools',
      searchPlaceholder: 'Search desk records, notes, trades, playbooks...',
      items: [
        { id: 'workspace', label: 'Writing Desk', icon: 'edit_note' },
        { id: 'community', label: 'Community', icon: 'forum' },
        { id: 'calculators', label: 'Calculators', icon: 'calc' },
        { id: 'settings', label: 'Settings', icon: 'settings' },
      ],
      sections: [
        {
          title: 'WORKSPACE',
          items: [
            {
              id: 'workspace',
              label: 'Writing Desk',
              icon: 'edit_note',
              subItems: [
                { id: 'journal', label: 'Journal' },
                { id: 'strategies', label: 'Strategies' },
                { id: 'notes', label: 'Notes' },
              ],
            },
            { id: 'calculators', label: 'Calculators', icon: 'calc' },
          ],
        },
        {
          title: 'CONNECT & INTELLIGENCE',
          items: [
            { id: 'community', label: 'Community', icon: 'forum', hasChevron: true },
            { id: 'messages', label: 'Messages', icon: 'chat' },
            { id: 'ai_copilot', label: 'AI Assistant', icon: 'spark' },
          ],
        },
        {
          title: 'MARKETS',
          items: [
            { id: 'market', label: 'Market Intelligence', icon: 'globe', hasChevron: true },
          ],
        },
        {
          title: 'ACCOUNT',
          items: [
            { id: 'settings', label: 'Settings', icon: 'settings', hasChevron: true },
          ],
        },
      ],
    },
    community: {
      centerIcon: 'apps',
      centerLabel: 'Switch to App',
      searchPlaceholder: 'Search traders, setups, tickers, posts...',
      items: [
        { id: 'community_feed', label: 'Feed', icon: 'feed' },
        { id: 'community_explore', label: 'Explore', icon: 'compass' },
        { id: 'community_network', label: 'Network', icon: 'users' },
        { id: 'community_profile', label: 'Profile', icon: 'user' },
      ],
      sections: [
        {
          title: 'COMMUNITY',
          items: [
            { id: 'community_feed', label: 'Feed', icon: 'feed' },
            { id: 'community_explore', label: 'Explore', icon: 'compass' },
            { id: 'community_network', label: 'Network', icon: 'users' },
            { id: 'community_profile', label: 'Profile', icon: 'user' },
          ],
        },
        {
          title: 'WORKSPACE',
          items: [
            { id: 'workspace', label: 'Writing Desk', icon: 'edit_note' },
            { id: 'market', label: 'Market Intelligence', icon: 'globe' },
            { id: 'messages', label: 'Messages', icon: 'chat' },
          ],
        },
        {
          title: 'ACCOUNT',
          items: [
            { id: 'settings', label: 'Settings', icon: 'settings', hasChevron: true },
          ],
        },
      ],
    },
    affiliate: {
      centerIcon: 'grid',
      centerLabel: 'More tools',
      searchPlaceholder: 'Search referrals, creatives, payouts...',
      items: [
        { id: 'overview', label: 'Hub', icon: 'dashboard' },
        { id: 'referrals', label: 'Referrals', icon: 'trend' },
        { id: 'marketing', label: 'Media Kit', icon: 'campaign' },
        { id: 'settings', label: 'Settings', icon: 'settings' },
      ],
      sections: [
        {
          title: 'PARTNER PORTAL',
          items: [
            { id: 'overview', label: 'Partner Hub', icon: 'dashboard' },
            { id: 'referrals', label: 'Referrals & Clicks', icon: 'trend' },
            { id: 'marketing', label: 'Media Kit & Creatives', icon: 'campaign' },
            { id: 'payouts', label: 'Payout History', icon: 'wallet' },
          ],
        },
        {
          title: 'OPERATIONS',
          items: [
            { id: 'ai_copilot', label: 'AI Assistant', icon: 'spark' },
            { id: 'messages', label: 'Messages', icon: 'chat' },
          ],
        },
        {
          title: 'ACCOUNT',
          items: [
            { id: 'settings', label: 'Partner Settings', icon: 'settings', hasChevron: true },
          ],
        },
      ],
    },
    admin: {
      centerIcon: 'grid',
      centerLabel: 'More tools',
      searchPlaceholder: 'Search users, affiliate reviews, audit logs...',
      items: [
        { id: 'overview', label: 'Overview', icon: 'dashboard' },
        { id: 'org_team', label: 'Users', icon: 'users' },
        { id: 'affiliate_reviews', label: 'Affiliates', icon: 'handshake' },
        { id: 'settings', label: 'Settings', icon: 'settings' },
      ],
      sections: [
        {
          title: 'GOVERNANCE',
          items: [
            { id: 'overview', label: 'Overview', icon: 'dashboard' },
            { id: 'org_team', label: 'Users', icon: 'users' },
            { id: 'affiliate_reviews', label: 'Affiliates', icon: 'handshake' },
            { id: 'org_publishing', label: 'Posts & Review', icon: 'layers' },
            { id: 'org_analytics', label: 'Analytics', icon: 'globe' },
          ],
        },
        {
          title: 'OPERATIONS',
          items: [
            { id: 'admin_ai', label: 'AI Control', icon: 'spark' },
            { id: 'messages', label: 'Messages', icon: 'chat' },
          ],
        },
        {
          title: 'ACCOUNT',
          items: [
            { id: 'settings', label: 'Settings', icon: 'settings', hasChevron: true },
          ],
        },
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
      return { hasFlag: false, isSuppressed: false, surfaceKey: '', label: '' };
    }
    if (silentRaw === '0') {
      return { hasFlag: false, isSuppressed: true, surfaceKey: '', label: '' };
    }
    if (silentRaw === '1') {
      return { hasFlag: true, isSuppressed: false, surfaceKey: '', label: '' };
    }
    if (silentRaw.indexOf('1|') !== 0) {
      return { hasFlag: false, isSuppressed: false, surfaceKey: '', label: '' };
    }
    var rest = silentRaw.slice(2).split('|');
    if (rest.length >= 2) {
      var key = rest[0].trim();
      var lbl = rest[1].trim();
      return {
        hasFlag: true,
        isSuppressed: false,
        surfaceKey: VALID_TOKEN_RE.test(key) ? key : '',
        label: VALID_LABEL_RE.test(lbl) ? lbl : '',
      };
    }
    var onlyLabel = rest[0].trim();
    return {
      hasFlag: true,
      isSuppressed: false,
      surfaceKey: '',
      label: VALID_LABEL_RE.test(onlyLabel) ? onlyLabel : '',
    };
  }

  function hasAuthCallbackParams(search, hash) {
    var combined = ((search || '') + '&' + (hash || '')).toLowerCase();
    return (
      /[?&#](code|error|error_code|token_hash|access_token|refresh_token)=/.test(
        combined,
      )
    );
  }

  function isAuthOrPublicRoute(host, path, search, hash) {
    host = String(host || '').toLowerCase().trim();
    path = String(path || '').toLowerCase().trim();
    if (hasAuthCallbackParams(search, hash)) return true;

    var parts = path.split('/');
    var seg = '';
    for (var i = 0; i < parts.length; i++) {
      if (parts[i]) {
        seg = parts[i];
        break;
      }
    }

    if (
      seg === 'auth' ||
      seg === 'login' ||
      seg === 'signup' ||
      seg === 'register' ||
      seg === 'onboarding' ||
      seg === 'get_started' ||
      seg === 'forgot-password' ||
      seg === 'forgot_password' ||
      seg === 'reset-password' ||
      seg === 'reset_password' ||
      seg === 'verify' ||
      seg === 'r' ||
      seg === 'join' ||
      seg === 'help'
    ) {
      return true;
    }

    if (
      (!path || path === '/') &&
      (host === 'alphajournal.in' || host === 'www.alphajournal.in')
    ) {
      return true;
    }

    return false;
  }

  function isAuthOrPublicUrl(url) {
    if (!url) return false;
    try {
      var base =
        typeof window !== 'undefined' && window.location && window.location.origin
          ? window.location.origin
          : 'https://app.alphajournal.in';
      var parsed = new URL(url, base);
      return isAuthOrPublicRoute(
        parsed.hostname,
        parsed.pathname,
        parsed.search,
        parsed.hash,
      );
    } catch (_) {
      return false;
    }
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

    // Matches AppScaffold._destinationSkeleton & UiSkeleton.* presets
    var specs = {
      workspace: {
        topTitle: 'Terminal / Workspace',
        label: 'Trade Journal',
        subtitle: 'Executions, trade notes, and performance stats',
        layoutKind: 'journal',
        activeSlot: 0,
        centerActive: false,
        centerRouteIcon: null,
        activeNavId: 'workspace',
      },
      community_feed: {
        topTitle: 'Community / Feed',
        label: 'Community',
        subtitle: 'Trader setups & market discussions',
        layoutKind: 'community',
        activeSlot: dockVariant === 'community' ? 0 : 1,
        centerActive: false,
        centerRouteIcon: null,
        activeNavId: dockVariant === 'community' ? 'community_feed' : 'community',
      },
      community_explore: {
        topTitle: 'Community / Explore',
        label: 'Explore',
        subtitle: 'Discover verified setups & analysts',
        layoutKind: 'community_explore',
        activeSlot: 1,
        centerActive: false,
        centerRouteIcon: null,
        activeNavId: 'community_explore',
      },
      community_network: {
        topTitle: 'Community / Network',
        label: 'Network',
        subtitle: 'Connected traders & following feed',
        layoutKind: 'network',
        activeSlot: 2,
        centerActive: false,
        centerRouteIcon: null,
        activeNavId: 'community_network',
      },
      community_profile: {
        topTitle: 'Community / Profile',
        label: 'Profile',
        subtitle: 'Track record & published insights',
        layoutKind: 'profile_preview',
        activeSlot: 3,
        centerActive: false,
        centerRouteIcon: null,
        activeNavId: 'community_profile',
      },
      market: {
        topTitle: 'Markets / Overview',
        label: 'Markets',
        subtitle: 'Screeners, indices & price depth',
        layoutKind: 'market',
        activeSlot: -1,
        centerActive: true,
        centerRouteIcon: 'globe',
        activeNavId: 'market',
      },
      journal: {
        topTitle: 'Workspace / Journal',
        label: 'Trade Journal',
        subtitle: 'Executions, trade notes, and performance stats',
        layoutKind: 'journal',
        activeSlot: -1,
        centerActive: true,
        centerRouteIcon: 'edit_note',
        activeNavId: 'journal',
      },
      strategies: {
        topTitle: 'Workspace / Strategies',
        label: 'Trading Strategies',
        subtitle: 'Backtested playbooks, Sharpe ratios, and win-rates',
        layoutKind: 'strategies',
        activeSlot: -1,
        centerActive: true,
        centerRouteIcon: 'layers',
        activeNavId: 'strategies',
      },
      notes: {
        topTitle: 'Workspace / Notes',
        label: 'Trade Journal',
        subtitle: 'Executions, trade notes, and performance stats',
        layoutKind: 'journal',
        activeSlot: -1,
        centerActive: true,
        centerRouteIcon: 'edit_note',
        activeNavId: 'notes',
      },
      calculators: {
        topTitle: 'Workspace / Calculators',
        label: 'Watchlists & Markets',
        subtitle: 'Position sizing, risk & R:R matrix',
        layoutKind: 'watchlists',
        activeSlot: 2,
        centerActive: false,
        centerRouteIcon: null,
        activeNavId: 'calculators',
      },
      messages: {
        topTitle: 'Connect / Messages',
        label: 'Messages',
        subtitle: 'Encrypted trader threads',
        layoutKind: 'messages',
        activeSlot: -1,
        centerActive: true,
        centerRouteIcon: 'chat',
        activeNavId: 'messages',
      },
      ai_copilot: {
        topTitle: 'Connect / AI Copilot',
        label: 'AI Trading Copilot',
        subtitle: 'Quantitative pattern detection & smart trade assistant',
        layoutKind: 'ai',
        activeSlot: -1,
        centerActive: true,
        centerRouteIcon: 'spark',
        activeNavId: 'ai_copilot',
      },
      settings: {
        topTitle: 'Account / Settings',
        label: 'Settings',
        subtitle: 'Security, appearance & preferences',
        layoutKind: 'settings',
        activeSlot: 3,
        centerActive: false,
        centerRouteIcon: null,
        activeNavId: 'settings',
      },
      partner_hub: {
        topTitle: 'Partner / Hub',
        label: 'Dashboard',
        subtitle: 'Real-time market analytics & active portfolio metrics',
        layoutKind: 'dashboard',
        activeSlot: 0,
        centerActive: false,
        centerRouteIcon: null,
        activeNavId: 'overview',
      },
      referrals: {
        topTitle: 'Partner / Referrals',
        label: 'Dashboard',
        subtitle: 'Real-time market analytics & active portfolio metrics',
        layoutKind: 'dashboard',
        activeSlot: 1,
        centerActive: false,
        centerRouteIcon: null,
        activeNavId: 'referrals',
      },
      marketing: {
        topTitle: 'Partner / Media Kit',
        label: 'Dashboard',
        subtitle: 'Real-time market analytics & active portfolio metrics',
        layoutKind: 'dashboard',
        activeSlot: 2,
        centerActive: false,
        centerRouteIcon: null,
        activeNavId: 'marketing',
      },
      payouts: {
        topTitle: 'Partner / Payouts',
        label: 'Dashboard',
        subtitle: 'Real-time market analytics & active portfolio metrics',
        layoutKind: 'dashboard',
        activeSlot: -1,
        centerActive: true,
        centerRouteIcon: 'wallet',
        activeNavId: 'payouts',
      },
      admin_console: {
        topTitle: 'Admin / Overview',
        label: 'Dashboard',
        subtitle: 'Real-time market analytics & active portfolio metrics',
        layoutKind: 'dashboard',
        activeSlot: 0,
        centerActive: false,
        centerRouteIcon: null,
        activeNavId: 'overview',
      },
      org_team: {
        topTitle: 'Admin / Users',
        label: 'Users',
        subtitle: 'Workspace members, roles & entitlements',
        layoutKind: 'page',
        activeSlot: 1,
        centerActive: false,
        centerRouteIcon: null,
        activeNavId: 'org_team',
      },
      affiliate_reviews: {
        topTitle: 'Admin / Affiliates',
        label: 'Affiliates',
        subtitle: 'Partner applications & approval queue',
        layoutKind: 'page',
        activeSlot: 2,
        centerActive: false,
        centerRouteIcon: null,
        activeNavId: 'affiliate_reviews',
      },
    };

    var chosen = specs[key] || specs.workspace;
    var mobileLabel = chosen.topTitle;
    if (mobileLabel && mobileLabel.indexOf(' / ') !== -1) {
      mobileLabel = mobileLabel.split(' / ').slice(1).join(' / ');
    }
    return {
      surfaceKey: key,
      topTitle: chosen.topTitle,
      mobileTitle: mobileLabel || chosen.label,
      label: silent.label && key !== 'workspace' ? silent.label : chosen.label,
      subtitle: chosen.subtitle,
      layoutKind: chosen.layoutKind,
      dockVariant: dockVariant,
      activeSlot: chosen.activeSlot,
      centerActive: chosen.centerActive,
      centerRouteIcon: chosen.centerRouteIcon,
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
        '--aj-sk-base': p.skBase,
        '--aj-sk-highlight': p.skHighlight,
        '--aj-dock-bg': p.dockBg,
        '--aj-dock-border': p.dockBorder,
        '--aj-shadow': p.shadow,
        '--aj-pad': theme.compact ? '12px' : '16px',
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
    if (typeof doc.querySelectorAll === 'function') {
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
      '@font-face{font-family:"NotoSans";src:url("/assets/assets/fonts/NotoSans-Regular.ttf") format("truetype");font-weight:400 500;font-style:normal;font-display:swap;}',
      '@font-face{font-family:"NotoSans";src:url("/assets/assets/fonts/NotoSans-Bold.ttf") format("truetype");font-weight:600 800;font-style:normal;font-display:swap;}',
      '.aj-trans-host{--aj-text-scale:1;--aj-unit:clamp(0.85px,0.0625rem,1.4px);position:fixed;inset:0;display:flex;background:var(--aj-bg);color:var(--aj-fg);font-family:"Noto Sans","NotoSans",system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;font-size:calc(14 * var(--aj-text-scale) * var(--aj-unit));pointer-events:auto;overflow:hidden;-webkit-font-smoothing:antialiased;}',
      '@media(min-width:600px){.aj-trans-host{--aj-text-scale:1.05;}}',
      '@media(min-width:905px){.aj-trans-host{--aj-text-scale:1.1;}}',
      '@media(min-width:1440px){.aj-trans-host{--aj-text-scale:1.15;}}',
      /* AppSidebar matching AppShell screenshot (no border-right divider) */
      '.aj-sidebar{display:none;flex-direction:column;width:76px;flex-shrink:0;background:var(--aj-bg);padding:4px;}',
      '@media(min-width:1024px){.aj-sidebar{width:244px;padding:4px 5px;}}',
      '@media(min-width:768px){.aj-sidebar{display:flex;}}',
      '.aj-side-head{display:flex;align-items:center;justify-content:center;gap:8px;padding:5px 4px;border-radius:12px;}',
      '@media(min-width:1024px){.aj-side-head{justify-content:flex-start;padding:5px 8px;background:rgba(255,255,255,0.025);border:1px solid var(--aj-border);}}',
      '.aj-light .aj-side-head{background:rgba(255,255,255,0.7);}',
      '.aj-logo-badge{width:20px;height:20px;border-radius:3px;background:var(--aj-primary);color:var(--aj-bg);display:grid;place-items:center;font-weight:700;font-size:calc(12 * var(--aj-text-scale) * var(--aj-unit));letter-spacing:-.04em;flex-shrink:0;}',
      '.aj-side-brand{display:none;flex-direction:column;gap:2px;min-width:0;flex:1;}',
      '@media(min-width:1024px){.aj-side-brand{display:flex;}}',
      '.aj-side-title{font-size:calc(13 * var(--aj-text-scale) * var(--aj-unit));font-weight:600;color:var(--aj-fg);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;line-height:1.35;}',
      '.aj-side-plan{font-size:calc(11 * var(--aj-text-scale) * var(--aj-unit));font-weight:400;color:var(--aj-fg-subtle);line-height:1.25;}',
      '.aj-side-swap{display:none;color:var(--aj-fg-muted);align-items:center;justify-content:center;}',
      '@media(min-width:1024px){.aj-side-swap{display:flex;}}',
      '.aj-side-nav{display:flex;flex-direction:column;gap:8px;flex:1;overflow:hidden;padding:6px 2px;}',
      '.aj-side-sec{display:flex;flex-direction:column;gap:2px;}',
      '.aj-side-sec-title{display:none;font-size:calc(11 * var(--aj-text-scale) * var(--aj-unit));font-weight:700;letter-spacing:.073em;color:var(--aj-fg-subtle);padding:8px 8px 4px;text-transform:uppercase;}',
      '@media(min-width:1024px){.aj-side-sec-title{display:block;}}',
      '.aj-side-item{display:flex;align-items:center;justify-content:center;gap:9px;height:33px;border-radius:8px;padding:4px 8px;color:var(--aj-fg-muted);font-size:calc(13 * var(--aj-text-scale) * var(--aj-unit));font-weight:500;white-space:nowrap;border:1px solid transparent;}',
      '@media(min-width:1024px){.aj-side-item{justify-content:space-between;}}',
      '.aj-side-item-left{display:flex;align-items:center;gap:9px;min-width:0;}',
      '.aj-side-item.is-active{background:var(--aj-primary-soft);color:var(--aj-fg);border:1px solid var(--aj-primary-border);font-weight:600;}',
      '.aj-side-item.is-active svg{color:var(--aj-primary);}',
      '.aj-side-item-label{display:none;}',
      '@media(min-width:1024px){.aj-side-item-label{display:inline;}}',
      '.aj-side-chev{display:none;color:var(--aj-fg-subtle);font-size:calc(12 * var(--aj-text-scale) * var(--aj-unit));}',
      '@media(min-width:1024px){.aj-side-chev{display:inline;}}',
      '.aj-side-subwrap{display:none;flex-direction:column;gap:2px;padding-left:26px;margin-top:2px;}',
      '@media(min-width:1024px){.aj-side-subwrap{display:flex;}}',
      '.aj-side-sub{height:29px;padding:0 8px;border-radius:8px;display:flex;align-items:center;font-size:calc(13 * var(--aj-text-scale) * var(--aj-unit));font-weight:500;color:var(--aj-fg-muted);}',
      '.aj-side-sub.is-active{background:var(--aj-primary-soft);color:var(--aj-fg);font-weight:600;}',
      '.aj-side-foot{display:none;padding:6px 8px;border-radius:10px;align-items:center;gap:9px;border:1px solid var(--aj-border);background:rgba(255,255,255,0.02);}',
      '.aj-light .aj-side-foot{background:rgba(255,255,255,0.65);}',
      '@media(min-width:1024px){.aj-side-foot{display:flex;}}',
      /* AppTopBar UiCard wrapper + rounded desktop AppContentSurface */
      '.aj-workspace{flex:1;min-width:0;display:flex;flex-direction:column;height:100%;overflow:hidden;}',
      '.aj-topbar{flex-shrink:0;padding:4px 8px;background:var(--aj-bg);}',
      '.aj-topbar-card{height:40px;display:flex;align-items:center;justify-content:space-between;padding:4px 8px;background:var(--aj-surface);border:1px solid var(--aj-border);border-radius:12px;gap:10px;}',
      '.aj-top-left{display:flex;align-items:center;gap:6px;min-width:0;flex:1;}',
      '.aj-top-menu-icon{color:var(--aj-fg);display:none;align-items:center;justify-content:center;width:28px;height:28px;border-radius:8px;flex-shrink:0;}',
      '@media(min-width:768px){.aj-top-menu-icon{display:flex;}}',
      '.aj-top-title{font-size:calc(14 * var(--aj-text-scale) * var(--aj-unit));font-weight:500;line-height:1.55;color:var(--aj-fg);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}',
      '.aj-top-title-desktop{display:none;}',
      '.aj-top-title-mobile{display:inline;}',
      '@media(min-width:768px){.aj-top-title-desktop{display:inline;}.aj-top-title-mobile{display:none;}}',
      '.aj-search-stub{display:none;align-items:center;gap:8px;flex:1.4;max-width:440px;height:28px;padding:0 10px;border-radius:8px;background:var(--aj-surface-muted);border:1px solid var(--aj-border);color:var(--aj-fg-subtle);font-size:calc(13 * var(--aj-text-scale) * var(--aj-unit));}',
      '@media(min-width:860px){.aj-search-stub{display:flex;}}',
      '.aj-search-txt{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}',
      '.aj-top-right{display:flex;align-items:center;gap:2px;flex-shrink:0;}',
      '.aj-icon-btn{width:28px;height:28px;border-radius:8px;display:grid;place-items:center;color:var(--aj-fg);}',
      '.aj-mobile-only{display:grid;}',
      '.aj-desktop-only{display:none;}',
      '@media(min-width:860px){.aj-mobile-only{display:none;}.aj-desktop-only{display:grid;}}',
      /* Rounded bordered desktop content frame matching app-content-surface */
      '.aj-content-frame{flex:1;min-height:0;display:flex;flex-direction:column;overflow:hidden;}',
      '@media(min-width:768px){.aj-content-frame{margin:0 7px 7px 0;border-radius:16px;border:1px solid var(--aj-border);background:var(--aj-bg);}}',
      '.aj-scroll{flex:1;overflow:hidden;padding:var(--aj-pad);padding-bottom:16px;}',
      '@media(min-width:768px){.aj-scroll{padding:16px;padding-bottom:24px;}}',
      '.aj-container{width:100%;max-width:1180px;margin:0 auto;display:flex;flex-direction:column;gap:12px;}',
      '.aj-page-head{display:flex;align-items:center;justify-content:space-between;gap:12px;}',
      '.aj-page-title{font-size:calc(24 * var(--aj-text-scale) * var(--aj-unit));font-weight:600;letter-spacing:-.015em;color:var(--aj-fg);line-height:1.25;}',
      '.aj-page-sub{font-size:calc(14 * var(--aj-text-scale) * var(--aj-unit));font-weight:400;color:var(--aj-fg-muted);margin-top:2px;line-height:1.55;}',
      '.aj-card{background:var(--aj-surface);border:1px solid var(--aj-border);border-radius:12px;padding:14px 16px;display:flex;flex-direction:column;gap:10px;}',
      '.aj-tabs-box{height:36px;padding:4px;border-radius:10px;background:rgba(255,255,255,0.02);border:1px solid var(--aj-border);display:flex;align-items:center;gap:6px;}',
      '.aj-light .aj-tabs-box{background:rgba(245,245,244,0.5);}',
      '.aj-tab-item{flex:1;height:100%;border-radius:7px;}',
      /* Synchronized _UiShimmerPainter sweep (1500ms linear, 42% band, low contrast) */
      '.aj-sk{position:relative;overflow:hidden;background:var(--aj-sk-base);border-radius:6px;flex-shrink:0;}',
      '.aj-sk-lg{border-radius:10px;}',
      '.aj-sk-pill{border-radius:999px;}',
      '.aj-sk-circle{border-radius:999px;}',
      '.aj-sk::after{content:"";position:absolute;top:0;bottom:0;left:0;width:42%;transform:translateX(-150%);background:linear-gradient(90deg,transparent 0%,var(--aj-sk-highlight) 50%,transparent 100%);animation:aj-ui-shimmer 1500ms linear infinite;}',
      '@keyframes aj-ui-shimmer{0%{transform:translateX(-150%)}100%{transform:translateX(360%)}}',
      '.aj-row{display:flex;align-items:center;gap:10px;}',
      '.aj-row-between{display:flex;align-items:center;justify-content:space-between;gap:10px;}',
      '.aj-col{display:flex;flex-direction:column;gap:6px;min-width:0;}',
      '.aj-metrics-4{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;}',
      '@media(min-width:768px){.aj-metrics-4{grid-template-columns:repeat(4,minmax(0,1fr));}}',
      '.aj-metrics-2{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;}',
      '.aj-metrics-3{display:flex;flex-direction:column;gap:10px;}',
      '@media(min-width:768px){.aj-metrics-3{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));}}',
      '.aj-comm-wrap{display:flex;align-items:flex-start;justify-content:center;gap:20px;width:100%;}',
      '.aj-comm-feed{flex:1;max-width:700px;min-width:0;display:flex;flex-direction:column;gap:10px;}',
      '.aj-comm-side{display:none;width:320px;flex-shrink:0;flex-direction:column;gap:14px;}',
      '@media(min-width:960px){.aj-comm-side{display:flex;}}',
      '.aj-heat-strip{display:flex;align-items:center;justify-content:space-around;gap:6px;padding:2px 0;}',
      '.aj-ribbon{height:54px;padding:0 12px;border-radius:8px;background:var(--aj-surface);border:1px solid var(--aj-border);display:flex;align-items:center;gap:10px;overflow:hidden;}',
      '.aj-vdiv{width:1px;height:22px;background:var(--aj-border);flex-shrink:0;}',
      '.aj-market-split{display:flex;flex-direction:column;gap:12px;}',
      '@media(min-width:768px){.aj-market-split{display:grid;grid-template-columns:minmax(0,6fr) minmax(0,4fr);align-items:start;}}',
      '.aj-mosaic{height:148px;display:grid;grid-template-columns:3fr 2fr 2fr;gap:4px;}',
      '.aj-mosaic-mid{display:grid;grid-template-rows:1fr 1fr;gap:4px;height:100%;}',
      /* Exact QuietDock floating pill (280x56, radius 28, margin 16, 5 equal 1fr slots, showLabels:false, 4px inset pill) */
      '.aj-dock-wrap{position:fixed;left:0;right:0;bottom:calc(16px + env(safe-area-inset-bottom,0px));z-index:20;display:flex;justify-content:center;pointer-events:none;}',
      '@media(min-width:768px){.aj-dock-wrap{display:none;}}',
      '.aj-dock{width:280px;height:56px;border-radius:28px;background:var(--aj-dock-bg);backdrop-filter:blur(18px) saturate(140%);-webkit-backdrop-filter:blur(18px) saturate(140%);border:1.2px solid var(--aj-dock-border,var(--aj-border-strong));box-shadow:var(--aj-shadow);display:grid;grid-template-columns:repeat(5,1fr);align-items:stretch;overflow:hidden;}',
      '.aj-dock-slot{position:relative;display:flex;align-items:center;justify-content:center;color:var(--aj-fg-muted);}',
      '.aj-dock-slot.is-active{color:var(--aj-primary);}',
      '.aj-dock-pill{position:absolute;inset:4px;border-radius:24px;background:var(--aj-primary-soft);border:1px solid var(--aj-primary-border);pointer-events:none;}',
      '.aj-dock-icon{position:relative;z-index:1;display:grid;place-items:center;}',
      '.aj-dock-back{position:absolute;top:8px;right:8px;z-index:2;color:var(--aj-primary);display:grid;place-items:center;}',
      '#' + VEIL_ID + '{z-index:2147483647;}',
      '@media(prefers-reduced-motion:reduce){.aj-sk::after{animation:none !important;}}',
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
    var filledIcons = { apps: true, grid: true };
    var isFilled = Boolean(filledIcons[name]);
    svg.setAttribute('fill', isFilled ? 'currentColor' : 'none');
    svg.setAttribute('stroke', isFilled ? 'none' : 'currentColor');
    svg.setAttribute('stroke-width', isFilled ? '0' : '1.75');
    svg.setAttribute('stroke-linecap', 'round');
    svg.setAttribute('stroke-linejoin', 'round');
    svg.setAttribute('aria-hidden', 'true');

    var paths = {
      menu: ['M4 7h16M4 12h16M4 17h10'],
      swap_vert: ['M8 9l4-4 4 4', 'M8 15l4 4 4-4'],
      dashboard: [
        'M4 5a1 1 0 0 1 1-1h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5Z',
        'M13 5a1 1 0 0 1 1-1h5a1 1 0 0 1 1 1v3a1 1 0 0 1-1 1h-5a1 1 0 0 1-1-1V5Z',
        'M13 13a1 1 0 0 1 1-1h5a1 1 0 0 1 1 1v6a1 1 0 0 1-1 1h-5a1 1 0 0 1-1-1v-6Z',
        'M4 15a1 1 0 0 1 1-1h5a1 1 0 0 1 1 1v4a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-4Z',
      ],
      edit_note: [
        'M3 7h11M3 12h11M3 17h7',
        'M16.5 13.5l3 3-5.2 5.2H11.5v-2.8l5-5.4Z',
      ],
      forum: [
        'M3 5.5A1.5 1.5 0 0 1 4.5 4h10A1.5 1.5 0 0 1 16 5.5V12a1.5 1.5 0 0 1-1.5 1.5H7L3 17V5.5Z',
        'M19 8h.5A1.5 1.5 0 0 1 21 9.5V20l-3.5-3H9.5A1.5 1.5 0 0 1 8 15.5V15',
      ],
      feed: [
        'M9 5.5A1.5 1.5 0 0 1 10.5 4h9A1.5 1.5 0 0 1 21 5.5v7a1.5 1.5 0 0 1-1.5 1.5h-9A1.5 1.5 0 0 1 9 12.5v-7Z',
        'M12.5 8h5',
        'M4 9v9a2 2 0 0 0 2 2h10',
      ],
      compass: [
        'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Z',
        'M15.4 8.6l-2 5.1-5.1 2 2-5.1 5.1-2Z',
      ],
      users: [
        'M15 19v-1a4 4 0 0 0-4-4H6.5a4 4 0 0 0-4 4v1',
        'M8.75 10.5a3.25 3.25 0 1 0 0-6.5 3.25 3.25 0 0 0 0 6.5Z',
        'M21.5 19v-1a3.5 3.5 0 0 0-2.6-3.4',
        'M16 4.2a3.25 3.25 0 0 1 0 6.3',
      ],
      user: [
        'M19 20v-1.5A4.5 4.5 0 0 0 14.5 14h-5A4.5 4.5 0 0 0 5 18.5V20',
        'M12 10.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Z',
      ],
      calc: [
        'M5.5 3h13A1.5 1.5 0 0 1 20 4.5v15a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 4 19.5v-15A1.5 1.5 0 0 1 5.5 3Z',
        'M8 6.5h8v3H8zM8 13h1.5M11.25 13h1.5M14.5 13H16M8 16.5h1.5M11.25 16.5h1.5M14.5 16.5H16',
      ],
      settings: [
        'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z',
        'M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09a1.65 1.65 0 0 0-1-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09a1.65 1.65 0 0 0 1.51-1 1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1Z',
      ],
      grid: [
        'M4 5.5A1.5 1.5 0 0 1 5.5 4h4A1.5 1.5 0 0 1 11 5.5v4A1.5 1.5 0 0 1 9.5 11h-4A1.5 1.5 0 0 1 4 9.5v-4ZM13 5.5A1.5 1.5 0 0 1 14.5 4h4A1.5 1.5 0 0 1 20 5.5v4a1.5 1.5 0 0 1-1.5 1.5h-4A1.5 1.5 0 0 1 13 9.5v-4ZM4 14.5A1.5 1.5 0 0 1 5.5 13h4a1.5 1.5 0 0 1 1.5 1.5v4A1.5 1.5 0 0 1 9.5 20h-4A1.5 1.5 0 0 1 4 18.5v-4ZM13 14.5a1.5 1.5 0 0 1 1.5-1.5h4a1.5 1.5 0 0 1 1.5 1.5v4a1.5 1.5 0 0 1-1.5 1.5h-4a1.5 1.5 0 0 1-1.5-1.5v-4Z',
      ],
      apps: [
        'M4.5 5.4a.9.9 0 0 1 .9-.9h1.2a.9.9 0 0 1 .9.9v1.2a.9.9 0 0 1-.9.9H5.4a.9.9 0 0 1-.9-.9V5.4ZM10.5 5.4a.9.9 0 0 1 .9-.9h1.2a.9.9 0 0 1 .9.9v1.2a.9.9 0 0 1-.9.9h-1.2a.9.9 0 0 1-.9-.9V5.4ZM16.5 5.4a.9.9 0 0 1 .9-.9h1.2a.9.9 0 0 1 .9.9v1.2a.9.9 0 0 1-.9.9h-1.2a.9.9 0 0 1-.9-.9V5.4ZM4.5 11.4a.9.9 0 0 1 .9-.9h1.2a.9.9 0 0 1 .9.9v1.2a.9.9 0 0 1-.9.9H5.4a.9.9 0 0 1-.9-.9v-1.2ZM10.5 11.4a.9.9 0 0 1 .9-.9h1.2a.9.9 0 0 1 .9.9v1.2a.9.9 0 0 1-.9.9h-1.2a.9.9 0 0 1-.9-.9v-1.2ZM16.5 11.4a.9.9 0 0 1 .9-.9h1.2a.9.9 0 0 1 .9.9v1.2a.9.9 0 0 1-.9.9h-1.2a.9.9 0 0 1-.9-.9v-1.2ZM4.5 17.4a.9.9 0 0 1 .9-.9h1.2a.9.9 0 0 1 .9.9v1.2a.9.9 0 0 1-.9.9H5.4a.9.9 0 0 1-.9-.9v-1.2ZM10.5 17.4a.9.9 0 0 1 .9-.9h1.2a.9.9 0 0 1 .9.9v1.2a.9.9 0 0 1-.9.9h-1.2a.9.9 0 0 1-.9-.9v-1.2ZM16.5 17.4a.9.9 0 0 1 .9-.9h1.2a.9.9 0 0 1 .9.9v1.2a.9.9 0 0 1-.9.9h-1.2a.9.9 0 0 1-.9-.9v-1.2Z',
      ],
      arrow_back: ['M19 12H5', 'M12 19l-7-7 7-7'],
      globe: [
        'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Z',
        'M3.6 9h16.8M3.6 15h16.8',
        'M12 3a14 14 0 0 1 0 18 14 14 0 0 1 0-18Z',
      ],
      layers: [
        'M12 3l8 4.5-8 4.5-8-4.5L12 3Z',
        'M4 12l8 4.5 8-4.5',
        'M4 16.5l8 4.5 8-4.5',
      ],
      spark: [
        'M10 3l1.6 4.4L16 9l-4.4 1.6L10 15l-1.6-4.4L4 9l4.4-1.6L10 3Z',
        'M18.5 3.5l.65 1.85 1.85.65-1.85.65-.65 1.85-.65-1.85-1.85-.65 1.85-.65.65-1.85Z',
        'M18 14.5l.55 1.45 1.45.55-1.45.55-.55 1.45-.55-1.45-1.45-.55 1.45-.55.55-1.45Z',
      ],
      chat: [
        'M4.5 6h15A1.5 1.5 0 0 1 21 7.5v8a1.5 1.5 0 0 1-1.5 1.5H8.5L4 20.5V7.5A1.5 1.5 0 0 1 5.5 6Z',
      ],
      trend: ['M3 17l6-6 4 4 8-8', 'M15 7h6v6'],
      campaign: [
        'M3 11v2a2 2 0 0 0 2 2h2l5 4V5L7 9H5a2 2 0 0 0-2 2Z',
        'M16 9a5 5 0 0 1 0 6',
      ],
      wallet: [
        'M4 7a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V7Z',
        'M16 12h4',
      ],
      handshake: ['M7 11l5-5 5 5', 'M4 14l4 4 4-3 4 3 4-4'],
      search: ['M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16Z', 'M20.5 20.5l-4-4'],
      bell: ['M18 8.5a6 6 0 1 0-12 0c0 6.5-2.5 8-2.5 8h17s-2.5-1.5-2.5-8', 'M13.7 20a2 2 0 0 1-3.4 0'],
      help: [
        'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Z',
        'M9.6 9.2a2.4 2.4 0 0 1 4.7.8c0 1.5-2.3 2-2.3 3.4',
        'M12 16.8h.01',
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

  function sk(doc, w, h, extraClass) {
    var cls = 'aj-sk' + (extraClass ? ' ' + extraClass : '');
    return el(doc, 'div', cls, 'width:' + w + ';height:' + h + ';');
  }

  function uiCard(doc, styleCss) {
    return el(doc, 'div', 'aj-card', styleCss);
  }

  function uiTabs(doc, count, height) {
    var box = el(doc, 'div', 'aj-tabs-box', height ? 'height:' + height + 'px;' : '');
    for (var i = 0; i < count; i++) {
      box.appendChild(sk(doc, '100%', '10px', 'aj-tab-item'));
    }
    return box;
  }

  function uiHeader(doc, title, subtitle, btnW) {
    var head = el(doc, 'div', 'aj-page-head');
    var left = el(doc, 'div', 'aj-col', 'gap:2px;flex:1;');
    if (title) {
      var t = el(doc, 'div', 'aj-page-title');
      t.textContent = title;
      left.appendChild(t);
    } else {
      left.appendChild(sk(doc, '148px', '18px'));
    }
    if (subtitle) {
      var s = el(doc, 'div', 'aj-page-sub');
      s.textContent = subtitle;
      left.appendChild(s);
    } else {
      left.appendChild(sk(doc, '210px', '11px'));
    }
    head.appendChild(left);
    head.appendChild(sk(doc, (btnW || 84) + 'px', '30px', 'aj-sk-lg'));
    return head;
  }

  function uiMetricCard(doc) {
    var c = uiCard(doc, 'padding:12px 14px;gap:0;');
    var top = el(doc, 'div', 'aj-row-between');
    top.appendChild(sk(doc, '68px', '10px'));
    top.appendChild(sk(doc, '14px', '14px', 'aj-sk-circle'));
    c.appendChild(top);
    c.appendChild(el(doc, 'div', '', 'height:10px;'));
    c.appendChild(sk(doc, '92px', '18px'));
    c.appendChild(el(doc, 'div', '', 'height:8px;'));
    var foot = el(doc, 'div', 'aj-row');
    foot.appendChild(sk(doc, '44px', '16px', 'aj-sk-pill'));
    foot.appendChild(sk(doc, '48px', '9px'));
    c.appendChild(foot);
    return c;
  }

  function uiChartCard(doc, chartHeight) {
    var c = uiCard(doc, 'padding:12px 14px;gap:12px;');
    var head = el(doc, 'div', 'aj-row-between');
    var left = el(doc, 'div', 'aj-col', 'gap:4px;');
    left.appendChild(sk(doc, '96px', '11px'));
    left.appendChild(sk(doc, '132px', '18px'));
    head.appendChild(left);
    head.appendChild(sk(doc, '84px', '24px', 'aj-sk-pill'));
    c.appendChild(head);
    c.appendChild(sk(doc, '100%', (chartHeight || 136) + 'px', 'aj-sk-lg'));
    return c;
  }

  function uiListItem(doc, showTrailing) {
    var c = uiCard(doc, 'padding:10px 14px;flex-direction:row;align-items:center;gap:12px;');
    c.appendChild(sk(doc, '34px', '34px', 'aj-sk-circle'));
    var col = el(doc, 'div', 'aj-col', 'flex:1;gap:5px;');
    col.appendChild(sk(doc, '124px', '12px'));
    col.appendChild(sk(doc, '172px', '10px'));
    c.appendChild(col);
    if (showTrailing !== false) {
      c.appendChild(sk(doc, '52px', '20px', 'aj-sk-pill'));
    }
    return c;
  }

  function uiIdentityCard(doc) {
    var c = uiCard(doc, 'padding:12px 14px;gap:10px;');
    var row = el(doc, 'div', 'aj-row');
    row.appendChild(sk(doc, '44px', '44px', 'aj-sk-circle'));
    var col = el(doc, 'div', 'aj-col', 'flex:1;gap:5px;');
    col.appendChild(sk(doc, '140px', '14px'));
    col.appendChild(sk(doc, '96px', '10px'));
    row.appendChild(col);
    c.appendChild(row);
    c.appendChild(sk(doc, '100%', '28px', 'aj-sk-lg'));
    return c;
  }

  function buildDashboard(doc, spec) {
    var frag = doc.createDocumentFragment();
    frag.appendChild(uiHeader(doc, spec.label, spec.subtitle, 84));
    var grid = el(doc, 'div', 'aj-metrics-4');
    for (var i = 0; i < 4; i++) grid.appendChild(uiMetricCard(doc));
    frag.appendChild(grid);
    frag.appendChild(uiChartCard(doc, 148));
    for (var j = 0; j < 4; j++) frag.appendChild(uiListItem(doc, true));
    return frag;
  }

  function buildJournal(doc, spec) {
    var frag = doc.createDocumentFragment();
    frag.appendChild(uiHeader(doc, spec.label, spec.subtitle, 88));
    frag.appendChild(uiTabs(doc, 4, 34));
    var stripCard = uiCard(doc, 'padding:10px 14px;');
    var strip = el(doc, 'div', 'aj-heat-strip');
    for (var d = 0; d < 7; d++) strip.appendChild(sk(doc, '32px', '42px', 'aj-sk-lg'));
    stripCard.appendChild(strip);
    frag.appendChild(stripCard);
    for (var i = 0; i < 5; i++) frag.appendChild(uiListItem(doc, true));
    return frag;
  }

  function buildStrategies(doc, spec) {
    var frag = doc.createDocumentFragment();
    frag.appendChild(uiHeader(doc, spec.label, spec.subtitle, 96));
    var kpis = el(doc, 'div', 'aj-metrics-2');
    kpis.appendChild(uiMetricCard(doc));
    kpis.appendChild(uiMetricCard(doc));
    frag.appendChild(kpis);
    for (var i = 0; i < 4; i++) {
      var c = uiCard(doc, 'padding:12px 14px;gap:8px;');
      var top = el(doc, 'div', 'aj-row-between');
      top.appendChild(sk(doc, '128px', '13px'));
      top.appendChild(sk(doc, '54px', '18px', 'aj-sk-pill'));
      c.appendChild(top);
      c.appendChild(sk(doc, '92%', '11px'));
      c.appendChild(sk(doc, '62%', '11px'));
      var foot = el(doc, 'div', 'aj-row-between');
      foot.appendChild(sk(doc, '72px', '10px'));
      foot.appendChild(sk(doc, '72px', '10px'));
      foot.appendChild(sk(doc, '72px', '10px'));
      c.appendChild(foot);
      frag.appendChild(c);
    }
    return frag;
  }

  function buildWatchlists(doc, spec) {
    var frag = doc.createDocumentFragment();
    frag.appendChild(uiHeader(doc, spec.label, spec.subtitle, 78));
    var pills = el(doc, 'div', 'aj-row');
    pills.appendChild(sk(doc, '60px', '26px', 'aj-sk-pill'));
    pills.appendChild(sk(doc, '76px', '26px', 'aj-sk-pill'));
    pills.appendChild(sk(doc, '68px', '26px', 'aj-sk-pill'));
    pills.appendChild(sk(doc, '56px', '26px', 'aj-sk-pill'));
    frag.appendChild(pills);
    for (var i = 0; i < 6; i++) {
      var c = uiCard(doc, 'padding:10px 14px;flex-direction:row;align-items:center;gap:12px;');
      c.appendChild(sk(doc, '30px', '30px', 'aj-sk-circle'));
      var col = el(doc, 'div', 'aj-col', 'flex:1;gap:4px;');
      col.appendChild(sk(doc, '56px', '12px'));
      col.appendChild(sk(doc, '92px', '10px'));
      c.appendChild(col);
      c.appendChild(sk(doc, '56px', '18px'));
      var rt = el(doc, 'div', 'aj-col', 'align-items:flex-end;gap:4px;');
      rt.appendChild(sk(doc, '48px', '12px'));
      rt.appendChild(sk(doc, '42px', '16px', 'aj-sk-pill'));
      c.appendChild(rt);
      frag.appendChild(c);
    }
    return frag;
  }

  function buildMarket(doc) {
    var frag = doc.createDocumentFragment();
    var hCard = uiCard(doc, 'padding:10px 14px;flex-direction:row;align-items:center;gap:12px;');
    hCard.appendChild(sk(doc, '18px', '18px'));
    var hMid = el(doc, 'div', 'aj-col', 'flex:1;gap:4px;');
    var hTop = el(doc, 'div', 'aj-row');
    hTop.appendChild(sk(doc, '124px', '13px'));
    hTop.appendChild(sk(doc, '52px', '16px', 'aj-sk-pill'));
    hMid.appendChild(hTop);
    hMid.appendChild(sk(doc, '188px', '10px'));
    hCard.appendChild(hMid);
    hCard.appendChild(sk(doc, '16px', '16px', 'aj-sk-circle'));
    frag.appendChild(hCard);

    frag.appendChild(uiTabs(doc, 6, 34));

    var rib = el(doc, 'div', 'aj-ribbon');
    rib.appendChild(sk(doc, '64px', '22px', 'aj-sk-pill'));
    rib.appendChild(el(doc, 'div', 'aj-vdiv'));
    for (var r = 0; r < 4; r++) {
      var pair = el(doc, 'div', 'aj-row', 'gap:8px;');
      var txt = el(doc, 'div', 'aj-col', 'gap:3px;');
      txt.appendChild(sk(doc, '42px', '8px'));
      txt.appendChild(sk(doc, '48px', '10px'));
      pair.appendChild(txt);
      pair.appendChild(sk(doc, '28px', '16px'));
      rib.appendChild(pair);
    }
    frag.appendChild(rib);

    var split = el(doc, 'div', 'aj-market-split');
    var leftCol = el(doc, 'div', 'aj-col', 'gap:12px;');
    var idxCard = uiCard(doc, 'padding:12px 14px;gap:8px;');
    var idxHead = el(doc, 'div', 'aj-row-between');
    idxHead.appendChild(sk(doc, '124px', '14px'));
    idxHead.appendChild(sk(doc, '56px', '18px', 'aj-sk-pill'));
    idxCard.appendChild(idxHead);
    for (var i = 0; i < 5; i++) {
      var row = el(doc, 'div', 'aj-row-between', 'padding:6px 0;');
      row.appendChild(sk(doc, '82px', '11px'));
      var rt = el(doc, 'div', 'aj-row');
      rt.appendChild(sk(doc, '52px', '11px'));
      rt.appendChild(sk(doc, '44px', '11px'));
      rt.appendChild(sk(doc, '36px', '16px', 'aj-sk-pill'));
      row.appendChild(rt);
      idxCard.appendChild(row);
    }
    leftCol.appendChild(idxCard);

    var hmCard = uiCard(doc, 'padding:12px 14px;gap:8px;');
    hmCard.appendChild(sk(doc, '136px', '14px'));
    var mos = el(doc, 'div', 'aj-mosaic');
    mos.appendChild(sk(doc, '100%', '100%'));
    var mid = el(doc, 'div', 'aj-mosaic-mid');
    mid.appendChild(sk(doc, '100%', '100%'));
    mid.appendChild(sk(doc, '100%', '100%'));
    mos.appendChild(mid);
    mos.appendChild(sk(doc, '100%', '100%'));
    hmCard.appendChild(mos);
    leftCol.appendChild(hmCard);
    split.appendChild(leftCol);

    var rightCol = el(doc, 'div', 'aj-col', 'gap:12px;');
    rightCol.appendChild(uiChartCard(doc, 132));
    rightCol.appendChild(uiListItem(doc, true));
    rightCol.appendChild(uiListItem(doc, true));
    rightCol.appendChild(uiListItem(doc, true));
    split.appendChild(rightCol);

    frag.appendChild(split);
    return frag;
  }

  function buildCommunity(doc, isExplore) {
    var frag = doc.createDocumentFragment();
    var wrap = el(doc, 'div', 'aj-comm-wrap');
    var feed = el(doc, 'div', 'aj-comm-feed');

    if (isExplore) {
      feed.appendChild(uiTabs(doc, 4, 34));
    } else {
      var comp = uiCard(doc, 'padding:12px 14px;gap:8px;');
      comp.appendChild(sk(doc, '100%', '34px', 'aj-sk-pill'));
      var chips = el(doc, 'div', 'aj-row');
      chips.appendChild(sk(doc, '68px', '20px', 'aj-sk-pill'));
      chips.appendChild(sk(doc, '74px', '20px', 'aj-sk-pill'));
      chips.appendChild(sk(doc, '78px', '20px', 'aj-sk-pill'));
      chips.appendChild(sk(doc, '68px', '20px', 'aj-sk-pill'));
      comp.appendChild(chips);
      feed.appendChild(comp);
    }

    var p1 = uiCard(doc, 'padding:12px 14px;gap:10px;');
    var a1 = el(doc, 'div', 'aj-row');
    a1.appendChild(sk(doc, '32px', '32px', 'aj-sk-circle'));
    var m1 = el(doc, 'div', 'aj-col', 'flex:1;gap:4px;');
    m1.appendChild(sk(doc, '110px', '12px'));
    m1.appendChild(sk(doc, '72px', '9px'));
    a1.appendChild(m1);
    a1.appendChild(sk(doc, '44px', '16px', 'aj-sk-pill'));
    p1.appendChild(a1);
    p1.appendChild(sk(doc, '96%', '11px'));
    p1.appendChild(sk(doc, '68%', '11px'));
    p1.appendChild(sk(doc, '100%', '96px', 'aj-sk-lg'));
    var f1 = el(doc, 'div', 'aj-row-between');
    f1.appendChild(sk(doc, '40px', '12px', 'aj-sk-pill'));
    f1.appendChild(sk(doc, '40px', '12px', 'aj-sk-pill'));
    f1.appendChild(sk(doc, '40px', '12px', 'aj-sk-pill'));
    f1.appendChild(sk(doc, '32px', '12px', 'aj-sk-pill'));
    p1.appendChild(f1);
    feed.appendChild(p1);

    for (var pi = 0; pi < 2; pi++) {
      var p2 = uiCard(doc, 'padding:12px 14px;gap:10px;');
      var a2 = el(doc, 'div', 'aj-row');
      a2.appendChild(sk(doc, '32px', '32px', 'aj-sk-circle'));
      var m2 = el(doc, 'div', 'aj-col', 'flex:1;gap:4px;');
      m2.appendChild(sk(doc, '124px', '12px'));
      m2.appendChild(sk(doc, '82px', '9px'));
      a2.appendChild(m2);
      p2.appendChild(a2);
      p2.appendChild(sk(doc, '94%', '11px'));
      p2.appendChild(sk(doc, '84%', '11px'));
      p2.appendChild(sk(doc, '58%', '11px'));
      var tags = el(doc, 'div', 'aj-row');
      tags.appendChild(sk(doc, '50px', '18px', 'aj-sk-pill'));
      tags.appendChild(sk(doc, '64px', '18px', 'aj-sk-pill'));
      tags.appendChild(sk(doc, '58px', '18px', 'aj-sk-pill'));
      p2.appendChild(tags);
      var f2 = el(doc, 'div', 'aj-row-between');
      f2.appendChild(sk(doc, '40px', '12px', 'aj-sk-pill'));
      f2.appendChild(sk(doc, '40px', '12px', 'aj-sk-pill'));
      f2.appendChild(sk(doc, '40px', '12px', 'aj-sk-pill'));
      f2.appendChild(sk(doc, '32px', '12px', 'aj-sk-pill'));
      p2.appendChild(f2);
      feed.appendChild(p2);
    }

    wrap.appendChild(feed);

    var side = el(doc, 'div', 'aj-comm-side');
    side.appendChild(sk(doc, '100%', '34px', 'aj-sk-pill'));
    var tr = uiCard(doc, 'padding:12px 14px;gap:10px;');
    tr.appendChild(sk(doc, '108px', '12px'));
    for (var ti = 0; ti < 4; ti++) {
      var trow = el(doc, 'div', 'aj-row-between');
      trow.appendChild(sk(doc, '84px', '11px'));
      trow.appendChild(sk(doc, '36px', '9px'));
      tr.appendChild(trow);
    }
    side.appendChild(tr);

    var wf = uiCard(doc, 'padding:12px 14px;gap:10px;');
    wf.appendChild(sk(doc, '96px', '12px'));
    for (var wi = 0; wi < 3; wi++) {
      var wrow = el(doc, 'div', 'aj-row');
      wrow.appendChild(sk(doc, '30px', '30px', 'aj-sk-circle'));
      var wcol = el(doc, 'div', 'aj-col', 'flex:1;gap:3px;');
      wcol.appendChild(sk(doc, '78px', '11px'));
      wcol.appendChild(sk(doc, '50px', '9px'));
      wrow.appendChild(wcol);
      wrow.appendChild(sk(doc, '50px', '22px', 'aj-sk-pill'));
      wf.appendChild(wrow);
    }
    side.appendChild(wf);
    wrap.appendChild(side);

    frag.appendChild(wrap);
    return frag;
  }

  function buildProfilePreview(doc) {
    var frag = doc.createDocumentFragment();
    frag.appendChild(uiIdentityCard(doc));
    var badges = el(doc, 'div', 'aj-row');
    badges.appendChild(sk(doc, '72px', '20px', 'aj-sk-pill'));
    badges.appendChild(sk(doc, '88px', '20px', 'aj-sk-pill'));
    badges.appendChild(sk(doc, '60px', '20px', 'aj-sk-pill'));
    frag.appendChild(badges);
    var mRow = el(doc, 'div', 'aj-metrics-3');
    for (var i = 0; i < 3; i++) mRow.appendChild(uiMetricCard(doc));
    frag.appendChild(mRow);
    frag.appendChild(uiChartCard(doc, 136));
    frag.appendChild(uiListItem(doc, true));
    frag.appendChild(uiListItem(doc, true));
    return frag;
  }

  function buildMessages(doc) {
    var frag = doc.createDocumentFragment();
    frag.appendChild(sk(doc, '100%', '34px', 'aj-sk-pill'));
    for (var i = 0; i < 7; i++) frag.appendChild(uiListItem(doc, true));
    return frag;
  }

  function buildAi(doc, spec) {
    var frag = doc.createDocumentFragment();
    var left = el(doc, 'div', 'aj-col', 'gap:2px;');
    var t = el(doc, 'div', 'aj-page-title');
    t.textContent = spec.label;
    left.appendChild(t);
    var s = el(doc, 'div', 'aj-page-sub');
    s.textContent = spec.subtitle;
    left.appendChild(s);
    frag.appendChild(left);

    var prompt = uiCard(doc, 'padding:12px 14px;height:58px;flex-direction:row;align-items:center;gap:12px;');
    prompt.appendChild(sk(doc, '18px', '18px', 'aj-sk-circle'));
    prompt.appendChild(sk(doc, '160px', '12px'));
    var sp = el(doc, 'div', '', 'flex:1;');
    prompt.appendChild(sp);
    prompt.appendChild(sk(doc, '54px', '28px', 'aj-sk-pill'));
    frag.appendChild(prompt);

    for (var i = 0; i < 4; i++) {
      var ic = uiCard(doc, 'padding:12px 14px;gap:8px;');
      var top = el(doc, 'div', 'aj-row-between');
      top.appendChild(sk(doc, '118px', '12px'));
      top.appendChild(sk(doc, '60px', '18px', 'aj-sk-pill'));
      ic.appendChild(top);
      ic.appendChild(sk(doc, '92%', '11px'));
      ic.appendChild(sk(doc, '60%', '11px'));
      frag.appendChild(ic);
    }
    return frag;
  }

  function buildSettings(doc) {
    var frag = doc.createDocumentFragment();
    frag.appendChild(uiIdentityCard(doc));
    for (var g = 0; g < 3; g++) {
      var grp = el(doc, 'div', 'aj-col', 'gap:8px;margin-top:4px;');
      grp.appendChild(sk(doc, '104px', '10px'));
      for (var r = 0; r < 3; r++) {
        var row = uiCard(doc, 'padding:10px 14px;flex-direction:row;align-items:center;gap:12px;');
        row.appendChild(sk(doc, '28px', '28px', 'aj-sk-lg'));
        var col = el(doc, 'div', 'aj-col', 'flex:1;gap:5px;');
        col.appendChild(sk(doc, '132px', '11px'));
        col.appendChild(sk(doc, '78%', '9px'));
        row.appendChild(col);
        grp.appendChild(row);
      }
      frag.appendChild(grp);
    }
    return frag;
  }

  function buildGenericPage(doc, spec, showTabs) {
    var frag = doc.createDocumentFragment();
    frag.appendChild(uiHeader(doc, spec.label, spec.subtitle, 84));
    if (showTabs) frag.appendChild(uiTabs(doc, 3, 34));
    for (var i = 0; i < 6; i++) frag.appendChild(uiListItem(doc, true));
    return frag;
  }

  function buildBodyForSurface(doc, spec) {
    switch (spec.layoutKind) {
      case 'journal':
        return buildJournal(doc, spec);
      case 'strategies':
        return buildStrategies(doc, spec);
      case 'watchlists':
        return buildWatchlists(doc, spec);
      case 'market':
        return buildMarket(doc);
      case 'community':
        return buildCommunity(doc, false);
      case 'community_explore':
        return buildCommunity(doc, true);
      case 'network':
        return buildGenericPage(doc, spec, true);
      case 'profile_preview':
        return buildProfilePreview(doc);
      case 'messages':
        return buildMessages(doc);
      case 'ai':
        return buildAi(doc, spec);
      case 'settings':
        return buildSettings(doc);
      case 'page':
        return buildGenericPage(doc, spec, true);
      case 'dashboard':
      default:
        return buildDashboard(doc, spec);
    }
  }

  function renderInto(container, spec, theme, doc) {
    doc = doc || (typeof document !== 'undefined' ? document : null);
    if (!container || !doc) return;

    ensureStyles(doc);
    applyThemeVariables(theme, doc);

    var dockCfg = DOCKS[spec.dockVariant] || DOCKS.trader;
    var host = el(doc, 'div', 'aj-trans-host');
    host.setAttribute('data-surface', spec.surfaceKey);
    host.setAttribute('data-dock-variant', spec.dockVariant);
    host.setAttribute('data-active-slot', String(spec.activeSlot));

    // Desktop & Tablet Sidebar mirroring AppSidebar / AppWorkspaceTile
    var sidebar = el(doc, 'aside', 'aj-sidebar');
    var sHead = el(doc, 'div', 'aj-side-head');
    var badge = el(doc, 'div', 'aj-logo-badge');
    badge.textContent = 'α';
    sHead.appendChild(badge);
    var sBrand = el(doc, 'div', 'aj-side-brand');
    var bTitle = el(doc, 'div', 'aj-side-title');
    bTitle.textContent = 'alphajournal';
    sBrand.appendChild(bTitle);
    var bSub = el(doc, 'div', 'aj-side-plan');
    bSub.textContent = dockCfg.planLabel || 'Workspace';
    sBrand.appendChild(bSub);
    sHead.appendChild(sBrand);
    var sSwap = el(doc, 'div', 'aj-side-swap');
    sSwap.appendChild(svgIcon(doc, 'swap_vert', 14));
    sHead.appendChild(sSwap);
    sidebar.appendChild(sHead);

    var sNav = el(doc, 'div', 'aj-side-nav');
    var sections = dockCfg.sections || [];
    for (var sci = 0; sci < sections.length; sci++) {
      var sec = sections[sci];
      var secWrap = el(doc, 'div', 'aj-side-sec');
      var secTitle = el(doc, 'div', 'aj-side-sec-title');
      secTitle.textContent = sec.title;
      secWrap.appendChild(secTitle);
      for (var ii = 0; ii < sec.items.length; ii++) {
        var navItem = sec.items[ii];
        var subActive = false;
        if (navItem.subItems) {
          for (var sbi = 0; sbi < navItem.subItems.length; sbi++) {
            if (navItem.subItems[sbi].id === spec.activeNavId) subActive = true;
          }
        }
        var activeNav = navItem.id === spec.activeNavId;
        var itemEl = el(
          doc,
          'div',
          'aj-side-item' + (activeNav || subActive ? ' is-active' : '')
        );
        var left = el(doc, 'div', 'aj-side-item-left');
        left.appendChild(svgIcon(doc, navItem.icon, 17));
        var lblEl = el(doc, 'span', 'aj-side-item-label');
        lblEl.textContent = navItem.label;
        left.appendChild(lblEl);
        itemEl.appendChild(left);
        if (navItem.hasChevron) {
          var chev = el(doc, 'span', 'aj-side-chev');
          chev.textContent = (activeNav || subActive) && navItem.subItems ? '⌄' : '›';
          itemEl.appendChild(chev);
        }
        secWrap.appendChild(itemEl);

        if (navItem.subItems && (activeNav || subActive)) {
          var subWrap = el(doc, 'div', 'aj-side-subwrap');
          for (var si = 0; si < navItem.subItems.length; si++) {
            var sub = navItem.subItems[si];
            var subEl = el(
              doc,
              'div',
              'aj-side-sub' + (sub.id === spec.activeNavId ? ' is-active' : '')
            );
            subEl.textContent = sub.label;
            subWrap.appendChild(subEl);
          }
          secWrap.appendChild(subWrap);
        }
      }
      sNav.appendChild(secWrap);
    }
    sidebar.appendChild(sNav);

    var foot = el(doc, 'div', 'aj-side-foot');
    foot.appendChild(sk(doc, '30px', '30px', 'aj-sk-circle'));
    var fCol = el(doc, 'div', 'aj-col', 'flex:1;gap:4px;');
    fCol.appendChild(sk(doc, '86px', '10px'));
    fCol.appendChild(sk(doc, '62px', '9px'));
    foot.appendChild(fCol);
    var fSwap = el(doc, 'div', 'aj-side-swap');
    fSwap.appendChild(svgIcon(doc, 'swap_vert', 14));
    foot.appendChild(fSwap);
    sidebar.appendChild(foot);
    host.appendChild(sidebar);

    // Main workspace column: AppTopBar (UiCard wrapper) + rounded content surface frame
    var workspace = el(doc, 'div', 'aj-workspace');
    var topbar = el(doc, 'header', 'aj-topbar');
    var topCard = el(doc, 'div', 'aj-topbar-card');

    var tLeft = el(doc, 'div', 'aj-top-left');
    var mBtn = el(doc, 'div', 'aj-top-menu-icon');
    mBtn.appendChild(svgIcon(doc, 'menu', 16));
    tLeft.appendChild(mBtn);
    var titleEl = el(doc, 'span', 'aj-top-title');
    var desktopTitle = el(doc, 'span', 'aj-top-title-desktop');
    desktopTitle.textContent = spec.topTitle || spec.label;
    var mobileTitle = el(doc, 'span', 'aj-top-title-mobile');
    mobileTitle.textContent = spec.mobileTitle || spec.label;
    titleEl.appendChild(desktopTitle);
    titleEl.appendChild(mobileTitle);
    tLeft.appendChild(titleEl);
    topCard.appendChild(tLeft);

    var searchStub = el(doc, 'div', 'aj-search-stub');
    searchStub.appendChild(svgIcon(doc, 'search', 14));
    var sTxt = el(doc, 'span', 'aj-search-txt');
    sTxt.textContent = dockCfg.searchPlaceholder || 'Search...';
    searchStub.appendChild(sTxt);
    topCard.appendChild(searchStub);

    var tRight = el(doc, 'div', 'aj-top-right');
    var mSearchBtn = el(doc, 'div', 'aj-icon-btn aj-mobile-only');
    mSearchBtn.appendChild(svgIcon(doc, 'search', 16));
    tRight.appendChild(mSearchBtn);
    var calcBtn = el(doc, 'div', 'aj-icon-btn aj-desktop-only');
    calcBtn.appendChild(svgIcon(doc, 'calc', 16));
    tRight.appendChild(calcBtn);
    var bellBtn = el(doc, 'div', 'aj-icon-btn');
    bellBtn.appendChild(svgIcon(doc, 'bell', 16));
    tRight.appendChild(bellBtn);
    var helpBtn = el(doc, 'div', 'aj-icon-btn');
    helpBtn.appendChild(svgIcon(doc, 'help', 16));
    tRight.appendChild(helpBtn);
    topCard.appendChild(tRight);

    topbar.appendChild(topCard);
    workspace.appendChild(topbar);

    var frame = el(doc, 'div', 'aj-content-frame');
    var scroll = el(doc, 'div', 'aj-scroll');
    var inner = el(doc, 'div', 'aj-container');
    inner.appendChild(buildBodyForSurface(doc, spec));
    scroll.appendChild(inner);
    frame.appendChild(scroll);
    workspace.appendChild(frame);
    host.appendChild(workspace);

    // Exact QuietDockScaffold floating capsule (280x56, radius 28, margin 16, 5 equal 1fr slots, icons only)
    var dockWrap = el(doc, 'div', 'aj-dock-wrap');
    var dock = el(doc, 'nav', 'aj-dock');
    dock.setAttribute('aria-label', 'Primary Navigation');

    for (var di = 0; di < dockCfg.items.length; di++) {
      if (di === 2) {
        var centerSlot = el(
          doc,
          'div',
          'aj-dock-slot aj-dock-center' + (spec.centerActive ? ' is-active' : '')
        );
        centerSlot.setAttribute('aria-label', dockCfg.centerLabel);
        if (spec.centerActive) {
          centerSlot.setAttribute('aria-current', 'page');
          centerSlot.appendChild(el(doc, 'div', 'aj-dock-pill'));
        }
        var cIconWrap = el(doc, 'div', 'aj-dock-icon');
        cIconWrap.appendChild(
          svgIcon(
            doc,
            spec.centerActive && spec.centerRouteIcon
              ? spec.centerRouteIcon
              : dockCfg.centerIcon,
            22
          )
        );
        centerSlot.appendChild(cIconWrap);
        if (spec.centerActive) {
          var bArrow = el(doc, 'div', 'aj-dock-back');
          bArrow.appendChild(svgIcon(doc, 'arrow_back', 11));
          centerSlot.appendChild(bArrow);
        }
        dock.appendChild(centerSlot);
      }
      var dItem = dockCfg.items[di];
      var isSelected = !spec.centerActive && di === spec.activeSlot;
      var slotEl = el(
        doc,
        'div',
        'aj-dock-slot aj-dock-item' + (isSelected ? ' is-active' : '')
      );
      slotEl.setAttribute('aria-label', dItem.label);
      if (isSelected) {
        slotEl.setAttribute('aria-current', 'page');
        slotEl.appendChild(el(doc, 'div', 'aj-dock-pill'));
      }
      var iconWrap = el(doc, 'div', 'aj-dock-icon');
      iconWrap.appendChild(svgIcon(doc, dItem.icon, 22));
      slotEl.appendChild(iconWrap);
      dock.appendChild(slotEl);
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
    // Only authenticated sessions may render the app UI skeleton across
    // subdomains; cookie-consent (`ax_onboard`), logged-out visitors, new
    // users, OAuth callbacks, and auth screens must show the default splash.
    var hasActiveSession =
      Boolean(readCookie('ax_sb_auth.n')) &&
      readCookie('ax_sb_auth_off') !== '1';
    var isAuthRoute = isAuthOrPublicRoute(
      curHost,
      location.pathname,
      location.search,
      location.hash,
    );
    var isSilent =
      hasActiveSession &&
      !isAuthRoute &&
      !silent.isSuppressed &&
      (silent.hasFlag ||
        (sameRootRef && sameRootCur && Boolean(refHost) && refHost !== curHost));

    var rootEl = document.documentElement;
    if (rootEl) {
      if (isSilent) {
        rootEl.classList.add('aj-silent-nav');
        window.__ajSilentNav = true;
        window.__ajSilentRaw = silentRaw;
        window.__ajSilentLabel = silent.label;
      } else {
        rootEl.classList.remove('aj-silent-nav');
        window.__ajSilentNav = false;
        window.__ajSilentRaw = '';
        window.__ajSilentLabel = '';
      }
    }

    if (silent.hasFlag || silent.isSuppressed) {
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

    var existing = document.getElementById(VEIL_ID);
    if (existing && existing.parentNode) {
      existing.parentNode.removeChild(existing);
    }
    var hasActiveSession =
      Boolean(readCookie('ax_sb_auth.n')) &&
      readCookie('ax_sb_auth_off') !== '1';
    if (!hasActiveSession || isAuthOrPublicUrl(url || '')) {
      return null;
    }

    var spec = resolveSurface({ url: url || '' });
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
