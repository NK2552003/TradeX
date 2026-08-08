import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';

/// Page scaffold: max content width, responsive padding, optional sticky header.
class UiPage extends StatelessWidget {
  const UiPage({
    super.key,
    required this.child,
    this.header,
    this.scrollable = true,
    this.maxWidth,
  });

  final Widget child;
  final Widget? header;
  final bool scrollable;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final r = context.uiRes;
    final EdgeInsets pad = EdgeInsets.symmetric(
      horizontal: context.sp(
        r.pick<double>(
          mobile: theme.spacing.lg,
          tablet: theme.spacing.xl,
          desktop: theme.spacing.xxl,
        ),
      ),
      vertical: context.sp(theme.spacing.lg),
    );

    Widget body = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? context.sz(theme.sizes.maxContentWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (header != null) ...<Widget>[
            header!,
            SizedBox(height: context.sp(theme.spacing.lg)),
          ],
          child,
        ],
      ),
    );

    body = Padding(padding: pad, child: Center(child: body));
    return ColoredBox(
      color: theme.colors.background,
      child: SafeArea(
        child: scrollable ? SingleChildScrollView(child: body) : body,
      ),
    );
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
    return Row(
      children: <Widget>[
        if (leading != null) ...<Widget>[
          leading!,
          SizedBox(width: context.sp(theme.spacing.md)),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (context.uiRes.isMobile
                        ? context.uiText.title
                        : context.uiText.display)
                    .copyWith(color: theme.colors.foreground),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.body
                      .copyWith(color: theme.colors.foregroundMuted),
                ),
            ],
          ),
        ),
        if (actions.isNotEmpty) ...<Widget>[
          SizedBox(width: context.sp(theme.spacing.md)),
          Wrap(
            spacing: context.sp(theme.spacing.sm),
            children: actions,
          ),
        ],
      ],
    );
  }
}
