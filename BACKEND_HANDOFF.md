
## 1. OTP send / verify / resend — the main one

**File:** `lib/features/auth/data/repositories/auth_otp_repository.dart`
**Class to replace:** `AuthOtpRepositoryImpl`
**Interface (do not change):** `AuthOtpRepository`

This is the single seam every OTP screen talks to — both the new
`OtpVerificationPage` (signup e-mail verification) and the OTP step inside
`ForgotPasswordPage` (password reset) call through it. The full REST
contract (endpoints, request/response JSON, status codes) is documented as
a comment block directly above the class — implement against that.

Three methods to implement for real:
- `sendOtp({identifier, purpose})` → `POST /auth/otp/send`
- `verifyOtp({identifier, purpose, code})` → `POST /auth/otp/verify`, returns `OtpVerifyResult(success, token, errorMessage)`
- `resendOtp({identifier, purpose})` → `POST /auth/otp/resend`

**Currently mocked as:** any 6-digit code succeeds except `000000` (which
is hardcoded to fail, purely so the UI's error state stays testable).
**Remove:** the two `Future.delayed(...)` calls and the `code == '000000'`
special case once real verification is in place.

**Schema note:** nothing in `database/` currently models OTP codes.
Suggested table: `otp_codes (identifier, purpose, code_hash, expires_at,
attempt_count, consumed_at, created_at)`. Codes should be single-use,
expire in 5–10 minutes, and be rate-limited server-side per identifier.

---

## 2. Password reset confirmation

**File:** `lib/features/auth/presentation/pages/forgot_password_page.dart`
**Method:** `_handleResetPassword()`

Currently just does `await Future.delayed(...)`. Needs to POST the new
password together with the `_resetToken` field (already captured from
`AuthOtpRepository.verifyOtp`'s response) to a "confirm reset" endpoint,
e.g. `POST /auth/password/reset { resetToken, newPassword }`. Reject
server-side if the token is missing, expired, or already used.

---

## 3. Login

**File:** `lib/features/auth/presentation/pages/login_page.dart`
**Method:** `_handleSubmit()` (look for the comment `// Simulate network
authentication request`)

Currently mocked with `Future.delayed(const Duration(milliseconds: 800))`.
Replace with a real `POST /auth/login { email, password }` call. On
success, call `widget.onLoginSuccess(role, email)` as before — that's what
drives navigation into the app, so keep that call in place.

---

## 4. Signup

**File:** `lib/features/auth/presentation/pages/signup_page.dart`
**Method:** `_handleSubmit()` (look for the comment `// Simulate network
registration request`)

Currently mocked with `Future.delayed(const Duration(milliseconds: 900))`.
Replace with a real `POST /auth/register { handlerId, email, password,
role, ... }` call. On success it calls `widget.onSignupSuccess(role,
email)`, which now routes the user into OTP verification (not straight
into the app) — that flow is already wired, no change needed there.

---

## Recommended order

1. Login + Signup endpoints (steps 3–4) — unblocks the base auth flow.
2. OTP endpoints (step 1) — unblocks signup e-mail verification and the
   password-reset OTP step.
3. Password reset confirmation (step 2) — depends on OTP being in place.

## Definition of done

- [ ] `AuthOtpRepositoryImpl` calls real endpoints; the `000000`-always-fails
      mock branch is removed.
- [ ] `login_page.dart` and `signup_page.dart` call real endpoints.
- [ ] `forgot_password_page.dart`'s reset confirmation sends `resetToken` +
      `newPassword` to a real endpoint.
- [ ] All error paths (invalid code, expired code, wrong password, email
      already registered, etc.) surface through the existing `_errorText` /
      `UiCallout` UI — no new UI states should be needed, just real error
      messages coming back from the API.
- [ ] No `Future.delayed` or `// Simulate...` / `// TODO(backend)` comments
      remain in the four files above.
