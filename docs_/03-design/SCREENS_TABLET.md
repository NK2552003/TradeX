# TradeX tablet screen specifications
## Layout adaptations from mobile baseline

Screen content is defined in [SCREENS_MOBILE.md](./SCREENS_MOBILE.md). This document explains how layout, navigation, and interaction patterns adapt to tablet viewports. Design tokens are documented in [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md).

**Breakpoints, as implemented** in [lib/core/flutter-ui/theme/ui_responsive.dart](../../lib/core/flutter-ui/theme/ui_responsive.dart): mobile below 600 dp, tablet 600–905 dp, desktop 905–1440 dp, large desktop 1440 dp and above. Each class also carries its own space/text/size multiplier (tablet 1.10 / 1.05 / 1.05), so a tablet is not a scaled phone screenshot — every token grows before layout is decided.

### 1. Navigation rail
- Bottom navigation bar converts to a left-hand navigation rail (80px wide with icons and text labels), visible in both portrait and landscape orientations.
- Floating action buttons are replaced by persistent action buttons docked in the top bar or navigation rail header.

### 2. Master-detail split views

Primary list-to-detail workflows switch to a two-pane layout (list occupying roughly 35% width on the left, detail occupying roughly 65% on the right):

| Module | Left pane | Right pane |
|---|---|---|
| Journal notes | 340 dp index rail (`AppWorkbenchIndex`) | Open entry document |
| Strategy notes | 340 dp playbook rail | Open playbook document |
| Watchlists | Watchlist list | Watchlist detail and symbol list |
| Community | Social feed | Post discussion detail |
| Notifications | Notification list | Associated target view in place |

**A tablet gets the desktop workbench, not a tablet-specific third layout.** The two writing destinations branch on `context.uiRes.isMobile` alone, so anything 600 dp and wider builds `AppWorkbenchLayout`. This is deliberate: a two-pane index-plus-document *is* the tablet answer, and maintaining a third arrangement between the phone's replace-and-back flow and the desktop's rail would triple the surface area for no new behaviour.

Two consequences of the shared frame on a tablet:

- **The linked-records aside never appears.** It requires 1500 dp. On a tablet the panel renders inside the document, below the body, exactly as it does on a phone.
- **The rail is a fixed 340 dp before scaling, so it is proportionally large.** At 768 dp the rail takes roughly 47% of the width. Controls inside it must tolerate that: segmented filter groups scroll horizontally rather than clip (`UiToggleGroup.scrollWhenTight`), and index rows are single-line with an ellipsis rather than wrapping.

### 3. Modal and popover presentations
Full-screen mobile sheets (trade creation, post composer, checkout) convert to centered modal dialogs with a maximum width of 600px. Bottom sheet pickers (asset selection, price alert configuration, outcome override) open as anchored popovers near the triggering element. Link pickers stay dialogs at every size above mobile — they carry a search field and a scrolling result list, which a popover cannot host comfortably.

### 4. Charts and graph views
- Portfolio Dashboard: primary stat cards arrange into a single horizontal row of four cards. Equity curve and monthly growth charts sit side by side rather than stacking vertically.
- Relational Graph View (deferred): canvas receives a permanent filter and legend sidebar on the right.

### 5. Multi-column lists
- Community feed and trader notes grid: single-column card feeds switch to a two-column grid in landscape orientation.
- Watchlist detail: ticker tables remain full width, incorporating sparkline mini-charts omitted on mobile for space.
- The journal and strategy *rails* stay single-column at every width. A two-column index defeats the point of a rail, which is a scannable vertical list beside the thing being read.

### 6. Keyboard and input support
- Hardware keyboard support: configure standard shortcuts (Command/Control + N for new records, Command/Control + F for search, Command/Control + Enter to save) across journal and community composer screens.
- Rich text toolbar: the note and playbook editor toolbars dock persistently to the top of the editor view rather than floating above the software keyboard.

### 7. Centered single-column screens
Authentication screens, user profile views, and settings pages center within a 600px width container to preserve comfortable text line lengths.

### 8. Enterprise adaptations (post-MVP)
Organization dashboard cards expand into a three-column grid. Team seat administration and API token management use the master-detail split pattern.
