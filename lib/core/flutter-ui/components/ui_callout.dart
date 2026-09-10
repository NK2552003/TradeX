import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';

/// Inline informational banner (risk warnings, market-closed notices).
class UiCallout extends StatelessWidget {
  const UiCallout({
    super.key,
    this.title,
    this.message,
    this.description,
    this.content,
    this.child,
    this.intent = UiIntent.info,
    this.icon,
    this.onClose,
    this.action,
  });

  final String? title;
  final String? message;
  final String? description;
  final Widget? content;
  final Widget? child;
  final UiIntent intent;
  final IconData? icon;
  final VoidCallback? onClose;
  final Widget? action;

  IconData get _defaultIcon => intent.icon;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final responsive = context.uiRes;
    final Color base = intent.color(context);
    final String? bodyText = message ?? description;
    final Widget? bodyContent = content ?? child;

    return Container(
      padding: EdgeInsets.all(
        context.sp(responsive.isMobile ? theme.spacing.md : theme.spacing.lg),
      ),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.08),
        borderRadius: context.radius(theme.radii.lg),
        border: Border.all(
          color: base.withValues(alpha: 0.28),
          width: theme.borders.hairline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon ?? _defaultIcon,
            color: base,
            size: context.sz(
              responsive.isMobile ? theme.sizes.iconSm : theme.sizes.iconMd,
            ),
          ),
          SizedBox(
            width: context.sp(
              responsive.isMobile ? theme.spacing.sm : theme.spacing.md,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (title != null && title!.isNotEmpty)
                  Text(
                    title!,
                    style: context.uiText.bodyStrong.copyWith(color: base),
                  ),
                if (bodyText != null && bodyText.isNotEmpty) ...<Widget>[
                  if (title != null && title!.isNotEmpty)
                    SizedBox(height: context.sp(theme.spacing.xs)),
                  Text(
                    bodyText,
                    style: context.uiText.body.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
                if (bodyContent != null) ...<Widget>[
                  if (title != null || bodyText != null)
                    SizedBox(height: context.sp(theme.spacing.xs)),
                  bodyContent,
                ],
                if (action != null) ...<Widget>[
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  action!,
                ],
              ],
            ),
          ),
          if (onClose != null)
            Padding(
              padding: EdgeInsets.only(left: context.sp(theme.spacing.xs)),
              child: UiInteractive(
                onTap: onClose,
                semanticLabel: 'Dismiss notice',
                builder: (BuildContext ctx, UiInteractiveState s) => Container(
                  width: ctx.sz(32),
                  height: ctx.sz(32),
                  decoration: BoxDecoration(
                    color: s.hovered
                        ? base.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: ctx.radius(theme.radii.sm),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.close,
                    size: ctx.sz(theme.sizes.iconSm),
                    color: s.hovered ? base : theme.colors.foregroundSubtle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
