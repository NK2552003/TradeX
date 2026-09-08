# TradeX desktop and web screen specifications
## Layout adaptations from mobile baseline

Screen content is detailed in [SCREENS_MOBILE.md](./SCREENS_MOBILE.md), and tablet adaptations are in [SCREENS_TABLET.md](./SCREENS_TABLET.md). This document covers Flutter desktop and web targets. Design tokens are documented in [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md).

**Breakpoints, as implemented:** the `desktop` device class starts at **905 dp**, and `largeDesktop` at 1440 dp — not 1200. Layout decisions in this document that need real width say so explicitly (the workbench aside needs 1500 dp) rather than assuming "desktop" means "wide".

### 1. Navigation shell
- Persistent left navigation sidebar (240px fixed width, icon with text labels, permanently expanded), replacing both the mobile navigation bar and tablet navigation rail.
- Top application bar: global search launcher, notification center bell with unread badge, and user profile menu (profile, settings, sign out) aligned to the right.
- Navigation sections mirror primary application tabs, with enterprise administration tools docked at the bottom of the sidebar for organization administrators.
- The shell swaps one destination widget per sidebar id; it does not push routes. See [NAVIGATION_ROUTING.md](../04-frontend/NAVIGATION_ROUTING.md#1-what-ships-today-one-shell-one-selected-id).

### 2. The workbench: journal notes and strategy notes

Both writing destinations use one shared frame, `AppWorkbenchLayout` in [lib/core/app-ui/blocks/workbench_blocks.dart](../../lib/core/app-ui/blocks/workbench_blocks.dart). Screens supply an index and a document and cannot choose their own arrangement — that is what keeps the journal and the playbook library reading like one application rather than two features by two authors.

| Column | Width | Journal | Strategy notes |
|---|---|---|---|
| Index rail | 340 dp, fixed | Entry list: search, status and outcome filters, sort, then the scrolling list | Playbook list: search, status filter (draft / testing / live / retired), sort |
| Document | Fills remaining | The open entry: header, numbers, story, attachments, linked records | The open playbook: header, performance, rules, linked records |
| Linked records aside | 320 dp | `AppLinkedRecordsPanel` for the open entry | `AppLinkedRecordsPanel` for the open playbook |

Three specifics that are decisions, not incidental:

- **The aside appears only at 1500 dp and above.** Below that, three columns squeeze the document until a markdown body wraps every few words, so the panel moves back inside the document instead. `showAside` alone does not force it.
- **The rail header and filters do not scroll.** `AppWorkbenchIndex` pins them above the list, so a search field a trader is typing into does not slide out from under the cursor.
- **A hosted document drops its own chrome.** `AppWorkbenchScope` marks the subtree; documents read it and omit the page header and back button they would draw on a phone. Two headers and a back button that goes nowhere is the failure this prevents.

The rail is where records are *created* on desktop: a "New entry" / "New playbook" action sits in the rail header (`journal_new_entry_rail`, `strategy_new_rail`), not in a floating action button. The phone uses a FAB instead; the two never coexist, and the widget tests assert the absence of the other.

Trader notes keep their own shape — a card grid, then a full-width reader or editor with a details rail — because a note has no natural index ordering to keep on screen the way a dated trade log does.

### 3. Three-pane layouts elsewhere

| Screen | Pane 1 (Left rail) | Pane 2 (Center) | Pane 3 (Right) |
|---|---|---|---|
| Community | Content classification rail | Social feed | Post discussion detail |
| Watchlists | Watchlist selector | Instrument table | Instrument detail |

Where tablet viewports use a two-pane list and detail split, desktop layouts introduce a permanent left filter rail to keep filtering options accessible without opening modal dialogs.

### 4. Modals and inline editing
Desktop layouts favor inline interactions for brief forms. For example, adding an asset to a watchlist expands an inline row rather than opening a popover. Complex workflows (such as plan upgrades and payment checkout) remain centered modal dialogs.

Link pickers are the exception worth naming: attaching a trade to a playbook opens a searchable dialog rather than an inline row, because the candidate list is the whole workspace filtered by `AppLinkGraph.options(kind, exclude:, query:)` and needs room to show a title, a subtitle and a figure per row.

### 5. Portfolio dashboard and graph view: Multi-column layouts
- Primary metrics: single horizontal row of four metric cards.
- Analytics charts: equity curve, monthly performance, and win/loss breakdown organize into a two-column grid, followed by the strategy performance table spanning full width below.
- Relational Graph View (deferred, see [DYNAMIC_LINKING.md](./DYNAMIC_LINKING.md) section 8): canvas fills the center pane, with filter controls docked permanently on the left and selected node details opening in an anchored right-hand inspector.

### 6. Desktop hover interactions
- Card rows: hovering over trade records, posts, or strategies elevates the card slightly and reveals secondary actions (quick edit, bookmark, and options menu).
- Index rail rows: hover shows the row's surface-hover fill; the selected row keeps a distinct filled state so hover never reads as selection.
- Link tiles: hover underlines the title and reveals the destination icon, so a reader can tell a cross-destination link from a plain chip before clicking it.
- Chart tooltips: hovering displays detailed price, date, and performance data points, replacing mobile long-press gestures.
- Sidebar items: hover backgrounds provide visual feedback distinct from selected route states.

### 7. Command palette search
The top navigation search input opens a unified command palette (Command or Control + K) that queries across trade records, strategies, notes, watchlists, and community posts. Results are grouped by record kind and open through the same `AppLinkRef` path as any in-document link, so the palette needs no navigation logic of its own.

### 8. Keyboard shortcuts

| Shortcut | Action |
|---|---|
| Cmd/Ctrl + N | New record in the current destination (journal entry, playbook, note, or post) |
| Cmd/Ctrl + K | Open command palette search |
| Cmd/Ctrl + F | Focus search and filter controls (the rail's search field on a workbench) |
| Cmd/Ctrl + Enter | Save current form or entry |
| Escape | Dismiss active modal or overlay |

### 9. Narrow desktop windows
A 1200 dp window is not a wide one. The index rail is a fixed 340 dp, and controls inside it must survive that: a five-segment status filter needs roughly 423 px and will clip. `UiToggleGroup.scrollWhenTight` makes segmented groups scroll horizontally once their box is genuinely too small, and it is a question about the box, not the screen — see [COMPONENT_LIBRARY.md](../04-frontend/COMPONENT_LIBRARY.md).

### 10. Centered single-column views
Authentication screens use a split layout with brand artwork on the left and form inputs on the right (maximum width 440px). Account settings and subscription management center within a single column with a maximum width of 700px.

### 11. Enterprise views (post-MVP)
Organization management dashboards expand into four-column widget grids. Team seat administration and API key consoles use the three-pane pattern, and workspace analytics use full-width multi-chart reports.
