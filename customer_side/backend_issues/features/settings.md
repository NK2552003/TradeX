# Backend Feature Audit: Settings, Billing & Team Management

**Component:** `lib/features/settings/`  
**Database Tables:** `public.profiles`, `public.organization_members`, `public.subscriptions`  
**Storage Bucket:** `avatars`  
**Files Evaluated:**  
- `lib/features/settings/data/repositories/profile_settings_repository.dart`  
- `lib/features/settings/data/repositories/organization_settings_repository.dart`  
- `database/migrations/004_affiliate_application_approval.sql`  

---

## 1. Security & Team Member Overwrite

- **Owner Demotion in Team Invites (`organization_settings_repository.dart:121`):**
  - Inviting a team member executes `.upsert()` with `user_id: currentUserId` (the owner's user ID) and the invited role.
  - Overwrites the owner's status and demotes them.
  - **Action:** Create an `organization_invites` table keyed by invite token and email.

---

## 2. Incomplete Account Deletion Backend Flow

- **Simulated Deletion (`profile_settings_repository.dart:255-265`):**
  - Only sets `status = 'pending_approval'`.
  - Retains all user data, trades, and active JWT tokens.
  - Violates Apple App Store Guideline 5.1.1(v) and GDPR Article 17.
  - **Action:** Deploy Supabase Edge Function `functions/v1/delete-account` using `supabaseAdmin.auth.admin.deleteUser(userId)` cascading deletions across all relational tables.

---

## 3. Missing `avatars` Bucket

- **Base64 DB Bloat:**
  - Storage upload fails because `avatars` bucket was never created in SQL.
  - Falls back to writing 2MB base64 data URI into `profiles.avatar_url`.
  - **Action:** Create `avatars` bucket with public read and owner-write RLS policies.
