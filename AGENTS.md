# TraderHub (TradeX) Exhaustive Reusable Component & Block System Rule

> **CRITICAL MANDATE FOR ALL AI ASSISTANTS**:
> ALWAYS use the pre-built, production-ready TraderHub UI component library (`package:tradex/core/app-ui/app_ui.dart` and `package:tradex/core/flutter-ui/flutter_ui.dart`) for ALL user interfaces, financial charts, domain cards, and screen layouts.
> **STRICTLY FORBIDDEN**: Do NOT build custom Flutter UI controls or layout primitives from scratch (e.g. `ElevatedButton`, `TextButton`, `OutlinedButton`, `TextField`, `Card`, `Container(decoration: ...)`, custom `CustomPainter` charts, or manual loading spinners) when a component or block already exists.

---

## 1. Mandatory Imports

For any new page, feature, widget, or layout, import the unified UI library:

```dart
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
```

---

## 2. Complete Catalog of All 133+ Reusable Components

### A. Foundation Actions & Buttons
1. `UiButton(label: '...', variant: UiVariant.solid, intent: UiIntent.primary)` — Standard button with solid, outline, ghost, soft, link variants.
2. `UiIconButton(icon: Icons.add, onPressed: ..., intent: UiIntent.primary)` — Icon button with tooltips, badge overlays, and sizes.
3. `UiDropdownMenu(actions: [UiMenuItem(...)], child: ...)` — Contextual action menu popup.
4. `UiMenuItem(label: '...', icon: Icons.edit, onPressed: ...)` — Dropdown menu item element.

### B. Form Inputs & Controls
5. `UiInput(label: '...', hintText: '...', value: val, onChanged: ...)` — Standard text input field with adornments and helper text.
6. `UiInput.search(value: q, onChanged: ..., onClear: ...)` — Instant search input field with clear button.
7. `UiSearchField(value: q, onChanged: ...)` — Specialized search input control.
8. `UiTextarea(label: '...', maxLines: 4, value: val, onChanged: ...)` — Multi-line text field with auto-resize.
9. `UiPasswordField(value: pwd, onChanged: ...)` — Secure password field with show/hide toggle.
10. `UiTagInput(tags: ['bullish', 'breakout'], onTagsChanged: ...)` — Multi-tag chip input control.
11. `UiSelect<T>(value: val, options: [...], onChanged: ...)` — Single & multi-select dropdown field with chip display.
12. `UiSelectNative<T>(value: val, options: [...])` — Native platform fallback select field.
13. `UiToggle(value: isChecked, onChanged: ...)` / `UiSwitch` — Toggle switch control with label.
14. `UiCheckbox(value: isChecked, onChanged: ...)` — Tri-state checkbox control with label.
15. `UiRadioGroup<T>(value: val, options: [...], onChanged: ...)` — Radio button selection group.
16. `UiRadioCardGroup<T>(value: val, options: [...], onChanged: ...)` — Interactive card-based radio selector grid.
17. `UiSlider(value: val, min: 0, max: 100, onChanged: ...)` — Numeric continuous/discrete slider.
18. `UiRangeSlider(values: range, onChanged: ...)` — Min-max dual-thumb range slider.
19. `UiDatePicker(selectedDate: date, onDateSelected: ...)` — Single date input with calendar picker popup.
20. `UiDateRangePicker(startDate: s, endDate: e, onRangeSelected: ...)` — Date range selection popover.
21. `UiCalendar(events: [...], onDateSelected: ...)` — Month/week calendar view with event markers.
22. `UiDropzone(onFilesDropped: ...)` — Drag-and-drop file upload target zone.
23. `UiEditorToolbar(actions: [...])` — Rich text formatting toolbar for trading journals.
24. `UiField(label: '...', child: ..., helperText: '...', errorText: '...')` — Unified form wrapper uniting label, input control, and message.
25. `UiLabel(text: '...', isRequired: true)` — Form field label with optional required star indicator.

### C. Navigation & Selection Primitives
26. `UiTabs(tabs: ['Overview', 'Analytics'], selectedIndex: idx, onChanged: ...)` — Tabbed switcher bar.
27. `UiTabBar(tabs: [...], selectedIndex: idx)` — Sub-tab selection bar.
28. `UiTabNavigation(views: [...], selectedIndex: idx)` — Tab routing shell view.
29. `UiToggleGroup<T>(options: [UiOption(label: '1D', value: '1d')], value: val)` — Segmented control group (1D, 1W, 1M, 1Y, ALL).
30. `UiBreadcrumbs(items: [UiBreadcrumbItem(label: 'Home'), UiBreadcrumbItem(label: 'Portfolio')])` — Navigation hierarchy breadcrumb links.
31. `UiPagination(currentPage: p, totalPages: n, onPageChanged: ...)` — Page number navigation bar.
32. `UiAccordion(sections: [UiAccordionSection(title: '...', child: ...)])` — Expandable disclosure collapse container.
33. `UiStepper(steps: [...], currentStep: s)` — Wizard step progress bar controller.
34. `UiTimeline(items: [UiTimelineItem(title: '...', timestamp: '...')])` — Vertical event timeline with status dots.

### D. Surfaces, Containers & Data Display
35. `UiCard(variant: UiCardVariant.surface, accentColor: colors.primary, child: ...)` — Surface container with optional accent stripe.
36. `UiCardGrid(children: [...])` — Responsive layout grid for cards.
37. `UiTable(columns: [...], rows: [...])` — Enterprise data table with sortable columns, custom cell builders, and pagination.
38. `UiAvatar(name: 'Jane Doe', imageProvider: ...)` — User avatar indicator.
39. `UiAvatarGroup(avatars: [...], maxVisible: 4)` — Stacked avatar stack with overflow counter (+3).
40. `UiBarList(items: [UiBarListItem(label: 'AAPL', value: 45.2, percentage: 0.85)])` — Ranked horizontal progress bar list.
41. `UiCategoryBar(categories: [UiCategoryItem(label: 'Stocks', value: 60, color: ...)])` — Multi-segment category bar.
42. `UiProgressBar(value: 0.75, label: '75% Complete')` — Linear progress bar.
43. `UiProgressCircle(value: 0.65)` — Radial progress indicator ring.
44. `UiMetricCard(title: 'Net Worth', value: '$124,500', change: '+12.4%', isPositive: true)` — Key metric stat card.
45. `UiTracker(values: [...])` — Streak activity tracker grid.
46. `UiMarquee(text: 'LIVE: NVDA +4.2% | AAPL +1.1% | BTC $94,200')` — Continuous scrolling ticker text banner.
47. `UiDivider(label: 'OR')` — Vertical & horizontal line divider with optional text.
48. `UiPage(title: '...', actions: [...], child: ...)` — Page layout shell with title, actions, and scroll controller.
49. `UiSplitPane(left: ..., right: ..., splitRatio: 0.3)` — Resizable split pane layout.
50. `UiNavShell(sidebar: ..., body: ...)` — Main layout shell wrapper with navigation rail.
51. `UiGap(size: 16)` — Consistent flex spacing widget.

### E. Feedback, Overlays & Async States
52. `UiBadge(label: 'Bullish', intent: UiIntent.success, variant: UiBadgeVariant.soft)` — Status chip badge.
53. `UiCallout(title: 'Warning', message: 'Margin level at 85%', intent: UiIntent.warning)` — Alert callout banner.
54. `UiDialog(title: 'Confirm Order', content: ..., actions: [...])` — Modal dialog box.
55. `UiDrawer(title: 'Filter Trades', child: ..., isOpen: isDrawerOpen)` — Animated side drawer panel.
56. `UiTooltip(message: 'Click to export CSV', child: ...)` — Tooltip overlay wrapper.
57. `UiToast` & `UiToaster` — Queueing toast notification controller.
58. `UiEmptyState(icon: Icons.inbox, title: 'No trades found', message: '...', actionLabel: 'Add Trade')` — Zero-data placeholder.
59. `UiAsyncView<T>(state: asyncData, builder: (data) => ..., loadingMessage: 'Fetching live prices...')` — Complete async loader handling loading, error, and content states.
60. `UiSkeleton(width: 120, height: 20)` — Shimmer skeleton placeholder.
61. `UiTypingIndicator()` — Animated 3-dot typing indicator for AI chat views.
62. `UiPopover(content: ..., child: ...)` — Floating contextual popover container.
63. `UiLightbox(mediaUrl: '...')` — Fullscreen image/media lightbox view.

### F. Financial Charts & Analytics
64. `UiAreaChart(series: [UiChartSeries(...)])` — Smooth gradient area chart.
65. `UiAreaChartCard(title: 'Portfolio Value', value: '$124,500', series: [...], timeframeOptions: [...])` — Pre-packaged area chart card.
66. `UiBarChart(series: [...])` — Bar chart visualization for volumes/returns.
67. `UiCandleChart(candles: [CandleData(...)], showVolume: true)` — Professional candlestick chart with OHLC data & volume bars.
68. `UiDonutChart(slices: [DonutSlice(...)], centerLabel: '$100K')` — Donut/pie chart for asset allocation.
69. `UiComboChart(lineSeries: ..., barSeries: ...)` — Dual-axis line & bar combination chart.
70. `UiChart(series: [...])` — Core multi-axis financial chart.
71. `UiLineChart(dataPoints: [...])` — Multi-line trend chart.
72. `UiSparkChart(data: [10, 15, 8, 22, 18, 30], color: colors.success)` — Ultra-compact sparkline chart.
73. `UiGraphCanvas(nodes: [...], edges: [...])` — Dynamic node-edge network graph canvas.

### G. Pre-Built Domain Cards (`lib/core/app-ui/cards/`)
74. `PortfolioSummaryCard` — Net worth, PnL, cash balance, and daily gain summary card.
75. `AssetAllocationCard` — Portfolio asset breakdown (stocks, crypto, options, cash).
76. `PerformanceCard` — Annual/monthly return matrix with win-rate stats.
77. `TradeHistoryCard` — Executed trade log card with entry/exit, quantity, PnL badge.
78. `PositionCard` — Open position card with live market price, liquidation level, and PnL.
79. `WatchlistCard` — Custom symbol watchlist card with sparklines and price changes.
80. `JournalEntryCard` — Trade journal record card with chart thumbnail, notes, and tags.
81. `MarketOverviewCard` — Major market indices summary card (S&P 500, Nasdaq, BTC, Gold).
82. `StrategyCard` — Quantitative strategy card with Sharpe ratio, win rate, and drawdown.
83. `AccountCard` — User profile summary card with tier badge and security status.
84. `AiInsightCard` — AI trade signal card with confidence score and trade setup rationale.
85. `CommunityPostCard` — Social post card with trader comments, likes, and chart attachments.

### H. Complete Screen Blocks (`lib/core/app-ui/blocks/`)
86. `DashboardBlocks` — Executive portfolio dashboard block with summary cards and active position feeds.
87. `JournalBlocks` — Trading journal screen block with calendar heatmap, entry filters, and execution stats.
88. `MarketBlocks` — Live market scanner block with order book, market depth, and top gainers/losers.
89. `ChartBlocks` — Technical analysis workspace block combining candlestick charts, indicator controls, and order entry panel.
90. `AccountBlocks` — Account settings block with security configuration, API keys, and notification toggles.
91. `CommunityBlocks` — Social trading feed block with trader leaderboards and strategy sharing.
92. `SearchBlocks` — Universal search modal block with instant symbol lookup and command palette.
93. `AiBlocks` — AI trading assistant block with conversational interface and pattern detection.
94. `EnterpriseBlocks` — Institutional risk management and compliance audit block.

---

## 3. Design Tokens & Context Rules

Access colors, typography, spacing, and sizing exclusively via context extensions:

```dart
final theme = context.ui;
final colors = theme.colors;
final textStyle = context.uiText;

final double padding = context.sp(theme.spacing.md);
final double iconSize = context.sz(24);
final BorderRadius radius = context.radius(theme.radii.md);
```

---

## 4. Copy-Pasteable Prompt for AI Assistants

Include this block when prompting an AI assistant for new features:

```text
You are building UI for TraderHub TradeX.

CRITICAL INSTRUCTION:
Do NOT create custom Flutter widgets (ElevatedButton, TextField, Card, Container borders, custom painters) from scratch.

ALWAYS use the pre-built 133+ TraderHub UI components from:
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

Required Component Map:
- Buttons & Actions: UiButton, UiIconButton, UiDropdownMenu, UiMenuItem
- Form Fields: UiInput, UiInput.search, UiTextarea, UiPasswordField, UiTagInput, UiSelect, UiToggle, UiCheckbox, UiRadioGroup, UiRadioCardGroup, UiSlider, UiRangeSlider, UiDatePicker, UiDateRangePicker, UiDropzone, UiEditorToolbar, UiField
- Navigation: UiTabs, UiTabBar, UiToggleGroup, UiBreadcrumbs, UiPagination, UiAccordion, UiStepper, UiTimeline
- Surfaces & Data: UiCard, UiCardGrid, UiTable, UiAvatar, UiAvatarGroup, UiBarList, UiCategoryBar, UiProgressBar, UiProgressCircle, UiMetricCard, UiTracker, UiMarquee, UiDivider, UiPage, UiSplitPane
- Feedback & Overlays: UiBadge, UiCallout, UiDialog, UiDrawer, UiTooltip, UiToast, UiEmptyState, UiAsyncView, UiSkeleton, UiTypingIndicator, UiPopover, UiLightbox
- Financial Analytics & Charts: UiAreaChart, UiAreaChartCard, UiBarChart, UiCandleChart, UiDonutChart, UiComboChart, UiSparkChart, UiGraphCanvas
- Domain Cards: PortfolioSummaryCard, AssetAllocationCard, PerformanceCard, TradeHistoryCard, PositionCard, WatchlistCard, JournalEntryCard, MarketOverviewCard, StrategyCard, AccountCard, AiInsightCard, CommunityPostCard
- Screen Blocks: DashboardBlocks, JournalBlocks, MarketBlocks, ChartBlocks, AccountBlocks, CommunityBlocks, SearchBlocks, AiBlocks, EnterpriseBlocks

Design Tokens Access:
- Use context.ui, context.uiText, context.sp(), context.sz().
- Refer to AGENTS.md and NumberedComponentShowcasePage for reference implementation.
```
