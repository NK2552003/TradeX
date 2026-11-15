import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/config/subdomain_cookie_codec.dart';
import 'package:web/web.dart' as web;

/// Web Supabase [LocalStorage] that persists the session in chunked cookies on
/// `.alphajournal.in` (as well as `window.localStorage`) so users signed in on
/// any subdomain (`alphajournal.in`, `app.`, `community.`, `affiliate.`,
/// `admin.`) remain signed in across all of them without re-authenticating.
class CrossSubdomainLocalStorage extends LocalStorage {
  CrossSubdomainLocalStorage({required this.persistSessionKey});

  factory CrossSubdomainLocalStorage.forUrl(String supabaseUrl) {
    final host = Uri.tryParse(supabaseUrl)?.host ?? '';
    final ref = host.isNotEmpty ? host.split('.').first : 'local';
    return CrossSubdomainLocalStorage(persistSessionKey: 'sb-$ref-auth-token');
  }

  final String persistSessionKey;

  static const String _cookieBase = 'ax_sb_auth';
  static const String _signedOutCookie = 'ax_sb_auth_off';
  static const int _sessionCookieMaxAgeSeconds = 60 * 60 * 24 * 30;

  bool get _isProdDomain =>
      SubdomainCookieCodec.isProductionDomain(web.window.location.hostname);

  bool get _isSecureContext => web.window.location.protocol == 'https:';

  @override
  Future<void> initialize() async {}

  String? _readRawSync() {
    if (_isProdDomain) {
      final cookies = SubdomainCookieCodec.parseCookieString(
        web.document.cookie,
      );
      if (cookies[_signedOutCookie] == '1') {
        try {
          web.window.localStorage.removeItem(persistSessionKey);
        } catch (_) {}
        return null;
      }
      final fromCookie = SubdomainCookieCodec.readChunked(cookies, _cookieBase);
      if (fromCookie != null && fromCookie.isNotEmpty) {
        // Keep local origin cache synchronized.
        try {
          if (web.window.localStorage.getItem(persistSessionKey) !=
              fromCookie) {
            web.window.localStorage.setItem(persistSessionKey, fromCookie);
          }
        } catch (_) {}
        return fromCookie;
      }
    }

    // Fallback to origin localStorage (localhost / preview deploy / first-time
    // migration from pre-subdomain deploys) and promote to shared cookie.
    try {
      final localValue = web.window.localStorage.getItem(persistSessionKey);
      if (localValue != null && localValue.isNotEmpty) {
        if (_isProdDomain) {
          _writeCookieChunks(localValue);
        }
        return localValue;
      }
    } catch (_) {}
    return null;
  }

  void _writeCookieChunks(String value) {
    final chunks = SubdomainCookieCodec.splitForCookies(value);
    if (chunks.isEmpty || chunks.length > SubdomainCookieCodec.maxChunks) {
      return;
    }
    const domain = '.${SubdomainCookieCodec.rootDomain}';
    final secure = _isSecureContext;
    web.document.cookie = SubdomainCookieCodec.formatDeleteCookie(
      _signedOutCookie,
      domain: domain,
      secure: secure,
    );
    for (var i = 0; i < chunks.length; i++) {
      web.document.cookie = SubdomainCookieCodec.formatSetCookie(
        '$_cookieBase.$i',
        chunks[i],
        domain: domain,
        maxAgeSeconds: _sessionCookieMaxAgeSeconds,
        secure: secure,
      );
    }
    web.document.cookie = SubdomainCookieCodec.formatSetCookie(
      '$_cookieBase.n',
      '${chunks.length}',
      domain: domain,
      maxAgeSeconds: _sessionCookieMaxAgeSeconds,
      secure: secure,
    );
    for (var i = chunks.length; i < SubdomainCookieCodec.maxChunks; i++) {
      web.document.cookie = SubdomainCookieCodec.formatDeleteCookie(
        '$_cookieBase.$i',
        domain: domain,
        secure: secure,
      );
    }
  }

  void _clearCookieChunks() {
    const domain = '.${SubdomainCookieCodec.rootDomain}';
    final secure = _isSecureContext;
    web.document.cookie = SubdomainCookieCodec.formatSetCookie(
      _signedOutCookie,
      '1',
      domain: domain,
      maxAgeSeconds: _sessionCookieMaxAgeSeconds,
      secure: secure,
    );
    web.document.cookie = SubdomainCookieCodec.formatDeleteCookie(
      '$_cookieBase.n',
      domain: domain,
      secure: secure,
    );
    for (var i = 0; i < SubdomainCookieCodec.maxChunks; i++) {
      web.document.cookie = SubdomainCookieCodec.formatDeleteCookie(
        '$_cookieBase.$i',
        domain: domain,
        secure: secure,
      );
    }
  }

  @override
  Future<bool> hasAccessToken() async => _readRawSync() != null;

  @override
  Future<String?> accessToken() async => _readRawSync();

  @override
  Future<void> removePersistedSession() async {
    try {
      web.window.localStorage.removeItem(persistSessionKey);
    } catch (_) {}
    if (_isProdDomain) {
      _clearCookieChunks();
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      web.window.localStorage.setItem(persistSessionKey, persistSessionString);
    } catch (_) {}
    if (_isProdDomain) {
      _writeCookieChunks(persistSessionString);
    }
  }
}

String? getSharedFlag(String key) {
  final cookies = SubdomainCookieCodec.parseCookieString(web.document.cookie);
  final fromCookie = cookies[key];
  if (fromCookie != null && fromCookie.isNotEmpty) return fromCookie;
  final isProd = SubdomainCookieCodec.isProductionDomain(
    web.window.location.hostname,
  );
  if (isProd && web.window.navigator.cookieEnabled) {
    // On production *.alphajournal.in hosts, cookies are authoritative so a flag
    // cleared on one subdomain cannot be resurrected by another origin's stale
    // localStorage entry.
    return null;
  }
  try {
    return web.window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void setSharedFlag(String key, String value, {int maxAgeDays = 30}) {
  final isProd = SubdomainCookieCodec.isProductionDomain(
    web.window.location.hostname,
  );
  if (!isProd || !web.window.navigator.cookieEnabled) {
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {}
  }
  if (!isProd) {
    return;
  }
  final secure = web.window.location.protocol == 'https:';
  web.document.cookie = SubdomainCookieCodec.formatSetCookie(
    key,
    value,
    domain: '.${SubdomainCookieCodec.rootDomain}',
    maxAgeSeconds: 60 * 60 * 24 * maxAgeDays,
    secure: secure,
  );
}

void removeSharedFlag(String key) {
  try {
    web.window.localStorage.removeItem(key);
  } catch (_) {}
  if (!SubdomainCookieCodec.isProductionDomain(web.window.location.hostname)) {
    return;
  }
  final secure = web.window.location.protocol == 'https:';
  web.document.cookie = SubdomainCookieCodec.formatDeleteCookie(
    key,
    domain: '.${SubdomainCookieCodec.rootDomain}',
    secure: secure,
  );
}

String _surfaceLabelForUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return '';
  final host = uri.host.toLowerCase();
  final seg = uri.pathSegments.isEmpty
      ? ''
      : uri.pathSegments.first.toLowerCase();
  if (seg == 'market' || seg.startsWith('market_')) return 'Markets';
  if (seg == 'journal') return 'Journal';
  if (seg == 'strategies' || seg == 'strategy') return 'Strategies';
  if (seg == 'notes' || seg == 'note') return 'Notes';
  if (seg == 'messages' || seg == 'message' || seg == 'thread') {
    return 'Messages';
  }
  if (seg == 'ai_copilot' || seg == 'ai' || seg == 'copilot') {
    return 'AI Copilot';
  }
  if (seg.startsWith('settings')) return 'Settings';
  if (host.startsWith('community.') ||
      seg.startsWith('community') ||
      seg.startsWith('@') ||
      seg == 'p' ||
      seg == 'posts' ||
      seg == 'post') {
    return 'Community';
  }
  if (host.startsWith('affiliate.') ||
      seg.startsWith('affiliate') ||
      seg == 'referrals' ||
      seg == 'marketing' ||
      seg == 'payouts') {
    return 'Partner Hub';
  }
  if (host.startsWith('admin.') ||
      seg.startsWith('admin') ||
      seg.startsWith('org_')) {
    return 'Admin Console';
  }
  if (host.startsWith('app.') || seg == 'workspace') return 'Workspace';
  return '';
}

void _showOutgoingNavigationVeil(String label) {
  try {
    final doc = web.document;
    final body = doc.body;
    if (body == null) return;
    doc.getElementById('aj-nav-veil')?.remove();

    final isLight =
        doc.documentElement?.classList.contains('aj-light') ?? false;
    final bg = isLight ? 'rgba(250, 249, 246, 0.92)' : 'rgba(13, 12, 11, 0.92)';
    final fg = isLight ? '#0D0C0B' : '#FAF9F6';
    final border = isLight
        ? 'rgba(13, 12, 11, 0.10)'
        : 'rgba(250, 249, 246, 0.12)';
    final pillBg = isLight
        ? 'rgba(255, 255, 255, 0.85)'
        : 'rgba(24, 22, 20, 0.85)';

    final veil = doc.createElement('div') as web.HTMLElement;
    veil.id = 'aj-nav-veil';
    veil.style.cssText =
        'position:fixed;inset:0;z-index:999998;display:flex;align-items:center;'
        'justify-content:center;background:$bg;backdrop-filter:blur(10px);'
        '-webkit-backdrop-filter:blur(10px);opacity:0;'
        'transition:opacity 120ms cubic-bezier(0.22,1,0.36,1);'
        'pointer-events:auto;';

    final bar = doc.createElement('div') as web.HTMLElement;
    bar.style.cssText =
        'position:fixed;top:0;left:0;right:0;height:2px;'
        'background:linear-gradient(90deg,transparent 0%,#8B9FE8 50%,transparent 100%);';
    veil.appendChild(bar);

    if (label.isNotEmpty) {
      final pill = doc.createElement('div') as web.HTMLElement;
      pill.style.cssText =
          'display:inline-flex;align-items:center;gap:10px;padding:10px 16px;'
          'border-radius:999px;background:$pillBg;border:1px solid $border;'
          'color:$fg;font-family:system-ui,-apple-system,sans-serif;'
          'font-size:13px;font-weight:500;letter-spacing:0.01em;'
          'box-shadow:0 8px 24px rgba(0,0,0,0.18);';
      pill.textContent = 'Opening $label…';
      veil.appendChild(pill);
    }

    body.appendChild(veil);
    // Force layout flush so opacity transition runs immediately before navigation.
    veil.getBoundingClientRect();
    veil.style.opacity = '1';
  } catch (_) {}
}

void navigateBrowserUrl(String url) {
  final label = _surfaceLabelForUrl(url);
  if (SubdomainCookieCodec.isProductionDomain(web.window.location.hostname)) {
    final secure = web.window.location.protocol == 'https:';
    final value = label.isEmpty ? '1' : '1|$label';
    web.document.cookie = SubdomainCookieCodec.formatSetCookie(
      'ax_silent_nav',
      value,
      domain: '.${SubdomainCookieCodec.rootDomain}',
      maxAgeSeconds: 20,
      secure: secure,
    );
  }
  _showOutgoingNavigationVeil(label);
  web.window.location.assign(url);
}
