# Third-Party Integrations — TraderHub

Every external service the backend talks to, what it's used for, and the integration contract. Secrets referenced here are defined in [ENVIRONMENT_VARIABLES.md](./ENVIRONMENT_VARIABLES.md). Edge Functions that call these are specced in [API_REFERENCE.md](./API_REFERENCE.md).

---

## 1. Claude API (Anthropic)
**Used by:** `ai-insight`, `analyze-screenshot` (vision), `ai-strategy-review`, `ai-journal-analysis`, `strategy-ai-summary`, and the not-yet-built `ai-chat`.

- **Auth:** `ANTHROPIC_API_KEY`, Edge Function secret only, never in client code (SECURITY_COMPLIANCE.md § 4).
- **Model selection:** pick per cost/latency tradeoff per function — vision (`analyze-screenshot`) and structured-extraction tasks can use a smaller/faster model; open-ended analysis (`ai-journal-analysis`, `ai-strategy-review`) benefits from a stronger model. Pin exact model versions in each function's code, not a shared constant, so one function's model upgrade doesn't silently change another's cost/behavior.
- **System prompt discipline:** every prompt across all five functions must include the mandatory disclaimer instruction (SECURITY_COMPLIANCE.md § 5) — this is enforced by code review, not by the API itself, so it's worth a shared prompt-template helper rather than five independently-written system prompts that could drift.
- **Structured output:** `analyze-screenshot`'s parsed fields (API_REFERENCE.md) should request JSON-only output from Claude and validate/parse defensively — never trust the model to always return valid JSON without a parse-failure fallback path (return `confidence: "low"` with nulls rather than crashing the function).
- **Cost control:** every call is logged to `ai_insight_requests` (API_DATA_MODEL.md § 1) *after* success, which is also the mechanism used for tier rate-limiting (API_REFERENCE.md § 3). No separate cost-tracking system exists yet — `ai_insight_requests` volume is the proxy metric (ROADMAP.md § Ongoing flags watching this post-launch).

## 2. Market Data Provider (Alpaca / Finnhub / Twelve Data)
**Used by:** `ai-insight` (price/indicator data feeding the AI summary), Ticker Detail screen (chart + indicators), `price-alerts` (threshold checking).

- **Provider choice deferred to implementation** — ARCHITECTURE.md § 1 lists all three as free-tier-first options; pick one for MVP based on: (a) free-tier rate limits vs. expected `price-alerts` polling frequency (every 5 min per API_DATA_MODEL.md § 8 — multiply by expected watchlist_items volume to check this doesn't blow the free tier immediately), (b) asset-class coverage (PRD.md § 4 Target Users includes forex and crypto, not just equities — confirm the chosen provider covers all three or plan a second provider for crypto/forex specifically).
- **Auth:** `MARKET_DATA_API_KEY`, Edge Function secret only.
- **Failover:** not yet specced — if the provider has an outage, `ai-insight` and Ticker Detail currently have no fallback behavior defined beyond the generic `502` error (API_REFERENCE.md). Flagged as a gap worth closing before launch if uptime matters (a cached-data fallback showing "prices as of [last successful fetch]" would be a reasonable minimum).
- **Caching:** `ai_insights` table caches AI summaries for 15 minutes (API_DATA_MODEL.md § 3) — raw price/indicator data itself is not currently cached separately from that, meaning every cache-miss `ai-insight` call re-fetches from the market data provider. Ticker Detail screen's own chart rendering likely needs its own shorter-TTL client-side cache to avoid hammering the provider on every screen open — not yet specced, flagged for the engineer building that screen.

## 3. RevenueCat
**Used by:** subscription purchase flow (Upgrade/Checkout screen), subscription tier sync to `profiles.subscription_tier` / `subscriptions` table.

- **Client side:** RevenueCat SDK handles the actual App Store/Play/Stripe purchase flow directly from Flutter (ARCHITECTURE.md § 1) — the backend doesn't broker the purchase itself.
- **Server side — webhook:** now fully specced as `POST /functions/v1/revenuecat-webhook` — full event-type handling table, idempotency mechanism (`revenuecat_webhook_events`), and response contract in API_DATA_MODEL.md § 9 / API_REFERENCE.md § 2. Summary of event handling:
  - `INITIAL_PURCHASE` / `RENEWAL` / `PRODUCT_CHANGE` → upsert `subscriptions` row, update `profiles.subscription_tier`
  - `CANCELLATION` → mark subscription as canceling but **do not immediately downgrade** `subscription_tier` — access continues until `expires_at`
  - `EXPIRATION` → downgrade `profiles.subscription_tier` to `'free'`
  - `BILLING_ISSUE` → triggers a `subscription_reminder` notification rather than an immediate downgrade
- **Auth:** RevenueCat signs webhook payloads — verify the signature (via `REVENUECAT_WEBHOOK_SECRET`) before processing. The specific header/verification method is in RevenueCat's own docs — confirm the current mechanism at implementation time since webhook auth schemes do change; that one detail is the only part of this integration still worth double-checking against RevenueCat's live documentation rather than this spec.
- **Enterprise billing:** explicitly NOT through RevenueCat (PRD.md § 5.9) — deferred entirely to when Enterprise is built (ROADMAP.md).

## 4. Push Notifications (FCM + APNs)
**Used by:** `price-alerts`, the `notify_new_message` trigger (Direct Messages), and any other write to the `notifications` table that should also push (community updates, strategy reminders, AI recommendations — API_DATA_MODEL.md notifications table).

- **Device token management:** the `device_tokens` table is now part of the schema (API_DATA_MODEL.md § 1), with owner-only RLS — client registers/refreshes its FCM/APNs token here on login and token-rotation events, and removes it on logout.
- **Delivery pattern:** in-app `notifications` row is always written first (source of truth, drives Notification Center regardless of push delivery success); the push itself is best-effort on top — a failed push should never block or roll back the `notifications` insert.
- **Direct Messages specifically:** the `notify_new_message` Postgres trigger (API_DATA_MODEL.md § 11) writes the `notifications` row synchronously on every message insert, but — same as `price-alerts` — something still needs to watch for new `category='direct_message'` rows and actually push via FCM/APNs. This is the same open mechanism question flagged in API_DATA_MODEL.md § 11: a Realtime-triggered Edge Function vs. folding it into a short-interval scheduled job. Not yet decided.
- **Per-category opt-out:** Notification Preferences (SCREENS_MOBILE.md § 8) controls this client-side and should be checked server-side too before sending a push. **Still open:** `device_tokens` currently has no per-category preference flag — either add one there or introduce a separate `notification_preferences` table (`user_id`, `category`, `push_enabled`) before this is fully enforceable server-side. This now matters more with Direct Messages added — someone opting out of DM push notifications specifically (as opposed to muting the whole app) needs this flag to exist.

## 5. Supabase Storage
**Used by:** avatars, post images, journal screenshots, strategy embedded images, Enterprise branding logos (post-MVP).

- **Bucket structure:**
  | Bucket | Path pattern | Access |
  |---|---|---|
  | `avatars` | `{user_id}/avatar.{ext}` | Public read, owner write |
  | `post-images` | `{user_id}/{postId}.{ext}` | Public read, owner write |
  | `screenshots` | `{user_id}/{uuid}.{ext}` | **Private** — owner-only read, matches `journal_entries` privacy (SECURITY_COMPLIANCE.md § 2) |
  | `strategy-images` | `{user_id}/{strategyId}/{uuid}.{ext}` | Follows the strategy's own `visibility` — public if the strategy is public, private otherwise (needs a signed-URL approach or a storage RLS policy that joins back to `strategies.visibility`, not just a static public/private bucket flag) |
- **Signed URLs:** private buckets (`screenshots`, private-strategy images) should be served via short-lived signed URLs generated on read, not permanent public URLs — avoid the common mistake of storing a public CDN URL for content that's supposed to be private.
- **Upload size limits:** enforce client-side AND server-side (Storage bucket policy) — recommend 10MB per image, matching the `analyze-screenshot` limit in API_REFERENCE.md § 2.
