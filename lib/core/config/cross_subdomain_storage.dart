import 'cross_subdomain_storage_stub.dart'
    if (dart.library.js_interop) 'cross_subdomain_storage_web.dart'
    as impl;

export 'cross_subdomain_storage_stub.dart'
    if (dart.library.js_interop) 'cross_subdomain_storage_web.dart'
    show CrossSubdomainLocalStorage;

/// Synchronous lightweight state flags mirrored across `*.alphajournal.in`
/// cookies on Web (no-op on native platforms).
class CrossSubdomainState {
  const CrossSubdomainState._();

  static String? getFlag(String key) => impl.getSharedFlag(key);

  static void setFlag(String key, String value, {int maxAgeDays = 30}) =>
      impl.setSharedFlag(key, value, maxAgeDays: maxAgeDays);

  static void removeFlag(String key) => impl.removeSharedFlag(key);

  /// Navigates the top-level browser context to [url] (cross-origin subdomain).
  static void navigateExternal(String url) => impl.navigateBrowserUrl(url);
}
