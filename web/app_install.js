/* Captured before Flutter starts; no tracking or network requests. */
(() => {
  'use strict';
  const key = 'alphajournal_install_dismissed_v1';
  const cooldown = 7 * 24 * 60 * 60 * 1000;
  const listeners = new Set();
  const display = window.matchMedia('(display-mode: standalone)');
  let pending = null;
  let busy = false;
  let installed = display.matches || navigator.standalone === true;
  let dismissedAt = 0;
  try { dismissedAt = Number(localStorage.getItem(key)) || 0; } catch (_) {}
  const snapshot = () => JSON.stringify({
    available: !!pending && !busy && !installed,
    installed,
    canSuggest: !!pending && !busy && !installed && Date.now() - dismissedAt >= cooldown,
  });
  const notify = () => listeners.forEach(fn => fn());
  const dismiss = () => {
    dismissedAt = Date.now();
    try { localStorage.setItem(key, String(dismissedAt)); } catch (_) {}
    notify();
  };
  window.addEventListener('beforeinstallprompt', event => {
    event.preventDefault();
    pending = event;
    notify();
  });
  window.addEventListener('appinstalled', () => {
    installed = true;
    pending = null;
    notify();
  });
  display.addEventListener('change', event => {
    installed = event.matches || navigator.standalone === true;
    notify();
  });
  window.alphajournalInstall = {
    snapshot,
    subscribe: fn => listeners.add(fn),
    dismiss,
    async prompt() {
      if (!pending || busy || installed) return 'unavailable';
      const event = pending;
      pending = null;
      busy = true;
      try {
        await event.prompt();
        const result = await event.userChoice;
        dismiss();
        return result.outcome; // Confirmation is reported only by appinstalled.
      } catch (_) {
        dismiss();
        return 'error';
      } finally {
        busy = false;
        notify();
      }
    },
  };
})();
