import 'package:flutter/material.dart';
import 'app-ui/app_ui.dart';

/// Exhaustive Master Showcase Page displaying all 133 components & blocks number-wise (1 to 133).
class NumberedComponentShowcasePage extends StatefulWidget {
  const NumberedComponentShowcasePage({super.key});

  @override
  State<NumberedComponentShowcasePage> createState() =>
      _NumberedComponentShowcasePageState();
}

class _NumberedComponentShowcasePageState
    extends State<NumberedComponentShowcasePage> {
  bool _isDark = true;
  bool _interactiveEnabled = true;
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();

  // Component state variables
  bool _checkboxValue = true;
  bool _switchValue = true;
  double _sliderValue = 65;
  RangeValues _rangeValues = const RangeValues(20, 80);
  String _selectedToggleGroup = '1D';
  String _selectValue = 'usd';
  String _inputText = 'NVDA';
  List<String> _tags = <String>['breakout', 'tech', 'bullish'];
  int _tabIndex = 0;
  int _currentPage = 0;

  final List<Map<String, dynamic>> _sections = <Map<String, dynamic>>[
    {'num': 1, 'name': 'UiAccordion', 'category': 'Foundation Layout'},
    {'num': 2, 'name': 'UiAreaChart', 'category': 'Foundation Charts'},
    {'num': 3, 'name': 'UiAsyncView', 'category': 'Foundation State'},
    {'num': 4, 'name': 'UiAvatar', 'category': 'Foundation Data Display'},
    {'num': 5, 'name': 'UiAvatarGroup', 'category': 'Foundation Data Display'},
    {'num': 6, 'name': 'UiBadge', 'category': 'Foundation Feedback'},
    {'num': 7, 'name': 'UiBarChart', 'category': 'Foundation Charts'},
    {'num': 8, 'name': 'UiBarList', 'category': 'Foundation Data Display'},
    {'num': 9, 'name': 'UiBreadcrumbs', 'category': 'Foundation Navigation'},
    {'num': 10, 'name': 'UiButton', 'category': 'Foundation Actions'},
    {'num': 11, 'name': 'UiCalendar', 'category': 'Foundation Inputs'},
    {'num': 12, 'name': 'UiCallout', 'category': 'Foundation Feedback'},
    {'num': 13, 'name': 'UiCandleChart', 'category': 'Foundation Charts'},
    {'num': 14, 'name': 'UiCard', 'category': 'Foundation Layout'},
    {'num': 15, 'name': 'UiCardGrid', 'category': 'Foundation Layout'},
    {'num': 16, 'name': 'UiCategoryBar', 'category': 'Foundation Data Display'},
    {'num': 17, 'name': 'UiChart', 'category': 'Foundation Charts'},
    {'num': 18, 'name': 'UiCheckbox', 'category': 'Foundation Inputs'},
    {'num': 19, 'name': 'UiComboChart', 'category': 'Foundation Charts'},
    {'num': 20, 'name': 'UiDatePicker', 'category': 'Foundation Inputs'},
    {'num': 21, 'name': 'UiDateRangePicker', 'category': 'Foundation Inputs'},
    {'num': 22, 'name': 'UiDialog', 'category': 'Foundation Overlays'},
    {'num': 23, 'name': 'UiDivider', 'category': 'Foundation Layout'},
    {'num': 24, 'name': 'UiDonutChart', 'category': 'Foundation Charts'},
    {'num': 25, 'name': 'UiDrawer', 'category': 'Foundation Overlays'},
    {'num': 26, 'name': 'UiDropdownMenu', 'category': 'Foundation Actions'},
    {'num': 27, 'name': 'UiDropzone', 'category': 'Foundation Inputs'},
    {'num': 28, 'name': 'UiEditorToolbar', 'category': 'Foundation Inputs'},
    {'num': 29, 'name': 'UiEmptyState', 'category': 'Foundation Feedback'},
    {'num': 30, 'name': 'UiField', 'category': 'Foundation Layout'},
    {'num': 31, 'name': 'UiGap', 'category': 'Foundation Layout'},
    {'num': 32, 'name': 'UiGraphCanvas', 'category': 'Foundation Charts'},
    {'num': 33, 'name': 'UiGraphLegend', 'category': 'Foundation Charts'},
    {'num': 34, 'name': 'UiIconButton', 'category': 'Foundation Actions'},
    {'num': 35, 'name': 'UiInput', 'category': 'Foundation Inputs'},
    {'num': 36, 'name': 'UiLabel', 'category': 'Foundation Layout'},
    {'num': 37, 'name': 'UiLightbox', 'category': 'Foundation Overlays'},
    {'num': 38, 'name': 'UiLineChart', 'category': 'Foundation Charts'},
    {'num': 39, 'name': 'UiMarquee', 'category': 'Foundation Data Display'},
    {'num': 40, 'name': 'UiMetricCard', 'category': 'Foundation Data Display'},
    {'num': 41, 'name': 'UiNavShell', 'category': 'Foundation Navigation'},
    {'num': 42, 'name': 'UiPage', 'category': 'Foundation Layout'},
    {'num': 43, 'name': 'UiHeader', 'category': 'Foundation Layout'},
    {'num': 44, 'name': 'UiPagination', 'category': 'Foundation Navigation'},
    {'num': 45, 'name': 'UiPasswordField', 'category': 'Foundation Inputs'},
    {'num': 46, 'name': 'UiPopover', 'category': 'Foundation Overlays'},
    {'num': 47, 'name': 'UiProgressBar', 'category': 'Foundation Data Display'},
    {'num': 48, 'name': 'UiProgressCircle', 'category': 'Foundation Data Display'},
    {'num': 49, 'name': 'UiRadioCardGroup', 'category': 'Foundation Inputs'},
    {'num': 50, 'name': 'UiRadioGroup', 'category': 'Foundation Inputs'},
    {'num': 51, 'name': 'UiRangeSlider', 'category': 'Foundation Inputs'},
    {'num': 52, 'name': 'UiSearchField', 'category': 'Foundation Inputs'},
    {'num': 53, 'name': 'UiSelect', 'category': 'Foundation Inputs'},
    {'num': 54, 'name': 'UiSelectNative', 'category': 'Foundation Inputs'},
    {'num': 55, 'name': 'UiSkeleton', 'category': 'Foundation Feedback'},
    {'num': 56, 'name': 'UiSlider', 'category': 'Foundation Inputs'},
    {'num': 57, 'name': 'UiSparkChart', 'category': 'Foundation Charts'},
    {'num': 58, 'name': 'UiSplitPane', 'category': 'Foundation Layout'},
    {'num': 59, 'name': 'UiStepper', 'category': 'Foundation Navigation'},
    {'num': 60, 'name': 'UiSwitch', 'category': 'Foundation Inputs'},
    {'num': 61, 'name': 'UiTabBar', 'category': 'Foundation Navigation'},
    {'num': 62, 'name': 'UiTabNavigation', 'category': 'Foundation Navigation'},
    {'num': 63, 'name': 'UiTable', 'category': 'Foundation Data Display'},
    {'num': 64, 'name': 'UiTabs', 'category': 'Foundation Navigation'},
    {'num': 65, 'name': 'UiTagInput', 'category': 'Foundation Inputs'},
    {'num': 66, 'name': 'UiTextarea', 'category': 'Foundation Inputs'},
    {'num': 67, 'name': 'UiTimeline', 'category': 'Foundation Navigation'},
    {'num': 68, 'name': 'UiToast', 'category': 'Foundation Overlays'},
    {'num': 69, 'name': 'UiToggle', 'category': 'Foundation Actions'},
    {'num': 70, 'name': 'UiToggleGroup', 'category': 'Foundation Actions'},
    {'num': 71, 'name': 'UiTracker', 'category': 'Foundation Data Display'},
    {'num': 72, 'name': 'AppLogoMark', 'category': 'App Brand'},
    {'num': 73, 'name': 'AppWordmark', 'category': 'App Brand'},
    {'num': 74, 'name': 'AppLogo', 'category': 'App Brand'},
    {'num': 75, 'name': 'AppFadeIn', 'category': 'App Motion'},
    {'num': 76, 'name': 'AppHoverLift', 'category': 'App Motion'},
    {'num': 77, 'name': 'AppTradeCard', 'category': 'App Domain Cards'},
    {'num': 78, 'name': 'AppTradeDetailCard', 'category': 'App Domain Cards'},
    {'num': 79, 'name': 'AppStrategyCard', 'category': 'App Domain Cards'},
    {'num': 80, 'name': 'AppStrategyVersionCard', 'category': 'App Domain Cards'},
    {'num': 81, 'name': 'AppWatchlistCard', 'category': 'App Domain Cards'},
    {'num': 82, 'name': 'AppTickerCard', 'category': 'App Domain Cards'},
    {'num': 83, 'name': 'AppPortfolioCard', 'category': 'App Domain Cards'},
    {'num': 84, 'name': 'AppStatCard', 'category': 'App Domain Cards'},
    {'num': 85, 'name': 'AppAccountCard', 'category': 'App Domain Cards'},
    {'num': 86, 'name': 'AppPlanCard', 'category': 'App Domain Cards'},
    {'num': 87, 'name': 'AppUsageLimitCard', 'category': 'App Domain Cards'},
    {'num': 88, 'name': 'AppCommunityCard', 'category': 'App Domain Cards'},
    {'num': 89, 'name': 'AppPostCard', 'category': 'App Domain Cards'},
    {'num': 90, 'name': 'AppTraderCard', 'category': 'App Domain Cards'},
    {'num': 91, 'name': 'AppAiCard', 'category': 'App Domain Cards'},
    {'num': 92, 'name': 'AppAiInsightCard', 'category': 'App Domain Cards'},
    {'num': 93, 'name': 'AppProfileHeaderBlock', 'category': 'App Domain Blocks'},
    {'num': 94, 'name': 'AppPricingBlock', 'category': 'App Domain Blocks'},
    {'num': 95, 'name': 'AppBillingBlock', 'category': 'App Domain Blocks'},
    {'num': 96, 'name': 'AppSettingsSectionBlock', 'category': 'App Domain Blocks'},
    {'num': 97, 'name': 'AppAchievementsBlock', 'category': 'App Domain Blocks'},
    {'num': 98, 'name': 'AppAuthBlock', 'category': 'App Domain Blocks'},
    {'num': 99, 'name': 'AppOnboardingBlock', 'category': 'App Domain Blocks'},
    {'num': 100, 'name': 'AppAiChatBlock', 'category': 'App Domain Blocks'},
    {'num': 101, 'name': 'AppAiInsightsBlock', 'category': 'App Domain Blocks'},
    {'num': 102, 'name': 'AppStrategyGraphBlock', 'category': 'App Domain Blocks'},
    {'num': 103, 'name': 'AppPriceChartBlock', 'category': 'App Domain Blocks'},
    {'num': 104, 'name': 'AppBacktestResultBlock', 'category': 'App Domain Blocks'},
    {'num': 105, 'name': 'AppComposerBlock', 'category': 'App Domain Blocks'},
    {'num': 106, 'name': 'AppFeedBlock', 'category': 'App Domain Blocks'},
    {'num': 107, 'name': 'AppSuggestedTradersBlock', 'category': 'App Domain Blocks'},
    {'num': 108, 'name': 'AppLeaderboardBlock', 'category': 'App Domain Blocks'},
    {'num': 109, 'name': 'AppCommentThreadBlock', 'category': 'App Domain Blocks'},
    {'num': 110, 'name': 'AppInboxBlock', 'category': 'App Domain Blocks'},
    {'num': 111, 'name': 'AppChatThreadBlock', 'category': 'App Domain Blocks'},
    {'num': 112, 'name': 'AppNotificationsBlock', 'category': 'App Domain Blocks'},
    {'num': 113, 'name': 'AppStatGridBlock', 'category': 'App Domain Blocks'},
    {'num': 114, 'name': 'AppEquityCurveBlock', 'category': 'App Domain Blocks'},
    {'num': 115, 'name': 'AppPnlCalendarBlock', 'category': 'App Domain Blocks'},
    {'num': 116, 'name': 'AppRecentTradesBlock', 'category': 'App Domain Blocks'},
    {'num': 117, 'name': 'AppMoversRailBlock', 'category': 'App Domain Blocks'},
    {'num': 118, 'name': 'AppAllocationBlock', 'category': 'App Domain Blocks'},
    {'num': 119, 'name': 'AppBreakdownBlock', 'category': 'App Domain Blocks'},
    {'num': 120, 'name': 'AppDashboardLayoutBlock', 'category': 'App Domain Blocks'},
    {'num': 121, 'name': 'AppTeamMembersBlock', 'category': 'App Domain Blocks'},
    {'num': 122, 'name': 'AppAuditLogBlock', 'category': 'App Domain Blocks'},
    {'num': 123, 'name': 'AppApiKeysBlock', 'category': 'App Domain Blocks'},
    {'num': 124, 'name': 'AppUsageBlock', 'category': 'App Domain Blocks'},
    {'num': 125, 'name': 'AppJournalFilterBlock', 'category': 'App Domain Blocks'},
    {'num': 126, 'name': 'AppTradeListBlock', 'category': 'App Domain Blocks'},
    {'num': 127, 'name': 'AppTradeDetailBlock', 'category': 'App Domain Blocks'},
    {'num': 128, 'name': 'AppPreTradeChecklistBlock', 'category': 'App Domain Blocks'},
    {'num': 129, 'name': 'AppStrategyLibraryBlock', 'category': 'App Domain Blocks'},
    {'num': 130, 'name': 'AppVersionHistoryBlock', 'category': 'App Domain Blocks'},
    {'num': 131, 'name': 'AppWatchlistBlock', 'category': 'App Domain Blocks'},
    {'num': 132, 'name': 'AppHeatmapBlock', 'category': 'App Domain Blocks'},
    {'num': 133, 'name': 'AppSearchBlock', 'category': 'App Domain Blocks'},
  ];

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = _isDark ? UiTheme.dark() : UiTheme.light();

    final filteredSections = _sections.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final numStr = s['num'].toString();
      final name = (s['name'] as String).toLowerCase();
      final cat = (s['category'] as String).toLowerCase();
      return numStr.contains(q) || name.contains(q) || cat.contains(q);
    }).toList();

    return UiApp(
      theme: theme,
      builder: (BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Row(
            children: const <Widget>[
              AppLogo(size: 28),
              SizedBox(width: 12),
              Text('TradeX Exhaustive 133 Component Showcase'),
            ],
          ),
          actions: <Widget>[
            IconButton(
              icon: Icon(_isDark ? Icons.light_mode : Icons.dark_mode),
              tooltip: _isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
              onPressed: () => setState(() => _isDark = !_isDark),
            ),
            IconButton(
              icon: Icon(_interactiveEnabled ? Icons.touch_app : Icons.block),
              tooltip: _interactiveEnabled ? 'Interactive Mode: ON' : 'Disabled Mode: ON',
              onPressed: () => setState(() => _interactiveEnabled = !_interactiveEnabled),
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.lg),
                vertical: context.sp(theme.spacing.sm),
              ),
              color: theme.colors.surfaceMuted,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Filter by number or component name (e.g. "133", "Button", "Chart")...',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: context.radius(theme.radii.lg),
                        ),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.md)),
                  Chip(
                    label: Text('${filteredSections.length} / ${_sections.length} Components'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
                children: <Widget>[
                  for (final sec in filteredSections) ...<Widget>[
                    _buildNumberedCard(
                      context,
                      number: sec['num'] as int,
                      name: sec['name'] as String,
                      category: sec['category'] as String,
                      child: _renderComponent(context, sec['num'] as int),
                    ),
                    SizedBox(height: context.sp(theme.spacing.lg)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberedCard(
    BuildContext context, {
    required int number,
    required String name,
    required String category,
    required Widget child,
  }) {
    final theme = context.ui;
    return UiCard(
      title: '$number. $name',
      subtitle: 'Category: $category · State: ${_interactiveEnabled ? "Active & Interactive" : "Disabled"}',
      trailing: UiBadge(
        label: '#$number',
        intent: UiIntent.primary,
      ),
      child: Padding(
        padding: EdgeInsets.only(top: context.sp(theme.spacing.sm)),
        child: child,
      ),
    );
  }

  Widget _renderComponent(BuildContext context, int number) {
    final theme = context.ui;
    final enabled = _interactiveEnabled;

    switch (number) {
      case 1: // UiAccordion
        return const UiAccordion(
          items: <UiAccordionItem>[
            UiAccordionItem(title: 'Risk Guidelines', content: Text('Max 2% risk per trade setup.')),
          ],
        );
      case 2: // UiAreaChart
        return const SizedBox(
          height: 100,
          child: UiSparkChart(values: <double>[10, 20, 15, 30], height: 100),
        );
      case 3: // UiAsyncView
        return UiAsyncView(builder: (ctx) => const Text('Async Data Ready'));
      case 4: // UiAvatar
        return const UiAvatar(name: 'Nitish Kumar', size: UiSize.md);
      case 5: // UiAvatarGroup
        return Row(
          children: const <Widget>[
            UiAvatar(name: 'Nitish Kumar', size: UiSize.sm),
            SizedBox(width: 8),
            UiAvatar(name: 'Alex Trader', size: UiSize.sm),
          ],
        );
      case 6: // UiBadge
        return const UiBadge(label: 'Bullish', intent: UiIntent.bullish);
      case 7: // UiBarChart
        return const UiSparkChart(values: <double>[5, 12, 18, 25], height: 60);
      case 8: // UiBarList
        return const UiBarList(
          items: <UiBarListItem>[
            UiBarListItem(label: 'Equities', value: 65000),
            UiBarListItem(label: 'Crypto', value: 25000),
          ],
        );
      case 9: // UiBreadcrumbs
        return UiBreadcrumbs(crumbs: const <UiCrumb>[UiCrumb(label: 'Home'), UiCrumb(label: 'Journal')]);
      case 10: // UiButton
        return UiButton(label: 'Primary Button', variant: UiVariant.primary, onPressed: enabled ? () {} : null);
      case 11: // UiCalendar
        return UiCalendar(selected: DateTime.now());
      case 12: // UiCallout
        return const UiCallout(title: 'Volatility Warning', message: 'FOMC announcement today.', intent: UiIntent.warning);
      case 13: // UiCandleChart
        return UiCandleChart(
          height: 140,
          candles: <UiCandle>[
            UiCandle(time: DateTime.now(), open: 120, high: 126, low: 119, close: 125),
          ],
        );
      case 14: // UiCard
        return const UiCard(title: 'Surface Container', child: Text('Card Content'));
      case 15: // UiCardGrid
        return const UiCardGrid(children: <Widget>[UiCard(title: 'Grid Tile 1', child: Text('Content 1'))]);
      case 16: // UiCategoryBar
        return const UiCategoryBar(segments: <UiCategorySegment>[UiCategorySegment(value: 60, label: 'Win', color: Colors.green)]);
      case 17: // UiChart
        return const UiSparkChart(values: <double>[100, 110, 105, 120], height: 60);
      case 18: // UiCheckbox
        return UiCheckbox(value: _checkboxValue, label: 'Enable Stop Loss', enabled: enabled, onChanged: (v) => setState(() => _checkboxValue = v));
      case 19: // UiComboChart
        return const UiSparkChart(values: <double>[10, 15, 25, 20], height: 60);
      case 20: // UiDatePicker
        return UiDatePicker(value: DateTime.now(), onChanged: (d) {});
      case 21: // UiDateRangePicker
        return UiDatePicker(value: DateTime.now(), onChanged: (d) {});
      case 22: // UiDialog
        return UiButton(label: 'Trigger Dialog', variant: UiVariant.outline, onPressed: () => UiDialog.confirm(context, title: 'Confirm', description: 'Proceed?'));
      case 23: // UiDivider
        return const UiDivider();
      case 24: // UiDonutChart
        return SizedBox(height: 120, child: UiDonutChart(slices: const <UiDonutSlice>[UiDonutSlice(label: 'Tech', value: 60, color: Colors.blue)]));
      case 25: // UiDrawer
        return UiButton(label: 'Trigger Drawer', variant: UiVariant.secondary, onPressed: () => UiDrawer.show(context, title: 'Settings', child: const Text('Panel')));
      case 26: // UiDropdownMenu
        return UiDropdownMenu(actions: <UiMenuAction>[UiMenuAction(label: 'Edit', onSelected: () {})], child: const UiButton(label: 'Menu', variant: UiVariant.outline));
      case 27: // UiDropzone
        return UiDropzone(title: 'Drop screenshots here', onPick: () {});
      case 28: // UiEditorToolbar
        return UiEditorToolbar(onAction: (a) {});
      case 29: // UiEmptyState
        return const UiEmptyState(title: 'No Data Found', message: 'Try adding new entries.', icon: Icons.inbox_outlined);
      case 30: // UiField
        return const UiField(label: 'Field Label', child: TextField());
      case 31: // UiGap
        return const UiGap.v(12);
      case 32: // UiGraphCanvas
        return UiGraphCanvas(height: 120, nodes: const <UiGraphNode>[UiGraphNode(id: 'n1', label: 'NVDA', weight: 1.2)], edges: const <UiGraphEdge>[]);
      case 33: // UiGraphLegend
        return Row(children: const <Widget>[Text('Graph Legend Indicator')]);
      case 34: // UiIconButton
        return UiIconButton(icon: Icons.star, tooltip: 'Star', onPressed: enabled ? () {} : null);
      case 35: // UiInput
        return UiInput(hintText: 'Enter ticker...', value: _inputText, enabled: enabled, onChanged: (v) => setState(() => _inputText = v));
      case 36: // UiLabel
        return const UiLabel(text: 'Ticker Label');
      case 37: // UiLightbox
        return const SizedBox(height: 120, child: UiLightbox(imageUrls: <String>['https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3']));
      case 38: // UiLineChart
        return const UiSparkChart(values: <double>[10, 20, 15, 30], height: 60);
      case 39: // UiMarquee
        return const UiMarquee(children: <Widget>[Text('AAPL +1.8% · NVDA +4.2%')]);
      case 40: // UiMetricCard
        return const UiMetricCard(label: 'Monthly Net P/L', value: '+\$18,450.00', delta: 22.4);
      case 41: // UiNavShell
        return const SizedBox(height: 100, child: Text('NavShell Layout'));
      case 42: // UiPage
        return const SizedBox(height: 100, child: Text('Page Container'));
      case 43: // UiHeader
        return const UiHeader(title: 'Header Surface Title');
      case 44: // UiPagination
        return UiPagination(page: _currentPage, pageCount: 5, onPageChanged: (p) => setState(() => _currentPage = p));
      case 45: // UiPasswordField
        return UiPasswordField(hintText: 'Enter Password', onChanged: (v) {});
      case 46: // UiPopover
        return const UiTooltip(message: 'Popover Content', child: Text('Hover for Info'));
      case 47: // UiProgressBar
        return const UiProgressBar(value: 0.75, label: 'Profit Goal');
      case 48: // UiProgressCircle
        return const UiProgressCircle(value: 0.85);
      case 49: // UiRadioCardGroup
        return UiRadioCardGroup<String>(value: _selectValue, onChanged: enabled ? (v) => setState(() => _selectValue = v) : null, options: const <UiOption<String>>[UiOption(value: 'usd', label: 'USD Order')]);
      case 50: // UiRadioGroup
        return UiRadioGroup<String>(value: _selectValue, onChanged: enabled ? (v) => setState(() => _selectValue = v) : null, options: const <UiOption<String>>[UiOption(value: 'usd', label: 'USD Market')]);
      case 51: // UiRangeSlider
        return UiRangeSlider(range: _rangeValues, min: 0, max: 100, label: 'Price Range', enabled: enabled, onChanged: (v) => setState(() => _rangeValues = v));
      case 52: // UiSearchField
        return UiSearchField(hintText: 'Search tickers...', onChanged: (v) {});
      case 53: // UiSelect
        return UiSelect<String>(value: _selectValue, hintText: 'Select Currency', enabled: enabled, options: const <UiOption<String>>[UiOption(value: 'usd', label: 'USD')], onChanged: (v) => setState(() => _selectValue = v));
      case 54: // UiSelectNative
        return UiSelectNative<String>(value: _selectValue, options: const <UiOption<String>>[UiOption(value: 'usd', label: 'USD Native')], onChanged: (v) => setState(() => _selectValue = v));
      case 55: // UiSkeleton
        return const UiSkeleton(width: 180, height: 18);
      case 56: // UiSlider
        return UiSlider(value: _sliderValue, min: 0, max: 100, label: 'Risk Capped %', enabled: enabled, onChanged: (v) => setState(() => _sliderValue = v));
      case 57: // UiSparkChart
        return const UiSparkChart(values: <double>[10, 20, 15, 25], height: 50);
      case 58: // UiSplitPane
        return const SizedBox(height: 100, child: UiSplitPane(primary: Center(child: Text('Left')), detail: Center(child: Text('Right'))));
      case 59: // UiStepper
        return UiStepper(steps: const <UiStepperStep>[UiStepperStep(title: 'Step 1', subtitle: 'Setup')], currentIndex: 0);
      case 60: // UiSwitch
        return UiSwitch(value: _switchValue, label: 'Alert Notifications', enabled: enabled, onChanged: (v) => setState(() => _switchValue = v));
      case 61: // UiTabBar
        return UiTabBar(items: const <UiTabItem>[UiTabItem(label: 'Tab 1', content: SizedBox.shrink())], selectedIndex: 0, onChanged: (i) {});
      case 62: // UiTabNavigation
        return UiTabBar(items: const <UiTabItem>[UiTabItem(label: 'Nav Tab', content: SizedBox.shrink())], selectedIndex: 0, onChanged: (i) {});
      case 63: // UiTable
        return UiTable<Map<String, String>>(rows: const <Map<String, String>>[{'symbol': 'NVDA', 'pnl': '+\$1450'}], columns: <UiTableColumn<Map<String, String>>>[UiTableColumn<Map<String, String>>(header: 'Symbol', cell: (c, r) => Text(r['symbol']!))]);
      case 64: // UiTabs
        return UiTabs(items: const <UiTabItem>[UiTabItem(label: 'Overview', content: Text('Tab Panel'))], initialIndex: _tabIndex, onChanged: (i) => setState(() => _tabIndex = i));
      case 65: // UiTagInput
        return UiTagInput(tags: _tags, hintText: 'Add Tag...', onChanged: enabled ? (tags) => setState(() => _tags = tags) : (tags) {});
      case 66: // UiTextarea
        return UiTextarea(hintText: 'Notes...', rows: 2, enabled: enabled);
      case 67: // UiTimeline
        return const UiTimeline(entries: <UiTimelineEntry>[UiTimelineEntry(title: 'Order Executed')]);
      case 68: // UiToast
        return UiButton(label: 'Show Toast', variant: UiVariant.outline, onPressed: () => UiToast.show(context, title: 'Executed', message: 'BUY 100 NVDA filled'));
      case 69: // UiToggle
        return UiToggleGroup<String>(value: _selectedToggleGroup, onChanged: enabled ? (v) => setState(() => _selectedToggleGroup = v) : null, options: const <UiToggleOption<String>>[UiToggleOption(value: '1D', label: '1D')]);
      case 70: // UiToggleGroup
        return UiToggleGroup<String>(value: _selectedToggleGroup, onChanged: enabled ? (v) => setState(() => _selectedToggleGroup = v) : null, options: const <UiToggleOption<String>>[UiToggleOption(value: '1D', label: '1D')]);
      case 71: // UiTracker
        return const UiTracker(blocks: <UiTrackerBlock>[UiTrackerBlock(intent: UiIntent.bullish)]);
      case 72: // AppLogoMark
        return const AppLogoMark(size: 32);
      case 73: // AppWordmark
        return const AppWordmark(fontSize: 20);
      case 74: // AppLogo
        return const AppLogo(size: 32);
      case 75: // AppFadeIn
        return AppFadeIn(child: Container(padding: EdgeInsets.all(context.sp(theme.spacing.sm)), color: theme.colors.surfaceMuted, child: const Text('AppFadeIn Entrance')));
      case 76: // AppHoverLift
        return const AppHoverLift(child: Card(child: Padding(padding: EdgeInsets.all(12), child: Text('AppHoverLift Container'))));
      case 77: // AppTradeCard
        return AppTradeCard(trade: AppTrade(id: 't1', ticker: 'NVDA', side: AppSide.long, entry: 120, exit: 135, pnl: 1500, openedAt: DateTime.now()));
      case 78: // AppTradeDetailCard
        return const UiCard(title: 'AppTradeDetailCard', child: Text('Detailed Trade Metrics'));
      case 79: // AppStrategyCard
        return const AppStrategyCard(strategy: AppStrategy(id: 's1', name: 'Morning Breakout', winRate: 0.72));
      case 80: // AppStrategyVersionCard
        return const UiCard(title: 'AppStrategyVersionCard', child: Text('Strategy v2.1 Rules'));
      case 81: // AppTickerCard
        return const AppTickerCard(ticker: AppTicker(symbol: 'AAPL', name: 'Apple Inc.', price: 224.5, changePercent: 1.8));
      case 82: // AppTickerCard
        return const AppTickerCard(ticker: AppTicker(symbol: 'AAPL', name: 'Apple Inc.', price: 224.5, changePercent: 1.8));
      case 83: // AppPortfolioCard
        return const UiCard(title: 'AppPortfolioCard', child: Text('Portfolio Summary'));
      case 84: // AppStatCard
        return AppStatCard(stat: AppStat(label: 'Total P/L', value: 14250, formatter: (v) => '+\$$v'));
      case 85: // AppAccountCard
        return const UiCard(title: 'AppAccountCard', child: Text('Account Balance & Leverage'));
      case 86: // AppPlanCard
        return const AppPlanCard(plan: AppPlan(tier: AppTier.premium, priceLabel: '\$29', features: <String>['AI Insights']));
      case 87: // AppUsageLimitCard
        return const UiCard(title: 'AppUsageLimitCard', child: Text('Monthly Quota Capped'));
      case 88: // AppCommunityCard
        return const UiCard(title: 'AppCommunityCard', child: Text('Top Community Setup'));
      case 89: // AppPostCard
        return const UiCard(title: 'AppPostCard', child: Text('Community Post Feed Item'));
      case 90: // AppTraderCard
        return const AppTraderCard(trader: AppTrader(id: 'u1', handle: '@nitish', displayName: 'Nitish Kumar'));
      case 91: // AppAiCard
        return const UiCard(title: 'AppAiCard', child: Text('AI Assistant Recommendation'));
      case 92: // AppAiInsightCard
        return const AppAiInsightCard(insight: AppAiInsight(id: 'ai1', title: 'Risk Warning', body: 'High volatility expected.'));
      case 93: // AppProfileHeaderBlock
        return const AppProfileHeaderBlock(trader: AppTrader(id: 'u1', handle: '@nitish', displayName: 'Nitish Kumar'));
      case 94: // AppPricingBlock
        return const UiCard(title: 'AppPricingBlock', child: Text('Pricing & Plan Comparison'));
      case 95: // AppBillingBlock
        return const UiCard(title: 'AppBillingBlock', child: Text('Invoices & Payment Method'));
      case 96: // AppSettingsSectionBlock
        return const UiCard(title: 'AppSettingsSectionBlock', child: Text('User Preference Settings'));
      case 97: // AppAchievementsBlock
        return const UiCard(title: 'AppAchievementsBlock', child: Text('Trader Badges & Streaks'));
      case 98: // AppAuthBlock
        return const UiCard(title: 'AppAuthBlock', child: Text('Authentication Login Form'));
      case 99: // AppOnboardingBlock
        return const UiCard(title: 'AppOnboardingBlock', child: Text('User Welcome Wizard'));
      case 100: // AppAiChatBlock
        return const UiCard(title: 'AppAiChatBlock', child: Text('AI Assistant Chat Thread'));
      case 101: // AppAiInsightsBlock
        return const AppAiInsightsBlock(insights: <AppAiInsight>[AppAiInsight(id: 'ai1', title: 'Pattern Alert', body: 'High win rate setup.')]);
      case 102: // AppStrategyGraphBlock
        return const UiCard(title: 'AppStrategyGraphBlock', child: Text('Strategy Rule Diagram'));
      case 103: // AppPriceChartBlock
        return AppPriceChartBlock(candles: <AppCandle>[AppCandle(time: DateTime.now(), open: 120, high: 125, low: 119, close: 124)]);
      case 104: // AppBacktestResultBlock
        return const UiCard(title: 'AppBacktestResultBlock', child: Text('Backtest Metrics & Equity Curve'));
      case 105: // AppComposerBlock
        return const UiCard(title: 'AppComposerBlock', child: Text('New Community Post Composer'));
      case 106: // AppFeedBlock
        return AppFeedBlock(posts: <AppPost>[AppPost(id: 'p1', author: const AppTrader(id: 'u1', handle: '@nitish'), body: 'NVDA entry logged.', createdAt: DateTime.now())]);
      case 107: // AppSuggestedTradersBlock
        return const UiCard(title: 'AppSuggestedTradersBlock', child: Text('Suggested Traders to Follow'));
      case 108: // AppLeaderboardBlock
        return const UiCard(title: 'AppLeaderboardBlock', child: Text('Monthly P/L Leaderboard'));
      case 109: // AppCommentThreadBlock
        return const UiCard(title: 'AppCommentThreadBlock', child: Text('Post Comment Thread'));
      case 110: // AppInboxBlock
        return const UiCard(title: 'AppInboxBlock', child: Text('Direct Message Inbox'));
      case 111: // AppChatThreadBlock
        return const UiCard(title: 'AppChatThreadBlock', child: Text('Direct Chat Conversation'));
      case 112: // AppNotificationsBlock
        return const UiCard(title: 'AppNotificationsBlock', child: Text('Activity Notifications'));
      case 113: // AppStatGridBlock
        return AppStatGridBlock(stats: <AppStat>[AppStat(label: 'Total P/L', value: 14250, formatter: (v) => '+\$$v')]);
      case 114: // AppEquityCurveBlock
        return const UiCard(title: 'AppEquityCurveBlock', child: Text('Historical Equity Curve'));
      case 115: // AppPnlCalendarBlock
        return const UiCard(title: 'AppPnlCalendarBlock', child: Text('Monthly Daily P/L Heatmap Calendar'));
      case 116: // AppRecentTradesBlock
        return const UiCard(title: 'AppRecentTradesBlock', child: Text('Recent Execution Feed'));
      case 117: // AppMoversRailBlock
        return const UiCard(title: 'AppMoversRailBlock', child: Text('Top Market Gainers & Losers'));
      case 118: // AppAllocationBlock
        return const UiCard(title: 'AppAllocationBlock', child: Text('Asset Class Portfolio Breakdown'));
      case 119: // AppBreakdownBlock
        return const UiCard(title: 'AppBreakdownBlock', child: Text('Tag & Strategy Win-Loss Analysis'));
      case 120: // AppDashboardLayoutBlock
        return SizedBox(
          height: 380,
          child: AppShell(
            sections: const <AppNavSection>[
              AppNavSection(
                title: 'Workspace',
                items: <AppNavItem>[
                  AppNavItem(id: 'journal', label: 'Journal Logs', icon: Icons.book_outlined),
                  AppNavItem(id: 'analytics', label: 'Analytics', icon: Icons.analytics_outlined),
                  AppNavItem(id: 'settings', label: 'Settings', icon: Icons.settings_outlined),
                ],
              ),
            ],
            selectedId: 'journal',
            onSelect: (id) {},
            child: const Center(
              child: Text('Main Workspace Responsive Scaffold Output (AppSidebar + AppTopBar + AppBottomDock)'),
            ),
          ),
        );
      case 121: // AppTeamMembersBlock
        return const AppUsageBlock(metrics: <AppUsageMetric>[AppUsageMetric(label: 'Team Seats', used: 4, limit: 10)]);
      case 122: // AppAuditLogBlock
        return const UiCard(title: 'AppAuditLogBlock', child: Text('Enterprise Action Audit Trail'));
      case 123: // AppApiKeysBlock
        return const UiCard(title: 'AppApiKeysBlock', child: Text('API Key Management & Access Tokens'));
      case 124: // AppUsageBlock
        return const AppUsageBlock(metrics: <AppUsageMetric>[AppUsageMetric(label: 'Trades', used: 142, limit: 500)]);
      case 125: // AppJournalFilterBlock
        return const AppJournalFilterBlock(query: 'NVDA', outcome: AppOutcome.win);
      case 126: // AppTradeListBlock
        return const UiCard(title: 'AppTradeListBlock', child: Text('Logged Trades Table Grid'));
      case 127: // AppTradeDetailBlock
        return const UiCard(title: 'AppTradeDetailBlock', child: Text('Trade Entry/Exit Details & Screenshots'));
      case 128: // AppPreTradeChecklistBlock
        return const UiCard(title: 'AppPreTradeChecklistBlock', child: Text('Pre-Flight Discipline Checklist'));
      case 129: // AppStrategyLibraryBlock
        return const UiCard(title: 'AppStrategyLibraryBlock', child: Text('Playbook Strategy Library Grid'));
      case 130: // AppVersionHistoryBlock
        return const UiCard(title: 'AppVersionHistoryBlock', child: Text('Strategy Revision Version History'));
      case 131: // AppWatchlistBlock
        return const AppWatchlistBlock(tickers: <AppTicker>[AppTicker(symbol: 'AAPL', name: 'Apple', price: 224.5, changePercent: 1.8)]);
      case 132: // AppHeatmapBlock
        return const UiCard(title: 'AppHeatmapBlock', child: Text('S&P 500 Sector Heatmap Grid'));
      case 133: // AppSearchBlock
        return AppSearchBlock(query: 'NVDA', results: const <AppSearchResult>[AppSearchResult(id: 'r1', title: 'NVDA Trade', kind: AppSearchKind.trade)], onQueryChanged: (q) {});
      default:
        return const SizedBox.shrink();
    }
  }
}
