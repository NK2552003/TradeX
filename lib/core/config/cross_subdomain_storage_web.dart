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
  try {
    return web.window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void setSharedFlag(String key, String value, {int maxAgeDays = 30}) {
  try {
    web.window.localStorage.setItem(key, value);
  } catch (_) {}
  if (!SubdomainCookieCodec.isProductionDomain(web.window.location.hostname)) {
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

void navigateBrowserUrl(String url) {
  web.window.location.assign(url);
}
