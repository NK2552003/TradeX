import 'package:flutter/material.dart';

import '../app-ui/blocks/account_blocks.dart';
import '../app-ui/blocks/ai_blocks.dart';
import '../app-ui/blocks/chart_blocks.dart';
import '../app-ui/blocks/community_blocks.dart';
import '../app-ui/blocks/dashboard_blocks.dart';
import '../app-ui/blocks/enterprise_blocks.dart';
import '../app-ui/blocks/journal_blocks.dart';
import '../app-ui/blocks/market_blocks.dart' as market;
import '../app-ui/blocks/market_blocks.dart';
import '../app-ui/blocks/search_blocks.dart';
import '../app-ui/models/app_models.dart';
import '../app-ui/models/app_models_extra.dart';
import '../app-ui/shell/app_shell.dart';
import '../app-ui/shell/app_workspace.dart';
import '../app-ui/theme/app_tokens.dart';
import '../flutter-ui/flutter_ui.dart';
import 'state_gallery.dart';

/// Batch — application blocks. One gallery per block class exported from
/// `app-ui/blocks/*.dart`, grouped by source file, followed by a bounded
/// shell/workspace gallery.
///
/// Gallery order (48 total):
///   Dashboard   1. AppStatGridBlock            2. AppEquityCurveBlock
///               3. AppPnlCalendarBlock         4. AppRecentTradesBlock
///               5. AppMoversRailBlock          6. AppAllocationBlock
///               7. AppBreakdownBlock           8. AppDashboardLayoutBlock
///   Journal     9. AppJournalFilterBlock      10. AppTradeListBlock
///              11. AppTradeDetailBlock        12. AppPreTradeChecklistBlock
///              13. AppStrategyLibraryBlock    14. AppVersionHistoryBlock
///   Market     15. AppWatchlistBlock          16. AppHeatmapBlock
///              17. AppAlertsBlock             18. AppNewsFeedBlock
///              19. AppSentimentBlock          20. AppAiInsightsBlock (market)
///              21. AppSymbolHeaderBlock
///   Community  22. AppComposerBlock           23. AppFeedBlock
///              24. AppSuggestedTradersBlock   25. AppLeaderboardBlock
///              26. AppCommentThreadBlock      27. AppInboxBlock
///              28. AppChatThreadBlock         29. AppNotificationsBlock
///   Account    30. AppProfileHeaderBlock      31. AppPricingBlock
///              32. AppBillingBlock            33. AppSettingsSectionBlock
///              34. AppAchievementsBlock       35. AppAuthBlock
///              36. AppOnboardingBlock
///   AI         37. AppAiChatBlock             38. AppAiInsightsBlock (ai)
///              39. AppStrategyGraphBlock
///   Chart      40. AppPriceChartBlock         41. AppBacktestResultBlock
///   Search     42. AppSearchBlock             43. AppSearchResultTile
///   Enterprise 44. AppTeamMembersBlock        45. AppAuditLogBlock
///              46. AppApiKeysBlock            47. AppUsageBlock
///   Shell      48. Shell & workspace (AppShell, AppSidebar, AppTopBar,
///                  AppBottomDock, AppNavTile, AppCommandPalette,
///                  AppWorkspacePane, AppWorkspaceThreePane)
const int kBlocksGalleryCount = 48;

class BlocksShowcaseSection extends StatefulWidget {
  const BlocksShowcaseSection({super.key, required this.startIndex});

  final int startIndex;

  @override
  State<BlocksShowcaseSection> createState() => _BlocksShowcaseSectionState();
}

class _BlocksShowcaseSectionState extends State<BlocksShowcaseSection> {
  @override
  Widget build(BuildContext context) {
    final int s = widget.startIndex;
    final double gap = context.sp(context.ui.spacing.lg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const UiShowcaseSection(
          title: 'Dashboard blocks',
          subtitle:
              'Stat grids, equity curve, P/L calendar, trades, movers, '
              'allocation, breakdowns and the responsive layout shell.',
        ),
        SizedBox(height: gap),
        _StatGridGallery(index: s),
        SizedBox(height: gap),
        _EquityCurveGallery(index: s + 1),
        SizedBox(height: gap),
        _PnlCalendarGallery(index: s + 2),
        SizedBox(height: gap),
        _RecentTradesGallery(index: s + 3),
        SizedBox(height: gap),
        _MoversRailGallery(index: s + 4),
        SizedBox(height: gap),
        _AllocationGallery(index: s + 5),
        SizedBox(height: gap),
        _BreakdownGallery(index: s + 6),
        SizedBox(height: gap),
        _DashboardLayoutGallery(index: s + 7),
        SizedBox(height: gap),

        const UiShowcaseSection(
          title: 'Journal blocks',
          subtitle:
              'Filtering, trade lists/detail, checklists, strategy library '
              'and version history.',
        ),
        SizedBox(height: gap),
        _JournalFilterGallery(index: s + 8),
        SizedBox(height: gap),
        _TradeListGallery(index: s + 9),
        SizedBox(height: gap),
        _TradeDetailGallery(index: s + 10),
        SizedBox(height: gap),
        _PreTradeChecklistGallery(index: s + 11),
        SizedBox(height: gap),
        _StrategyLibraryGallery(index: s + 12),
        SizedBox(height: gap),
        _VersionHistoryGallery(index: s + 13),
        SizedBox(height: gap),

        const UiShowcaseSection(
          title: 'Market blocks',
          subtitle:
              'Watchlist, heatmap, alerts, news, sentiment, AI insights and '
              'the symbol detail header.',
        ),
        SizedBox(height: gap),
        _WatchlistGallery(index: s + 14),
        SizedBox(height: gap),
        _HeatmapGallery(index: s + 15),
        SizedBox(height: gap),
        _AlertsGallery(index: s + 16),
        SizedBox(height: gap),
        _NewsFeedGallery(index: s + 17),
        SizedBox(height: gap),
        _SentimentGallery(index: s + 18),
        SizedBox(height: gap),
        _MarketAiInsightsGallery(index: s + 19),
        SizedBox(height: gap),
        _SymbolHeaderGallery(index: s + 20),
        SizedBox(height: gap),

        const UiShowcaseSection(
          title: 'Community blocks',
          subtitle:
              'Composer, feed, suggested traders, leaderboard, comments, '
              'inbox, chat and notifications.',
        ),
        SizedBox(height: gap),
        _ComposerGallery(index: s + 21),
        SizedBox(height: gap),
        _FeedGallery(index: s + 22),
        SizedBox(height: gap),
        _SuggestedTradersGallery(index: s + 23),
        SizedBox(height: gap),
        _LeaderboardGallery(index: s + 24),
        SizedBox(height: gap),
        _CommentThreadGallery(index: s + 25),
        SizedBox(height: gap),
        _InboxGallery(index: s + 26),
        SizedBox(height: gap),
        _ChatThreadGallery(index: s + 27),
        SizedBox(height: gap),
        _NotificationsGallery(index: s + 28),
        SizedBox(height: gap),

        const UiShowcaseSection(
          title: 'Account blocks',
          subtitle:
              'Profile header, pricing, billing, settings, achievements, '
              'auth and onboarding.',
        ),
        SizedBox(height: gap),
        _ProfileHeaderGallery(index: s + 29),
        SizedBox(height: gap),
        _PricingGallery(index: s + 30),
        SizedBox(height: gap),
        _BillingGallery(index: s + 31),
        SizedBox(height: gap),
        _SettingsSectionGallery(index: s + 32),
        SizedBox(height: gap),
        _AchievementsGallery(index: s + 33),
        SizedBox(height: gap),
        _AuthGallery(index: s + 34),
        SizedBox(height: gap),
        _OnboardingGallery(index: s + 35),
        SizedBox(height: gap),

        const UiShowcaseSection(
          title: 'AI blocks',
          subtitle:
              'Assistant chat thread, insight cards and the strategy '
              'relationship graph.',
        ),
        SizedBox(height: gap),
        _AiChatGallery(index: s + 36),
        SizedBox(height: gap),
        _AiInsightsGallery(index: s + 37),
        SizedBox(height: gap),
        _StrategyGraphGallery(index: s + 38),
        SizedBox(height: gap),

        const UiShowcaseSection(
          title: 'Chart blocks',
          subtitle: 'Price chart with timeframe/type switcher and backtest results.',
        ),
        SizedBox(height: gap),
        _PriceChartGallery(index: s + 39),
        SizedBox(height: gap),
        _BacktestResultGallery(index: s + 40),
        SizedBox(height: gap),

        const UiShowcaseSection(
          title: 'Search blocks',
          subtitle: 'Global search surface and a single result tile.',
        ),
        SizedBox(height: gap),
        _SearchGallery(index: s + 41),
        SizedBox(height: gap),
        _SearchResultTileGallery(index: s + 42),
        SizedBox(height: gap),

        const UiShowcaseSection(
          title: 'Enterprise blocks',
          subtitle: 'Team roster, audit log, API keys and plan usage meters.',
        ),
        SizedBox(height: gap),
        _TeamMembersGallery(index: s + 43),
        SizedBox(height: gap),
        _AuditLogGallery(index: s + 44),
        SizedBox(height: gap),
        _ApiKeysGallery(index: s + 45),
        SizedBox(height: gap),
        _UsageGallery(index: s + 46),
        SizedBox(height: gap),

        const UiShowcaseSection(
          title: 'Shell & workspace',
          subtitle:
              'Adaptive app shell, sidebar, top bar, bottom dock, command '
              'palette and split/three-pane workspaces (bounded height).',
        ),
        SizedBox(height: gap),
        _ShellGallery(index: s + 47),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

/// Wraps [child] in a locally tightened [UiTheme] to approximate a dense /
/// compact rendering for blocks that don't expose their own density knob.
Widget _dense(BuildContext context, Widget child) {
  final UiTheme theme = context.ui;
  return UiThemeScope(
    theme: theme.copyWith(
      spacing: const UiSpacing(
        none: 0,
        xxs: 1,
        xs: 2,
        sm: 4,
        md: 6,
        lg: 8,
        xl: 12,
        xxl: 16,
        xxxl: 24,
      ),
    ),
    child: child,
  );
}

Widget _mobile360(Widget child) => SizedBox(
      width: 360,
      child: MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          devicePixelRatio: 1.0,
        ),
        child: child,
      ),
    );

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

class _StatGridGallery extends StatelessWidget {
  const _StatGridGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppStatGridBlock',
        description: 'Responsive KPI grid with a skeleton loading state.',
        tags: const <String>['dashboard'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppStatGridBlock(stats: _stats), fill: true),
          UiStateCase('loading',
              builder: (_) =>
                  const AppStatGridBlock(stats: <AppStat>[], loading: true),
              fill: true),
          UiStateCase('dense',
              builder: (BuildContext ctx) =>
                  _dense(ctx, AppStatGridBlock(stats: _stats)),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppStatGridBlock(stats: _stats))),
        ],
      );
}

class _EquityCurveGallery extends StatelessWidget {
  const _EquityCurveGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppEquityCurveBlock',
        description: 'Equity curve card with a range switcher.',
        tags: const <String>['dashboard', 'chart'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppEquityCurveBlock(series: _series),
              fill: true),
          UiStateCase('dense',
              builder: (BuildContext ctx) =>
                  _dense(ctx, AppEquityCurveBlock(series: _series)),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppEquityCurveBlock(series: _series))),
        ],
      );
}

class _PnlCalendarGallery extends StatelessWidget {
  const _PnlCalendarGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppPnlCalendarBlock',
        description: 'Monthly P/L calendar heatmap.',
        tags: const <String>['dashboard'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppPnlCalendarBlock(days: _days), fill: true),
          UiStateCase('empty',
              builder: (_) => const AppPnlCalendarBlock(days: <AppDayPnl>[]),
              fill: true),
          UiStateCase('dense',
              builder: (BuildContext ctx) =>
                  _dense(ctx, AppPnlCalendarBlock(days: _days)),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppPnlCalendarBlock(days: _days))),
        ],
      );
}

class _RecentTradesGallery extends StatelessWidget {
  const _RecentTradesGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppRecentTradesBlock',
        description: 'Recent trades list with a view-all action; native empty state.',
        tags: const <String>['dashboard'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppRecentTradesBlock(trades: _trades, onViewAll: () {}),
              fill: true),
          UiStateCase('empty',
              builder: (_) => const AppRecentTradesBlock(trades: <AppTrade>[]),
              fill: true),
          UiStateCase('dense',
              builder: (BuildContext ctx) =>
                  _dense(ctx, AppRecentTradesBlock(trades: _trades)),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppRecentTradesBlock(trades: _trades))),
        ],
      );
}

class _MoversRailGallery extends StatelessWidget {
  const _MoversRailGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppMoversRailBlock',
        description: 'Horizontally scrolling gainers / losers rail.',
        tags: const <String>['dashboard', 'market'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppMoversRailBlock(tickers: _tickers), fill: true),
          UiStateCase('dense',
              builder: (BuildContext ctx) =>
                  _dense(ctx, AppMoversRailBlock(tickers: _tickers)),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppMoversRailBlock(tickers: _tickers))),
        ],
      );
}

class _AllocationGallery extends StatelessWidget {
  const _AllocationGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppAllocationBlock',
        description: 'Allocation donut chart with legend.',
        tags: const <String>['dashboard', 'chart'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppAllocationBlock(
                    slices: _slices,
                    totalLabel: '\$48,120',
                  ),
              fill: true),
          UiStateCase('dense',
              builder: (BuildContext ctx) => _dense(
                  ctx, AppAllocationBlock(slices: _slices, totalLabel: '\$48,120')),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(
                  AppAllocationBlock(slices: _slices, totalLabel: '\$48,120'))),
        ],
      );
}

class _BreakdownGallery extends StatelessWidget {
  const _BreakdownGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppBreakdownBlock',
        description: 'Ranked bar-list breakdown; native empty state.',
        tags: const <String>['dashboard'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppBreakdownBlock(items: _barItems), fill: true),
          UiStateCase('empty',
              builder: (_) => const AppBreakdownBlock(items: <UiBarListItem>[]),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppBreakdownBlock(items: _barItems))),
        ],
      );
}

class _DashboardLayoutGallery extends StatelessWidget {
  const _DashboardLayoutGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppDashboardLayoutBlock',
        description: 'Two-column responsive dashboard body: main + side.',
        tags: const <String>['dashboard', 'layout'],
        cases: <UiStateCase>[
          UiStateCase(
            'populated',
            builder: (_) => AppDashboardLayoutBlock(
              main: <Widget>[AppStatGridBlock(stats: _stats)],
              side: <Widget>[AppAllocationBlock(slices: _slices)],
            ),
            fill: true,
          ),
          UiStateCase(
            'mobile 360',
            builder: (_) => _mobile360(
              AppDashboardLayoutBlock(
                main: <Widget>[AppStatGridBlock(stats: _stats)],
                side: <Widget>[AppAllocationBlock(slices: _slices)],
              ),
            ),
          ),
        ],
      );
}

// ---------------------------------------------------------------------------
// Journal
// ---------------------------------------------------------------------------

class _JournalFilterGallery extends StatelessWidget {
  const _JournalFilterGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppJournalFilterBlock',
        description: 'Search + outcome filters + sort trigger.',
        tags: const <String>['journal'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppJournalFilterBlock(
                    query: '',
                    outcome: null,
                    onOpenFilters: () {},
                  ),
              fill: true),
          UiStateCase('filtered',
              builder: (_) => AppJournalFilterBlock(
                    query: 'AAPL',
                    outcome: AppOutcome.win,
                  ),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(
                  const AppJournalFilterBlock(query: '', outcome: null))),
        ],
      );
}

class _TradeListGallery extends StatelessWidget {
  const _TradeListGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppTradeListBlock',
        description: 'Table on wide screens, cards on phones; native loading/empty.',
        tags: const <String>['journal', 'table'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppTradeListBlock(trades: _trades), fill: true),
          UiStateCase('loading',
              builder: (_) =>
                  const AppTradeListBlock(trades: <AppTrade>[], loading: true),
              fill: true),
          UiStateCase('empty',
              builder: (_) => AppTradeListBlock(
                    trades: const <AppTrade>[],
                    emptyAction: UiButton(label: 'Log trade', onPressed: () {}),
                  ),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppTradeListBlock(trades: _trades))),
        ],
      );
}

class _TradeDetailGallery extends StatelessWidget {
  const _TradeDetailGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppTradeDetailBlock',
        description: 'Full trade detail: levels, result, notes, psychology.',
        tags: const <String>['journal'],
        minCaseWidth: 320,
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppTradeDetailBlock(
                    trade: _trades.first,
                    onEdit: () {},
                    onDelete: () {},
                  ),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(
                  AppTradeDetailBlock(trade: _trades.first))),
        ],
      );
}

class _PreTradeChecklistGallery extends StatelessWidget {
  const _PreTradeChecklistGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppPreTradeChecklistBlock',
        description: 'Checklist gate with completion progress.',
        tags: const <String>['journal'],
        cases: <UiStateCase>[
          UiStateCase('in progress',
              builder: (_) => AppPreTradeChecklistBlock(items: _checklist)),
          UiStateCase(
            'complete',
            builder: (_) => AppPreTradeChecklistBlock(
              items: <AppChecklistItem>[
                for (final AppChecklistItem c in _checklist)
                  AppChecklistItem(
                      id: c.id, label: c.label, description: c.description, done: true),
              ],
              onConfirm: () {},
            ),
          ),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppPreTradeChecklistBlock(items: _checklist))),
        ],
      );
}

class _StrategyLibraryGallery extends StatelessWidget {
  const _StrategyLibraryGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppStrategyLibraryBlock',
        description: 'Strategy grid with native empty state.',
        tags: const <String>['journal'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppStrategyLibraryBlock(strategies: _strategies),
              fill: true),
          UiStateCase('empty',
              builder: (_) => AppStrategyLibraryBlock(
                    strategies: const <AppStrategy>[],
                    onCreate: () {},
                  ),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppStrategyLibraryBlock(strategies: _strategies))),
        ],
      );
}

class _VersionHistoryGallery extends StatelessWidget {
  const _VersionHistoryGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppVersionHistoryBlock',
        description: 'Strategy version history timeline.',
        tags: const <String>['journal'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppVersionHistoryBlock(versions: _versions),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppVersionHistoryBlock(versions: _versions))),
        ],
      );
}

// ---------------------------------------------------------------------------
// Market
// ---------------------------------------------------------------------------

class _WatchlistGallery extends StatelessWidget {
  const _WatchlistGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppWatchlistBlock',
        description: 'Watchlist grid with native loading/empty states.',
        tags: const <String>['market'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppWatchlistBlock(tickers: _tickers), fill: true),
          UiStateCase('loading',
              builder: (_) =>
                  const AppWatchlistBlock(tickers: <AppTicker>[], loading: true),
              fill: true),
          UiStateCase('empty',
              builder: (_) => AppWatchlistBlock(
                    tickers: const <AppTicker>[],
                    onAdd: () {},
                  ),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppWatchlistBlock(tickers: _tickers))),
        ],
      );
}

class _HeatmapGallery extends StatelessWidget {
  const _HeatmapGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppHeatmapBlock',
        description: 'Sector / symbol heatmap grid.',
        tags: const <String>['market'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppHeatmapBlock(entries: _tickers), fill: true),
          UiStateCase('dense',
              builder: (BuildContext ctx) => _dense(ctx, AppHeatmapBlock(entries: _tickers)),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppHeatmapBlock(entries: _tickers))),
        ],
      );
}

class _AlertsGallery extends StatelessWidget {
  const _AlertsGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppAlertsBlock',
        description: 'Price alert manager with native empty state.',
        tags: const <String>['market'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppAlertsBlock(alerts: _alerts, onCreate: () {}),
              fill: true),
          UiStateCase('empty',
              builder: (_) => AppAlertsBlock(
                    alerts: const <AppPriceAlert>[],
                    onCreate: () {},
                  ),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppAlertsBlock(alerts: _alerts))),
        ],
      );
}

class _NewsFeedGallery extends StatelessWidget {
  const _NewsFeedGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppNewsFeedBlock',
        description: 'Market news feed with native empty state.',
        tags: const <String>['market'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppNewsFeedBlock(items: _news), fill: true),
          UiStateCase('empty',
              builder: (_) => const AppNewsFeedBlock(items: <AppNewsItem>[]),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppNewsFeedBlock(items: _news))),
        ],
      );
}

class _SentimentGallery extends StatelessWidget {
  const _SentimentGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppSentimentBlock',
        description: 'Bullish / neutral / bearish crowd sentiment gauge.',
        tags: const <String>['market'],
        cases: <UiStateCase>[
          UiStateCase('bullish tilt',
              builder: (_) =>
                  const AppSentimentBlock(bullish: 62, neutral: 24, bearish: 14),
              fill: true),
          UiStateCase('bearish tilt',
              builder: (_) =>
                  const AppSentimentBlock(bullish: 18, neutral: 22, bearish: 60),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(
                  const AppSentimentBlock(bullish: 40, neutral: 30, bearish: 30))),
        ],
      );
}

class _MarketAiInsightsGallery extends StatelessWidget {
  const _MarketAiInsightsGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppAiInsightsBlock (market)',
        description:
            'AI insights rail from market_blocks.dart — native loading state.',
        tags: const <String>['market', 'ai'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => market.AppMarketAiInsightsBlock(insights: _insights),
              fill: true),
          UiStateCase('loading',
              builder: (_) => const market.AppMarketAiInsightsBlock(
                    insights: <AppAiInsight>[],
                    loading: true,
                  ),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(market.AppMarketAiInsightsBlock(insights: _insights))),
        ],
      );
}

class _SymbolHeaderGallery extends StatelessWidget {
  const _SymbolHeaderGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppSymbolHeaderBlock',
        description: 'Symbol detail header with timeframe switcher.',
        tags: const <String>['market'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppSymbolHeaderBlock(
                    ticker: _tickers.first,
                    timeframe: '1D',
                    onAddToWatchlist: () {},
                  ),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(
                  AppSymbolHeaderBlock(ticker: _tickers.first, timeframe: '1W'))),
        ],
      );
}

// ---------------------------------------------------------------------------
// Community
// ---------------------------------------------------------------------------

class _ComposerGallery extends StatelessWidget {
  const _ComposerGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppComposerBlock',
        description: 'Post composer with attach + submit actions.',
        tags: const <String>['community'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) =>
                  AppComposerBlock(me: _me, value: '', onAttach: () {}, onSubmit: () {}),
              fill: true),
          UiStateCase('submitting',
              builder: (_) => AppComposerBlock(
                    me: _me,
                    value: 'Reviewing today\'s open range breakout…',
                    submitting: true,
                  ),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppComposerBlock(me: _me))),
        ],
      );
}

class _FeedGallery extends StatelessWidget {
  const _FeedGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppFeedBlock',
        description: 'Social feed with native loading/empty states.',
        tags: const <String>['community'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppFeedBlock(posts: _posts), fill: true),
          UiStateCase('loading',
              builder: (_) => const AppFeedBlock(posts: <AppPost>[], loading: true),
              fill: true),
          UiStateCase('empty',
              builder: (_) => const AppFeedBlock(posts: <AppPost>[]), fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppFeedBlock(posts: _posts))),
        ],
      );
}

class _SuggestedTradersGallery extends StatelessWidget {
  const _SuggestedTradersGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppSuggestedTradersBlock',
        description: 'Traders to follow list.',
        tags: const <String>['community'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppSuggestedTradersBlock(traders: _traders),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppSuggestedTradersBlock(traders: _traders))),
        ],
      );
}

class _LeaderboardGallery extends StatelessWidget {
  const _LeaderboardGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppLeaderboardBlock',
        description: 'Ranked leaderboard with a period switcher.',
        tags: const <String>['community'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppLeaderboardBlock(entries: _leaderboard, period: 'Week'),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) =>
                  _mobile360(AppLeaderboardBlock(entries: _leaderboard, period: 'Month'))),
        ],
      );
}

class _CommentThreadGallery extends StatelessWidget {
  const _CommentThreadGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppCommentThreadBlock',
        description: 'Comment thread with inline reply composer.',
        tags: const <String>['community'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppCommentThreadBlock(comments: _comments, draft: ''),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppCommentThreadBlock(comments: _comments))),
        ],
      );
}

class _InboxGallery extends StatelessWidget {
  const _InboxGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppInboxBlock',
        description: 'Direct-message inbox list with native empty state.',
        tags: const <String>['community'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppInboxBlock(conversations: _conversations),
              fill: true),
          UiStateCase('empty',
              builder: (_) => const AppInboxBlock(conversations: <AppConversation>[]),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppInboxBlock(conversations: _conversations))),
        ],
      );
}

class _ChatThreadGallery extends StatelessWidget {
  const _ChatThreadGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppChatThreadBlock',
        description: 'Bubble thread + composer (bounded height: uses Expanded).',
        tags: const <String>['community'],
        minCaseWidth: 320,
        cases: <UiStateCase>[
          UiStateCase(
            'populated',
            builder: (_) => SizedBox(
              height: 360,
              child: AppChatThreadBlock(peer: _traders.first, messages: _chat),
            ),
            fill: true,
          ),
          UiStateCase(
            'mobile 360',
            builder: (_) => _mobile360(
              SizedBox(
                height: 360,
                child: AppChatThreadBlock(peer: _traders.first, messages: _chat),
              ),
            ),
          ),
        ],
      );
}

class _NotificationsGallery extends StatelessWidget {
  const _NotificationsGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppNotificationsBlock',
        description: 'Notification center with native "all caught up" empty state.',
        tags: const <String>['community'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppNotificationsBlock(
                    notifications: _notifications,
                    onMarkAllRead: () {},
                  ),
              fill: true),
          UiStateCase('empty',
              builder: (_) =>
                  const AppNotificationsBlock(notifications: <AppNotification>[]),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppNotificationsBlock(notifications: _notifications))),
        ],
      );
}

// ---------------------------------------------------------------------------
// Account
// ---------------------------------------------------------------------------

class _ProfileHeaderGallery extends StatelessWidget {
  const _ProfileHeaderGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppProfileHeaderBlock',
        description: 'Profile header: avatar, tier, stats and primary actions.',
        tags: const <String>['account'],
        cases: <UiStateCase>[
          UiStateCase('other trader',
              builder: (_) => AppProfileHeaderBlock(
                    trader: _traders.first,
                    onFollow: () {},
                    onMessage: () {},
                  ),
              fill: true),
          UiStateCase('me',
              builder: (_) =>
                  AppProfileHeaderBlock(trader: _me, isMe: true, onEdit: () {}),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppProfileHeaderBlock(trader: _traders.first))),
        ],
      );
}

class _PricingGallery extends StatelessWidget {
  const _PricingGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppPricingBlock',
        description: 'Pricing table, stacked on mobile.',
        tags: const <String>['account'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppPricingBlock(plans: _plans, onSelect: (_) {}),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppPricingBlock(plans: _plans))),
        ],
      );
}

class _BillingGallery extends StatelessWidget {
  const _BillingGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppBillingBlock',
        description: 'Subscription overview with usage meters.',
        tags: const <String>['account'],
        cases: <UiStateCase>[
          UiStateCase(
            'populated',
            builder: (_) => AppBillingBlock(
              tier: AppTier.premium,
              renewalLabel: 'Renews on Jul 12, 2025',
              usage: <Widget>[
                const UiProgressBar(value: 0.62, label: 'AI credits'),
                const UiProgressBar(value: 0.3, label: 'Seats'),
              ],
              onManage: () {},
              onUpgrade: () {},
            ),
            fill: true,
          ),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(const AppBillingBlock(
                  tier: AppTier.free, renewalLabel: 'Free plan'))),
        ],
      );
}

class _SettingsSectionGallery extends StatelessWidget {
  const _SettingsSectionGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppSettingsSectionBlock',
        description: 'Titled group of setting rows.',
        tags: const <String>['account'],
        cases: <UiStateCase>[
          UiStateCase(
            'populated',
            builder: (_) => AppSettingsSectionBlock(
              title: 'Notifications',
              description: 'Choose what you hear about.',
              children: <Widget>[
                UiSwitch(value: true, label: 'Price alerts', onChanged: (_) {}),
                UiSwitch(value: false, label: 'Weekly digest', onChanged: (_) {}),
              ],
            ),
            fill: true,
          ),
          UiStateCase(
            'mobile 360',
            builder: (_) => _mobile360(AppSettingsSectionBlock(
              title: 'Security',
              children: <Widget>[
                UiSwitch(value: true, label: 'Two-factor auth', onChanged: (_) {}),
              ],
            )),
          ),
        ],
      );
}

class _AchievementsGallery extends StatelessWidget {
  const _AchievementsGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppAchievementsBlock',
        description: 'Achievements wall grid.',
        tags: const <String>['account'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppAchievementsBlock(achievements: _achievements),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppAchievementsBlock(achievements: _achievements))),
        ],
      );
}

class _AuthGallery extends StatelessWidget {
  const _AuthGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppAuthBlock',
        description: 'Sign in / sign up card with native error and loading states.',
        tags: const <String>['account'],
        cases: <UiStateCase>[
          UiStateCase('sign in',
              builder: (_) => AppAuthBlock(
                    signUp: false,
                    email: 'trader@example.com',
                    onSubmit: () {},
                    onToggleMode: () {},
                  ),
              fill: true),
          UiStateCase('loading',
              builder: (_) => const AppAuthBlock(signUp: false, loading: true),
              fill: true),
          UiStateCase('error',
              builder: (_) => const AppAuthBlock(
                    signUp: false,
                    error: 'Incorrect email or password',
                  ),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(const AppAuthBlock(signUp: true))),
        ],
      );
}

class _OnboardingGallery extends StatelessWidget {
  const _OnboardingGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppOnboardingBlock',
        description: 'Onboarding step list with progress.',
        tags: const <String>['account'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppOnboardingBlock(
                    steps: _checklist,
                    currentStep: 1,
                    onContinue: () {},
                    onSkip: () {},
                  ),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(
                  AppOnboardingBlock(steps: _checklist, currentStep: 0))),
        ],
      );
}

// ---------------------------------------------------------------------------
// AI
// ---------------------------------------------------------------------------

class _AiChatGallery extends StatelessWidget {
  const _AiChatGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppAiChatBlock',
        description: 'AI assistant thread + composer (bounded height).',
        tags: const <String>['ai'],
        minCaseWidth: 320,
        cases: <UiStateCase>[
          UiStateCase(
            'populated',
            builder: (_) => SizedBox(
              height: 380,
              child: AppAiChatBlock(
                messages: _aiMessages,
                onSend: (_) {},
                prompts: _aiPrompts,
              ),
            ),
            fill: true,
          ),
          UiStateCase(
            'generating',
            builder: (_) => SizedBox(
              height: 380,
              child: AppAiChatBlock(
                messages: _aiMessages,
                onSend: (_) {},
                generating: true,
                onStop: () {},
              ),
            ),
            fill: true,
          ),
          UiStateCase(
            'empty',
            builder: (_) => SizedBox(
              height: 320,
              child: AppAiChatBlock(messages: const <AppAiMessage>[], onSend: (_) {}),
            ),
            fill: true,
          ),
          UiStateCase(
            'mobile 360',
            builder: (_) => _mobile360(
              SizedBox(
                height: 380,
                child: AppAiChatBlock(messages: _aiMessages, onSend: (_) {}),
              ),
            ),
          ),
        ],
      );
}

class _AiInsightsGallery extends StatelessWidget {
  const _AiInsightsGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppAiInsightsBlock (ai)',
        description: 'AI review card stack with native loading/empty states.',
        tags: const <String>['ai'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppAiInsightsBlock(insights: _insights), fill: true),
          UiStateCase('loading',
              builder: (_) =>
                  const AppAiInsightsBlock(insights: <AppAiInsight>[], loading: true),
              fill: true),
          UiStateCase('empty',
              builder: (_) => AppAiInsightsBlock(
                    insights: const <AppAiInsight>[],
                    onGenerate: () {},
                  ),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppAiInsightsBlock(insights: _insights))),
        ],
      );
}

class _StrategyGraphGallery extends StatelessWidget {
  const _StrategyGraphGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppStrategyGraphBlock',
        description: 'Strategy / ticker relationship graph with legend.',
        tags: const <String>['ai'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppStrategyGraphBlock(
                    nodes: _graphNodes,
                    links: _graphLinks,
                    height: 260,
                  ),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppStrategyGraphBlock(
                  nodes: _graphNodes, links: _graphLinks, height: 220))),
        ],
      );
}

// ---------------------------------------------------------------------------
// Chart
// ---------------------------------------------------------------------------

class _PriceChartGallery extends StatelessWidget {
  const _PriceChartGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppPriceChartBlock',
        description:
            'Price chart with quote header, timeframe/type switchers, native '
            'loading/empty via UiAsyncView.',
        tags: const <String>['chart'],
        minCaseWidth: 320,
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppPriceChartBlock(
                    candles: _candles,
                    ticker: _tickers.first,
                    entry: 224,
                    stopLoss: 218,
                    target: 236,
                  ),
              fill: true),
          UiStateCase('loading',
              builder: (_) => const AppPriceChartBlock(
                    candles: <AppCandle>[],
                    loading: true,
                  ),
              fill: true),
          UiStateCase('empty',
              builder: (_) => const AppPriceChartBlock(candles: <AppCandle>[]),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppPriceChartBlock(candles: _candles))),
        ],
      );
}

class _BacktestResultGallery extends StatelessWidget {
  const _BacktestResultGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppBacktestResultBlock',
        description: 'Backtest summary metrics with equity sparkline.',
        tags: const <String>['chart'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) =>
                  AppBacktestResultBlock(result: _backtest, onRerun: () {}, onSave: () {}),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppBacktestResultBlock(result: _backtest))),
        ],
      );
}

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

class _SearchGallery extends StatelessWidget {
  const _SearchGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppSearchBlock',
        description: 'Global search surface, native loading/empty via UiAsyncView.',
        tags: const <String>['search'],
        minCaseWidth: 320,
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppSearchBlock(
                    query: 'AAPL',
                    results: _searchResults,
                    onQueryChanged: (_) {},
                  ),
              fill: true),
          UiStateCase('loading',
              builder: (_) => AppSearchBlock(
                    query: 'AAPL',
                    results: const <AppSearchResult>[],
                    onQueryChanged: (_) {},
                    loading: true,
                  ),
              fill: true),
          UiStateCase('empty',
              builder: (_) => AppSearchBlock(
                    query: 'zzz',
                    results: const <AppSearchResult>[],
                    onQueryChanged: (_) {},
                  ),
              fill: true),
          UiStateCase('recent (no query)',
              builder: (_) => AppSearchBlock(
                    query: '',
                    results: const <AppSearchResult>[],
                    onQueryChanged: (_) {},
                    recent: const <String>['AAPL', 'breakout', '@quantqueen'],
                  ),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppSearchBlock(
                  query: 'AAPL', results: _searchResults, onQueryChanged: (_) {}))),
        ],
      );
}

class _SearchResultTileGallery extends StatelessWidget {
  const _SearchResultTileGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppSearchResultTile',
        description: 'A single search hit row.',
        tags: const <String>['search'],
        minCaseWidth: 280,
        cases: <UiStateCase>[
          for (final AppSearchResult r in _searchResults)
            UiStateCase(r.kind.name,
                builder: (_) => AppSearchResultTile(result: r, onTap: () {})),
          UiStateCase('mobile 360',
              builder: (_) =>
                  _mobile360(AppSearchResultTile(result: _searchResults.first))),
        ],
      );
}

// ---------------------------------------------------------------------------
// Enterprise
// ---------------------------------------------------------------------------

class _TeamMembersGallery extends StatelessWidget {
  const _TeamMembersGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppTeamMembersBlock',
        description: 'Team roster table with native loading/empty states.',
        tags: const <String>['enterprise'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppTeamMembersBlock(members: _team, onInvite: () {}),
              fill: true),
          UiStateCase('loading',
              builder: (_) =>
                  const AppTeamMembersBlock(members: <AppTeamMember>[], loading: true),
              fill: true),
          UiStateCase('empty',
              builder: (_) =>
                  AppTeamMembersBlock(members: const <AppTeamMember>[], onInvite: () {}),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppTeamMembersBlock(members: _team))),
        ],
      );
}

class _AuditLogGallery extends StatelessWidget {
  const _AuditLogGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppAuditLogBlock',
        description: 'Compliance audit trail with native loading/empty states.',
        tags: const <String>['enterprise'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppAuditLogBlock(entries: _auditEntries, onExport: () {}),
              fill: true),
          UiStateCase('loading',
              builder: (_) =>
                  const AppAuditLogBlock(entries: <AppAuditEntry>[], loading: true),
              fill: true),
          UiStateCase('empty',
              builder: (_) => const AppAuditLogBlock(entries: <AppAuditEntry>[]),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppAuditLogBlock(entries: _auditEntries))),
        ],
      );
}

class _ApiKeysGallery extends StatelessWidget {
  const _ApiKeysGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppApiKeysBlock',
        description: 'API key management with native loading/empty states.',
        tags: const <String>['enterprise'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppApiKeysBlock(keys: _apiKeys, onCreate: () {}),
              fill: true),
          UiStateCase('loading',
              builder: (_) => const AppApiKeysBlock(keys: <AppApiKey>[], loading: true),
              fill: true),
          UiStateCase('empty',
              builder: (_) => AppApiKeysBlock(keys: const <AppApiKey>[], onCreate: () {}),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppApiKeysBlock(keys: _apiKeys))),
        ],
      );
}

class _UsageGallery extends StatelessWidget {
  const _UsageGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'AppUsageBlock',
        description: 'Plan usage meters (AI credits, seats, storage).',
        tags: const <String>['enterprise'],
        cases: <UiStateCase>[
          UiStateCase('populated',
              builder: (_) => AppUsageBlock(metrics: _usage, onUpgrade: () {}),
              fill: true),
          UiStateCase('mobile 360',
              builder: (_) => _mobile360(AppUsageBlock(metrics: _usage))),
        ],
      );
}

// ---------------------------------------------------------------------------
// Shell & workspace
// ---------------------------------------------------------------------------

class _ShellGallery extends StatelessWidget {
  const _ShellGallery({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => UiStateGallery(
        index: index,
        name: 'Shell & workspace',
        description:
            'AppShell, AppSidebar, AppTopBar, AppBottomDock, AppNavTile, '
            'AppCommandPalette, AppWorkspacePane and AppWorkspaceThreePane, '
            'each bounded so they render sensibly inside the gallery grid.',
        tags: const <String>['shell', 'navigation'],
        minCaseWidth: 320,
        cases: <UiStateCase>[
          UiStateCase(
            'AppShell (desktop content area)',
            builder: (_) => SizedBox(
              height: 420,
              child: AppShell(
                sections: _navSections,
                selectedId: 'dashboard',
                onSelect: (_) {},
                trader: _me,
                tier: AppTier.premium,
                onSearch: () {},
                onNotifications: () {},
                unreadNotifications: 3,
                child: const UiEmptyState(
                  title: 'Page content',
                  message: 'The routed page renders here.',
                  icon: Icons.dashboard_outlined,
                ),
              ),
            ),
            fill: true,
          ),
          UiStateCase(
            'AppSidebar',
            builder: (_) => SizedBox(
              height: 360,
              child: AppSidebar(
                sections: _navSections,
                selectedId: 'journal',
                onSelect: (_) {},
              ),
            ),
          ),
          UiStateCase(
            'AppSidebar (collapsed)',
            builder: (_) => SizedBox(
              height: 360,
              child: AppSidebar(
                sections: _navSections,
                selectedId: 'journal',
                onSelect: (_) {},
                collapsed: true,
              ),
            ),
          ),
          UiStateCase(
            'AppTopBar',
            builder: (_) => AppTopBar(
              trader: _me,
              tier: AppTier.premium,
              onSearch: () {},
              onNotifications: () {},
              unread: 2,
            ),
            fill: true,
          ),
          UiStateCase(
            'AppBottomDock',
            builder: (_) => AppBottomDock(
              items: _navSections.first.items,
              selectedId: 'dashboard',
              onSelect: (_) {},
            ),
            fill: true,
          ),
          UiStateCase(
            'AppNavTile',
            builder: (_) => SizedBox(
              width: 220,
              child: AppNavTile(
                item: _navSections.first.items.first,
                selectedId: 'dashboard',
                onSelect: (_) {},
              ),
            ),
          ),
          UiStateCase(
            'AppCommandPalette',
            builder: (_) => AppCommandPalette(
              items: _commands,
              query: '',
              onQueryChanged: (_) {},
              onSelect: (_) {},
            ),
            fill: true,
          ),
          UiStateCase(
            'AppWorkspacePane',
            builder: (_) => SizedBox(
              height: 360,
              child: AppWorkspacePane(
                list: AppWatchlistBlock(tickers: _tickers),
                detail: AppSymbolHeaderBlock(ticker: _tickers.first, timeframe: '1D'),
                hasSelection: true,
                onClearSelection: () {},
                listTitle: 'Watchlist',
                detailTitle: _tickers.first.symbol,
              ),
            ),
            fill: true,
          ),
          UiStateCase(
            'AppWorkspaceThreePane',
            builder: (_) => SizedBox(
              height: 360,
              child: AppWorkspaceThreePane(
                rail: const UiEmptyState(title: 'Filters', icon: Icons.filter_list),
                list: AppWatchlistBlock(tickers: _tickers),
                detail: AppSymbolHeaderBlock(ticker: _tickers.first, timeframe: '1D'),
                hasSelection: true,
              ),
            ),
            fill: true,
          ),
        ],
      );
}

// ---------------------------------------------------------------------------
// Shared sample data
// ---------------------------------------------------------------------------

final AppTrader _me = const AppTrader(
  id: 'me',
  handle: 'you',
  displayName: 'You',
  avatarUrl: null,
  bio: 'Swing trading momentum breakouts. Building in public.',
  tier: AppTier.premium,
  followers: 1280,
  following: 96,
  winRate: 61,
  verified: false,
);

final List<AppTrader> _traders = <AppTrader>[
  const AppTrader(
    id: 't1',
    handle: 'quantqueen',
    displayName: 'Quant Queen',
    bio: 'Systematic equities. Options overlays.',
    tier: AppTier.enterprise,
    followers: 48200,
    following: 210,
    winRate: 68,
    verified: true,
    isFollowing: true,
    tradingStyle: 'Swing',
  ),
  const AppTrader(
    id: 't2',
    handle: 'macro_max',
    displayName: 'Macro Max',
    bio: 'Rates, FX and crude.',
    tier: AppTier.free,
    followers: 3900,
    following: 540,
    winRate: 54,
    tradingStyle: 'Macro',
  ),
  const AppTrader(
    id: 't3',
    handle: 'daytrader_dee',
    displayName: 'Dee',
    tier: AppTier.premium,
    followers: 15300,
    following: 88,
    winRate: 59,
    isFollowing: false,
    tradingStyle: 'Day',
  ),
];

final List<AppTrade> _trades = <AppTrade>[
  AppTrade(
    id: 'tr1',
    ticker: 'AAPL',
    side: AppSide.long,
    entry: 220.10,
    exit: 227.40,
    openedAt: DateTime(2025, 5, 1, 9, 40),
    closedAt: DateTime(2025, 5, 1, 15, 55),
    stopLoss: 216.5,
    target: 230,
    size: 100,
    pnl: 730,
    pnlPercent: 3.3,
    rMultiple: 2.1,
    outcome: AppOutcome.win,
    strategy: 'Opening range breakout',
    tags: const <String>['breakout', 'tech'],
    notes: 'Clean break of the opening range with volume confirmation.',
    screenshotUrl: 'https://picsum.photos/seed/aapl/640/360',
    psychologyScore: 8,
  ),
  AppTrade(
    id: 'tr2',
    ticker: 'TSLA',
    side: AppSide.short,
    entry: 182.5,
    exit: 189.2,
    openedAt: DateTime(2025, 5, 2, 10, 5),
    closedAt: DateTime(2025, 5, 2, 11, 30),
    stopLoss: 190,
    target: 172,
    size: 40,
    pnl: -268,
    pnlPercent: -3.6,
    rMultiple: -0.9,
    outcome: AppOutcome.loss,
    strategy: 'Fade the gap',
    tags: const <String>['gap', 'ev'],
    notes: 'Stopped out — squeeze on delivery headline.',
    psychologyScore: 4,
  ),
  AppTrade(
    id: 'tr3',
    ticker: 'MSFT',
    side: AppSide.long,
    entry: 411.2,
    exit: null,
    openedAt: DateTime(2025, 5, 5, 9, 45),
    stopLoss: 405,
    target: 428,
    size: 60,
    pnl: 96,
    pnlPercent: 0.4,
    outcome: AppOutcome.open,
    strategy: 'Trend continuation',
    tags: const <String>['trend'],
  ),
];

final List<AppStrategy> _strategies = <AppStrategy>[
  AppStrategy(
    id: 's1',
    name: 'Opening range breakout',
    summary: 'Trade the break of the first 15-minute range on volume.',
    category: 'Momentum',
    isPublic: true,
    isFavorite: true,
    trades: 84,
    winRate: 0.63,
    avgR: 1.4,
    netPnl: 18240,
    updatedAt: DateTime(2025, 4, 20),
    versionCount: 4,
    equityCurve: const <double>[0, 4, 3, 8, 12, 10, 18],
  ),
  AppStrategy(
    id: 's2',
    name: 'Mean reversion VWAP',
    summary: 'Fade extremes back to VWAP in range-bound tape.',
    category: 'Reversion',
    trades: 51,
    winRate: 0.57,
    avgR: 0.9,
    netPnl: 6120,
    updatedAt: DateTime(2025, 3, 2),
    versionCount: 2,
    equityCurve: const <double>[0, 1, 2, 1.5, 3, 4, 6],
  ),
];

final List<AppStrategyVersion> _versions = <AppStrategyVersion>[
  AppStrategyVersion(
      id: 'v3',
      version: 3,
      savedAt: DateTime(2025, 4, 20),
      author: 'You',
      note: 'Tightened stop rules',
      isCurrent: true),
  AppStrategyVersion(
      id: 'v2', version: 2, savedAt: DateTime(2025, 2, 12), author: 'You'),
  AppStrategyVersion(
      id: 'v1',
      version: 1,
      savedAt: DateTime(2025, 1, 3),
      author: 'You',
      note: 'Initial draft'),
];

final List<AppTicker> _tickers = <AppTicker>[
  const AppTicker(
    symbol: 'AAPL',
    name: 'Apple Inc.',
    price: 227.10,
    changePercent: 1.8,
    spark: <double>[220, 222, 219, 224, 226, 227],
    category: 'Technology',
    isFavorite: true,
  ),
  const AppTicker(
    symbol: 'TSLA',
    name: 'Tesla, Inc.',
    price: 184.30,
    changePercent: -2.4,
    spark: <double>[190, 188, 186, 187, 185, 184],
    category: 'Automotive',
  ),
  const AppTicker(
    symbol: 'BTC',
    name: 'Bitcoin',
    price: 64120,
    changePercent: 3.1,
    spark: <double>[60000, 61200, 62800, 63000, 63900, 64120],
    category: 'Crypto',
    currencySymbol: '',
  ),
  const AppTicker(
    symbol: 'MSFT',
    name: 'Microsoft Corp.',
    price: 418.60,
    changePercent: 0.6,
    spark: <double>[410, 412, 415, 414, 417, 418.6],
    category: 'Technology',
  ),
];

final List<AppPriceAlert> _alerts = <AppPriceAlert>[
  const AppPriceAlert(
      id: 'a1', symbol: 'AAPL', targetPrice: 230, above: true, currentPrice: 227.1),
  const AppPriceAlert(
      id: 'a2',
      symbol: 'TSLA',
      targetPrice: 175,
      above: false,
      currentPrice: 184.3,
      active: false,
      triggeredAt: null),
];

final List<AppStat> _stats = <AppStat>[
  AppStat(label: 'Net P/L', value: 18240, delta: 12.4, icon: Icons.trending_up),
  AppStat(label: 'Win rate', value: 63, suffix: '%', delta: 2.1),
  AppStat(label: 'Avg R', value: 1.4, delta: -0.2),
  AppStat(label: 'Trades', value: 84, delta: 6),
];

final List<AppSeriesPoint> _series = <AppSeriesPoint>[
  for (int i = 0; i < 12; i++)
    AppSeriesPoint(label: 'W$i', value: 10000 + i * 650 + (i.isEven ? 300 : -150)),
];

final List<AppDayPnl> _days = <AppDayPnl>[
  for (int i = 0; i < 28; i++)
    AppDayPnl(
      date: DateTime(2025, 5, 1).add(Duration(days: i)),
      pnl: (i % 5 == 0) ? -180.0 : (i * 23.0 - 120),
      trades: i % 3,
    ),
];

final List<UiDonutSlice> _slices = <UiDonutSlice>[
  const UiDonutSlice(label: 'Technology', value: 42),
  const UiDonutSlice(label: 'Crypto', value: 21),
  const UiDonutSlice(label: 'Macro', value: 18),
  const UiDonutSlice(label: 'Cash', value: 19),
];

final List<UiBarListItem> _barItems = <UiBarListItem>[
  const UiBarListItem(label: 'Breakouts', value: 12400),
  const UiBarListItem(label: 'Reversion', value: 6100),
  const UiBarListItem(label: 'News plays', value: -1800),
];

final List<AppNewsItem> _news = <AppNewsItem>[
  AppNewsItem(
    id: 'n1',
    headline: 'Apple beats on services revenue, guides above street',
    source: 'Reuters',
    publishedAt: DateTime.now().subtract(const Duration(minutes: 40)),
    sentimentScore: 0.6,
    tickers: const <String>['AAPL'],
    summary: 'Q2 services growth outpaces hardware for the third quarter.',
  ),
  AppNewsItem(
    id: 'n2',
    headline: 'Fed holds rates, signals cautious path forward',
    source: 'Bloomberg',
    publishedAt: DateTime.now().subtract(const Duration(hours: 3)),
    sentimentScore: -0.1,
    tickers: const <String>['SPY'],
  ),
];

final List<AppAiInsight> _insights = <AppAiInsight>[
  AppAiInsight(
    id: 'i1',
    title: 'Your best setups happen before 10:30am',
    body: '72% of winning trades this month were opened in the first hour.',
    confidence: 0.82,
    sentimentScore: 0.4,
    tickers: const <String>['AAPL', 'MSFT'],
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  AppAiInsight(
    id: 'i2',
    title: 'Revenge trading risk detected',
    body: 'Position size increased 3x after Tuesday\'s loss on TSLA.',
    confidence: 0.65,
    sentimentScore: -0.3,
    tickers: const <String>['TSLA'],
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
];

final List<AppPost> _posts = <AppPost>[
  AppPost(
    id: 'p1',
    author: _traders[0],
    body: 'Closed AAPL for +2.1R off the opening range. Textbook.',
    createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
    type: 'trade',
    tickers: const <String>['AAPL'],
    likes: 84,
    comments: 12,
    liked: true,
  ),
  AppPost(
    id: 'p2',
    author: _traders[1],
    body: 'Fed day. Staying flat until the dust settles.',
    createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    likes: 31,
    comments: 4,
  ),
];

final List<AppComment> _comments = <AppComment>[
  AppComment(
    id: 'c1',
    author: _traders[1],
    body: 'Great execution, what was your size?',
    createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
    likes: 3,
  ),
  AppComment(
    id: 'c2',
    author: _traders[2],
    body: '100 shares, sized down after the loss Tuesday.',
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    liked: true,
  ),
];

final List<AppConversation> _conversations = <AppConversation>[
  AppConversation(
    id: 'conv1',
    peer: _traders[0],
    lastMessage: 'Sent you the backtest results',
    lastMessageAt: DateTime.now().subtract(const Duration(minutes: 8)),
    unread: 2,
  ),
  AppConversation(
    id: 'conv2',
    peer: _traders[2],
    lastMessage: 'Thanks for the tip on ORB!',
    lastMessageAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
];

final List<AppChatMessage> _chat = <AppChatMessage>[
  AppChatMessage(
      id: 'm1',
      body: 'Hey — saw your AAPL trade, nice work.',
      fromMe: false,
      sentAt: DateTime.now().subtract(const Duration(minutes: 10))),
  AppChatMessage(
      id: 'm2',
      body: 'Thanks! Clean breakout with volume.',
      fromMe: true,
      sentAt: DateTime.now().subtract(const Duration(minutes: 9))),
  AppChatMessage(
      id: 'm3',
      body: 'Sending the chart now…',
      fromMe: true,
      sentAt: DateTime.now(),
      pending: true),
];

final List<AppNotification> _notifications = <AppNotification>[
  AppNotification(
    id: 'note1',
    title: 'AAPL hit your alert at \$227.10',
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    icon: Icons.notifications_active,
    category: 'alert',
  ),
  AppNotification(
    id: 'note2',
    title: 'Quant Queen liked your trade',
    body: 'AAPL · +2.1R',
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    read: true,
    category: 'social',
  ),
];

final List<MapEntry<AppTrader, double>> _leaderboard = <MapEntry<AppTrader, double>>[
  MapEntry<AppTrader, double>(_traders[0], 24.6),
  MapEntry<AppTrader, double>(_traders[2], 18.2),
  MapEntry<AppTrader, double>(_traders[1], 9.4),
];

final List<AppPlan> _plans = <AppPlan>[
  const AppPlan(
    tier: AppTier.free,
    priceLabel: '\$0',
    features: <String>['50 trades / month', 'Basic journal', 'Community feed'],
  ),
  const AppPlan(
    tier: AppTier.premium,
    priceLabel: '\$19',
    features: <String>['Unlimited trades', 'AI insights', 'Strategy library'],
    highlighted: true,
    current: true,
  ),
  const AppPlan(
    tier: AppTier.enterprise,
    priceLabel: '\$49',
    features: <String>['Team seats', 'Audit log', 'API access'],
  ),
];

final List<AppChecklistItem> _checklist = <AppChecklistItem>[
  const AppChecklistItem(
      id: 'c1', label: 'Checked economic calendar', done: true),
  const AppChecklistItem(
      id: 'c2', label: 'Defined stop and target', done: true),
  const AppChecklistItem(
      id: 'c3', label: 'Position sized to 1R risk', done: false),
  const AppChecklistItem(
      id: 'c4', label: 'No revenge trading', description: 'Cooldown after a loss', done: false),
];

final List<AppAchievement> _achievements = <AppAchievement>[
  const AppAchievement(
      id: 'ach1', title: '10-win streak', icon: Icons.local_fire_department, unlocked: true),
  const AppAchievement(
      id: 'ach2', title: 'Journaled 100 trades', icon: Icons.book, unlocked: true),
  const AppAchievement(
      id: 'ach3',
      title: 'Risk manager',
      icon: Icons.shield_outlined,
      unlocked: false,
      progress: 0.6),
];

final List<AppAiMessage> _aiMessages = <AppAiMessage>[
  const AppAiMessage(
      id: 'am1', role: AppAiRole.user, body: 'Summarise my week.'),
  const AppAiMessage(
    id: 'am2',
    role: AppAiRole.assistant,
    body: 'You closed 6 trades, +\$1,240 net, 67% win rate. Best setup: '
        'opening range breakouts.',
    sources: <String>['journal:this_week'],
  ),
];

final List<AppAiPrompt> _aiPrompts = <AppAiPrompt>[
  const AppAiPrompt(
      label: 'Review last trade', prompt: 'Review my last trade', icon: Icons.rate_review_outlined),
  const AppAiPrompt(
      label: 'Stress test strategy', prompt: 'Stress test my ORB strategy', icon: Icons.science_outlined),
];

final List<AppGraphNode> _graphNodes = <AppGraphNode>[
  const AppGraphNode(id: 'orb', label: 'ORB', group: 'Strategy', intent: UiIntent.primary, weight: 2),
  const AppGraphNode(id: 'aapl', label: 'AAPL', group: 'Ticker', intent: UiIntent.bullish),
  const AppGraphNode(id: 'tsla', label: 'TSLA', group: 'Ticker', intent: UiIntent.bearish),
  const AppGraphNode(id: 'vwap', label: 'VWAP reversion', group: 'Strategy', intent: UiIntent.info),
];

final List<AppGraphLink> _graphLinks = <AppGraphLink>[
  const AppGraphLink(source: 'orb', target: 'aapl', strength: 0.9),
  const AppGraphLink(source: 'orb', target: 'tsla', strength: 0.4),
  const AppGraphLink(source: 'vwap', target: 'tsla', strength: 0.6, label: 'fades'),
];

final List<AppCandle> _candles = <AppCandle>[
  for (int i = 0; i < 30; i++)
    AppCandle(
      time: DateTime(2025, 5, 1).add(Duration(days: i)),
      open: 220 + i * 0.4,
      high: 222 + i * 0.4,
      low: 218 + i * 0.4,
      close: 221 + i * 0.4,
      volume: 1200000 + i * 3000,
    ),
];

final AppBacktestResult _backtest = AppBacktestResult(
  id: 'bt1',
  name: 'ORB v3 — 2 year backtest',
  netPnl: 42800,
  winRate: 0.61,
  trades: 312,
  equityCurve: <double>[for (int i = 0; i < 24; i++) i * 1780.0 - (i.isOdd ? 400 : 0)],
  maxDrawdown: 0.14,
  profitFactor: 1.9,
  sharpe: 1.4,
  runAt: DateTime.now().subtract(const Duration(hours: 6)),
);

final List<AppSearchResult> _searchResults = <AppSearchResult>[
  const AppSearchResult(
      id: 'r1', title: 'AAPL', kind: AppSearchKind.ticker, subtitle: 'Apple Inc.', meta: '227.10'),
  const AppSearchResult(
      id: 'r2',
      title: 'Opening range breakout',
      kind: AppSearchKind.strategy,
      subtitle: '84 trades · 63% win rate'),
  const AppSearchResult(
      id: 'r3',
      title: 'Quant Queen',
      kind: AppSearchKind.trader,
      subtitle: '@quantqueen',
      avatarUrl: null),
  const AppSearchResult(
      id: 'r4',
      title: 'Closed AAPL +2.1R',
      kind: AppSearchKind.post,
      subtitle: 'Quant Queen · 20m ago'),
];

final List<AppTeamMember> _team = <AppTeamMember>[
  AppTeamMember(
    id: 'tm1',
    name: 'You',
    email: 'you@traderhub.io',
    role: AppTeamRole.owner,
    status: AppMemberStatus.active,
    lastActiveAt: DateTime.now(),
  ),
  AppTeamMember(
    id: 'tm2',
    name: 'Dee Park',
    email: 'dee@traderhub.io',
    role: AppTeamRole.analyst,
    status: AppMemberStatus.invited,
  ),
  AppTeamMember(
    id: 'tm3',
    name: 'Max Rivera',
    email: 'max@traderhub.io',
    role: AppTeamRole.member,
    status: AppMemberStatus.suspended,
    lastActiveAt: DateTime.now().subtract(const Duration(days: 40)),
  ),
];

final List<AppAuditEntry> _auditEntries = <AppAuditEntry>[
  AppAuditEntry(
    id: 'au1',
    actor: 'You',
    action: 'Revoked API key',
    at: DateTime.now().subtract(const Duration(hours: 2)),
    target: 'key_prod_1',
    ip: '82.14.3.10',
  ),
  AppAuditEntry(
    id: 'au2',
    actor: 'Dee Park',
    action: 'Invited teammate',
    at: DateTime.now().subtract(const Duration(days: 1)),
    target: 'max@traderhub.io',
  ),
];

final List<AppApiKey> _apiKeys = <AppApiKey>[
  AppApiKey(
    id: 'k1',
    label: 'Production sync',
    maskedKey: 'sk_live_••••••1234',
    createdAt: DateTime(2025, 1, 4),
    lastUsedAt: DateTime.now().subtract(const Duration(minutes: 30)),
    scopes: const <String>['trades:read'],
  ),
  AppApiKey(
    id: 'k2',
    label: 'Old broker export',
    maskedKey: 'sk_live_••••••0098',
    createdAt: DateTime(2024, 8, 1),
    revoked: true,
    scopes: const <String>['trades:read', 'trades:write'],
  ),
];

final List<AppUsageMetric> _usage = <AppUsageMetric>[
  const AppUsageMetric(label: 'AI credits', used: 620, limit: 1000, unit: 'credits'),
  const AppUsageMetric(label: 'Seats', used: 4, limit: 5, unit: 'seats'),
  const AppUsageMetric(label: 'Storage', used: 92, limit: 100, unit: 'GB'),
];

final List<AppNavSection> _navSections = <AppNavSection>[
  AppNavSection(
    title: null,
    items: <AppNavItem>[
      const AppNavItem(id: 'dashboard', label: 'Dashboard', icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard),
      const AppNavItem(id: 'journal', label: 'Journal', icon: Icons.menu_book_outlined, selectedIcon: Icons.menu_book),
      const AppNavItem(id: 'market', label: 'Market', icon: Icons.show_chart, badgeCount: 2),
      const AppNavItem(id: 'community', label: 'Community', icon: Icons.forum_outlined),
      const AppNavItem(id: 'ai', label: 'AI coach', icon: Icons.auto_awesome, tierLocked: true),
    ],
  ),
  AppNavSection(
    title: 'Account',
    items: <AppNavItem>[
      const AppNavItem(id: 'settings', label: 'Settings', icon: Icons.settings_outlined),
    ],
  ),
];

final List<AppCommandItem> _commands = <AppCommandItem>[
  const AppCommandItem(id: 'cmd1', label: 'New trade', icon: Icons.add_circle_outline, group: 'Actions', hint: '⌘N'),
  const AppCommandItem(id: 'cmd2', label: 'Go to dashboard', icon: Icons.dashboard_outlined, group: 'Navigate'),
  const AppCommandItem(id: 'cmd3', label: 'Search traders', icon: Icons.person_search_outlined, group: 'Navigate'),
];
