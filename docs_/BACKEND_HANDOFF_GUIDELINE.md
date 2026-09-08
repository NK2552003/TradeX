# TradeX backend integration guide: Authentication and settings

Document version: 1.0.0  
Audience: Backend engineers, API developers, and full stack architects  
Frontend target: Flutter (Web, Desktop, and Mobile) with clean architecture  
Status: Frontend complete and verified with passing test suites

---

## Table of contents

1. [Architectural overview](#1-architectural-overview)
2. [Phase 1: Session security and role-based access control](#2-phase-1-session-security-and-role-based-access-control-rbac)
3. [Phase 2: Core profile and security foundation](#3-phase-2-core-profile-and-security-foundation)
4. [Phase 3: Role-specific domain business engines](#4-phase-3-role-specific-domain-business-engines)
   - [3A. Active trader domain](#3a-active-trader-domain-personal-trading-preferences-and-discipline-rules)
   - [3B. Affiliate partner domain](#3b-affiliate-partner-domain-referrals-revshare-and-payouts)
   - [3C. Desk administrator domain](#3c-desk-administrator-domain-firm-risk-limits-circuit-breakers-and-team-seats)
5. [Phase 4: Subscriptions, monetization, and invoicing](#5-phase-4-subscriptions-monetization-and-invoicing)
6. [Phase 5: Alerts, privacy, and data export](#6-phase-5-alerts-privacy-and-gdpr-data-export)
7. [Repository swapping guide](#7-repository-swapping-guide-how-to-wire-real-apis)
8. [Verification status](#8-complete-verification-status)

---

## 1. Architectural overview

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

## 2. Phase 1: Session security and role-based access control (RBAC)

### 2.1 Three supported user roles

```dart
enum UserRole {
  customer,   // Active Quantitative Trader
  affiliate,  // Creator & Affiliate Partner
  userAdmin,  // Institutional Desk Administrator
}
```

### 2.2 JWT token payload specification

Every issued authentication JWT (or Supabase auth session) must contain custom claims for `role`, `tier`, and optional `org_id`:

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

### 2.3 Server-side access control (RBAC matrix)

Role boundaries:
- `customer` (Individual Trader): Full access to personal trading preferences (such as risk percentages, personal checklists, and watchlists). Does not have access to desk-wide policies or team settings.
- `affiliate` (Creator / Partner): Full access to the affiliate portal, referral slugs, and commission payout requests.
- `userAdmin` (Institutional Desk Administrator): Access to firm-wide risk controls, trader capital allocations, team seat invitations, and workspace governance.

| Endpoint scope | Customer (Trader) | Affiliate partner | Desk admin | Purpose and access boundary |
|---|---|---|---|---|
| `/users/*` | Read/Write | Read/Write | Read/Write | Personal user profile, email, and 2FA settings |
| `/users/trading-preferences` (or `/trader/preferences`) | Read/Write | Block (403) | Read/Write | Personal risk rules, pre-trade checklist, and watchlists |
| `/affiliate/settings` | Read-only (Perks) | Read/Write | Read/Write | Referral link (`/r/:slug`) and revenue share info |
| `/affiliate/payout/*` | Block (403) | Read/Write | Read/Write | Monthly commission payout withdrawal requests |
| `/desk/risk/*` | Block (403) | Block (403) | Read/Write | Desk-wide firm drawdown limits and capital caps |
| `/org/workspace` and `/org/members/*` | Block (403) | Block (403) | Read/Write | Desk-wide team seat invites and workspace branding |
| `/billing/*` | Read/Write | Not applicable | Not applicable | Customer subscription plans, cards, and invoices |

---

## 3. Phase 2: Core profile and security foundation

### 3.1 User profile endpoints

#### `GET /users/profile`
Headers: `Authorization: Bearer <token>`  
Response (200 OK):
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
Payload:
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

### 3.2 Security and two-factor authentication (2FA)

#### `POST /auth/password/update`
```json
{
  "currentPassword": "OldPassword123!",
  "newPassword": "NewSecurePassword456!"
}
```

#### `POST /auth/2fa/generate-secret`
Response (200 OK):
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

## 4. Phase 3: Role-specific domain business engines

### 3A. Active trader domain (Personal trading preferences and discipline rules)
Frontend repository: [`TradingPrefsRepository`](file:///Users/nitishkumar/Downloads/Projects/nk2552003/TradeX/lib/features/settings/data/repositories/trading_prefs_repository.dart)  
Scope: Personal risk boundaries, execution checklists, and watchlists for individual traders.

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
Accepts partial updates to personal position sizing percentage, R:R multiples, checklist items, and watchlists.

---

### 3B. Affiliate partner domain (Referrals, RevShare, and payouts)
Frontend repository: [`AffiliateSettingsRepository`](file:///Users/nitishkumar/Downloads/Projects/nk2552003/TradeX/lib/features/settings/data/repositories/affiliate_settings_repository.dart)  
Scope: Referral link tracking, 30% lifetime revenue share, and payout destinations for partners and creators.

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
Updates custom referral slugs (`tradex.ai/r/:slug`), payout methods (`upi`, `bank_neft`, `razorpay`), and payment thresholds.

#### `POST /affiliate/payout/request`
Submits a withdrawal request when `pending_payout` meets or exceeds `minimum_payout_threshold`.

---

### 3C. Desk administrator domain (Firm risk limits, circuit breakers, and team seats)
Frontend repositories: [`DeskRiskRepository`](file:///Users/nitishkumar/Downloads/Projects/nk2552003/TradeX/lib/features/settings/data/repositories/desk_risk_repository.dart) and [`OrganizationSettingsRepository`](file:///Users/nitishkumar/Downloads/Projects/nk2552003/TradeX/lib/features/settings/data/repositories/organization_settings_repository.dart)  
Scope: Institutional desk governance configured by administrators and applied across all desk traders.

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

## 5. Phase 4: Subscriptions, monetization, and invoicing

Frontend repository: [`BillingSettingsRepository`](file:///Users/nitishkumar/Downloads/Projects/nk2552003/TradeX/lib/features/settings/data/repositories/billing_settings_repository.dart)  
Scope: Applicable to paying customers (active traders). Affiliate partners receive payouts through affiliate endpoints, and desk administrators manage desk capacity via workspace endpoints.

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

## 6. Phase 5: Alerts, privacy, and GDPR data export

### 6.1 Notifications preferences
Endpoint: `GET/PATCH /users/notifications`
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

### 6.2 Privacy and GDPR data export
Endpoint: `GET /users/data-export`
Generates a zip archive containing:
- `profile.json` (account metadata)
- `trades.csv` (all logged trade records)
- `risk_logs.json` (discipline metrics and checklist responses)

---

## 7. Repository swapping guide: How to wire real APIs

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

Inject the implementation into `BillingSettingsPage(repository: HttpBillingSettingsRepositoryImpl(...))` or register it in your dependency container.

---

## 8. Complete verification status

All pages and models validate cleanly against the compiler:

```bash
# Static analysis verification
dart analyze --fatal-warnings lib/
# Result: Analyzing lib... No issues found! (0 errors, 0 warnings, 0 todos)

# Unit & integration tests
flutter test
# Result: All tests passed
```
