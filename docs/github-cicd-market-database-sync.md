# GitHub CI/CD Pipeline for Direct Supabase Market & News Database Sync

This guide explains how the automated GitHub Actions CI/CD pipeline (`supabase-market-sync.yml`) synchronizes live market quotes, fundamentals, OHLCV price history, screeners, and financial news directly from GitHub into the live Supabase Postgres database — so the customer app (`app.alphajournal.in`, `community.alphajournal.in`) always reads fresh data from Supabase tables and never depends on bundled static assets at runtime.

---

## 1. Architecture Overview

| Component | Path | Purpose |
| :--- | :--- | :--- |
| **GitHub Actions Workflow** | `.github/workflows/supabase-market-sync.yml` | Runs automatically every 6 hours (`cron: '0 */6 * * *'`), on every push to `assets/data/**` or `scripts/sync_market_data_to_supabase.mjs`, and on manual trigger (`workflow_dispatch`). |
| **Node.js Sync Engine** | `scripts/sync_market_data_to_supabase.mjs` | Zero-dependency ESM script (Node 20 native `fetch`) that pulls live Yahoo Finance chart quotes + RSS market news (Economic Times, Moneycontrol, Yahoo Finance), merges with repository market datasets, and batch-upserts into Supabase REST API (`/rest/v1/*`). |
| **Flutter Runtime Reader** | `lib/features/market_data/data/asset_market_repository.dart` | Queries `tickers`, `stock_quotes`, `stock_fundamentals`, `stock_price_history`, `news_articles`, `news_article_tickers`, `screener_categories`, and `screener_results` directly from Supabase. |

---

## 2. Database Tables Updated by the Pipeline

1. `public.tickers` — Master symbol universe (NSE `.NS`, US Equities, Indices, Crypto, Forex, Commodities).
2. `public.stock_quotes` — Latest price, previous close, day high/low, volume, and daily change %.
3. `public.stock_fundamentals` — Sector, industry, market cap, P/E, forward P/E, P/B, ROE, dividend yield, 52-week range, and company summary.
4. `public.stock_price_history` — Daily OHLCV candle bars (`ticker, date` composite key).
5. `public.news_articles` — Financial news headlines, summaries, publisher, article links, and timestamps.
6. `public.news_article_tickers` — Join table linking news articles to related ticker symbols.
7. `public.screener_categories` & `public.screener_results` — Ranked market screeners (Top Gainers, Most Active, India Nifty 50 leaders, High Dividend, etc.).

---

## 3. Step-by-Step Setup on GitHub

### Step 1: Open Repository Actions Secrets
1. Go to your GitHub repository in the browser.
2. Click **Settings** (top navigation tab).
3. In the left sidebar, expand **Secrets and variables** -> click **Actions**.
4. Click **New repository secret** for each secret listed below.

### Step 2: Add Required GitHub Secrets

| Secret Name | Required | Value / Where to Find It |
| :--- | :--- | :--- |
| `SUPABASE_URL` | **Yes** | `https://ylxwgkhtwrizdmuhlhxs.supabase.co` (Supabase Dashboard -> Project Settings -> API -> Project URL) |
| `SUPABASE_SERVICE_ROLE_KEY` | **Recommended** | Your Supabase `service_role` secret key (Supabase Dashboard -> Project Settings -> API -> `service_role` secret). Bypasses RLS for server-side batch upserts. |
| `SUPABASE_ANON_KEY` | Fallback | Your Supabase `anon` public key (used if `SUPABASE_SERVICE_ROLE_KEY` is not set). |
| `SUPABASE_ADMIN_EMAIL` | Optional | `backend.admin@alphajournal.in` (used with `SUPABASE_ANON_KEY` to authenticate as an admin before upserting). |
| `SUPABASE_ADMIN_PASSWORD` | Optional | `BackendAdmin@2026!` |

> **Security Tip:** If you provide `SUPABASE_SERVICE_ROLE_KEY`, the script writes directly with service-role privileges and does not require `SUPABASE_ADMIN_EMAIL` or `SUPABASE_ADMIN_PASSWORD`. If you only provide `SUPABASE_ANON_KEY`, also set `SUPABASE_ADMIN_EMAIL` and `SUPABASE_ADMIN_PASSWORD` so the script authenticates as the Backend Admin first.

---

## 4. Triggering the Pipeline

### A. Automatic Scheduled Updates (Every 6 Hours)
The workflow is pre-configured with:
```yaml
on:
  schedule:
    - cron: '0 */6 * * *'
```
GitHub Actions will automatically fetch live quotes and breaking financial news every 6 hours and upsert them into Supabase.

### B. Direct Update on Git Push
Whenever you commit and push changes to:
- `assets/data/**` (e.g. adding new tickers in `assets/data/tickers/universe.json` or historical bars in `assets/data/history/*.json`)
- `scripts/sync_market_data_to_supabase.mjs`

GitHub Actions automatically runs the sync job and updates the live Supabase database within ~45 seconds.

### C. Manual One-Click Trigger (`workflow_dispatch`)
1. Open your GitHub repository -> click the **Actions** tab.
2. Select **Supabase Market & News Database Sync** in the left workflow list.
3. Click **Run workflow** (top-right button).
4. Choose:
   - **Dataset scope**: `all` (default), `quotes`, `history`, `news`, or `screeners`
   - **Fetch live quotes & RSS market news**: `true` (default) or `false`
5. Click the green **Run workflow** button.

---

## 5. Running the Sync Locally from Terminal

You can also run the exact same pipeline from your local machine at any time:

```bash
SUPABASE_URL="https://ylxwgkhtwrizdmuhlhxs.supabase.co" \
SUPABASE_ANON_KEY="<your-supabase-anon-key>" \
SUPABASE_ADMIN_EMAIL="backend.admin@alphajournal.in" \
SUPABASE_ADMIN_PASSWORD="BackendAdmin@2026!" \
node scripts/sync_market_data_to_supabase.mjs --scope=all --live=true
```
