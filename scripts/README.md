# Finance asset pipeline

The fetchers are adapted from all four ZIPs in `Downloads/files (1)`.
`source_kits.json` records archive and member SHA-256 hashes. The scripts use
project-relative paths, so they work from any working directory.

Install `scripts/requirements.txt`, then run:

```sh
python3 scripts/refresh_loop.py --once
python3 scripts/validate_asset_sql.py
```

The full NASDAQ/NYSE/AMEX and NSE directories feed batched quotes and one-month
history. Fundamentals cover the first 300 attempted symbols and core news covers
100, matching the supplied kit's intended scale. Existing actively tracked quotes
are prioritized before the alphabetical directory. Full six-month details cover
12 symbols by default; pass symbols to `fetch_stock_detail.py` or set
`DETAIL_TICKER_LIMIT`. `MARKET_TICKER_LIMIT`, `FUNDAMENTALS_LIMIT` and
`NEWS_TICKER_LIMIT` allow bounded refreshes. Topic news and the real Yahoo screener
categories run separately, including indices, sectors, crypto and local-history
RSI. Predefined screens retain the canonical file labels (`top_gainers`, etc.).

Every refresh saves directly into `assets/data`, preserves previous quotes and
fundamentals on missing responses, and checkpoints each quote batch. Missing
stock-detail sections retain prior values and list their names in `retained_fields`.
No synthetic market results are generated. Articles merge by link while preserving
all ticker associations. JSON sanitizes non-finite numbers to null.

The final exporter rebuilds combined stock-detail/screener files and the manifest,
and generates repeatable SQL seeds for the existing canonical database schema.
The provided kits' database tables already exist in `database/schema.sql`; no
second news schema is introduced. `scripts/db.py` remains the shared adapter,
with the project's link-upsert news behavior. `KIT_DATABASE.md` is the supplied
kit's reference documentation; paths in it refer to the original distribution.

The refresh orchestrator removes `DATABASE_URL` from child processes, so this
command changes local assets and SQL files only. Applying SQL to a database is a
separate operation. Yahoo failures may retain older snapshots or leave a category
empty; inspect timestamps and refresh logs before treating bundled data as current.
