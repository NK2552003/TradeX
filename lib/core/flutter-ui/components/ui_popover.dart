import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';
import 'ui_dialog.dart';

/// Anchored popover; converts to a bottom sheet on phones.
class UiPopover extends StatelessWidget {
  const UiPopover({
    super.key,
    required this.trigger,
    required this.content,
    this.width,
  });

  final Widget trigger;
  final WidgetBuilder content;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return UiInteractive(
      onTap: () {
        if (context.uiRes.isMobile) {
          UiDialog.show<void>(context, child: content(context));
        } else {
          final RenderBox box = context.findRenderObject() as RenderBox;
          final Offset o = box.localToGlobal(Offset.zero);
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
                  width: width ?? context.sz(300),
                  child: Padding(
                    padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
                    child: content(context),
                  ),
                ),
              ),
            ],
          );
        }
      },
      builder: (BuildContext ctx, UiInteractiveState st) => trigger,
    );
  }
}
