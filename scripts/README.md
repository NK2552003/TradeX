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

### Production market/news workflow

`.github/workflows/supabase-market-sync.yml` validates pull requests and the
`fix/copilot` branch without publishing. Scheduled runs (every six hours),
`main` changes, and manual live runs publish through
`scripts/sync_market_pipeline.py`. Set repository secrets `SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY`; no extra market/news API key is required.
`OPEN_AI_KEY` remains exclusively for the Dart copilot service.

The pipeline preserves the existing database fields. It fetches two years of
real daily OHLCV, authenticated Yahoo company profiles/fundamentals via
`yfinance`, fresh quotes with **provider timestamps**, ranked screeners and
Yahoo/RSS news. Existing quoted symbols are included alongside the full curated
US/India/crypto universe. No historical prices are deleted. Missing provider
values preserve stored details instead of replacing them with zero or null.

News uses the provider's best thumbnail, RSS media/enclosures, then publisher
Open Graph/Twitter images and descriptions. Original publication dates and all
reported ticker associations survive deduplication. Recent articles with missing
images are rechecked; only the previous pipeline's six generic photo placeholders
are removed. A publisher may provide no accessible image; the UI retains its
honest fallback in that case.

Scopes `all`, `quotes`, `history`, `news`, and `screeners` perform only the
selected dataset work and required dependencies. `fetch_live: false` in Actions
runs offline checks only. There is no automatic fallback to stale bundled data.
Confirmed writes, per-symbol coverage, latest dates, missing fields, publisher
coverage and failures appear in the job summary and a 30-day JSON artifact.
Provider outages and database errors fail immediately. Symbols that return an
unsupported listing or fewer than two usable daily bars are reported as
discarded and excluded from that run, preserving their previous database rows
and allowing the remaining market partition to publish. Partial successful
writes remain safe to rerun. Market publishing jobs queue rather than cancel
one another.

Read-only diagnostics (no Supabase credentials needed):

```sh
python -m pip install -r scripts/requirements.txt
python -m unittest discover -s test/scripts -p 'test_*.py' -v
python scripts/sync_market_pipeline.py --dry-run --symbols AAPL,RELIANCE.NS,BTC-USD --report /tmp/market-report.json
```

For a provider outage, inspect the artifact, then rerun the affected scope.
Retired SQ, ZOMATO.NS, LTIM.NS and TATAMOTORS.NS remain archived;
the universe fetches XYZ, ETERNAL.NS, LTM.NS and the separate TMCV.NS/TMPV.NS
listings. Historical bars are never copied across a rename or demerger. Other
delisted/renamed symbols are reported explicitly. An empty or stale feed fails coverage checks; archived records
remain available. The app loads the latest history in chronological order and
fetches sparklines for visible instruments that were not prefetched.

### Application version and update manifest

`scripts/generate_app_update_manifest.py` publishes database-free update
metadata from the canonical `version: X.Y.Z+BUILD` value in `pubspec.yaml`.
Generate only the platform that is actually being released:

```sh
python3 scripts/generate_app_update_manifest.py --platform web
python3 scripts/generate_app_update_manifest.py --platform web --check
```

Repeat `--platform android`, `ios`, `macos`, `windows`, or `linux` only after
the signed build is downloadable through its official store or release channel.
Use `--minimum-version` and `--minimum-build-number` only to retire an older
build for a documented security or compatibility requirement. The generator
rejects invalid versions, negative builds, unknown platforms, and minimum
releases newer than the published latest release.

`scripts/prepare_client_config.py` also synchronizes the web entry before a
production web build. The update manifest is a small static HTTPS asset and
must not be replaced with a Supabase query.
