// Flutter measures the visual viewport on its resize event. Some mobile
// browsers settle the final keyboard height on a scroll or a window resize.
(() => {
  const viewport = window.visualViewport;
  if (!viewport || !navigator.maxTouchPoints) return;

  const editable = 'input, textarea, [contenteditable="true"]';
  let editing = false;
  let frame = 0;
  let reportedHeight = viewport.height;
  let focusWidth = 0;
  let focusHeight = 0;
  let pollTimer = 0;
  let sawKeyboard = false;

  function activeEditor() {
    let element = document.activeElement;
    while (element?.shadowRoot?.activeElement) element = element.shadowRoot.activeElement;
    return element?.matches?.(editable) ? element : null;
  }

  document.addEventListener('focusin', (event) => {
    const target = event.composedPath?.().find((node) => node.matches?.(editable)) ?? event.target;
    if (!target.matches?.(editable)) return;
    if (!editing) {
      focusWidth = viewport.width;
      focusHeight = viewport.height;
    }
    editing = true;
    watchViewport();
  });

  // Android keyboards can hide while the input keeps focus and without a
  // resize event. Observe until the measured viewport has actually recovered.
  function watchViewport() {
    clearTimeout(pollTimer);
    if (!editing) return;
    pollTimer = setTimeout(() => {
      reconcile();
      watchViewport();
    }, 200);
  }

  function reconcile() {
    if (!editing) return;
    cancelAnimationFrame(frame);
    frame = requestAnimationFrame(() => {
      if (viewport.scale !== 1 || Math.abs(viewport.width - focusWidth) > 1) {
        editing = false;
        return;
      }
      const restored = viewport.height >= focusHeight - 1;
      if (focusHeight - viewport.height > 100) sawKeyboard = true;
      // A focused composer near the bottom can also pan the document.
      if (restored && window.scrollY) window.scrollTo(window.scrollX, 0);
      if (viewport.height !== reportedHeight) {
        reportedHeight = viewport.height;
        viewport.dispatchEvent(new Event('resize'));
      }
      // Blur can precede the final viewport update. Keep listening until the
      // browser has actually returned the keyboard's space.
      if (restored && (sawKeyboard || !activeEditor())) {
        editing = false;
        sawKeyboard = false;
        clearTimeout(pollTimer);
      }
    });
  }

  viewport.addEventListener('resize', (event) => {
    reportedHeight = viewport.height;
    if (event.isTrusted) {
      if (!editing && activeEditor()) {
        editing = true;
        watchViewport();
      }
      reconcile();
    }
  });
  viewport.addEventListener('scroll', reconcile);
  window.addEventListener('resize', reconcile);
  document.addEventListener('focusout', reconcile);
})();
