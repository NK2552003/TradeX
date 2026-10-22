# Frontend Layout & Responsive Breakpoint Defects

**Target Audience:** Frontend Engineers  
**Scope:** Mobile & Desktop Viewports, Landscape/Portrait Transitions, Keyboard Insets, Gesture Conflicts, and Touch Targets (WCAG 2.1 AA)  
**Date:** 2026-10-21  

---

## 1. Executive Summary & Responsive Grid Deficiencies

TradeX is designed as a universal financial terminal running on Web, macOS/Windows Desktop, Tablets (iPad, Android), and Mobile phones. While the visual aesthetic is high quality, the application suffers from multiple **viewport overflow crashes, double-dock rendering on mobile screens, keyboard inset calculation errors, and touch target accessibility violations**.

---

## 2. Comprehensive Layout Defect Breakdown

### 2.1. Landscape Overflow on Mobile Onboarding
- **Location:** `lib/features/auth/presentation/pages/get_started_page.dart` (Lines 80–125).
- **Defect:** `_buildMobileView` places the brand logo, hero typography, feature pill carousel, social proof badges, and CTAs inside a rigid vertical `Column`.
- **Failure:** When a mobile user rotates their device to landscape (height ~390px) or on devices with display scaling set to "Large", the bottom actions overflow the viewport bounds:
  ```
  A RenderFlex overflowed by 114 pixels on the bottom.
  ```
- **Remediation:** Wrap the root body of `_buildMobileView` in a `SingleChildScrollView` with `ClampingScrollPhysics`.

---

### 2.2. Double Mobile Bottom Navigation Bar Rendering
- **Locations:** `lib/core/widgets/app_scaffold.dart` (Lines 1100–1150) and `lib/features/community/presentation/community_root_screen.dart` (Lines 220–260).
- **Defect:**
  - `AppScaffold` renders a bottom navigation dock (`AppScaffoldDock`) on mobile viewports (`width < 640px`).
  - When the user selects Community, `CommunityRootScreen` renders its own bottom-anchored tab bar (`UiTabBar` with Feed, Explore, Audio Spaces, Bookmarks).
- **Failure:** On mobile phones, two stacked bottom navigation bars render simultaneously. This consumes **over 140px of vertical screen real estate**, pushing post composers and trade cards offscreen and breaking the visual hierarchy.
- **Remediation:** Remove the bottom tab bar in `CommunityRootScreen` when running inside `AppScaffold`. Move community sub-tabs into a top `SliverPersistentHeader` or top tab navigation bar.

---

### 2.3. Keyboard Occlusion & Double-Inset Bug
- **Location:** `lib/features/notes/ui/note_editor_screen.dart` (Lines 1300–1370).
- **Code Trace:**
  ```dart
  final double inset = MediaQuery.viewInsetsOf(context).bottom;
  final double safeBottom = MediaQuery.paddingOf(context).bottom;
  final double baseBottom = inset > 0 ? inset : safeBottom;
  final double gutter = context.sp(theme.spacing.md);
  final double toolbarClearance = wide || !editing ? 0 : context.sz(64);

  Positioned(
    left: 0,
    right: 0,
    bottom: baseBottom + gutter,
    child: MarkdownEditorToolbar(...),
  )
  ```
- **Failure Mechanics:**
  1. The enclosing `Scaffold` already has `resizeToAvoidBottomInset: true`, which shrinks the viewport by `inset` when the virtual keyboard opens.
  2. The `Stack` is placed inside this reduced viewport, and `Positioned(bottom: baseBottom + gutter)` shifts the toolbar upwards by `inset` a **second time**.
  3. Result: The toolbar floats in the middle of the screen (approx. 200–250px above the virtual keyboard), covering the text cursor.
  4. When `MarkdownSlashPalette` opens, it gets pushed completely off the top of the mobile screen.
- **Remediation:** In `NoteEditorScreen`, pass `resizeToAvoidBottomInset: false` to the enclosing Scaffold or adjust `bottom: safeBottom + gutter` when `inset > 0`.

---

### 2.4. Spreadsheet Table Squishing on Mobile Journal
- **Location:** `lib/features/journal/ui/journal_screen.dart` (Lines 1500–1560).
- **Defect:** In `_JournalTableView`, trade records are rendered as a fixed-column data table (Date, Symbol, Type, Quantity, Entry Price, Exit Price, Net P&L, Status, Strategy).
- **Failure:** On mobile viewports (<600px), all 9 columns are forced into a single non-scrollable row. Text strings wrap aggressively (`N I F T Y`, `B U Y`), numeric figures clip, and P&L badges are completely squished into illegible vertical strips.
- **Remediation:** Implement responsive layout switching: on mobile devices (`width < 600px`), display trade records as vertical card tiles (`UiCard`); reserve multi-column spreadsheet tables for tablet/desktop viewports (`width >= 600px`) with horizontal scrollbars.

---

### 2.5. Split Mode Layout Compression on Portrait Tablets
- **Location:** `lib/features/strategies/ui/strategy_editor_screen.dart` (Lines 45–55).
- **Defect:** In `Split` mode, the strategy editor forces markdown writing and preview panes side-by-side in a horizontal `Row`.
- **Failure:** On devices with width < 840px (portrait iPad, foldable devices, or mobile landscape), each pane receives < 380px. Code blocks, parameter tables, and checklist items clip horizontally, and toolbar buttons wrap over the text editing area.
- **Remediation:** Automatically disable `Split` mode when `constraints.maxWidth < 840px` or `context.uiRes.isMobile`, defaulting to tabbed `Write` or `Read` modes.

---

### 2.6. Touch Target Accessibility Violations (WCAG 2.1 AA)
- **Affected Surfaces:**
  - `lib/features/community/presentation/widgets/community_author_header.dart` (Lines 250–265): Mute/Report dropdown trigger measures **28 × 28 px**.
  - `lib/features/market_data/presentation/market_movers_panel.dart` (Lines 80–120): Ticker chip pills measure **32 × 24 px**.
  - `lib/features/calculators/ui/calculators_screen.dart` (Lines 120–160): Quick clear buttons measure **26 × 26 px**.
- **Violation:** WCAG 2.1 Success Criterion 2.5.5 (Target Size) and Apple/Android Human Interface Guidelines mandate a minimum tap target size of **48 × 48 px** (or 44 × 44 pt).
- **User Impact:** Mobile traders experience high rates of missed taps and accidental clicks on neighboring controls.
- **Remediation:** Wrap compact buttons in `UiIconButton` with minimum visual touch target padding or enforce `constraints: BoxConstraints(minWidth: 48, minHeight: 48)`.

---

### 2.7. Chart Gesture Collision with Mobile OS Back Navigation
- **Location:** `lib/features/market_data/presentation/market_instrument_view.dart` (Lines 250–310).
- **Defect:** The interactive candlestick chart attaches an unconstrained `HorizontalDragGestureRecognizer` across the entire width of the card.
- **Failure:** On Android 10+ and iOS, users attempting to swipe from the left screen edge to navigate back have their gesture captured by the chart's candle panning controller, trapping them on the detail screen.
- **Remediation:** Add 16px edge padding where chart gestures are disabled, or require two-finger gestures to pan charts horizontally on touch devices.

---

### 2.8. Mobile Message Composer Safe Area Inset Collision
- **Location:** `lib/features/messages/presentation/widgets/message_composer.dart` (Lines 20–60).
- **Defect:** The message composer lacks `SafeArea(bottom: true)`. When the virtual keyboard dismisses on gesture-based mobile devices (iPhone X–16, modern Android), the send button and input field are partially obscured by the home indicator bar.
- **Remediation:** Wrap composer in `SafeArea(top: false, child: ...)`.

---

### 2.9. Desktop Carousel Card Overlap on Intermediate Tablet Breakpoints
- **Location:** `lib/features/workspace/ui/workspace_screen.dart` (Lines 350–420).
- **Defect:** On viewports between 768px and 904px, Writing Desk carousels display 2.5 cards with floating arrow navigation buttons positioned over the card margins. The right pagination button directly covers the title and badge of the partially visible card, triggering accidental clicks.
- **Remediation:** Anchor pagination buttons in the section header rather than overlaying them as floating arrows atop cards.

---

### 2.10. Pricing Plan Currency Text Wrapping on Narrow Mobile Screens
- **Location:** `lib/features/public_site/presentation/public_pricing_content.dart` (Lines 100–120).
- **Defect:** On narrow phones (width ≤ 360px), `plan.priceLabel(isAnnual: annual)` renders with fixed large typography (`fontSize: context.fs(36)`). Localized pricing strings (`₹14,999 / year`) overflow card bounds, wrapping "/ year" under numeric characters and clipping savings chips.
- **Remediation:** Wrap price labels in `FittedBox(fit: BoxFit.scaleDown, child: Text(...))`.
