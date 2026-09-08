/// Redesigned journal cards with compact, professional layouts.
///
/// Features reduced sizing (20-30% smaller), responsive grids,
/// and enhanced visual hierarchy for desktop and mobile.

import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';
import '../motion/app_motion.dart';
import '../theme/app_tokens.dart';

/// Compact trade card optimized for dense grids.
///
/// 25% smaller than standard cards with cleaner visual hierarchy.
class AppTradeCardCompact extends StatelessWidget {
  const AppTradeCardCompact({
    super.key,
    required this.trade,
    this.onTap,
    this.selected = false,
    this.loading = false,
  });

  final AppTrade trade;
  final VoidCallback? onTap;
  final bool selected;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color plColor = AppTokens.pl(context, trade.pnl);
    final bool isMobile = context.uiRes.isMobile;

    return AppHoverLift(
      child: UiCard(
        onTap: onTap,
        selected: selected,
        loading: loading,
        accentColor: plColor,
        padding: EdgeInsets.all(context.sp(isMobile ? theme.spacing.sm : theme.spacing.md)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Header row with ticker and side
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    trade.ticker,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.labelStrong.copyWith(
                      fontSize: isMobile ? 13 : 14,
                    ),
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xxs)),
                UiBadge(
                  label: AppTokens.sideLabel(trade.side),
                  intent: AppTokens.sideIntent(trade.side),
                  icon: AppTokens.sideIcon(trade.side),
                  size: UiSize.xs,
                ),
              ],
            ),
            
            SizedBox(height: context.sp(theme.spacing.xxs)),
            
            // Date and strategy
            if (trade.strategy != null || trade.openedAt != null)
              Text(
                <String>[
                  if (trade.openedAt != null) AppTokens.shortDate(trade.openedAt!),
                  if (trade.strategy != null) trade.strategy!,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.caption.copyWith(
                  color: context.uiColors.foregroundMuted,
                  fontSize: 11,
                ),
              ),
            
            const Spacer(),
            
            // P/L prominently displayed
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: AppCountUp(
                    value: trade.pnl,
                    formatter: (num v) => AppTokens.signedMoney(v),
                    style: context.uiText.titleStrong.copyWith(
                      fontSize: isMobile ? 16 : 18,
                      color: plColor,
                    ),
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                UiBadge.delta(
                  trade.pnlPercent,
                  size: UiSize.xs,
                ),
              ],
            ),
            
            SizedBox(height: context.sp(theme.spacing.xs)),
            
            // Key metrics row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _buildMetric(
                  context,
                  label: 'Entry',
                  value: AppTokens.money(trade.entry),
                ),
                if (trade.exit != null) ...<Widget>[
                  _buildMetric(
                    context,
                    label: 'Exit',
                    value: AppTokens.money(trade.exit!),
                  ),
                ],
                if (trade.rMultiple != null) ...<Widget>[
                  _buildMetric(
                    context,
                    label: 'R',
                    value: AppTokens.rr(trade.rMultiple!),
                    color: _getRColor(context, trade.rMultiple!),
                  ),
                ],
              ],
            ),
            
            // Tags if space permits
            if (!isMobile && (trade.tags.isNotEmpty || trade.strategy != null)) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.xs)),
              Wrap(
                spacing: context.sp(theme.spacing.xxs),
                runSpacing: context.sp(theme.spacing.xxxs),
                children: <Widget>[
                  if (trade.strategy != null)
                    UiBadge(
                      label: trade.strategy!,
                      intent: UiIntent.primary,
                      icon: Icons.auto_graph,
                      size: UiSize.xs,
                      maxWidth: context.sz(80),
                    ),
                  ...trade.tags.take(3).map((String tag) => 
                    UiBadge(
                      label: '#$tag',
                      size: UiSize.xs,
                      variant: UiBadgeVariant.ghost,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getRColor(BuildContext context, double r) {
    if (r >= 2.0) return context.uiColors.bullish;
    if (r <= -1.0) return context.uiColors.bearish;
    return context.uiColors.foregroundMuted;
  }

  Widget _buildMetric(
    BuildContext context, {
    required String label,
    required String value,
    Color? color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: context.uiText.caption.copyWith(
            fontSize: 9,
            color: context.uiColors.foregroundSubtle,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.uiText.numeric.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color ?? context.uiColors.foreground,
          ),
        ),
      ],
    );
  }
}

/// Ultra-compact trade row for lists.
class AppTradeRowCompact extends StatelessWidget {
  const AppTradeRowCompact({
    super.key,
    required this.trade,
    this.onTap,
    this.showOutcome = true,
  });

  final AppTrade trade;
  final VoidCallback? onTap;
  final bool showOutcome;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color plColor = AppTokens.pl(context, trade.pnl);
    final Color outcomeColor = AppTokens.outcomeIntent(trade.outcome).color(context);

    return InkWell(
      onTap: onTap,
      borderRadius: context.radius(theme.radii.sm),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.sm),
          vertical: context.sp(theme.spacing.xs),
        ),
        decoration: BoxDecoration(
          borderRadius: context.radius(theme.radii.sm),
          border: Border.all(
            color: context.uiColors.border,
            width: theme.borders.hairline,
          ),
        ),
        child: Row(
          children: <Widget>[
            // Outcome indicator
            if (showOutcome) ...<Widget>[
              Icon(
                Icons.circle,
                size: context.sz(6),
                color: outcomeColor,
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
            ],
            
            // Ticker and side
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        trade.ticker,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.labelStrong.copyWith(
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(width: context.sp(theme.spacing.xxs)),
                      Text(
                        AppTokens.sideLabel(trade.side),
                        style: context.uiText.caption.copyWith(
                          fontSize: 10,
                          color: outcomeColor,
                        ),
                      ),
                    ],
                  ),
                  if (trade.openedAt != null)
                    Text(
                      AppTokens.shortDate(trade.openedAt!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption.copyWith(
                        fontSize: 10,
                        color: context.uiColors.foregroundSubtle,
                      ),
                    ),
                ],
              ),
            ),
            
            // P/L
            SizedBox(width: context.sp(theme.spacing.md)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  AppTokens.signedMoney(trade.pnl),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.numeric.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: plColor,
                  ),
                ),
                if (trade.rMultiple != null)
                  Text(
                    AppTokens.rr(trade.rMultiple!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.caption.copyWith(
                      fontSize: 9,
                      color: context.uiColors.foregroundMuted,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Trade summary card for dashboards.
class AppTradeSummaryCompact extends StatelessWidget {
  const AppTradeSummaryCompact({
    super.key,
    required this.title,
    required this.trades,
    required this.pnl,
    this.winRate,
    this.onTap,
  });

  final String title;
  final int trades;
  final double pnl;
  final double? winRate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color plColor = AppTokens.pl(context, pnl);

    return UiCard(
      onTap: onTap,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.label.copyWith(
              color: context.uiColors.foregroundMuted,
              fontSize: 11,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          AppCountUp(
            value: pnl,
            formatter: (num v) => AppTokens.signedMoney(v),
            style: context.uiText.heading.copyWith(
              fontSize: 20,
              color: plColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Row(
            children: <Widget>[
              _buildStat(
                context,
                value: '$trades',
                label: 'Trades',
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              if (winRate != null) ...<Widget>[
                _buildStat(
                  context,
                  value: '${winRate!.toStringAsFixed(0)}%',
                  label: 'Win Rate',
                  color: winRate! >= 50
                      ? context.uiColors.bullish
                      : context.uiColors.bearish,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(
    BuildContext context, {
    required String value,
    required String label,
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: context.uiText.bodyStrong.copyWith(
            fontSize: 14,
            color: color ?? context.uiColors.foreground,
          ),
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
