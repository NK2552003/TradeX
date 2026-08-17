# Screens — Tablet (iPad / Android tablet)
## Layout Adaptations from the Mobile Baseline

This doc does **not** repeat every field — screen content is defined once in [SCREENS_MOBILE.md](./SCREENS_MOBILE.md). It documents how layout, navigation, and interaction patterns *change* at tablet breakpoints (~768–1200px width). Visual tokens: [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md).

### 1. Navigation shell
- Bottom tab bar → **left-hand navigation rail** (icon + label, ~80px wide, always visible in portrait and landscape)
- No FAB overlapping content — "New" actions become a persistent button at the top of the rail or top bar of the active list screen

### 2. Master-detail split views
The biggest structural change: any List → Detail flow that was full-screen push-navigation on mobile becomes a **two-pane split** on tablet (list ~35% width on the left, detail ~65% on the right), so a detail screen never fully covers the list.

| Applies to | Left pane | Right pane |
|---|---|---|
| Journal | Journal List | Journal Entry Detail (or empty state: "Select an entry") |
| Strategy Notes | Strategy List | Strategy Detail (with inline Edit toggle rather than a separate full-screen editor) |
| Watchlists | Watchlist List | Watchlist Detail |
| Community | Community Feed | Post Detail |
| Notifications | Notification Center list | Deep-linked content in-place (right pane), rather than navigating away entirely |

The Strategy Editor is the one exception kept as a full-pane takeover (writing is the primary task, so it gets the whole width) — but it replaces only the *right* pane, list stays visible on the left.

### 3. Modals → Dialogs
Full-screen modals on mobile (Journal Entry Create/Edit, Create Post, Checkout) become **centered dialogs** (max-width ~600px, dimmed backdrop) rather than covering the whole screen — consistent with tablet OS conventions (iPadOS especially). Bottom sheets (Add Ticker, Price Alert Setup, outcome override) also become centered popovers anchored near the tapped element rather than sliding from the bottom edge.

### 4. Charts & Graph View
- Portfolio Dashboard: headline stat cards move from a 2×2 grid to a single row of 4; charts get meaningfully more horizontal room, so Equity Curve and Monthly Growth can sit side-by-side instead of stacked
- Graph View: canvas gets a persistent (not collapsible) legend sidebar on the right instead of a bottom-sheet legend

### 5. Multi-column lists
- Community Feed and Strategy List: single-column card list becomes a 2-column masonry/grid on landscape tablet widths, to avoid excessive whitespace either side of narrow cards
- Watchlist Detail: ticker rows stay single-column (dense tabular data reads better as one wide column with more columns of info per row — add a sparkline column that mobile omits for space)

### 6. Keyboard & input
- iPad hardware keyboard support: standard shortcuts (Cmd+N new entry, Cmd+F search/filter, Cmd+Enter save) should be wired for the Journal, Strategy Editor, and Create Post screens
- Rich text editor toolbar (Strategy Editor) becomes a persistent top toolbar instead of a keyboard-anchored bottom bar, since tablets often pair with external keyboards

### 7. Screens with no meaningful change
Auth screens (Splash, Sign Up, Log In, Forgot Password), Own Profile, Public Profile, and Settings keep the mobile single-column layout but center within a max-width (~600px) container rather than stretching edge-to-edge — avoids overly long line lengths on wide screens.

### 8. Enterprise screens (post-MVP)
Org Dashboard's 2-column quick-link grid becomes 3-column; Team Management and API Key Management adopt the same list+detail split pattern as § 2 (member/key list on the left, detail/edit on the right).
