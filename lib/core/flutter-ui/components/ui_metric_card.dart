import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_card.dart';
import 'ui_common.dart';

/// KPI / metric tile built on [UiCard]; used for portfolio stats.
class UiMetricCard extends StatelessWidget {
  const UiMetricCard({
    super.key,
    String? label,
    String? title,
    required this.value,
    this.delta,
    this.change,
    this.isPositive,
    String? subtitle,
    String? caption,
    this.icon,
    this.chart,
    this.sparkline,
    this.intent,
    this.onTap,
  }) : label = title ?? label ?? '',
       subtitle = subtitle ?? caption;

  final String label;
  final String value;
  final num? delta;
  final String? change;
  final bool? isPositive;
  final String? subtitle;
  final IconData? icon;
  final Widget? chart;
  final List<double>? sparkline;
  final UiIntent? intent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final r = context.uiRes;

    final String? effectiveChange = change ?? (delta != null ? uiSignedPercent(delta!) : null);
    final Color deltaColor = isPositive != null
        ? (isPositive! ? theme.colors.bullish : theme.colors.bearish)
        : (delta == null
            ? theme.colors.foregroundMuted
            : (delta! >= 0 ? theme.colors.bullish : theme.colors.bearish));

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
          if (subtitle != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xxs)),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundSubtle,
              ),
            ),
          ],
          SizedBox(height: context.sp(theme.spacing.xs)),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xxs),
            children: <Widget>[
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.title.copyWith(
                  color: theme.colors.foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: context.fs(r.isMobile ? 16 : 18),
                ),
              ),
              if (effectiveChange != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(theme.spacing.xs),
                    vertical: context.sp(theme.spacing.xxs * 0.5),
                  ),
                  decoration: BoxDecoration(
                    color: deltaColor.withValues(alpha: 0.12),
                    borderRadius: context.radius(theme.radii.sm),
                  ),
                  child: Text(
                    effectiveChange,
                    maxLines: 1,
                    style: context.uiText.caption.copyWith(
                      color: deltaColor,
                      fontWeight: FontWeight.w700,
                      fontSize: context.fs(r.isMobile ? 11 : 12),
                    ),
                  ),
                ),
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
