import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Reusable interactive drill-in navigation row for settings lists.
class SettingsNavRow extends StatelessWidget {
  const SettingsNavRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.badgeLabel,
    this.badgeIntent = UiIntent.primary,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? badgeLabel;
  final UiIntent badgeIntent;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    return UiCard(
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: context.sp(theme.spacing.sm + 2),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: EdgeInsets.all(context.sp(theme.spacing.xs + 2)),
              decoration: BoxDecoration(
                color: isDestructive
                    ? colors.bearish.withValues(alpha: 0.12)
                    : colors.primary.withValues(alpha: 0.08),
                borderRadius: context.radius(theme.radii.md),
              ),
              child: Icon(
                icon,
                size: context.sz(theme.sizes.iconSm),
                color: isDestructive ? colors.bearish : colors.primary,
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.md)),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: context.sp(theme.spacing.xs),
                  runSpacing: context.sp(theme.spacing.xxs),
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.bodyStrong.copyWith(
                        color: isDestructive
                            ? colors.bearish
                            : colors.foreground,
                      ),
                    ),
                    if (badgeLabel != null) ...[
                      UiBadge(
                        label: badgeLabel!,
                        intent: badgeIntent,
                        size: UiSize.xs,
                      ),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Text(
                    subtitle!,
                    style: context.uiText.caption.copyWith(
                      color: colors.foregroundMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: context.sz(theme.sizes.iconSm),
              color: colors.foregroundSubtle,
            ),
        ],
      ),
    );
  }
}
