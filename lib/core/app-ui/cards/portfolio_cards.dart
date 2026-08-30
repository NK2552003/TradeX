import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';
import '../motion/app_motion.dart';
import '../theme/app_tokens.dart';

/// Headline KPI tile with animated value, delta badge and optional sparkline.
class AppStatCard extends StatelessWidget {
  const AppStatCard({
    super.key,
    required this.stat,
    this.onTap,
    this.dense = false,
    this.selected = false,
  });

  final AppStat stat;
  final VoidCallback? onTap;
  final bool dense;

  /// Highlights the tile as the active/selected KPI.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String Function(num) fmt =
        stat.formatter ?? (num v) => uiCompactNumber(v);
    final Color deltaColor = stat.delta == null
        ? theme.colors.foregroundMuted
        : AppTokens.pl(context, stat.delta!);

    return AppHoverLift(
      child: UiCard(
        onTap: onTap,
        selected: selected,
        padding: dense ? EdgeInsets.all(context.sp(theme.spacing.md)) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (stat.icon != null) ...<Widget>[
                  Icon(
                    stat.icon,
                    size: context.sz(theme.sizes.iconSm),
                    color: theme.colors.foregroundMuted,
                  ),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                ],
                Expanded(
                  child: Text(
                    stat.label,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.label.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: AppCountUp(
                    value: stat.value,
                    formatter: (num v) => '${fmt(v)}${stat.suffix ?? ''}',
                    style: context.uiText.title,
                  ),
                ),
                if (stat.delta != null)
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          AppTokens.plIcon(stat.delta!),
                          size: context.sz(theme.sizes.iconSm),
                          color: deltaColor,
                        ),
                        SizedBox(width: context.sp(theme.spacing.xxs)),
                        Flexible(
                          child: Text(
                            AppTokens.signedPercent(stat.delta!, decimals: 1),
                            overflow: TextOverflow.ellipsis,
                            style: context.uiText.caption.copyWith(
                              color: deltaColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (stat.spark.isNotEmpty) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.md)),
              UiSparkChart(
                values: stat.spark,
                color: stat.delta == null ? theme.colors.primary : deltaColor,
                filled: true,
                height: dense ? 28 : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Radial win-rate gauge with wins/losses breakdown.
class AppWinRateCard extends StatelessWidget {
  const AppWinRateCard({
    super.key,
    required this.winRate,
    required this.wins,
    required this.losses,
    this.breakeven = 0,
    this.title = 'Win rate',
  });

  final double winRate;
  final int wins;
  final int losses;
  final int breakeven;
  final String title;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: title,
      child: Row(
        children: <Widget>[
          AppReveal(
            builder: (BuildContext context, double t) => UiProgressCircle(
              value: (winRate / 100 * t).clamp(0, 1),
              size: 104,
              intent: winRate >= 50 ? UiIntent.bullish : UiIntent.bearish,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${(winRate * t).toStringAsFixed(0)}%',
                    style: context.uiText.heading,
                  ),
                  Text(
                    'win',
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.lg)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _row(context, 'Wins', wins, UiIntent.bullish),
                _row(context, 'Losses', losses, UiIntent.bearish),
                _row(context, 'Break-even', breakeven, UiIntent.neutral),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, int value, UiIntent intent) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
      child: Row(
        children: <Widget>[
          Container(
            width: context.sz(8),
            height: context.sz(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: intent.color(context),
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
          Flexible(
            child: Text(
              AppTokens.count(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: context.uiText.numeric,
            ),
          ),
        ],
      ),
    );
  }
}

/// Best / worst trade highlight.
class AppExtremeTradeCard extends StatelessWidget {
  const AppExtremeTradeCard({
    super.key,
    required this.trade,
    required this.best,
    this.onTap,
  });

  final AppTrade trade;
  final bool best;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color color = best ? theme.colors.bullish : theme.colors.bearish;
    return UiCard(
      onTap: onTap,
      accentColor: color,
      title: best ? 'Best trade' : 'Worst trade',
      trailing: UiBadge(
        label: trade.ticker,
        intent: best ? UiIntent.bullish : UiIntent.bearish,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppTokens.signedMoney(trade.pnl),
            style: context.uiText.title.copyWith(color: color),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            '${AppTokens.sideLabel(trade.side)} · '
            '${AppTokens.shortDate(trade.openedAt)}'
            '${trade.rMultiple == null ? '' : ' · ${AppTokens.rr(trade.rMultiple!)}'}',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Risk/reward gauge showing average R against a target R.
class AppRiskRewardCard extends StatelessWidget {
  const AppRiskRewardCard({
    super.key,
    required this.avgR,
    this.targetR = 2,
    this.title = 'Avg risk / reward',
  });

  final double avgR;
  final double targetR;
  final String title;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double ratio = (avgR / (targetR == 0 ? 1 : targetR)).clamp(0, 1);
    return UiCard(
      title: title,
      trailing: UiBadge(
        label: 'Target ${AppTokens.rr(targetR)}',
        intent: UiIntent.info,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppCountUp(
            value: avgR,
            formatter: (num v) => AppTokens.rr(v),
            style: context.uiText.title.copyWith(
              color: avgR >= targetR
                  ? theme.colors.bullish
                  : theme.colors.warning,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiProgressBar(
            value: ratio.toDouble(),
            intent: avgR >= targetR ? UiIntent.bullish : UiIntent.warning,
            showValue: false,
          ),
        ],
      ),
    );
  }
}

/// Max drawdown card with an inverted area sparkline.
class AppDrawdownCard extends StatelessWidget {
  const AppDrawdownCard({
    super.key,
    required this.maxDrawdownPercent,
    required this.series,
    this.title = 'Max drawdown',
  });

  final double maxDrawdownPercent;
  final List<double> series;
  final String title;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppCountUp(
            value: maxDrawdownPercent,
            formatter: (num v) => '-${v.abs().toStringAsFixed(1)}%',
            style: context.uiText.title.copyWith(color: theme.colors.bearish),
          ),
          if (series.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            UiSparkChart(
              values: series,
              color: theme.colors.bearish,
              filled: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Trading streak card built on the tracker component.
class AppStreakCard extends StatelessWidget {
  const AppStreakCard({
    super.key,
    required this.days,
    this.title = 'Discipline streak',
    this.currentStreak,
  });

  /// Newest last. Positive = green day, negative = red day, 0 = no trades.
  final List<double> days;
  final String title;
  final int? currentStreak;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      title: title,
      trailing: currentStreak == null
          ? null
          : UiBadge(
              label: '$currentStreak day streak',
              intent: UiIntent.bullish,
              icon: Icons.local_fire_department_outlined,
            ),
      child: UiTracker(
        blocks: days
            .map(
              (double d) => UiTrackerBlock(
                intent: AppTokens.plIntent(d),
                tooltip: AppTokens.signedMoney(d),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// One day inside the P/L calendar heatmap.
class AppCalendarDayCard extends StatelessWidget {
  const AppCalendarDayCard({
    super.key,
    required this.day,
    required this.maxAbsPnl,
    this.onTap,
  });

  final AppDayPnl day;
  final double maxAbsPnl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color base = AppTokens.pl(context, day.pnl);
    final double intensity = maxAbsPnl == 0
        ? 0.06
        : (day.pnl.abs() / maxAbsPnl).clamp(0.06, 0.9).toDouble();

    return UiTooltip(
      message:
          '${AppTokens.shortDate(day.date)} · '
          '${AppTokens.signedMoney(day.pnl)} · ${day.trades} trades',
      child: UiInteractive(
        enabled: onTap != null,
        onTap: onTap,
        builder: (BuildContext ctx, UiInteractiveState s) => AnimatedContainer(
          duration: theme.motion.fast,
          decoration: BoxDecoration(
            color: day.trades == 0
                ? theme.colors.surfaceMuted
                : base.withValues(
                    alpha: s.hovered ? intensity + 0.12 : intensity,
                  ),
            borderRadius: ctx.radius(theme.radii.sm),
            border: Border.all(
              color: s.hovered
                  ? theme.colors.borderStrong
                  : theme.colors.border,
              width: theme.borders.hairline,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.date.day}',
            style: ctx.uiText.caption.copyWith(
              color: day.trades == 0
                  ? theme.colors.foregroundSubtle
                  : theme.colors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton for KPI tiles.
class AppStatCardSkeleton extends StatelessWidget {
  const AppStatCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          UiSkeleton(width: context.sz(90), height: context.sz(12)),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiSkeleton(width: context.sz(140), height: context.sz(26)),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiSkeleton(height: context.sz(28)),
        ],
      ),
    );
  }
}
