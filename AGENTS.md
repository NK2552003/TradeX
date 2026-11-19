# AlphaJournal Engineering Contract

This file is the repository-wide instruction set for people and coding agents working in this project. It replaces older frozen component inventories with rules that point to the actual source of truth.

## 1. Product identity

| Surface | Required value |
| --- | --- |
| Product and user-facing name | **AlphaJournal** |
| Dart package and technical slug | `alphajournal` |
| Android application ID | `com.nk2552003.alphajournal` |
| Apple bundle ID | `com.nk2552003.alphajournal` |
| Native URL scheme | `alphajournal://` |
| Production domain | `alphajournal.in` |
| GitHub repository | **`NK2552003/TradeX`** |

The GitHub repository name and remote are the only active exception allowed to retain **TradeX**. Do not rename the repository, repository directory, or Git remote unless the owner explicitly requests it. Do not introduce TradeX into product copy, app metadata, service names, notifications, store listings, URLs, package IDs, or new runtime identifiers.

Legacy TradeX strings may remain only where they are required to read or migrate existing user data or immutable migration history. Mark compatibility readers clearly and remove them only after a verified forward migration.

## 2. Reusable UI is mandatory

All Flutter screens, dialogs, cards, forms, charts, loading states, and layouts must use the production AlphaJournal UI libraries:

~~~dart
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
~~~

Before creating a widget, inspect these export surfaces:

- `lib/core/app-ui/app_ui.dart`
- `lib/core/flutter-ui/flutter_ui.dart`

Those exports are the current catalogue. Never rely on an old component count or copy a frozen numbered list into a prompt.

### Available component families

- Actions: `UiButton`, `UiIconButton`, `UiDropdownMenu`, menu actions.
- Inputs: `UiInput`, `UiOtpField`, `UiTextarea`, `UiPasswordField`, `UiSearchField`, selects, tags, toggles, checkboxes, radios, sliders, date controls, dropzones, and editor controls.
- Navigation: tabs, toggle groups, breadcrumbs, pagination, steppers, timelines, accordions, and navigation shells.
- Surfaces and data: `UiCard`, `UiCardGrid`, `UiTable`, `UiDataPanel`, `UiStatStrip`, `UiKeyValueTable`, `UiRangeMeter`, metrics, avatars, progress, categories, trackers, and marquees.
- Feedback and state: callouts, badges, dialogs, drawers, popovers, tooltips, toasts, empty states, skeletons, reveal transitions, scrollbars, async views, deferred content, and lazy lists.
- Media and charts: remote images, lightboxes, line, area, bar, combo, spark, donut, candle, waterfall, and graph charts.
- Domain cards: portfolio, watchlist, journal, strategy, community, account, AI, notes, calculator, desk, presence, and trend cards.
- Feature blocks: dashboard, market, journal, community, account, AI, chart, search, enterprise, notes, calculator, workbench, research, desk, linking, journal-note, and strategy-note blocks.
- App shells: `AppShell`, `AppQuietDockScaffold`, `AppWorkspacePane`, and `AppWorkspaceThreePane`.

### Forbidden duplication

Do not create raw `ElevatedButton`, `TextButton`, `OutlinedButton`, `TextField`, decorated `Container` cards, manual loading spinners, or custom-painted financial charts when the library already provides the behavior.

A small layout primitive is acceptable only when:

1. no equivalent exported component exists;
2. composition of existing components cannot express the requirement cleanly;
3. the new primitive is reusable rather than screen-specific; and
4. it is added to the appropriate UI library export and covered by tests.

## 3. Design tokens, responsiveness, and accessibility

Use context-backed design tokens rather than literal colors, radii, spacing, or text styles:

~~~dart
final theme = context.ui;
final colors = theme.colors;
final textStyles = context.uiText;
final padding = context.sp(theme.spacing.md);
final iconSize = context.sz(24);
final radius = context.radius(theme.radii.md);
~~~

Every UI change must:

- support narrow mobile, tablet, and desktop widths without overflow;
- preserve full-width behavior where a workspace or table requires it;
- keep touch targets at least 44 logical pixels;
- provide semantic labels and keyboard/focus behavior;
- respect text scaling, reduced motion, safe areas, and light/dark themes;
- use lazy/deferred components for expensive off-screen content;
- keep the dock visible-state transition animated and avoid abrupt scroll-driven disappearance;
- avoid nested scroll ownership that causes hidden content or unbounded constraints.

For World Indices and Assets, render one consolidated detail table for each requested view. Do not split the same dataset into three competing tables.

## 4. Architecture and state boundaries

Keep features organized by responsibility:

- Presentation owns rendering, interaction, and view state.
- Controllers/providers own orchestration and cancellable asynchronous state.
- Repositories own remote/local data access, caching, pagination, and mapping.
- Models are typed and must not depend on presentation widgets.
- Shared policy belongs under `lib/core/`, not duplicated across screens.

Prefer existing repository and state-management patterns in the feature being changed. Do not perform Supabase, HTTP, storage, billing, or AI requests directly from a widget build method.

All asynchronous work must expose loading, empty, error, retry, and stale-data behavior. Dispose controllers, subscriptions, timers, listeners, and streams.

## 5. Subscription and entitlement enforcement

The canonical client entitlement definitions live in:

- `lib/core/data/app_entitlements.dart`

Current product boundary:

| Capability | Free | Basic / Pro |
| --- | --- | --- |
| Community market sidebar preview | Limited permitted tickers/news/instrument summaries | Included |
| Full Market Intelligence | No | Yes |
| Private Messages | No | Yes |
| Core calculators | Yes | Yes |
| Advanced calculators | No | Yes |

Entitlements are a security boundary, not only a visual lock.

For every gated feature:

1. check access before navigation and before mounting the expensive screen;
2. show a consistent upgrade notification explaining the required plan;
3. do not start paid network, realtime, market, AI, or database calls for an ineligible user;
4. enforce the same rule in the repository/service layer;
5. enforce ownership and tier again in Edge Functions, RPCs, database functions, and RLS;
6. add tests for direct routes, deep links, stale sessions, downgraded users, and direct API/RPC attempts.

Never trust a tier sent by the client. Resolve effective access from trusted server-side subscription state. User-editable metadata must never authorize paid or privileged access.

## 6. Supabase and database security

For every table exposed through the Data API:

- enable RLS;
- use ownership-aware policies, not `TO authenticated` alone;
- add both `USING` and `WITH CHECK` to ownership-sensitive updates;
- use `security_invoker = true` for exposed views where supported;
- keep `SECURITY DEFINER` functions exceptional, outside exposed schemas, with explicit authorization and revoked default execute access;
- never use `raw_user_meta_data` or `user_metadata` for authorization;
- never ship `service_role`, secret keys, database passwords, provider secrets, or webhook secrets to Flutter/web clients.

Schema changes are forward-only. Do not rewrite applied migrations. Add a new migration, test it against staging, run database/security advisors, and include rollback or remediation notes.

Storage policies must cover the exact operation set. An upsert requires select, insert, and update permissions. Validate file ownership, type, size, and path on the server.

Cross-domain CORS is required for the approved AlphaJournal origins. Keep the explicit allowlist for:

- `https://alphajournal.in`
- `https://www.alphajournal.in`
- `https://app.alphajournal.in`
- `https://community.alphajournal.in`
- `https://affiliate.alphajournal.in`
- `https://admin.alphajournal.in`

Do not replace the allowlist with `*`, and do not remove approved cross-subdomain behavior.

## 7. Authentication, sessions, and links

Cross-subdomain session continuity across `*.alphajournal.in` is intentional and must remain. Preserve secure parent-domain cookie behavior, origin validation, SameSite/Secure attributes, session expiry, logout propagation, and stale-cookie cleanup.

Use verified HTTPS Universal Links/App Links for sensitive navigation and installed-app detection. Expected behavior:

1. if AlphaJournal is installed, an approved HTTPS link opens the app;
2. if it is not installed, the link remains on the matching web route;
3. authentication callbacks return to the intended destination;
4. no auth token, OTP, or recovery secret appears in logs or public issue reports.

Do not treat a custom URL scheme as the only verification mechanism for sensitive deep links.

## 8. Unified AI behavior

`lib/core/ai/unified_ai_service.dart` is the canonical multi-provider AI service. Its gateway-first behavior, provider ordering, streaming behavior, fallbacks, timeouts, and error handling are intentional.

Do not replace it with a single-provider client, bypass its gateway, reorder providers, expose provider keys, or remove fallbacks unless the owner explicitly requests an architecture change. New AI features must use the unified service or a server-side gateway-backed abstraction.

AI calls must be entitlement-aware, cancellable, bounded, observable without logging prompts/secrets, and protected from duplicate invocation during rebuilds.

## 9. Market data and egress

Market reads must prefer bounded, cached, shared results over per-widget or per-navigation refetches.

- Deduplicate concurrent requests and apply an explicit freshness window.
- Paginate or window large datasets.
- Select only required columns and rows.
- Avoid downloading the same quote, news item, image, or instrument details for multiple cards.
- Cancel obsolete requests and prevent rebuild-triggered fetch loops.
- Keep Free users on the limited Community preview path; do not call full Market Intelligence endpoints for them.
- Include World Indices and Assets in validation and scheduled CI synchronization.
- Treat provider responses as untrusted input and validate before publication.

Changes to `.github/workflows/supabase-market-sync.yml`, market scripts, or reference datasets must keep offline validation and publish coverage reports.

## 10. Security baseline

AlphaJournal handles accounts, private user content, financial context, subscriptions, and authenticated APIs. Treat it as at least a Tier 2 user-data application.

- Use platform secure storage for auth/session secrets; never plain preferences.
- Keep HTTPS and platform transport security enabled.
- Do not hardcode high-value secrets or rely on compile-time defines to hide server credentials.
- Validate all security-critical input on the server.
- Redact tokens, cookies, passwords, OTPs, personal data, message content, billing data, and signed URLs from logs.
- Use release obfuscation with securely retained split debug symbols.
- Pin dependencies and commit lockfiles.
- Add rate limits, idempotency, replay protection, and signature verification to sensitive server operations.
- Prefer warnings/limited behavior over unreliable hard blocks for rooted or jailbroken devices unless policy requires otherwise.

Confirmed or plausibly exploitable vulnerabilities must be reported privately through GitHub Security Advisories, not a public issue.

## 11. Testing and quality gates

Every fix requires the narrowest useful regression test. Security and entitlement fixes must include a negative test proving the bypass remains closed.

Before handoff, run the relevant subset and, when practical:

~~~bash
dart analyze
flutter test
node --test test/security/platform_security_test.cjs test/web/app_install_test.cjs
git diff --check
~~~

For database changes, also run the matching database tests and Supabase advisors. For UI changes, test mobile and desktop constraints, keyboard navigation, text scaling, loading/error/empty states, and route/deep-link entry.

Do not claim completion from static inspection alone when an executable verification exists.

## 12. GitHub issue and disclosure workflow

Use the forms under `.github/ISSUE_TEMPLATE/` and the routing guide in `.github/ISSUE_GUIDE.md`.

- Public issues must contain sanitized reproduction data only.
- Secrets, PII, private messages, payment details, and weaponized exploit steps are prohibited.
- Confirmed or suspected exploitable vulnerabilities go to the repository's private Security Advisory flow.
- Every issue should state affected version/environment, expected and actual behavior, impact, evidence, and acceptance criteria.
- Release-blocking security, data-loss, authorization, billing, or privacy defects require regression coverage before closure.

## 13. Definition of done

Work is complete only when:

- the implementation uses current shared components and architecture;
- branding and repository exceptions are correct;
- client and server authorization agree;
- no ineligible network/database calls occur;
- loading, error, empty, offline, and retry behavior are handled;
- relevant tests and analysis pass;
- documentation and issue/release notes are updated;
- no secrets or sensitive user data appear in code, logs, screenshots, fixtures, or public issues.
