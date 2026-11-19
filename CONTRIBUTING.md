# Contributing to AlphaJournal

Thank you for improving AlphaJournal. This repository is named `NK2552003/TradeX`, but the product, package, services, applications, and user-facing identity are AlphaJournal.

## Before you start

1. Read [AGENTS.md](AGENTS.md) for mandatory architecture, UI, security, entitlement, Supabase, linking, and testing rules.
2. Search [existing issues](https://github.com/NK2552003/TradeX/issues).
3. Choose the correct [Issue Form](https://github.com/NK2552003/TradeX/issues/new/choose) for non-trivial work.
4. Read the [Security Policy](.github/SECURITY.md) before reporting security-sensitive behavior.

Do not open a public issue or pull request for a working exploit, secret exposure, authorization/payment bypass, cross-user data access, or private-data leak. Use a [Private Security Advisory](https://github.com/NK2552003/TradeX/security/advisories/new).

## Product and repository identity

| Item | Required value |
| --- | --- |
| Product name | AlphaJournal |
| Dart package | `alphajournal` |
| Android/Apple ID | `com.nk2552003.alphajournal` |
| Domain | `alphajournal.in` |
| URL scheme | `alphajournal://` |
| GitHub repository | `NK2552003/TradeX` |

Do not reintroduce TradeX into active product copy or runtime identifiers. Legacy strings are allowed only for verified compatibility migrations or immutable history.

## Fork and synchronize

Create a fork, then clone it and register this repository as `upstream`:

~~~bash
git clone https://github.com/YOUR_USERNAME/TradeX.git
cd TradeX
git remote add upstream https://github.com/NK2552003/TradeX.git
git remote -v
~~~

Before starting a branch:

~~~bash
git checkout main
git fetch upstream
git merge --ff-only upstream/main
git push origin main
git checkout -b fix/short-description
~~~

Push work to your fork and open a pull request into `NK2552003/TradeX:main`. Do not push directly to the upstream `main` branch.

## Development setup

Install the Flutter version used by CI, then:

~~~bash
flutter pub get
dart analyze
flutter test
~~~

Some validation suites also require Node.js and Python dependencies. Follow the matching workflow or feature README rather than installing unpinned global packages.

Never commit:

- `.env` files or production build defines;
- access/refresh tokens, cookies, OTPs, passwords, or private keys;
- Supabase service-role keys or credentialed database URLs;
- provider, billing, webhook, signing, Firebase, or store secrets;
- real private messages, journals, receipts, user exports, or PII;
- release debug-symbol archives.

## Branch and issue scope

- Keep one coherent change per branch and pull request.
- Separate unrelated bugs instead of hiding them in a broad refactor.
- Preserve existing user changes in a dirty worktree.
- Do not rewrite applied database migrations.
- Do not rename the repository or Git remote.
- Avoid generated-file churn unless the source change requires it.

Use descriptive branch names such as:

- `fix/dock-scroll-animation`
- `fix/free-market-entitlement`
- `feat/consolidated-world-indices`
- `docs/security-issue-forms`

Use focused commits with a short conventional prefix:

- `feat: add …`
- `fix: prevent …`
- `test: cover …`
- `docs: explain …`
- `refactor: simplify …`
- `chore: maintain …`

If review changes are requested, update the same branch and push again. After merge, synchronize `main` and delete the merged branch from your fork.

## Flutter UI requirements

Use the shared libraries:

~~~dart
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
~~~

Inspect the exports before building a new control:

- `lib/core/app-ui/app_ui.dart`
- `lib/core/flutter-ui/flutter_ui.dart`

Do not duplicate shared buttons, inputs, cards, charts, loaders, dialogs, tables, shells, or feature blocks. Use design tokens from `context.ui`, `context.uiText`, `context.sp()`, `context.sz()`, and the provided radius helpers.

UI pull requests must cover:

- mobile, tablet, and desktop constraints;
- keyboard and focus behavior;
- semantic labels and readable contrast;
- text scaling and reduced motion;
- loading, empty, error, retry, and offline/stale states;
- scroll ownership and dock/navigation animation;
- reuse of existing AlphaJournal components.

## Entitlements and network calls

The client entitlement source is `lib/core/data/app_entitlements.dart`.

- Free users receive only the approved Community market/news/instrument preview.
- Full Market Intelligence and private Messages require Basic or Pro.
- Core calculators remain Free; advanced calculator IDs require Basic or Pro.

Every gated feature must be enforced:

1. before navigation;
2. before mounting the screen;
3. before remote/realtime/AI work starts;
4. in the repository/service;
5. in Edge Functions/RPC/database/RLS.

Add a direct-route or direct-API negative test. Hiding a button is not authorization.

## Supabase and migration changes

- Review the current Supabase changelog and official documentation for the affected feature.
- Use forward-only migrations and test them in staging.
- Enable RLS on Data API-exposed tables.
- Bind access to trusted ownership/tier state.
- Use both `USING` and `WITH CHECK` for ownership-sensitive updates.
- Never authorize with user-editable metadata.
- Treat `SECURITY DEFINER` as exceptional and revoke default execution.
- Run relevant database tests and advisors.

Cross-subdomain behavior for approved AlphaJournal origins is required. Preserve the explicit CORS allowlist; never replace it with a wildcard.

## Unified AI changes

Use `lib/core/ai/unified_ai_service.dart` or the approved server gateway. Do not remove its gateway-first flow, provider ordering, streaming behavior, or fallbacks unless an architecture change is explicitly approved.

Use synthetic prompts in tests and reports. Never log or publish private prompts, completions, journals, messages, API keys, or raw provider payloads.

## Testing expectations

Add the narrowest regression test that proves the defect and fix.

Common checks:

~~~bash
dart analyze
flutter test
node --test test/security/platform_security_test.cjs test/web/app_install_test.cjs
git diff --check
~~~

Run feature-specific tests for the code changed. Database, security, billing, entitlement, privacy, and auth fixes require a negative test that demonstrates the bypass/failure remains closed.

## Documentation and changelog

Update documentation when behavior, configuration, architecture, entitlement, deployment, or operator action changes.

Add a concise entry under [CHANGELOG.md](CHANGELOG.md) → **Unreleased** for user-visible, security, migration, or release-process changes. Do not disclose private advisory details before coordinated release.

## Pull request requirements

Use the repository pull-request template and include:

- the problem and outcome;
- linked issue/advisory where safe;
- screenshots or recordings for UI work with all user data removed;
- test commands and results;
- data/migration/egress impact;
- entitlement and security impact;
- rollout and rollback notes.

A pull request is ready when analysis and relevant tests pass, the diff contains no secrets, the requested behavior is demonstrably complete, and documentation reflects the final implementation.
