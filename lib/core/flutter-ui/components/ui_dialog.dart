import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_button.dart';
import 'ui_common.dart';
import 'ui_card.dart';
import 'ui_icon_button.dart';

class UiDialog extends StatelessWidget {
  const UiDialog({
    super.key,
    required this.title,
    this.description,
    this.content,
    this.actions = const <Widget>[],
    this.icon,
    this.intent = UiIntent.primary,
  });

  final String title;
  final String? description;
  final Widget? content;
  final List<Widget> actions;
  final IconData? icon;
  final UiIntent intent;

  /// Shows the dialog; a bottom sheet on phones, centered modal otherwise.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool dismissible = true,
    double maxWidth = 480,
  }) {
    final theme = context.ui;
    final mobile = context.uiRes.isMobile;
    return showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierColor: theme.colors.overlay,
      builder: (BuildContext ctx) => AnimatedPadding(
        duration: theme.motion.fast,
        padding:
            MediaQuery.viewInsetsOf(ctx) +
            EdgeInsets.all(
              ctx.sp(mobile ? theme.spacing.sm : theme.spacing.md),
            ),
        child: Align(
          alignment: mobile ? Alignment.bottomCenter : Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ctx.sz(maxWidth)),
            child: UiCard(
              key: const ValueKey('ui-dialog-surface'),
              padding: EdgeInsets.zero,
              variant: UiCardVariant.elevated,
              child: Material(
                type: MaterialType.transparency,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(
                    ctx.sp(mobile ? theme.spacing.lg : theme.spacing.xl),
                  ),
                  child: _UiDialogHost(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Convenience confirm dialog (e.g. "Close position?").
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? description,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    UiVariant confirmVariant = UiVariant.primary,
  }) async {
    final bool? result = await show<bool>(
      context,
      child: Builder(
        builder: (BuildContext ctx) => UiDialog(
          title: title,
          description: description,
          actions: <Widget>[
            UiButton(
              label: cancelLabel,
              variant: UiVariant.secondary,
              expandOnMobile: false,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            UiButton(
              label: confirmLabel,
              variant: confirmVariant,
              expandOnMobile: false,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final Widget dialogBody = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Container(
                padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
                decoration: BoxDecoration(
                  color: intent.surface(context),
                  borderRadius: context.radius(theme.radii.md),
                ),
                child: Icon(
                  icon,
                  color: intent.color(context),
                  size: context.sz(theme.sizes.iconMd),
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
            ],
            Expanded(
              child: Text(
                title,
                style: context.uiText.heading.copyWith(
                  color: theme.colors.foreground,
                ),
              ),
            ),
            UiIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              size: UiSize.sm,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        if (description != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          Text(
            description!,
            style: context.uiText.body.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
        ],
        if (content != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.lg)),
          content!,
        ],
        if (actions.isNotEmpty) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xl)),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: context.sp(theme.spacing.sm),
            runSpacing: context.sp(theme.spacing.sm),
            children: actions,
          ),
        ],
      ],
    );

    if (_UiDialogHost.maybeOf(context)) return dialogBody;

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(
        context.sp(
          context.uiRes.isMobile ? theme.spacing.md : theme.spacing.xl,
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.sz(560),
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: UiCard(
          key: const ValueKey<String>('ui-dialog-surface'),
          padding: EdgeInsets.zero,
          variant: UiCardVariant.elevated,
          child: Material(
            type: MaterialType.transparency,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
              child: _UiDialogHost(child: dialogBody),
            ),
          ),
        ),
      ),
    );
  }
}

class _UiDialogHost extends InheritedWidget {
  const _UiDialogHost({required super.child});

  static bool maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_UiDialogHost>() != null;

  @override
  bool updateShouldNotify(_UiDialogHost oldWidget) => false;
}
