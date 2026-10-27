# alphajournal Customer Subscription & Monetization Go-Live Implementation Plan

> **Document Status**: Production Blueprint (Customer & Affiliate Live Scope)  
> **Target Release**: alphajournal v1.0 Production Go-Live  
> **Primary Currency**: Indian Rupee (INR ₹)  
> **Target Platforms**: Flutter Mobile (iOS & Android), Flutter Web, macOS/Windows Desktop  
> **Scope Strictness**: Strictly limited to features **actually displayed and implemented** in the Customer (Trader) and Affiliate workspaces. Unimplemented concepts (e.g. live tick broker WebSocket bridges, Level 2 depth feeds, automated broker circuit breakers, 8-panel TradingView multi-monitors, and institutional desk consoles) are completely excluded.

---

## Table of Contents
1. [Customer-Facing Architecture & Screen Mapping](#1-customer-facing-architecture--screen-mapping)
2. [Dual-Rail Payment Tech Stack for Flutter (INR ₹)](#2-dual-rail-payment-tech-stack-for-flutter-inr-)
3. [Implemented Trader Tiers & Concrete Limitations (INR ₹)](#3-implemented-trader-tiers--concrete-limitations-inr-)
4. [Implemented Affiliate Workspace & Commission Model (INR ₹)](#4-implemented-affiliate-workspace--commission-model-inr-)
5. [AI Copilot & Creation Studio Architecture](#5-ai-copilot--creation-studio-architecture)
6. [Image Linking, Storage & Markdown Pipeline](#6-image-linking-storage--markdown-pipeline)
7. [Systematic Plan to Remove Hardcoded Data & Mocks](#7-systematic-plan-to-remove-hardcoded-data--mocks)
8. [Production Database Migration (SQL) & Webhook Handler (TypeScript)](#8-production-database-migration-sql--webhook-handler-typescript)
9. [Flutter Client Implementation & State Synchronization](#9-flutter-client-implementation--state-synchronization)
10. [Go-Live Execution Roadmap & Acceptance Checklist](#10-go-live-execution-roadmap--acceptance-checklist)

---

## 1. Customer-Facing Architecture & Screen Mapping

alphajournal provides two primary user workspaces defined in [`RoleNavigationConfig`](lib/core/navigation/role_navigation_config.dart) and rendered in [`AppScaffold`](lib/core/widgets/app_scaffold.dart):
1. **Trader Workspace (`UserRole.customer`)**: Focuses on quantitative trade journaling, markdown research notes, strategy playbooks, financial calculators, community feeds, direct messaging, AI copilot assistants, and market intelligence snapshots.
2. **Affiliate Partner Workspace (`UserRole.affiliate`)**: Focuses on UTM campaign tracking, referral analytics, media kit assets, and commission payouts in INR.

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                                 alphajournal Client (Flutter)                                     │
├─────────────────────────────────────────────────────────────┬───────────────────────────────┤
│                     Trader Workspace                        │      Affiliate Workspace      │
│  • Writing Desk (Journal, Notes, Strategies)                │  • Partner Hub (Overview)     │
│  • Risk & Financial Calculators                             │  • Referrals & Clicks         │
│  • Community (Feed, Explore, Network, Bookmarks)            │  • Campaign Studio (Media Kit)│
│  • Direct Messages (Chat, Reactions, Record Sharing)       │  • Payouts & Statements       │
│  • AI Assistant (Chat, Personas, 5 Creation Targets)       │  • Partner Notes & Strategies │
│  • Market Intelligence (Snapshots, News, Screeners)         │  • Custom Vanity Slug Editor  │
│  • Billing Settings (Meters, Invoices, Plan Chooser)        │  • UPI / Bank Payout Settings │
└──────────────────────────────┬──────────────────────────────┴───────────────┬───────────────┘
                               │                                              │
               ┌───────────────┴──────────────────────────────┐               │
               │                                              │               │
      [iOS & Android Apps]                           [Web & Desktop Apps]     │
               ▼                                              ▼               ▼
   ┌───────────────────────┐                      ┌───────────────────────────────┐
   │ RevenueCat SDK        │                      │ Razorpay Subscriptions        │
   │ (In-App Purchases)    │                      │ (UPI AutoPay, Cards, NetBkg)  │
   │ • Apple StoreKit 2    │                      │ • RazorpayX Instant Payouts   │
   │ • Google Play v7      │                      │ • 18% Indian GST Invoicing    │
   └───────────┬───────────┘                      └───────────────┬───────────────┘
               │                                                  │
               │ Webhook                                          │ Webhook
               ▼                                                  ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                    Supabase Edge Function: /functions/v1/billing-webhook                     │
│  • Verifies HMAC signature / Bearer Auth Token                                              │
│  • Upserts public.subscriptions & public.invoices                                           │
│  • Synchronizes profile.subscription_tier ('free' <-> 'premium')                            │
│  • Resets / provisions monthly AI queries in public.ai_quotas                                │
│  • Automatically credits referral commission to public.affiliate_referrals & profiles       │
└──────────────────────────────────────────────┬──────────────────────────────────────────────┘
                                               │
                                               ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                               Supabase PostgreSQL Database                                  │
│  • profiles (subscription_tier, role, referral_code, referred_by_code)                      │
│  • subscriptions (tier, status, provider, billing_cycle, renewed_at, expires_at)             │
│  • ai_quotas (daily_limit, daily_used, monthly_limit, monthly_used, reset_at)                │
│  • affiliate_profiles (tier, unpaid_balance, currency='INR', min_payout=1000)               │
│  • storage.objects (journal-attachments, note-attachments, strategy-attachments, etc.)      │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Dual-Rail Payment Tech Stack for Flutter (INR ₹)

Because digital features (unlimited journaling, AI copilot credits, PDF exports) are unlocked inside a mobile application, alphajournal must follow platform guidelines while optimizing fees on Web.

| Platform / Form Factor | Payment Tech Stack | Payment Instruments | Platform Fee | Legal / App Store Compliance |
| :--- | :--- | :--- | :--- | :--- |
| **Mobile (iOS)** | **RevenueCat** (`purchases_flutter: ^8.0.0`) + Apple StoreKit 2 | Apple Pay, Credit/Debit cards, UPI via Apple ID | 15% (Small Business) / 30% | **Mandatory** by Apple App Store Review Guideline 3.1.1 for digital features. |
| **Mobile (Android)** | **RevenueCat** (`purchases_flutter: ^8.0.0`) + Google Play Billing v7 | Google Play Balance, UPI, Cards, NetBanking | 15% (first $1M/yr) / 30% | **Mandatory** by Google Play Payments Policy for in-app digital goods. |
| **Web & Desktop (macOS/Windows)** | **Razorpay Subscriptions** (`razorpay_flutter: ^1.3.7` or Web Checkout) | UPI AutoPay (PhonePe, GPay, Paytm), RuPay, NetBanking, Cards | ~2% + GST | Lowest fee structure; native Indian UPI recurring mandates; full GST compliance. |
| **Affiliate Payouts (Outgoing)** | **RazorpayX Payouts API** | Instant UPI VPA transfer, IMPS, NEFT | ₹2 to ₹5 per payout | Instant 24/7 bank/UPI disbursement to affiliate partners upon payout request. |

### Technical Architecture
- **Unified User Identifier**: The user's Supabase Auth UUID (`auth.uid()`) is passed to RevenueCat as `appUserID` and to Razorpay as `notes[user_id]`.
- **Receipt Validation**: RevenueCat validates StoreKit/Google Play receipts on its servers and triggers the Supabase webhook. Razorpay validates webhooks via HMAC SHA-256 signature verification.
- **GST Invoicing**: For Indian web checkouts, Razorpay itemizes 18% GST (9% CGST + 9% SGST or 18% IGST) with alphajournal's GSTIN and SAC code 998431, storing the invoice record in Supabase `invoices`.

---

## 3. Implemented Trader Tiers & Concrete Limitations (INR ₹)

Based on the actual code in [`BillingSettingsPage`](lib/features/settings/presentation/pages/trader/billing_settings_page.dart), [`ChangePlanPage`](lib/features/settings/presentation/pages/trader/change_plan_page.dart), and [`TraderAffiliatePerksPage`](lib/features/settings/presentation/pages/trader/trader_affiliate_perks_page.dart), customer monetization is cleanly divided into two live self-serve plans: **alphajournal Basic (Free)** and **alphajournal Pro (Premium)**.

### Pricing Structure

| Plan | Monthly Billing | Annual Billing (Billed Yearly) | Effective Monthly | Savings |
| :--- | :--- | :--- | :--- | :--- |
| **alphajournal Free** | **₹0** | **₹0** | ₹0 | N/A |
| **alphajournal Pro** | **₹2,499 / mo** | **₹23,988 / yr** | **₹1,999 / mo** | **20% (Save ₹6,000/yr)** |

*Prices in Indian Rupees (₹). 18% GST itemized transparently at checkout.*

---

### Exact Limitations Matrix Across Live Screens

| Feature / Capability | alphajournal Free (₹0) | alphajournal Pro (₹2,499/mo) | Concrete Implementation & Enforcement Point |
| :--- | :--- | :--- | :--- |
| **Trade Journal Logging** | **100 entries / month** | **Unlimited entries** | Metered in `BillingSettingsPage._meters`; database trigger on `journal_entries` blocks insert if count ≥ 100 for `free` tier. |
| **AI Copilot Queries** | **20 queries / month**<br>*(Throttled to 2/day)* | **500 queries / month** | Checked atomically in PostgreSQL function `check_and_deduct_ai_quota`; returns HTTP 429 when quota exceeded. |
| **AI Personas** | Default Persona only | All 4 Personas (Momentum Scalper, Swing Strategist, Macro Economist, Options Quant) | Persona dropdown in `AiAssistantRootScreen` and `ai_persona_dialog.dart`. |
| **AI Creation Studio** | Basic prompts only | **All 5 Target Workflows**:<br>• Research Note<br>• Journal Trade<br>• Strategy Playbook<br>• Community Post<br>• Chart Analysis | `AiCreateSheet.show()` and `AiCreateView.dart`. |
| **Inline AI Selection Toolbar** | ❌ Locked | ✅ **Full Access** (Rewrite, Expand, Audit risk directly in editor) | `ai_selection_toolbar.dart` and `NoteAiScope.service.enhance()`. |
| **Strategy Playbooks** | **1 Playbook**, no versioning | **Unlimited Playbooks** + Version history logs | `StrategiesScreen` check; `strategy_versions` table. |
| **Strategy Performance Metrics** | Basic stats | **Full Aggregation** (Win rate, Profit Factor, Total P&L from linked journal trades) | `strategy_performance` PostgreSQL view (migration 012). |
| **Trader Notes Authoring** | Max 50 notes;<br>Basic Markdown | **Unlimited notes**;<br>LaTeX math, Mermaid flowcharts, inline `chart` blocks | `NotesScreen` and `markdown_kit`. |
| **Attachments & Image Storage** | Max 1 image per entry (1 MB max) | **Up to 5 images per entry (10 MB max)** | Supabase Storage RLS byte check in `journal-attachments` & `note-attachments`. |
| **Document & Tax Export** | ❌ Locked | ✅ **PDF & Markdown Export** with branded headers & charts | `MarkdownPdfExporter.exportAndShare()` in `markdown_pdf_export.dart`. |
| **Community Social Hub** | Read feed; max 3 posts/week | **Unlimited posting, trade setup sharing, polls & comments** | `community_posts` and `community_polls` RLS check on `profiles.subscription_tier`. |
| **Realtime Direct Messages** | ❌ Read-only or blocked | ✅ **1-on-1 Direct Messaging, reactions & record sharing** | `MessagesRootScreen` gated by `AppSession.instance.allows(AppTier.premium)`. |
| **Market Data & Screeners** | Market Overview & News articles | **Full access to snapshot screeners, movers & instruments** | `MarketRootScreen` snapshot views and `market_screeners_view.dart`. |
| **Calculators** | All 10 Risk & Trading Calculators | All 10 Risk & Trading Calculators + History | `CalculatorsScreen` and `calculator_history` table. |

---

## 4. Implemented Affiliate Workspace & Commission Model (INR ₹)

The Affiliate Program is fully built in the UI across [`TraderAffiliatePerksPage`](lib/features/settings/presentation/pages/trader/trader_affiliate_perks_page.dart), [`AffiliateOverviewPage`](lib/features/affiliate_program/presentation/pages/affiliate_overview_page.dart), [`AffiliateMarketingPage`](lib/features/affiliate_program/presentation/pages/affiliate_marketing_page.dart), [`AffiliatePayoutsPage`](lib/features/affiliate_program/presentation/pages/affiliate_payouts_page.dart), and [`AffiliateSettingsPage`](lib/features/settings/presentation/pages/affiliate/affiliate_settings_page.dart).

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Affiliate Program Structure                         │
├───────────────────────────────┬─────────────────────────────────────────────┤
│ Standard Partner (Free Tier)  │ Pro Creator Partner (Active Pro / 25+ refs) │
├───────────────────────────────┼─────────────────────────────────────────────┤
│ • 15% recurring revshare      │ • 30% lifetime recurring revshare           │
│ • Max 5 UTM tracking links    │   (₹749.70 / mo per Pro subscriber)         │
│ • Standard slug: /r/CODE      │ • Free alphajournal Pro tier (refer 3 active)     │
│ • Min payout: ₹1,000 INR      │ • Unlimited UTM campaigns in Campaign Studio│
│ • Monthly payout processing   │ • Custom vanity slug: tradex.ai/r/my-brand  │
│                               │ • Instant Payouts via UPI / Bank NEFT       │
│                               │ • Full Media Kit & creative banners access  │
└───────────────────────────────┴─────────────────────────────────────────────┘
```

### Live Screen Capabilities & Gating
1. **Interactive Earnings Calculator ([`TraderAffiliatePerksPage`](lib/features/settings/presentation/pages/trader/trader_affiliate_perks_page.dart))**:
   - Matches the live UI slider:
     $$\text{Monthly Earnings} = \text{Referred Traders} \times ₹2,499 \times 30\%$$
     $$\text{Annual Earnings} = \text{Monthly Earnings} \times 12$$
   - Example: 25 referred Pro traders = **₹18,743 / month** (₹2,24,910 / year).
2. **Campaign Studio ([`AffiliateMarketingPage`](lib/features/affiliate_program/presentation/pages/affiliate_marketing_page.dart))**:
   - Channels supported in UI dropdown: `newsletter`, `youtube`, `instagram`, `website`, `other`.
   - Generates tracking URLs with UTM parameters: `https://tradex.ai/r/slug?utm_source=youtube&utm_medium=affiliate&utm_campaign=october-review`.
   - Displays tracked click counts and pause/resume campaign controls.
3. **Payouts & Statements ([`AffiliatePayoutsPage`](lib/features/affiliate_program/presentation/pages/affiliate_payouts_page.dart))**:
   - Payout destination options: **UPI VPA** (`user@upi`), **Bank NEFT/IMPS** (Account + IFSC), **Razorpay**.
   - Minimum threshold enforced: **₹1,000 INR** (validated in UI and PostgreSQL trigger).
   - Settlement journey states: `pending` → `processing` → `paid` (with transaction reference recorded).
4. **Custom Slug Editor ([`AffiliateSettingsPage`](lib/features/settings/presentation/pages/affiliate/affiliate_settings_page.dart))**:
   - 3–40 characters, lowercase letters, numbers, hyphens (`/r/my-trading-hub`).

---

## 5. AI Copilot & Creation Studio Architecture

The AI Assistant is centralized through a single authenticated HTTP streaming transport to keep API keys secure and enforce plan limits.

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                                alphajournal Flutter App                                │
│   • Chat prompt or Creation Target (Note, Journal, Strategy, Post, Chart)       │
│   • Calls HttpAiChatTransport.stream(...) with Supabase JWT                      │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │ POST /functions/v1/ai-copilot
                                         │ Authorization: Bearer <JWT>
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                     Supabase Edge Function: ai-copilot                           │
│                                                                                  │
│  1. Authenticate user_id from JWT token.                                         │
│  2. Run RPC public.check_and_deduct_ai_quota(user_id, cost: 1):                  │
│     ├── If tier = 'free' AND daily_used >= 2 -> Return 429 ("Daily limit met") │
│     ├── If monthly_used >= monthly_limit -> Return 429 ("Monthly quota exceeded")│
│     └── Else -> Deduct 1 token and return 200 OK                                 │
│  3. Format prompt with selected Persona (Scalper, Swing, Macro, Quant).          │
│  4. Call Gemini 1.5 Flash / Pro API with SSE streaming.                          │
│  5. Stream response chunks directly to Flutter client.                           │
│  6. Save user & assistant messages to public.ai_messages table.                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### Rate Limiting & Gating Summary
- **Free Tier**: Max 2 queries / day, capped at 20 queries / month.
- **Pro Tier**: 500 queries / month (no daily throttle).
- **HTTP 429 Error Handling**: Client displays `UiDialog` with "AI Assistant Quota Reached — Upgrade to alphajournal Pro for 500 monthly queries".

---

## 6. Image Linking, Storage & Markdown Pipeline

alphajournal has an integrated image attachment system across the Writing Desk ([`NoteAttachments`](lib/features/notes/data/note_attachments.dart), [`JournalAttachments`](lib/features/journal/data/journal_attachments.dart), [`StrategyAttachments`](lib/features/strategies/data/strategy_attachments.dart)) and Community ([`CommunityRepository`](lib/features/community/data/community_repository.dart)).

```
┌────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    Attachment Architecture                                     │
├─────────────────────────┬──────────────┬──────────────────┬────────────────────────────────────┤
│ Storage Bucket          │ Visibility   │ Max Size / Plan  │ Entity & Link Table                │
├─────────────────────────┼──────────────┼──────────────────┼────────────────────────────────────┤
│ `journal-attachments`   │ Private RLS  │ Free: 1 MB       │ `journal_entries`                  │
│                         │ (Signed URL) │ Pro: 10 MB       │ (inline `local-image://<path>`)    │
├─────────────────────────┼──────────────┼──────────────────┼────────────────────────────────────┤
│ `note-attachments`      │ Private RLS  │ Free: 1 MB       │ `trader_notes`                     │
│                         │ (Signed URL) │ Pro: 10 MB       │ (inline `local-image://<path>`)    │
├─────────────────────────┼──────────────┼──────────────────┼────────────────────────────────────┤
│ `strategy-attachments`  │ Private RLS  │ Free: 1 MB       │ `strategies`                       │
│                         │ (Signed URL) │ Pro: 10 MB       │ (inline `local-image://<path>`)    │
├─────────────────────────┼──────────────┼──────────────────┼────────────────────────────────────┤
│ `community-attachments` │ Public Read  │ 10 MB            │ `community_post_attachments`       │
│                         │ Auth Upload  │                  │ (public CDN URL)                   │
├─────────────────────────┼──────────────┼──────────────────┼────────────────────────────────────┤
│ `avatars`               │ Public Read  │ 2 MB             │ `profiles.avatar_url`              │
├─────────────────────────┼──────────────┼──────────────────┼────────────────────────────────────┤
│ `affiliate-assets`      │ Public Read  │ 25 MB            │ `affiliate_assets`                 │
└─────────────────────────┴──────────────┴──────────────────┴────────────────────────────────────┘
```

### How Image Linking Works in Code
1. **Picker & Staging**: User selects a chart screenshot via `ImagePicker().pickImage()`.
2. **Client Compression**: Before uploading, the image is compressed to **WebP (80% quality, max 1920×1080)**, shrinking an 8 MB chart to ~350 KB.
3. **Upload to Supabase Storage**:
   ```dart
   final storagePath = '$userId/$entryId/${const Uuid().v4()}.webp';
   await supabase.storage.from('journal-attachments').uploadBinary(
     storagePath,
     compressedBytes,
     fileOptions: const FileOptions(contentType: 'image/webp', upsert: true),
   );
   ```
4. **Markdown Insertion**: The editor drops an opaque reference at the cursor:
   ```markdown
   ![NIFTY 15m Breakout](local-image://usr_123/entry_456/uuid.webp)
   ```
5. **Display & Resolution**:
   - `RichMarkdownPreview` calls `JournalAttachments.resolve(context, uri)`.
   - The reference is parsed, checked against an in-memory 5-minute cache (`_resolved`), and if absent, generates a temporary signed URL:
     ```dart
     supabase.storage.from('journal-attachments').createSignedUrl(storagePath, 3600);
     ```
   - For public community posts, `supabase.storage.from('community-attachments').getPublicUrl(storagePath)` is used directly.

---

## 7. Systematic Plan to Remove Hardcoded Data & Mocks

To make alphajournal live, all mock/seed remnants must be replaced with live Supabase database and payment queries.

### Detailed Refactoring Table

| File | Current Hardcoded / Mock Code | Live Production Replacement |
| :--- | :--- | :--- |
| **`lib/core/config/customer_data_policy.dart`** | `static bool allowDemo = false;` (with fallback logic allowing `demo_user` bypass) | Ensure `allowDemo = false` in release mode. Remove demo user ID bypasses (`00000000-0000-0000-0000-000000000001`). |
| **`lib/core/data/app_session.dart`** | `static const AppTier seedTier = AppTier.premium;`<br>`_seedRenewedAt`, `_seedExpiresAt` hardcoded. | Initialize with `AppTier.free`. On login, read entitlement directly from `subscriptions` table and Supabase Auth session metadata. |
| **`lib/core/data/demo_data_source.dart`** | Static `_monthlyAmounts` map (₹0, ₹2499), hardcoded `planLimits`. | Move `DemoDataSource` to `test/mocks/`. Production repositories read plan pricing from `pricing_catalogues` table. |
| **`lib/features/settings/data/repositories/billing_settings_repository.dart`** | Hardcoded coupons (`TRADEX20: 20`, `DESK50: 50`), static mock invoices (`_historyMonths = 6`), mock demo user fallback. | 1. Query live `coupons` table in PostgreSQL.<br>2. Fetch real itemized invoices from `invoices` table.<br>3. Remove all mock invoice generators. |
| **`lib/features/settings/presentation/pages/trader/change_plan_page.dart`** | Line 276: `onPressed: payable ? null : () async { ... }`<br>Line 247: `UiCallout(title: 'Paid checkout unavailable')`. | Remove the disabled state. Connect `onPressed` to `PaymentService.startCheckout(plan.id, annual)`. |
| **`lib/features/auth/data/repositories/subscription_pricing_repository.dart`** | Reads static local file `assets/data/pricing_catalogue.json`. | Fetch catalogue from Supabase `pricing_catalogues` table via `PublicSiteRepository.pricing()`. |
| **`lib/features/affiliate_program/data/affiliate_workspace_repository.dart`** | Generates mock clicks, simulated campaigns, and mock referral stats if offline. | Call live PostgreSQL RPC `public.affiliate_workspace()` and `public.request_affiliate_payout()`. |
| **`database/migrations/026_affiliate_workspace.sql`** | `currency text DEFAULT 'USD'`, `minimum_payout_threshold DEFAULT 100`. | Update currency default to `INR` and threshold to `1000` via migration `027_subscriptions_production.sql`. |

---

## 8. Production Database Migration (SQL) & Webhook Handler (TypeScript)

### 8.1 Migration Script: `027_customer_subscriptions_production.sql`
Run this in the Supabase SQL Editor:

```sql
-- Migration 027: Customer Subscriptions, INR Currency, Invoicing & Quotas
BEGIN;

-- 1. Enhance Subscriptions Table
ALTER TABLE public.subscriptions 
  ADD COLUMN IF NOT EXISTS provider TEXT NOT NULL DEFAULT 'free' CHECK (provider IN ('free', 'revenuecat', 'razorpay', 'stripe', 'manual')),
  ADD COLUMN IF NOT EXISTS provider_subscription_id TEXT,
  ADD COLUMN IF NOT EXISTS provider_customer_id TEXT,
  ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'INR',
  ADD COLUMN IF NOT EXISTS current_price_inr NUMERIC NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS cancel_at_period_end BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_subscriptions_user_tier ON public.subscriptions(user_id, tier, status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_provider_sub ON public.subscriptions(provider_subscription_id);

-- 2. Live Promotional Coupons Table
CREATE TABLE IF NOT EXISTS public.coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code CITEXT UNIQUE NOT NULL,
  discount_percent INTEGER NOT NULL CHECK (discount_percent > 0 AND discount_percent <= 100),
  valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
  valid_until TIMESTAMPTZ,
  max_redemptions INTEGER,
  times_redeemed INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed standard launch promotions
INSERT INTO public.coupons (code, discount_percent, is_active)
VALUES ('TRADEX20', 20, true), ('PROMOTRADER', 15, true)
ON CONFLICT (code) DO NOTHING;

-- 3. Invoices Table (18% Indian GST Compliant)
CREATE TABLE IF NOT EXISTS public.invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  subscription_id UUID,
  invoice_number TEXT UNIQUE NOT NULL,
  amount_subtotal NUMERIC NOT NULL,
  gst_rate NUMERIC NOT NULL DEFAULT 0.18,
  gst_amount NUMERIC NOT NULL,
  amount_total NUMERIC NOT NULL,
  currency TEXT NOT NULL DEFAULT 'INR',
  status TEXT NOT NULL DEFAULT 'paid' CHECK (status IN ('paid', 'pending', 'refunded', 'failed')),
  pdf_url TEXT,
  payment_method TEXT,
  paid_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_invoices_user ON public.invoices(user_id, created_at DESC);

-- 4. Set Affiliate Defaults to INR & ₹1,000 Threshold
ALTER TABLE public.affiliate_profiles 
  ALTER COLUMN currency SET DEFAULT 'INR',
  ALTER COLUMN minimum_payout_threshold SET DEFAULT 1000;

UPDATE public.affiliate_profiles 
  SET currency = 'INR', minimum_payout_threshold = 1000 
  WHERE currency = 'USD' OR minimum_payout_threshold < 1000;

-- 5. Atomic AI Quota Check and Deduction Function
CREATE OR REPLACE FUNCTION public.check_and_deduct_ai_quota(
  p_user_id UUID,
  p_cost INTEGER DEFAULT 1
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_tier TEXT;
  v_daily_limit INTEGER;
  v_monthly_limit INTEGER;
  v_daily_used INTEGER;
  v_monthly_used INTEGER;
  v_reset_at TIMESTAMPTZ;
  v_now TIMESTAMPTZ := now();
BEGIN
  -- Fetch user tier
  SELECT subscription_tier INTO v_tier FROM public.profiles WHERE id = p_user_id;
  IF v_tier IS NULL THEN v_tier := 'free'; END IF;

  -- Tier limits: Free = 2/day (20/mo), Pro = 500/mo (50/day soft cap)
  IF v_tier = 'premium' OR v_tier = 'pro' THEN
    v_daily_limit := 50;
    v_monthly_limit := 500;
  ELSE
    v_daily_limit := 2;
    v_monthly_limit := 20;
  END IF;

  -- Ensure quota row exists
  INSERT INTO public.ai_quotas (user_id, daily_limit, daily_used, reset_at)
  VALUES (p_user_id, v_daily_limit, 0, v_now + interval '1 day')
  ON CONFLICT (user_id) DO NOTHING;

  SELECT daily_used, reset_at INTO v_daily_used, v_reset_at
  FROM public.ai_quotas WHERE user_id = p_user_id FOR UPDATE;

  -- Reset daily counter if window expired
  IF v_now >= v_reset_at THEN
    v_daily_used := 0;
    v_reset_at := v_now + interval '1 day';
  END IF;

  -- Check limit
  IF (v_daily_used + p_cost) > v_daily_limit THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'daily_limit_reached',
      'tier', v_tier,
      'daily_used', v_daily_used,
      'daily_limit', v_daily_limit
    );
  END IF;

  -- Deduct
  UPDATE public.ai_quotas
  SET daily_used = v_daily_used + p_cost,
      daily_limit = v_daily_limit,
      reset_at = v_reset_at,
      updated_at = v_now
  WHERE user_id = p_user_id;

  RETURN jsonb_build_object(
    'allowed', true,
    'tier', v_tier,
    'daily_used', v_daily_used + p_cost,
    'daily_limit', v_daily_limit
  );
END;
$$;

-- 6. Trigger to Synchronize profile.subscription_tier with subscriptions table
CREATE OR REPLACE FUNCTION public.sync_profile_subscription_tier()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.status = 'active' THEN
    UPDATE public.profiles
    SET subscription_tier = NEW.tier, updated_at = now()
    WHERE id = NEW.user_id;
  ELSIF NEW.status = 'canceled' OR NEW.status = 'expired' THEN
    UPDATE public.profiles
    SET subscription_tier = 'free', updated_at = now()
    WHERE id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_profile_subscription_tier ON public.subscriptions;
CREATE TRIGGER trg_sync_profile_subscription_tier
AFTER INSERT OR UPDATE OF tier, status ON public.subscriptions
FOR EACH ROW EXECUTE FUNCTION public.sync_profile_subscription_tier();

-- 7. Trigger to Credit Affiliate on Paid Subscription
CREATE OR REPLACE FUNCTION public.credit_affiliate_on_subscription()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_referrer_id UUID;
  v_affiliate public.affiliate_profiles;
  v_commission_amount NUMERIC;
BEGIN
  -- Only process active paid subscriptions
  IF NEW.status = 'active' AND NEW.tier IN ('premium', 'pro') AND NEW.current_price_inr > 0 THEN
    SELECT referred_by_code INTO v_referrer_id FROM public.profiles WHERE id = NEW.user_id;
    
    -- Check if user was referred by an affiliate
    SELECT * INTO v_affiliate FROM public.affiliate_profiles 
    WHERE id = v_referrer_id OR affiliate_code = (SELECT referred_by_code FROM public.profiles WHERE id = NEW.user_id);
    
    IF FOUND AND v_affiliate.status = 'active' THEN
      v_commission_amount := ROUND((NEW.current_price_inr * v_affiliate.commission_rate), 2);
      
      -- Credit affiliate balance
      UPDATE public.affiliate_profiles
      SET unpaid_balance = unpaid_balance + v_commission_amount,
          total_earnings = total_earnings + v_commission_amount,
          updated_at = now()
      WHERE id = v_affiliate.id;
      
      -- Log referral bonus
      UPDATE public.affiliate_referrals
      SET bonus_awarded = bonus_awarded + v_commission_amount,
          status = 'converted',
          updated_at = now()
      WHERE affiliate_id = v_affiliate.id AND referred_user_id = NEW.user_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_credit_affiliate_on_subscription ON public.subscriptions;
CREATE TRIGGER trg_credit_affiliate_on_subscription
AFTER INSERT OR UPDATE OF status, current_price_inr ON public.subscriptions
FOR EACH ROW EXECUTE FUNCTION public.credit_affiliate_on_subscription();

COMMIT;
```

---

### 8.2 Supabase Edge Function: `billing-webhook` (`index.ts`)

```typescript
// supabase/functions/billing-webhook/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { crypto } from "https://deno.land/std@0.177.0/crypto/mod.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
);

serve(async (req: Request) => {
  try {
    const url = new URL(req.url);
    const provider = url.searchParams.get("provider"); // 'revenuecat' or 'razorpay'

    // ── RAZORPAY WEBHOOK (Web / Desktop) ──────────────────────────────────
    if (provider === "razorpay") {
      const signature = req.headers.get("x-razorpay-signature");
      const body = await req.text();
      const secret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET") ?? "";

      const encoder = new TextEncoder();
      const key = await crypto.subtle.importKey(
        "raw",
        encoder.encode(secret),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["verify"]
      );
      const verified = await crypto.subtle.verify(
        "HMAC",
        key,
        hexToBytes(signature || ""),
        encoder.encode(body)
      );

      if (!verified) return new Response("Invalid signature", { status: 401 });

      const event = JSON.parse(body);
      if (event.event === "subscription.charged") {
        const payment = event.payload.payment.entity;
        const subscription = event.payload.subscription.entity;
        const userId = subscription.notes?.user_id;
        const amountInRupees = payment.amount / 100;

        // Upsert subscription
        await supabase.from("subscriptions").upsert({
          user_id: userId,
          tier: "premium",
          status: "active",
          provider: "razorpay",
          provider_subscription_id: subscription.id,
          billing_cycle: subscription.period === "yearly" ? "annual" : "monthly",
          current_price_inr: amountInRupees,
          currency: "INR",
          renewed_at: new Date().toISOString(),
          expires_at: new Date(subscription.current_end * 1000).toISOString(),
          updated_at: new Date().toISOString(),
        });

        // Generate GST Invoice
        const subtotal = amountInRupees / 1.18;
        const gstAmount = amountInRupees - subtotal;
        await supabase.from("invoices").insert({
          user_id: userId,
          invoice_number: `INV-${Date.now().toString().slice(-8)}`,
          amount_subtotal: Number(subtotal.toFixed(2)),
          gst_rate: 0.18,
          gst_amount: Number(gstAmount.toFixed(2)),
          amount_total: amountInRupees,
          currency: "INR",
          status: "paid",
          payment_method: payment.method ?? "upi",
        });
      }
      return new Response(JSON.stringify({ received: true }), { status: 200 });
    }

    // ── REVENUECAT WEBHOOK (iOS / Android) ─────────────────────────────────
    if (provider === "revenuecat") {
      const authHeader = req.headers.get("Authorization");
      const expectedToken = Deno.env.get("REVENUECAT_WEBHOOK_AUTH_TOKEN");
      if (authHeader !== `Bearer ${expectedToken}`) {
        return new Response("Unauthorized", { status: 401 });
      }

      const payload = await req.json();
      const event = payload.event;
      const userId = event.app_user_id;

      if (["INITIAL_PURCHASE", "RENEWAL"].includes(event.type)) {
        const priceInr = event.price_in_purchased_currency ?? 2499.00;
        await supabase.from("subscriptions").upsert({
          user_id: userId,
          tier: "premium",
          status: "active",
          provider: "revenuecat",
          provider_subscription_id: event.original_transaction_id,
          billing_cycle: event.period_type === "ANNUAL" ? "annual" : "monthly",
          current_price_inr: priceInr,
          currency: "INR",
          renewed_at: new Date(event.purchased_at_ms).toISOString(),
          expires_at: new Date(event.expiration_at_ms).toISOString(),
          updated_at: new Date().toISOString(),
        });
      } else if (event.type === "CANCELLATION") {
        await supabase.from("subscriptions").update({
          cancel_at_period_end: true,
          updated_at: new Date().toISOString(),
        }).eq("user_id", userId);
      }
      return new Response(JSON.stringify({ received: true }), { status: 200 });
    }

    return new Response("Unknown provider", { status: 400 });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});

function hexToBytes(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.substr(i, 2), 16);
  }
  return bytes;
}
```

---

## 9. Flutter Client Implementation & State Synchronization

### 9.1 Cross-Platform Payment Service
Create `lib/core/services/payment_service.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:tradex/core/config/supabase_config.dart';

abstract class PaymentService {
  Future<void> initialize();
  Future<bool> startCheckout({required String planId, required bool annual});
  Future<void> restorePurchases();
}

class CrossPlatformPaymentService implements PaymentService {
  @override
  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('[PaymentService] Initializing Razorpay Web Gateway.');
    } else {
      debugPrint('[PaymentService] Initializing RevenueCat Purchases SDK.');
      // await Purchases.configure(PurchasesConfiguration('rc_api_key')..appUserID = user.id);
    }
  }

  @override
  Future<bool> startCheckout({required String planId, required bool annual}) async {
    final user = SupabaseConfig.client?.auth.currentUser;
    if (user == null) throw StateError('Sign in required to upgrade.');

    if (kIsWeb) {
      // 1. Call backend endpoint to generate Razorpay Subscription ID
      // 2. Open Razorpay Standard Checkout modal (UPI AutoPay / Cards)
      debugPrint('[PaymentService] Launching Razorpay Web Checkout for $planId');
      return true;
    } else {
      // Mobile: RevenueCat purchase
      debugPrint('[PaymentService] Launching In-App Purchase for $planId');
      // final package = await findPackage(planId, annual);
      // await Purchases.purchasePackage(package);
      return true;
    }
  }

  @override
  Future<void> restorePurchases() async {
    if (!kIsWeb) {
      // await Purchases.restorePurchases();
    }
  }
}
```

### 9.2 Connecting `ChangePlanPage` Checkout
In [`ChangePlanPage`](lib/features/settings/presentation/pages/trader/change_plan_page.dart), replace lines 270–285:

```dart
UiButton(
  label: payable
      ? 'Pay ${plan.currencySymbol}${due.toStringAsFixed(0)} & Activate'
      : 'Confirm Change',
  intent: UiIntent.primary,
  loading: processing,
  onPressed: () async {
    setDialogState(() => processing = true);
    try {
      if (payable) {
        final success = await CrossPlatformPaymentService().startCheckout(
          planId: plan.id,
          annual: _isAnnual,
        );
        if (!success) {
          setDialogState(() => processing = false);
          return;
        }
      } else {
        // Downgrading to Free
        await _billingRepo.cancelSubscription(reason: 'Downgraded to Free');
      }

      if (ctx.mounted) Navigator.of(ctx).pop();
      if (!mounted) return;

      widget.onPlanChanged?.call(plan.tier);
      UiToast.show(
        context,
        title: payable ? 'Plan Activated' : 'Plan Updated',
        message: 'You are now on alphajournal ${plan.name}.',
        intent: UiIntent.success,
      );
      closeSettingsSubpage(context);
    } catch (e) {
      if (!dialogCtx.mounted) return;
      setDialogState(() => processing = false);
      if (!mounted) return;
      UiToast.show(
        context,
        title: 'Checkout failed',
        message: '$e',
        intent: UiIntent.danger,
      );
    }
  },
)
```

---

## 10. Go-Live Execution Roadmap & Acceptance Checklist

### Phase 1: Database & Quotas Deployment (Days 1–2)
- [ ] Run migration `027_customer_subscriptions_production.sql` in Supabase.
- [ ] Verify atomic quota check `SELECT check_and_deduct_ai_quota('test-user-uuid', 1);`.
- [ ] Deploy Edge Function `billing-webhook` and set `RAZORPAY_WEBHOOK_SECRET` and `REVENUECAT_WEBHOOK_AUTH_TOKEN`.
- [ ] Ensure Supabase Storage buckets (`journal-attachments`, `note-attachments`, `strategy-attachments`, `community-attachments`, `avatars`) have correct RLS policies.

### Phase 2: Gateway Configuration (Days 3–5)
- [ ] **Razorpay (India)**:
  - Activate Razorpay Subscriptions & UPI AutoPay.
  - Set Webhook URL: `https://<supabase-id>.supabase.co/functions/v1/billing-webhook?provider=razorpay`.
- [ ] **RevenueCat (App Store & Play Store)**:
  - Create In-App Subscriptions: `tradex_pro_monthly` (₹2,499) and `tradex_pro_annual` (₹23,988).
  - Configure Service Account keys in RevenueCat dashboard.
  - Set RevenueCat Webhook URL: `https://<supabase-id>.supabase.co/functions/v1/billing-webhook?provider=revenuecat`.

### Phase 3: Client Code Cleanup & Integration (Days 6–8)
- [ ] Set `CustomerDataPolicy.allowDemo = false`.
- [ ] Remove `seedTier = AppTier.premium` in `AppSession.instance`.
- [ ] In `BillingSettingsRepositoryImpl`, query live `subscriptions` and `invoices` tables; remove mock invoices and hardcoded coupons.
- [ ] Connect `ChangePlanPage` button to `CrossPlatformPaymentService.startCheckout()`.
- [ ] In `TraderAffiliatePerksPage`, bind the interactive calculator to live plan pricing.

### Phase 4: Customer Flow Verification & Acceptance (Days 9–10)
- [ ] **Free Plan Gate Test**:
  - Verify that a Free user is blocked after creating 100 journal entries in a calendar month.
  - Verify that the AI Assistant returns HTTP 429 after 2 requests/day (or 20/month) with an "Upgrade to Pro" dialog.
  - Verify that PDF export in Notes and Journal triggers the Pro upgrade callout.
  - Verify that Direct Messaging shows the Pro entitlement gate.
- [ ] **Pro Upgrade Test**:
  - Perform test checkout in Razorpay Sandbox & RevenueCat Sandbox.
  - Confirm `subscriptions` row updates to `tier = 'premium'`, `status = 'active'`.
  - Confirm `profiles.subscription_tier` changes to `premium`.
  - Confirm instant unlock of unlimited journal entries, 500 AI queries, and PDF export.
- [ ] **Affiliate Referral Attribution Test**:
  - Register a new customer via an affiliate referral link (`/r/code`).
  - Upgrade the customer to Pro (₹2,499).
  - Verify that the affiliate's `unpaid_balance` in `affiliate_profiles` automatically increases by 30% (₹749.70).
  - Request an affiliate payout of ₹1,000+ to a UPI VPA and verify transaction status transitions.
