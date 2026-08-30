# API Reference — TraderHub

Full backend API surface: Supabase's auto-generated REST layer (PostgREST) for direct table access, plus every custom Edge Function. Schema/RLS source of truth: [API_DATA_MODEL.md](./API_DATA_MODEL.md) (this doc formats the same Edge Functions as a proper reference with error codes; the underlying flow/request/response bodies there are authoritative if the two ever drift). Error format conventions: [ERROR_HANDLING.md](./ERROR_HANDLING.md). Third-party calls made *by* these functions: [INTEGRATIONS.md](./INTEGRATIONS.md).

Base URL: `https://<project-ref>.supabase.co`

---

## 1. Table access (PostgREST, auto-generated)

Every table in API_DATA_MODEL.md § 1 is reachable at `/rest/v1/<table>` with standard PostgREST verbs — **RLS is the only authorization layer**, there's no separate application-level permission check. Client code (Flutter, via `supabase_flutter`) should use the SDK's query builder rather than hand-rolling REST calls, but the underlying contract is:

| Verb | Path | Notes |
|---|---|---|
| GET | `/rest/v1/journal_entries?select=*&order=created_at.desc` | RLS restricts to the caller's own rows automatically |
| POST | `/rest/v1/journal_entries` | Body = row to insert; `user_id` should be set from the authenticated session, never trusted from client input even though RLS would reject a mismatched insert anyway (defense in depth) |
| PATCH | `/rest/v1/journal_entries?id=eq.<uuid>` | Partial update |
| DELETE | `/rest/v1/journal_entries?id=eq.<uuid>` | Hard delete — no soft-delete/trash convention currently specced; flagged as a gap if "undo delete" (SCREENS_MOBILE.md toast pattern) needs to survive an app restart, since right now Undo only works if the delete hasn't been confirmed to the server yet |

**Auth header on every request:** `Authorization: Bearer <supabase JWT>`. Anonymous/public reads (public strategies, posts, profiles) use the anon key and rely entirely on the `for select using (...)` RLS policies — never a separate "public API key."

**Views:** `portfolio_stats` (API_DATA_MODEL.md § 1) is queried the same way: `GET /rest/v1/portfolio_stats?user_id=eq.<uuid>` — views inherit RLS from their underlying tables in Postgres/Supabase, so no separate policy is needed on the view itself, but verify this on first deploy (view RLS inheritance has historically had Postgres-version-dependent edge cases).

**Direct Messages (`conversations` / `messages`) — table access with a tier-gated insert:**
| Verb | Path | Notes |
|---|---|---|
| GET | `/rest/v1/conversations?select=*&order=last_message_at.desc` | Lists the caller's own conversations (participant on either side) — RLS handles the "own" filtering, but the client still needs to determine which side is "them" vs. "the other person" using its own `user_id`, since the row doesn't label which column is "me" |
| POST | `/rest/v1/conversations` | Creating a new conversation — rejected with a Postgres RLS error (surfaces as `403` at the client, per ERROR_HANDLING.md's mapping) if the caller isn't Premium/Enterprise (API_DATA_MODEL.md § 2). Client should check `subscriptionTierProvider` (STATE_MANAGEMENT.md § 8, frontend doc set) *before* attempting this, to show the upsell interstitial without a failed round-trip |
| GET | `/rest/v1/messages?conversation_id=eq.<uuid>&order=created_at.desc` | Message history for a conversation |
| POST | `/rest/v1/messages` | Send a message — same tier-gate behavior as above, checked per-message (API_DATA_MODEL.md § 2) |
| PATCH | `/rest/v1/messages?id=eq.<uuid>` | Used only to set `read_at` on received messages — the RLS policy explicitly blocks changing `content` this way (API_DATA_MODEL.md § 2) |

**Real-time:** the chat UI subscribes to `messages` via Supabase Realtime filtered by `conversation_id`, rather than polling — this is the same `StreamProvider` pattern already used for other real-time surfaces (STATE_MANAGEMENT.md § 2, frontend doc set). New-message delivery to the Notification Center and push both come from the `notify_new_message` trigger (API_DATA_MODEL.md § 11), not from this Realtime subscription — the subscription is purely for the open chat screen's live updates.

---

## 2. Edge Functions

All Edge Functions live at `/functions/v1/<name>`, require `Authorization: Bearer <JWT>` unless noted, and return the standard error envelope from ERROR_HANDLING.md § 1 on failure.

### `POST /functions/v1/ai-insight`
| | |
|---|---|
| Auth | Required |
| Tier gate | Free: 0/day; Premium/Enterprise: soft cap (API_DATA_MODEL.md § 10) |
| Request | `{ "ticker": string }` |
| Success (200) | `{ ticker, summary, indicators, disclaimer, generated_at }` |
| Errors | `401` unauthenticated · `429` tier limit exceeded · `422` unknown/invalid ticker · `502` upstream (Claude or market data) failure |

### `POST /functions/v1/analyze-screenshot`
| | |
|---|---|
| Auth | Required |
| Tier gate | Free: 0/day; Premium/Enterprise: soft cap |
| Request | `{ "image_base64": string, "media_type": "image/png" \| "image/jpeg" }` |
| Success (200) | `{ screenshot_url, parsed: {...}, confidence }` |
| Errors | `401` · `429` · `413` image too large (define a max — recommend 10MB) · `422` unreadable image · `502` upstream vision call failure |

### `POST /functions/v1/ai-strategy-review`
| | |
|---|---|
| Auth | Required, Premium/Enterprise only |
| Request | `{ "strategy_id": uuid }` |
| Success (200) | `{ review: string, flagged_rules: [...] }` |
| Errors | `401` · `403` Free tier or not the strategy owner · `404` strategy not found · `502` |

### `POST /functions/v1/ai-journal-analysis`
| | |
|---|---|
| Auth | Required, Premium/Enterprise only |
| Request | `{ "date_range": { "from": ISO8601, "to": ISO8601 }, "strategy_id": uuid \| null }` |
| Success (200) | `{ patterns: { mistakes: [...], psychology_trends: [...], tag_outcome_correlations: [...] } }` |
| Errors | `401` · `403` · `422` invalid date range (e.g. `from` after `to`) · `502` |

### `POST /functions/v1/strategy-ai-summary`
| | |
|---|---|
| Auth | Required, Premium/Enterprise only, must own the strategy |
| Request | `{ "strategy_id": uuid }` |
| Success (200) | `{ ai_summary: string }` — also persisted to `strategies.ai_summary` |
| Errors | `401` · `403` · `404` · `502` |

### `POST /functions/v1/price-alerts` (scheduled, not client-invoked)
| | |
|---|---|
| Auth | Service role only — invoked by Supabase cron, never reachable by a client JWT |
| Request | none (cron trigger) |
| Behavior | See API_DATA_MODEL.md § 8; writes to `notifications`, pushes via FCM/APNs (INTEGRATIONS.md § 4) |
| Errors | Logged to Sentry (DEPLOYMENT.md § 7), not returned to any caller |

### `POST /functions/v1/revenuecat-webhook`
| | |
|---|---|
| Auth | **Not** a client JWT — service-to-service, verified via RevenueCat's signature header against `REVENUECAT_WEBHOOK_SECRET` |
| Request | RevenueCat's standard webhook payload (`event.id`, `event.type`, `app_user_id`, etc.) |
| Success (200) | `{ "received": true }` |
| Errors | `401` bad signature · `400` malformed payload · `500` unexpected failure (RevenueCat retries on non-2xx — idempotency via `revenuecat_webhook_events` handles safe reprocessing) |
| Full event-type handling table | API_DATA_MODEL.md § 9 |

### `POST /functions/v1/ai-chat` (Premium)
| | |
|---|---|
| Auth | Required, Premium/Enterprise only |
| Tier gate | Free: `403`; Premium/Enterprise: soft cap, logged under `kind='chat'` |
| Request | `{ scope: "ticker"\|"watchlist"\|"portfolio", scope_id: string, message: string, conversation_id: uuid\|null }` |
| Success (200 or streamed) | `{ conversation_id, message, disclaimer }` — see API_DATA_MODEL.md § 10 for the streaming-format caveat (still an open implementation detail, not a contract gap) |
| Errors | `401` · `403` Free tier · `422` invalid scope/scope_id · `502` upstream Claude failure |
| Dependency note | Requires the `ai_chat_messages` table, which is flagged as not-yet-added to the schema in API_DATA_MODEL.md § 10 — pending a conversation-retention policy decision. This is the one piece of `ai-chat` still genuinely open; everything else about the endpoint is now specced. |

---

## 3. Rate limiting implementation pattern
Every tier-gated Edge Function follows the same check before doing any paid work (Claude/market-data calls):

```sql
select count(*) from ai_insight_requests
where user_id = :user_id
  and kind = :kind
  and requested_at > now() - interval '1 day';
```
Compare against the tier limit table (API_DATA_MODEL.md § 10), reject with `429` before calling any upstream API if exceeded, otherwise proceed and insert a new `ai_insight_requests` row **after** the upstream call succeeds (not before — a failed upstream call shouldn't consume the user's quota). See BACKGROUND_JOBS.md § 2 for the reasoning on soft vs. hard caps.

## 4. Pagination convention
All list-returning table queries use PostgREST's `Range` header / `limit`+`offset` query params (standard, no custom pagination scheme). Default page size: 20 for card-list screens (Journal, Strategy, Community, Watchlist), 50 for dense list screens (Notification Center, Followers/Following).
