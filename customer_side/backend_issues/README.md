# TradeX Backend Developer Handoff & Issue Registry

**Target Audience:** Backend / Supabase / PostgreSQL / Cloud Platform Engineers  
**Scope:** PostgreSQL Migrations, Row Level Security (RLS) Policies, Supabase Storage Buckets & Folder Hierarchies, Realtime Channels, Edge Functions, Third-Party Payments (Stripe/Razorpay), and Data Governance.  
**Auditor:** Antigravity AI Engineering Team  
**Date:** 2026-10-21  

---

## 1. Executive Summary & Backend Health Dashboard

A comprehensive audit of the database migrations (`database/migrations/001` through `025`), database policies (`database/rls_policies.sql`), and server integration repositories revealed **critical privilege escalation flaws, public leakage of unencrypted banking and tax KYC data, 100% rejection of user file uploads, fatal column name mismatches breaking live data synchronization, and over 22 MB of static JSON mock files simulating a live exchange terminal**.

```
┌────────────────────────────────────────────────────────────────────────┐
│                      BACKEND HEALTH DASHBOARD                          │
├──────────────────────────────┬──────────────────┬──────────────────────┤
│ Metric                       │ Value            │ Status               │
├──────────────────────────────┼──────────────────┼──────────────────────┤
│ Live Database Synchronization│ 22%              │ ⚠️ Heavy Mock Rely   │
│ Production RLS Integrity     │ CRITICAL FAIL    │ 🚨 Privilege Escal. │
│ Storage Upload Success Rate  │ 0%               │ ❌ 100% 403 Denied   │
│ Real-Time DM Privacy         │ FAIL (IDOR)      │ 🚨 Public Broadcast  │
│ KYC / Tax Data Protection    │ FAIL (NO RLS)    │ 🚨 Publicly Leaked   │
│ Real Exchange Feed           │ 0% Live          │ ❌ Static Bundled    │
│ Payment Processing Backend   │ 0% Integrated    │ ❌ Dummy Simulation  │
└──────────────────────────────┴──────────────────┴──────────────────────┘
```

---

## 2. P0 / P1 Critical Backend Vulnerabilities

| Priority | Vulnerability / Defect | Location | Severity | Immediate Remediation |
| :---: | :--- | :--- | :---: | :--- |
| **P0** | **Catastrophic Bank & PAN Tax Leak** | `004_affiliate_application_approval.sql` | **CRITICAL** | `affiliate_applications` has **zero RLS** enabled; anyone with anon key can dump applicant full names, phone numbers, bank accounts, IFSC, and Indian PAN cards. Enable RLS and owner-read policies immediately. |
| **P0** | **Untrusted Sign-Up Role Escalation** | `003_affiliates_and_auth_triggers.sql:84-118` | **CRITICAL** | `handle_new_user_signup()` reads `NEW.raw_user_meta_data->>'role'`; supplying `{"role": "user_admin"}` grants full administrator access and enterprise tier upon registration. |
| **P0** | **Client Subscription Tier Forgery** | `001_core_schema.sql:48-55` | **CRITICAL** | `subscriptions_own_write` RLS allows any user to execute `INSERT`/`UPDATE` on their own row, granting themselves free `institutional` access without paying. |
| **P0** | **Global Real-Time Direct Message Leakage (IDOR)** | `018_messages_realtime.sql` & client repo | **CRITICAL** | Realtime subscription on `chat_messages` lacks thread filters or private channel constraints, broadcasting all private chats platform-wide. |
| **P0** | **Universal OTP Verification Bypass** | `supabase_auth_otp_repository.dart:77-83` | **CRITICAL** | Error catch block falls back to mock repository accepting any 6-digit code except `000000`, bypassing auth. |
| **P0** | **100% Storage Attachment Upload Denial** | `notes`, `journal`, `strategies`, `community` | **CRITICAL** | Storage RLS checks `(storage.foldername(name))[1] = auth.uid()::text`, while client uploads to `$entityId/...`. 100% of uploads return 403 Forbidden. |
| **P0** | **Schema Mismatch Breaking 100% of Journal Operations** | `journal_repository.dart:207, 450, 490, 536` | **CRITICAL** | Client queries `.select('*, strategies(name)')`. The database column is `title`, NOT `name`. Throws `PGRST100` on every operation, falling back to RAM. |
| **P0** | **Statutory Tax Miscalculation (Finance Act 2024)** | `tax_calculators.dart:18-44` | **CRITICAL** | Equity capital gains calculations use outdated rates (STCG 15% vs 20%, LTCG 10% vs 12.5%, exemption ₹1.0L vs ₹1.25L), providing non-compliant tax figures to traders. |
| **P1** | **Exposed `.env` File in Compiled Assets** | `pubspec.yaml` (lines 92–95) | **HIGH** | Plaintext production Supabase URLs and Anon keys are bundled into binary assets. Remove from `pubspec.yaml` and pass via `--dart-define`. |
| **P1** | **Database Bloat via 2MB Base64 Avatars** | `profile_settings_repository.dart:180-195` | **HIGH** | `avatars` bucket does not exist in RLS policies; repository catches 403 error and writes a 2MB raw base64 data URI into `profiles.avatar_url`. |
| **P1** | **Fatal PostgREST Schema Mismatches on Watchlists** | `005_watchlists.sql` vs client repo | **HIGH** | `watchlist_items` in SQL only has `symbol`, but client queries `ticker`, `category`, `is_favorite`, `price_alert_threshold`. Throws SQL column errors. |
| **P1** | **Synthetic UUID Type Collisions** | `025_entity_ticker_links.sql` & client repos | **HIGH** | Client generates string IDs (`etl_0001_${timestamp}` and `note_ai_${uid}`) and upserts them into `UUID PRIMARY KEY` columns, failing with error `22P02`. |

---

## 3. Directory Navigation for Backend Engineers

All backend issues are broken down into cross-cutting architectural specifications and 15 feature-specific implementation briefs:

```
customer_side/backend_issues/
├── README.md                                  # This document
├── rls_and_security.md                        # RLS policies, privilege escalation, role protection & KYC leaks
├── storage_architecture.md                    # Bucket configurations, folder conventions, 403 upload fixes & signed URLs
├── schema_and_migrations.md                   # Column mismatches, UUID type errors, missing tables & migration fixes
│
└── features/
    ├── auth.md                                # handle_new_user_signup trigger, OTP bypass, plaintext session storage
    ├── community.md                           # RLS block checks, delete IDOR, missing profile columns, fake SEBI license
    ├── journal.md                             # strategies(name) vs strategies(title) join bug, storage 403, signed URLs
    ├── notes.md                               # Note attachments storage path 403, signed URLs, real Edge Function AI refactor
    ├── strategies.md                          # strategy_versions_public_read missing policy, storage 403, mirror array triggers
    ├── market_data.md                         # 22MB static mock JSON replacement, Supabase Edge Function market quote proxy
    ├── watchlists.md                          # Schema mismatch on watchlist_items (symbol vs ticker), live quote joins
    ├── ai_assistant.md                        # 'note_ai_...' non-UUID crash, Edge Function LLM streaming endpoint
    ├── calculators.md                         # Wire calculator_history table, Finance Act 2024 tax rates, lot sizes
    ├── settings.md                            # approve_affiliate_application RPC lockdown, avatars bucket, real deletion Edge Function
    ├── workspace.md                           # N+1 query optimization via inFilter, non-UUID link edge pollution
    ├── affiliate_program.md                   # Enable RLS on affiliate_applications, fix infinite $50 balance exploit
    ├── public_site.md                         # Dynamic pricing catalogue synchronization, purge false AES-256 claims
    ├── linking.md                             # 'etl_...' non-UUID type collision on entity_ticker_links
    └── messages.md                            # Realtime private channel lockdown, cleartext DB storage, empty state fix
```

---

## 4. Backend Developer Priorities & Working Rules

1. **Rule #1: Zero Unrestricted Table Access:**
   - Every table must have `ALTER TABLE <table_name> ENABLE ROW LEVEL SECURITY;`.
   - Never allow authenticated clients to update critical entitlement columns (`role`, `subscription_tier`, `commission_rate`, `unpaid_balance`).
2. **Rule #2: Enforce Three-Tier Storage Path Convention:**
   - Client and storage RLS policies must strictly conform to:
     `<bucket>/<user_id>/<entity_id>/<file_name>`
3. **Rule #3: Never Trust Client Metadata on Auth:**
   - In database triggers (`NEW.raw_user_meta_data`), discard any user-supplied role or entitlement claims. Always default new accounts to `trader` and `free` tier.
4. **Rule #4: Service Role Isolation:**
   - Administrative mutations (plan changes, KYC verification, account deletions) must execute inside Supabase Edge Functions utilizing `SUPABASE_SERVICE_ROLE_KEY`. Never expose `service_role` keys to clients.
