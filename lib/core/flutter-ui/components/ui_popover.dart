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
          final Size screen = MediaQuery.sizeOf(context);
          final double effectiveWidth = math.min(
            context.sz(width ?? 300),
            math.max(120.0, screen.width - 32),
          );
          final double left = o.dx.clamp(
            16.0,
            math.max(16.0, screen.width - effectiveWidth - 16.0),
          );
          final bool openUp = o.dy + box.size.height + 240 > screen.height &&
              o.dy > screen.height * 0.45;

          UiDialog.present<void>(
            context: context,
            barrierDismissible: true,
            barrierColor: Colors.transparent,
            builder: (BuildContext dialogCtx) => Stack(
              children: <Widget>[
                Positioned(
                  left: left,
                  top: openUp ? null : o.dy + box.size.height + 6,
                  bottom: openUp ? (screen.height - o.dy + 6) : null,
                  width: effectiveWidth,
                  child: Material(
                    color: theme.colors.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: dialogCtx.radius(theme.radii.lg),
                      side: BorderSide(
                        color: theme.colors.border,
                        width: theme.borders.hairline,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: screen.height * 0.65,
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(dialogCtx.sp(theme.spacing.lg)),
                        child: resolved,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      },
      builder: (_, _) => trigger,
    );
  }
}
