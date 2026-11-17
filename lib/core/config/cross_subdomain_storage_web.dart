import 'dart:js_interop';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/config/subdomain_cookie_codec.dart';
import 'package:web/web.dart' as web;

@JS('alphajournalTransition')
external _JsNavTransition? get _jsNavTransition;

extension type _JsNavTransition._(JSObject _) implements JSObject {
  external void syncTheme(String mode, String density, bool isLight);
}

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
    const domain = '.${SubdomainCookieCodec.rootDomain}';
    final secure = _isSecureContext;
    // Always clear any prior signed-out marker before storing chunks so large
    // OAuth sessions are never invalidated on the next read by a stale marker.
    web.document.cookie = SubdomainCookieCodec.formatDeleteCookie(
      _signedOutCookie,
      domain: domain,
      secure: secure,
    );
    final chunks = SubdomainCookieCodec.splitForCookies(value);
    if (chunks.isEmpty || chunks.length > SubdomainCookieCodec.maxChunks) {
      return;
    }
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

String? getLocalPreferenceFallback(String key) {
  try {
    final direct = web.window.localStorage.getItem(key);
    if (direct != null && direct.isNotEmpty) return direct;
    final pref = web.window.localStorage.getItem('flutter.$key');
    if (pref == null || pref.isEmpty) return null;
    final trimmed = pref.trim();
    if (trimmed.length >= 2 &&
        trimmed.startsWith('"') &&
        trimmed.endsWith('"')) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed;
  } catch (_) {
    return null;
  }
}

void setSharedFlag(String key, String value, {int maxAgeDays = 30}) {
  final isProd = SubdomainCookieCodec.isProductionDomain(
    web.window.location.hostname,
  );
  final isAppearancePref =
      key == 'ax_theme_mode' ||
      key == 'ax_theme_density' ||
      key == 'ax_chart_range' ||
      key == 'ax_chart_style' ||
      key == 'ax_chart_colors';
  if (!isProd || !web.window.navigator.cookieEnabled || isAppearancePref) {
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {}
  }
  if (!isProd) {
    return;
  }
  final secure = web.window.location.protocol == 'https:';
  // Expire any host-only cookie first so it cannot shadow `.alphajournal.in`.
  web.document.cookie = SubdomainCookieCodec.formatDeleteCookie(
    key,
    secure: secure,
  );
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
    secure: secure,
  );
  web.document.cookie = SubdomainCookieCodec.formatDeleteCookie(
    key,
    domain: '.${SubdomainCookieCodec.rootDomain}',
    secure: secure,
  );
}

void syncWebTheme({
  required String mode,
  required String density,
  required bool isLight,
}) {
  try {
    final transition = _jsNavTransition;
    if (transition != null) {
      transition.syncTheme(mode, density, isLight);
      return;
    }
  } catch (_) {}

  try {
    final doc = web.document;
    final rootEl = doc.documentElement;
    final bg = isLight ? '#FAFAF9' : '#0D0C0B';
    final fg = isLight ? '#151312' : '#FAFAF9';
    if (rootEl != null) {
      if (isLight) {
        rootEl.classList.add('aj-light');
      } else {
        rootEl.classList.remove('aj-light');
      }
      if (rootEl.isA<web.HTMLElement>()) {
        final htmlEl = rootEl as web.HTMLElement;
        htmlEl.style.colorScheme = isLight ? 'light' : 'dark';
        htmlEl.style.setProperty('--aj-bg', bg);
        htmlEl.style.setProperty('--aj-fg', fg);
      }
    }
    doc.body?.style.backgroundColor = bg;
    final meta = doc.querySelector('meta[name="theme-color"]');
    meta?.setAttribute('content', bg);
  } catch (_) {}
}

void navigateBrowserUrl(String url) {
  final silentValue = SubdomainCookieCodec.silentNavValueForUrl(url);
  final cookies = SubdomainCookieCodec.parseCookieString(web.document.cookie);
  final bool hasActiveSession =
      (cookies['ax_sb_auth.n']?.isNotEmpty ?? false) &&
      cookies['ax_sb_auth_off'] != '1';
  final bool useSilentNavigation = hasActiveSession && silentValue != '0';
  if (SubdomainCookieCodec.isProductionDomain(web.window.location.hostname)) {
    final secure = web.window.location.protocol == 'https:';
    web.document.cookie = SubdomainCookieCodec.formatDeleteCookie(
      'ax_silent_nav',
      secure: secure,
    );
    if (useSilentNavigation) {
      web.document.cookie = SubdomainCookieCodec.formatSetCookie(
        'ax_silent_nav',
        silentValue,
        domain: '.${SubdomainCookieCodec.rootDomain}',
        maxAgeSeconds: 20,
        secure: secure,
      );
    } else {
      web.document.cookie = SubdomainCookieCodec.formatDeleteCookie(
        'ax_silent_nav',
        domain: '.${SubdomainCookieCodec.rootDomain}',
        secure: secure,
      );
    }
  }
  web.window.location.assign(url);
}
