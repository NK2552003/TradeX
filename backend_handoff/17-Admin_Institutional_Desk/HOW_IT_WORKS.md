# 17 — Admin Institutional Desk & Cross-Platform Governance

This document specifies the backend architecture, database schema, Row-Level Security (RLS) policies, and repository contracts for the **Admin Side (`UserRole.userAdmin`)** of TradeX, including full linking across the **Consumer (Trader)** and **Affiliate Partner (INR)** workspaces.

---

## 1. Admin Console Surface Mapping

All 6 Admin Console destinations in [`lib/core/widgets/app_scaffold.dart`](../../lib/core/widgets/app_scaffold.dart) are backed by [`AdminConsoleRepository`](../../lib/features/admin_console/data/admin_console_repository.dart):

| Navigation ID | Screen Widget | Core Responsibilities |
| :--- | :--- | :--- |
| `'overview'` | `AdminOverviewPage` | Executive INR KPI strip (`₹25.00 Cr` supervised capital), Emergency Killswitch / Circuit Breaker toggle, Cumulative Desk P&L vs NIFTY 50 chart, Division Capital Allocation donut chart, Live Pre-Trade Order Approvals, Active Risk Breaches, Cross-Platform Governance Bridge, and SHA-256 Audit Stream. |
| `'org_team'` | `AdminTeamSeatsPage` | 4-Tab Governance Hub: **1. Desk Traders & Seats** (Provision seat, adjust INR capital/drawdown cap, freeze/unfreeze), **2. Consumer Accounts** (Subscription tier overrides in INR, workspace activity), **3. Affiliate Partners (INR)** (Tier promotion, ledger inspection), **4. Account Deletions & Conditional Data Purge Queue**. |
| `'org_risk'` | `AdminRiskCompliancePage` | Interactive Firm Risk Policy sliders (`maxLeverage`, `maxDailyLossPercent`, `maxTotalDrawdownPercent`), Exchange Segment Gates (NSE/BSE NFO Options, MCX, Crypto, Mandatory Stop-Loss, Auto-Liquidate), Pre-Trade High-Notional Order Approval Queue, and Risk Breach Incident Log. |
| `'org_audit'` | `AdminAuditLogPage` | Tamper-evident SHA-256 compliance ledger across `risk_control`, `order_approval`, `seat_governance`, `affiliate_review`, `payout_settlement`, and `account_deletion`, with Table/Timeline switcher, cryptographic proof inspector, and CSV/JSON export. |
| `'org_analytics'` | `AdminAnalyticsPage` | Multi-timeframe (`1W`, `1M`, `3M`, `6M`, `1Y`, `ALL`) Desk Alpha vs NIFTY 50 chart, Platform Subscription & Affiliate SaaS Revenue chart (INR), Division Attribution (`UiBarList` & `UiDonutChart`), and Proprietary Trader Scorecard Leaderboard. |
| `'affiliate_reviews'` | `AffiliateApprovalsPage` | Partner Application KYC/Reach review, **INR Payout Settlement Queue** (UTR settlement with 5% TDS u/s 194H breakdown or rejection/refund), Commission Tier selector, and Media Kit Copy Asset publisher. |

---

## 2. Database Tables & Schema (`027_admin_affiliate_inr_deletion_production.sql`)

Defined in [`database/migrations/027_admin_affiliate_inr_deletion_production.sql`](../../database/migrations/027_admin_affiliate_inr_deletion_production.sql):

1. **`public.organizations`**:
   - Institutional firm root (`id`, `owner_id`, `name`, `slug`, `supervised_capital_inr`, `allocated_capital_inr`, `currency = 'INR'`, `circuit_breaker_state` (`armed`, `tripped`, `halted`), `killswitch_reason`, `settings`).
2. **`public.organization_members`**:
   - Proprietary trader seats (`organization_id`, `user_id`, `handle`, `display_name`, `email`, `role` (`owner`, `admin`, `risk_manager`, `trader`, `analyst`), `desk_division`, `allocated_capital_inr`, `used_margin_inr`, `daily_pnl_inr`, `monthly_pnl_inr`, `win_rate_pct`, `sharpe_ratio`, `current_drawdown_pct`, `max_drawdown_limit_pct`, `open_positions_count`, `status` (`active`, `invited`, `frozen`, `suspended`)).
3. **`public.desk_risk_configs` / `public.desk_risk_policies`**:
   - Firm-wide risk thresholds (`max_leverage`, `max_daily_loss_percent`, `max_total_drawdown_percent`, `max_single_order_inr`, `allow_options`, `allow_crypto`, `allow_commodities`, `require_stop_loss`, `auto_liquidate_on_breach`, `circuit_breaker_armed`).
4. **`public.desk_order_approvals`**:
   - Pre-trade high-notional order queue (`trader_user_id`, `trader_handle`, `trader_name`, `desk_division`, `symbol`, `exchange` (`NSE`, `BSE`, `NFO`, `MCX`), `side`, `quantity`, `order_price_inr`, `notional_value_inr`, `leverage_x`, `stop_loss_inr`, `target_price_inr`, `strategy_name`, `reason_flagged`, `status` (`pending`, `approved`, `rejected`), `reviewer_id`, `reviewer_notes`, `reviewed_at`).
5. **`public.desk_risk_breaches`**:
   - Real-time drawdown, margin, and stop-loss breach incidents (`trader_user_id`, `trader_handle`, `desk_division`, `breach_type`, `severity` (`warning`, `critical`, `halt`), `symbol`, `metric_value_inr`, `threshold_value_inr`, `description`, `status` (`open`, `acknowledged`, `trader_frozen`, `resolved`), `resolution_notes`).
6. **`public.admin_audit_logs`**:
   - Append-only SHA-256 cryptographic compliance log (`actor_id`, `actor_handle`, `actor_role`, `category`, `action`, `target_type`, `target_label`, `severity`, `ip_address`, `sha256_hash`, `details`, `created_at`).

---

## 3. Security Layer & Row-Level Security (RLS)

- **`public.is_admin_caller()` (`SECURITY DEFINER`)**:
  - Checks `public.profiles.user_role IN ('user_admin', 'admin')` or `public.organization_members.role IN ('owner', 'admin', 'risk_manager')` for `auth.uid()`.
- **Strict Table Policies**:
  - `organizations` & `organization_members`: Full CRUD restricted to `public.is_admin_caller()`; individual members have read-only access to their own seat row (`user_id = auth.uid()`).
  - `desk_risk_configs`, `desk_order_approvals`, `desk_risk_breaches`: Full management restricted to `public.is_admin_caller()`; traders can insert/view their own flagged pre-trade orders and breaches.
  - `admin_audit_logs`: Read and insert restricted to `public.is_admin_caller()`; `UPDATE` and `DELETE` are omitted so audit logs remain immutable.
