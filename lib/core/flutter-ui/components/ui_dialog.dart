import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_button.dart';
import 'ui_common.dart';
import 'ui_card.dart';
import 'ui_icon_button.dart';
import 'ui_gap.dart';

class UiDialog extends StatelessWidget {
  const UiDialog({
    super.key,
    required this.title,
    this.description,
    Widget? content,
    Widget? child,
    this.actions = const <Widget>[],
    this.icon,
    this.leading,
    this.footer,
    this.intent = UiIntent.primary,
  }) : content = content ?? child;

  final String title;
  final String? description;
  final Widget? content;
  final List<Widget> actions;
  final IconData? icon;
  final Widget? leading;
  final Widget? footer;
  final UiIntent intent;

  /// Completes after the closing transition has removed the dialog's fields.
  /// Callers may then safely dispose their text controllers.
  static Future<T?> present<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<T>(
      context: context,
      builder: builder,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? context.ui.colors.overlay,
    );
    final result = await navigator.push<T>(route);
    await route.completed;
    return result;
  }

  /// Shows the dialog; a bottom sheet on phones, centered modal otherwise.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool dismissible = true,
    double maxWidth = 480,
    bool pinFooter = false,
    bool blurBackdrop = false,
  }) {
    final theme = context.ui;
    return present<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierColor: theme.colors.overlay,
      builder: (BuildContext ctx) {
        final mobile = ctx.uiRes.isMobile;
        final inset = EdgeInsets.all(
          ctx.sp(mobile ? theme.spacing.lg : theme.spacing.xl),
        );
        final body = _UiDialogHost(pinFooter: pinFooter, child: child);
        final panel = AnimatedPadding(
          duration: theme.motion.fast,
          padding:
              MediaQuery.viewInsetsOf(ctx) +
              EdgeInsets.all(ctx.sp(mobile ? 0 : theme.spacing.md)),
          child: Align(
            alignment: mobile ? Alignment.bottomCenter : Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ctx.sz(maxWidth),
                maxHeight:
                    MediaQuery.sizeOf(ctx).height * (mobile ? 0.92 : 0.88),
              ),
              child: UiCard(
                key: const ValueKey('ui-dialog-surface'),
                padding: EdgeInsets.zero,
                variant: UiCardVariant.elevated,
                borderRadius: mobile
                    ? BorderRadius.vertical(
                        top: Radius.circular(ctx.sz(theme.radii.xl)),
                      )
                    : null,
                child: Material(
                  type: MaterialType.transparency,
                  child: pinFooter
                      ? Padding(padding: inset, child: body)
                      : SingleChildScrollView(padding: inset, child: body),
                ),
              ),
            ),
          ),
        );
        final blur = ctx.sp(theme.spacing.xs);
        return blurBackdrop
            ? BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: panel,
              )
            : panel;
      },
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
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (leading != null) ...[
          leading!,
          UiGap.h(theme.spacing.md),
        ] else if (icon != null) ...<Widget>[
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
          size: footer == null ? UiSize.sm : UiSize.md,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
    final Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
          if (context.uiRes.isMobile && actions.length <= 2)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = actions.length - 1; i >= 0; i--) ...<Widget>[
                  if (i < actions.length - 1)
                    SizedBox(height: context.sp(theme.spacing.xs)),
                  actions[i],
                ],
              ],
            )
          else
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: context.sp(theme.spacing.sm),
                runSpacing: context.sp(theme.spacing.sm),
                children: actions,
              ),
            ),
        ],
      ],
    );

    final host = _UiDialogHost.maybeOf(context);
    final bottom = footer;
    final completeBody = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, body, ?bottom],
    );
    if (host != null) {
      if (!host.pinFooter) return completeBody;
      return LayoutBuilder(
        builder: (context, constraints) {
          // On short windows or at large font sizes, let the entire sheet scroll.
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final roomForActions =
              context.sz(theme.sizes.minTapTarget) * 6 * textScale;
          if (bottom == null || constraints.maxHeight < roomForActions) {
            return SingleChildScrollView(child: completeBody);
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Flexible(child: SingleChildScrollView(child: body)),
              bottom,
            ],
          );
        },
      );
    }

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
              child: _UiDialogHost(child: completeBody),
            ),
          ),
        ),
      ),
    );
  }
}

class _UiDialogHost extends InheritedWidget {
  const _UiDialogHost({required super.child, this.pinFooter = false});
  final bool pinFooter;

  static _UiDialogHost? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_UiDialogHost>();

  @override
  bool updateShouldNotify(_UiDialogHost oldWidget) =>
      pinFooter != oldWidget.pinFooter;
}
