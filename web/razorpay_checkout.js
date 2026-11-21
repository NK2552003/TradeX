(function () {
  const CHECKOUT_SCRIPT_URL = 'https://checkout.razorpay.com/v1/checkout.js';
  let scriptPromise = null;

  function loadRazorpayScript() {
    if (typeof window.Razorpay === 'function') {
      return Promise.resolve(true);
    }
    if (scriptPromise) return scriptPromise;

    scriptPromise = new Promise((resolve) => {
      const existing = document.querySelector(
        `script[src="${CHECKOUT_SCRIPT_URL}"]`,
      );
      if (existing) {
        existing.addEventListener('load', () =>
          resolve(typeof window.Razorpay === 'function'),
        );
        existing.addEventListener('error', () => {
          scriptPromise = null;
          resolve(false);
        });
        return;
      }

      const script = document.createElement('script');
      script.src = CHECKOUT_SCRIPT_URL;
      script.async = true;
      const timer = setTimeout(() => {
        scriptPromise = null;
        resolve(false);
      }, 12000);

      script.onload = () => {
        clearTimeout(timer);
        resolve(typeof window.Razorpay === 'function');
      };
      script.onerror = () => {
        clearTimeout(timer);
        scriptPromise = null;
        resolve(false);
      };
      document.head.appendChild(script);
    });

    return scriptPromise;
  }

  const DEFAULT_APP_ICON_URL = 'https://app.alphajournal.in/icons/Icon-192.png';

  function resolveAppIconUrl(customUrl) {
    if (typeof customUrl === 'string' && /^https:\/\//i.test(customUrl.trim())) {
      return customUrl.trim();
    }
    try {
      const origin = window.location && window.location.origin;
      if (origin && /^https:\/\//i.test(origin) && origin.includes('alphajournal.in')) {
        return origin.replace(/\/+$/, '') + '/icons/Icon-192.png';
      }
    } catch (_) {}
    return DEFAULT_APP_ICON_URL;
  }

  function resolveIsDark(options) {
    if (options && typeof options.is_dark === 'boolean') {
      return options.is_dark;
    }
    try {
      const rootTheme = document.documentElement.getAttribute('data-theme');
      if (rootTheme === 'light') return false;
      if (rootTheme === 'dark') return true;
      if (window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches) {
        return false;
      }
    } catch (_) {}
    return true;
  }

  function cleanupRazorpayDom() {
    const backdrop = document.getElementById('aj-razorpay-backdrop');
    if (backdrop) backdrop.remove();
    const bar = document.getElementById('aj-razorpay-return-bar');
    if (bar) bar.remove();
    const containers = document.querySelectorAll('.razorpay-container');
    containers.forEach((el) => {
      try {
        el.remove();
      } catch (_) {}
    });
    // Keep Flutter's body overflow intact
    document.body.style.overflow = 'hidden';
  }

  function mountThemedBackdrop(isDark, backdropColor) {
    const existing = document.getElementById('aj-razorpay-backdrop');
    if (existing) existing.remove();

    const backdrop = document.createElement('div');
    backdrop.id = 'aj-razorpay-backdrop';
    backdrop.style.cssText = [
      'position:fixed',
      'inset:0',
      'z-index:2147483644',
      `background:${backdropColor || (isDark ? 'rgba(13,12,11,0.92)' : 'rgba(250,249,247,0.92)')}`,
      'backdrop-filter:blur(10px)',
      '-webkit-backdrop-filter:blur(10px)',
      'pointer-events:none',
    ].join(';');
    document.body.appendChild(backdrop);
    return backdrop;
  }

  function mountReturnBar(onReturnClick, styleOpts) {
    const existing = document.getElementById('aj-razorpay-return-bar');
    if (existing) existing.remove();

    const isDark = styleOpts.isDark;
    const surfaceColor =
      styleOpts.surfaceColor || (isDark ? 'rgba(24,23,21,0.94)' : 'rgba(255,255,255,0.96)');
    const foregroundColor =
      styleOpts.foregroundColor || (isDark ? '#FAFAF9' : '#181715');
    const borderColor =
      styleOpts.borderColor || (isDark ? 'rgba(255,255,255,0.18)' : 'rgba(24,23,21,0.16)');
    const shadow = isDark
      ? '0 8px 24px rgba(0,0,0,0.48)'
      : '0 8px 24px rgba(24,23,21,0.12)';

    const bar = document.createElement('div');
    bar.id = 'aj-razorpay-return-bar';
    bar.style.cssText = [
      'position:fixed',
      'top:14px',
      'left:16px',
      'z-index:2147483647',
      'display:flex',
      'align-items:center',
      'gap:8px',
      'pointer-events:auto',
    ].join(';');

    const btn = document.createElement('button');
    btn.type = 'button';
    btn.id = 'aj-razorpay-return-btn';
    btn.style.cssText = [
      'appearance:none',
      'display:inline-flex',
      'align-items:center',
      'gap:8px',
      `border:1px solid ${borderColor}`,
      `background:${surfaceColor}`,
      `color:${foregroundColor}`,
      'padding:8px 14px',
      'border-radius:999px',
      'font:600 13px/1.2 "Noto Sans",system-ui,-apple-system,sans-serif',
      'cursor:pointer',
      `box-shadow:${shadow}`,
      'backdrop-filter:blur(10px)',
      '-webkit-backdrop-filter:blur(10px)',
    ].join(';');

    const arrow = document.createElement('span');
    arrow.textContent = '←';
    arrow.setAttribute('aria-hidden', 'true');

    const icon = document.createElement('img');
    icon.src = styleOpts.iconUrl;
    icon.alt = '';
    icon.width = 18;
    icon.height = 18;
    icon.style.cssText =
      'width:18px;height:18px;border-radius:4px;object-fit:cover;display:block;flex-shrink:0;';

    const label = document.createElement('span');
    label.textContent = 'Return to AlphaJournal';

    btn.appendChild(arrow);
    btn.appendChild(icon);
    btn.appendChild(label);
    btn.addEventListener('click', onReturnClick);

    bar.appendChild(btn);
    document.body.appendChild(bar);
    return btn;
  }

  async function openCheckout(optionsJson) {
    let options;
    try {
      options = JSON.parse(optionsJson);
    } catch (_) {
      return JSON.stringify({
        status: 'error',
        error: 'Invalid checkout configuration.',
      });
    }

    const loaded = await loadRazorpayScript();
    if (!loaded || typeof window.Razorpay !== 'function') {
      return JSON.stringify({
        status: 'unavailable',
        error: 'Razorpay Checkout SDK could not be loaded.',
      });
    }

    return new Promise((resolve) => {
      let settled = false;
      let rzpInstance = null;
      let lastFailureMessage = null;
      let lastFailureCode = null;

      function finish(payload) {
        if (settled) return;
        settled = true;
        try {
          if (rzpInstance && typeof rzpInstance.close === 'function') {
            rzpInstance.close();
          }
        } catch (_) {}
        cleanupRazorpayDom();
        resolve(JSON.stringify(payload));
      }

      const isDark = resolveIsDark(options);
      const iconUrl = resolveAppIconUrl(options.image);
      const backdropHex =
        options.backdrop_color || (isDark ? '#0D0C0B' : '#FAF9F7');
      const themeHex =
        options.theme_color || (isDark ? '#181715' : '#181715');

      mountThemedBackdrop(
        isDark,
        isDark ? 'rgba(13, 12, 11, 0.90)' : 'rgba(250, 249, 247, 0.90)',
      );

      mountReturnBar(
        () => {
          if (lastFailureMessage) {
            finish({
              status: 'failed',
              error: lastFailureMessage,
              code: lastFailureCode || 'PAYMENT_FAILED',
            });
          } else {
            finish({
              status: 'cancelled',
              error: 'Returned to AlphaJournal before completing payment.',
            });
          }
        },
        {
          isDark,
          iconUrl,
          surfaceColor: options.surface_color,
          foregroundColor: options.foreground_color,
          borderColor: options.border_color,
        },
      );

      try {
        const rzpOptions = {
          key: options.key_id,
          subscription_id: options.subscription_id,
          name: options.name || 'AlphaJournal',
          description: options.description || 'AlphaJournal Subscription',
          image: iconUrl,
          prefill: {
            email: options.email || '',
            name: options.user_name || '',
          },
          notes: {
            tier: options.tier || '',
            billing_cycle: options.billing_cycle || '',
          },
          theme: {
            color: themeHex,
            backdrop_color: backdropHex,
          },
          retry: {
            enabled: false,
          },
          handler: function (response) {
            finish({
              status: 'success',
              razorpay_payment_id: response?.razorpay_payment_id || '',
              razorpay_subscription_id:
                response?.razorpay_subscription_id ||
                options.subscription_id ||
                '',
              razorpay_signature: response?.razorpay_signature || '',
            });
          },
          modal: {
            escape: true,
            backdropclose: false,
            confirm_close: false,
            ondismiss: function () {
              if (lastFailureMessage) {
                finish({
                  status: 'failed',
                  error: lastFailureMessage,
                  code: lastFailureCode || 'PAYMENT_FAILED',
                });
              } else {
                finish({
                  status: 'cancelled',
                  error: 'Checkout was closed before payment completed.',
                });
              }
            },
          },
        };

        rzpInstance = new window.Razorpay(rzpOptions);
        rzpInstance.on('payment.failed', function (response) {
          const err = response?.error || {};
          lastFailureMessage =
            err.description ||
            err.reason ||
            'Payment failed or was declined by the bank.';
          lastFailureCode = err.code || 'PAYMENT_FAILED';
          // With retry.enabled = false, close the modal and return the user directly
          // to AlphaJournal so they are never stranded on a failure screen.
          setTimeout(() => {
            finish({
              status: 'failed',
              error: lastFailureMessage,
              code: lastFailureCode,
            });
          }, 350);
        });

        rzpInstance.open();
      } catch (err) {
        finish({
          status: 'error',
          error:
            err && err.message
              ? err.message
              : 'Could not open Razorpay Checkout.',
        });
      }
    });
  }

  globalThis.alphajournalRazorpay = {
    openCheckout,
  };
})();
