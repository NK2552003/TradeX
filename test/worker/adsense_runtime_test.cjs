const test = require('node:test');
const assert = require('node:assert/strict');
const create = require('../../web/adsense.js');
const publisherId = 'ca-pub-1234567890123456';
const configuration = {enabled: true, publisherId, slots: {feed_inline: '1234567890', community_rail: '9876543210'}};
const granted = {cmpStatus: 'loaded', eventStatus: 'tcloaded', gdprApplies: true,
  tcString: 'provider-supplied-tcf-string', listenerId: 1,
  purpose: {consents: {1: true, 3: true, 4: true}}, vendor: {consents: {755: true}}};
const allowed = {eligible: true, advertising: true, personalized: false, expiresAt: Date.now() + 600000};
class Element {
  style = {}; attrs = {}; children = []; isConnected = true;
  setAttribute(k, v) {this.attrs[k] = v;}
  getAttribute(k) {return this.attrs[k];}
  replaceChildren(...children) {this.children = children;}
  width = 728;
  getBoundingClientRect() {return {width: this.width};}
  remove() {this.isConnected = false;}
}
function setup({cmp = true, autoLoad = true, failScript = false} = {}) {
  const scripts = [], observers = [], resizes = [], mutations = [], timers = new Map();
  let cmpCallback, reloads = 0, nextTimer = 1;
  const win = {
    document: {head: {appendChild(el) {
      scripts.push(el);
      if (autoLoad) queueMicrotask(() => failScript ? el.onerror?.() : el.onload?.());
    }}, createElement: () => new Element()},
    location: {reload: () => reloads++},
    setTimeout: (cb) => {const id = nextTimer++; timers.set(id, cb); return id;},
    clearTimeout: id => timers.delete(id),
    setInterval: () => 50, clearInterval() {}, addEventListener() {},
    IntersectionObserver: class {constructor(cb) {this.cb = cb; observers.push(this);} observe() {this.cb([{isIntersecting: true}]);} disconnect() {}},
    ResizeObserver: class {constructor(cb) {this.cb = cb; resizes.push(this);} observe() {this.cb();} disconnect() {}},
    MutationObserver: class {constructor(cb) {this.cb = cb; mutations.push(this);} observe() {} disconnect() {}},
  };
  if (cmp) win.__tcfapi = (command, version, callback) => {
    if (command === 'addEventListener') {cmpCallback = callback; callback(granted, true);}
  };
  const api = create(win);
  api.configure(configuration);
  return {api, win, scripts, observers, resizes, mutations, timers,
    consent: (value) => cmpCallback?.(value, true),
    reloads: () => reloads,
    mount(placement = 'feed_inline', instanceId = placement) {
      const el = new Element(), states = [];
      api.mount(el, placement, 300, 250, value => states.push(value), instanceId);
      return {el, states};
    },
    sdk: () => scripts.filter(s => s.src.includes('adsbygoogle.js')),
  };
}
const flush = () => new Promise(resolve => setImmediate(resolve));

test('disabled configuration and rejected local consent make no network requests', async () => {
  for (const config of [{...configuration, enabled: false}, configuration]) {
    const f = setup(); f.api.configure(config);
    f.api.updateAccess({...allowed, advertising: false}); f.mount(); await flush();
    assert.equal(f.scripts.length, 0);
  }
});
test('unknown or paid account eligibility suppresses every request', async () => {
  const f = setup(); f.api.updateAccess({...allowed, eligible: false}); f.mount(); await flush();
  assert.equal(f.scripts.length, 0);
});
test('CMP missing or refusing Google/storage consent blocks the SDK', async () => {
  const missing = setup({cmp: false}); missing.api.updateAccess(allowed); missing.mount(); await flush();
  assert.equal(missing.sdk().length, 0);
  const f = setup({autoLoad: false}); f.api.updateAccess(allowed);
  f.win.__tcfapi = (c, v, callback) => callback({...granted, purpose: {consents: {1: false}}}, true);
  f.mount(); await flush(); assert.equal(f.sdk().length, 0);
});
test('SDK loads once, requests once per placement, and defaults to non-personalized', async () => {
  const f = setup(); f.api.updateAccess(allowed); f.mount(); f.mount('community_rail'); await flush();
  assert.equal(f.sdk().length, 1); assert.equal(f.win.adsbygoogle.length, 2);
  assert.equal(f.win.adsbygoogle.requestNonPersonalizedAds, 1);
  f.observers.forEach(o => o.cb([{isIntersecting: true}])); await flush();
  assert.equal(f.win.adsbygoogle.length, 2);
});
test('each five-post occurrence requests independently without repeating on remount', async () => {
  const f = setup(); f.api.updateAccess(allowed);
  f.mount('feed_inline', 'feed_inline:1');
  f.mount('feed_inline', 'feed_inline:3');
  f.mount('feed_inline', 'feed_inline:5');
  await flush();
  assert.equal(f.sdk().length, 1);
  assert.equal(f.win.adsbygoogle.length, 3);
  const duplicate = f.mount('feed_inline', 'feed_inline:1');
  f.observers.forEach(o => o.cb([{isIntersecting: true}]));
  await flush();
  assert.equal(f.win.adsbygoogle.length, 3);
  assert.ok(duplicate.states.includes('unfilled'));
});
test('feed ads fill the parent column and resize without another request', async () => {
  const f = setup(); f.api.updateAccess(allowed);
  const ad = f.mount(); await flush();
  const ins = ad.el.children[0];
  assert.equal(ad.el.style.width, '100%');
  assert.equal(ins.style.width, '100%');
  assert.equal(ins.style.display, 'block');
  assert.equal(ins.style.height, '250px');
  assert.equal(ins.getAttribute('data-ad-format'), undefined);
  for (const width of [390, 664, 960]) {
    ad.el.width = width; f.resizes[0].cb(); await flush();
    assert.equal(ad.el.children[0], ins);
    assert.equal(f.win.adsbygoogle.length, 1);
  }
});
test('feed width is rechecked after asynchronous SDK loading', async () => {
  const f = setup({autoLoad: false}); f.api.updateAccess(allowed);
  const ad = f.mount(); ad.el.width = 249;
  f.sdk()[0].onload(); await flush();
  assert.equal(f.win.adsbygoogle.length, 0);
  ad.el.width = 664; f.resizes[0].cb(); await flush();
  assert.equal(f.win.adsbygoogle.length, 1);
});
test('stale asynchronous SDK completion cannot request ads after withdrawal', async () => {
  const f = setup({autoLoad: false}); f.api.updateAccess(allowed); const ad = f.mount();
  f.api.updateAccess({...allowed, advertising: false});
  f.sdk()[0].onload(); await flush();
  assert.equal(f.win.adsbygoogle.length, 0);
  assert.equal(ad.el.children.length, 0);
  for (const callback of f.timers.values()) callback();
  assert.equal(f.reloads(), 1);
});
test('unfilled units collapse, filled units are never forcibly hidden', async () => {
  const f = setup(); f.api.updateAccess(allowed); const ad = f.mount(); await flush();
  ad.el.children[0].setAttribute('data-ad-status', 'filled'); f.mutations[0].cb();
  assert.equal(ad.el.children.length, 1); assert.ok(ad.states.includes('filled'));
  ad.el.children[0].setAttribute('data-ad-status', 'unfilled'); f.mutations[0].cb();
  assert.equal(ad.el.children.length, 0); assert.ok(ad.states.includes('unfilled'));
});
test('ad-blocker/network failure collapses the unit without repeated script loads', async () => {
  const f = setup({failScript: true}); f.api.updateAccess(allowed); const ad = f.mount(); await flush();
  assert.ok(ad.states.includes('error')); assert.equal(f.win.adsbygoogle.length, 0);
  f.observers.forEach(o => o.cb([{isIntersecting: true}])); await flush();
  assert.equal(f.sdk().length, 1);
});
test('expired permission never starts SDK and no CMP loads without a placement', async () => {
  const f = setup({cmp: false});
  f.api.configure({...configuration, cmpScriptUrl: 'https://cmp.example/certified.js'});
  f.api.updateAccess(allowed); assert.equal(f.scripts.length, 0);
  f.api.updateAccess({...allowed, expiresAt: 1}); f.mount(); await flush();
  assert.equal(f.scripts.length, 0);
});
test('personalization needs both the local choice and CMP personalization purposes', async () => {
  const f = setup();
  f.api.updateAccess({...allowed, personalized: true}); f.mount(); await flush();
  assert.equal(f.win.adsbygoogle.requestNonPersonalizedAds, 0);
  f.consent({...granted, eventStatus: 'useractioncomplete', purpose: {consents: {1: true, 3: false, 4: false}}});
  for (const callback of f.timers.values()) callback();
  assert.equal(f.reloads(), 1);
});
test('opening CMP preferences does not prematurely reload or grant consent', async () => {
  const f = setup(); f.api.updateAccess(allowed); f.mount(); await flush();
  f.consent({...granted, eventStatus: 'cmpuishown'});
  assert.equal(f.reloads(), 0);
  f.mount('community_rail'); await flush();
  assert.equal(f.win.adsbygoogle.length, 1);
  f.consent({...granted, eventStatus: 'useractioncomplete'}); await flush();
  assert.equal(f.win.adsbygoogle.length, 2);
});
