import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { runInNewContext } from 'node:vm';

const script = readFileSync(new URL('../../web/keyboard_viewport.js', import.meta.url), 'utf8');

test('resyncs a late viewport restoration after blur without looping or disturbing a cancelled swipe', () => {
  const window = new EventTarget();
  const document = new EventTarget();
  const viewport = Object.assign(new EventTarget(), { height: 800, width: 390, scale: 1 });
  const field = new EventTarget();
  field.matches = () => true;
  window.visualViewport = viewport;
  window.scrollX = 0;
  window.scrollY = 0;
  window.scrollTo = (_, y) => { window.scrollY = y; };
  let frame;
  let resizes = 0;
  viewport.addEventListener('resize', () => resizes++);
  // Forward focusin to the document with its original field target.
  const listeners = new Map();
  document.addEventListener = (type, listener) => listeners.set(type, listener);
  runInNewContext(script, {
    window, document, Event, navigator: { maxTouchPoints: 5 },
    requestAnimationFrame: (fn) => { frame = fn; return 1; },
    cancelAnimationFrame: () => { frame = undefined; },
  });
  document.activeElement = field;
  listeners.get('focusin')({ target: field });
  viewport.height = 500;
  viewport.dispatchEvent(new Event('resize'));
  window.scrollY = 120;
  viewport.height = 640;
  viewport.dispatchEvent(new Event('scroll'));
  viewport.height = 500; // Gesture cancelled before the next frame.
  frame();
  assert.equal(resizes, 1);
  assert.equal(window.scrollY, 120);

  document.activeElement = null;
  listeners.get('focusout')();
  frame();
  // Only a visual viewport scroll arrives. The final size settles after it.
  viewport.dispatchEvent(new Event('scroll'));
  viewport.height = 800;
  frame();
  assert.equal(resizes, 2);
  assert.equal(window.scrollY, 0);
  window.dispatchEvent(new Event('resize'));
  assert.equal(resizes, 2);
});
