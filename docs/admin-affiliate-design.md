# Admin and affiliate workspace

Administration uses the existing Supabase accounts, billing, writing, community,
chat, and affiliate records. Admin pages use `AdminRepository` and authenticated
RPCs; a failed live request shows an error instead of sample accounts or metrics.

## Navigation and controls

| Area | Records and actions |
| --- | --- |
| Overview and analytics | Real counts, 7/30/90-day activity, new users, review queues, post engagement, subscriptions, and AI requests |
| Users | Search, status filters, paginated accounts, details, suspension/restoration, role changes, and administrator notes |
| User permissions | Separate posts, comments, notes, journal, strategies, messages, AI, and affiliate controls; per-user quota overrides |
| Affiliates | Application details and approval/rejection, affiliate status and commission controls, referrals, campaigns, payout history and settlement references |
| Posts and comments | Approval queue, review reasons, moderation, pin/feature options, post engagement totals, and linked comments |
| Writing | Per-user notes, journal entries, and strategies; details, restriction/restoration, public visibility, and deletion |
| Messages and AI | User-specific conversations, messages, AI prompts/responses, provider/model/token records, quotas, and restrictions |
| Subscriptions | Current billing entitlement for every account, time-limited app-access grants, expiry, and removal of grants |
| Activity | Database changes, page activity, administrator decisions, actor/subject filters, and record history |
| Deletion requests | Reviewed, confirmed server-side deletion of files and Auth accounts, retryable receipts, and cancellation before processing |
| App settings | Platform feature availability; user overrides cannot enable a globally disabled feature |

Institutional capital allocation, seat invitations, desk orders, and fabricated
risk queues are removed from admin navigation. Legacy admin settings destinations
resolve to platform settings. Private billing-provider charges/cancellations are
not fabricated by changing an entitlement or payout status.

## Shared components and responsive behavior

Pages use the TraderHub libraries `core/app-ui/app_ui.dart` and
`core/flutter-ui/flutter_ui.dart`: `UiPage`, `UiCard`, `UiCardGrid`, `UiTable`,
`UiTabs`, `UiAsyncView`, and shared forms/dialogs. Resource lists share pagination,
filters, loading/errors, record drill-down, and return navigation. Narrow layouts
stack table rows and wrap actions; the regression suite includes larger text,
keyboard insets, light/dark themes, and phone/tablet/desktop widths.

## Database and runtime enforcement

Apply migrations in order:

1. `supabase/migrations/20261027051156_admin_user_management.sql`
2. `supabase/migrations/20261027072601_admin_deletion_consent.sql`

The first migration reuses existing business tables and adds administration
controls, platform settings, durable audit/deletion receipts, AI request fields,
and missing affiliate workspace objects. It checks the caller's current active
administrator profile and restricts all privileged RPCs. RLS and write triggers
apply restrictions to existing sessions, ownership, public documents, related
records, storage, and feature/quota operations. Account access and entitlements
are refreshed in the app.

Account removal cascades linked records. The customer flow therefore requests
full removal after review, optionally waiting 30 days. Legacy partial-retention
requests are blocked by the second migration rather than treated as consent for
full removal. Administrator accounts require demotion by another administrator;
active provider billing must be resolved before deletion. Deletion receipts and
administrator history survive account removal. No production account was deleted
as part of verification.

History is captured from deployment forward. Existing record timestamps and
engagement totals remain available; actions from before tracking began cannot be
reconstructed. Export submission reports a queued request, not a completed file.

## Server functions and client configuration

- `supabase/functions/admin-delete-user/index.ts` validates the authenticated
  administrator, claims a deletion, removes owned Storage files before Auth, and
  records completion or a retryable error.
- `supabase/functions/ai-gateway/index.ts` validates the user, reserves quota
  before provider calls, rechecks access before saving, and records provider
  results and usage. Provider credentials stay on the server.
- `supabase/config.toml` keeps JWT verification enabled for both functions.
- Run `python3 scripts/prepare_client_config.py` before building. Only allowlisted
  public settings go into `assets/config/client.env`; the full `.env` is not
  bundled into the application.

## Verification on 27 October 2026

Both migrations were executed successfully in the authenticated Supabase SQL
Editor for project `ylxwgkhtwrizdmuhlhxs`. Both Edge Functions were deployed with
JWT verification enabled. The SQL Editor returned:

- 28 readback results across all 17 resource types, real account counts, all 24
  user details/entitlements, and customer/anonymous denial checks.
- Three additional live consent checks: partial retention and legacy tax
  retention cannot authorize full removal; denied claims preserve account and
  request status. Verification transactions rolled back their temporary data.

At readback there were 24 accounts, 10 posts, four comments, seven notes, 12
journal entries, eight strategies, three AI threads, seven AI messages, one AI
request, one affiliate, two referrals, and two payouts. Activity totals inside
the readback transaction include its temporary audited detail views, which are
rolled back; they should not be treated as earlier production activity.

Local validation:

- `bash scripts/verify_admin_affiliate_ui.sh`: analyzer clean; 259 tests passed;
  239 responsive screenshots and a review gallery generated.
- `database/tests/admin_user_management.sql`: 70 database checks passed with
  fixture changes rolled back.
- `supabase/functions/tests/admin_functions_test.ts`: 13 Edge Function tests
  passed, covering authentication, quotas, persistence, cleanup ordering, and
  interrupted deletion recovery.
- `flutter build web --release`: passed, including the Wasm compatibility check.
  The built configuration contains public settings only.
- Scripted browser rendering of the release build reached the public landing
  page with no browser errors; authenticated admin interaction remains separate
  from the widget-test screenshots and SQL role simulations.

Evidence is under `artifacts/admin-deployment/` and
`artifacts/admin-affiliate-design/`. The repeatable SQL checks are in
`database/tests/admin_live_readback.sql` and
`database/tests/admin_deletion_consent_live.sql`.

The continuation check at 08:22 UTC confirmed that anonymous overview/settings
requests and unsigned account deletion requests return HTTP 401. The AI endpoint
still returns HTTP 503, `AI service is not configured.` Results are saved in
`artifacts/admin-deployment/continuation-public-check.json`. Flutter analysis was
rerun against the current checkout and returned no issues.

### Continue in the existing Chrome session

`scripts/chrome_admin_session.py` targets the regular Chrome process by PID, so
Flutter's separate Chrome process cannot accidentally replace the signed-in
dashboard session. It lists only Supabase and local application tabs and does
not launch a browser or read stored credentials.

```bash
python3 scripts/chrome_admin_session.py list
python3 scripts/chrome_admin_session.py inspect --tab-id <id-from-list>
python3 scripts/chrome_admin_session.py run-js --tab-id <id-from-list> --file <check.js>
```

Chrome must permit JavaScript from Apple Events (View > Developer > Allow
JavaScript from Apple Events). The current session has this disabled. The
script reports Chrome's explicit error and stops; the existing SQL tab and its
saved queries remain available. Authenticated browser verification and any
additional SQL execution remain pending that browser permission.

AI deployment still needs at least one provider credential in Edge Function
Secrets (`OPENROUTER_API_KEY`, `GEMINI_API_KEY`, `OPENAI_API_KEY`, or
`CLAUDE_API_KEY`). The latest endpoint probe returned `AI service is not
configured.` The existing dashboard session reported insufficient permission to
manage secrets; this must be resolved before reporting live AI generation as
verified. No frontend hosting deployment has been performed.
