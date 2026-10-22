# TradeX Customer-Side Audit & Developer Hand-off Registry

**Application Target:** TradeX (TraderHub) Multi-Platform Financial Terminal  
**Scope:** Customer-Facing Client Architecture, UI/UX Layout, Security, Cryptographic Posture, Deep Linking, Supabase Integration, RLS Policies, and Data Governance  
**Auditor:** Antigravity AI Senior Architecture & Security Team  
**Date:** 2026-10-21  

---

## 1. Developer Hand-off Directory Structure

The customer-side audit is formally segregated into two dedicated developer hand-off packages: **Frontend Developer Package (`frontend_issues/`)** and **Backend Developer Package (`backend_issues/`)**:

```
customer_side/
├── README.md                                  # Master index, system health dashboard & hand-off roadmap (this file)
│
├── 🎨 frontend_issues/                         # DEDICATED FRONTEND DEVELOPER PACKAGE
│   ├── README.md                              # Frontend overview, health dashboard & Master Catalog of 24 Dead Buttons
│   ├── layout_and_responsive.md               # Mobile/desktop overflows, double docks, keyboard insets & touch targets
│   ├── navigation_and_routes.md               # go_router declarative migration, web browser history & back button
│   └── features/                              # 15 Feature-Specific Frontend Hand-off Briefs
│       ├── auth.md                            # Google OAuth missing, OTP screens, landscape overflow, role dialog
│       ├── community.md                       # Double bottom bar, pull-to-refresh no-op, dead quote/report/mute
│       ├── journal.md                         # Mobile spreadsheet squishing, trade logging UX
│       ├── notes.md                           # Keyboard double-insets, slash palette overflow, AST hitching, LFI
│       ├── strategies.md                      # Split mode tablet squishing, dead header menu, public warning dialog
│       ├── market_data.md                     # Candlestick pan gesture vs OS back navigation, mover ticker wrap
│       ├── watchlists.md                      # Dead "Add Symbol" toast, dead ticker tap, live price hydration
│       ├── ai_assistant.md                    # Dead action buttons, simulated typing indicator, regex bot replacement
│       ├── calculators.md                     # 22 calculators UI, division by zero guards, Finance Act 2024 tax UI
│       ├── settings.md                        # Dead CVC input, fake email OTP, fake account deletion, copy link bug
│       ├── workspace.md                       # Desktop carousel card overlap, search/filter state retention
│       ├── affiliate_program.md               # SMS verify fake instant success, mobile referral copy clipboard bug
│       ├── public_site.md                     # Criminal AES-256 claims in footer, dead social icons, currency wrap
│       ├── linking.md                         # Stale ticker universe in picker, graph rebuild main isolate lag
│       └── messages.md                        # Mobile message composer safe area, false E2EE banner removal
│
└── 🛠️ backend_issues/                          # DEDICATED BACKEND DEVELOPER PACKAGE
    ├── README.md                              # Backend overview, health dashboard & P0/P1 Critical Security Matrix
    ├── rls_and_security.md                    # PostgreSQL RLS policies, privilege escalation, role protection & KYC leaks
    ├── storage_architecture.md                # Storage folder conventions, 100% 403 upload fixes, signed URLs, avatars
    ├── schema_and_migrations.md               # PostgREST column mismatches, UUID type errors (22P02), migration scripts
    └── features/                              # 15 Feature-Specific Backend Hand-off Briefs
        ├── auth.md                            # handle_new_user_signup trigger, OTP bypass, plaintext session storage
        ├── community.md                       # RLS block checks, delete IDOR, missing profile columns, fake SEBI license
        ├── journal.md                         # strategies(name) vs strategies(title) join bug, storage 403, signed URLs
        ├── notes.md                           # Note attachments storage path 403, signed URLs, real Edge Function AI
        ├── strategies.md                      # strategy_versions_public_read missing policy, storage 403, trigger races
        ├── market_data.md                     # 22MB static mock JSON replacement, Supabase Edge Function quote proxy
        ├── watchlists.md                      # Schema mismatch on watchlist_items (symbol vs ticker), live quote joins
        ├── ai_assistant.md                    # 'note_ai_...' non-UUID crash, Edge Function LLM streaming endpoint
        ├── calculators.md                     # Wire calculator_history table, Finance Act 2024 tax rates, lot sizes
        ├── settings.md                        # approve_affiliate_application RPC lockdown, avatars bucket, deletion func
        ├── workspace.md                       # N+1 query optimization via inFilter, non-UUID link edge pollution
        ├── affiliate_program.md               # Enable RLS on affiliate_applications, fix infinite $50 balance exploit
        ├── public_site.md                     # Dynamic pricing catalogue synchronization, purge false AES-256 claims
        ├── linking.md                         # 'etl_...' non-UUID type collision on entity_ticker_links
        └── messages.md                        # Realtime private channel lockdown, cleartext DB storage, empty state fix
```

---

## 2. System Health Dashboard

```
┌────────────────────────────────────────────────────────────────────────┐
│                        TRADEX SYSTEM HEALTH                            │
├──────────────────────────────┬──────────────────┬──────────────────────┤
│ Metric                       │ Value            │ Status               │
├──────────────────────────────┼──────────────────┼──────────────────────┤
│ Live Backend Connectivity    │ 22%              │ ⚠️ Heavy Mock Rely   │
│ Production RLS Integrity     │ CRITICAL FAIL    │ 🚨 Privilege Escal. │
│ Storage Upload Success Rate  │ 0%               │ ❌ 100% 403 Denied   │
│ Real-Time Exchange Feed      │ 0%               │ ❌ Static Bundled    │
│ Real-Time DM Privacy         │ FAIL (IDOR)      │ 🚨 Public Broadcast  │
│ KYC / Tax Data Protection    │ FAIL (NO RLS)    │ 🚨 Publicly Leaked   │
│ Cryptographic Protection     │ 0% Implemented   │ ❌ Plaintext Storage │
│ AI Copilot Backend           │ 0% LLM Call      │ ❌ Canned Regex Bot  │
│ Payment Gateway              │ 0% Integrated    │ ❌ Fake Simulation   │
│ Dead Buttons / No-Op Actions │ 24 Cataloged     │ ⚠️ Incomplete Flows  │
└──────────────────────────────┴──────────────────┴──────────────────────┘
```

---

## 3. Developer Hand-off Quick Links

- **For the Frontend Developer:** Hand over [`customer_side/frontend_issues/README.md`](file:///Users/nitishkumar/Downloads/Projects/nk2552003/TradeX/customer_side/frontend_issues/README.md). It outlines the 24 dead buttons to wire, viewport/keyboard insets to fix, and the `go_router` declarative routing architecture.
- **For the Backend Developer:** Hand over [`customer_side/backend_issues/README.md`](file:///Users/nitishkumar/Downloads/Projects/nk2552003/TradeX/customer_side/backend_issues/README.md). It provides the P0 security patches, SQL migrations for RLS lockdown, storage bucket configurations to resolve the 100% upload failure, and schema column alignments.
