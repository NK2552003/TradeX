import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Opens a settings sub-sub page in a sleek, half-open right-sidebar overlay
/// with smooth ease-out (enter) and ease-in (exit) slide animations.
Future<T?> showSettingsSideSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget child,
  Widget? action,
  double desktopWidthRatio = 0.50,
}) {
  final theme = context.ui;
  final colors = theme.colors;
  final bool isMobile = context.uiRes.isMobile;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: colors.overlay,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (
      BuildContext ctx,
      Animation<double> anim,
      Animation<double> secAnim,
    ) {
      final double screenWidth = MediaQuery.of(ctx).size.width;
      final double targetWidth = isMobile
          ? screenWidth
          : (screenWidth * desktopWidthRatio).clamp(480.0, 740.0);

      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: targetWidth,
            height: double.infinity,
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                left: BorderSide(
                  color: colors.border,
                  width: theme.borders.hairline,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(-6, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Side Sheet Top Header
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ctx.sp(theme.spacing.lg),
                      vertical: ctx.sp(theme.spacing.md),
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: colors.border,
                          width: theme.borders.hairline,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ctx.uiText.heading.copyWith(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (subtitle != null) ...[
                                SizedBox(height: ctx.sp(theme.spacing.xxs)),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ctx.uiText.caption.copyWith(
                                    color: colors.foregroundMuted,
                                    fontSize: 12.0,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (action != null) ...[
                          action,
                          SizedBox(width: ctx.sp(theme.spacing.xs)),
                        ],
                        UiIconButton(
                          icon: Icons.close_rounded,
                          size: UiSize.sm,
                          tooltip: 'Close panel',
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),

                  // Side Sheet Body Content
                  Expanded(
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (
      BuildContext ctx,
      Animation<double> anim,
      Animation<double> secAnim,
      Widget child,
    ) {
      final curveAnim = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(curveAnim),
        child: child,
      );
    },
  );
}
