# 18 — Account Deletion & Conditional Post-Deletion Data Purge

This document specifies the end-to-end **Account Deletion & Conditional Data Purge** architecture across all three AlphaJournal user roles (`customer`, `affiliate`, `user_admin`), fulfilling Indian **DPDP Act 2023** data erasure rights while preserving statutory **Income Tax Act (Section 194H TDS & GST)** financial records when required.

---

## 1. User-Facing Flow (`DeleteAccountPage`)

Located at [`lib/features/settings/presentation/pages/shared/delete_account_page.dart`](../../lib/features/settings/presentation/pages/shared/delete_account_page.dart) and accessible from:
- `SettingsRootPage` (`'delete_account'`)
- `AccountSecurityPage` (Danger Zone -> Delete Account)
- `PrivacySettingsPage` (Data Deletion & Retention -> Delete Account)

### Step 1: Mandatory Post-Deletion Data Purge Condition (`data_purge_condition`)
Every user (`customer`, `affiliate`, `user_admin`) selects one of three explicit conditions governing how their data is deleted after account deletion:
1. **`immediate_purge` (Condition A — Immediate Cascade Data Purge)**:
   - Immediately purges all selected personal, trading, community, AI, and affiliate campaign data domains the moment account deletion is confirmed.
2. **`after_30_day_grace` (Condition B — 30-Day Recovery Grace Period)**:
   - Immediately locks the account and hides public profiles/links, scheduling permanent cascade data purge at `NOW() + INTERVAL '30 days'`. Signing back in or contacting an Admin before `scheduled_purge_at` can cancel and restore the account.
3. **`purge_personal_keep_tax_ledger` (Condition C — Immediate Personal Purge + Statutory INR Tax Ledger Retention)**:
   - Immediately purges all personal profile fields, journals, notes, strategies, watchlists, community posts, messages, AI threads, and referral campaigns, while anonymizing and retaining statutory Indian GST & 5% TDS Form 16A payout ledger records (`affiliate_payouts`) as required under Indian tax law.

### Step 2: Granular Data Domain Checkboxes
- `purge_journals_notes_strategies`: Purges `trades`, `trader_notes`, `strategies`, `watchlists`, `calculator_history`, `universal_links`, and `entity_ticker_links`.
- `purge_community_messages`: Purges `community_posts`, `community_comments`, `unified_comments`, and `chat_messages`.
- `purge_ai_workspace`: Purges `ai_threads`, `ai_messages`, and `ai_saved_setups`.
- `purge_affiliate_campaigns`: Releases custom `/r/:slug` and purges `affiliate_campaigns` and `affiliate_applications`.

### Step 3: Pre-Deletion Workspace Archive & "DELETE" Verification
- Users can prepare a full JSON/CSV archive before confirming.
- Confirmation requires typing `DELETE` in uppercase in a verification modal.

---

## 2. Database Schema & RPC Contracts (`027_admin_affiliate_inr_deletion_production.sql`)

### Table: `public.account_deletion_requests`
- Columns: `id`, `user_id`, `user_email`, `user_display_name`, `user_role`, `reason`, `feedback`, `data_purge_condition`, `purge_journals_notes_strategies`, `purge_community_messages`, `purge_ai_workspace`, `purge_affiliate_campaigns`, `retain_statutory_tax_ledger`, `export_before_delete`, `status` (`pending_grace_period`, `processing_purge`, `data_purged`, `cancelled`), `requested_at`, `scheduled_purge_at`, `purged_at`, `processed_by`, `admin_notes`, `purge_summary`.

### Security Definer Functions:
1. `public.request_account_deletion_with_conditions(...)`:
   - Authenticated RPC that inserts the user's `account_deletion_requests` record.
   - If `p_data_purge_condition IN ('immediate_purge', 'purge_personal_keep_tax_ledger')`, it immediately invokes `public.execute_user_data_purge(v_req_id)` in the same transaction and logs a cryptographic SHA-256 proof to `public.admin_audit_logs`.
   - If `p_data_purge_condition = 'after_30_day_grace'`, it sets `status = 'pending_grace_period'` and `scheduled_purge_at = NOW() + INTERVAL '30 days'`.
2. `public.execute_user_data_purge(p_request_id uuid)`:
   - Executes the cascade delete across all selected tables for `v_req.user_id`, anonymizes `public.profiles`, transitions `status = 'data_purged'`, records `purge_summary` JSONB, and writes a tamper-evident entry to `public.admin_audit_logs`.

---

## 3. Admin Supervision & Execution (`AdminTeamSeatsPage`)
- In the Admin Console (`Traders & Seats` -> `Data Purge` tab), administrators can inspect all pending and completed deletion requests, view the user's chosen condition and data scopes, and either **Execute Conditional Data Purge Now** or **Cancel & Restore Account**.
