import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../cards/journal_cards.dart';
import '../cards/portfolio_cards.dart';
import '../cards/watchlist_cards.dart';
import '../models/app_models.dart';
import '../motion/app_motion.dart';
import '../theme/app_tokens.dart';

/// Responsive grid of KPI tiles — 1 col phone, 2 tablet, 4 desktop.
class AppStatGridBlock extends StatelessWidget {
  const AppStatGridBlock({
    super.key,
    required this.stats,
    this.loading = false,
  });

  final List<AppStat> stats;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return UiCardGrid(
        childAspectRatio: context.uiRes.pick<double>(
          mobile: 1.5,
          tablet: 1.35,
          desktop: 1.35,
        ),
        desktopColumns: 4,
        largeColumns: 4,
        children: const <Widget>[
          AppStatCardSkeleton(),
          AppStatCardSkeleton(),
          AppStatCardSkeleton(),
          AppStatCardSkeleton(),
        ],
      );
    }
    return UiCardGrid(
      childAspectRatio: context.uiRes.pick<double>(
        mobile: 1.5,
        tablet: 1.35,
        desktop: 1.35,
      ),
      desktopColumns: 4,
      largeColumns: 4,
      children: <Widget>[
        for (int i = 0; i < stats.length; i++)
          AppFadeIn(
            delay: Duration(milliseconds: 60 * i),
            child: AppStatCard(stat: stats[i]),
          ),
      ],
    );
  }
}

/// Equity curve with a range switcher.
class AppEquityCurveBlock extends StatefulWidget {
  const AppEquityCurveBlock({
    super.key,
    required this.series,
    this.title = 'Equity curve',
    this.ranges = const <String>['1W', '1M', '3M', 'YTD', 'ALL'],
    this.onRangeChanged,
  });

  final List<AppSeriesPoint> series;
  final String title;
  final List<String> ranges;
  final ValueChanged<String>? onRangeChanged;

  @override
  State<AppEquityCurveBlock> createState() => _AppEquityCurveBlockState();
}

class _AppEquityCurveBlockState extends State<AppEquityCurveBlock> {
  late String _range = widget.ranges.last;

  @override
  Widget build(BuildContext context) {
    final double last = widget.series.isEmpty ? 0 : widget.series.last.value;
    final double first = widget.series.isEmpty ? 0 : widget.series.first.value;
    final double change = last - first;

    return UiCard(
      title: widget.title,
      subtitle: AppTokens.signedMoney(change),
      trailing: UiToggleGroup<String>(
        value: _range,
        options: <UiToggleOption<String>>[
          for (final String r in widget.ranges)
            UiToggleOption<String>(value: r, label: r),
        ],
        onChanged: (String v) {
          setState(() => _range = v);
          widget.onRangeChanged?.call(v);
        },
      ),
      child: UiChart(
        height: context.uiRes.pick<double>(
          mobile: 200,
          tablet: 260,
          desktop: 320,
        ),
        data: <UiChartPoint>[
          for (final AppSeriesPoint p in widget.series)
            UiChartPoint(label: p.label, values: <double>[p.value]),
        ],
        series: <UiChartSeries>[
          UiChartSeries(
            name: 'Equity',
            type: UiChartSeriesType.area,
            color: AppTokens.pl(context, change),
          ),
        ],
        showLegend: false,
        valueFormatter: (num v) => AppTokens.compactMoney(v),
      ),
    );
  }
}

/// Monthly P/L calendar heatmap. 7 columns on every device.
class AppPnlCalendarBlock extends StatelessWidget {
  const AppPnlCalendarBlock({
    super.key,
    required this.days,
    this.title = 'P/L calendar',
    this.onDayTap,
  });

  final List<AppDayPnl> days;
  final String title;
  final ValueChanged<AppDayPnl>? onDayTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double maxAbs = days.fold<double>(
      0,
      (double m, AppDayPnl d) => d.pnl.abs() > m ? d.pnl.abs() : m,
    );
    final double total = days.fold<double>(
      0,
      (double s, AppDayPnl d) => s + d.pnl,
    );

    return UiCard(
      title: title,
      trailing: UiBadge(
        label: AppTokens.signedMoney(total),
        intent: AppTokens.plIntent(total),
        filled: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              for (final String d in const <String>[
                'M',
                'T',
                'W',
                'T',
                'F',
                'S',
                'S',
              ])
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundSubtle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: days.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: context.sp(theme.spacing.xs),
              crossAxisSpacing: context.sp(theme.spacing.xs),
            ),
            itemBuilder: (BuildContext _, int i) => AppCalendarDayCard(
              day: days[i],
              maxAbsPnl: maxAbs,
              onTap: onDayTap == null ? null : () => onDayTap!(days[i]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent trades list with a "view all" action.
class AppRecentTradesBlock extends StatelessWidget {
  const AppRecentTradesBlock({
    super.key,
    required this.trades,
    this.title = 'Recent trades',
    this.onViewAll,
    this.onTradeTap,
    this.limit = 5,
  });

  final List<AppTrade> trades;
  final String title;
  final VoidCallback? onViewAll;
  final ValueChanged<AppTrade>? onTradeTap;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<AppTrade> shown = trades.take(limit).toList();
    return UiCard(
      title: title,
      trailing: onViewAll == null
          ? null
          : UiButton(
              label: 'View all',
              variant: UiVariant.ghost,
              size: UiSize.sm,
              expandOnMobile: false,
              onPressed: onViewAll,
            ),
      child: shown.isEmpty
          ? const UiEmptyState(
              title: 'No trades yet',
              message: 'Log your first trade to start building your journal.',
              icon: Icons.candlestick_chart_outlined,
            )
          : Column(
              children: <Widget>[
                for (int i = 0; i < shown.length; i++) ...<Widget>[
                  AppTradeCard(
                    trade: shown[i],
                    dense: true,
                    onTap: onTradeTap == null
                        ? null
                        : () => onTradeTap!(shown[i]),
                  ),
                  if (i != shown.length - 1)
                    SizedBox(height: context.sp(theme.spacing.sm)),
                ],
              ],
            ),
    );
  }
}

/// Horizontally scrolling gainers / losers rail.
class AppMoversRailBlock extends StatelessWidget {
  const AppMoversRailBlock({
    super.key,
    required this.tickers,
    this.title = 'Top movers',
    this.onTickerTap,
  });

  final List<AppTicker> tickers;
  final String title;
  final ValueChanged<AppTicker>? onTickerTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: context.uiText.subheading),
        SizedBox(height: context.sp(theme.spacing.md)),
        SizedBox(
          height: context.sz(168),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tickers.length,
            separatorBuilder: (_, _) =>
                SizedBox(width: context.sp(theme.spacing.md)),
            itemBuilder: (BuildContext _, int i) => AppMoverCard(
              ticker: tickers[i],
              onTap: onTickerTap == null
                  ? null
                  : () => onTickerTap!(tickers[i]),
            ),
          ),
        ),
      ],
    );
  }
}

/// Allocation donut + legend list.
class AppAllocationBlock extends StatelessWidget {
  const AppAllocationBlock({
    super.key,
    required this.slices,
    this.title = 'Allocation',
    this.totalLabel,
  });

  final List<UiDonutSlice> slices;
  final String title;
  final String? totalLabel;

  @override
  Widget build(BuildContext context) {
    return UiCard(
      title: title,
      child: UiDonutChart(
        slices: slices,
        center: totalLabel == null
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(totalLabel!, style: context.uiText.subheading),
                  Text(
                    'total',
                    style: context.uiText.caption.copyWith(
                      color: context.uiColors.foregroundMuted,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Performance-by-tag/session ranked bar list.
class AppBreakdownBlock extends StatelessWidget {
  const AppBreakdownBlock({
    super.key,
    required this.items,
    this.title = 'Performance breakdown',
  });

  final List<UiBarListItem> items;
  final String title;

  @override
  Widget build(BuildContext context) => UiCard(
    title: title,
    child: items.isEmpty
        ? const UiEmptyState(title: 'Not enough data yet')
        : UiBarList(
            items: items,
            valueFormatter: (num v) => AppTokens.compactMoney(v),
          ),
  );
}

/// Two-column responsive dashboard body: main column + side column.
class AppDashboardLayoutBlock extends StatelessWidget {
  const AppDashboardLayoutBlock({
    super.key,
    required this.main,
    required this.side,
  });

  final List<Widget> main;
  final List<Widget> side;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double gap = context.sp(theme.spacing.lg);
    Widget stack(List<Widget> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < items.length; i++) ...<Widget>[
          items[i],
          if (i != items.length - 1) SizedBox(height: gap),
        ],
      ],
    );

    if (!context.uiRes.isDesktop) {
      return stack(<Widget>[...main, ...side]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: 2, child: stack(main)),
        SizedBox(width: gap),
        Expanded(child: stack(side)),
      ],
    );
  }
}
