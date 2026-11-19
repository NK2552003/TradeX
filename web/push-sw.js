self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('push', event => {
  let data = {};
  try { data = event.data?.json() || {}; } catch (_) { /* Never display raw payloads. */ }
  event.waitUntil(self.registration.showNotification('AlphaJournal', {
    body: 'You have new activity. Open AlphaJournal to view it.',
    tag: typeof data.id === 'string' ? data.id : 'activity',
    data: {url: new URL('../', self.registration.scope).href},
  }));
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil((async () => {
    const url = new URL('../', self.registration.scope).href;
    const clients = await self.clients.matchAll({type: 'window', includeUncontrolled: true});
    const client = clients.find(c => c.url.startsWith(url));
    if (client) return client.focus();
    return self.clients.openWindow(url);
  })());
});
