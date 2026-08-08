import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';
import '../motion/app_motion.dart';
import '../theme/app_tokens.dart';

/// Watched ticker: price, % change, sparkline, optional note.
class AppTickerCard extends StatelessWidget {
  const AppTickerCard({
    super.key,
    required this.ticker,
    this.onTap,
    this.onFavorite,
    this.dense = false,
    this.selected = false,
    this.loading = false,
  });

  final AppTicker ticker;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool dense;

  /// Highlights the card as the active/selected watchlist row.
  final bool selected;

  /// Renders the built-in [UiCard] skeleton instead of the price/spark body.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color pl = AppTokens.pl(context, ticker.changePercent);
    return AppHoverLift(
      child: UiCard(
        onTap: onTap,
        selected: selected,
        loading: loading,
        padding: dense ? EdgeInsets.all(context.sp(theme.spacing.md)) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        ticker.symbol,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.subheading,
                      ),
                      Text(
                        ticker.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.caption
                            .copyWith(color: theme.colors.foregroundMuted),
                      ),
                    ],
                  ),
                ),
                if (onFavorite != null)
                  UiIconButton(
                    icon: ticker.isFavorite ? Icons.star : Icons.star_border,
                    size: UiSize.sm,
                    tooltip: 'Favorite',
                    onPressed: onFavorite,
                  ),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.md)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: AppCountUp(
                    value: ticker.price,
                    formatter: (num v) =>
                        AppTokens.money(v, symbol: ticker.currencySymbol),
                    style: context.uiText.title,
                  ),
                ),
                UiBadge.delta(ticker.changePercent),
              ],
            ),
            if (ticker.spark.isNotEmpty) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.md)),
              UiSparkChart(values: ticker.spark, color: pl, filled: true),
            ],
            if (ticker.note != null && !dense) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.md)),
              Text(
                ticker.note!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.caption
                    .copyWith(color: theme.colors.foregroundMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Price alert row: target, direction, distance-to-target progress.
class AppPriceAlertCard extends StatelessWidget {
  const AppPriceAlertCard({
    super.key,
    required this.alert,
    this.onToggle,
    this.onDelete,
  });

  final AppPriceAlert alert;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double current = alert.currentPrice ?? alert.targetPrice;
    final double progress = alert.targetPrice == 0
        ? 0
        : (current / alert.targetPrice).clamp(0, 1).toDouble();
    return UiCard(
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                alert.above ? Icons.north : Icons.south,
                size: context.sz(theme.sizes.iconSm),
                color: alert.above ? theme.colors.bullish : theme.colors.bearish,
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: Text(
                  '${alert.symbol} ${alert.above ? 'above' : 'below'} '
                  '${AppTokens.money(alert.targetPrice)}',
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.bodyStrong,
                ),
              ),
              UiSwitch(value: alert.active, onChanged: onToggle),
              if (onDelete != null)
                UiIconButton(
                  icon: Icons.delete_outline,
                  size: UiSize.sm,
                  tooltip: 'Delete alert',
                  onPressed: onDelete,
                ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          UiProgressBar(
            value: progress,
            intent: alert.active ? UiIntent.primary : UiIntent.neutral,
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            alert.triggeredAt != null
                ? 'Triggered ${AppTokens.relativeTime(alert.triggeredAt!)}'
                : 'Now ${AppTokens.money(current)}',
            style: context.uiText.caption
                .copyWith(color: theme.colors.foregroundMuted),
          ),
        ],
      ),
    );
  }
}

/// Compact tile for gainer/loser rails — horizontal scroll friendly.
class AppMoverCard extends StatelessWidget {
  const AppMoverCard({super.key, required this.ticker, this.onTap, this.width});

  final AppTicker ticker;
  final VoidCallback? onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color pl = AppTokens.pl(context, ticker.changePercent);
    return SizedBox(
      width: context.sz(width ?? 168),
      child: UiCard(
        onTap: onTap,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(ticker.symbol, style: context.uiText.bodyStrong),
            SizedBox(height: context.sp(theme.spacing.xxs)),
            Text(
              AppTokens.money(ticker.price, symbol: ticker.currencySymbol),
              style: context.uiText.numeric,
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            if (ticker.spark.isNotEmpty)
              UiSparkChart(values: ticker.spark, color: pl, height: 32),
            SizedBox(height: context.sp(theme.spacing.sm)),
            UiBadge.delta(ticker.changePercent),
          ],
        ),
      ),
    );
  }
}

/// Heat tile used inside the sector heatmap grid.
class AppHeatTile extends StatelessWidget {
  const AppHeatTile({
    super.key,
    required this.label,
    required this.changePercent,
    this.onTap,
  });

  final String label;
  final double changePercent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color base = AppTokens.pl(context, changePercent);
    final double intensity =
        (changePercent.abs() / 5).clamp(0.10, 0.85).toDouble();
    return UiInteractive(
      enabled: onTap != null,
      onTap: onTap,
      builder: (BuildContext ctx, UiInteractiveState s) => AnimatedContainer(
        duration: theme.motion.fast,
        curve: theme.motion.curve,
        padding: EdgeInsets.all(ctx.sp(theme.spacing.md)),
        decoration: BoxDecoration(
          color: base.withValues(alpha: s.hovered ? intensity + 0.1 : intensity),
          borderRadius: ctx.radius(theme.radii.lg),
          border: Border.all(
            color: base.withValues(alpha: 0.4),
            width: theme.borders.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ctx.uiText.label,
            ),
            Text(
              AppTokens.signedPercent(changePercent),
              style: ctx.uiText.numeric.copyWith(color: base),
            ),
          ],
        ),
      ),
    );
  }
}
