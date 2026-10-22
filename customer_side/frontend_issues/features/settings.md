# Frontend Feature Audit: Settings & Profile Management

**Component:** `lib/features/settings/`  
**Target Files:**  
- `lib/features/settings/presentation/pages/trader/change_plan_page.dart`  
- `lib/features/settings/presentation/pages/trader/billing_settings_page.dart`  
- `lib/features/settings/presentation/pages/trader/invoice_detail_page.dart`  
- `lib/features/settings/presentation/pages/shared/account_security_page.dart`  
- `lib/features/settings/presentation/pages/shared/privacy_settings_page.dart`  
- `lib/features/settings/presentation/pages/shared/help_about_page.dart`  
- `lib/features/settings/presentation/pages/shared/delete_account_page.dart`  
- `lib/features/settings/presentation/pages/trader/affiliate_settings_page.dart`  

---

## 1. Dead Buttons & Discarded User Input

| UI Control | File & Line | Failure Mechanism | Priority |
|---|---|---|:---:|
| CVC Field | `change_plan_page.dart:271` | Declared as `const UiInput(...)` without controller; user cannot type or submit CVC. | High |
| "Save card" Button | `billing_settings_page.dart:178` | Delays 800ms and emits a toast; entered card fields are discarded. | High |
| Email OTP Input | `account_security_page.dart:172` | Has `onChanged: (v) {}` which discards user input. | High |
| "Verify & Update Email" | `account_security_page.dart:186` | Delays 500ms and modifies local memory without verifying token in Supabase. | High |
| "Download PDF" | `invoice_detail_page.dart:51` | Emits `UiToast`; never downloads invoice file. | Medium |
| "Download ZIP" | `privacy_settings_page.dart:160` | Emits `UiToast`; never downloads GDPR archive. | Medium |
| "Send Ticket" | `help_about_page.dart:374` | Delays 600ms, clears fields, emits toast; ticket data discarded. | Medium |
| "Copy Link" (Mobile) | `affiliate_settings_page.dart:330` | Displays toast but omits `Clipboard.setData()`; copies nothing! | Low |

---

## 2. Incomplete Account Deletion Flow

- **Simulated Deletion (`delete_account_page.dart:86-105`):**
  - Tapping "Delete Account" only sets `status = 'pending_approval'`. It never signs the user out, leaves JWT active, and keeps the screen mounted.
  - **Action:** Sign out the user and route to `AuthWrapper` after initiating account deletion.
