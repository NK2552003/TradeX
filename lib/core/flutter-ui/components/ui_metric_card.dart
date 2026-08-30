import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_card.dart';
import 'ui_common.dart';

/// KPI / metric tile built on [UiCard]; used for portfolio stats.
class UiMetricCard extends StatelessWidget {
  const UiMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.icon,
    this.chart,
    this.onTap,
  });

  final String label;
  final String value;
  final num? delta;
  final IconData? icon;
  final Widget? chart;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final r = context.uiRes;
    final Color deltaColor = delta == null
        ? theme.colors.foregroundMuted
        : (delta! >= 0 ? theme.colors.bullish : theme.colors.bearish);
    return UiCard(
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(r.isMobile ? theme.spacing.sm + 2 : theme.spacing.md),
        vertical: context.sp(r.isMobile ? theme.spacing.sm : theme.spacing.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: context.sz(theme.sizes.iconSm),
                  color: theme.colors.foregroundMuted,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.label.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.title.copyWith(
                    color: theme.colors.foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: context.fs(r.isMobile ? 16 : 18),
                  ),
                ),
              ),
              if (delta != null) ...<Widget>[
                const SizedBox(width: 4),
                Text(
                  uiSignedPercent(delta!),
                  maxLines: 1,
                  style: context.uiText.caption.copyWith(
                    color: deltaColor,
                    fontWeight: FontWeight.w700,
                    fontSize: context.fs(r.isMobile ? 11 : 12),
                  ),
                ),
              ],
            ],
          ),
          if (chart != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xs)),
            SizedBox(
              height: context.sz(r.isMobile ? 20.0 : 24.0),
              child: chart,
            ),
          ],
        ],
      ),
    );
  }
}
