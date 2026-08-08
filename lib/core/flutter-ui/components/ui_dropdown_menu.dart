import 'package:flutter/material.dart';

import '../themes/ui_theme.dart';
import 'ui_common.dart';

class UiMenuAction {
  const UiMenuAction({
    required this.label,
    required this.onSelected,
    this.icon,
    this.destructive = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onSelected;
  final IconData? icon;
  final bool destructive;
  final bool enabled;
}

/// Context/overflow menu (post actions: share, report, mute).
class UiDropdownMenu extends StatelessWidget {
  const UiDropdownMenu({
    super.key,
    required this.actions,
    this.icon = Icons.more_horiz,
    this.child,
  });

  final List<UiMenuAction> actions;
  final IconData icon;
  final Widget? child;

  Future<void> _open(BuildContext context) async {
    final theme = context.ui;
    if (context.uiRes.isMobile) {
      final int? index = await showModalBottomSheet<int>(
        context: context,
        backgroundColor: theme.colors.surface,
        barrierColor: theme.colors.overlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(context.sz(theme.radii.xxl)),
          ),
        ),
        builder: (BuildContext ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < actions.length; i++)
                _UiMenuRow(
                  action: actions[i],
                  onTap: () => Navigator.of(ctx).pop(i),
                ),
            ],
          ),
        ),
      );
      if (index != null) actions[index].onSelected();
      return;
    }

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset o = box.localToGlobal(Offset.zero);
    final int? index = await showMenu<int>(
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
      items: <PopupMenuEntry<int>>[
        for (int i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value: i,
            enabled: actions[i].enabled,
            padding: EdgeInsets.zero,
            child: _UiMenuRow(action: actions[i]),
          ),
      ],
    );
    if (index != null) actions[index].onSelected();
  }

  @override
  Widget build(BuildContext context) => UiInteractive(
        onTap: () => _open(context),
        builder: (BuildContext ctx, UiInteractiveState s) =>
            child ??
            Icon(
              icon,
              size: ctx.sz(ctx.uiSizes.iconMd),
              color: s.hovered
                  ? ctx.uiColors.foreground
                  : ctx.uiColors.foregroundMuted,
            ),
      );
}

class _UiMenuRow extends StatelessWidget {
  const _UiMenuRow({required this.action, this.onTap});

  final UiMenuAction action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final Color fg = !action.enabled
        ? theme.colors.disabledForeground
        : action.destructive
            ? theme.colors.destructive
            : theme.colors.foreground;
    return UiInteractive(
      enabled: action.enabled,
      onTap: onTap ?? action.onSelected,
      builder: (BuildContext ctx, UiInteractiveState s) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: ctx.sp(theme.spacing.lg),
          vertical: ctx.sp(theme.spacing.md),
        ),
        color: s.hovered ? theme.colors.surfaceHover : Colors.transparent,
        child: Row(
          children: <Widget>[
            if (action.icon != null) ...<Widget>[
              Icon(action.icon, size: ctx.sz(theme.sizes.iconSm), color: fg),
              SizedBox(width: ctx.sp(theme.spacing.md)),
            ],
            Expanded(
              child: Text(
                action.label,
                style: ctx.uiText.body.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
