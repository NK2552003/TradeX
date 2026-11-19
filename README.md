# AlphaJournal

**A cross-platform trading journal, research workspace, market-intelligence suite, community, and AI-assisted workflow for disciplined traders.**

AlphaJournal is built with Flutter for web, Android, iOS, macOS, Windows, and Linux. It connects private journals, research notes, strategy playbooks, calculators, market context, Community discussions, and a gateway-first Unified AI workspace without treating any client-side gate as authorization.

> [!IMPORTANT]
> AlphaJournal is under active development. The repository contains substantial implemented functionality and release infrastructure, but production billing, store signing/listings, hosted migration verification, legal placeholders, and final multi-platform release validation are still open. Do not describe the current tree as store-ready or production-certified.

## Project snapshot

| Item | Current value |
| --- | --- |
| Product name | **AlphaJournal** |
| Version | `1.0.0+1` from [`pubspec.yaml`](pubspec.yaml) |
| Dart package | `alphajournal` |
| Android / Apple identifier | `com.nk2552003.alphajournal` |
| Native URL scheme | `alphajournal://` |
| Production domain | `alphajournal.in` |
| GitHub repository | [`NK2552003/TradeX`](https://github.com/NK2552003/TradeX) |
| Status | Active development / release preparation |

The GitHub repository name is the only active **TradeX** exception. Product copy, package names, native IDs, links, services, and new runtime identifiers must use **AlphaJournal**. Legacy TradeX strings may remain only where an existing-data migration or immutable history requires them.

## What AlphaJournal includes

- **Writing Desk:** date-based activity, recent work, command navigation, and connected private records.
- **Trade Journal:** structured trade reviews, execution data, P&L and R-multiple calculations, tags, attachments, analytics, sharing, and eligible PDF export.
- **Research Notes:** Markdown editing and preview, trader-focused templates, tables, checklists, code, math, charts, attachments, dictation, ticker links, backlinks, AI refactoring, and eligible export.
- **Strategy Playbooks:** setup rules, entry/exit and risk plans, lifecycle states, revisions, evidence links, analytics, AI review, and plan-aware limits.
- **Calculators:** trading, investing, options, forex, and tax tools with journal-draft handoff where supported.
- **Market Intelligence:** World Indices, Assets, movers, instruments, news, screeners, history, fundamental/valuation context, holders, option snapshots, search, and shareable ticker previews.
- **Community:** feeds, profiles, posts, articles, media, cashtags, mentions, hashtags, polls, reactions, bookmarks, reposts, replies, moderation, live spaces, and public-record previews.
- **Private Messages:** Basic/Pro direct and group conversations, encrypted envelopes, attachments, voice notes, requests, reactions, presence, and shared AlphaJournal record cards.
- **Unified AI:** gateway-first multi-provider chat, streaming, search/research modes, citations, trader workflows, tool approvals, workspace actions, memory controls, schedules, voice, and saved research pages.
- **Operations:** affiliate workspace, server-verified admin console, publication library, notification controls, privacy tools, subscription management, release notes, and security reporting.

For the detailed walkthrough, see the [feature guide](docs/FEATURES_GUIDE.md). The complete current capability and change inventory is maintained in the [changelog](CHANGELOG.md).

## Plans and enforced access

Plan checks are enforced before navigation, before an expensive screen mounts, before paid network/realtime/database work begins, in repositories/services, and again at trusted server/database boundaries.

| Capability | Free | Basic | Pro |
| --- | --- | --- | --- |
| Community | Included, subject to published quotas | Included | Included |
| Community market sidebar | Limited approved tickers, news, and instrument summaries | Included | Included |
| Full Market Intelligence | Locked | Included | Included |
| Private Messages | Locked | Included | Included |
| Core calculators | Included | Included | Included |
| Advanced calculators | Locked | Included | Included |
| Workspace and AI usage | Limited | Higher limits | Highest limits |
| PDF export and advanced backtesting | Not included | Not included by baseline | Included by baseline |

The baseline quotas live in [`lib/core/config/customer_limitations.dart`](lib/core/config/customer_limitations.dart), and paid capability policy lives in [`lib/core/data/app_entitlements.dart`](lib/core/data/app_entitlements.dart). A published server catalogue may update plan presentation and quota values, but the client must never grant access from user-editable metadata or an untrusted tier value.

Paid monthly checkout remains disabled until the production Razorpay/RevenueCat products, signed builds, verified webhooks, store review, and server-side entitlement readback are complete.

## Platform architecture

| Surface | Canonical host | Responsibility |
| --- | --- | --- |
| Public site | `alphajournal.in` / `www.alphajournal.in` | Landing, auth entry, help, pricing, referrals, public content |
| Trader app | `app.alphajournal.in` | Writing Desk, Journal, Notes, Strategies, Calculators, Markets, Messages, AI, settings |
| Community | `community.alphajournal.in` | Feed, discovery, profiles, public posts, discussions |
| Affiliate | `affiliate.alphajournal.in` | Applications, referrals, campaigns, assets, payouts |
| Admin | `admin.alphajournal.in` | Publishing, moderation, users, subscriptions, risk, audits, settings |

Approved AlphaJournal subdomains intentionally share authenticated session continuity. That requirement is preserved through explicit origin allowlisting and secure parent-domain session handling; wildcard credentialed CORS is not permitted.

Verified HTTPS App Links / Universal Links are the preferred handoff mechanism. When a supported AlphaJournal app is installed, approved links can open the native route. Otherwise, users remain on the equivalent web route. The `alphajournal://` scheme remains available for internal/native routing but is not the only security boundary for sensitive links.

## Versioning and updates

The canonical application version is the `version: X.Y.Z+BUILD` value in [`pubspec.yaml`](pubspec.yaml). Flutter propagates it to supported platform metadata.

AlphaJournal checks the small static HTTPS manifest at [`web/app-update.json`](web/app-update.json); version checks do not query Supabase. The implementation supports:

- recommended updates that a user can postpone per release;
- required updates when a build is below the published minimum;
- six-hour successful-check caching and 15-minute failure retries;
- concurrent request deduplication and a streamed 64 KiB manifest limit;
- safe web cache/service-worker cleanup followed by a reload;
- native handoff to an official store or signed download channel.

Native applications do not silently replace their own binaries. Publishing version metadata does not mean an Android, Apple, or desktop build is actually available; update metadata for a native platform must be advanced only after its signed release is live.

Generate or verify release metadata with:

```bash
python3 scripts/generate_app_update_manifest.py --platform web
python3 scripts/generate_app_update_manifest.py --platform web --check
```

See [Release and version operations](CHANGELOG.md#release-and-version-operations) before changing minimum-supported releases.

## Technology

- Flutter and Dart 3 for the multi-platform client
- Supabase Auth, Postgres, RLS, Storage, Realtime, and Edge Functions
- Cloudflare Pages/Worker routing for the web surfaces, headers, SEO, and social previews
- Python market/news synchronization and release tooling
- GitHub Actions for update validation and scheduled market/reference-data publication
- RevenueCat and Razorpay integrations prepared for verified server-side subscription reconciliation
- Firebase Cloud Messaging and web push support
- Gateway-first Unified AI with bounded provider fallbacks
- Shared AlphaJournal component libraries under `lib/core/app-ui/` and `lib/core/flutter-ui/`

## Repository map

| Path | Purpose |
| --- | --- |
| `lib/core/` | Shared UI, configuration, security, updates, billing, navigation, linking, privacy, notifications, and AI infrastructure |
| `lib/features/` | Auth, workspace, journal, notes, strategies, calculators, markets, community, messages, AI, affiliate, admin, and settings |
| `assets/` | Fonts, public client configuration, and in-app legal/publication content |
| `database/` | Canonical schema, ordered migrations, RLS policies, seeds, and database tests |
| `supabase/` | Deployable Edge Functions and newer forward-only Supabase migrations |
| `scripts/` | Market pipeline, validation, client-config preparation, and update-manifest generation |
| `server/copilot/` | Optional encrypted self-hosted Copilot service and operational guide |
| `worker/` | Cloudflare routing, SEO, and public sharing behavior |
| `web/` | PWA assets, headers, install/update bridges, push worker, manifest, and release metadata |
| `test/` | Flutter, Dart, Node, Python, database, security, worker, and web regression coverage |
| `.github/` | Issue forms, security/support policy, pull-request template, and CI workflows |
| `docs/` | Feature, deployment, billing, AI, observability, security, and publication documentation |
| `backend_handoff/` | Feature-specific backend contracts and operational handoff notes |

## Local development

### Prerequisites

- Flutter `3.47.9` on the stable channel, matching current CI
- Dart SDK compatible with `^3.12.2`
- Python `3.11` for scripts and pipeline tests
- Node.js `22` for web, worker, database-contract, and security tests
- Platform toolchains for any native target you intend to run
- Optional: a current Supabase CLI for local database and Edge Function work

Use the committed lockfile and Android Gradle wrapper. Review upstream migration notes before upgrading major dependencies; in particular, Supabase Flutter v3 is a breaking upgrade from the currently pinned v2 client.

### Install and configure

```bash
git clone https://github.com/NK2552003/TradeX.git
cd TradeX
flutter pub get
cp .env.example .env
```

Fill only the values needed for your local workflow. Then generate the allowlisted public client asset:

```bash
python3 scripts/prepare_client_config.py
```

The generator reads the ignored root `.env`, exports only approved public settings to `assets/config/client.env`, and synchronizes the web update metadata. Review the generated file before building.

### Run the app

```bash
# Web
flutter run -d chrome

# Any connected/supported target
flutter devices
flutter run -d <device-id>
```

When Supabase is not configured, parts of the application can use local/demo behavior; authenticated, realtime, storage, billing, and hosted AI flows require correctly configured services.

## Configuration and secret rules

Safe client configuration includes values such as a Supabase project URL, a publishable/anonymous client key, public RevenueCat SDK keys, a Razorpay public Key ID, environment name, and the public update-manifest URL.

Never place these values in Flutter assets, Dart defines, screenshots, logs, issues, or commits:

- Supabase `service_role` or secret keys;
- database passwords or credentialed database URLs;
- OpenAI/OpenRouter/Gemini/Anthropic provider secrets;
- Razorpay Key Secret or webhook secret;
- RevenueCat secret API key or webhook token;
- Firebase service-account JSON;
- signing keys, private certificates, OTPs, cookies, access/refresh tokens, or private user data.

Server/provider secrets belong in Supabase Edge Function secrets, CI secret storage, or the deployment secret manager. The client-facing key is still constrained by grants, RLS, ownership checks, and server-side entitlement policy.

## Supabase and database workflow

Read [`database/README.md`](database/README.md) before changing schema or policies.

- Use forward-only migrations; never rewrite a migration already applied to a shared environment.
- Keep explicit grants and RLS together for Data API objects. Grants decide whether a role can reach an object; RLS decides which rows it can access.
- Bind private rows to ownership or another trusted authorization rule. `TO authenticated` alone is not object authorization.
- Ownership-sensitive updates require both `USING` and `WITH CHECK`.
- Prefer `security_invoker` views. Treat `SECURITY DEFINER` as exceptional, revoke default execution, and authorize callers inside the function.
- Never authorize from `user_metadata` / `raw_user_meta_data`.
- Test Storage upserts with select, insert, and update policy coverage.
- Apply and verify migrations in staging, run database/security advisors, and record rollback/remediation notes before production promotion.

Market and storage egress are controlled through bounded selects, pagination/windowing, shared freshness windows, request deduplication, lazy loading, and last-known-good data. Free users must not start full Market Intelligence or paid Message queries. World Indices and Assets are published by the dedicated reference-market CI job and displayed as one consolidated detail table per view.

Pipeline documentation is in [`scripts/README.md`](scripts/README.md) and [`docs/github-cicd-market-database-sync.md`](docs/github-cicd-market-database-sync.md).

## Validation

Run the checks relevant to your change. The broad local baseline is:

```bash
dart analyze
flutter test
python3 -m unittest discover -s test/scripts -p 'test_*.py' -v
node --test test/security/platform_security_test.cjs test/web/app_install_test.cjs test/web/app_update_test.cjs
git diff --check
```

Useful focused checks include:

```bash
# Update system
flutter test test/core/update
python3 test/scripts/test_generate_app_update_manifest.py

# Entitlements and paid-feature bypasses
flutter test test/core/data test/features/calculators/calculator_entitlements_test.dart test/features/community/community_market_access_test.dart

# Market pipeline without hosted writes
python -m pip install -r scripts/requirements.txt
python scripts/sync_market_pipeline.py --dry-run --symbols AAPL,RELIANCE.NS,BTC-USD --report /tmp/alphajournal-market-report.json
```

Security, privacy, auth, billing, entitlement, RLS, and data-isolation changes require a negative regression test that proves the bypass or cross-user access remains closed.

## Deployment and release

Web releases prepare version metadata and public configuration before the Flutter build:

```bash
python3 scripts/generate_app_update_manifest.py --platform web
python3 scripts/prepare_client_config.py
python3 scripts/generate_app_update_manifest.py --platform web --check
flutter build web --release
```

Deployment details, subdomain routing, auth redirects, DNS, AI secrets, and Cloudflare setup are documented in [`docs/cloudflare-deployment-and-subdomains.md`](docs/cloudflare-deployment-and-subdomains.md).

Before a release:

1. Update `version: X.Y.Z+BUILD` in `pubspec.yaml`.
2. Move completed entries from **Unreleased** into a dated changelog release.
3. Validate update metadata and all affected tests.
4. Apply and verify database changes in staging.
5. Publish only the platform metadata whose signed build is actually available.
6. Complete the evidence checklist in [`ALPHAJOURNAL_NEXT_STEPS.md`](ALPHAJOURNAL_NEXT_STEPS.md).

### Current release blockers

- hosted Supabase migrations, grants, RLS, and advisors need final staging evidence;
- Android release signing and Apple provisioning/store configuration are incomplete;
- production RevenueCat/Razorpay products, secrets, webhooks, reconciliation, restore, expiry, and refund flows are not fully verified;
- production push credentials and physical-device delivery tests remain;
- App Links / Universal Links require final hosted association files and platform verification;
- legal/publication drafts still require owner/legal review and final business/contact details;
- the complete web, Android, and iOS release candidate matrix has not passed final validation.

## Security and responsible disclosure

Do not put suspected exploitable vulnerabilities, secrets, authorization/payment bypasses, cross-user data, private messages, or weaponized steps in a public issue.

- Confirmed or suspected exploitable issue: [open a private GitHub Security Advisory](https://github.com/NK2552003/TradeX/security/advisories/new)
- Disclosure rules and scope: [Security Policy](.github/SECURITY.md)
- Non-sensitive hardening or ordinary defects: [Issue Guide](.github/ISSUE_GUIDE.md)
- Guided issue forms: [New issue chooser](https://github.com/NK2552003/TradeX/issues/new/choose)

Cross-subdomain sessions for approved AlphaJournal origins and the gateway-first Unified AI fallback design are intentional. Report an origin bypass, cookie leak, unauthorized session transfer, exposed provider key, or broken authorization boundary—not the existence of those supported architectures by itself.

## Contributing

Read the [engineering contract](AGENTS.md) and [contribution guide](CONTRIBUTING.md) before changing code. New Flutter UI must reuse the AlphaJournal libraries exported by:

```dart
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
```

Do not duplicate an existing shared button, input, card, table, chart, loader, dialog, shell, or feature block. Pull requests must include relevant tests, sanitized evidence, entitlement/security impact, data/egress impact, and rollout/rollback notes.

## Documentation index

| Document | Use it for |
| --- | --- |
| [`CHANGELOG.md`](CHANGELOG.md) | Unreleased work, complete capability inventory, fixes, security changes, and release operations |
| [`ALPHAJOURNAL_NEXT_STEPS.md`](ALPHAJOURNAL_NEXT_STEPS.md) | Evidence-driven security and release command center |
| [`AGENTS.md`](AGENTS.md) | Repository-wide engineering, architecture, UI, security, and quality rules |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Branch, issue, testing, documentation, and pull-request workflow |
| [`.github/ISSUE_GUIDE.md`](.github/ISSUE_GUIDE.md) | Choose the correct issue form and sanitize evidence |
| [`.github/SECURITY.md`](.github/SECURITY.md) | Private vulnerability disclosure and safe-harbor policy |
| [`docs/FEATURES_GUIDE.md`](docs/FEATURES_GUIDE.md) | Detailed product capabilities and user workflows |
| [`docs/ALPHAJOURNAL_BILLING_AND_PUBLICATION.md`](docs/ALPHAJOURNAL_BILLING_AND_PUBLICATION.md) | Billing providers, catalogue, webhook, and publication gates |
| [`docs/cloudflare-deployment-and-subdomains.md`](docs/cloudflare-deployment-and-subdomains.md) | Web build, domains, redirects, Cloudflare, and runtime configuration |
| [`docs/security/deploy-2026.md`](docs/security/deploy-2026.md) | Security-focused deployment checklist |
| [`docs/SUPABASE_LOGGING_AND_OBSERVABILITY.md`](docs/SUPABASE_LOGGING_AND_OBSERVABILITY.md) | Logging, monitoring, and operational diagnostics |
| [`docs/copilot.md`](docs/copilot.md) | Unified AI/Copilot architecture and deployment |
| [`CONTEXT.md`](CONTEXT.md) | Writing-record, linking, sharing, and visibility terminology |
| [`scripts/README.md`](scripts/README.md) | Market/news data and update-manifest tooling |
| [`database/README.md`](database/README.md) | Schema, migrations, RLS, seeds, and database verification |

## Recent work

The current **Unreleased** log includes the AlphaJournal rebrand, animated dock behavior, full-width workspace fixes, installed-app handoff, consolidated World Indices/Assets tables, market-sync CI coverage, plan-aware Market Intelligence/Messages/calculator restrictions, reduced duplicate data calls, security hardening, GitHub issue workflows, `.gitignore` corrections, and the cross-platform update system.

Read [`CHANGELOG.md`](CHANGELOG.md) for the authoritative details and release procedure. Do not copy the capability list into a second release log; update the changelog whenever behavior, security, configuration, entitlements, deployment, or operator actions change.
