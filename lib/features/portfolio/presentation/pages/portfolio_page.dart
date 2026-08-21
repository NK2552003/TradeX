import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/portfolio/data/repositories/portfolio_repository.dart';

/// Performance analyzer tabs.
enum _PortfolioView { overview, breakdown, calendar }

/// Portfolio analyzer: equity, risk, breakdowns by symbol/playbook/session and
/// a P/L calendar. Every number is derived by [PortfolioRepository] from the
/// journal, so the backend only has to replace the snapshot query.
class PortfolioPage extends StatefulWidget {
  const PortfolioPage({
    super.key,
    this.repository,
    this.onOpenJournal,
    this.onOpenStrategies,
    this.onOpenTrade,
  });

  final PortfolioRepository? repository;
  final VoidCallback? onOpenJournal;
  final VoidCallback? onOpenStrategies;

  /// Opens a single trade — used by the best/worst cards.
  final ValueChanged<AppTrade>? onOpenTrade;

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  late final PortfolioRepository _repo =
      widget.repository ?? PortfolioRepositoryImpl();

  PortfolioSnapshot? _snapshot;
  List<String> _ranges = const <String>[];
  String _range = 'ALL';
  AppDayPnl? _selectedDay;
  _PortfolioView _view = _PortfolioView.overview;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final List<String> ranges = await _repo.getRanges();
    if (!mounted) return;
    setState(() {
      _ranges = ranges;
      if (!ranges.contains(_range) && ranges.isNotEmpty) _range = ranges.last;
    });
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final PortfolioSnapshot snapshot = await _repo.getSnapshot(range: _range);
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _loading = false;
      _selectedDay = null;
    });
  }

  void _setRange(String range) {
    if (range == _range) return;
    setState(() => _range = range);
    _load();
  }

  /// Playbooks ranked by net P/L — powers the head-to-head comparison.
  List<AppStrategy> _rankedStrategies(PortfolioSnapshot snapshot) {
    final List<AppStrategy> ranked = <AppStrategy>[...snapshot.strategies]
      ..sort((AppStrategy a, AppStrategy b) => b.netPnl.compareTo(a.netPnl));
    return ranked;
  }

  @override
  Widget build(BuildContext context) {
    final PortfolioSnapshot? snapshot = _snapshot;

    return AppPageBlock(
      title: 'Portfolio analyzer',
      subtitle: snapshot == null
          ? 'Crunching your journal…'
          : '${AppTokens.percent(snapshot.winRate)} win rate · ${AppTokens.rr(snapshot.avgR)} avg R · '
                '${AppTokens.percent(snapshot.maxDrawdownPercent)} max drawdown',
      scrollable: false,
      actions: <Widget>[
        UiButton(
          label: 'Open journal',
          variant: UiVariant.outline,
          leadingIcon: Icons.menu_book_outlined,
          expandOnMobile: false,
          hideLabelOnMobile: true,
          onPressed: widget.onOpenJournal,
        ),
        UiButton(
          label: 'Refresh',
          leadingIcon: Icons.refresh_rounded,
          expandOnMobile: false,
          loading: _loading,
          onPressed: _load,
        ),
      ],
      child: Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: context.sp(context.ui.spacing.md),
              runSpacing: context.sp(context.ui.spacing.sm),
              children: <Widget>[
                UiToggleGroup<_PortfolioView>(
                  options: const <UiToggleOption<_PortfolioView>>[
                    UiToggleOption<_PortfolioView>(
                      value: _PortfolioView.overview,
                      label: 'Overview',
                      icon: Icons.speed_rounded,
                    ),
                    UiToggleOption<_PortfolioView>(
                      value: _PortfolioView.breakdown,
                      label: 'Breakdown',
                      icon: Icons.pie_chart_outline_rounded,
                    ),
                    UiToggleOption<_PortfolioView>(
                      value: _PortfolioView.calendar,
                      label: 'Calendar',
                      icon: Icons.calendar_month_rounded,
                    ),
                  ],
                  value: _view,
                  expand: context.uiRes.isMobile,
                  onChanged: (_PortfolioView view) =>
                      setState(() => _view = view),
                ),
                if (_ranges.isNotEmpty)
                  UiToggleGroup<String>(
                    options: <UiToggleOption<String>>[
                      for (final String range in _ranges)
                        UiToggleOption<String>(value: range, label: range),
                    ],
                    value: _range,
                    size: UiSize.sm,
                    expand: context.uiRes.isMobile,
                    onChanged: _setRange,
                  ),
              ],
            ),
            UiGap.v(context.ui.spacing.lg),
            Expanded(
              child: snapshot == null
                  ? _skeleton()
                  : switch (_view) {
                      _PortfolioView.overview => _overview(snapshot),
                      _PortfolioView.breakdown => _breakdown(snapshot),
                      _PortfolioView.calendar => _calendar(snapshot),
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _skeleton() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const AppStatGridBlock(stats: <AppStat>[], loading: true),
        UiGap.v(context.ui.spacing.lg),
        UiCard(child: UiSkeleton(height: context.sz(280))),
      ],
    ),
  );

  Widget _overview(PortfolioSnapshot s) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppStatGridBlock(stats: s.stats, loading: _loading),
        UiGap.v(context.ui.spacing.lg),
        AppDashboardLayoutBlock(
          main: <Widget>[
            AppFadeIn(
              child: AppEquityCurveBlock(
                series: s.equity,
                title: 'Equity curve',
                ranges: _ranges,
                onRangeChanged: _setRange,
              ),
            ),
            AppFadeIn(
              delay: AppMotion.step * 2,
              child: AppBreakdownBlock(
                items: s.bySymbol,
                title: 'P/L by instrument',
              ),
            ),
            if (s.best != null && s.worst != null)
              AppFadeIn(
                delay: AppMotion.step * 3,
                child: UiCard(
                  title: 'Outliers',
                  subtitle: 'The trades that moved the curve most.',
                  child: UiCardGrid(
                    mobileColumns: 1,
                    tabletColumns: 2,
                    desktopColumns: 2,
                    largeColumns: 2,
                    childAspectRatio: context.uiRes.pick<double>(
                      mobile: 1.9,
                      tablet: 1.7,
                      desktop: 1.9,
                    ),
                    children: <Widget>[
                      AppExtremeTradeCard(
                        trade: s.best!,
                        best: true,
                        onTap: widget.onOpenTrade == null
                            ? null
                            : () => widget.onOpenTrade!(s.best!),
                      ),
                      AppExtremeTradeCard(
                        trade: s.worst!,
                        best: false,
                        onTap: widget.onOpenTrade == null
                            ? null
                            : () => widget.onOpenTrade!(s.worst!),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          side: <Widget>[
            AppWinRateCard(
              winRate: s.winRate,
              wins: s.wins,
              losses: s.losses,
              breakeven: s.breakeven,
            ),
            AppRiskRewardCard(avgR: s.avgR),
            AppDrawdownCard(
              maxDrawdownPercent: s.maxDrawdownPercent,
              series: s.drawdown,
            ),
            AppStreakCard(days: s.streak),
          ],
        ),
      ],
    ),
  );

  Widget _breakdown(PortfolioSnapshot s) {
    final List<AppStrategy> ranked = _rankedStrategies(s);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppDashboardLayoutBlock(
            main: <Widget>[
              AppFadeIn(
                child: AppBreakdownBlock(
                  items: s.byStrategy,
                  title: 'P/L by playbook',
                ),
              ),
              AppFadeIn(
                delay: AppMotion.step * 2,
                child: AppBreakdownBlock(
                  items: s.bySession,
                  title: 'P/L by session',
                ),
              ),
              if (ranked.length >= 2)
                AppFadeIn(
                  delay: AppMotion.step * 3,
                  child: UiCard(
                    title: 'Best vs. worst playbook',
                    subtitle: 'Where to add size and where to cut it.',
                    trailing: UiButton(
                      label: 'Workbench',
                      size: UiSize.sm,
                      variant: UiVariant.outline,
                      trailingIcon: Icons.arrow_forward_rounded,
                      expandOnMobile: false,
                      onPressed: widget.onOpenStrategies,
                    ),
                    child: AppStrategyComparisonCard(
                      a: ranked.first,
                      b: ranked.last,
                    ),
                  ),
                ),
            ],
            side: <Widget>[
              AppAllocationBlock(
                slices: s.allocation,
                title: 'Capital at work',
                totalLabel: 'Deployed',
              ),
              UiCard(
                title: 'Playbook league table',
                child: ranked.isEmpty
                    ? const UiEmptyState(
                        title: 'No playbooks yet',
                        message: 'Tag your trades to unlock this breakdown.',
                        icon: Icons.account_tree_outlined,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          for (final AppStrategy strategy in ranked.take(5))
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: context.sp(context.ui.spacing.sm),
                              ),
                              child: AppStrategyPerformanceCard(
                                strategy: strategy,
                                onTap: widget.onOpenStrategies,
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _calendar(PortfolioSnapshot s) {
    final AppDayPnl? day = _selectedDay;
    final double maxAbs = s.days.fold<double>(
      0,
      (double m, AppDayPnl d) => d.pnl.abs() > m ? d.pnl.abs() : m,
    );
    final List<AppDayPnl> green = s.days
        .where((AppDayPnl d) => d.pnl > 0)
        .toList(growable: false);
    final List<AppDayPnl> red = s.days
        .where((AppDayPnl d) => d.pnl < 0)
        .toList(growable: false);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppFadeIn(
            child: AppPnlCalendarBlock(
              days: s.days,
              title: 'Daily P/L · $_range',
              onDayTap: (AppDayPnl value) =>
                  setState(() => _selectedDay = value),
            ),
          ),
          UiGap.v(context.ui.spacing.lg),
          AppDashboardLayoutBlock(
            main: <Widget>[
              UiCard(
                title: day == null
                    ? 'Day detail'
                    : AppTokens.shortDate(day.date),
                subtitle: day == null
                    ? 'Tap a day on the calendar.'
                    : '${day.trades} trade${day.trades == 1 ? '' : 's'} closed',
                child: day == null
                    ? const UiEmptyState(
                        title: 'Nothing selected',
                        message:
                            'Pick a day to see the realised result and volume.',
                        icon: Icons.touch_app_outlined,
                      )
                    : AppCalendarDayCard(day: day, maxAbsPnl: maxAbs),
              ),
            ],
            side: <Widget>[
              UiCard(
                title: 'Consistency',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    UiCategoryBar(
                      segments: <UiCategorySegment>[
                        UiCategorySegment(
                          value: green.length.toDouble(),
                          label: 'Green days',
                          color: context.uiColors.bullish,
                        ),
                        UiCategorySegment(
                          value: red.length.toDouble(),
                          label: 'Red days',
                          color: context.uiColors.bearish,
                        ),
                        UiCategorySegment(
                          value: (s.days.length - green.length - red.length)
                              .toDouble(),
                          label: 'Flat',
                          color: context.uiColors.foregroundSubtle,
                        ),
                      ],
                    ),
                    UiGap.v(context.ui.spacing.md),
                    UiTracker(
                      blocks: <UiTrackerBlock>[
                        for (final AppDayPnl d in s.days.take(28))
                          UiTrackerBlock(
                            intent: AppTokens.plIntent(d.pnl),
                            tooltip:
                                '${AppTokens.shortDate(d.date)} · ${AppTokens.signedMoney(d.pnl)}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              AppStreakCard(days: s.streak, title: 'Last 14 sessions'),
            ],
          ),
        ],
      ),
    );
  }
}
