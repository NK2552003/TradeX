# Environment Variables & Secrets — TraderHub

Single consolidated reference. DEV_SETUP.md § 3 and DEPLOYMENT.md § 4 both touch on this piece by piece; this doc is the full list in one place, per environment.

### 1. Client (Flutter `.env`)
Safe-ish to be present in the built app (scoped entirely by RLS, not secret in the traditional sense) — but still not committed to git, since project refs/keys shouldn't be casually public either.

| Variable | Example | Notes |
|---|---|---|
| `SUPABASE_URL` | `https://<project-ref>.supabase.co` | Differs per environment (dev/staging/prod — DEPLOYMENT.md § 1) |
| `SUPABASE_ANON_KEY` | `eyJ...` | Public-safe by design as long as RLS is correct everywhere (SECURITY_COMPLIANCE.md § 4) |
| `REVENUECAT_API_KEY` (iOS) | `appl_...` | Public SDK key, per-platform |
| `REVENUECAT_API_KEY` (Android) | `goog_...` | Public SDK key, per-platform |

### 2. Supabase Edge Function secrets (server-side only)
Set via `supabase secrets set <NAME>=<value>` — **never** in the Flutter `.env`, never logged (SECURITY_COMPLIANCE.md § 4).

| Variable | Used by | Notes |
|---|---|---|
| `ANTHROPIC_API_KEY` | `ai-insight`, `analyze-screenshot`, `ai-strategy-review`, `ai-journal-analysis`, `strategy-ai-summary` | INTEGRATIONS.md § 1 |
| `MARKET_DATA_API_KEY` | `ai-insight`, `price-alerts` | Provider TBD — INTEGRATIONS.md § 2 |
| `REVENUECAT_WEBHOOK_SECRET` | `revenuecat-webhook` (API_DATA_MODEL.md § 9) | Used to verify webhook signature |
| `FCM_SERVICE_ACCOUNT_JSON` | `price-alerts` and any other notification-sending function | Firebase service account credentials for server-to-FCM auth |
| `APNS_KEY_ID` / `APNS_TEAM_ID` / `APNS_PRIVATE_KEY` | Same as above, iOS push | Apple Push Notification service auth |

### 3. Per-environment values (dev / staging / prod)
Per DEPLOYMENT.md § 1: each environment is a **separate Supabase project** with its own full set of the above — never share a key across environments, even for lower-risk-looking ones like `MARKET_DATA_API_KEY`. Recommended convention: staging uses provider **sandbox/test** credentials wherever the third party offers them (RevenueCat sandbox, a market-data provider's free/dev tier) so staging load never counts against production quotas or costs.

| | dev | staging | prod |
|---|---|---|---|
| Supabase project | local (via CLI) | staging project | prod project |
| Anthropic key | dev/test key if available, else shared low-volume key | separate key from prod, watch usage separately | production key, primary cost driver to monitor |
| Market data | free tier | free tier or sandbox | paid tier once volume requires it |
| RevenueCat | sandbox | sandbox | production |
| FCM/APNs | dev-registered app | staging-registered app (separate bundle ID recommended) | prod-registered app |

### 4. Rotation policy
Tied to SECURITY_COMPLIANCE.md § 9 (Incident Response): any key that leaks (committed to git, exposed in a client build, appears in a log) gets rotated immediately, not on a schedule. Beyond incident-driven rotation, no fixed rotation cadence is currently specced — worth revisiting once the team is bigger than solo (ROADMAP.md context: solo build for MVP).

### 5. What's still missing here
- Exact RevenueCat webhook secret verification mechanism — confirm current RevenueCat documentation at implementation time (INTEGRATIONS.md § 3 flags this).
- No secrets manager beyond Supabase's built-in `secrets set` is currently planned — fine at solo/MVP scale, worth a note that this doc should be revisited if the team grows or a formal secrets manager (Doppler, Vault, etc.) gets adopted.
