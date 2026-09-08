# Finance Data Fetcher (US + India) — JSON + Postgres Prototype Kit

## Read this first: what's genuinely possible vs. not

| Feature | Status |
|---|---|
| Quotes, fundamentals, price history, options chains | ✅ Fully available |
| Real Yahoo screeners (most active, gainers, losers, 52-wk high/low, dividends, market cap tiers) | ✅ Fully available (`screeners.py`) |
| World indices by continent, sector ETFs, crypto movers, ETF/mutual fund lists | ✅ Fully available |
| Per-ticker news, full detail | ✅ Fully available |
| Oversold stocks (RSI-based) | ⚠️ Computed locally from tracked tickers only — no market-wide Yahoo screen exists for this |
| Pink sheet stocks | ⚠️ Included but the exchange filter needs verification against live results |
| ETF/index full holdings ("Components") | ⚠️ No reliable free source — not included |
| **News organized by Yahoo's website topics/categories** (Markets, Economy & Policy, Tariffs, etc.) | ❌ Not possible via any API — Yahoo's site renders these directly, there's no topic endpoint |
| **Conversations tab** | ❌ Not possible via any API — it's Yahoo's own comment system |
| **Videos tab** | ❌ Not possible via any API — video content isn't part of any data endpoint |
| **Private companies** | ❌ Not possible via free sources — no market data exists since they're not publicly traded |

See the relevant sections below for full detail on each.

---


Fetches stock quotes, fundamentals, 30-day price history, and news for US and
Indian market tickers using `yfinance`, and saves everything to local JSON
files — and optionally to a Postgres database with a storage-conscious
**daily-rewrite** design. Built for prototyping a frontend, and ready to plug
straight into a real backend when you're ready.

---

## What's included

| File | Purpose |
|---|---|
| `fetch_finance_data.py` | Core script — batched fetch for quotes/history (scales to 8,000+ tickers), capped fundamentals, writes JSON + Postgres |
| `fetch_ticker_lists.py` | One-time helper — downloads the full US (NASDAQ/NYSE) + India (NSE) ticker universe as CSV |
| `screeners.py` | **NEW** — real Yahoo screeners (most active, gainers, losers, 52-week high/low, dividends, market cap tiers), world indices by continent, sector ETF breakdown, crypto movers |
| `fetch_stock_detail.py` | **NEW** — full per-stock detail: summary, quote, news, chart, options chain, dividends/splits, recommendations, holders |
| `db.py` | Postgres storage layer — connection, schema creation, upserts, daily truncate |
| `schema.sql` | Table definitions (see "Database Tables" below) |
| `.env.example` | Template for your `DATABASE_URL` |
| `serve_data.py` | Tiny local HTTP server (CORS-enabled) so a frontend can `fetch()` the JSON directly |
| `refresh_loop.py` | Runs the fetcher on a loop, so data stays fresh while you develop |

**Note:** the news kit (topic-grouped news fetcher) is a separate download —
see `finance_news_kit.zip`.

---

## Setup

```bash
pip install yfinance --break-system-packages
```

For Postgres support, also install:
```bash
pip install psycopg2-binary --break-system-packages
```

(Drop `--break-system-packages` if you're using a virtual environment instead
of a system Python install.)

---

## Usage — JSON only (no database)

```bash
python fetch_finance_data.py
```
Works exactly as before if you don't set `DATABASE_URL` — writes only to
`./data/*.json`.

## Usage — JSON + Postgres

### 1. Start a local Postgres instance (Docker example)
```bash
docker run --name local-postgres \
  -e POSTGRES_PASSWORD=devpass \
  -e POSTGRES_DB=financeapp \
  -p 5432:5432 \
  -d postgres:16
```

### 2. Set your connection string
```bash
cp .env.example .env
# edit .env if your credentials differ, then:
export DATABASE_URL=postgresql://postgres:devpass@localhost:5432/financeapp
```

### 3. Run the fetcher
```bash
python fetch_finance_data.py
```
On first run, tables are created automatically from `schema.sql` — no manual
migration step needed. Every run after that:
- Writes JSON files as before (unchanged)
- Truncates and refills `stock_quotes` (see storage strategy below)
- Upserts full-detail news into `news_articles`, deduped by link — old
  articles stay until they age past 7 days, new ones are added
- Upserts `stock_fundamentals` (one row per ticker, always current)
- Appends today's row per ticker into `stock_price_history`, then deletes
  anything older than 30 days

---

## Storage strategy: daily rewrite + 7-day news window

| Table | Behavior | Why |
|---|---|---|
| `stock_quotes` | **Truncated + refilled every run** | Only the current snapshot matters — no reason to keep yesterday's price rows once today's exist |
| `news_articles` | **Rolling 7-day window** (upsert + cleanup, not truncated) | A full week of detailed news needs to persist across runs — truncating daily would lose everything but today. Deduped by article link, and anything older than 7 days is deleted automatically |
| `stock_fundamentals` | **Upserted per ticker** (no truncate) | Changes rarely (PE ratio, sector, etc.) — one row per ticker stays accurate without a wipe |
| `stock_price_history` | **Append-only, capped to 30 days** | Needed for chart/sparkline trends — a single day can't show a trend, so this table keeps a short rolling window instead of full daily wipe, but is still bounded and cleaned up automatically |

**Net effect:** `stock_quotes` never grows past "right now." `news_articles`
holds a genuine rolling week of full-detail articles, bounded and
self-cleaning rather than growing forever. `stock_price_history` stays
capped at 30 days. Nothing accumulates indefinitely.

---

## Database Tables

### `stock_quotes`
Current price snapshot, one row per ticker, rewritten every run.
| Column | Type | Notes |
|---|---|---|
| `ticker` | VARCHAR(15) PK | e.g. `AAPL`, `RELIANCE.NS` |
| `market` | VARCHAR(5) | `US` or `IN` |
| `exchange` | VARCHAR(10) | `NASDAQ`, `NYSE`, `NSE`, `BSE` |
| `currency` | VARCHAR(5) | `USD` or `INR` |
| `price` | DECIMAL | |
| `previous_close` | DECIMAL | |
| `day_high` / `day_low` | DECIMAL | |
| `volume` | BIGINT | |
| `change_pct` | DECIMAL | |
| `updated_at` | TIMESTAMPTZ | |

### `stock_fundamentals`
Company metadata, one row per ticker, upserted (not wiped).
| Column | Type | Notes |
|---|---|---|
| `ticker` | VARCHAR(15) PK | |
| `market` / `exchange` / `currency` | — | same as above |
| `name` | TEXT | full company name |
| `market_cap` | BIGINT | |
| `pe_ratio` | DECIMAL | |
| `sector` / `industry` | VARCHAR(50) | |
| `fifty_two_week_high` / `low` | DECIMAL | |
| `dividend_yield` | DECIMAL | |
| `updated_at` | TIMESTAMPTZ | |

### `stock_price_history`
One row per ticker per calendar day, rolling 30-day window.
| Column | Type | Notes |
|---|---|---|
| `id` | SERIAL PK | |
| `ticker` | VARCHAR(15) | |
| `market` / `currency` | — | |
| `date` | DATE | unique with `ticker` |
| `open` / `high` / `low` / `close` | DECIMAL | |
| `volume` | BIGINT | |
| `recorded_at` | TIMESTAMPTZ | |

### `news_articles`
Rolling 7-day window of full-detail news, deduped by link (not truncated).
| Column | Type | Notes |
|---|---|---|
| `id` | SERIAL PK | |
| `ticker` | VARCHAR(15) | nullable if general market news |
| `market` | VARCHAR(5) | |
| `title` | TEXT | |
| `summary` | TEXT | full article summary/description, not just headline |
| `link` | TEXT UNIQUE | dedupe key — re-fetching updates the existing row |
| `publisher` | VARCHAR(100) | |
| `thumbnail_url` | TEXT | article image, if available |
| `related_tickers` | JSONB | array of tickers this article relates to |
| `content_type` | VARCHAR(30) | e.g. `STORY`, `VIDEO` |
| `published_at` | TIMESTAMPTZ | |
| `fetched_at` | TIMESTAMPTZ | last time this row was updated |

Full DDL with indexes is in `schema.sql` — it runs automatically on first
script execution, but you can also run it manually:
```bash
psql $DATABASE_URL -f schema.sql
```

---

## Serving JSON to your frontend
```bash
python serve_data.py
```
Then fetch from your frontend at:
```
http://localhost:8000/quotes.json
http://localhost:8000/fundamentals.json
http://localhost:8000/news.json
http://localhost:8000/history/AAPL.json
```
CORS is already enabled, so this works from a browser-based frontend
(React, Flutter web, plain HTML/JS) without extra config. This works whether
or not you're also writing to Postgres — JSON output is unaffected.

## Keep data refreshing automatically (optional)
```bash
python refresh_loop.py
```
Re-runs the fetcher (JSON + Postgres, if configured) every 60 seconds in a
loop. Leave this running in a separate terminal while you build. Stop with
`Ctrl+C`. See "Estimated data volume" below before running this continuously
at 100 tickers.

---

## Scaling to the full market (8,000+ tickers)

The default setup (100 hardcoded tickers) doesn't scale to thousands —
fetching one ticker at a time would take hours and risk getting rate-limited.
For the full US + India universe, the fetcher switches strategy automatically
once you generate the full ticker lists:

### 1. Download the full ticker universe (one-time, or refresh monthly)
```bash
pip install requests --break-system-packages
python fetch_ticker_lists.py
```
This downloads:
- `tickers/us_tickers.csv` — NASDAQ + NYSE + AMEX (~8,000 symbols, official NASDAQ Trader data)
- `tickers/in_tickers.csv` — NSE equity list (~2,000 symbols, official NSE data)

If `fetch_finance_data.py` finds these files, it uses them automatically. If
not, it falls back to a small built-in list (6 US + 5 India tickers).

### 2. What changes at this scale
| Behavior | 100 tickers | 8,000 tickers |
|---|---|---|
| Quotes + history | One `yf.Ticker()` call per symbol | **Batched** `yf.download()` calls, 100 tickers per request |
| Fundamentals (`.info`) | Fetched for every ticker | **Capped** to the first `FUNDAMENTALS_LIMIT` tickers (default 300) — this call is slow; fetching it for all 8,000 isn't practical even as a prototype |
| News | Fetched for every ticker | **Capped** to the first `NEWS_TICKER_LIMIT` tickers (default 100) |
| Runtime | ~3–5 minutes | ~15–30 minutes (batched requests, ~80 batches at 100 tickers each) |

**Why fundamentals/news are capped:** in a real app, these should be fetched
for tickers your users actually watch — not the entire market. The cap is a
placeholder; swap `FUNDAMENTALS_LIMIT`/`NEWS_TICKER_LIMIT` for a real
watchlist query once you're past prototyping (see the "dynamic ticker
tracking" pattern in the full implementation plan).

### 3. Run it
```bash
python fetch_finance_data.py
```
Batches print progress as they go, e.g.:
```
Tracking 8143 tickers total (7982 US + 161 India)
Batch 1/82 (100 tickers)...
  batch done — 97 quotes, 100 fundamentals, 100 tickers' news so far
Batch 2/82 (100 tickers)...
  ...
```

### 4. Tuning knobs (top of `fetch_finance_data.py`)
```python
BATCH_SIZE = 100            # tickers per yf.download() call
BATCH_PAUSE_SECONDS = 2     # pause between batches
FUNDAMENTALS_LIMIT = 300    # how many tickers get full fundamentals
NEWS_TICKER_LIMIT = 100        # how many tickers get news fetched (cap for scale)
NEWS_LIMIT_PER_TICKER = 10     # articles per ticker
NEWS_RETENTION_DAYS = 7          # rolling window, not a total-count cap
```
Increasing `BATCH_SIZE` speeds things up but raises the chance of a single
request failing/timing out; decreasing `BATCH_PAUSE_SECONDS` speeds things up
but raises rate-limit risk. The defaults are a reasonable starting point —
tune based on what you observe when running it.

---

---

## Data shape reference

**`quotes.json`** (keyed by ticker):
```json
{
  "AAPL": {
    "ticker": "AAPL",
    "market": "US",
    "exchange": "US",
    "currency": "USD",
    "price": 227.5,
    "previous_close": 225.1,
    "day_high": 228.3,
    "day_low": 225.9,
    "volume": 48213000,
    "change_pct": 1.07,
    "updated_at": "2026-09-03T10:15:00Z"
  }
}
```

**`fundamentals.json`** (keyed by ticker):
```json
{
  "RELIANCE.NS": {
    "ticker": "RELIANCE.NS",
    "market": "IN",
    "exchange": "NSE",
    "currency": "INR",
    "name": "Reliance Industries Limited",
    "market_cap": 19800000000000,
    "pe_ratio": 24.3,
    "sector": "Energy",
    "industry": "Oil & Gas Refining & Marketing",
    "fifty_two_week_high": 3200.0,
    "fifty_two_week_low": 2100.0,
    "dividend_yield": 0.35,
    "updated_at": "2026-09-03T10:15:00Z"
  }
}
```

**`history/<ticker>.json`**:
```json
{
  "ticker": "AAPL",
  "market": "US",
  "currency": "USD",
  "period": "1mo",
  "interval": "1d",
  "data": [
    { "date": "2026-08-04T00:00:00", "open": 220.1, "high": 222.3, "low": 219.5, "close": 221.8, "volume": 51000000 }
  ]
}
```

**`news.json`** (flat array, newest first, rolling 7-day window):
```json
[
  {
    "ticker": "TSLA",
    "market": "US",
    "title": "Example headline",
    "summary": "Longer summary/description of the article content...",
    "link": "https://...",
    "publisher": "Reuters",
    "thumbnail_url": "https://...",
    "related_tickers": ["TSLA"],
    "content_type": "STORY",
    "published_at": "2026-09-03T09:00:00+00:00"
  }
]
```

---

## Known limitations (by design, for a prototype)

- **Fixed ticker list only** — no search/lookup for arbitrary tickers. Add
  tickers manually to the list in `fetch_finance_data.py`.
- **30-day price history only** — change `period="1mo"` in
  `fetch_history()` inside `fetch_finance_data.py` if you want more (e.g.
  `period="1y"`).
- **Data only updates when the script runs** — either rerun manually or use
  `refresh_loop.py` for continuous updates.
- **`yfinance` is an unofficial wrapper around Yahoo Finance's public
  endpoints** — no guaranteed uptime or rate limits. Fine for prototyping;
  not a licensed data feed for production use.

---

## Estimated data volume

**At 100 tickers (small/prototype scale):**
- One full run: ~4–7 MB downloaded, ~400–700 KB saved to JSON
- Continuous 60s refresh: ~6–10 GB/day (not recommended at this interval)

**At 8,000 tickers (full market scale):**
- Batched quotes + history for all 8,000: **~150–300 MB downloaded per run**
  (batched requests are far more efficient per-ticker than individual calls)
- Fundamentals capped to 300 tickers: adds ~5–10 MB
- News capped to 100 tickers: adds ~1–2 MB
- **Total per run: ~160–320 MB**, saved JSON ~10–20 MB (history files are
  the bulk of it — 8,000 small per-ticker JSON files)
- **Do not run this on a 60-second loop.** At 8,000 tickers, run it once or
  twice a day (e.g. after market close for each region) — continuous
  refresh at this scale would mean hundreds of GB/day and near-certain
  rate-limiting from Yahoo.

**Database storage at 8,000 tickers** (daily-rewrite design, see storage
strategy above): ~80–120 MB total, flat over time — see the Database Tables
section for the per-table breakdown.

---

## Market screeners, world indices, sectors, and crypto (`screeners.py`)

Real Yahoo Finance screener data — most active, gainers, losers, 52-week
highs/lows, dividends, market cap tiers — plus world indices by continent,
sector ETF performance, and crypto movers.

```bash
python screeners.py
```

Output: `data/screeners/*.json` — one file per category:
- `most_active.json`, `top_gainers.json`, `top_losers.json`
- `small_cap_stocks.json`, `undervalued_large_caps.json` (large cap proxy)
- `growth_technology_stocks.json`, `undervalued_growth_stocks.json`
- `most_shorted_stocks.json`
- `fifty_two_week_gainers.json`, `fifty_two_week_losers.json`
- `highest_dividend_stocks.json`, `most_expensive_stocks.json`
- `large_cap_stocks.json`, `small_cap_stocks_by_marketcap.json`
- `pink_sheet_stocks.json` (⚠️ exchange filter needs verification — see below)
- `oversold_stocks_by_rsi.json` (⚠️ computed locally, not a Yahoo screen — see below)
- `top_mutual_funds.json`, `top_etfs_us.json`, `top_performing_etfs.json`, `technology_etfs.json`, `bond_etfs.json`
- `world_indices_by_continent.json`
- `sector_breakdown.json`
- `crypto_all.json`, `crypto_top_gainers.json`, `crypto_top_losers.json`

### Two categories with real limitations — please read

**"Oversold stocks"** — Yahoo's screener API has no RSI/technical-indicator
field at all. There is no way to ask Yahoo "show me oversold stocks"
market-wide. Instead, this script computes 14-day RSI from price history
for tickers you've **already fetched** (via `fetch_finance_data.py`) and
flags anything below RSI 30. This only covers your tracked universe, not
the whole market — a true market-wide oversold screen isn't possible via
any free data source.

**"Pink sheet stocks"** — uses an `exchange` filter with the code `"PNK"`,
which is Yahoo's typical designation for OTC Pink stocks. I could not
verify this against live results (no network access while building this),
so **check your first run's output** — if it returns nothing or wrong
results, the exchange code may need adjusting.

---

## Full per-stock detail (`fetch_stock_detail.py`)

Pulls everything available for **one ticker at a time** into a single
combined JSON — the closest real equivalent to Yahoo's per-stock page tabs.

```bash
python fetch_stock_detail.py AAPL
python fetch_stock_detail.py AAPL MSFT RELIANCE.NS   # multiple at once
```

Output: `data/stock_detail/<TICKER>.json`, containing:
| Section | Yahoo tab equivalent | Contents |
|---|---|---|
| `summary` | Summary | Company profile, PE/PEG/EPS, 52-week range, moving averages, analyst targets |
| `quote` | (price header) | Live price, change %, volume |
| `news` | News | Up to 20 full-detail articles |
| `chart` | Chart | 6-month OHLCV history (change `period=` in the script for more/less) |
| `options` | Options | **Full options chain**, all expirations, calls + puts |
| `dividends_and_splits` | (part of Historical Data) | Full dividend and split history |
| `recommendations` | (part of Summary) | Analyst rating history |
| `holders` | (part of Summary) | Major and institutional holders |

### What's explicitly NOT included, and why
- **`conversations`** — Yahoo's comment/discussion system. Not exposed by
  any API; rendered entirely by their website's own backend. No workaround
  exists short of scraping their site directly (fragile, likely against
  their Terms of Service).
- **`components`** (full ETF/index holdings lists) — no reliable free
  source via yfinance. Some ETFs expose partial holdings via
  `yf.Ticker(t).get_funds_data()` in some yfinance versions, but it's
  inconsistent across tickers and not included here to avoid giving you
  data that silently breaks.

Both are flagged directly in the output JSON under a `"not_available"` key,
so your frontend can show an honest "not available" state instead of a
blank/broken section.

### A note on runtime for options
Options chains can be large — a liquid stock like AAPL might have 15-20
expiration dates, each with 50-100+ strikes for calls and puts. Fetching
`fetch_stock_detail.py` for many tickers at once will be slow and produce
large JSON files; this script is designed for on-demand single/few-ticker
lookups (e.g., when a user opens a specific stock's detail page in your
app), not for bulk fetching your whole tracked universe.

---


Once your frontend is built against this static/local data, the natural
next step is standing up the FastAPI + PostgreSQL backend (from the full
implementation plan) so quotes update on a live schedule and multiple
frontend clients can read from one shared source instead of each running
this script independently.
