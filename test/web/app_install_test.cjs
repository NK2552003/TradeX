const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync('web/app_install.js', 'utf8');
function browser({blocked = false, installed = false} = {}) {
  const handlers = {};
  const storage = new Map();
  let now = 2000000000000;
  const window = {matchMedia: () => ({matches: installed, addEventListener: (name, fn) => handlers.display = fn}), addEventListener: (name, fn) => handlers[name] = fn};
  vm.runInNewContext(source, {window, navigator: {}, Set, Number, JSON, Date: {now: () => now}, localStorage: {getItem: k => {if (blocked) throw Error(); return storage.get(k);}, setItem: (k,v) => {if (blocked) throw Error(); storage.set(k,v);}}});
  return {api: window.alphajournalInstall, handlers, advance: ms => now += ms, state: () => JSON.parse(window.alphajournalInstall.snapshot())};
}
function offer(b, outcome = 'accepted') {
  let calls = 0;
  b.handlers.beforeinstallprompt({preventDefault() {}, prompt: async () => {calls++;}, userChoice: Promise.resolve({outcome})});
  return () => calls;
}
test('late event enables install and each browser event is consumed only once', async () => {
  const b = browser();
  assert.equal(b.state().available, false);
  const calls = offer(b);
  assert.equal(b.state().canSuggest, true);
  assert.equal(await b.api.prompt(), 'accepted');
  assert.equal(await b.api.prompt(), 'unavailable');
  assert.equal(calls(), 1);
  assert.equal(b.state().installed, false);
  b.handlers.appinstalled();
  assert.equal(b.state().installed, true);
});
test('dismissal cooldown survives blocked storage in memory', () => {
  const b = browser({blocked: true}); offer(b); b.api.dismiss();
  assert.equal(b.state().canSuggest, false);
  b.advance(7*86400000);
  assert.equal(b.state().canSuggest, true);
});
test('standalone suppresses prompts and failures allow later browser events', async () => {
  const installed = browser({installed: true}); offer(installed);
  assert.equal(installed.state().available, false);
  const b = browser();
  b.handlers.beforeinstallprompt({preventDefault() {}, prompt: async () => {throw Error('cancel');}});
  assert.equal(await b.api.prompt(), 'error');
  offer(b, 'dismissed');
  assert.equal(await b.api.prompt(), 'dismissed');
});
