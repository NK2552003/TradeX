import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';
import 'ui_dialog.dart';

/// Anchored popover; converts to a bottom sheet on phones.
class UiPopover extends StatelessWidget {
  const UiPopover({
    super.key,
    Widget? trigger,
    Widget? child,
    required this.content,
    this.width,
  }) : trigger = trigger ?? child ?? const SizedBox.shrink();

  final Widget trigger;
  final dynamic content;
  /// Panel width in logical points (scaled internally).
  final double? width;

  Widget _resolveContent(BuildContext context) {
    if (content is Widget Function(BuildContext)) {
      return (content as Widget Function(BuildContext))(context);
    }
    if (content is Widget) {
      return content as Widget;
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return UiInteractive(
      onTap: () {
        final Widget resolved = _resolveContent(context);
        if (context.uiRes.isMobile) {
          UiDialog.show<void>(context, child: resolved);
        } else {
          final RenderBox? box = context.findRenderObject() as RenderBox?;
          if (box == null || !box.hasSize) return;
          final Offset o = box.localToGlobal(Offset.zero);
          final double screenWidth = MediaQuery.sizeOf(context).width;
          final double effectiveWidth = math.min(
            context.sz(width ?? 300),
            screenWidth - 32,
          );

          showMenu<void>(
            context: context,
            color: theme.colors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: context.radius(theme.radii.lg),
              side: BorderSide(
                color: theme.colors.border,
                width: theme.borders.hairline,
              ),
            ),
            position: RelativeRect.fromLTRB(
              o.dx,
              o.dy + box.size.height,
              o.dx + box.size.width,
              o.dy,
            ),
            items: <PopupMenuEntry<void>>[
              PopupMenuItem<void>(
                enabled: false,
                padding: EdgeInsets.zero,
                child: SizedBox(
                  width: effectiveWidth,
                  child: Padding(
                    padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
                    child: resolved,
                  ),
                ),
              ),
            ],
          );
        }
      },
      builder: (_, _) => trigger,
    );
  }
}
