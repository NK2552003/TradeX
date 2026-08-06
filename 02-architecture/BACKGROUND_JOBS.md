# Background Jobs & Scheduled Tasks — TraderHub

Everything that runs without a direct client request: cron jobs, cache/TTL maintenance, and the reasoning behind rate-limit design choices. Edge Function contracts: [API_REFERENCE.md](./API_REFERENCE.md).

### 1. Scheduled jobs (Supabase cron)

| Job | Schedule | Function | Purpose |
|---|---|---|---|
| Price alert check | Every 5 min, market hours only | `price-alerts` | Checks `watchlist_items.price_alert_threshold` against current prices, writes to `notifications`, pushes via FCM/APNs (INTEGRATIONS.md § 4) |
| `ai_insights` cache sweep | Hourly | none yet — **gap** | `ai_insights` rows older than the 15-min TTL (API_DATA_MODEL.md § 3) aren't actively deleted, just treated as stale on next read. Table will grow unbounded without a cleanup job. Recommend a simple `delete from ai_insights where generated_at < now() - interval '7 days'` on a daily schedule — keep a longer retention than the TTL itself in case of debugging/audit needs, but don't keep it forever |
| Subscription expiry reconciliation | Daily | none yet — **gap** | RevenueCat webhooks (INTEGRATIONS.md § 3) should keep `profiles.subscription_tier` current in real time, but a daily reconciliation job against RevenueCat's own subscriber API is good defense-in-depth in case a webhook is ever missed/fails silently |
| `ai_insight_requests` retention | Weekly | none yet — **gap** | This table is an audit/rate-limit log (API_DATA_MODEL.md § 1) and will grow indefinitely; only the last 24h matters for rate limiting (API_REFERENCE.md § 3). Recommend archiving or deleting rows older than 90 days, keeping enough history for the "watch cost profile" goal in ROADMAP.md § Ongoing without keeping everything forever |

**Market hours definition:** "market hours only" for the price-alert job needs an explicit definition once forex/crypto are in scope (PRD.md § 4) — those trade nearly 24/7, unlike equities. Don't hardcode US equity market hours (9:30am–4pm ET) into the scheduler if the ticker being checked is a crypto pair; the job needs to branch on asset class, or just run continuously for non-equity tickers. Flagged as an implementation detail to get right, not just a scheduling nicety.

### 2. Rate limiting: soft vs. hard caps
API_DATA_MODEL.md § 10 describes Premium's AI limits as "soft caps" rather than hard 429s at a fixed number, unlike Free's hard `0`. Reasoning worth preserving for whoever implements this:
- **Free tier:** hard `0` — no ambiguity, enforced exactly as API_REFERENCE.md § 3 describes.
- **Premium/Enterprise:** the PRD advertises "Unlimited AI Trading Assistant" (PRD.md § 5.9) — a hard daily cap would contradict that marketing promise. The "soft cap" pattern means: normal usage never hits a limit, but an anomalous volume (e.g. 500 calls/day from one account, clearly automated/abusive rather than a trader using the app) should still trigger a review rather than an unbounded cost exposure. Implementation approach: log everything to `ai_insight_requests` as normal, but add an alerting threshold (not a user-facing block) that notifies via Sentry/ops channel when a single user crosses an unusual volume in a day — a human reviews rather than the system auto-blocking. This preserves the "unlimited" promise while still catching abuse.
- This distinction should be implemented as configuration (a threshold value per tier), not hardcoded per-function, so the specific numbers can be tuned post-launch based on real usage (ROADMAP.md § Ongoing already flags watching Premium's cost profile).

### 3. Idempotency
- **RevenueCat webhook (INTEGRATIONS.md § 3):** must be idempotent — RevenueCat can and will redeliver the same event. Use the event's own ID (dedupe against a processed-events log or an `on conflict do nothing` upsert keyed on event ID) rather than assuming each webhook call is unique.
- **`price-alerts`:** must not re-notify for the same threshold crossing on every 5-minute run until the price moves back below/above the threshold again. This is now resolved in the schema: `watchlist_items.alert_armed` (boolean) and `alert_last_triggered_at` (timestamp) track exactly this state — see API_DATA_MODEL.md § 1 for the columns and § 8 for the arm/re-arm logic the job implements against them.
- **AI Edge Functions:** not required to be idempotent in the strict sense (a retry that re-runs `ai-insight` just costs another API call, not a data-correctness problem) but should still avoid double-logging to `ai_insight_requests` on a client-side retry of the same logical request — a request ID or short debounce window is worth considering if retries turn out to be common in practice.
