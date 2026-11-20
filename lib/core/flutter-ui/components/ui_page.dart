import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';

/// Page scaffold: max content width, responsive padding, optional sticky header.
class UiPage extends StatelessWidget {
  UiPage({
    super.key,
    required this.child,
    Widget? header,
    String? title,
    String? subtitle,
    List<Widget>? actions,
    this.scrollable = true,
    this.scrollController,
    this.maxWidth,
  }) : header =
           header ??
           (title != null
               ? UiHeader(
                   title: title,
                   subtitle: subtitle,
                   actions: actions ?? const <Widget>[],
                 )
               : null);

  final Widget child;
  final Widget? header;
  final bool scrollable;
  final ScrollController? scrollController;

  /// Content column cap in logical points (scaled internally).
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final r = context.uiRes;
    final EdgeInsets pad = EdgeInsets.symmetric(
      horizontal: context.sp(
        r.pick<double>(
          mobile: theme.spacing.sm,
          tablet: theme.spacing.md,
          desktop: theme.spacing.lg,
        ),
      ),
      vertical: context.sp(theme.spacing.lg),
    );

    final double? rawMaxWidth = maxWidth;
    final double maxW = (rawMaxWidth == null || rawMaxWidth.isInfinite)
        ? (rawMaxWidth ?? context.sz(theme.sizes.maxContentWidth))
        : context.sz(rawMaxWidth);

    Widget body = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (header != null) ...<Widget>[
            header!,
            SizedBox(height: context.sp(theme.spacing.lg)),
          ],
          if (scrollable) child else Expanded(child: child),
        ],
      ),
    );

    final EdgeInsets safePad = MediaQuery.paddingOf(context);
    if (scrollable) {
      // Apply safe-area insets inside the ScrollView rather than wrapping it
      // in an outer SafeArea so content starts cleanly below floating headers
      // at rest and scrolls smoothly behind translucent frosted-glass chrome.
      return SingleChildScrollView(
        controller: scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          pad.left + safePad.left,
          pad.top + safePad.top,
          pad.right + safePad.right,
          pad.bottom + safePad.bottom,
        ),
        child: Align(alignment: Alignment.topCenter, child: body),
      );
    }
    body = Padding(
      padding: pad,
      child: Align(alignment: Alignment.topCenter, child: body),
    );
    return SafeArea(child: SizedBox.expand(child: body));
  }
}

/// Responsive header row: title + actions that never clip on small widths.
class UiHeader extends StatelessWidget {
  const UiHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final Widget identity = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (leading != null) ...<Widget>[
          leading!,
          SizedBox(width: context.sp(theme.spacing.sm)),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: context.uiText.title.copyWith(
                  color: theme.colors.foreground,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                SizedBox(height: context.sp(theme.spacing.xxs)),
                Text(
                  subtitle!,
                  style: context.uiText.body.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (actions.isEmpty) return identity;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget actionRow = Wrap(
          spacing: context.sp(theme.spacing.xs),
          runSpacing: context.sp(theme.spacing.xs),
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actions,
        );
        if (actions.isNotEmpty && constraints.maxWidth < context.sz(720)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              identity,
              SizedBox(height: context.sp(theme.spacing.sm)),
              Align(alignment: Alignment.centerLeft, child: actionRow),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: identity),
            if (actions.isNotEmpty) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.md)),
              Flexible(
                child: Align(alignment: Alignment.topRight, child: actionRow),
              ),
            ],
          ],
        );
      },
    );
  }
}
