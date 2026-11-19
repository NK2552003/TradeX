const {readFileSync} = require('node:fs');
const {join} = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
(async () => {
  let permission = 'default', requested = 0, subscribed = false;
  const sub = {endpoint: 'https://fcm.googleapis.com/send/test', toJSON: () => ({endpoint: sub.endpoint, keys: {auth: 'a', p256dh: 'b'}}),
    unsubscribe: async () => { subscribed = false; return true; }};
  const reg = {active: true, pushManager: {getSubscription: async () => subscribed ? sub : null,
    subscribe: async options => { assert(options.userVisibleOnly); subscribed = true; return sub; }}};
  const Notification = {get permission() {return permission;}, requestPermission: async () => {requested++; return permission;}};
  const context = {window: {isSecureContext: true, PushManager: {}, Notification}, Notification,
    navigator: {serviceWorker: {register: async (url, options) => {assert.equal(url, 'push-sw.js'); assert.equal(options.scope, './push/'); return reg;}}},
    Uint8Array, atob: value => Buffer.from(value, 'base64').toString('binary')};
  vm.runInNewContext(readFileSync(join(__dirname, '../web/push_notifications.js'), 'utf8'), context);
  assert.equal(await context.window.alphajournalPushStatus(), 'default');
  assert.equal(requested, 0);
  await assert.rejects(context.window.alphajournalPushEnable(''), /not been configured/);
  permission = 'denied';
  await assert.rejects(context.window.alphajournalPushEnable('AQID'), /blocked/);
  assert.equal(subscribed, false);
  permission = 'granted';
  assert.equal(JSON.parse(await context.window.alphajournalPushEnable('AQID')).endpoint, sub.endpoint);
  assert.equal(await context.window.alphajournalPushStatus(), 'subscribed');
  assert.equal(await context.window.alphajournalPushDisable(), sub.endpoint);
  assert.equal(await context.window.alphajournalPushStatus(), 'default');
  const handlers = {}; let shown;
  const worker = {self: {addEventListener: (event, fn) => handlers[event] = fn,
    registration: {scope: 'https://example.test/push/', showNotification: async (title, value) => {shown = {title, ...value};}},
    clients: {matchAll: async () => [], openWindow: async url => {assert.equal(url, 'https://example.test/');}}}, URL};
  vm.runInNewContext(readFileSync(join(__dirname, '../web/push-sw.js'), 'utf8'), worker);
  let done;
  handlers.push({data: {json: () => ({id:'one', body:'secret', url:'https://evil.test/'})}, waitUntil: promise => done = promise});
  await done;
  assert(!JSON.stringify(shown).includes('secret'));
  handlers.notificationclick({notification: {close() {}}, waitUntil: promise => done = promise});
  await done;
  console.log('Browser permission, registration, unsubscribe, private preview and safe click tests passed.');
})().catch(error => {console.error(error); process.exitCode = 1;});
