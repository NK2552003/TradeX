const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const scriptSource = fs.readFileSync(
  path.join(process.cwd(), 'web/razorpay_checkout.js'),
  'utf8',
);

function createFakeEnv({ origin = 'https://app.alphajournal.in' } = {}) {
  const byId = new Map();
  const children = [];

  function makeEl(tag) {
    const el = {
      tagName: tag.toUpperCase(),
      id: '',
      type: '',
      src: '',
      alt: '',
      width: 0,
      height: 0,
      textContent: '',
      style: { cssText: '', overflow: '' },
      attrs: {},
      children: [],
      listeners: {},
      setAttribute(k, v) {
        this.attrs[k] = String(v);
      },
      addEventListener(type, fn) {
        this.listeners[type] = fn;
      },
      appendChild(child) {
        this.children.push(child);
        if (child.id) byId.set(child.id, child);
        return child;
      },
      remove() {
        if (this.id) byId.delete(this.id);
      },
    };
    return el;
  }

  let capturedOptions = null;
  function FakeRazorpay(opts) {
    capturedOptions = opts;
    return {
      on() {},
      open() {},
      close() {},
    };
  }

  const document = {
    documentElement: {
      getAttribute() {
        return null;
      },
    },
    head: { appendChild() {} },
    body: {
      style: { overflow: 'hidden' },
      appendChild(el) {
        children.push(el);
        if (el.id) byId.set(el.id, el);
        return el;
      },
    },
    createElement: makeEl,
    getElementById: (id) => byId.get(id) || null,
    querySelector: () => null,
    querySelectorAll: () => [],
  };

  const sandbox = {
    window: {
      location: { origin },
      Razorpay: FakeRazorpay,
    },
    document,
    setTimeout,
    clearTimeout,
  };
  sandbox.globalThis = sandbox;
  vm.runInNewContext(scriptSource, sandbox);

  return {
    bridge: sandbox.globalThis.alphajournalRazorpay,
    getCapturedOptions: () => capturedOptions,
    byId,
  };
}

test('Razorpay checkout adapts to dark/light app theme and includes AlphaJournal app icon', async () => {
  const darkEnv = createFakeEnv();
  const darkPromise = darkEnv.bridge.openCheckout(
    JSON.stringify({
      key_id: 'rzp_test_123',
      subscription_id: 'sub_123',
      name: 'AlphaJournal',
      is_dark: true,
      theme_color: '#181715',
      backdrop_color: '#0D0C0B',
      surface_color: '#181715',
      foreground_color: '#FAFAF9',
      border_color: '#3A3835',
    }),
  );

  await new Promise((r) => setImmediate(r));
  const darkOpts = darkEnv.getCapturedOptions();
  assert.equal(darkOpts.image, 'https://app.alphajournal.in/icons/Icon-192.png');
  assert.equal(darkOpts.theme.color, '#181715');
  assert.equal(darkOpts.theme.backdrop_color, '#0D0C0B');
  assert.ok(darkEnv.byId.get('aj-razorpay-backdrop'));
  const darkBtn = darkEnv.byId.get('aj-razorpay-return-btn');
  assert.ok(darkBtn);
  assert.match(darkBtn.style.cssText, /background:#181715/);
  assert.match(darkBtn.style.cssText, /color:#FAFAF9/);
  const darkImg = darkBtn.children.find((c) => c.tagName === 'IMG');
  assert.equal(darkImg.src, 'https://app.alphajournal.in/icons/Icon-192.png');

  darkBtn.listeners.click();
  const darkResult = JSON.parse(await darkPromise);
  assert.equal(darkResult.status, 'cancelled');
  assert.equal(darkEnv.byId.get('aj-razorpay-backdrop'), undefined);

  const lightEnv = createFakeEnv();
  const lightPromise = lightEnv.bridge.openCheckout(
    JSON.stringify({
      key_id: 'rzp_test_123',
      subscription_id: 'sub_456',
      name: 'AlphaJournal',
      is_dark: false,
      theme_color: '#181715',
      backdrop_color: '#FAF9F7',
      surface_color: '#FFFFFF',
      foreground_color: '#181715',
      border_color: '#D6D3D1',
    }),
  );

  await new Promise((r) => setImmediate(r));
  const lightOpts = lightEnv.getCapturedOptions();
  assert.equal(lightOpts.image, 'https://app.alphajournal.in/icons/Icon-192.png');
  assert.equal(lightOpts.theme.backdrop_color, '#FAF9F7');
  const lightBtn = lightEnv.byId.get('aj-razorpay-return-btn');
  assert.match(lightBtn.style.cssText, /background:#FFFFFF/);
  assert.match(lightBtn.style.cssText, /color:#181715/);

  lightBtn.listeners.click();
  await lightPromise;
});
