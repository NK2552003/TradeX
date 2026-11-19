# Changelog

All notable AlphaJournal changes are recorded here.

AlphaJournal follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and semantic versioning. The canonical application version is `version: X.Y.Z+BUILD` in `pubspec.yaml`; Flutter propagates it to Android, iOS, macOS, Windows, Linux, and web release metadata.

## [Unreleased]

### Added

- Automatic release checks for web, Android, iOS, macOS, Windows, and Linux.
- A static, database-free `app-update.json` release manifest with latest and minimum-supported version/build values per platform.
- Recommended-update prompts that can be postponed per release and non-dismissible required-update prompts for unsupported builds.
- Secure web refresh behavior that removes obsolete Flutter caches and the legacy Flutter service worker before loading the newest deployment without removing AlphaJournal push workers or unrelated application caches.
- Store/download handoff for native platforms; Android, Apple, and desktop binaries remain subject to their signed store or installer update flow.
- A Help and policies version card showing the installed semantic version, build number, package identifier, platform, and manual update-check action.
- Six-hour successful update-check caching, 15-minute failure retries, streamed 64 KiB response limits, and concurrent-request deduplication to avoid repeated network traffic.
- A release-manifest generator that synchronizes public release metadata from `pubspec.yaml` without querying Supabase.
- Professional GitHub Issue Forms for security hardening, bugs, frontend/accessibility, authentication, database/egress, billing/entitlements, market data, Unified AI, community/messages, mobile/deep links, performance, deployment, features, and documentation.
- Private vulnerability disclosure policy, public issue-routing guide, contribution guide, pull-request checklist, and evidence-based AlphaJournal release command center.

### Application capabilities

- **Accounts and access:** email/password and OTP flows, recovery, authenticated sessions, role switching, cross-subdomain session continuity, account/device controls, profile privacy, blocked-user management, account deletion, and public/private record visibility.
- **Installation and navigation:** installable PWA support, Android/iOS/native application identity `com.nk2552003.alphajournal`, verified HTTPS deep-link preparation, installed-related-app detection, route-preserving app handoff, browser fallback, global search, breadcrumbs, and contextual record links.
- **Writing Desk and workspace:** date-based activity, quick creation, linked trades/notes/playbooks, responsive workspace panes, command-palette navigation, recent activity, and reusable record previews.
- **Trade Journal:** structured execution templates, long/short entries, entry/exit/stop/target/quantity/fees, P&L and R-multiple calculations, conviction/emotion/mistake tags, attachments, strategy links, analytics windows, public/private sharing, and eligible PDF export.
- **Trading Notes:** Markdown authoring and preview, templates, tables/checklists/code/math/flow content, `$TICKER` chips, `[[wiki links]]`, attachments, dictation, backlinks, AI refactoring, publication links, sharing, and eligible PDF export.
- **Strategy Playbooks:** setup templates, entry/exit/risk rules, Draft/Backtesting/Live/Archived lifecycle, revision history, linked journal evidence, performance telemetry, AI review, sharing, and tier-aware active-playbook limits.
- **Calculators:** Position Size, Risk/Reward, Brokerage & Charges, Margin, Pivot Points, Fibonacci Levels, Profit & Loss, Options P&L, Black-Scholes Greeks, Contract Value, SIP, Lumpsum, Fixed Deposit, CAGR, Inflation Impact, PPF, EMI, Currency Converter, Pip Value, STCG, LTCG, and Trading Turnover, including journal-draft handoff where supported.
- **Market Intelligence:** global and Indian market overview, World Indices, Assets, movers, instruments, news, screeners, coverage status, quote history, valuation/fundamental details, holders, option snapshots, symbol search, canonical instrument links, and shareable ticker previews.
- **Community:** public feeds and profiles, handles, posts, trade-setup cards, articles, charts, media and audio, cashtags/mentions/hashtags, polls, reactions, bookmarks, reposts, quote posts, nested replies, follows, notifications, moderation/reporting, live spaces, snapshot sharing, and clipping community research into private workspace records.
- **Private Messages:** Basic/Pro-only direct and group conversations, encrypted message envelopes, recovery-key workflow, attachments, voice notes, typing/read state, forwarding, requests, blocking, and shared Journal/Note/Strategy/Market/Community record cards.
- **Unified AI:** gateway-first multi-provider AI with preserved fallbacks, streaming chat, Auto/Live Search/Deep Research modes, citations, specialist trader workflows, tool approvals, workspace-aware actions, memory controls, schedules, voice input/output, call history, and saved research pages.
- **Notifications:** in-app activity inbox, unread state, mentions/replies/security events, route-aware navigation, device subscription controls, and web push delivery support.
- **Subscriptions and billing:** Free, Basic, and Pro plan definitions, trusted entitlement refresh, quota/usage displays, upgrade notices, billing management, purchase restoration, RevenueCat mobile integration, Razorpay server checkout preparation, webhook reconciliation, invoices, cancellation/refund guidance, and server-enforced access expectations. Paid monthly checkout remains disabled until production provider products, signing, webhooks, and store review are complete.
- **Affiliate workspace:** partner applications, referral codes and `/r/:slug` links, consent-aware cross-subdomain attribution, UTM campaign tracking, referral/conversion views, marketing assets, payout profiles, approval state, and administrative review.
- **Admin console:** server-verified admin entry, analytics, users, records, subscriptions, team seats, affiliate approvals/payouts, publishing, moderation, risk/compliance, audit logs, account-deletion oversight, and platform settings.
- **Help, legal, and privacy:** searchable publication library, release notes, installation help, support requests, cookie/consent preferences, privacy and data controls, trading/AI risk notices, accessibility guidance, and public help routes.
- **Experience and accessibility:** AlphaJournal shared UI components, responsive mobile/tablet/desktop layouts, light/dark themes, density/zoom/text-size controls, keyboard and focus behavior, safe areas, reduced-motion support, loading/empty/error states, animated overlays, and full-width data workspaces.

### Changed

- Replaced the obsolete scaffold README with a complete AlphaJournal project guide covering current capabilities, plan enforcement, architecture, setup, secrets, Supabase/RLS workflow, validation, versioning, deployment, release blockers, security reporting, contribution rules, and documentation links.
- Renamed product-facing TradeX/alphajournal references to **AlphaJournal** while retaining `NK2552003/TradeX` only as the GitHub repository-name exception.
- Standardized the Dart package slug as `alphajournal`, native URL scheme as `alphajournal://`, production hosts under `alphajournal.in`, and native application/bundle identifier as `com.nk2552003.alphajournal`.
- Replaced the frozen UI component inventory in `AGENTS.md` with a maintainable engineering contract based on the real `app_ui.dart` and `flutter_ui.dart` exports.
- Kept intentional cross-subdomain authentication for approved `*.alphajournal.in` hosts with explicit origin validation instead of wildcard CORS.
- Preserved the Unified AI gateway-first provider order, streaming behavior, bounded timeouts, and provider fallbacks.
- Consolidated World Indices and Assets into a single complete detail table per view instead of three competing tables.
- Updated plan copy and route policy so Free includes Community, core calculators, limited Community market previews, and limited workspace/AI quotas; Basic and Pro unlock full Market Intelligence, Private Messages, and advanced calculators; Pro adds the highest limits and eligible advanced exports/analytics.

### Fixed

- Animated the scroll-driven dock visibility transition so the dock no longer disappears abruptly.
- Corrected full-width layouts and table constraints that left unused horizontal space or clipped content.
- Added installed-app detection and route-preserving native handoff while retaining the same web route when no supported app is installed.
- Added World Indices and Assets to scheduled market synchronization and validation coverage.
- Prevented Free users from mounting or directly navigating into full Market Intelligence, Private Messages, or advanced calculators; blocked attempts receive a consistent upgrade notification.
- Prevented paid-only market/message/database/realtime work from starting when the active entitlement is ineligible.
- Reduced repeated market, image, storage, and database reads through bounded selection, pagination, shared freshness windows, concurrent-request deduplication, and lazy/deferred loading.
- Hardened update parsing against malformed, unsupported, insecure, oversized, and unavailable manifests; update-check failures do not block normal application startup.
- Corrected Git ignore rules so the Android Gradle wrapper, release/update sources, CI workflows, tests, and documentation are publishable while build output, generated registrants, local Supabase state, IDE metadata, environment secrets, signing keys, and service credentials remain excluded.

### Security

- Enforced entitlement checks before navigation, before expensive screens mount, in repositories/services, and in server/database boundaries where applicable.
- Required trusted server-side subscription state rather than client-editable role/tier metadata for paid access.
- Preserved ownership-aware RLS, storage operation coverage, privileged-function authorization, input validation, secret separation, sensitive-log redaction, webhook verification, idempotency, and replay protection requirements.
- Public security reports now require sanitized evidence with no credentials, tokens, personal data, private messages, payment data, active bypass instructions, or weaponized exploit details.
- Confirmed or plausibly exploitable vulnerabilities are routed to GitHub Private Security Advisories.
- Security, privacy, billing, and entitlement changes require negative regression tests demonstrating that direct-route and direct-API bypasses remain closed.

### Release and version operations

1. Update `version: X.Y.Z+BUILD` in `pubspec.yaml`. Increase `X.Y.Z` according to semantic versioning and always increase the numeric build for each submitted native binary.
2. Move relevant entries from **Unreleased** into `## [X.Y.Z] - YYYY-MM-DD`.
3. Publish web metadata before the web build:

   ~~~bash
   python3 scripts/generate_app_update_manifest.py --platform web
   python3 scripts/prepare_client_config.py
   flutter build web --release
   ~~~

4. When a signed native release is actually live, publish only that platform's version metadata, for example:

   ~~~bash
   python3 scripts/generate_app_update_manifest.py --platform android
   python3 scripts/generate_app_update_manifest.py --platform ios
   ~~~

5. Use `--minimum-version` and `--minimum-build-number` only when older releases must be blocked for a verified security or compatibility reason.
6. Validate metadata before deployment:

   ~~~bash
   python3 scripts/generate_app_update_manifest.py --platform web --check
   flutter test test/core/update
   python3 test/scripts/test_generate_app_update_manifest.py
   node --test test/web/app_update_test.cjs
   ~~~

## Release entry template

~~~markdown
## [X.Y.Z] - YYYY-MM-DD

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security
~~~

Release notes must describe user-visible impact in plain language, identify migrations/entitlement/rollout requirements, avoid secrets and private advisory details, and state any rollback, compatibility, or minimum-version requirement.
