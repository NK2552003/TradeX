# TraderHub — Backend Developer Docs

Everything needed to build the Supabase backend (Postgres/Auth/Realtime/Storage/Edge Functions) and its integrations. Product/UI context lives in separate doc sets (product docs, UI/UX designer docs) — this package is scoped to server-side implementation.

For the combined frontend + backend layout, see [FULL_STACK_FOLDER_STRUCTURE.md](../FULL_STACK_FOLDER_STRUCTURE.md).

## Read in this order

1. **[ARCHITECTURE.md](./ARCHITECTURE.md)** — stack, high-level diagram, folder structure, environments. Start here for orientation.
2. **[API_DATA_MODEL.md](./API_DATA_MODEL.md)** — full schema DDL, RLS policies, Edge Function flows (source of truth for the data model).
3. **[DATABASE_ERD.md](./DATABASE_ERD.md)** — visual entity relationships, indexing recommendations, migration conventions.
4. **[API_REFERENCE.md](./API_REFERENCE.md)** — every REST/RPC endpoint and Edge Function as a formal request/response reference, including error cases.
5. **[INTEGRATIONS.md](./INTEGRATIONS.md)** — Claude API, market data provider, RevenueCat, push notifications, Supabase Storage — what each is used for and the integration contract.
6. **[BACKGROUND_JOBS.md](./BACKGROUND_JOBS.md)** — scheduled jobs, rate-limit design (soft vs. hard caps), idempotency requirements.
7. **[ERROR_HANDLING.md](./ERROR_HANDLING.md)** — standard error envelope, HTTP status conventions, client retry guidance, logging rules.
8. **[ENVIRONMENT_VARIABLES.md](./ENVIRONMENT_VARIABLES.md)** — every secret/env var, per environment.
9. **[SECURITY_COMPLIANCE.md](./SECURITY_COMPLIANCE.md)** — RLS review checklist, AI output compliance, incident response.
10. **[TESTING_STRATEGY.md](./TESTING_STRATEGY.md)** — RLS testing, Edge Function testing, coverage priorities.
11. **[DEPLOYMENT.md](./DEPLOYMENT.md)** — CI/CD pipeline, staging→prod release process, rollback plan.
12. **[DEV_SETUP.md](./DEV_SETUP.md)** — local environment setup, running Supabase locally, common issues.

## Known gaps — flagged, not silently built around
These came up while writing the docs above. Several were closed in a later revision (schema/contracts added); what's left is genuinely still open:

| Gap | Status | Where flagged | What's needed |
|---|---|---|---|
| RevenueCat webhook receiver | ✅ Resolved | API_DATA_MODEL.md § 9, API_REFERENCE.md § 2 | Full contract + idempotency now specced — just needs building against the spec |
| `device_tokens` table for push notifications | ✅ Resolved | API_DATA_MODEL.md § 1, INTEGRATIONS.md § 4 | Table + RLS now in the schema |
| `ai-chat` (AI Q&A) request/response contract | ✅ Resolved | API_DATA_MODEL.md § 10, API_REFERENCE.md § 2 | Contract specced; streaming wire-format still needs a final decision alongside frontend implementation |
| `price-alerts` cooldown/dedup state | ✅ Resolved | API_DATA_MODEL.md § 1 (`watchlist_items.alert_armed`/`alert_last_triggered_at`), § 8 (arm/re-arm logic) | Schema + logic now specced |
| Per-category push notification opt-out enforcement server-side | 🔶 Open | INTEGRATIONS.md § 4 | `device_tokens` has no per-category flag yet — needs either a column there or a separate `notification_preferences` table |
| Direct Message push delivery mechanism unchosen | 🔶 Open | API_DATA_MODEL.md § 11, INTEGRATIONS.md § 4 | The `notify_new_message` trigger writes the in-app `notifications` row synchronously, but nothing watches for `category='direct_message'` rows and actually calls FCM/APNs yet — needs a Realtime-triggered function or scheduled-polling decision |
| `blocks` table not yet applied to Community feed filtering | 🔶 Open | DATABASE_ERD.md § 2 | A blocked user's public posts/comments are still technically visible in the blocker's own feed — `posts`/`comments` stay public-read by design, so this needs an application-layer query filter (`not in (select blocked_id from blocks where blocker_id = auth.uid())`), not an RLS change |
| `ai_chat_messages` table (conversation history for `ai-chat`) | 🔶 Open | API_DATA_MODEL.md § 10 | Needs a retention-policy decision (how long to keep chat history) before adding the table with real defaults |
| No cache-sweep job for `ai_insights`, no retention job for `ai_insight_requests` | 🔶 Open | BACKGROUND_JOBS.md § 1 | Add two simple scheduled cleanup jobs |
| Market data provider not chosen yet | 🔶 Open | INTEGRATIONS.md § 2 | Decide based on rate limits + forex/crypto coverage before `ai-insight`/`price-alerts` can be finished |
| No failover if market data provider is down | 🔶 Open | INTEGRATIONS.md § 2 | At minimum, a cached "prices as of" fallback |
| No soft-delete/trash convention — all deletes are hard deletes | 🔶 Open | API_REFERENCE.md § 1 | Matters for the "Undo" toast pattern (SCREENS_MOBILE.md cross-cutting states) surviving an app restart or a delayed sync; needs a decision on whether to add a `deleted_at` column (soft delete + a cleanup job) or accept that Undo only works in the same session |
| Enterprise data model (`organizations`, `organization_members`, `api_keys`) unspecced | 🔶 Intentionally deferred | ARCHITECTURE.md § 4, ROADMAP.md | Deferred intentionally — Enterprise is post-MVP |
| Global desktop search has no backend query defined | (cross-referenced from the UI/UX doc set) | Needs a cross-table search approach or search index before implementation |

Treat this table as the actual backlog for backend work that isn't yet "just build what the docs say" — everything else in this package is meant to be buildable as specified.
