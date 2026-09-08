# TradeX environment variables and secrets

Consolidated reference for environment variables and secrets across deployment tiers. For setup and continuous integration instructions, see [DEV_SETUP.md](../05-ops/DEV_SETUP.md) and [DEPLOYMENT.md](../05-ops/DEPLOYMENT.md).

### 1. Client environment variables (Flutter `.env`)

These values are bundled with the Flutter client and rely on database row-level security rather than secrecy. Keep client `.env` files out of version control.

| Variable | Example | Notes |
|---|---|---|
| `SUPABASE_URL` | `https://<project-ref>.supabase.co` | Unique per deployment tier (dev, staging, prod; see DEPLOYMENT.md section 1) |
| `SUPABASE_ANON_KEY` | `eyJ...` | Safe for public distribution when RLS policies are active on all tables |
| `REVENUECAT_API_KEY` (iOS) | `appl_...` | Public Apple platform key for RevenueCat |
| `REVENUECAT_API_KEY` (Android) | `goog_...` | Public Google Play platform key for RevenueCat |

### 2. Edge Function secrets (server-side only)

Configure these secrets using `supabase secrets set <NAME>=<value>`. Do not include these variables in client builds or application logs.

| Variable | Consumed by | Operational notes |
|---|---|---|
| `ANTHROPIC_API_KEY` | `ai-insight`, `analyze-screenshot`, `ai-strategy-review`, `ai-journal-analysis`, `strategy-ai-summary` | Powers LLM queries (see INTEGRATIONS.md section 1) |
| `MARKET_DATA_API_KEY` | `ai-insight`, `price-alerts` | Market data provider credentials (see INTEGRATIONS.md section 2) |
| `REVENUECAT_WEBHOOK_SECRET` | `revenuecat-webhook` | Validates webhook authenticity for subscription updates |
| `FCM_SERVICE_ACCOUNT_JSON` | `price-alerts` and alert dispatch functions | Service account credentials for Firebase Cloud Messaging |
| `APNS_KEY_ID` / `APNS_TEAM_ID` / `APNS_PRIVATE_KEY` | Push dispatch functions | Apple Push Notification service token authentication |

### 3. Environment matrices (dev, staging, prod)

Maintain separate Supabase projects for each environment with distinct credentials:

| Configuration | Development | Staging | Production |
|---|---|---|---|
| Supabase project | Local instance via CLI | Hosted staging project | Hosted production project |
| Anthropic API key | Low-volume developer key | Isolated staging key | Production key with budget monitoring |
| Market data | Free tier | Free tier or vendor sandbox | Production tier matching traffic volume |
| RevenueCat | Sandbox environment | Sandbox environment | Production account |
| Push credentials | Local test registration | Staging app bundle registration | Production app store bundle |

### 4. Secret rotation guidelines

If a credential appears in version control, build outputs, or server logs, rotate it immediately following the incident response guidelines in [SECURITY_COMPLIANCE.md](../05-ops/SECURITY_COMPLIANCE.md). Scheduled key rotations can be introduced post-launch as team size expands.

### 5. Open configuration items

- Webhook signature headers: confirm the latest RevenueCat signature format during webhook implementation.
- Secrets infrastructure: Supabase secret management meets current requirements. A dedicated vault solution can be evaluated if operational demands expand.
