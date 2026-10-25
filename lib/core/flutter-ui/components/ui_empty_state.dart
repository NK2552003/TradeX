import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_button.dart';
import 'ui_common.dart';

/// Empty state block used by feeds, watchlists and search results.
class UiEmptyState extends StatelessWidget {
  const UiEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.actionLabel,
    this.onActionPressed,
    this.compact = false,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.xxl)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colors.surfaceMuted,
              ),
              child: Icon(
                icon,
                size: context.sz(theme.sizes.iconLg),
                color: theme.colors.foregroundSubtle,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.lg)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.uiText.subheading.copyWith(
                color: theme.colors.foreground,
              ),
            ),
            if (message != null) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.xs)),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: context.uiText.body.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
            if (action != null || actionLabel != null) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.lg)),
              action ??
                  UiButton(
                    label: actionLabel!,
                    onPressed: onActionPressed ?? () {},
                    variant: UiVariant.solid,
                    intent: UiIntent.primary,
                  ),
            ],
          ],
        ),
      ),
    );
  }
}
