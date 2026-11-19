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

test('installed related Android app receives the current verified HTTPS route', async () => {
  const handlers = {};
  const assigned = [];
  const session = new Map();
  const window = {
    matchMedia: () => ({matches: false, addEventListener: () => {}}),
    addEventListener: (name, fn) => handlers[name] = fn,
  };
  const location = {
    hostname: 'community.alphajournal.in',
    protocol: 'https:',
    href: 'https://community.alphajournal.in/community/post/post_42?ref=abc#comments',
    assign: value => assigned.push(value),
  };
  vm.runInNewContext(source, {
    window,
    location,
    navigator: {
      getInstalledRelatedApps: async () => [
        {platform: 'play', id: 'release.package.from.manifest'},
      ],
    },
    URL,
    Set,
    Number,
    JSON,
    Date,
    localStorage: {getItem: () => null, setItem: () => {}},
    sessionStorage: {
      getItem: key => session.get(key) ?? null,
      setItem: (key, value) => session.set(key, value),
    },
  });
  await new Promise(resolve => setImmediate(resolve));
  const state = JSON.parse(window.alphajournalInstall.snapshot());
  assert.equal(state.nativeInstalled, true);
  assert.equal(state.relatedAppsChecked, true);
  assert.equal(state.installed, true);
  assert.equal(assigned.length, 1);
  const handoff = new URL(assigned[0]);
  assert.equal(handoff.pathname, '/community/post/post_42');
  assert.equal(handoff.searchParams.get('ref'), 'abc');
  assert.equal(handoff.searchParams.get('app_handoff'), '1');
  assert.equal(handoff.hash, '#comments');
  assert.equal(window.alphajournalInstall.openInstalledApp(), false);
});

function createCookieJar() {
  const cookies = new Map();
  return {
    createBrowser({hostname = 'alphajournal.in', installed = false} = {}) {
      const handlers = {};
      const storage = new Map();
      let now = 2000000000000;
      const doc = {
        visibilityState: 'visible',
        addEventListener: () => {},
        get cookie() {
          return Array.from(cookies.entries())
            .map(([k, v]) => `${k}=${encodeURIComponent(v.value)}`)
            .join('; ');
        },
        set cookie(assignment) {
          const parts = String(assignment).split(';').map(s => s.trim());
          const eq = parts[0].indexOf('=');
          const name = parts[0].slice(0, eq);
          const rawVal = parts[0].slice(eq + 1);
          const val = decodeURIComponent(rawVal);
          const domainAttr = parts.find(p => p.toLowerCase().startsWith('domain='));
          cookies.set(name, {value: val, domain: domainAttr || ''});
        },
      };
      const window = {
        matchMedia: () => ({matches: installed, addEventListener: (name, fn) => handlers.display = fn}),
        addEventListener: (name, fn) => handlers[name] = fn,
      };
      vm.runInNewContext(source, {
        window,
        document: doc,
        location: {hostname, protocol: 'https:'},
        navigator: {},
        Set,
        Number,
        Math,
        JSON,
        Date: {now: () => now},
        localStorage: {
          getItem: k => storage.get(k) ?? null,
          setItem: (k, v) => storage.set(k, v),
        },
      });
      return {
        api: window.alphajournalInstall,
        handlers,
        cookies,
        state: () => JSON.parse(window.alphajournalInstall.snapshot()),
      };
    },
  };
}

test('dismissing or installing on one subdomain unifies across all subdomains via .alphajournal.in cookies', () => {
  const jar = createCookieJar();
  const root = jar.createBrowser({hostname: 'alphajournal.in'});
  offer(root);
  assert.equal(root.state().canSuggest, true);
  root.api.dismiss();
  assert.equal(root.cookies.get('alphajournal_install_dismissed_v1').domain, 'Domain=.alphajournal.in');

  const app = jar.createBrowser({hostname: 'app.alphajournal.in'});
  offer(app);
  assert.equal(app.state().canSuggest, false);

  app.handlers.appinstalled();
  assert.equal(app.cookies.get('alphajournal_install_installed_v1').value, '1');
  assert.equal(app.cookies.get('alphajournal_install_installed_v1').domain, 'Domain=.alphajournal.in');

  const community = jar.createBrowser({hostname: 'community.alphajournal.in'});
  offer(community);
  assert.equal(community.state().installed, true);
  assert.equal(community.state().canSuggest, false);
});
