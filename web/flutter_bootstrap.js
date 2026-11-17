{{flutter_js}}
{{flutter_build_config}}

(() => {
  'use strict';

  const legacyWorkerPath = '/flutter_service_worker.js';
  const cleanupReloadKey = 'aj_flutter_worker_cleanup_v1';

  const workerScriptUrl = registration =>
    registration.active?.scriptURL ||
    registration.waiting?.scriptURL ||
    registration.installing?.scriptURL ||
    '';

  const isLegacyFlutterWorker = scriptUrl => {
    if (!scriptUrl) return false;
    try {
      return new URL(scriptUrl, window.location.href).pathname.endsWith(
        legacyWorkerPath,
      );
    } catch (_) {
      return false;
    }
  };

  const removeLegacyFlutterCache = async () => {
    if (!('caches' in window)) return;
    const cacheNames = await caches.keys();
    await Promise.all(
      cacheNames
        .filter(name => name.startsWith('flutter-'))
        .map(name => caches.delete(name)),
    );
  };

  const cleanupLegacyFlutterWorker = async () => {
    if (!('serviceWorker' in navigator)) return false;
    const wasControlled = isLegacyFlutterWorker(
      navigator.serviceWorker.controller?.scriptURL,
    );
    const registrations = await navigator.serviceWorker.getRegistrations();
    const legacyRegistrations = registrations.filter(registration =>
      isLegacyFlutterWorker(workerScriptUrl(registration)),
    );

    await Promise.all(
      legacyRegistrations.map(registration => registration.unregister()),
    );
    await removeLegacyFlutterCache();

    if (wasControlled && sessionStorage.getItem(cleanupReloadKey) !== '1') {
      sessionStorage.setItem(cleanupReloadKey, '1');
      window.location.reload();
      return true;
    }
    return false;
  };

  cleanupLegacyFlutterWorker()
    .then(reloaded => {
      if (!reloaded) _flutter.loader.load();
    })
    .catch(error => {
      console.warn('Legacy Flutter worker cleanup failed:', error);
      _flutter.loader.load();
    });
})();
