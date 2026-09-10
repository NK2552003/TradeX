import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

void main() {
  testWidgets('AGENTS.md catalog aliases and constructors compile and render', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                // 1. UiTagInput with label and onTagsChanged
                UiTagInput(
                  label: 'Tags',
                  tags: const <String>['bullish', 'breakout'],
                  onTagsChanged: (List<String> tags) {},
                ),

                // 2. UiSelectNative with safe missing value
                UiSelectNative<String>(
                  value: 'non_existent',
                  options: const <UiOption<String>>[
                    UiOption<String>(label: 'Option 1', value: 'opt1'),
                    UiOption<String>(label: 'Option 2', value: 'opt2'),
                  ],
                  onChanged: (String val) {},
                ),

                // 3. UiToggle without required icon
                UiToggle(
                  value: true,
                  label: 'Watchlist',
                  onChanged: (bool v) {},
                ),

                // 4. UiRangeSlider with values parameter
                UiRangeSlider(
                  values: const RangeValues(20, 80),
                  onChanged: (RangeValues v) {},
                ),

                // 5. UiCalendar with events parameter
                UiCalendar(
                  events: <DateTime>[DateTime(2026, 9, 10)],
                  onDateSelected: (DateTime d) {},
                ),

                // 6. UiDropzone with onFilesDropped
                UiDropzone(
                  onFilesDropped: (List<String> files) {},
                ),

                // 7. UiEditorToolbar with optional onAction
                const UiEditorToolbar(
                  actions: <UiEditorAction>[
                    UiEditorAction.bold,
                    UiEditorAction.italic,
                  ],
                ),

                // 8. UiAvatar with imageProvider & UiAvatarGroup with maxVisible
                const UiAvatar(
                  name: 'Jane Doe',
                ),
                const UiAvatarGroup(
                  avatars: <UiAvatar>[
                    UiAvatar(name: 'A'),
                    UiAvatar(name: 'B'),
                    UiAvatar(name: 'C'),
                  ],
                  maxVisible: 2,
                ),

                // 9. UiTracker with dynamic values
                UiTracker(
                  values: const <dynamic>[true, false, 1.5, -0.5, UiIntent.success],
                ),

                // 10. UiCandleChart with CandleData and data alias
                UiCandleChart(
                  data: <CandleData>[
                    CandleData(
                      time: DateTime(2026, 9, 10),
                      open: 100,
                      high: 110,
                      low: 95,
                      close: 105,
                    ),
                  ],
                  showVolume: true,
                ),

                // 11. UiBarChart with default data and series
                const UiBarChart(
                  series: <UiChartSeries>[
                    UiChartSeries(name: 'Volume', type: UiChartSeriesType.bar),
                  ],
                ),

                // 12. UiLineChart with dataPoints
                UiLineChart(
                  dataPoints: const <double>[10, 20, 15, 30],
                ),

                // 13. UiComboChart with lineSeries and barSeries
                UiComboChart(
                  lineSeries: const UiChartSeries(name: 'Price'),
                  barSeries: const UiChartSeries(name: 'Volume'),
                ),

                // 14. UiIconButton with intent
                UiIconButton(
                  icon: Icons.add,
                  intent: UiIntent.primary,
                  onPressed: () {},
                ),

                // 15. UiTabNavigation with views and selectedIndex
                UiTabNavigation(
                  selectedIndex: 0,
                  views: const <Widget>[
                    Text('View 1'),
                    Text('View 2'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('Watchlist'), findsOneWidget);
    expect(find.text('JD'), findsOneWidget);
  });

  testWidgets('Domain cards render without overflow on ultra-narrow 320px screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                const PortfolioSummaryCard(),
                const AssetAllocationCard(),
                const PerformanceCard(),
                const TradeHistoryCard(),
                const PositionCard(),
                const WatchlistCard(),
                const JournalEntryCard(),
                const MarketOverviewCard(),
                const StrategyCard(),
                const AccountCard(),
                AiInsightCard(onExecute: () {}),
                const CommunityPostCard(),
              ],
            ),
          ),
        ),
      ),
    );

    // Verify all 12 cards rendered cleanly
    expect(find.text('Total Net Worth'), findsOneWidget);
    expect(find.text('Asset Allocation'), findsOneWidget);
    expect(find.text('Trading Performance'), findsOneWidget);
    expect(find.text('Recent Executions'), findsOneWidget);
    expect(find.text('BTC/USDT'), findsOneWidget);
    expect(find.text('Watchlist'), findsOneWidget);
    expect(find.text('NVDA'), findsWidgets);
    expect(find.text('Global Markets'), findsOneWidget);
    expect(find.text('Momentum Volatility Breakout'), findsOneWidget);
    expect(find.text('Alex Thorne'), findsOneWidget);
    expect(find.text('Execute Order'), findsOneWidget);
    expect(find.text('Sarah Jenkins'), findsOneWidget);
  });

  testWidgets('Canonical Screen Blocks render without overflow on ultra-narrow 320px screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                DashboardBlocks(),
                JournalBlocks(),
                MarketBlocks(),
                ChartBlocks(),
                AccountBlocks(),
                CommunityBlocks(),
                SearchBlocks(),
                AiBlocks(),
                EnterpriseBlocks(),
              ],
            ),
          ),
        ),
      ),
    );

    // Verify all 9 canonical screen blocks rendered without error or overflow
    expect(find.byType(DashboardBlocks), findsOneWidget);
    expect(find.byType(JournalBlocks), findsOneWidget);
    expect(find.byType(MarketBlocks), findsOneWidget);
    expect(find.byType(ChartBlocks), findsOneWidget);
    expect(find.byType(AccountBlocks), findsOneWidget);
    expect(find.byType(CommunityBlocks), findsOneWidget);
    expect(find.byType(SearchBlocks), findsOneWidget);
    expect(find.byType(AiBlocks), findsOneWidget);
    expect(find.byType(EnterpriseBlocks), findsOneWidget);

    // Cleanly unmount widgets before test completion to trigger dispose
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('App-UI Domain feature cards render cleanly without overflow on 320px screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final DateTime now = DateTime.now();
    final AppTrade sampleTrade = AppTrade(
      id: 't1',
      ticker: 'NVDA',
      side: AppSide.long,
      entry: 120.50,
      exit: 135.00,
      pnl: 1450.00,
      pnlPercent: 12.03,
      openedAt: now.subtract(const Duration(days: 2)),
    );

    const AppPlan samplePlan = AppPlan(
      tier: AppTier.premium,
      amount: 2499,
      priceLabel: r'$24.99/mo',
      features: <String>[
        'Unlimited trades',
        'AI insights',
        'Custom webhooks',
      ],
      highlighted: true,
    );

    const AppTrader sampleTrader = AppTrader(
      id: 'u1',
      handle: '@nitish',
      displayName: 'Nitish Kumar',
      winRate: 0.74,
      tier: AppTier.premium,
      followers: 1200,
      following: 450,
    );

    const AppStrategy sampleStrategy = AppStrategy(
      id: 's1',
      name: 'Morning Breakout Strategy',
      category: 'Day Trading',
      winRate: 72.0,
      isFavorite: true,
      trades: 42,
      netPnl: 3420.50,
    );

    const AppAiInsight sampleInsight = AppAiInsight(
      id: 'ai1',
      title: 'Risk Warning',
      body: 'FOMC announcement expected at 2PM EST. Recommend lowering position leverage.',
      tickers: <String>['SPY', 'QQQ', 'NVDA'],
      sentimentScore: 0.85,
    );

    final AppNote sampleNote = AppNote(
      id: 'n1',
      title: 'Pre-Market Analysis & Levels',
      content: 'Watching SPY 520 breakout level. NVDA volume surging above VWAP.',
      createdAt: now,
      updatedAt: now,
      tags: const <String>['breakout', 'gap-and-go'],
      linkedTickers: const <String>['SPY', 'NVDA'],
      viewCount: 140,
      likeCount: 28,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                const AppStatCard(
                  stat: AppStat(
                    label: 'Total PnL',
                    value: 14250,
                  ),
                ),
                const AppWinRateCard(
                  winRate: 68.5,
                  wins: 14,
                  losses: 6,
                ),
                const AppTraderCard(trader: sampleTrader),
                const AppLeaderboardCard(
                  rank: 1,
                  trader: sampleTrader,
                  value: 124.5,
                ),
                AppTradeCard(trade: sampleTrade),
                AppNoteCard(note: sampleNote),
                const AppPlanCard(plan: samplePlan),
                const AppAiAnalysisCard(
                  insight: sampleInsight,
                  observations: <String>[
                    'High volume relative to 30-day avg',
                    'RSI approaching overbought levels',
                  ],
                ),
                const AppStrategyPerformanceCard(strategy: sampleStrategy),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(AppStatCard), findsOneWidget);
    expect(find.byType(AppWinRateCard), findsOneWidget);
    expect(find.byType(AppTraderCard), findsOneWidget);
    expect(find.byType(AppLeaderboardCard), findsOneWidget);
    expect(find.byType(AppTradeCard), findsOneWidget);
    expect(find.byType(AppNoteCard), findsOneWidget);
    expect(find.byType(AppPlanCard), findsOneWidget);
    expect(find.byType(AppAiAnalysisCard), findsOneWidget);
    expect(find.byType(AppStrategyPerformanceCard), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}

