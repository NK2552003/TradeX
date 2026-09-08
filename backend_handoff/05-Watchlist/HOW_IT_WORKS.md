# 05 Watchlist

## Overview

This feature needs backend linking and RLS setup. Check the schema and RLS policies for exact details.

Watchlist manages user-created lists of symbols.
# TraderHub research workspace — frontend handoff

## Run the preview

```sh
flutter pub get
flutter run -d chrome -t lib/main_research_preview.dart
# Native desktop: replace -d chrome with -d macos.
```

The preview opens the journal without authentication. The normal signed-in app
also exposes Markets, Watchlist and News in trader navigation and the mobile
More tools menu. The preview uses the existing journal, strategy and trader-note
repositories and bundled market assets. No backend or database is required.

## Implemented interactions

- **Desktop writing:** searchable persistent library, selected record, resizable
  split, hide/show library, reading and editing, templates, existing exports,
  strategy revisions, and links. The original editors and repository contracts
  are retained.
- **Mobile writing:** card-based library followed by a focused document/editor,
  dedicated screen headings, reachable creation actions, and filters in a sheet.
  Editors measure their available pane before showing a split preview.
- **Research desk:** at 1,080 logical pixels of available workspace width, a
  resizable rail starts at 30% on the right. Its tabs are Headlines and Watchlist.
  Focus mode hides it while retaining the mounted document and editor state.
  Smaller workspaces use an inset floating research drawer. News also has a dedicated
  destination. Controls and document panes use actual available width.
- **Markets:** US/India and sector filters, company/symbol search, symbol order,
  gainers, losers, volume ordering, universe breadth, price/date/source/currency,
  previous close, daily range, OHLCV, five-bar SMA, line/candle switch, 1W/1M
  windows, company fundamentals, price-history table and CSV copy. The chart
  windows filter real available daily bars; no intraday or one-year chart is
  simulated from a month of data.
- **Watchlists:** create, rename, delete, select collections; add/remove symbols;
  reorder with “My order”; shared state across the main screen and research rail.
- **News:** search publisher/title/summary/symbol, US/India, watchlist and saved
  filters, bookmarks, publication dates, publisher summary reader, original link,
  copy URL, create a private research note including the source and ticker links.
- **Alerts:** validated target-price drafts, above/below condition, local storage,
  deletion. The UI explicitly says monitoring and notification delivery are not
  connected. No background price evaluation or order execution is claimed.
- **Linking:** the desktop formatting ribbon and mobile link control open one
  searchable picker for notes, trades, strategies and symbols. Markdown
  `tradex://` links form bidirectional graph edges, including same-kind links.
  Titles resolve dynamically by ID; removed targets remain visibly broken.
  Code examples do not create relationships. Remove a body citation in its
  source editor to remove its automatic backlink; metadata-only links retain
  the existing unlink behavior. A citation does not assign a strategy to a trade.

## Data provenance and reproducible scripts

The supplied `Downloads/finance_json_scripts 3` files were copied to
`scripts/finance/`; their original instructions are in `UPSTREAM_README.md`.
The preview builder wraps them without enabling their optional database writes.

```sh
python3 -m venv scripts/finance/.venv
scripts/finance/.venv/bin/pip install -r scripts/finance/requirements-preview.txt
# Deterministic, fully synthetic fallback fixtures:
scripts/finance/.venv/bin/python scripts/finance/build_preview.py
# Fetch a bounded six-symbol sample and replace successful fixture records:
scripts/finance/.venv/bin/python scripts/finance/build_preview.py --fetch
```

The executed fetch produced **6 Yahoo quote/history series and 13 stories**.
Five additional symbols retain synthetic quote/history/fundamental records, for
11 sample instruments in total. Consult `assets/market/manifest.json` for the
fetch report and the per-record `source` fields for provenance. News stories in
this run are fetched publisher summaries. The offline-only builder creates
explicitly labeled sample editorial briefs, with no fabricated publisher URLs.

`--fetch` runs the supplied fetcher in a temporary working directory with
`DATABASE_URL` removed, six selected symbols, capped news, and a 180-second
deadline. It does not download the whole ticker universe or start a refresh
loop. `price_as_of` comes from the last history bar, not the fetch timestamp.
The copied fetcher uses yfinance's daily adjusted close; this is not a live
quote, tick stream, exchange market-status feed or market-depth feed.

## Frontend adapter boundary

`lib/features/markets/data/market_repository.dart` defines:

```dart
abstract class MarketRepository {
  Future<MarketSnapshot> load();
  Future<List<MarketBar>> history(String symbol);
}
```

`JsonMarketRepository` loads bundled JSON by default. Point the same frontend at
an HTTP server with:

```sh
python3 -m http.server 8000 --bind 127.0.0.1 --directory assets/market
flutter run -d macos -t lib/main_research_preview.dart \
  --dart-define=MARKET_DATA_BASE_URL=http://127.0.0.1:8000
```

For a web client use a backend with CORS configured for the local development
origin. The supplied `serve_data.py` is CORS-enabled and serves its `data/`
folder; copy the generated asset JSON there if using it. A phone/emulator needs
the development machine's reachable address rather than its own localhost.

Required relative resources, matching the supplied scripts:

| Resource | Shape |
| --- | --- |
| `quotes.json` | Object keyed by ticker; price, previous_close, day_high/day_low, volume, change_pct, market, exchange, currency, updated_at; optional source and price_as_of |
| `fundamentals.json` | Object keyed by ticker; name, sector, industry, market_cap, pe_ratio, fifty_two_week_high/low, dividend_yield, source |
| `news.json` | Array of title, summary, publisher, link, related_tickers, ticker, market, published_at, source |
| `history/<encoded-symbol>.json` | Object with data array of date/open/high/low/close/volume; optional source |

Numeric nulls render as an em dash. Invalid quotes/OHLC bars are discarded.
Stories deduplicate by URL and sort by publication time. Requests time out after
12 seconds. Failure to load the main remote snapshot falls back to a complete
bundled snapshot and shows a banner. A remote history failure shows retry UI;
it never overlays synthetic history on a fetched quote. Refresh failures keep
the last successful snapshot with an error message.

For production replace `MarketRepository` through the store's constructor and
the scope instance, or serve this JSON contract. Add authenticated paginated
symbol search, scheduling, per-symbol freshness, entitlement controls and
exchange session state at the backend. The sample directory represents eleven
instruments, not the entire US/India market. Add a distinct timeframe API before
enabling intraday or longer history options. Price-alert evaluation and delivery
require a backend worker and permission-aware push/email integration.

## Persistence and linking

`MarketWorkspaceStore` stores watchlist collections, order, selected list,
bookmarks and alert drafts in device-local SharedPreferences under
`tradex.market.workspace.v1`. Writes are serialized. Local storage failures are
reported. Production storage needs authenticated user ownership, synchronization
and account separation. The preview key is not a production multi-user store.

The existing `NotesRepository`, `JournalRepository`, `StrategiesRepository` and
`AppLinkGraphService` remain the writing boundaries. Their current demo
implementations retain mutations for the app session; **new notes/journal edits
are not durable across application restart** until these repositories are
connected. The backend must preserve raw Markdown and stable record IDs. Existing
metadata relationships remain compatible with the earlier linked-notes handoff.

`AppLinkGraph` parses Markdown links into an adjacency index once per graph
snapshot. Both outbound references and inbound backlinks are merged with existing
metadata, deduplicated by kind and ID, and updated on repository stream emissions.
Links inside fenced or inline code are ignored. Searchable picker contents combine
the graph with the loaded market symbols. Ticker links navigate to Markets;
existing NSE aliases such as RELIANCE resolve to a loaded RELIANCE.NS quote.
Symbols not present in the sample show an explicit unavailable-symbol state.

## Shared components changed

- `AppWorkbenchLayout` and `AppWorkbenchIndex`: resizable libraries, focus controls,
  stable pane identity, compact filters and optional scrolling mobile headers.
- `AppWorkspaceHeading`, `AppMarketQuoteTile`, `AppNewsStoryCard`: reusable blocks
  composed from the unified libraries and design tokens.
- Journal/strategy headers use `UiHeader` so actions wrap within their actual pane.
- `UiEditorToolbar`: all formatting actions remain reachable in narrow panes.
- `UiEmptyState`: short panes can scroll instead of overflowing.
- `AppLinkedJournalCard`: ticker/side wrap inside a narrow metadata rail.
- The shell labels market data as daily snapshots instead of implying a live feed.

## Validation

```sh
flutter analyze --no-pub
flutter test --no-pub
```

Focused tests cover malformed and missing market data, remote fallback, chart
source consistency, persistent watchlists/bookmarks, same-kind backlinks,
renaming/deleted targets, code-block exclusion, news-to-note creation, and the
writing/market/watchlist layouts at 390, 768 and 1440 pixels. The local browser
preview was also inspected on desktop and phone sizes.

Final verification (7 September 2026): `flutter analyze --no-pub` reported no issues;
all 387 tests passed; `flutter build web --release -t lib/main_research_preview.dart`
succeeded and produced `build/web`. The browser check also verified mobile
news-sheet ticker navigation dismisses the sheet and opens the requested quote.


## Floating workspace layout update

- `AppShell.researchPanelBuilder` now owns the companion research panel. It sits
  beside the main header and content surface, uses approximately 30% of the
  available desktop workspace, and can be resized. The pane fills the window
  height with the same outer inset as the floating header.
- Research desk / Focus mode lives in `AppTopBar`. Compact headers use an icon
  with a tooltip. Phone and tablet open an inset floating drawer. Closing the
  desktop pane expands the header and content while keeping unsaved input mounted.
- Removed the nested workspace header and workbench title strip. Hide/show
  library controls stay with the document library.
- `UiDrawer` and `UiDialog` share elevated `UiCard` surfaces, rounded corners,
  safe-area margins, and keyboard insets. Link pickers, news readers, note filters,
  mobile selects, date ranges, AI prompts, insert menus, and document outlines
  follow this treatment.
- `research_shell_layout_test.dart` checks pane geometry, draft preservation,
  compact drawer placement, and dialog layout above the keyboard.


## Cron Jobs
- None required for core Watchlist, though backend may schedule quote updates for highly-watched symbols.
