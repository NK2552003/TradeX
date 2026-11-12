/* First-party lifecycle only. No Google request occurs until all gates pass. */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory;
  else root.AlphaJournalAds = factory(root);
})(typeof globalThis !== 'undefined' ? globalThis : this, function (win) {
  'use strict';
  const doc = win.document;
  let config = { enabled: false, slots: {} };
  let access = { eligible: false, advertising: false, personalized: false, expiresAt: 0 };
  let consent = null;
  let cmpAttached = false;
  let cmpListenerId;
  let cmpScript;
  let cmpPoll;
  let script;
  let loading;
  let sdkStarted = false;
  let cmpStarted = false;
  let reloadScheduled = false;
  let generation = 0;
  const entries = new Map();
  const used = new Set();
  const parse = value => typeof value === 'string' ? JSON.parse(value) : value;
  const validPublisher = () => /^ca-pub-\d{16}$/.test(config.publisherId || '');
  const localAllowed = () => config.enabled === true && validPublisher() &&
    access.eligible === true && access.advertising === true && access.expiresAt > Date.now();
  const cmpAllowed = () => consent && consent.cmpStatus === 'loaded' &&
    (consent.eventStatus === 'tcloaded' || consent.eventStatus === 'useractioncomplete') &&
    (consent.gdprApplies === false || (consent.gdprApplies === true &&
      typeof consent.tcString === 'string' && consent.tcString.length > 0 &&
      consent.purpose?.consents?.[1] === true && consent.vendor?.consents?.[755] === true));
  const personalizedAllowed = () => access.personalized === true &&
    (consent?.gdprApplies === false ||
      (consent?.purpose?.consents?.[3] === true && consent?.purpose?.consents?.[4] === true));
  const fits = entry => entry.element.getBoundingClientRect().width >=
    (entry.responsive ? 250 : entry.width);

  function clearEntry(entry, status) {
    entry.intersection?.disconnect();
    entry.resize?.disconnect();
    entry.mutation?.disconnect();
    if (entry.timeout) win.clearTimeout(entry.timeout);
    entry.element.replaceChildren();
    if (status) entry.callback(status);
  }
  function stop(reload) {
    generation++;
    entries.forEach(e => clearEntry(e, 'blocked'));
    entries.clear();
    if (script) script.remove();
    if (cmpScript) cmpScript.remove();
    if (cmpPoll) win.clearInterval(cmpPoll);
    cmpPoll = null;
    if (cmpAttached && cmpListenerId && typeof win.__tcfapi === 'function') {
      win.__tcfapi('removeEventListener', 2, () => {}, cmpListenerId);
    }
    cmpAttached = false;
    cmpListenerId = undefined;
    consent = null;
    // Removing a script tag does not unload executing JavaScript. A fresh
    // document guarantees the SDK cannot follow a paid/private route or a
    // withdrawn choice. The router gets the current task to update the URL.
    if (reload && (sdkStarted || cmpStarted) && !reloadScheduled) {
      reloadScheduled = true;
      win.setTimeout(() => win.location.reload(), 0);
    }
  }

  function attachCmp() {
    if (!localAllowed() || cmpAttached) return;
    if (typeof win.__tcfapi !== 'function') return;
    cmpAttached = true;
    if (cmpPoll) win.clearInterval(cmpPoll);
    cmpPoll = null;
    win.__tcfapi('addEventListener', 2, (data, success) => {
      if (!cmpAttached || !localAllowed()) return;
      const wasPersonalized = personalizedAllowed();
      consent = success ? data : null;
      cmpListenerId = data?.listenerId;
      const settled = !success || data?.eventStatus === 'tcloaded' || data?.eventStatus === 'useractioncomplete';
      if (sdkStarted && settled && (!cmpAllowed() ||
          (wasPersonalized && !personalizedAllowed()))) {
        stop(true);
        return;
      }
      entries.forEach(tryRequest);
    });
  }
  function startCmp() {
    if (!localAllowed() || entries.size === 0) return;
    attachCmp();
    if (cmpAttached || cmpPoll) return;
    // Optional URL must be the script supplied by the site's certified CMP.
    // Never fabricate a TCF string or use the local switches as CMP consent.
    if (!cmpScript && config.cmpScriptUrl) {
      try {
        const url = new URL(config.cmpScriptUrl);
        if (url.protocol !== 'https:' || url.username || url.password) return;
        cmpScript = doc.createElement('script');
        cmpScript.async = true;
        cmpScript.src = url.href;
        cmpScript.onload = attachCmp;
        cmpStarted = true;
        doc.head.appendChild(cmpScript);
      } catch (_) { return; }
    }
    let attempts = 0;
    cmpPoll = win.setInterval(() => {
      if (!localAllowed() || ++attempts > 120) {
        win.clearInterval(cmpPoll); cmpPoll = null; return;
      }
      attachCmp();
    }, 500);
  }
  function ensureSdk() {
    if (loading) return loading;
    const epoch = generation;
    loading = new Promise((resolve, reject) => {
      if (!localAllowed() || !cmpAllowed()) { reject(Error('Consent unavailable')); return; }
      // Manual units only. Auto ads must also be disabled in the AdSense account.
      win.adsbygoogle = win.adsbygoogle || [];
      win.adsbygoogle.requestNonPersonalizedAds = personalizedAllowed() ? 0 : 1;
      script = doc.createElement('script');
      script.async = true;
      script.crossOrigin = 'anonymous';
      script.src = 'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=' + config.publisherId;
      script.onload = () => epoch === generation ? resolve() : reject(Error('Access changed'));
      script.onerror = () => reject(Error('Ad service unavailable'));
      sdkStarted = true;
      doc.head.appendChild(script);
    });
    return loading;
  }
  async function tryRequest(entry) {
    if (entry.requesting || entry.requested || used.has(entry.instanceId) ||
        !localAllowed() || !cmpAllowed() || !entry.visible || !entry.element.isConnected ||
        !fits(entry)) return;
    const slot = config.slots[entry.placement];
    if (!/^\d{1,20}$/.test(slot || '')) return;
    const epoch = generation;
    entry.requesting = true;
    try {
      await ensureSdk();
      if (epoch !== generation || !entries.has(entry.element) || !entry.element.isConnected ||
          !localAllowed() || !cmpAllowed() || !entry.visible || !fits(entry) ||
          used.has(entry.instanceId)) return;
      const ins = doc.createElement('ins');
      ins.className = 'adsbygoogle';
      // AdSense's supported expandable-width/fixed-height Display pattern.
      // Keep the unit inside the Flutter post column, with no viewport expansion.
      ins.style.display = entry.responsive ? 'block' : 'inline-block';
      ins.style.width = entry.responsive ? '100%' : entry.width + 'px';
      if (entry.responsive) ins.style.minWidth = '250px';
      ins.style.height = entry.height + 'px';
      ins.setAttribute('data-ad-client', config.publisherId);
      ins.setAttribute('data-ad-slot', slot);
      entry.element.replaceChildren(ins);
      // Only non-identifying placement IDs reach the SDK. No account, record,
      // message, portfolio, search query, or other targeting data is supplied.
      win.adsbygoogle.requestNonPersonalizedAds = personalizedAllowed() ? 0 : 1;
      win.adsbygoogle.push({});
      used.add(entry.instanceId);
      entry.requested = true;
      entry.callback('requested');
      entry.mutation = new win.MutationObserver(() => {
        const status = ins.getAttribute('data-ad-status');
        if (status === 'unfilled') clearEntry(entry, 'unfilled');
        if (status === 'filled') {
          entry.callback('filled');
          if (entry.timeout) win.clearTimeout(entry.timeout);
        }
      });
      entry.mutation.observe(ins, {attributes: true, attributeFilter: ['data-ad-status']});
      entry.timeout = win.setTimeout(() => {
        // Collapse only an explicitly unfilled unit. Never obscure a live ad.
        if (ins.getAttribute('data-ad-status') === 'unfilled') clearEntry(entry, 'unfilled');
      }, 20000);
    } catch (_) {
      if (entries.has(entry.element)) clearEntry(entry, 'error');
    } finally {
      entry.requesting = false;
    }
  }
  const api = {
    configure(value) {
      const next = parse(value);
      if (sdkStarted && (next.publisherId !== config.publisherId || !next.enabled)) stop(true);
      config = {...next, slots: next.slots || {}};
    },
    updateAccess(value) {
      const next = parse(value);
      const reduced = access.personalized && !next.personalized;
      access = next;
      if (!localAllowed() || (sdkStarted && reduced)) { stop(true); return; }
      startCmp();
      entries.forEach(tryRequest);
    },
    mount(element, placement, width, height, callback, instanceId = placement) {
      if (entries.has(element)) return;
      const responsive = placement === 'feed_inline' || placement === 'feed_footer';
      element.setAttribute('aria-label', 'Advertisement');
      element.style.width = responsive ? '100%' : width + 'px';
      element.style.height = height + 'px';
      if (!/^\d{1,20}$/.test(config.slots[placement] || '')) { callback('error'); return; }
      const entry = {element, placement, instanceId, responsive, width, height, callback, visible: false};
      entries.set(element, entry);
      if (used.has(instanceId)) { callback('unfilled'); return; }
      entry.intersection = new win.IntersectionObserver(observed => {
        entry.visible = observed.some(e => e.isIntersecting);
        tryRequest(entry);
      }, {threshold: 0.1});
      entry.intersection.observe(element);
      entry.resize = new win.ResizeObserver(() => tryRequest(entry));
      entry.resize.observe(element);
      startCmp();
    },
    unmount(element) {
      const entry = entries.get(element);
      if (entry) clearEntry(entry);
      entries.delete(element);
    },
    suspend() { access = {...access, eligible: false}; stop(true); },
  };
  win.addEventListener?.('pagehide', () => stop(false));
  win.addEventListener?.('focus', () => { if (!localAllowed()) stop(true); });
  return api;
});
