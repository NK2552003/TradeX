const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync('web/app_update.js', 'utf8');

test('reload clears only Flutter caches and legacy Flutter workers', async () => {
  const deletedCaches = [];
  const unregistered = [];
  const replacements = [];
  const registrations = [
    {
      active: {scriptURL: 'https://app.alphajournal.in/flutter_service_worker.js'},
      unregister: async () => unregistered.push('flutter'),
    },
    {
      active: {scriptURL: 'https://app.alphajournal.in/push-sw.js'},
      unregister: async () => unregistered.push('push'),
    },
  ];
  const cacheStorage = {
    keys: async () => ['flutter-app-manifest', 'alphajournal-private-cache'],
    delete: async name => deletedCaches.push(name),
  };
  const window = {
    caches: cacheStorage,
    location: {
      href: 'https://app.alphajournal.in/workspace?tab=today#desk',
      replace: value => replacements.push(value),
    },
  };
  vm.runInNewContext(source, {
    window,
    navigator: {
      serviceWorker: {getRegistrations: async () => registrations},
    },
    caches: cacheStorage,
    URL,
    Date: {now: () => 1234567890},
    Promise,
  });

  assert.equal(await window.alphajournalUpdate.reload(), true);
  assert.deepEqual(deletedCaches, ['flutter-app-manifest']);
  assert.deepEqual(unregistered, ['flutter']);
  assert.equal(replacements.length, 1);
  const target = new URL(replacements[0]);
  assert.equal(target.pathname, '/workspace');
  assert.equal(target.searchParams.get('tab'), 'today');
  assert.equal(target.searchParams.get('app_version_refresh'), '1234567890');
  assert.equal(target.hash, '#desk');
});

test('cache API failures still trigger a safe reload', async () => {
  const replacements = [];
  const cacheStorage = {keys: async () => { throw new Error('blocked'); }};
  const window = {
    caches: cacheStorage,
    location: {
      href: 'https://alphajournal.in/',
      replace: value => replacements.push(value),
    },
  };
  vm.runInNewContext(source, {
    window,
    navigator: {},
    caches: cacheStorage,
    URL,
    Date: {now: () => 42},
    Promise,
  });

  assert.equal(await window.alphajournalUpdate.reload(), true);
  assert.equal(replacements.length, 1);
});
