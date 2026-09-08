# Component library: TradeX UI system

Use the pre-built TradeX UI component library (`package:tradex/core/app-ui/app_ui.dart` and `package:tradex/core/flutter-ui/flutter_ui.dart`) for all user interfaces, financial charts, domain cards, and screen layouts. Do not build custom Flutter UI controls or layout primitives from scratch when an existing component or block already serves the purpose.

---

## 1. Mandatory imports

Import the unified UI library for any new page, feature, widget, or layout:

```dart
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
```

---

## 2. Reusable component catalog

### A. Actions and buttons
1. `UiButton(label: '...', variant: UiVariant.solid, intent: UiIntent.primary)`: Standard button with solid, outline, ghost, soft, and link variants.
2. `UiIconButton(icon: Icons.add, onPressed: ..., intent: UiIntent.primary)`: Icon button with tooltips, badge overlays, and sizes.
3. `UiDropdownMenu(actions: [UiMenuItem(...)], child: ...)`: Contextual action menu popup.
4. `UiMenuItem(label: '...', icon: Icons.edit, onPressed: ...)`: Dropdown menu item element.

### B. Form inputs and controls
5. `UiInput(label: '...', hintText: '...', value: val, onChanged: ...)`: Standard text input field with adornments and helper text.
6. `UiInput.search(value: q, onChanged: ..., onClear: ...)`: Instant search input field with clear button.
7. `UiSearchField(value: q, onChanged: ...)`: Specialized search input control.
8. `UiTextarea(label: '...', maxLines: 4, value: val, onChanged: ...)`: Multi-line text field with auto-resize.
9. `UiPasswordField(value: pwd, onChanged: ...)`: Secure password field with show/hide toggle.
10. `UiTagInput(tags: ['bullish', 'breakout'], onTagsChanged: ...)`: Multi-tag chip input control.
11. `UiSelect<T>(value: val, options: [...], onChanged: ...)`: Single and multi-select dropdown field with chip display.
12. `UiSelectNative<T>(value: val, options: [...])`: Native platform fallback select field.
13. `UiToggle(value: isChecked, onChanged: ...)` or `UiSwitch`: Toggle switch control with label.
14. `UiCheckbox(value: isChecked, onChanged: ...)`: Tri-state checkbox control with label.
15. `UiRadioGroup<T>(value: val, options: [...], onChanged: ...)`: Radio button selection group.
16. `UiRadioCardGroup<T>(value: val, options: [...], onChanged: ...)`: Interactive card-based radio selector grid.
17. `UiSlider(value: val, min: 0, max: 100, onChanged: ...)`: Numeric continuous/discrete slider.
18. `UiRangeSlider(values: range, onChanged: ...)`: Min-max dual-thumb range slider.
19. `UiDatePicker(selectedDate: date, onDateSelected: ...)`: Single date input with calendar picker popup.
20. `UiDateRangePicker(startDate: s, endDate: e, onRangeSelected: ...)`: Date range selection popover.
21. `UiCalendar(events: [...], onDateSelected: ...)`: Month/week calendar view with event markers.
22. `UiDropzone(onFilesDropped: ...)`: Drag-and-drop file upload target zone.
23. `UiEditorToolbar(actions: [...])`: Rich text formatting toolbar for trading journals.
24. `UiField(label: '...', child: ..., helperText: '...', errorText: '...')`: Unified form wrapper uniting label, input control, and message.
25. `UiLabel(text: '...', isRequired: true)`: Form field label with optional required star indicator.

### C. Navigation and selection
26. `UiTabs(tabs: ['Overview', 'Analytics'], selectedIndex: idx, onChanged: ...)`: Tabbed switcher bar.
27. `UiTabBar(tabs: [...], selectedIndex: idx)`: Sub-tab selection bar.
28. `UiTabNavigation(views: [...], selectedIndex: idx)`: Tab routing shell view.
29. `UiToggleGroup<T>(options: [UiToggleOption(label: '1D', value: '1d')], value: val)`: Segmented control group (1D, 1W, 1M, 1Y, ALL). `scrollWhenTight` defaults to `true`: when the segments need more width than the box allows the track scrolls horizontally instead of clipping. That is a question about the box, not the screen — a five-segment control is comfortable on a 1600 px desktop and clips its last segment inside a 340 dp index rail on the same screen. Set it to `false` only for a group you would rather see clip than scroll.
30. `UiBreadcrumbs(items: [UiBreadcrumbItem(label: 'Home'), UiBreadcrumbItem(label: 'Portfolio')])`: Navigation hierarchy breadcrumb links.
31. `UiPagination(currentPage: p, totalPages: n, onPageChanged: ...)`: Page number navigation bar.
32. `UiAccordion(sections: [UiAccordionSection(title: '...', child: ...)])`: Expandable disclosure collapse container.
33. `UiStepper(steps: [...], currentStep: s)`: Wizard step progress bar controller.
34. `UiTimeline(items: [UiTimelineItem(title: '...', timestamp: '...')])`: Vertical event timeline with status dots.

### D. Surfaces, containers, and data display
35. `UiCard(variant: UiCardVariant.surface, accentColor: colors.primary, child: ...)`: Surface container with optional accent stripe.
36. `UiCardGrid(children: [...])`: Responsive layout grid for cards.
37. `UiTable(columns: [...], rows: [...])`: Enterprise data table with sortable columns, custom cell builders, and pagination.
38. `UiAvatar(name: 'Jane Doe', imageProvider: ...)`: User avatar indicator.
39. `UiAvatarGroup(avatars: [...], maxVisible: 4)`: Stacked avatar stack with overflow counter (+3).
40. `UiBarList(items: [UiBarListItem(label: 'AAPL', value: 45.2, percentage: 0.85)])`: Ranked horizontal progress bar list.
41. `UiCategoryBar(categories: [UiCategoryItem(label: 'Stocks', value: 60, color: ...)])`: Multi-segment category bar.
42. `UiProgressBar(value: 0.75, label: '75% Complete')`: Linear progress bar.
43. `UiProgressCircle(value: 0.65)`: Radial progress indicator ring.
44. `UiMetricCard(title: 'Net Worth', value: '$124,500', change: '+12.4%', isPositive: true)`: Key metric stat card.
45. `UiTracker(values: [...])`: Streak activity tracker grid.
46. `UiMarquee(text: 'LIVE: NVDA +4.2% | AAPL +1.1% | BTC $94,200')`: Continuous scrolling ticker text banner.
47. `UiDivider(label: 'OR')`: Vertical and horizontal line divider with optional text.
48. `UiPage(title: '...', actions: [...], child: ...)`: Page layout shell with title, actions, and scroll controller.
49. `UiSplitPane(left: ..., right: ..., splitRatio: 0.3)`: Resizable split pane layout.
50. `UiNavShell(sidebar: ..., body: ...)`: Main layout shell wrapper with navigation rail.
51. `UiGap(size: 16)`: Consistent flex spacing widget.

### E. Feedback, overlays, and asynchronous states
52. `UiBadge(label: 'Bullish', intent: UiIntent.success, variant: UiBadgeVariant.soft)`: Status chip badge.
53. `UiCallout(title: 'Warning', message: 'Margin level at 85%', intent: UiIntent.warning)`: Alert callout banner.
54. `UiDialog(title: 'Confirm Order', content: ..., actions: [...])`: Modal dialog box.
55. `UiDrawer(title: 'Filter Trades', child: ..., isOpen: isDrawerOpen)`: Animated side drawer panel.
56. `UiTooltip(message: 'Click to export CSV', child: ...)`: Tooltip overlay wrapper.
57. `UiToast` and `UiToaster`: Queueing toast notification controller.
58. `UiEmptyState(icon: Icons.inbox, title: 'No trades found', message: '...', actionLabel: 'Add Trade')`: Zero-data placeholder.
59. `UiAsyncView<T>(state: asyncData, builder: (data) => ..., loadingMessage: 'Fetching live prices...')`: Async loader handling loading, error, and content states.
60. `UiSkeleton(width: 120, height: 20)`: Shimmer skeleton placeholder.
61. `UiTypingIndicator()`: Animated three-dot typing indicator for AI chat views.
62. `UiPopover(content: ..., child: ...)`: Floating contextual popover container.
63. `UiLightbox(mediaUrl: '...')`: Fullscreen image and media lightbox view.

### F. Financial charts and analytics
64. `UiAreaChart(series: [UiChartSeries(...)])`: Smooth gradient area chart.
65. `UiAreaChartCard(title: 'Portfolio Value', value: '$124,500', series: [...], timeframeOptions: [...])`: Pre-packaged area chart card.
66. `UiBarChart(series: [...])`: Bar chart visualization for volumes and returns.
67. `UiCandleChart(candles: [CandleData(...)], showVolume: true)`: Candlestick chart with OHLC data and volume bars.
68. `UiDonutChart(slices: [DonutSlice(...)], centerLabel: '$100K')`: Donut chart for asset allocation.
69. `UiComboChart(lineSeries: ..., barSeries: ...)`: Dual-axis line and bar combination chart.
70. `UiChart(series: [...])`: Core multi-axis financial chart.
71. `UiLineChart(dataPoints: [...])`: Multi-line trend chart.
72. `UiSparkChart(data: [10, 15, 8, 22, 18, 30], color: colors.success)`: Compact sparkline chart.
73. `UiGraphCanvas(nodes: [...], edges: [...])`: Dynamic node-edge network graph canvas.

### G. Pre-built domain cards (`lib/core/app-ui/cards/`)

Cards render one record. They take a model from `lib/core/app-ui/models/` and a callback; none of them fetch, and none of them own state. Every class is exported from `app_ui.dart`.

| File | Classes |
|---|---|
| `portfolio_cards.dart` | `AppStatCard`, `AppWinRateCard`, `AppExtremeTradeCard`, `AppRiskRewardCard`, `AppDrawdownCard`, `AppStreakCard`, `AppCalendarDayCard`, `AppStatCardSkeleton` |
| `journal_cards.dart` | `AppTradeCard`, `AppLinkedJournalCard`, `AppPnlSummaryCard`, `AppLessonCard`, `AppScreenshotImportCard`, `AppChecklistCard`, `AppPsychologyCard`, `AppTradeCardSkeleton` |
| `notes_cards.dart` | `AppNoteCard`, `AppNoteCardSkeleton`, `AppNoteStatRow` |
| `strategy_cards.dart` | `AppStrategyCard`, `AppStrategyPerformanceCard`, `AppVersionCard`, `AppStrategyComparisonCard`, `AppStrategySummaryCard` |
| `watchlist_cards.dart` | `AppTickerCard`, `AppPriceAlertCard`, `AppMoverCard`, `AppHeatTile` |
| `community_cards.dart` | `AppPostCard`, `AppTraderRow`, `AppTraderCard`, `AppLeaderboardCard`, `AppCommentCard`, `AppConversationCard`, `AppMessageBubble`, `AppAiInsightCard`, `AppNewsCard`, `AppNotificationCard` |
| `ai_cards.dart` | `AppAiMessageBubble`, `AppAiAnalysisCard`, `AppAiPromptChips` |
| `account_cards.dart` | `AppPlanCard`, `AppUsageCard`, `AppTierGateCard`, `AppAchievementCard`, `AppSettingCard` |
| `calculator_cards.dart` | `AppCalculatorNavItem`, `AppCalculatorMissingTool`, `AppCalculatorWorkspaceSkeleton` |

### H. Screen blocks (`lib/core/app-ui/blocks/`)

Blocks compose cards and primitives into a region of a screen. They are still presentational: a block that needs data takes a list, and a block that needs an action takes a callback.

| File | Classes |
|---|---|
| `dashboard_blocks.dart` | `AppStatGridBlock`, `AppEquityCurveBlock`, `AppPnlCalendarBlock`, `AppRecentTradesBlock`, `AppMoversRailBlock`, `AppAllocationBlock`, `AppBreakdownBlock`, `AppDashboardLayoutBlock` |
| `journal_blocks.dart` | `AppJournalFilterBlock`, `AppTradeListBlock`, `AppTradeDetailBlock`, `AppPreTradeChecklistBlock`, `AppStrategyLibraryBlock`, `AppVersionHistoryBlock` |
| `journal_note_blocks.dart` | `AppJournalNoteFilterBar`, `AppJournalNoteStatRow`, `AppJournalNoteIndexList`, `AppJournalNoteIndexRow`, `AppJournalNoteCard`, `AppJournalNoteGrid`, `AppJournalNoteHeader`, `AppJournalNoteMetrics` |
| `strategy_note_blocks.dart` | `AppStrategyNoteFilterBar`, `AppStrategyNoteStatRow`, `AppStrategyNoteIndexList`, `AppStrategyNoteIndexRow`, `AppStrategyNoteCard`, `AppStrategyNotePerformance`, `AppStrategyNoteGrid`, `AppStrategyNoteHeader`, `AppStrategyNoteVersionList` |
| `notes_blocks.dart` | `AppNoteFilterBlock`, `AppNoteGridBlock`, `AppNoteLazyGridSliver` |
| `linking_blocks.dart` | `AppLinkChip`, `AppLinkRefTile`, `AppLinkSection`, `AppLinkSectionHeader`, `AppLinkedRecordsPanel`, `AppLinkGraphStrip` |
| `workbench_blocks.dart` | `AppWorkbenchScope`, `AppWorkbenchLayout`, `AppWorkbenchIndex`, `AppIndexRow`, `AppIndexSectionHeader` |
| `calculator_blocks.dart` | `AppCalcHeadline`, `AppCalcInputGroup`, `AppCalcPanel`, `AppCalcSeries`, `AppCalcTrendChart`, `AppCalculatorWorkspaceScope`, `AppCalculatorLayout`, `AppCalcNumberField`, `AppCalcSegment`, `AppCalcSliderField`, `AppCalculatorFilterBlock`, `AppCalculatorToolIndex` |
| `market_blocks.dart` | `AppWatchlistBlock`, `AppHeatmapBlock`, `AppAlertsBlock`, `AppNewsFeedBlock`, `AppSentimentBlock`, `AppMarketAiInsightsBlock`, `AppSymbolHeaderBlock` |
| `chart_blocks.dart` | `AppPriceChartBlock`, `AppBacktestResultBlock` |
| `community_blocks.dart` | `AppComposerBlock`, `AppFeedBlock`, `AppSuggestedTradersBlock`, `AppLeaderboardBlock`, `AppCommentThreadBlock`, `AppInboxBlock`, `AppChatThreadBlock`, `AppNotificationsBlock` |
| `ai_blocks.dart` | `AppAiChatBlock`, `AppAiInsightsBlock`, `AppStrategyGraphBlock` |
| `account_blocks.dart` | `AppProfileHeaderBlock`, `AppPricingBlock`, `AppBillingBlock`, `AppSettingsSectionBlock`, `AppAchievementsBlock`, `AppAuthBlock`, `AppOnboardingBlock` |
| `search_blocks.dart` | `AppSearchBlock`, `AppSearchResultTile` |
| `enterprise_blocks.dart` | `AppTeamMembersBlock`, `AppAuditLogBlock`, `AppApiKeysBlock`, `AppUsageBlock` |

### I. Shell (`lib/core/app-ui/shell/`)

| File | Classes |
|---|---|
| `app_shell.dart` | `AppShell`, `AppWorkspaceTile`, `AppSidebar`, `AppNavUserTile`, `AppNavTile`, `AppTopBar`, `AppCommandPalette`, `AppPageBlock` |
| `app_workspace.dart` | `AppWorkspacePane`, `AppWorkspaceThreePane` |

### J. The three linked authoring surfaces

Trader notes, journal notes and strategy notes are built from one shared vocabulary. Reach for these before writing anything new, because the cross-links between the three surfaces are wired through them:

| Component | Use it for |
|---|---|
| `AppWorkbenchLayout` | The desktop three-region shell: index rail, document, and an optional aside. Wrap it in `AppWorkbenchScope` so descendants can read the active id without a callback chain |
| `AppWorkbenchIndex` + `AppIndexRow` + `AppIndexSectionHeader` | The index rail. Rows are dense, single-line, and selected-state aware — this is the desktop counterpart to a phone's card grid, not a narrower version of it |
| `AppLinkedRecordsPanel` | The aside that lists every record linked to the one on screen, grouped by kind. Needs roughly 1500 dp of window before it earns its place |
| `AppLinkSection` + `AppLinkSectionHeader` + `AppLinkRefTile` | One group inside that panel: a header with a count, then a tile per linked record. `AppLinkRefTile` renders an `AppLinkRef`, including `AppLinkRef.missing` for a link whose target is gone |
| `AppLinkChip` | An inline link, for a header or a card footer where a full tile is too much |
| `AppLinkGraphStrip` | The horizontal summary of a record's links, used on phones where there is no room for an aside |
| `AppJournalNote*` / `AppStrategyNote*` | Per-surface filter bar, stat row, index list/row, card, grid, header. Same names, same order, same argument shapes on both — deliberately, so a change to one surface is obvious in the other |

Two conventions worth knowing before you use them:

- **Win rate scales differ and are not interchangeable.** `AppStrategy.winRate` is `0..100`; `AppJournalStats.winRate` and both stat-row models are `0..1`. A widget test fails on any rendered percentage above 100. Do not "normalise" one to the other.
- **`AppLinkGraph.refFor` never returns null.** An unresolvable link comes back as `AppLinkRef.missing`, which `AppLinkRefTile` renders as a dimmed tile. Nothing downstream needs a null check.

---

## 3. Design tokens and context rules

Access colors, typography, spacing, and sizing through context extensions:

```dart
final theme = context.ui;
final colors = theme.colors;
final textStyle = context.uiText;

final double padding = context.sp(theme.spacing.md);
final double iconSize = context.sz(24);
final BorderRadius radius = context.radius(theme.radii.md);
```

---

## 4. Prompt template for assistants

Include this instruction block when requesting UI development assistance:

```text
You are building UI for TradeX.

Always use the pre-built TradeX UI components from:
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

Required Component Map:
- Buttons and Actions: UiButton, UiIconButton, UiDropdownMenu, UiMenuItem
- Form Fields: UiInput, UiInput.search, UiTextarea, UiPasswordField, UiTagInput, UiSelect, UiToggle, UiCheckbox, UiRadioGroup, UiRadioCardGroup, UiSlider, UiRangeSlider, UiDatePicker, UiDateRangePicker, UiDropzone, UiEditorToolbar, UiField
- Navigation: UiTabs, UiTabBar, UiToggleGroup, UiBreadcrumbs, UiPagination, UiAccordion, UiStepper, UiTimeline
- Surfaces and Data: UiCard, UiCardGrid, UiTable, UiAvatar, UiAvatarGroup, UiBarList, UiCategoryBar, UiProgressBar, UiProgressCircle, UiMetricCard, UiTracker, UiMarquee, UiDivider, UiPage, UiSplitPane
- Feedback and Overlays: UiBadge, UiCallout, UiDialog, UiDrawer, UiTooltip, UiToast, UiEmptyState, UiAsyncView, UiSkeleton, UiTypingIndicator, UiPopover, UiLightbox
- Financial Analytics and Charts: UiAreaChart, UiAreaChartCard, UiBarChart, UiCandleChart, UiDonutChart, UiComboChart, UiSparkChart, UiGraphCanvas
- Domain Cards: PortfolioSummaryCard, AssetAllocationCard, PerformanceCard, TradeHistoryCard, PositionCard, WatchlistCard, JournalEntryCard, MarketOverviewCard, StrategyCard, AccountCard, AiInsightCard, CommunityPostCard
- Screen Blocks: DashboardBlocks, JournalBlocks, MarketBlocks, ChartBlocks, AccountBlocks, CommunityBlocks, SearchBlocks, AiBlocks, EnterpriseBlocks

Design Tokens Access:
- Use context.ui, context.uiText, context.sp(), context.sz().
- Refer to AGENTS.md and NumberedComponentShowcasePage for reference implementation.
```
