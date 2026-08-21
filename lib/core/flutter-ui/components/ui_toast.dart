import 'package:flutter/material.dart';
import '../theme/ui_theme.dart';
import 'ui_common.dart';
import 'ui_toaster.dart';

/// Sonner-inspired modern toast component with clean typography, elevation,
/// zero underlines, semantic intent badges, and action support.
class UiToast extends StatelessWidget {
  const UiToast({super.key, required this.data, this.onDismiss});

  final UiToastData data;
  final VoidCallback? onDismiss;

  /// General toast trigger.
  static void show(
    BuildContext context, {
    required String title,
    String? message,
    UiIntent intent = UiIntent.neutral,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final scope = UiToastScope.maybeOf(context);
    final toastData = UiToastData(
      title: title,
      message: message,
      intent: intent,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );

    if (scope != null) {
      scope.show(toastData);
    } else {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$title${message != null ? ' — $message' : ''}',
              style: const TextStyle(decoration: TextDecoration.none),
            ),
            duration: duration,
          ),
        );
      } catch (_) {}
    }
  }

  /// Convenience helper for success toasts.
  static void success(
    BuildContext context, {
    required String title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      title: title,
      message: message,
      intent: UiIntent.success,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Convenience helper for error / destructive toasts.
  static void error(
    BuildContext context, {
    required String title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      title: title,
      message: message,
      intent: UiIntent.danger,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Convenience helper for warning toasts.
  static void warning(
    BuildContext context, {
    required String title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      title: title,
      message: message,
      intent: UiIntent.warning,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Convenience helper for informational toasts.
  static void info(
    BuildContext context, {
    required String title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      title: title,
      message: message,
      intent: UiIntent.info,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  IconData _resolveIcon(UiIntent intent) {
    if (data.icon != null) return data.icon!;
    switch (intent) {
      case UiIntent.success:
      case UiIntent.bullish:
        return Icons.check_circle_rounded;
      case UiIntent.danger:
      case UiIntent.bearish:
        return Icons.error_rounded;
      case UiIntent.warning:
        return Icons.warning_rounded;
      case UiIntent.info:
      case UiIntent.primary:
        return Icons.info_rounded;
      case UiIntent.neutral:
        return Icons.notifications_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final Color accent = data.intent.color(context);
    final IconData icon = _resolveIcon(data.intent);

    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: TextStyle(
          fontFamily: theme.typography.fontFamily,
          decoration: TextDecoration.none,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: context.sz(320),
            maxWidth: context.sz(420),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.md),
              vertical:
                  context.sp(theme.spacing.sm) + context.sp(theme.spacing.xxs),
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: context.radius(theme.radii.lg),
              border: Border.all(
                color: colors.border,
                width: theme.borders.hairline,
              ),
              boxShadow: theme.shadows.lg,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Sonner Status Icon Badge
                Padding(
                  padding: EdgeInsets.only(top: context.sp(theme.spacing.xxs)),
                  child: Container(
                    padding: EdgeInsets.all(context.sp(theme.spacing.xxs)),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: accent, size: context.sz(16)),
                  ),
                ),
                SizedBox(
                  width:
                      context.sp(theme.spacing.sm) +
                      context.sp(theme.spacing.xxs),
                ),

                // Title and Description Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        data.title,
                        style: context.uiText.bodyStrong.copyWith(
                          color: colors.foreground,
                          fontSize: context.fs(13.5),
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      if (data.message != null &&
                          data.message!.isNotEmpty) ...<Widget>[
                        SizedBox(height: context.sp(theme.spacing.xxs)),
                        Text(
                          data.message!,
                          style: context.uiText.caption.copyWith(
                            color: colors.foregroundMuted,
                            fontSize: context.fs(12.5),
                            height: 1.4,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Optional Sonner Action Button
                if (data.actionLabel != null &&
                    data.onAction != null) ...<Widget>[
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  GestureDetector(
                    onTap: () {
                      data.onAction?.call();
                      onDismiss?.call();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.sp(theme.spacing.sm),
                        vertical: context.sp(theme.spacing.xxs),
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: context.radius(theme.radii.sm),
                        border: Border.all(
                          color: colors.border,
                          width: theme.borders.hairline,
                        ),
                      ),
                      child: Text(
                        data.actionLabel!,
                        style: context.uiText.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.foreground,
                          fontSize: context.fs(11.5),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ],

                // Close Button
                SizedBox(width: context.sp(theme.spacing.xs)),
                GestureDetector(
                  onTap: onDismiss,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: context.sp(theme.spacing.xxs),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: context.sz(14),
                      color: colors.foregroundSubtle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
