// Loaded before Flutter. Permission is requested directly from a user gesture.
(() => {
  const supported = () => window.isSecureContext && 'serviceWorker' in navigator &&
    'PushManager' in window && 'Notification' in window;
  const registration = () => navigator.serviceWorker.register('push-sw.js', {scope: './push/'});
  const active = async () => {
    const reg = await registration();
    if (!reg.active) await new Promise((resolve, reject) => {
      const worker = reg.installing || reg.waiting;
      if (!worker) return reject(new Error('Notification worker unavailable.'));
      worker.addEventListener('statechange', () => {
        if (worker.state === 'activated') resolve();
        if (worker.state === 'redundant') reject(new Error('Notification worker failed.'));
      });
    });
    return reg;
  };
  window.alphajournalPushSubscription = async () => {
    if (!supported() || Notification.permission !== 'granted') return '';
    const reg = await registration();
    const sub = await reg.pushManager.getSubscription();
    return sub ? JSON.stringify(sub.toJSON()) : '';
  };
  window.alphajournalPushStatus = async () => {
    if (!supported()) return 'unsupported';
    if (Notification.permission !== 'granted') return Notification.permission;
    const reg = await registration();
    return await reg.pushManager.getSubscription() ? 'subscribed' : 'default';
  };
  window.alphajournalPushEnable = async (publicKey) => {
    if (!supported()) throw new Error('Push is unavailable here. Use a supported browser over HTTPS.');
    if (!publicKey) throw new Error('Push delivery has not been configured yet.');
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') throw new Error('Notifications are blocked. Allow them in your browser site settings.');
    const reg = await active();
    let sub = await reg.pushManager.getSubscription();
    if (!sub) {
      const raw = atob(publicKey.replace(/-/g, '+').replace(/_/g, '/'));
      sub = await reg.pushManager.subscribe({userVisibleOnly: true,
        applicationServerKey: Uint8Array.from(raw, c => c.charCodeAt(0))});
    }
    return JSON.stringify(sub.toJSON());
  };
  window.alphajournalPushDisable = async () => {
    if (!supported()) return '';
    const reg = await registration();
    const sub = await reg.pushManager.getSubscription();
    if (!sub) return '';
    const endpoint = sub.endpoint;
    if (!await sub.unsubscribe()) throw new Error('Could not unsubscribe this browser. Try again.');
    return endpoint;
  };
})();
