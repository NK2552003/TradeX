(() => {
  'use strict';

  let reloading = false;

  const clearFlutterCaches = async () => {
    if (!('caches' in window)) return;
    const names = await caches.keys();
    await Promise.all(
      names
        .filter(name => name.startsWith('flutter-'))
        .map(name => caches.delete(name)),
    );
  };

  const removeLegacyWorkers = async () => {
    if (!('serviceWorker' in navigator)) return;
    const registrations = await navigator.serviceWorker.getRegistrations();
    await Promise.all(
      registrations
        .filter(registration => {
          const worker =
            registration.active ||
            registration.waiting ||
            registration.installing;
          return worker && worker.scriptURL.endsWith('/flutter_service_worker.js');
        })
        .map(registration => registration.unregister()),
    );
  };

  window.alphajournalUpdate = {
    async reload() {
      if (reloading) return true;
      reloading = true;
      try {
        await Promise.all([clearFlutterCaches(), removeLegacyWorkers()]);
      } catch (_) {
        // Reloading is still the safe fallback when browser cache APIs fail.
      }
      const target = new URL(window.location.href);
      target.searchParams.set('app_version_refresh', Date.now().toString());
      window.location.replace(target.toString());
      return true;
    },
  };
})();
