# TradeX Frontend Developer Handoff & Issue Registry

**Target Audience:** Frontend Flutter / Mobile / Web Engineers  
**Scope:** Client-Side Architecture, UI/UX Layouts, Viewport Responsiveness, Touch Targets (WCAG), Deep Linking & Declarative Routing, Navigation State, Animations, and Dead UI Controls.  
**Auditor:** Antigravity AI Engineering Team  
**Date:** 2026-10-21  

---

## 1. Executive Summary & Frontend Architecture Overview

TradeX features a modern, bespoke financial design system (`TraderHub` / `core/app-ui`) built on top of Material 3 and custom tokens (`AppTokens`). However, our comprehensive client-side code analysis revealed **critical frontend bugs, 24 completely dead or no-op buttons, severe layout squishing on mobile/tablet viewports, double-inset keyboard occlusion, and zero declarative deep-linking infrastructure**.

```
┌────────────────────────────────────────────────────────────────────────┐
│                     FRONTEND HEALTH DASHBOARD                          │
├──────────────────────────────┬──────────────────┬──────────────────────┤
│ Metric                       │ Value            │ Status               │
├──────────────────────────────┼──────────────────┼──────────────────────┤
│ Dead Buttons / No-Op Actions │ 24 Cataloged     │ 🚨 Needs Immediate Fix│
│ Touch Target Compliance      │ 62%              │ ⚠️ WCAG Violations    │
│ Keyboard Handling Integrity  │ FAIL             │ ❌ Double Inset Bug   │
│ Declarative Web Routing      │ 0% Implemented   │ ❌ Procedural Only   │
│ Double Mobile Docks          │ Present in Comm. │ ❌ 140px Screen Loss │
│ False Marketing Claims       │ 3 Surfaces       │ ❌ Immediate Removal │
└──────────────────────────────┴──────────────────┴──────────────────────┘
```

---

## 2. Master Catalog of Dead Buttons & No-Op Handlers

The following 24 UI controls are currently present in the production UI but are completely non-functional (they execute empty closures, display misleading toasts, or trigger fake timers without doing any real work):

| # | Screen / Surface | File & Line Reference | UI Control | Failure Mechanic | Severity |
|---|---|---|---|---|---|
| 1 | Login Page | `login_page.dart:401, 553` | "Sign in with Google" | Emits `UiToast`; OAuth flow missing | High |
| 2 | Sign Up Page | `signup_page.dart:475, 627` | "Sign up with Google" | Emits `UiToast`; OAuth flow missing | High |
| 3 | Forgot Password | `forgot_password_page.dart:189` | "Reset Password" | 800ms timer; never calls Supabase Auth | Critical |
| 4 | Watchlists Page | `watchlists_page.dart:61` | "Add Symbol" | Emits `UiToast`; search modal never opens | Critical |
| 5 | Watchlists Page | `watchlists_page.dart:83` | Watchlist Ticker Tap | Sets unread `_selectedTicker`; no-op | High |
| 6 | Community Post Detail | `community_post_detail_view.dart:111` | "Quote" Post | `onQuote: () {}` empty closure | Medium |
| 7 | Community Author Header | `community_author_header.dart:257` | "Mute User" | `onPressed: onMute ?? () {}` fallback | Medium |
| 8 | Community Author Header | `community_author_header.dart:262` | "Report Post" | `onPressed: onReport ?? () {}` fallback | Medium |
| 9 | Community Feed View | `community_feed_view.dart:390` | Pull-to-Refresh | Executes `setState(() {})`; does not re-fetch DB | Medium |
| 10 | Security Settings | `account_security_page.dart:172` | Email OTP Field | `onChanged: (v) {}` discards entered OTP | High |
| 11 | Security Settings | `account_security_page.dart:186` | Verify Email Button | 500ms delay; never validates token | High |
| 12 | Security Settings | `account_security_page.dart:475` | Link Google / Apple | Modifies in-memory list; no OAuth | Medium |
| 13 | Billing Settings | `billing_settings_page.dart:178` | "Save card" | Discards card fields; no gateway call | High |
| 14 | Change Plan Page | `change_plan_page.dart:271` | CVC Input | `const UiInput` with no controller | High |
| 15 | Invoice Detail Page | `invoice_detail_page.dart:51` | "Download PDF" | Emits `UiToast`; no file download | Medium |
| 16 | Privacy Settings | `privacy_settings_page.dart:160` | "Download ZIP" | Emits `UiToast`; no file download | Medium |
| 17 | Help & Support | `help_about_page.dart:374` | "Send Ticket" | 600ms timer; drops ticket data | Medium |
| 18 | Affiliate Settings | `affiliate_settings_page.dart:330` | "Copy Link" (Mobile) | Omits `Clipboard.setData`; copies nothing | Low |
| 19 | Affiliate Application | `affiliate_application_page.dart:677`| SMS Verify Icon | Sets `_phoneVerified = true` instantly | Medium |
| 20 | HTML Markdown Viewer | `html_block.dart:512` | HTML `<a>` Links | Styles text; lacks tap recognizer | Low |
| 21 | Public Footer | `tradex_footer.dart:388–450` | Twitter, Discord, etc. | Emits `UiToast`; does not open URL | Low |
| 22 | AI Assistant Chat | `ai_chat_view.dart:242` | Header Options | Child `UiIconButton` has `onPressed: null` | Low |
| 23 | AI Assistant Insights | `ai_insights_view.dart:367` | Card Dropdown | Child `UiIconButton` has `onPressed: null` | Low |
| 24 | Strategy Editor | `strategy_editor_screen.dart:1158`| Header More Menu | Child `UiIconButton` has `onPressed: null` | Low |

---

## 3. Directory Navigation for Frontend Engineers

All frontend issues are broken down into cross-cutting architectural specifications and 15 feature-specific implementation briefs:

```
customer_side/frontend_issues/
├── README.md                                  # This document
├── layout_and_responsive.md                   # Overflows, underflows, keyboard insets, double docks & touch targets
├── navigation_and_routes.md                   # Declarative routing (go_router), deep linking, browser history & back button
│
└── features/
    ├── auth.md                                # Google OAuth, OTP screens, landscape overflow, role switcher dialog
    ├── community.md                           # Double bottom bar, pull-to-refresh, dead quote/report/mute, advisor disclosure
    ├── journal.md                             # Spreadsheet table squishing on mobile, trade logging flows
    ├── notes.md                               # Keyboard double-insets, slash palette overflow, AST UI thread hitching, LFI
    ├── strategies.md                          # Split mode tablet squishing, dead header menu, public confirmation dialog
    ├── market_data.md                         # Candlestick pan gesture vs OS back navigation, mover ticker wrap, disclaimers
    ├── watchlists.md                          # Dead "Add Symbol" toast, dead ticker tap, live price hydration
    ├── ai_assistant.md                        # Dead action buttons, simulated typing indicator, regex bot replacement
    ├── calculators.md                         # 22 calculators UI, division by zero guards, Finance Act 2024 tax UI, lot sizes
    ├── settings.md                            # Dead CVC input, fake email OTP, fake account deletion, mobile copy link bug
    ├── workspace.md                           # Desktop carousel card overlap, date filter preservation on back navigation
    ├── affiliate_program.md                   # SMS verify fake instant success, mobile referral copy clipboard bug
    ├── public_site.md                         # Criminal AES-256 claims in footer, dead social icons, narrow screen currency wrap
    ├── linking.md                             # Stale ticker universe in picker, graph rebuild main isolate lag
    └── messages.md                            # Mobile message composer safe area, false E2EE banner removal, empty state
```

---

## 4. Frontend Developer Priorities & Working Rules

1. **Rule #1: Strict Reusable Component Compliance:**
   - Adhere to `AGENTS.md` mandate: **Never** build custom buttons (`ElevatedButton`, `TextButton`) or custom input containers. Always use `UiButton`, `UiIconButton`, `UiInput`, `UiCard`, `UiBadge`, etc., from `package:tradex/core/app-ui/app_ui.dart`.
2. **Rule #2: Eliminate All Dead UI Controls:**
   - Either wire every listed button in Section 2 to a functional handler/service or remove/disable the control visually (`disabled: true`). Never ship no-op dummy timers to users.
3. **Rule #3: Keyboard & Safe Area Insets:**
   - Never combine `resizeToAvoidBottomInset: true` with manual `MediaQuery.viewInsetsOf(context).bottom` inside a `Positioned` widget. Always wrap mobile bottom bars in `SafeArea(bottom: true)`.
4. **Rule #4: Purge False Cryptographic Copy:**
   - Remove "AES-256 GCM client-side encryption" claims from `tradex_footer.dart:727` and "Direct messages are end-to-end encrypted" from `messages_thread_view.dart:400, 919`.
