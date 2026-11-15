/* Captured before Flutter starts; no tracking or network requests. */
(() => {
  'use strict';
  const dismissKey = 'alphajournal_install_dismissed_v1';
  const installedKey = 'alphajournal_install_installed_v1';
  const rootDomain = 'alphajournal.in';
  const cooldown = 7 * 24 * 60 * 60 * 1000;
  const dismissCookieSeconds = 30 * 24 * 60 * 60;
  const installedCookieSeconds = 365 * 24 * 60 * 60;
  const listeners = new Set();
  const display = window.matchMedia('(display-mode: standalone)');
  let pending = null;
  let busy = false;
  let installed = display.matches || navigator.standalone === true;
  let dismissedAt = 0;

  const isProdHost = () => {
    try {
      if (typeof location === 'undefined') return false;
      const host = String(location.hostname || '').toLowerCase();
      return host === rootDomain || host.endsWith('.' + rootDomain);
    } catch (_) {
      return false;
    }
  };

  const readCookie = name => {
    try {
      if (typeof document === 'undefined' || !document.cookie) return '';
      const prefix = name + '=';
      const parts = document.cookie.split(';');
      for (let i = 0; i < parts.length; i++) {
        const part = parts[i].trim();
        if (part.startsWith(prefix)) {
          return decodeURIComponent(part.slice(prefix.length));
        }
      }
    } catch (_) {}
    return '';
  };

  const writeCookie = (name, value, maxAgeSeconds) => {
    try {
      if (typeof document === 'undefined') return;
      const attrs = [
        name + '=' + encodeURIComponent(String(value)),
        'Path=/',
        'SameSite=Lax',
        'Max-Age=' + String(maxAgeSeconds),
      ];
      if (isProdHost()) attrs.push('Domain=.' + rootDomain);
      if (typeof location !== 'undefined' && location.protocol === 'https:') {
        attrs.push('Secure');
      }
      document.cookie = attrs.join('; ');
    } catch (_) {}
  };

  const readStorage = name => {
    try {
      return typeof localStorage !== 'undefined' ? (localStorage.getItem(name) || '') : '';
    } catch (_) {
      return '';
    }
  };

  const writeStorage = (name, value) => {
    try {
      if (typeof localStorage !== 'undefined') localStorage.setItem(name, String(value));
    } catch (_) {}
  };

  const readDismissedAt = () => {
    const localTs = Number(readStorage(dismissKey)) || 0;
    const cookieTs = Number(readCookie(dismissKey)) || 0;
    return Math.max(dismissedAt, localTs, cookieTs);
  };

  const isInstalled = () =>
    installed ||
    display.matches ||
    navigator.standalone === true ||
    readStorage(installedKey) === '1' ||
    readCookie(installedKey) === '1';

  dismissedAt = readDismissedAt();
  if (dismissedAt > 0 && isProdHost() && !readCookie(dismissKey)) {
    writeCookie(dismissKey, String(dismissedAt), dismissCookieSeconds);
  }

  const snapshot = () => {
    const currentlyInstalled = isInstalled();
    const latestDismissedAt = readDismissedAt();
    return JSON.stringify({
      available: !!pending && !busy && !currentlyInstalled,
      installed: currentlyInstalled,
      canSuggest:
        !!pending &&
        !busy &&
        !currentlyInstalled &&
        Date.now() - latestDismissedAt >= cooldown,
    });
  };
  const notify = () => listeners.forEach(fn => fn());
  const dismiss = () => {
    dismissedAt = Date.now();
    writeStorage(dismissKey, String(dismissedAt));
    writeCookie(dismissKey, String(dismissedAt), dismissCookieSeconds);
    notify();
  };
  const markInstalled = () => {
    installed = true;
    pending = null;
    dismissedAt = Date.now();
    writeStorage(installedKey, '1');
    writeCookie(installedKey, '1', installedCookieSeconds);
    writeStorage(dismissKey, String(dismissedAt));
    writeCookie(dismissKey, String(dismissedAt), dismissCookieSeconds);
    notify();
  };
  window.addEventListener('beforeinstallprompt', event => {
    event.preventDefault();
    pending = event;
    notify();
  });
  window.addEventListener('appinstalled', markInstalled);
  display.addEventListener('change', event => {
    installed = event.matches || navigator.standalone === true;
    if (installed) {
      writeStorage(installedKey, '1');
      writeCookie(installedKey, '1', installedCookieSeconds);
    }
    notify();
  });
  window.addEventListener('focus', notify);
  window.addEventListener('storage', notify);
  if (typeof document !== 'undefined' && document.addEventListener) {
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') notify();
    });
  }
  window.alphajournalInstall = {
    snapshot,
    subscribe: fn => listeners.add(fn),
    dismiss,
    async prompt() {
      if (!pending || busy || isInstalled()) return 'unavailable';
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
