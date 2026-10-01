# Unified Database Architecture — All Four Kits

This document explains how the Core, Screeners, Stock Detail, and News
kits share one database. Each kit's own README covers its specific tables
in detail — this is the map showing how they all connect.

**This schema was tested against a real, running Postgres 16 instance**
during development: all 18 tables were created successfully, every write
function in `db.py` was exercised with real data, and the foreign key /
cascade-delete behavior was verified with actual queries — not just
compiled or import-checked.

---

## The core idea: one `tickers` table, everything else links to it

```
                              ┌─────────────┐
                              │   tickers   │
                              │─────────────│
                              │ ticker (PK) │
                              │ market      │
                              │ exchange    │
                              │ currency    │
                              │ asset_type  │
                              │ name        │
                              └──────┬──────┘
                                     │ referenced by every table below
        ┌──────────────┬────────────┼────────────┬─────────────────┐
        ▼              ▼            ▼            ▼                 ▼
  stock_quotes   stock_fundamentals  │      screener_results   news_article_tickers
  (Core Kit)     (Core Kit)          │      (Screeners Kit)    (Core/News Kit)
                                     │
                          stock_price_history
                             (Core Kit)
        ┌──────────────┬────────────┬────────────┬─────────────────┐
        ▼              ▼            ▼            ▼                 ▼
  options_expirations dividends  stock_splits  analyst_        holders
  (Stock Detail Kit)  (Stock     (Stock        recommendations (Stock
        │             Detail)    Detail)       (Stock Detail)  Detail)
        ▼
  options_contracts
  (Stock Detail Kit)
```

Every table that describes "something about a ticker" has a foreign key
back to `tickers.ticker`. No kit repeats `market`/`exchange`/`currency`
columns independently — that data lives once, in `tickers`, and everything
else references it.

**Why this matters in practice:**
- Run all four kits against the same `DATABASE_URL`, and a ticker fetched
  by one kit is immediately visible to queries involving another kit's
  tables — no manual reconciliation needed.
- Deleting a ticker from `tickers` cascades and removes all its dependent
  rows automatically (quotes, history, options, news links, etc.) — tested
  directly: deleting a ticker with a news-article link correctly removed
  the join-table row.
- Every fetch script calls `upsert_ticker()` (directly or indirectly via
  `upsert_quote()`, `insert_news_article()`, etc.) before writing anything
  that references that ticker, so the foreign key is always satisfied.

---

## The 18 tables, grouped by kit

| Kit | Tables it owns |
|---|---|
| **Core Kit** | `stock_quotes`, `stock_fundamentals`, `stock_price_history` |
| **Screeners Kit** | `screener_categories`, `screener_results`, `index_metadata`, `sector_metadata` |
| **Stock Detail Kit** | `options_expirations`, `options_contracts`, `dividends`, `stock_splits`, `analyst_recommendations`, `holders` |
| **News Kit** (shared with Core Kit) | `news_articles`, `news_article_tickers`, `news_topics`, `news_article_topics` |
| **Shared by all** | `tickers` |

The Core Kit and News Kit **both** write to `news_articles` — a ticker's
news fetched via the Core Kit's batch process and a topic-grouped fetch via
the News Kit land in the same table, deduped by article link, rather than
creating two separate copies of the same story.

---

## Two-table pattern used for many-to-many relationships

Instead of a flat `ticker` column on `news_articles` (which would only
allow one ticker per article), the schema uses a proper join table:

```sql
news_articles (id, title, link, ...)
news_article_tickers (article_id → news_articles.id, ticker → tickers.ticker)
```

One article about "the Magnificent Seven" can link to all 7 tickers at
once. The same pattern is used for `news_article_topics` (an article can
belong to multiple of the News Kit's topic buckets) and
`screener_results` → `screener_categories` (a ticker can appear in
multiple screener categories, e.g. both "most active" and "top gainers"
the same day).

---

## Setup (once, shared across all four kits)

```bash
docker run --name local-postgres \
  -e POSTGRES_PASSWORD=devpass -e POSTGRES_DB=financeapp \
  -p 5432:5432 -d postgres:16

export DATABASE_URL=postgresql://postgres:devpass@localhost:5432/financeapp
```

Every kit's script calls `init_schema()` automatically on first run, which
executes the full `schema.sql` (all 18 tables) — it's idempotent
(`CREATE TABLE IF NOT EXISTS`), so running it from multiple kits is safe
and only needs to happen once in practice.

Run the kits in any order — there's no strict dependency, except:
- **Screeners Kit's "oversold stocks"** reads price history JSON files
  produced by the **Core Kit**, so run the Core Kit first if you want that
  specific category populated.
- Everything else works independently, whichever order you run the kits in.

---

## Verifying it worked

```sql
-- See every ticker any kit has touched
SELECT ticker, market, asset_type FROM tickers ORDER BY ticker;

-- See a ticker's full picture across kits
SELECT
  t.ticker, t.name,
  q.price, q.change_pct,
  f.pe_ratio, f.sector,
  (SELECT COUNT(*) FROM news_article_tickers nat WHERE nat.ticker = t.ticker) AS news_count,
  (SELECT COUNT(*) FROM options_expirations oe WHERE oe.ticker = t.ticker) AS options_expirations_count
FROM tickers t
LEFT JOIN stock_quotes q ON q.ticker = t.ticker
LEFT JOIN stock_fundamentals f ON f.ticker = t.ticker
WHERE t.ticker = 'AAPL';
```
