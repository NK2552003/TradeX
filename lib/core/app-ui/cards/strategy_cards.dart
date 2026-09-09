import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';
import '../motion/app_motion.dart';
import '../theme/app_tokens.dart';

/// Strategy note card: name, category, visibility, AI summary preview.
class AppStrategyCard extends StatelessWidget {
  const AppStrategyCard({
    super.key,
    required this.strategy,
    this.onTap,
    this.onFavorite,
    this.dense = false,
    this.selected = false,
    this.loading = false,
  });

  final AppStrategy strategy;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool dense;

  /// Highlights the card as the active/selected strategy.
  final bool selected;

  /// Renders the built-in [UiCard] skeleton instead of the summary body.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return AppHoverLift(
      child: UiCard(
        onTap: onTap,
        selected: selected,
        loading: loading,
        title: strategy.name,
        subtitle: strategy.category,
        trailing: UiIconButton(
          icon: strategy.isFavorite ? Icons.star : Icons.star_border,
          onPressed: onFavorite,
          size: UiSize.sm,
          tooltip: 'Favorite',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (strategy.summary != null && !dense)
              Text(
                strategy.summary!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.body.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            Wrap(
              spacing: context.sp(theme.spacing.xs),
              runSpacing: context.sp(theme.spacing.xs),
              children: <Widget>[
                UiBadge(
                  label: strategy.isPublic ? 'Public' : 'Private',
                  icon: strategy.isPublic ? Icons.public : Icons.lock_outline,
                ),
                UiBadge(
                  label: 'v${strategy.versionCount}',
                  icon: Icons.history,
                ),
                UiBadge(
                  label: '${strategy.trades} trades',
                  intent: UiIntent.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-strategy performance: win rate ring, net P/L, average R, equity spark.
class AppStrategyPerformanceCard extends StatelessWidget {
  const AppStrategyPerformanceCard({
    super.key,
    required this.strategy,
    this.onTap,
  });

  final AppStrategy strategy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color pl = AppTokens.pl(context, strategy.netPnl);
    return UiCard(
      onTap: onTap,
      title: strategy.name,
      subtitle: '${strategy.trades} trades',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          UiProgressCircle(
            value: (strategy.winRate / 100).clamp(0, 1),
            size: 76,
            intent: strategy.winRate >= 50
                ? UiIntent.bullish
                : UiIntent.bearish,
            center: Text(
              '${strategy.winRate.toStringAsFixed(0)}%',
              style: context.uiText.bodyStrong,
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.md)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppCountUp(
                  value: strategy.netPnl,
                  formatter: (num v) => AppTokens.signedMoney(v),
                  style: context.uiText.heading.copyWith(color: pl),
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                Text(
                  'Avg ${AppTokens.rr(strategy.avgR)} per trade',
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
                if (strategy.equityCurve.isNotEmpty) ...<Widget>[
                  SizedBox(height: context.sp(theme.spacing.xs)),
                  UiSparkChart(
                    values: strategy.equityCurve,
                    color: pl,
                    filled: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One entry in a strategy's version history.
class AppVersionCard extends StatelessWidget {
  const AppVersionCard({
    super.key,
    required this.version,
    this.onRestore,
    this.onTap,
  });

  final AppStrategyVersion version;
  final VoidCallback? onRestore;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      onTap: onTap,
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      child: Row(
        children: <Widget>[
          Container(
            width: context.sz(36),
            height: context.sz(36),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colors.surfaceMuted,
              borderRadius: context.radius(theme.radii.md),
            ),
            child: Text('v${version.version}', style: context.uiText.caption),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  version.note ?? 'Saved revision',
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.bodyStrong,
                ),
                Text(
                  '${AppTokens.relativeTime(version.savedAt)}'
                  '${version.author == null ? '' : ' · ${version.author}'}',
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
          if (version.isCurrent)
            const UiBadge(label: 'Current', intent: UiIntent.bullish)
          else if (onRestore != null)
            UiButton(
              label: 'Restore',
              variant: UiVariant.outline,
              size: UiSize.sm,
              expandOnMobile: false,
              onPressed: onRestore,
            ),
        ],
      ),
    );
  }
}

/// Side-by-side comparison of two strategies.
class AppStrategyComparisonCard extends StatelessWidget {
  const AppStrategyComparisonCard({
    super.key,
    required this.a,
    required this.b,
  });

  final AppStrategy a;
  final AppStrategy b;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    Widget column(AppStrategy s, CrossAxisAlignment align) => Column(
      crossAxisAlignment: align,
      children: <Widget>[
        Text(
          s.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.uiText.bodyStrong,
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        Text(
          AppTokens.signedMoney(s.netPnl),
          style: context.uiText.heading.copyWith(
            color: AppTokens.pl(context, s.netPnl),
          ),
        ),
        Text(
          '${s.winRate.toStringAsFixed(0)}% win · ${AppTokens.rr(s.avgR)}',
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundMuted,
          ),
        ),
      ],
    );

    return UiCard(
      title: 'Head to head',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: column(a, CrossAxisAlignment.start)),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.xs),
                ),
                child: Text(
                  'vs',
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundSubtle,
                  ),
                ),
              ),
              Expanded(child: column(b, CrossAxisAlignment.end)),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiCategoryBar(
            showLegend: false,
            segments: <UiCategorySegment>[
              UiCategorySegment(
                value: a.trades.toDouble(),
                label: a.name,
                color: theme.colors.primary,
              ),
              UiCategorySegment(
                value: b.trades.toDouble(),
                label: b.name,
                color: theme.colors.info,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// AI-generated plain-English summary of a strategy document.
class AppStrategySummaryCard extends StatelessWidget {
  const AppStrategySummaryCard({
    super.key,
    required this.summary,
    this.onRegenerate,
    this.loading = false,
  });

  final String summary;
  final VoidCallback? onRegenerate;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: 'AI summary',
      trailing: UiIconButton(
        icon: Icons.refresh,
        size: UiSize.sm,
        tooltip: 'Regenerate',
        onPressed: onRegenerate,
      ),
      accentColor: theme.colors.primary,
      child: loading
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                UiSkeleton(height: context.sz(12)),
                SizedBox(height: context.sp(theme.spacing.xs)),
                UiSkeleton(height: context.sz(12)),
                SizedBox(height: context.sp(theme.spacing.xs)),
                UiSkeleton(width: context.sz(180), height: context.sz(12)),
              ],
            )
          : Text(
              summary,
              style: context.uiText.body.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
    );
  }
}
