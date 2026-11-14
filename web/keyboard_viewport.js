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

  document.addEventListener('focusin', ({ target }) => {
    if (!target.matches?.(editable)) return;
    if (!editing) {
      focusWidth = viewport.width;
      focusHeight = viewport.height;
    }
    editing = true;
  });

  function reconcile() {
    if (!editing) return;
    cancelAnimationFrame(frame);
    frame = requestAnimationFrame(() => {
      if (viewport.scale !== 1 || Math.abs(viewport.width - focusWidth) > 1) {
        editing = false;
        return;
      }
      const restored = viewport.height >= focusHeight - 1;
      // A focused composer near the bottom can also pan the document.
      if (restored && window.scrollY) window.scrollTo(window.scrollX, 0);
      if (viewport.height !== reportedHeight) {
        reportedHeight = viewport.height;
        viewport.dispatchEvent(new Event('resize'));
      }
      // Blur can precede the final viewport update. Keep listening until the
      // browser has actually returned the keyboard's space.
      if (restored && !document.activeElement?.matches(editable)) editing = false;
    });
  }

  viewport.addEventListener('resize', (event) => {
    reportedHeight = viewport.height;
    if (event.isTrusted) reconcile();
  });
  viewport.addEventListener('scroll', reconcile);
  window.addEventListener('resize', reconcile);
  document.addEventListener('focusout', reconcile);
})();
