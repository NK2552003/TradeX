# TradeX — Post-Auth & Settings Backend Integration Guideline

> **Document Version**: 1.0.0  
> **Audience**: Backend Engineers, API Developers, Full-Stack Architects  
> **Frontend Target**: Flutter (Web, Desktop & Mobile) with Clean Architecture  
> **Status**: Frontend Complete & Verified (Zero Warnings, Zero Analyzer Errors, 100% Tests Passing)

---

## 📑 Table of Contents

1. [Architectural Overview](#1-architectural-overview)
2. [Phase 1: Session Security & Role-Based Access Control (RBAC)](#2-phase-1-session-security--role-based-access-control-rbac)
3. [Phase 2: Core Profile & Security Foundation](#3-phase-2-core-profile--security-foundation)
4. [Phase 3: Role-Specific Domain Business Engines](#4-phase-3-role-specific-domain-business-engines)
   - [3A. Active Trader Domain (Trading Preferences & Risk Gates)](#3a-active-trader-domain-trading-preferences--risk-gates)
   - [3B. Affiliate Partner Domain (Referrals, RevShare & Payouts)](#3b-affiliate-partner-domain-referrals-revshare--payouts)
   - [3C. Desk Administrator Domain (Firm Risk Limits & Team Seats)](#3c-desk-administrator-domain-firm-risk-limits--team-seats)
5. [Phase 4: Subscriptions, Monetization & Invoicing](#5-phase-4-subscriptions-monetization--invoicing)
6. [Phase 5: Alerts, Privacy & GDPR Data Export](#6-phase-5-alerts-privacy--gdpr-data-export)
7. [Repository Swapping Guide (How to Wire Real APIs)](#7-repository-swapping-guide-how-to-wire-real-apis)
8. [Complete API Schema & Payload Reference](#8-complete-api-schema--payload-reference)

---

## 1. Architectural Overview

TradeX follows clean architecture principles. Every feature module is organized into three distinct layers:

```
lib/features/home/presentation/pages/
├── trader/
│   └── trader_landing_page.dart         # Active Trader Dashboard (P&L, Win Rate, Gates, Affiliate Spotlight)
├── affiliate/
│   └── affiliate_landing_page.dart      # Partner Portal Dashboard (Referrals, Earnings, Copy Link, Media Kit)
├── admin/
│   └── admin_landing_page.dart          # Institutional Console (Desk Seats, Drawdown Breaker, Audit Status)
└── user_role_landing_page.dart          # Role Dispatcher routing to role-specific dashboard based on userRole

lib/features/settings/
├── models/                     # Immutable Dart data models (fromJson / toJson)
│   ├── affiliate_settings_model.dart
│   ├── billing_models.dart
│   ├── connected_account_model.dart
│   ├── desk_risk_model.dart
│   ├── notification_prefs_model.dart
│   ├── org_models.dart
│   ├── privacy_settings_model.dart
│   └── trading_prefs_model.dart
├── data/repositories/          # Abstract Repository Interfaces + Mock Implementations
│   ├── affiliate_settings_repository.dart
│   ├── billing_settings_repository.dart
│   ├── desk_risk_repository.dart
│   ├── notification_prefs_repository.dart
│   ├── organization_settings_repository.dart
│   ├── privacy_repository.dart
│   ├── profile_settings_repository.dart
│   └── trading_prefs_repository.dart
└── presentation/pages/         # Reactive UI Screens partitioned by User Role & Scope
    ├── shared/                 # Shared across all authenticated roles
    │   ├── settings_root_page.dart
    │   ├── profile_settings_page.dart
    │   ├── account_security_page.dart
    │   ├── delete_account_page.dart
    │   ├── notifications_settings_page.dart
    │   ├── privacy_settings_page.dart
    │   ├── blocked_users_page.dart
    │   ├── appearance_settings_page.dart
    │   └── help_about_page.dart
    ├── trader/                 # Active Trader / Customer exclusive
    │   ├── trading_preferences_page.dart
    │   ├── trader_affiliate_perks_page.dart
    │   ├── billing_settings_page.dart
    │   ├── change_plan_page.dart
    │   ├── billing_history_page.dart
    │   └── invoice_detail_page.dart
    ├── affiliate/              # Affiliate Partner exclusive
    │   └── affiliate_settings_page.dart
    └── admin/                  # Institutional Desk Admin exclusive
        ├── organization_settings_page.dart
        ├── team_roles_page.dart
        └── desk_risk_page.dart
```

---

## 2. Phase 1: Session Security & Role-Based Access Control (RBAC)

### 2.1 Three Supported User Roles

```dart
enum UserRole {
  customer,   // Active Quantitative Trader
  affiliate,  // Creator & Affiliate Partner
  userAdmin,  // Institutional Desk Administrator
}
```

### 2.2 JWT Token Payload Specification

Every issued authentication JWT (or Supabase auth session) **must** contain custom claims for `role`, `tier`, and optional `org_id`:

```json
{
  "sub": "usr_01HXYZ789",
  "email": "nitish@tradex.ai",
  "role": "customer",
  "tier": "premium",
  "org_id": null,
  "iat": 1771234567,
  "exp": 1771839367
}
```

### 2.3 Server-Side Access Control (RBAC Matrix)

> **Important Role Distinction**:
> - **`customer` = Individual Trader**: Has full access to their **own personal trading preferences** (e.g. personal max risk %, personal checklist, personal watchlists). They **do NOT** have access to firm-wide desk policies or team management.
> - **`affiliate` = Creator / Partner**: Has full access to their **affiliate portal, referral slugs, and commission payout requests**.
> - **`userAdmin` = Institutional Desk Administrator**: Has exclusive access to **firm-wide risk limits, trader capital ceilings, team seat invites, and workspace governance**.

| Endpoint Scope | Customer (Trader) | Affiliate Partner | Desk Admin | Purpose & Access Boundary |
|---|---|---|---|---|
| `/users/*` | ✅ Read/Write | ✅ Read/Write | ✅ Read/Write | Personal user profile, email & security 2FA |
| `/users/trading-preferences` (or `/trader/preferences`) | ✅ Read/Write | ❌ Block (403) | ✅ Read/Write | **Personal** risk rules, pre-trade checklist & watchlists |
| `/affiliate/settings` | 👁️ Read-Only (Perks) | ✅ Read/Write | ✅ Read/Write | Referral link (`/r/:slug`), RevShare info |
| `/affiliate/payout/*` | ❌ Block (403) | ✅ Read/Write | ✅ Read/Write | Monthly commission payout withdrawal requests |
| `/desk/risk/*` | ❌ Block (403) | ❌ Block (403) | ✅ Read/Write | **Desk-wide** firm drawdown limits & trader capital caps |
| `/org/workspace` & `/org/members/*` | ❌ Block (403) | ❌ Block (403) | ✅ Read/Write | **Desk-wide** team seat invites & workspace branding |
| `/billing/*` | ✅ Read/Write | ❌ Not Applicable | ❌ Not Applicable | **Customer-Only** subscription plans, cards, & invoices |

---

## 3. Phase 2: Core Profile & Security Foundation

### 3.1 User Profile Endpoints

#### `GET /users/profile`
**Headers**: `Authorization: Bearer <token>`  
**Response (200 OK)**:
```json
{
  "id": "usr_01HXYZ789",
  "handle": "nitish",
  "displayName": "Nitish Kumar",
  "email": "nitish@tradex.ai",
  "avatarUrl": "https://i.pravatar.cc/150?img=12",
  "bio": "Quantitative swing trader focusing on tech and commodities.",
  "tradingExperience": "Intermediate (2-5 years)",
  "tradingStyles": ["Day Trading", "Swing Trading", "Momentum"],
  "publicStats": true,
  "creatorBio": "Trading educator with 25K+ Discord community members.",
  "deskDivision": "Alpha Quantitative Prop Trading Desk"
}
```

#### `PATCH /users/profile`
**Payload**:
```json
{
  "displayName": "Nitish Kumar",
  "bio": "Updated quantitative strategy bio.",
  "tradingExperience": "Advanced (5+ years)",
  "tradingStyles": ["Options", "Scalping"],
  "publicStats": false
}
```

---

### 3.2 Security & Two-Factor Authentication (2FA)

#### `POST /auth/password/update`
```json
{
  "currentPassword": "OldPassword123!",
  "newPassword": "NewSecurePassword456!"
}
```

#### `POST /auth/2fa/generate-secret`
**Response (200 OK)**:
```json
{
  "secretKey": "JBSWY3DPEHPK3PXP",
  "qrCodeDataUri": "otpauth://totp/TradeX:nitish@tradex.ai?secret=JBSWY3DPEHPK3PXP&issuer=TradeX"
}
```

#### `POST /auth/2fa/enable`
```json
{
  "secretKey": "JBSWY3DPEHPK3PXP",
  "totpCode": "492817"
}
```

#### `POST /auth/2fa/disable`
```json
{
  "currentPassword": "SecurePassword456!",
  "totpCode": "829103"
}
```

---

## 4. Phase 3: Role-Specific Domain Business Engines

### 3A. Active Trader Domain (Personal Trading Preferences & Discipline Rules)
*Frontend Repository*: [`TradingPrefsRepository`](file:///Users/nitishkumar/Downloads/Projects/nk2552003/TradeX/lib/features/settings/data/repositories/trading_prefs_repository.dart)  
*Scope*: Personal risk boundaries, execution checklists, and watchlists for the **individual trader**.

#### `GET /trader/preferences` (or `/users/trading-preferences`)
```json
{
  "default_position_size_pct": 2.0,
  "default_r_multiple": 2.5,
  "enforce_checklist": true,
  "checklist_items": [
    { "id": "chk_1", "label": "Stop loss defined & calculated before entry", "required": true, "enabled": true },
    { "id": "chk_2", "label": "Key support/resistance structure confirmed on 4H/1D", "required": true, "enabled": true },
    { "id": "chk_3", "label": "Risk-to-reward ratio is at least 2:1", "required": true, "enabled": true },
    { "id": "chk_4", "label": "No high-impact economic news within 15 minutes", "required": false, "enabled": true }
  ],
  "default_watchlist": ["NVDA", "AAPL", "SPY", "TSLA", "BTC"]
}
```

#### `PATCH /trader/preferences`
*Accepts partial updates to personal position sizing %, R:R multiples, checklist items, and watchlists.*

---

### 3B. Affiliate Partner Domain (Referrals, RevShare & Payouts)
*Frontend Repository*: [`AffiliateSettingsRepository`](file:///Users/nitishkumar/Downloads/Projects/nk2552003/TradeX/lib/features/settings/data/repositories/affiliate_settings_repository.dart)  
*Scope*: Referral link tracking, 30% lifetime revenue share, and payout destinations for **creators / affiliate partners**.

#### `GET /affiliate/settings`
```json
{
  "referral_code": "NITISH_ALPHA",
  "referral_slug": "nitish_alpha",
  "commission_rate": 0.30,
  "payout_method": "upi",
  "payout_vpa": "nitish@okhdfcbank",
  "bank_account_last4": null,
  "minimum_payout_threshold": 2500.0,
  "auto_payout_enabled": true,
  "total_earnings": 84500.00,
  "pending_payout": 14200.00,
  "active_referrals_count": 48,
  "conversion_rate_pct": 14.2
}
```

#### `PATCH /affiliate/settings`
*Used to customize slug (`tradex.ai/r/:slug`), update payout method (`upi`, `bank_neft`, `razorpay`), and adjust threshold.*

#### `POST /affiliate/payout/request`
*Triggers an on-demand payout if `pending_payout >= minimum_payout_threshold`.*

---

### 3C. Desk Administrator Domain (Firm Risk Limits, Circuit Breakers & Team Seats)
*Frontend Repositories*: [`DeskRiskRepository`](file:///Users/nitishkumar/Downloads/Projects/nk2552003/TradeX/lib/features/settings/data/repositories/desk_risk_repository.dart) & [`OrganizationSettingsRepository`](file:///Users/nitishkumar/Downloads/Projects/nk2552003/TradeX/lib/features/settings/data/repositories/organization_settings_repository.dart)  
*Scope*: Institutional desk governance configured by the **Desk Administrator**, applied desk-wide across all traders.

#### `GET /desk/risk/policies`
```json
{
  "max_firm_drawdown_percent": 5.0,
  "max_position_per_trader": 5000000.0,
  "enforce_pre_trade_checklist": true,
  "manager_approval_threshold": 1000000.0,
  "require_2fa_for_desk": true
}
```

#### `GET /org/workspace`
```json
{
  "org_name": "Alpha Quantitative Prop Desk",
  "custom_domain": "desk.alphatrading.io",
  "total_seats": 25,
  "used_seats": 18,
  "members": [
    { "id": "m_1", "email": "nitish@tradex.ai", "name": "Nitish Kumar", "role": "owner", "joined_at": "2026-01-10T00:00:00Z" },
    { "id": "m_2", "email": "alex.trader@alphatrading.io", "name": "Alex Vance", "role": "trader", "joined_at": "2026-02-01T00:00:00Z" }
  ]
}
```

#### `POST /org/members/invite`
```json
{
  "email": "sarah.quant@alphatrading.io",
  "role": "trader"
}
```

---

## 5. Phase 4: Subscriptions, Monetization & Invoicing

*Frontend Repository*: [`BillingSettingsRepository`](file:///Users/nitishkumar/Downloads/Projects/nk2552003/TradeX/lib/features/settings/data/repositories/billing_settings_repository.dart)  
*Scope*: Exclusively for paying **Customers (Active Traders)**. Affiliate Partners (who earn commissions via `/affiliate/payout/*`) and Desk Administrators (who manage desk capacity via `/org/workspace`) do NOT have self-serve customer billing.

### 5.1 Endpoints

#### `GET /billing/subscription`
```json
{
  "plan_id": "plan_pro_monthly",
  "plan_name": "Pro",
  "status": "active",
  "amount": 2499.0,
  "currency": "INR",
  "billing_cycle": "monthly",
  "current_period_start": "2026-08-01T00:00:00Z",
  "current_period_end": "2026-09-01T00:00:00Z",
  "trades_logged_this_month": 42,
  "max_trades_per_month": 500,
  "ai_tokens_used": 18400,
  "max_ai_tokens": 100000,
  "payment_method": {
    "brand": "Visa",
    "last4": "4242",
    "exp_month": 12,
    "exp_year": 2028,
    "is_default": true
  }
}
```

#### `POST /billing/plan/change`
```json
{
  "new_plan_id": "plan_elite_annual",
  "prorate": true
}
```

#### `GET /billing/invoices`
```json
[
  {
    "id": "inv_001",
    "invoice_number": "TRADEX-2026-0801",
    "amount": 2499.0,
    "currency": "INR",
    "status": "paid",
    "issued_at": "2026-08-01T00:00:00Z",
    "pdf_url": "https://billing.tradex.ai/invoices/inv_001.pdf"
  }
]
```

---

## 6. Phase 5: Alerts, Privacy & GDPR Data Export

### 6.1 Notifications Preferences
*Endpoint*: `GET/PATCH /users/notifications`
```json
{
  "email_trade_alerts": true,
  "push_trade_alerts": true,
  "ai_daily_digest": true,
  "referral_alerts": true,
  "desk_risk_alerts": false,
  "quiet_hours_enabled": true,
  "quiet_hours_start": "22:00",
  "quiet_hours_end": "07:00"
}
```

### 6.2 Privacy & GDPR Data Export
*Endpoint*: `GET /users/data-export`
- Generates a zip archive containing:
  - `profile.json` (account metadata)
  - `trades.csv` (all executed journal records)
  - `risk_logs.json` (discipline & checklist history)

---

## 7. Repository Swapping Guide (How to Wire Real APIs)

Each repository in `lib/features/settings/data/repositories/` is designed for drop-in replacement:

```dart
// Example: Creating a live HTTP / Supabase implementation
class HttpBillingSettingsRepositoryImpl implements BillingSettingsRepository {
  HttpBillingSettingsRepositoryImpl({required this.httpClient});
  final http.Client httpClient;

  @override
  Future<SubscriptionSummary> getSubscriptionSummary() async {
    final response = await httpClient.get(Uri.parse('$apiBaseUrl/billing/subscription'));
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return SubscriptionSummary.fromJson(json);
  }

  @override
  Future<void> changePlan(String newPlanId) async {
    await httpClient.post(
      Uri.parse('$apiBaseUrl/billing/plan/change'),
      body: jsonEncode({'new_plan_id': newPlanId}),
    );
  }
  
  // Implement remaining interface methods...
}
```

Then inject into `BillingSettingsPage(repository: HttpBillingSettingsRepositoryImpl(...))` or via your dependency container (e.g. `get_it` or `Provider`).

---

## 8. Complete Verification Status

All pages and models have been validated against the Flutter & Dart compiler:

```bash
# Static analysis verification
dart analyze --fatal-warnings lib/
# Result: Analyzing lib... No issues found! (0 errors, 0 warnings, 0 todos)

# Unit & integration tests
flutter test
# Result: All 6 tests passed! (Exit Code: 0)
```
