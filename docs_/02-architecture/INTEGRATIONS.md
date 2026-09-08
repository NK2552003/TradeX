# TradeX third-party integrations

This document details external service dependencies, integration contracts, and security boundaries. Environment variables and secrets are defined in [ENVIRONMENT_VARIABLES.md](./ENVIRONMENT_VARIABLES.md). Edge Function interfaces are detailed in [API_REFERENCE.md](./API_REFERENCE.md).

---

## 1. Claude API (Anthropic)

Powers `ai-insight`, `analyze-screenshot`, `ai-strategy-review`, `ai-journal-analysis`, and `strategy-ai-summary`.

- Authentication: `ANTHROPIC_API_KEY` is configured as a server-side Edge Function secret and is never distributed in client builds.
- Model selection: assign models according to task requirements. Structured extraction (`analyze-screenshot`) runs efficiently on compact models, while open-ended analysis (`ai-journal-analysis` and `ai-strategy-review`) benefits from higher-capacity models. Specify explicit model versions in each function definition to prevent unintended behavior shifts during vendor updates.
- System prompt standards: all functions calling Claude must include explicit educational disclaimers stating that outputs do not constitute financial advice. Use a shared prompt template module to ensure uniform wording across all endpoints.
- Structured output handling: `analyze-screenshot` requests strict JSON outputs and parses responses defensively. If parsing encounters malformed data, return `{ "confidence": "low" }` with null fields rather than terminating with an unhandled exception.
- Usage tracking: every successful invocation logs a record to `ai_insight_requests`, which also acts as the source of truth for daily rate limit calculations.

## 2. Market data providers (Alpaca, Finnhub, or Twelve Data)

Supplies real-time quotes and indicators to `ai-insight`, ticker detail charts, and `price-alerts`.

- Vendor selection: evaluate vendors based on free-tier rate limits and asset coverage. The service must support equities, foreign exchange, and cryptocurrency pairs to match target user profiles.
- Authentication: `MARKET_DATA_API_KEY` is maintained exclusively within Edge Function secrets.
- Outage handling: implement a cached quote fallback showing last-known prices with timestamps when external providers experience downtime.
- Caching: the `ai_insights` table caches generated analyses for 15 minutes. The frontend charting components should maintain short-lived memory caches to prevent redundant network requests when switching tabs.

## 3. RevenueCat subscription billing

Coordinates subscription transactions and synchronizes subscription tiers with `profiles.subscription_tier`.

- Client architecture: the RevenueCat Flutter SDK coordinates purchases directly through Apple App Store, Google Play, and Stripe.
- Server webhook: `POST /functions/v1/revenuecat-webhook` processes lifecycle events, recording them in `revenuecat_webhook_events` for idempotency:
  - `INITIAL_PURCHASE`, `RENEWAL`, and `PRODUCT_CHANGE`: updates `subscriptions` and promotes `profiles.subscription_tier`.
  - `CANCELLATION`: flags the subscription as non-renewing while preserving active tier privileges until `expires_at`.
  - `EXPIRATION`: downgrades `profiles.subscription_tier` to `free`.
  - `BILLING_ISSUE`: issues a payment reminder notification without immediately revoking tier access.
- Webhook authentication: validates incoming request signatures using `REVENUECAT_WEBHOOK_SECRET` before processing payloads.
- Enterprise accounts: institutional billing uses direct contract invoicing rather than mobile in-app purchases.

## 4. Push notifications (FCM and APNs)

Delivers market alerts, direct messages, and community activity notifications.

- Token registration: devices register their FCM or APNs tokens in the `device_tokens` table on login and remove them on logout.
- Delivery lifecycle: database triggers insert records into the `notifications` table first. Push notification dispatch runs as a secondary operation, ensuring push failures never cancel database writes.
- Direct message delivery: the `notify_new_message` trigger records notifications synchronously on message insert. Outbound mobile alerts can be dispatched via Realtime database listeners or asynchronous worker functions.
- Notification filtering: check user notification preferences before dispatching push notifications to respect per-category mute settings.

## 5. Supabase Storage buckets

Stores profile avatars, community images, journal screenshots, and strategy diagrams.

| Bucket | Path format | Access model |
|---|---|---|
| `avatars` | `{user_id}/avatar.{ext}` | Public read access, owner write |
| `post-images` | `{user_id}/{postId}.{ext}` | Public read access, owner write |
| `screenshots` | `{user_id}/{uuid}.{ext}` | Private access restricted to trade author |
| `strategy-images` | `{user_id}/{strategyId}/{uuid}.{ext}` | Inherits parent strategy visibility: public for published strategies, signed URLs for private strategies |

- Private media delivery: serve private files (trade screenshots and private strategy notes) through expiring signed URLs rather than static public endpoints.
- Size enforcement: restrict file sizes to 10 MB per image at both the client layer and through storage bucket policies.
