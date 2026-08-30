# Screens — Desktop / Web
## Layout Adaptations from the Mobile Baseline

Screen content is defined once in [SCREENS_MOBILE.md](./SCREENS_MOBILE.md); tablet deltas are in [SCREENS_TABLET.md](./SCREENS_TABLET.md). This doc covers desktop-class breakpoints (>1200px — Flutter Web and Desktop builds per ARCHITECTURE.md). Visual tokens: [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md).

### 1. Navigation shell
- **Persistent left sidebar** (~240px, icon + label, always expanded — no rail/collapse needed at this width), replaces both the mobile bottom bar and the tablet rail
- Top bar (full-width, above content): search (global, see § 6), notification bell icon with unread-count badge, avatar menu (Profile/Settings/Log out) on the far right
- Sidebar sections mirror the 7 tabs from SCREENS_AND_FLOWS.md § 0, with Enterprise items appended at the bottom (visually separated) for org-admin accounts

### 2. Three-pane layouts (where tablet used two)
Desktop width supports a third pane in several places:

| Screen | Pane 1 | Pane 2 | Pane 3 |
|---|---|---|---|
| Journal | Filter/sort rail (collapsible) | Journal List | Journal Entry Detail |
| Strategy Notes | Category list (collapsible) | Strategy List | Strategy Detail / Editor |
| Community | Content-type filter rail | Feed | Post Detail |

Where tablet's two-pane split was list+detail, desktop adds a persistent filter/navigation rail as pane 1 rather than putting filters in a top bar or bottom sheet.

### 3. Modals → Inline dialogs, rarely full interstitials
Same dialog treatment as tablet (§ 3 there), but desktop additionally supports **inline editing** for short forms — e.g. adding a ticker to a watchlist can be an inline row-expansion rather than a popover, since there's room. Checkout remains a centered dialog/modal (Stripe's web element embeds naturally there).

### 4. Portfolio Dashboard & Graph View — full multi-column
- Headline stats: single row of 4, generous card padding
- Equity Curve, Monthly Growth, and Win/Loss Distribution charts sit in a 2-column grid (not stacked), with Strategy Performance Breakdown as a full-width table below rather than a card list
- Graph View: canvas takes the full center pane with the legend as a permanent left-docked panel (not collapsible — desktop has room) and a right-docked "node details" panel that populates on click instead of navigating away

### 5. Hover states (new on desktop — no direct mobile/tablet equivalent)
- Post cards, journal entry cards, strategy cards: hover elevates the card (subtle shadow/border highlight) and reveals secondary actions (save, quick-edit, overflow menu) that are otherwise tap-to-reveal
- Chart data points: hover tooltip (replaces mobile's tap-and-hold tooltip)
- Nav sidebar items: hover background highlight distinct from the active-state highlight

### 6. Global search (desktop-only surface)
- Top bar search expands into a command-palette-style overlay (Cmd/Ctrl+K) searching across journal entries, strategies, watchlists, tickers, and community posts at once — this doesn't exist as a unified surface on mobile/tablet, where search is scoped per-screen. Flagged as a desktop-specific addition, not a port of a mobile screen — needs its own design pass and isn't yet reflected in API_DATA_MODEL.md (would need a cross-table search query or a search index).

### 7. Keyboard shortcuts
| Shortcut | Action |
|---|---|
| Cmd/Ctrl + N | New journal entry (context-aware: new post/strategy if on that screen) |
| Cmd/Ctrl + K | Global search |
| Cmd/Ctrl + F | Filter current list |
| Cmd/Ctrl + Enter | Save current form |
| Esc | Close dialog/modal |

### 8. Screens with no meaningful change beyond width capping
Auth screens remain centered, max-width ~440px, on a full-height branded split layout (illustration/value-prop on one side, form on the other — a purely desktop-web pattern since there's horizontal room mobile/tablet don't have). Settings and Manage Subscription keep a single centered column, max-width ~700px.

### 9. Enterprise screens (post-MVP)
Org Dashboard becomes a true dashboard grid (4+ widgets across), Team Management and API Key Management use the three-pane pattern from § 2 (filter/role rail, list, detail), and Organization Analytics gains full-width multi-chart layouts comparable to Portfolio Dashboard's desktop treatment in § 4.
