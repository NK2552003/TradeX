import 'package:flutter/material.dart';

import '../themes/ui_theme.dart';
import 'ui_common.dart';

/// Surface container used for every panel in the app (feed post, watchlist,
/// KPI tile, chart wrapper).
class UiCard extends StatelessWidget {
  const UiCard({
    super.key,
    required this.child,
    this.padding,
    this.title,
    this.subtitle,
    this.trailing,
    this.footer,
    this.onTap,
    this.elevated = false,
    this.accentColor,
    this.borderless = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? footer;
  final VoidCallback? onTap;
  final bool elevated;
  final Color? accentColor;
  final bool borderless;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final r = context.uiRes;
    final BorderRadius radius = context.radius(theme.radii.xl);
    final EdgeInsetsGeometry pad = padding ??
        EdgeInsets.all(
          context.sp(r.isMobile ? theme.spacing.lg : theme.spacing.xl),
        );

    return UiInteractive(
      enabled: onTap != null,
      onTap: onTap,
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      builder: (BuildContext ctx, UiInteractiveState s) => AnimatedContainer(
        duration: theme.motion.fast,
        curve: theme.motion.curve,
        decoration: BoxDecoration(
          color: s.hovered && onTap != null
              ? theme.colors.surfaceMuted
              : theme.colors.surface,
          borderRadius: radius,
          border: borderless
              ? null
              : Border.all(
                  color: s.hovered && onTap != null
                      ? theme.colors.borderStrong
                      : theme.colors.border,
                  width: theme.borders.hairline,
                ),
          boxShadow: elevated ? theme.shadows.md : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (accentColor != null)
              Container(width: ctx.sz(3), color: accentColor),
            Expanded(
              child: Padding(
                padding: pad,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (title != null || trailing != null)
                      _UiCardHeader(
                        title: title,
                        subtitle: subtitle,
                        trailing: trailing,
                      ),
                    if (title != null || trailing != null)
                      SizedBox(height: ctx.sp(theme.spacing.md)),
                    child,
                    if (footer != null) ...<Widget>[
                      SizedBox(height: ctx.sp(theme.spacing.md)),
                      Divider(
                        height: theme.borders.hairline,
                        color: theme.colors.border,
                      ),
                      SizedBox(height: ctx.sp(theme.spacing.md)),
                      footer!,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UiCardHeader extends StatelessWidget {
  const _UiCardHeader({this.title, this.subtitle, this.trailing});

  final String? title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (title != null)
                Text(
                  title!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.heading
                      .copyWith(color: theme.colors.foreground),
                ),
              if (subtitle != null) ...<Widget>[
                SizedBox(height: context.sp(theme.spacing.xxs)),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption
                      .copyWith(color: theme.colors.foregroundMuted),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          SizedBox(width: context.sp(theme.spacing.sm)),
          trailing!,
        ],
      ],
    );
  }
}
