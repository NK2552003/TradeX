# TradeX backend developer documentation

This package covers the Supabase backend implementation, including PostgreSQL schema, row-level security policies, Realtime channels, Storage buckets, Edge Functions, and external integrations. Product and UI contexts are detailed in separate documents.

For the combined repository layout, refer to [FULL_STACK_FOLDER_STRUCTURE.md](../FULL_STACK_FOLDER_STRUCTURE.md).

## Recommended reading order

1. **[ARCHITECTURE.md](./ARCHITECTURE.md)**: stack choices, system diagram, folder structure, and deployment environments.
2. **[API_DATA_MODEL.md](./API_DATA_MODEL.md)**: database schema DDL, RLS policies, and Edge Function flows.
3. **[DATABASE_ERD.md](./DATABASE_ERD.md)**: visual entity relationships, indexing strategies, and migration patterns.
4. **[API_REFERENCE.md](./API_REFERENCE.md)**: endpoint definitions, Edge Function contracts, and error payloads.
5. **[INTEGRATIONS.md](./INTEGRATIONS.md)**: Claude API, market data services, RevenueCat, push notifications, and Supabase Storage.
6. **[BACKGROUND_JOBS.md](./BACKGROUND_JOBS.md)**: scheduled background tasks, rate limiting, and idempotency guarantees.
7. **[ERROR_HANDLING.md](./ERROR_HANDLING.md)**: error response format, HTTP status codes, retry logic, and logging standards.
8. **[ENVIRONMENT_VARIABLES.md](./ENVIRONMENT_VARIABLES.md)**: required environment variables and secrets by deployment stage.
9. **[SECURITY_COMPLIANCE.md](../05-ops/SECURITY_COMPLIANCE.md)**: RLS audit checklist, AI safety compliance, and incident response.
10. **[TESTING_STRATEGY.md](../05-ops/TESTING_STRATEGY.md)**: RLS verification, Edge Function tests, and test coverage targets.
11. **[DEPLOYMENT.md](../05-ops/DEPLOYMENT.md)**: CI/CD deployment pipelines, staging to production promotion, and rollbacks.
12. **[DEV_SETUP.md](../05-ops/DEV_SETUP.md)**: local development setup, running local Supabase containers, and troubleshooting.

## Technical backlog and open questions

These items require architectural decisions or additional configuration before final implementation:

| Item | Status | Reference | Next action |
|---|---|---|---|
| RevenueCat webhook receiver | Resolved | API_DATA_MODEL.md section 9, API_REFERENCE.md section 2 | Implement endpoint handler according to documented webhook contract. |
| Device tokens table for push notifications | Resolved | API_DATA_MODEL.md section 1, INTEGRATIONS.md section 4 | Table and RLS policies are incorporated into the schema. |
| AI chat request and response contract | Resolved | API_DATA_MODEL.md section 10, API_REFERENCE.md section 2 | Contract defined; finalize wire streaming format during frontend integration. |
| Price alert cooldown and deduplication state | Resolved | API_DATA_MODEL.md sections 1 and 8 | Implemented via `watchlist_items.alert_armed` and `alert_last_triggered_at`. |
| Server-side push notification category filtering | Open | INTEGRATIONS.md section 4 | Add preference flags to `device_tokens` or establish a dedicated `notification_preferences` table. |
| Direct message push dispatch mechanism | Open | API_DATA_MODEL.md section 11, INTEGRATIONS.md section 4 | Select between an Edge Function listening to database change events or a polling worker to invoke FCM/APNs. |
| Blocked user filtering in community feeds | Open | DATABASE_ERD.md section 2 | Add application-level query exclusions for blocked users on public post feeds. |
| AI chat message history table | Open | API_DATA_MODEL.md section 10 | Define message retention policies before establishing a dedicated chat history table. |
| Cache cleanup and request log retention | Open | BACKGROUND_JOBS.md section 1 | Implement scheduled cleanup routines for `ai_insights` and `ai_insight_requests`. |
| Market data vendor selection | Open | INTEGRATIONS.md section 2 | Finalize vendor choice based on rate limits and asset coverage. |
| Market data outage fallback | Open | INTEGRATIONS.md section 2 | Implement cached price fallbacks when external market APIs are unavailable. |
| Deletion policy (soft vs hard delete) | Open | API_REFERENCE.md section 1 | Decide whether to add `deleted_at` timestamps to support multi-session undo operations. |
| Enterprise data schema | Deferred | ARCHITECTURE.md section 4, ROADMAP.md | Intentionally deferred to post-MVP roadmap. |
| Global desktop search backend query | Open | UI/UX specifications | Establish a cross-table search query or PostgreSQL full text index. |

This table serves as the primary technical backlog for items requiring architectural clarification before execution.
