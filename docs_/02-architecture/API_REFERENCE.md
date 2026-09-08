# TradeX API reference

This document details the backend API surface, comprising the auto-generated PostgREST endpoints and custom Supabase Edge Functions. Database schemas and row-level security policies are specified in [API_DATA_MODEL.md](./API_DATA_MODEL.md). Error formats are defined in [ERROR_HANDLING.md](./ERROR_HANDLING.md). External provider interactions are detailed in [INTEGRATIONS.md](./INTEGRATIONS.md).

Base URL: `https://<project-ref>.supabase.co`

---

## 1. Table access (PostgREST)

Every database table defined in [API_DATA_MODEL.md](./API_DATA_MODEL.md) is accessible at `/rest/v1/<table>` using standard PostgREST conventions. Row-level security operates as the sole authorization boundary:

| Method | Path | Operational notes |
|---|---|---|
| GET | `/rest/v1/journal_entries?select=*&order=created_at.desc` | RLS automatically filters results to the caller's authorized records. |
| POST | `/rest/v1/journal_entries` | Inserts a trade record. Set `user_id` from the active session context. |
| PATCH | `/rest/v1/journal_entries?id=eq.<uuid>` | Updates fields on an existing record owned by the caller. |
| DELETE | `/rest/v1/journal_entries?id=eq.<uuid>` | Permanently deletes a trade record. |

Authentication: include `Authorization: Bearer <jwt>` on all requests. Public queries (such as published strategies or public profiles) use the anonymous key and rely on `for select using (...)` security policies.

Database views: query `portfolio_stats` directly via `GET /rest/v1/portfolio_stats?user_id=eq.<uuid>`. The view inherits row-level security permissions from its underlying tables.

### Direct messaging endpoints

| Method | Path | Operational notes |
|---|---|---|
| GET | `/rest/v1/conversations?select=*&order=last_message_at.desc` | Retrieves active conversations. The client uses its local `user_id` to determine counterparty identity. |
| POST | `/rest/v1/conversations` | Initializes a conversation. Requests from Free accounts are rejected with HTTP 403 by database RLS. |
| GET | `/rest/v1/messages?conversation_id=eq.<uuid>&order=created_at.desc` | Retrieves chronological message history. |
| POST | `/rest/v1/messages` | Transmits a message, subject to tier gating checks on insert. |
| PATCH | `/rest/v1/messages?id=eq.<uuid>` | Updates `read_at` on received messages. RLS policies prevent modifying message bodies. |

Real-time delivery: the active chat interface subscribes to `messages` via Supabase Realtime filtered by `conversation_id`. Outbound push alerts and notification center entries are generated through database triggers.

---

## 2. Edge Functions

All Edge Functions run under `/functions/v1/<name>`, expect `Authorization: Bearer <jwt>` unless documented otherwise, and return standard error envelopes on failure.

### `POST /functions/v1/ai-insight`
| Parameter | Definition |
|---|---|
| Authorization | Required |
| Access tiers | Free: 0 per day; Premium and Enterprise: soft operational cap |
| Request body | `{ "ticker": string }` |
| Response (200 OK) | `{ ticker, summary, indicators, disclaimer, generated_at }` |
| Error codes | `401` Unauthorized, `429` Rate limit exceeded, `422` Unrecognized ticker, `502` Provider failure |

### `POST /functions/v1/analyze-screenshot`
| Parameter | Definition |
|---|---|
| Authorization | Required |
| Access tiers | Free: 0 per day; Premium and Enterprise: soft operational cap |
| Request body | `{ "image_base64": string, "media_type": "image/png" \| "image/jpeg" }` |
| Response (200 OK) | `{ screenshot_url, parsed: {...}, confidence }` |
| Error codes | `401` Unauthorized, `429` Rate limit exceeded, `413` Payload exceeds 10 MB, `422` Unreadable image, `502` Vision processing error |

### `POST /functions/v1/ai-strategy-review`
| Parameter | Definition |
|---|---|
| Authorization | Required (Premium and Enterprise subscribers only) |
| Request body | `{ "strategy_id": uuid }` |
| Response (200 OK) | `{ review: string, flagged_rules: [...] }` |
| Error codes | `401` Unauthorized, `403` Insufficient subscription tier, `404` Record not found, `502` Provider failure |

### `POST /functions/v1/ai-journal-analysis`
| Parameter | Definition |
|---|---|
| Authorization | Required (Premium and Enterprise subscribers only) |
| Request body | `{ "date_range": { "from": ISO8601, "to": ISO8601 }, "strategy_id": uuid \| null }` |
| Response (200 OK) | `{ patterns: { mistakes: [...], psychology_trends: [...], tag_outcome_correlations: [...] } }` |
| Error codes | `401` Unauthorized, `403` Insufficient subscription tier, `422` Invalid date bounds, `502` Provider failure |

### `POST /functions/v1/strategy-ai-summary`
| Parameter | Definition |
|---|---|
| Authorization | Required (Must own the target strategy) |
| Request body | `{ "strategy_id": uuid }` |
| Response (200 OK) | `{ ai_summary: string }` (automatically persisted to `strategies.ai_summary`) |
| Error codes | `401` Unauthorized, `403` Forbidden, `404` Record not found, `502` Provider failure |

### `POST /functions/v1/price-alerts` (Scheduled background worker)
| Parameter | Definition |
|---|---|
| Authorization | Service role only; invoked via cron schedule |
| Request body | None |
| Functionality | Evaluates alert triggers, records notification rows, and dispatches mobile push alerts |
| Monitoring | Failures log directly to Sentry |

### `POST /functions/v1/revenuecat-webhook`
| Parameter | Definition |
|---|---|
| Authorization | Verified using RevenueCat signature header against `REVENUECAT_WEBHOOK_SECRET` |
| Request body | Standard RevenueCat webhook event payload |
| Response (200 OK) | `{ "received": true }` |
| Error codes | `401` Signature mismatch, `400` Malformed payload, `500` Processing error (triggers provider retry) |

### `POST /functions/v1/ai-chat` (Premium)
| Parameter | Definition |
|---|---|
| Authorization | Required (Premium and Enterprise subscribers only) |
| Access tiers | Free: `403`; Premium: soft operational limit logged under `kind = 'chat'` |
| Request body | `{ scope: "ticker"\|"watchlist"\|"portfolio", scope_id: string, message: string, conversation_id: uuid\|null }` |
| Response | `{ conversation_id, message, disclaimer }` |
| Error codes | `401` Unauthorized, `403` Insufficient tier, `422` Invalid scope parameters, `502` Claude API failure |

---

## 3. Rate limiting enforcement

Functions verify usage limits before invoking third-party APIs:

```sql
select count(*) from ai_insight_requests
where user_id = :user_id
  and kind = :kind
  and requested_at > now() - interval '1 day';
```

If the count exceeds the subscriber's daily limit, return HTTP 429 immediately. Otherwise, invoke the external service and record a new row in `ai_insight_requests` upon successful completion.

## 4. Pagination standards

List queries use PostgREST range headers or `limit` and `offset` query parameters. Standard page sizing:
- 20 items per page for card grids and visual lists (Journal, Strategies, Community feed, and Watchlists).
- 50 items per page for dense operational lists (Notification Center and Follower lists).
