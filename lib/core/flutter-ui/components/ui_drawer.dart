import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_icon_button.dart';
import 'ui_card.dart';

/// Inset, floating side panel. On phones it sits above the safe area and keyboard.
class UiDrawer extends StatelessWidget {
  const UiDrawer({
    super.key,
    required this.title,
    required this.child,
    this.isOpen = true,
    this.onClose,
    this.footer,
    this.scrollable = true,
    this.showHeader = true,
    this.contentPadding,
  });

  final String title;
  final Widget child;
  final bool isOpen;
  final VoidCallback? onClose;
  final Widget? footer;
  final bool scrollable;
  final bool showHeader;
  final EdgeInsetsGeometry? contentPadding;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget child,
    Widget? footer,
    bool fromRight = true,
    double width = 420,
    bool scrollable = true,
    bool showHeader = true,
    EdgeInsetsGeometry? contentPadding,
  }) {
    final theme = context.ui;
    final bool mobile = context.uiRes.isMobile;
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      barrierColor: theme.colors.overlay,
      transitionDuration: theme.motion.normal,
      pageBuilder: (BuildContext ctx, _, _) => SafeArea(
        top: true,
        bottom: !mobile,
        child: AnimatedPadding(
          duration: MediaQuery.disableAnimationsOf(ctx)
              ? Duration.zero
              : theme.motion.fast,
          padding:
              MediaQuery.viewInsetsOf(ctx) +
              (mobile
                  ? EdgeInsets.zero
                  : EdgeInsets.all(ctx.sp(theme.spacing.md))),
          child: LayoutBuilder(
            builder: (context, box) => Align(
              alignment: mobile
                  ? Alignment.bottomCenter
                  : (fromRight ? Alignment.centerRight : Alignment.centerLeft),
              child: SizedBox(
                width: mobile
                    ? double.infinity
                    : ctx.sz(width).clamp(0.0, box.maxWidth),
                height: mobile ? box.maxHeight * .94 : box.maxHeight,
                child: UiCard(
                  key: const ValueKey('ui-drawer-surface'),
                  padding: EdgeInsets.zero,
                  variant: UiCardVariant.elevated,
                  borderRadius: mobile
                      ? BorderRadius.vertical(
                          top: Radius.circular(ctx.sz(theme.radii.xl)),
                        )
                      : null,
                  child: SafeArea(
                    top: false,
                    bottom: mobile,
                    child: Material(
                      type: MaterialType.transparency,
                      child: UiDrawer(
                        title: title,
                        footer: footer,
                        scrollable: scrollable,
                        showHeader: showHeader,
                        contentPadding: contentPadding,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder:
          (
            BuildContext ctx,
            Animation<double> anim,
            _,
            Widget child,
          ) => SlideTransition(
            position: Tween<Offset>(
              begin: mobile
                  ? const Offset(0, 1)
                  : Offset(fromRight ? 1 : -1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: theme.motion.curve)),
            child: child,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isOpen) return const SizedBox.shrink();
    final theme = context.ui;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool boundedHeight = constraints.hasBoundedHeight;
        final Widget body = scrollable
            ? SingleChildScrollView(
                padding:
                    contentPadding ??
                    EdgeInsets.all(context.sp(theme.spacing.lg)),
                child: child,
              )
            : Padding(
                padding:
                    contentPadding ??
                    EdgeInsets.all(context.sp(theme.spacing.lg)),
                child: child,
              );
        return Column(
          mainAxisSize: boundedHeight ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (showHeader)
              Padding(
                padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: context.uiText.heading.copyWith(
                          color: theme.colors.foreground,
                        ),
                      ),
                    ),
                    UiIconButton(
                      icon: Icons.close,
                      tooltip: 'Close',
                      onPressed:
                          onClose ?? () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
            if (showHeader)
              Container(
                height: theme.borders.hairline,
                color: theme.colors.border,
              ),
            if (boundedHeight)
              Expanded(child: body)
            else
              Flexible(fit: FlexFit.loose, child: body),
            if (footer != null) ...<Widget>[
              Container(
                height: theme.borders.hairline,
                color: theme.colors.border,
              ),
              Padding(
                padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
                child: footer!,
              ),
            ],
          ],
        );
      },
    );
  }
}
