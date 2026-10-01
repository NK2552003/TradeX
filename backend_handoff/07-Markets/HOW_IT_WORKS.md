# Market Intelligence and finance assets

The current browser uses `AssetMarketRepository` and the finance kits supplied in
`Downloads/files (1)`. Archive/member hashes are in `scripts/source_kits.json`.
`assets/data/manifest.json` is the current coverage record. A directory entry is
not a successfully fetched quote, and a quote does not imply a full detail record.
The current refresh contains 15,311 quotes and 12 full details; read the manifest
for counts after subsequent refreshes.

## Authoritative database contracts

Install `database/schema.sql` for a new database. Existing installations apply
migrations 023 and 024, then generated seeds 03 and 04. Run
`python3 scripts/validate_asset_sql.py` to check the import twice in temporary
PostgreSQL. No live database is modified by the refresh command.

- `tickers`: shared symbol registry. Keep `.NS`, index prefixes and crypto symbols.
- `stock_quotes`: latest price, previous close, range, volume, percentage and time.
- `stock_fundamentals`: optional capped fundamentals coverage.
- `stock_price_history`: OHLCV keyed by ticker/date.
- `stock_details`: full JSON contract: summary, quote, news, six-month chart,
  options, dividends/splits, recommendations, holders and availability metadata.
- `screener_categories` / `screener_results`: ranked, normalized query interface.
- `market_screener_snapshots`: complete original category payload, counts and
  export time. Join by category ID; nested index and sector data remain intact.
- Options, dividends, splits, recommendations and holders also populate their
  existing normalized tables. Export converts epoch holder dates to ISO dates.

The older `instruments`, `quotes`, `market_history` tables are compatibility
contracts for earlier work. The current asset browser uses the canonical
`tickers`/`stock_*` contracts above; do not create a second market import path.

## Frontend

Overview, News, Movers, Instruments, Screeners and Data coverage are available from the independent
Market Intelligence menu. Community's right rail includes the Yahoo top-gainer
and top-loser screens alongside its restored live space, premium, market news,
trends, suggested traders, notification prompt, disclaimer and footer sections. Rows preserve company names, native currencies and source
ranking. Sparklines use available exported history, never generated shapes.
The browser displays every exported screener category, including funds, RSI,
crypto, sector ETFs and indices by continent. Lists are paginated and search
filters loaded records. Full details load on demand; symbols without a full
snapshot use their available quote/history and show empty optional sections.

The default overview shows manifest-backed coverage counts, actual movers, and
an entry point into research. Desktop instruments and screeners use sortable,
paginated shared tables. Screener categories are grouped by asset family; row
expansion exposes all original quote fields, including RSI. Opening a dossier
and returning preserves the screener page, selection and scroll position.
Desktop dossiers organize fundamentals, news, history, options, corporate actions,
analyst research, ownership and provider availability into tabs. Mobile uses
accordions. The coverage directory includes symbols with no exported quote and
never invents a price for them. Article readers use available summaries and link
to the publisher; full article bodies are not present in the export.

`screeners.json` is a map of category name to the source kit's original shape:
Yahoo `{quotes,count,total}`, arrays for crypto/RSI, nested continent maps for
indices, and sector maps. The adapter normalizes those shapes for UI rows while
SQL preserves each original payload. Missing prices are not coerced to zero.

The shared repository caches decoded assets. Initial loading
reads aggregate files and a limited set of visible histories, not thousands of
history requests. Bundled prices are snapshots; use the quote timestamp for age.
Failed upstream sections retain prior data with `retained_fields` metadata.

If histories were omitted from a checkout but survive in an exported SQL file,
`python3 scripts/restore_asset_history.py /path/to/preserved.sql` recovers missing
files without replacing existing histories. Then rerun `export_asset_sql.py`.

## Incremental rendering

`UiDeferred` mounts off-screen sections only near the enclosing vertical viewport.
It skips non-scrollable nested lists, retains section anchors, and keeps mounted
sections available for back navigation. `UiLazyList` uses one sliver viewport and
automatically reveals records in batches of 20 near the end. Community feed/news,
Explore posts and category article lists use this component; existing table
pagination limits other market datasets. Explore previews one article per topic
and its View all action opens only that topic's lazy article list. Topics retain
the source asset grouping; uncategorized articles stay reachable in Other market
news. Market news reveals further batches on scroll and defers its image cards.
