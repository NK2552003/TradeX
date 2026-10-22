# Backend Feature Audit: Affiliate Program

**Component:** `lib/features/affiliate_program/` & `settings/trader/`  
**Database Tables:** `public.affiliate_applications`, `public.affiliates`  
**Files Evaluated:**  
- `database/migrations/004_affiliate_application_approval.sql`  
- `database/migrations/003_affiliates_and_auth_triggers.sql`  

---

## 1. Critical Public Data Exposure (Zero RLS)

- **Unrestricted Access to Bank & PAN Data:**
  - Table `affiliate_applications` contains applicant full name, phone number, PAN card number, bank account number, and IFSC code.
  - **No RLS was enabled on the table.**
  - Any anon user can dump all applicant records via PostgREST.
  - **Action:** Execute `ALTER TABLE affiliate_applications ENABLE ROW LEVEL SECURITY;` and restrict reads to owners and admins.

---

## 2. Insecure Approval RPC & Referral Balance Exploitation

- **Unauthorized RPC Execution:**
  - Function `approve_affiliate_application` is `SECURITY DEFINER` without admin authorization checks.
  - Any applicant can self-approve their application and set an arbitrary commission rate.
  - **Action:** Add `IF NOT is_user_admin() THEN RAISE EXCEPTION 'Forbidden'; END IF;`.
- **Infinite $50 Balance Inflation (`003_affiliates_and_auth_triggers.sql:145-151`):**
  - Sign-up trigger immediately credits $50.00 to the affiliate's `unpaid_balance` upon user creation, without email verification or payment.
  - Attackers can create throwaway accounts and drain referral budgets.
  - **Action:** Credit affiliate balance only upon confirmed subscription payment via payment webhook.
