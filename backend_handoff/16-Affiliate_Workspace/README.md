# 16 — Affiliate Workspace (100% INR `₹` Production Specification)

The affiliate role answers every partner destination: Partner Hub (`overview`), Referrals (`referrals`), Campaign Studio (`marketing`), Payouts (`payouts`), and Affiliate Settings (`settings_affiliate`), plus Admin Partner & INR Payout Governance (`affiliate_reviews`). Existing Notes, Strategies, Community, Messages, and AI pages remain shared.

---

## 1. Currency & Indian Regulatory Mandate (100% INR `₹` — Zero USD)

- **Settlement Currency**: Exclusively **Indian Rupees (`INR` / `₹`)** across `affiliate_profiles`, `affiliate_commission_tiers`, `affiliate_referrals`, `affiliate_payouts`, and `affiliate_applications`.
- **Minimum Payout Threshold**: `₹1,000.00 INR` (`minimum_payout_threshold >= 1000`).
- **Indian Payout Rails**:
  - `upi` — NPCI UPI Virtual Payment Address (e.g., `name@okhdfcbank`)
  - `bank_neft` — Indian Bank NEFT Transfer (with 11-character IFSC code)
  - `bank_imps` — Instant IMPS Bank Transfer
  - `bank_rtgs` — High-Value RTGS Transfer (`>= ₹2,00,000`)
- **Statutory Tax Compliance**:
  - **5% TDS u/s 194H**: Deducted automatically at source on gross INR commission payouts (`tds_rate = 0.0500`), backed by verified 10-character Indian **PAN** (`^[A-Z]{5}[0-9]{4}[A-Z]{1}$`) and quarterly Form 16A certificate generation.
  - **Optional 18% GST Input Credit**: Supported when partner provides a valid 15-character **GSTIN** (`^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$`).

---

## 2. Database Migrations & Dynamic Schema (`026` + `027`)

Apply:
1. `database/migrations/026_affiliate_workspace.sql`
2. `database/migrations/027_admin_affiliate_inr_deletion_production.sql`

### Dynamic Tables (Nothing Hardcoded):
- `public.affiliate_commission_tiers`:
  - Stores dynamic tier ladders (`standard` 15%, `silver` 20%, `gold` 25%, `platinum` 35%), `min_converted_referrals`, `min_payout_threshold_inr` (`₹1,000`), `tds_rate` (`5%`), and `benefits` JSON array.
- `public.affiliate_program_terms`:
  - Stores dynamic SEBI IA/RA, ASCI influencer disclosure, Income Tax Section 194H TDS, 30-day attribution window, and prohibited self-referral clauses returned directly inside `affiliate_workspace()`.
- `public.affiliate_profiles`:
  - Includes `currency = 'INR'`, `minimum_payout_threshold = 1000.00`, `tds_rate = 0.0500`, `gst_registered`, `gstin`, `pan_number`, `terms_version_accepted`, and `payout_details` JSONB (`account_holder_name`, `bank_name`, `account_number`, `ifsc_code`, `upi_vpa`, `pan_number`, `gstin`).
- `public.affiliate_payouts`:
  - Stores `currency = 'INR'`, `gross_amount`, `tds_amount`, `gst_amount`, `net_amount`, `payout_method`, `payout_destination`, `transaction_reference` (UTR), and `balance_reserved`.

---

## 3. Trusted Backend RPCs

- `public.affiliate_workspace()`:
  - Authenticated partner read returning `{ enrolled, profile, campaigns, referrals, payouts, assets, tiers, terms }`.
- `public.request_affiliate_payout(p_amount numeric)`:
  - Validates `p_amount >= 1000` (₹1,000 INR), locks the partner row, computes 5% TDS and net INR disbursement, reserves balance atomically, and snapshots the UPI/Bank IFSC destination.
- `public.admin_review_affiliate_payout(p_payout_id uuid, p_approve boolean, p_reference_code text, p_notes text)`:
  - Admin-only (`public.is_admin_caller()`) settlement RPC that marks a pending INR payout as `paid` with a bank/NPCI UTR reference or `cancelled` (automatically refunding the reserved INR balance via trigger) and writes a tamper-evident entry to `public.admin_audit_logs`.
- `public.review_affiliate_application(p_application_id uuid, p_approve boolean, p_review_notes text)`:
  - Admin-only RPC approving or rejecting partner applications and provisioning the partner's INR `affiliate_profiles` record.
