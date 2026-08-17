# Error Handling & Observability Conventions — TraderHub

Standard error shape, HTTP status usage, and logging/observability conventions for every Edge Function. Function-specific error cases: [API_REFERENCE.md](./API_REFERENCE.md). Incident response process: [SECURITY_COMPLIANCE.md](./SECURITY_COMPLIANCE.md) § 9.

### 1. Standard error response envelope
Every Edge Function returns errors in this shape — never a bare string, never an unhandled stack trace:

```json
{
  "error": {
    "code": "rate_limit_exceeded",
    "message": "You've reached today's AI Trading Assistant limit for your plan.",
    "status": 429
  }
}
```
- `code`: a stable, machine-readable snake_case identifier — the client switches on this, not on `message`.
- `message`: human-readable, safe to show directly in the UI (see CONTENT_STYLE.md § 4 error microcopy patterns for tone — this is where that copy actually gets written into the API contract).
- `status`: mirrors the HTTP status code, included in the body too so client error handling doesn't have to separately parse headers.

### 2. HTTP status code conventions
| Status | Meaning here | Example |
|---|---|---|
| `400` | Malformed request body (missing required field, wrong type) | Missing `ticker` on `ai-insight` |
| `401` | No/invalid JWT | Expired session |
| `403` | Authenticated but not authorized for this action | Free tier hitting a Premium-gated function; non-owner editing a private strategy |
| `404` | Resource doesn't exist, **or** exists but is private and the caller isn't the owner | Deliberately conflated per CONTENT_STYLE.md § 4 — never distinguish "not found" from "not yours" in the response, to avoid leaking existence of private data |
| `413` | Payload too large | Screenshot upload over the size limit (API_REFERENCE.md § 2) |
| `422` | Well-formed request, semantically invalid | Unknown ticker symbol, invalid date range |
| `429` | Rate limit exceeded | Tier daily cap hit |
| `502` | Upstream third-party failure | Claude API or market data provider error/timeout |
| `500` | Unhandled/unexpected — should be rare, always logged | Anything not already categorized above |

### 3. Client retry guidance
| Status | Client behavior |
|---|---|
| `429` | Do not auto-retry — show the upsell interstitial (SCREENS_MOBILE.md § cross-cutting) or a "try again tomorrow" message, depending on tier |
| `502` | Safe to retry once automatically with a short backoff (1-2s); if it fails again, show the Error state (SCREENS_MOBILE.md cross-cutting) with a manual Retry button |
| `500` | Same as `502` — treat as transient unless it persists across multiple manual retries |
| `401` | Refresh the session token once; if that also fails, route to Log In (DYNAMIC_LINKING.md § 5.1 pattern — store intended destination, redirect back after re-auth) |
| `400` / `422` / `403` / `404` | Never auto-retry — these won't succeed on retry without the request itself changing |

### 4. Logging & observability
- **Sentry** (ARCHITECTURE.md § 1) captures both client crashes and Edge Function errors — every `500`/`502` response should also emit a Sentry event server-side with enough context to debug (function name, `kind`/`ticker`/relevant params) but **never** the raw request body if it could contain user journal/strategy content (privacy — SECURITY_COMPLIANCE.md § 2 data classification applies to logs too, not just the database).
- **Never log secrets** — API keys, JWTs, full Authorization headers must never appear in logs, Sentry breadcrumbs, or error messages returned to the client (SECURITY_COMPLIANCE.md § 4 already states this for the codebase generally; it applies equally to logging).
- **Structured logging:** Edge Functions should log as structured JSON (function name, `user_id` — safe to log since it's not secret and is needed for debugging, request duration, outcome) rather than free-text `console.log`, so logs are queryable later if a proper log aggregator gets added post-MVP.
- **What's not yet decided:** whether Edge Function logs live only in Supabase's built-in function logs (fine at MVP scale) or get shipped to a dedicated log aggregator — revisit alongside the "team grows past solo" trigger already noted in ENVIRONMENT_VARIABLES.md § 4.

### 5. Validation conventions
- Validate request bodies at the top of every Edge Function before any side effects (before incrementing rate-limit counters, before calling any upstream API) — a `400` for a malformed request should never consume quota or cost money.
- Prefer explicit allow-lists over blocklists where practical (e.g. `media_type` on `analyze-screenshot` should check against `['image/png', 'image/jpeg']` rather than trying to reject "bad" types).
