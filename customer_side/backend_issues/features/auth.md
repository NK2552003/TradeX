# Backend Feature Audit: Authentication & Identity

**Component:** `lib/features/auth/` & `database/migrations/`  
**Database Tables:** `auth.users`, `public.profiles`, `public.subscriptions`  
**Files Evaluated:**  
- `database/migrations/003_affiliates_and_auth_triggers.sql`  
- `database/migrations/001_core_schema.sql`  
- `lib/features/auth/data/repositories/supabase_auth_otp_repository.dart`  
- `lib/features/auth/data/services/auth_session_storage.dart`  

---

## 1. Critical Vulnerabilities & Exploits

### 1.1. Untrusted Trigger Metadata Role Escalation (P0)
- **Location:** `003_affiliates_and_auth_triggers.sql:84-118`.
- **Defect:** `handle_new_user_signup()` reads `NEW.raw_user_meta_data->>'role'` directly from the unauthenticated client request.
- **Exploitation:** Supplying `data: {"role": "user_admin"}` grants full administrator role and enterprise subscription tier upon registration.
- **Action:** Patch trigger to ignore client `role` metadata and unconditionally set `role = 'trader'` and tier = `'free'`.

### 1.2. Universal OTP Bypass Fallback
- **Location:** `supabase_auth_otp_repository.dart:77-83`.
- **Defect:** On network timeout or error, code falls back to `AuthOtpRepositoryImpl` which accepts any 6-digit code except `000000`.
- **Action:** Remove mock fallback; throw explicit authentication error to client.

### 1.3. Plaintext JWT Storage in SharedPreferences
- **Location:** `auth_session_storage.dart:26-55`.
- **Defect:** Active JWT access and refresh tokens are written unencrypted to XML/plist on mobile and `localStorage` on web.
- **Action:** Migrate to `flutter_secure_storage` using Android Keystore / iOS Keychain.
