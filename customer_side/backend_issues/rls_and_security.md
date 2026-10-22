# Backend Architecture: Row Level Security (RLS) & Access Control Audit

**Target Audience:** Supabase / PostgreSQL / Security Engineers  
**Scope:** PostgreSQL RLS Policies, Database Triggers, RPC Functions, Role Escalation Vulnerabilities, and Identity Protection  
**Date:** 2026-10-21  

---

## 1. Executive Summary & Security Posture

A comprehensive analysis of `database/migrations/` (files 001 through 025) and `database/rls_policies.sql` revealed multiple **critical, unauthenticated privilege escalation vulnerabilities and public data exposure flaws**. Row Level Security is either absent, improperly bypassed by client-side writes, or compromised by insecure `SECURITY DEFINER` functions.

---

## 2. In-Depth Vulnerability Breakdown & SQL Patches

### 2.1. Untrusted Sign-Up Trigger Metadata Escalation
- **Location:** `database/migrations/003_affiliates_and_auth_triggers.sql` (Lines 84–118).
- **Vulnerable Code:**
  ```sql
  CREATE OR REPLACE FUNCTION public.handle_new_user_signup()
  RETURNS TRIGGER AS $$
  DECLARE
      v_role user_role;
      ...
  BEGIN
      -- Reads unvalidated JSON metadata supplied by client:
      v_role := COALESCE(
          (NEW.raw_user_meta_data->>'role')::user_role,
          'trader'::user_role
      );
      ...
      INSERT INTO public.profiles (id, email, role, subscription_tier, status)
      VALUES (
          NEW.id,
          NEW.email,
          v_role,
          CASE WHEN v_role = 'user_admin' THEN 'enterprise'::subscription_tier ELSE 'free'::subscription_tier END,
          'active'
      );
  ```
- **Exploitation:** An attacker signs up via standard Supabase Auth passing client metadata:
  ```json
  { "email": "attacker@evil.com", "password": "...", "data": { "role": "user_admin" } }
  ```
  The database trigger provisions the user with root administrator privileges (`role: 'user_admin'`) and grants them an enterprise subscription tier immediately.
- **Remediation SQL:**
  ```sql
  CREATE OR REPLACE FUNCTION public.handle_new_user_signup()
  RETURNS TRIGGER AS $$
  BEGIN
      -- Unconditionally enforce trader role and free tier on self-signup:
      INSERT INTO public.profiles (id, email, role, subscription_tier, status)
      VALUES (NEW.id, NEW.email, 'trader'::user_role, 'free'::subscription_tier, 'active');
      RETURN NEW;
  END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;
  ```

---

### 2.2. Zero RLS on Sensitive Affiliate Banking & PAN Data
- **Location:** `database/migrations/004_affiliate_application_approval.sql` (Lines 10–35).
- **Vulnerability:** Migration 004 creates the `affiliate_applications` table to store applicants' full names, phone numbers, Indian PAN cards, bank account numbers, and IFSC codes.
- **Defect:** **The migration completely fails to enable Row Level Security.**
- **Exploitation:** Anyone possessing the public Supabase `anon` key can run:
  ```http
  GET https://<project>.supabase.co/rest/v1/affiliate_applications?select=*
  ```
  This dumps the bank accounts and tax credentials of every applicant.
- **Remediation SQL:**
  ```sql
  ALTER TABLE public.affiliate_applications ENABLE ROW LEVEL SECURITY;

  CREATE POLICY affiliate_applications_user_all ON public.affiliate_applications
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

  CREATE POLICY affiliate_applications_admin_read ON public.affiliate_applications
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'user_admin'));
  ```

---

### 2.3. Direct Client Subscription Tier Forgery
- **Location:** `database/migrations/001_core_schema.sql` (Lines 48–55).
- **Vulnerable Code:**
  ```sql
  CREATE POLICY subscriptions_own_write ON subscriptions
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
  ```
- **Vulnerability:** `subscriptions_own_write` grants every user write permissions on their own subscription row. Any user can send an HTTP `PATCH /rest/v1/subscriptions` setting `{"plan_tier": "institutional", "status": "active"}` to unlock the platform for free.
- **Remediation SQL:**
  ```sql
  DROP POLICY IF EXISTS subscriptions_own_write ON subscriptions;

  -- Subscriptions must be strictly read-only for clients:
  CREATE POLICY subscriptions_own_read ON subscriptions
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
  -- Mutations must be performed strictly via service_role payment webhooks!
  ```

---

### 2.4. Unauthenticated RPC Application Approval
- **Location:** `database/migrations/004_affiliate_application_approval.sql` (Lines 40–118).
- **Vulnerability:** Function `approve_affiliate_application` is marked `SECURITY DEFINER` but completely lacks an authorization check verifying that `auth.uid()` has `role = 'user_admin'`.
- **Exploitation:** Any authenticated applicant can call `POST /rest/v1/rpc/approve_affiliate_application` to self-approve their application and set an arbitrary commission rate (e.g. 50%).
- **Remediation SQL:**
  ```sql
  CREATE OR REPLACE FUNCTION approve_affiliate_application(
      p_application_id UUID,
      p_commission_rate NUMERIC DEFAULT 0.20
  )
  RETURNS JSONB
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $$
  BEGIN
      IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'user_admin') THEN
          RAISE EXCEPTION 'Access Denied: Only administrators can approve affiliate applications.';
      END IF;
      ...
  ```

---

### 2.5. Profile Role Escalation via Incomplete `WITH CHECK`
- **Location:** `database/rls_policies.sql` (Lines 130–145).
- **Vulnerability:** `profiles_update` policy allows users to update their own profile row without column restrictions. An authenticated user can update `role = 'user_admin'`.
- **Remediation SQL:**
  ```sql
  CREATE OR REPLACE FUNCTION protect_profile_columns()
  RETURNS TRIGGER AS $$
  BEGIN
      IF NEW.role IS DISTINCT FROM OLD.role AND NOT EXISTS (
          SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'user_admin'
      ) THEN
          RAISE EXCEPTION 'Unauthorized: Users cannot alter their own system role.';
      END IF;
      RETURN NEW;
  END;
  $$ LANGUAGE plpgsql;

  CREATE TRIGGER trg_protect_profile_columns
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION protect_profile_columns();
  ```

---

### 2.6. Missing Public Strategy Versions RLS Policy
- **Location:** `database/rls_policies.sql` (Lines 98–108).
- **Defect:** `strategy_versions` only has policy `strategy_versions_own_all`. When external visitors view a public strategy, PostgREST returns an empty version list because `auth.uid() != s.user_id`.
- **Remediation SQL:**
  ```sql
  CREATE POLICY strategy_versions_public_read ON strategy_versions
  FOR SELECT TO authenticated, anon
  USING (
      EXISTS (
          SELECT 1 FROM strategies s
          WHERE s.id = strategy_versions.strategy_id
            AND s.visibility = 'public'
      )
  );
  ```
