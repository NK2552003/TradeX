# TradeX error handling and observability

Standard error response envelope, HTTP status code conventions, and observability guidelines for Supabase Edge Functions. Endpoint-specific error definitions are in [API_REFERENCE.md](./API_REFERENCE.md). Incident response steps are in [SECURITY_COMPLIANCE.md](../05-ops/SECURITY_COMPLIANCE.md).

### 1. Error response envelope

Edge Functions return errors in a consistent JSON structure, avoiding raw strings and unhandled stack traces:

```json
{
  "error": {
    "code": "rate_limit_exceeded",
    "message": "You've reached today's AI Trading Assistant limit for your plan.",
    "status": 429
  }
}
```

- `code`: stable, snake_case identifier used for client logic branching.
- `message`: human-readable description appropriate for UI display (see CONTENT_STYLE.md section 4).
- `status`: mirrors the HTTP status code, enabling client error handlers to inspect status directly from the body.

### 2. HTTP status code conventions

| Status | Usage in TradeX | Example |
|---|---|---|
| `400` | Malformed request body (missing required field, incorrect data type) | Missing `ticker` field on `ai-insight` |
| `401` | Missing or invalid authentication token | Expired session token |
| `403` | Authenticated account lacks authorization | Free tier calling Premium-only functions |
| `404` | Record does not exist, or exists privately for another user | Returning 404 for private strategies prevents confirming existence |
| `413` | Upload payload exceeds size limits | Screenshot upload over 10 MB limit |
| `422` | Request is well-formed but semantically invalid | Unrecognized ticker symbol or invalid date range |
| `429` | Rate limit exceeded | Daily AI request quota reached |
| `502` | Upstream provider error or timeout | Claude API or market data service failure |
| `500` | Unexpected server failure | Unhandled exceptions; logged automatically |

### 3. Client retry guidance

| Status | Recommended client behavior |
|---|---|
| `429` | Do not retry automatically. Display an upgrade prompt or daily limit notice based on the user's tier. |
| `502` | Retry once automatically after a 1 to 2 second backoff. If it fails again, display an error view with a manual retry button. |
| `500` | Treat as transient on first occurrence; present a manual retry option. |
| `401` | Refresh the session token once. If refresh fails, redirect to the login screen and preserve the intended target route. |
| `400`, `422`, `403`, `404` | Do not retry automatically; the request parameters require client adjustment. |

### 4. Logging and monitoring

- Error tracking with Sentry: captures client exceptions and Edge Function failures. Edge Functions should report `500` and `502` errors with diagnostic context (function name, symbol, request ID), while strictly excluding private journal notes or personal user entries.
- Credential protection: never log API keys, access tokens, or Authorization headers in application logs or monitoring breadcrumbs.
- Structured logging: write function output as structured JSON (function name, `user_id`, execution duration, and outcome status) to enable structured filtering.
- Log aggregation: native Supabase function logging is sufficient for MVP scale. Third-party log aggregators can be connected post-launch if team operations expand.

### 5. Input validation standards

- Validate input parameters at the top of every Edge Function before executing database queries or external API calls. Malformed requests (HTTP 400) should never consume rate limit quota or incur API costs.
- Prefer explicit allowlists over blocklists (such as checking `media_type` against `['image/png', 'image/jpeg']`).
