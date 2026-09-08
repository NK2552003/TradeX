/// Redesigned strategy cards with compact, professional layouts.
///
/// Features reduced sizing (20-30% smaller), responsive grids,
/// and enhanced visual hierarchy for desktop and mobile.

import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';
import '../motion/app_motion.dart';
import '../theme/app_tokens.dart';

/// Compact strategy card optimized for dense grids.
///
/// 25% smaller than standard cards with cleaner visual hierarchy.
class AppStrategyCardCompact extends StatelessWidget {
  const AppStrategyCardCompact({
    super.key,
    required this.strategy,
    this.onTap,
    this.onFavorite,
    this.selected = false,
    this.loading = false,
  });

  final AppStrategy strategy;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool selected;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;

    return AppHoverLift(
      child: UiCard(
        onTap: onTap,
        selected: selected,
        loading: loading,
        padding: EdgeInsets.all(context.sp(isMobile ? theme.spacing.sm : theme.spacing.md)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Header row with name and favorite
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    strategy.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.labelStrong.copyWith(
                      fontSize: isMobile ? 13 : 14,
                    ),
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xxs)),
                UiIconButton(
                  icon: strategy.isFavorite ? Icons.star : Icons.star_border,
                  onPressed: onFavorite,
                  size: UiSize.xs,
                  tooltip: 'Favorite',
                ),
              ],
            ),
            
            SizedBox(height: context.sp(theme.spacing.xxs)),
            
            // Category badge
            if (strategy.category.isNotEmpty)
              Container(
                margin: EdgeInsets.only(bottom: context.sp(theme.spacing.xxs)),
                child: UiBadge(
                  label: strategy.category,
                  size: UiSize.xs,
                  variant: UiBadgeVariant.outline,
                  maxWidth: context.sz(120),
                ),
              ),
            
            // Status indicator
            Row(
              children: <Widget>[
                Container(
                  width: context.sz(6),
                  height: context.sz(6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(context),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xxs)),
                Text(
                  _getStatusLabel(),
                  style: context.uiText.caption.copyWith(
                    color: context.uiColors.foregroundMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            
            const Spacer(),
            
            // Metrics row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _buildMetric(
                  context,
                  value: '${strategy.trades}',
                  label: 'Trades',
                  icon: Icons.trending_up,
                ),
                _buildMetric(
                  context,
                  value: '${strategy.winRate.toStringAsFixed(0)}%',
                  label: 'Win Rate',
                  icon: Icons.check_circle_outline,
                  color: strategy.winRate >= 50 
                      ? context.uiColors.bullish 
                      : context.uiColors.bearish,
                ),
                _buildMetric(
                  context,
                  value: AppTokens.signedMoney(strategy.netPnl),
                  label: 'P/L',
                  icon: Icons.attach_money,
                  color: AppTokens.pl(context, strategy.netPnl),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(BuildContext context) {
    switch (strategy.status) {
      case AppStrategyStatus.live:
        return context.uiColors.bullish;
      case AppStrategyStatus.testing:
        return context.uiColors.warning;
      case AppStrategyStatus.draft:
        return context.uiColors.foregroundSubtle;
      case AppStrategyStatus.retired:
        return context.uiColors.bearish;
    }
  }

  String _getStatusLabel() {
    switch (strategy.status) {
      case AppStrategyStatus.live:
        return 'Live';
      case AppStrategyStatus.testing:
        return 'Testing';
      case AppStrategyStatus.draft:
        return 'Draft';
      case AppStrategyStatus.retired:
        return 'Retired';
    }
  }

  Widget _buildMetric(
    BuildContext context, {
    required String value,
    required String label,
    required IconData icon,
    Color? color,
  }) {
    final UiTheme theme = context.ui;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: context.sz(12),
              color: color ?? context.uiColors.foregroundMuted,
            ),
            SizedBox(width: context.sp(theme.spacing.xxxs)),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.numeric.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: context.uiText.caption.copyWith(
            fontSize: 10,
            color: context.uiColors.foregroundSubtle,
          ),
        ),
      ],
    );
  }
}

/// Strategy performance summary card for dashboards.
class AppStrategyPerformanceCompact extends StatelessWidget {
  const AppStrategyPerformanceCompact({
    super.key,
    required this.strategy,
    this.onTap,
  });

  final AppStrategy strategy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color plColor = AppTokens.pl(context, strategy.netPnl);
    final bool isMobile = context.uiRes.isMobile;

    return UiCard(
      onTap: onTap,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Row(
        children: <Widget>[
          // Win rate circle
          SizedBox(
            width: context.sz(64),
            height: context.sz(64),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                UiProgressCircle(
                  value: (strategy.winRate / 100).clamp(0, 1),
                  size: 64,
                  strokeWidth: 6,
                  intent: strategy.winRate >= 50
                      ? UiIntent.bullish
                      : UiIntent.bearish,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${strategy.winRate.toStringAsFixed(0)}',
                      style: context.uiText.titleStrong.copyWith(
                        fontSize: 16,
                        color: plColor,
                      ),
                    ),
                    Text(
                      '%',
                      style: context.uiText.caption.copyWith(
                        fontSize: 10,
                        color: context.uiColors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          SizedBox(width: context.sp(theme.spacing.md)),
          
          // Performance metrics
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strategy.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.labelStrong,
                ),
                SizedBox(height: context.sp(theme.spacing.xxs)),
                Text(
                  '${strategy.trades} trades',
                  style: context.uiText.caption.copyWith(
                    color: context.uiColors.foregroundMuted,
                    fontSize: 11,
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                AppCountUp(
                  value: strategy.netPnl,
                  formatter: (num v) => AppTokens.signedMoney(v),
                  style: context.uiText.bodyStrong.copyWith(
                    color: plColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Spark chart
          if (strategy.equityCurve.isNotEmpty && !isMobile) ...<Widget>[
            SizedBox(
              width: context.sz(80),
              height: context.sz(40),
              child: UiSparkChart(
                values: strategy.equityCurve,
                color: plColor,
                filled: true,
                strokeWidth: 2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mini strategy card for sidebars and quick reference.
class AppStrategyMiniCard extends StatelessWidget {
  const AppStrategyMiniCard({
    super.key,
    required this.strategy,
    this.onTap,
    this.showMetrics = true,
  });

  final AppStrategy strategy;
  final VoidCallback? onTap;
  final bool showMetrics;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color plColor = AppTokens.pl(context, strategy.netPnl);

    return InkWell(
      onTap: onTap,
      borderRadius: context.radius(theme.radii.md),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.sm),
          vertical: context.sp(theme.spacing.xs),
        ),
        decoration: BoxDecoration(
          borderRadius: context.radius(theme.radii.md),
          border: Border.all(
            color: context.uiColors.border,
            width: theme.borders.hairline,
          ),
        ),
        child: Row(
          children: <Widget>[
            // Status dot
            Container(
              width: context.sz(8),
              height: context.sz(8),
              decoration: BoxDecoration(
                color: _getStatusColor(context),
                shape: BoxShape.circle,
              ),
            ),
            
            SizedBox(width: context.sp(theme.spacing.sm)),
            
            // Name
            Expanded(
              child: Text(
                strategy.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.label,
              ),
            ),
            
            // Metrics
            if (showMetrics) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.sm)),
              Text(
                '${strategy.winRate.toStringAsFixed(0)}%',
                style: context.uiText.numeric.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: strategy.winRate >= 50
                      ? context.uiColors.bullish
                      : context.uiColors.bearish,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(BuildContext context) {
    switch (strategy.status) {
      case AppStrategyStatus.live:
        return context.uiColors.bullish;
      case AppStrategyStatus.testing:
        return context.uiColors.warning;
      case AppStrategyStatus.draft:
        return context.uiColors.foregroundSubtle;
      case AppStrategyStatus.retired:
        return context.uiColors.bearish;
    }
  }
}
