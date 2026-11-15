# TradeX Logging, Log Query Usage & Observability Guide

This document explains how **Supabase Logs Explorer / Log Query usage**, **Edge Function structured logs**, **Cloudflare Workers Observability**, and **persistent Postgres runtime logs** are configured across TradeX.

---

## 1. Understanding Supabase "Log Query" vs Log Ingestion

In the Supabase Organization Usage dashboard:

- **Log Query allowance** (100 GB included on the Free plan, scaling with ingested log volume) tracks the volume of log data **scanned** when you query logs via:
  - **Supabase Studio → Logs & Analytics / Logs Explorer**
  - **Supabase CLI** (`supabase logs`)
  - **Supabase Management API** (`/v1/projects/{ref}/analytics/endpoints/logs.all`)
- **"No data in period"** (`0.00 GB`) appears until at least one log query has executed against non-empty project logs. Usage metrics refresh hourly and can take **up to 24 hours** to appear in the billing/usage chart.
- Every live invocation across Postgres, Auth, Storage, API Gateway (`edge_logs`), and Edge Functions (`function_logs`, `function_edge_logs`) automatically feeds Supabase's log pipeline once traffic hits the project.

---

## 2. What Is Enabled in TradeX

### A. Supabase Local & CLI Analytics (`supabase/config.toml`)
- Enabled `[analytics] enabled = true` so local `supabase start` runs Logflare/analytics ingestion across Postgres, Auth, Storage, API gateway, and Edge Functions.
- Declared all 10 Edge Functions with explicit `verify_jwt` settings:
  - JWT-verified: `admin-delete-user`, `ai-gateway`, `ai-voice`, `ai-chat`, `note-ai-refactor`, `create-business-checkout`
  - Custom signature/secret/CORS handlers: `market-quote-proxy`, `push-dispatch`, `razorpay-webhook`, `revenuecat-webhook`

### B. Structured PII-Free Edge Function Logger (`supabase/functions/_shared/logger.ts`)
- Exports `createEdgeRequestLogger(fn, request)`, `logEdgeEvent(level, fn, event, details)`, `sanitizeLogDetails(details)`, and `describeError(error)`.
- Automatically redacts sensitive fields (`authorization`, `apikey`, `token`, `secret`, `password`, `email`, `prompt`, `message`, `messages`, `signature`, `x-razorpay-signature`, `x-push-secret`, etc.).
- Emits single-line JSON events (`ts`, `source`, `level`, `fn`, `event`, `request_id`, `method`, `path`, `status`, `duration_ms`) ingested directly into Supabase ClickHouse `function_logs`.
- Instrumented across all 10 Edge Functions:
  - `ai-gateway`, `ai-voice`, `ai-chat`, `note-ai-refactor`
  - `market-quote-proxy`, `push-dispatch`, `admin-delete-user`
  - `create-business-checkout`, `razorpay-webhook`, `revenuecat-webhook`

### C. Cloudflare Workers Logs & Traces (`wrangler.jsonc` & `worker/index.js`)
- Enabled `"observability"` in `wrangler.jsonc`:
  - `logs.enabled = true` (`head_sampling_rate: 1`)
  - `traces.enabled = true` (`head_sampling_rate: 0.1`)
- Added `logWorkerEvent(level, event, details)` in `worker/index.js` emitting structured JSON telemetry for:
  - `worker_redirect` (canonical subdomain/domain 308 redirects)
  - `worker_sitemap_served` / `worker_sitemap_blocked` (`/sitemap.xml` URL counts & latency)
  - `worker_seo_served` (`post`, `profile`, or `static` SSR metadata injection, `noindex`, and latency)

### D. Persistent Postgres Runtime Archive (`supabase/migrations/20261115133500_system_runtime_logs.sql`)
Because Supabase Free plan Logs Explorer retains logs for 1 day, `public.system_runtime_logs` provides a compact, indexed Postgres table for critical runtime records:
- Strict RLS (`admin_only_read_system_runtime_logs`): only active `user_admin` accounts (`tradex_private.is_admin()`) can `SELECT`; only `service_role` can write.
- Server-only helpers in `tradex_private`:
  - `tradex_private.write_system_runtime_log(...)`
  - `tradex_private.prune_system_runtime_logs(p_keep_days integer DEFAULT 30)`

---

## 3. Useful CLI & Logs Explorer Queries

### Query Logs via Supabase CLI
```bash
# Stream/tail remote Edge Function execution logs
supabase logs --service functions

# Stream Postgres logs
supabase logs --service postgres

# Stream API Gateway (edge_logs)
supabase logs --service edge-logs

# Stream Auth & Storage logs
supabase logs --service auth
supabase logs --service storage
```

### Ready-to-Run Supabase Studio → Logs Explorer SQL (ClickHouse)

**1. Edge Function latency, status codes & errors (last 24h)**
```sql
select
  timestamp,
  event_message,
  metadata
from function_logs
order by timestamp desc
limit 100;
```

**2. Edge Function HTTP status breakdown (`function_edge_logs`)**
```sql
select
  timestamp,
  request.method as method,
  request.url as url,
  response.status_code as status_code
from function_edge_logs
cross join unnest(metadata) as m
cross join unnest(m.request) as request
cross join unnest(m.response) as response
order by timestamp desc
limit 100;
```

**3. API Gateway + Storage Cached Egress hits (`edge_logs`)**
```sql
select
  timestamp,
  request.method as method,
  request.path as path,
  response.status_code as status_code
from edge_logs
cross join unnest(metadata) as m
cross join unnest(m.request) as request
cross join unnest(m.response) as response
where request.path like '%/storage/v1/%'
order by timestamp desc
limit 100;
```

**4. Postgres & Auth slow/error events**
```sql
select timestamp, event_message
from postgres_logs
where event_message like '%ERROR%' or event_message like '%FATAL%'
order by timestamp desc
limit 50;
```

---

## 4. Deployment Commands

```bash
# 1. Push the persistent runtime log migration (+ storage egress migration) to the linked remote DB
npx supabase db push --remote

# 2. Deploy all instrumented Edge Functions without local Docker
npx supabase functions deploy --use-api

# 3. Redeploy Cloudflare Worker with Observability logs/traces enabled
npx wrangler deploy
```

> Tip: Running 1–2 queries in **Supabase Studio → Logs Explorer** (or invoking `supabase logs --service functions` after deploying and hitting an endpoint) immediately starts scanning your project's ingested logs; the Usage dashboard updates hourly / within 24 hours.
