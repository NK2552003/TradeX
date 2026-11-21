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

  function cleanupRazorpayDom() {
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

  function mountReturnBar(onReturnClick) {
    const existing = document.getElementById('aj-razorpay-return-bar');
    if (existing) existing.remove();

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
    btn.textContent = '← Return to AlphaJournal';
    btn.style.cssText = [
      'appearance:none',
      'border:1px solid rgba(255,255,255,0.22)',
      'background:rgba(13,12,11,0.94)',
      'color:#FAFAF9',
      'padding:9px 16px',
      'border-radius:999px',
      'font:600 13px/1.2 "Noto Sans",system-ui,-apple-system,sans-serif',
      'cursor:pointer',
      'box-shadow:0 6px 20px rgba(0,0,0,0.45)',
      'backdrop-filter:blur(8px)',
    ].join(';');
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

      mountReturnBar(() => {
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
      });

      try {
        const rzpOptions = {
          key: options.key_id,
          subscription_id: options.subscription_id,
          name: options.name || 'AlphaJournal',
          description: options.description || 'AlphaJournal Subscription',
          prefill: {
            email: options.email || '',
            name: options.user_name || '',
          },
          notes: {
            tier: options.tier || '',
            billing_cycle: options.billing_cycle || '',
          },
          theme: {
            color: '#6B7FD7',
            backdrop_color: 'rgba(13, 12, 11, 0.78)',
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
