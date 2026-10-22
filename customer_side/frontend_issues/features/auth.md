# Frontend Feature Audit: Authentication & Onboarding

**Component:** `lib/features/auth/`  
**Target Files:**  
- `lib/features/auth/presentation/pages/login_page.dart`  
- `lib/features/auth/presentation/pages/signup_page.dart`  
- `lib/features/auth/presentation/pages/forgot_password_page.dart`  
- `lib/features/auth/presentation/pages/get_started_page.dart`  
- `lib/features/auth/presentation/pages/onboarding_profile_setup_page.dart`  
- `lib/features/auth/presentation/widgets/tradex_footer.dart`  
- `lib/core/widgets/app_scaffold.dart`  

---

## 1. Dead Buttons & No-Op Handlers

| UI Control | File & Line | Failure Mechanism | Priority |
|---|---|---|:---:|
| "Sign in with Google" | `login_page.dart:401, 553` | Emits `UiToast(title: 'Google Sign-In', message: '...')`; never triggers OAuth flow. | High |
| "Sign up with Google" | `signup_page.dart:475, 627` | Emits `UiToast`; OAuth flow missing. | High |
| "Reset Password" | `forgot_password_page.dart:189` | Runs 800ms `Future.delayed`; never calls Supabase Auth `resetPasswordForEmail()`. | Critical |
| Role Switcher Dialog | `app_scaffold.dart:1020, 1395` | Production scaffold builds and displays `_showRoleSwitcherDialog`, allowing anyone to switch to `user_admin` in UI! | Critical |

---

## 2. Layout & Responsiveness Flaws

- **Landscape Overflow in Onboarding (`get_started_page.dart:80-125`):**
  - Rigid `Column` in `_buildMobileView` overflows by 114px on landscape or scaled mobile displays.
  - **Action:** Wrap the column in `SingleChildScrollView`.
- **Keyboard Overlap on Auth Fields:**
  - On compact Android devices, focusing the password input pushes the sign-up CTA button offscreen without scroll physics.
  - **Action:** Ensure `UiPage` or `CustomScrollView` encapsulates all auth cards.

---

## 3. False Marketing Claims to Remove

- **`tradex_footer.dart:727`:**
  - *"Broker API credentials and private strategy journals are encrypted client-side using AES-256 GCM before hitting storage."*
  - **Action:** Delete this text immediately. Zero AES encryption is implemented in the app.
