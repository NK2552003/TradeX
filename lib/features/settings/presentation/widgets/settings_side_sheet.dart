import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Opens a settings sub-sub page in a sleek, half-open right-sidebar overlay
/// with smooth ease-out (enter) and ease-in (exit) slide animations.
Future<T?> showSettingsSideSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget child,
  Widget? action,
  double desktopWidthRatio = 0.52,
  double? maxWidth,
  double? minDesktopWidth,
}) {
  final UiTheme initialTheme = context.ui;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: initialTheme.colors.overlay,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder:
        (BuildContext ctx, Animation<double> anim, Animation<double> secAnim) {
          final UiTheme theme = ctx.ui;
          final UiColors colors = theme.colors;
          final bool isMobile = ctx.uiRes.isMobile;
          final bool isTablet = ctx.uiRes.isTablet;
          final double screenWidth = MediaQuery.of(ctx).size.width;
          final double effectiveMax = maxWidth ?? (screenWidth > 1400 ? 1200.0 : 960.0);
          final double effectiveMin = minDesktopWidth ?? 640.0;
          final double targetWidth = isMobile
              ? screenWidth
              : isTablet
              ? (screenWidth * 0.90).clamp(560.0, 840.0)
              : (screenWidth * desktopWidthRatio).clamp(effectiveMin, effectiveMax);

          final double floatingInset = isMobile ? 0 : ctx.sp(theme.spacing.sm);
          final double keyboardInset = MediaQuery.viewInsetsOf(ctx).bottom;
          final double dockInset = isMobile ? 108.0 : 0.0;
          final double bottomInset = isMobile
              ? (keyboardInset > 0 ? keyboardInset + 24.0 : dockInset)
              : (floatingInset + keyboardInset);

          final Animation<double> curveAnim = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          return Padding(
            padding: EdgeInsets.fromLTRB(
              floatingInset,
              floatingInset,
              floatingInset,
              bottomInset,
            ),
            child: Align(
              alignment: isMobile ? Alignment.bottomCenter : Alignment.centerRight,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: isMobile ? const Offset(0.0, 1.0) : const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(curveAnim),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: isMobile
                      ? BorderRadius.zero
                      : ctx.radius(theme.radii.xl),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    key: const ValueKey<String>('settings-side-sheet-surface'),
                    width: targetWidth,
                    height: double.infinity,
                    constraints: BoxConstraints(
                      maxHeight: isMobile
                          ? double.infinity
                          : MediaQuery.sizeOf(ctx).height - (floatingInset * 2),
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: isMobile
                          ? BorderRadius.zero
                          : ctx.radius(theme.radii.xl),
                      border: Border.all(
                        color: colors.border,
                        width: theme.borders.hairline,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 28,
                          offset: const Offset(-6, 0),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: isMobile
                          ? BorderRadius.zero
                          : ctx.radius(theme.radii.xl),
                      clipBehavior: Clip.antiAlias,
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
                                          SizedBox(
                                            height: ctx.sp(theme.spacing.xxs),
                                          ),
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
                            Expanded(child: child),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
    transitionBuilder:
        (
          BuildContext ctx,
          Animation<double> anim,
          Animation<double> secAnim,
          Widget child,
        ) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child,
          );
        },
  );
}
