# TradeX background jobs and scheduled tasks

This document describes recurring server routines, automated cache maintenance, and rate limiting policies. For individual endpoint specifications, see [API_REFERENCE.md](./API_REFERENCE.md).

### 1. Scheduled jobs (Supabase cron)

| Job | Schedule | Target function | Operational purpose |
|---|---|---|---|
| Price alert verification | Every 5 minutes | `price-alerts` | Evaluates `watchlist_items.price_alert_threshold` against current market feeds, records matches in `notifications`, and delivers push alerts via FCM and APNs (see INTEGRATIONS.md section 4). |
| AI insight cache cleanup | Hourly | Scheduled SQL query | Removes stale rows from `ai_insights`. Although rows older than 15 minutes are treated as expired on read, a daily sweep (`delete from ai_insights where generated_at < now() - interval '7 days'`) prevents table bloat while preserving recent diagnostic history. |
| Subscription status audit | Daily | Reconciliation job | Validates local subscription states against the RevenueCat subscriber API to catch edge cases where webhook events may have failed to process. |
| AI audit log retention | Weekly | Maintenance task | Purges `ai_insight_requests` records older than 90 days. The 24-hour rate limit calculation only requires recent logs, and 90 days provides sufficient data for cost modeling. |

Market hours configuration: once cryptocurrency and foreign exchange symbols are included, scheduling must account for continuous trading rather than traditional equity market hours (9:30 AM to 4:00 PM Eastern Time). Schedule runs continuously or branch execution logic based on asset class.

### 2. Rate limiting: Soft versus hard caps

- Free tier: strict limit of zero AI requests, enforced as specified in [API_REFERENCE.md](./API_REFERENCE.md).
- Premium and Enterprise tiers: the product advertises unrestricted AI assistance, so ordinary trading activity should not encounter artificial daily caps. To protect backend budgets against compromised keys or automated abuse (such as hundreds of requests per day from a single account), implement an administrative alert threshold. Crossing this threshold generates a notification in operational monitoring channels for manual review rather than showing an automated error to the user.
- Configure rate limit parameters as environment settings per tier rather than hardcoding values inside function code, allowing adjustments based on observed consumption metrics.

### 3. Idempotency guarantees

- RevenueCat webhooks: handlers must handle duplicate event deliveries gracefully. Use the incoming event ID with an `on conflict do nothing` statement or verify against a processed webhook log before applying changes.
- Price alert deduplication: ensure the background runner does not trigger repeated notifications on every cycle while an asset price hovers near a trigger price. Use `watchlist_items.alert_armed` and `alert_last_triggered_at` to require price reset before re-arming the alert (see API_DATA_MODEL.md section 8).
- AI Edge Functions: while repeat executions do not corrupt transactional state, deduplicate entries in `ai_insight_requests` during client retries by tracking client request identifiers or using brief debouncing windows.
