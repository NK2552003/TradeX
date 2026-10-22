# Frontend Feature Audit: Affiliate Program

**Component:** `lib/features/affiliate_program/` & `settings/trader/`  
**Target Files:**  
- `lib/features/settings/presentation/pages/trader/affiliate_settings_page.dart`  
- `lib/features/settings/presentation/pages/trader/affiliate_application_page.dart`  

---

## 1. Dead Buttons & False Verification Flows

| UI Control | File & Line | Failure Mechanism | Priority |
|---|---|---|:---:|
| SMS Verify Icon | `affiliate_application_page.dart:677` | Instantly sets `_phoneVerified = true` in local state without sending an SMS OTP! | Medium |
| "Copy Link" (Mobile) | `affiliate_settings_page.dart:330` | Emits `UiToast('Referral link copied')` but omits `Clipboard.setData(...)`. | Low |

---

## 2. Payout Request Disconnect

- **Simulated Payout Requests:**
  - Tapping "Request Payout" displays a simulated modal; no bank transfer or Stripe Connect payout intent is generated.
  - **Action:** Connect to backend payout RPC.
