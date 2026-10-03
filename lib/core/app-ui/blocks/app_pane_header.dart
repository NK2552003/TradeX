import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';

/// Shared chrome for the top of a pane: an optional back affordance, an
/// optional leading widget (e.g. an avatar), a title/subtitle block and a row
/// of trailing actions, under a hairline bottom border.
///
/// Collapses the three near-identical hand-rolled pane headers that used to
/// live in Messages (inbox secondary + thread) and the AI assistant side
/// panel. Pure presentation — depth comes from the hairline, never a shadow.
class AppPaneHeader extends StatelessWidget {
  const AppPaneHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.leadingBack,
    this.trailing = const <Widget>[],
    this.onTitleTap,
    this.safeAreaTop = true,
    this.showBorder = true,
    this.dense = false,
    this.backTooltip = 'Back',
  });

  final String title;
  final String? subtitle;

  /// Custom leading widget (e.g. an avatar), rendered after [leadingBack].
  final Widget? leading;

  /// When non-null, a back icon button is shown at the start of the row.
  final VoidCallback? leadingBack;

  /// Right-aligned action widgets (icon buttons, badges, menus).
  final List<Widget> trailing;

  final VoidCallback? onTitleTap;
  final bool safeAreaTop;
  final bool showBorder;
  final bool dense;
  final String backTooltip;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    final Widget titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.uiText.subheading.copyWith(
            color: theme.colors.foreground,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
      ],
    );

    final Widget row = Row(
      children: <Widget>[
        if (leadingBack != null) ...<Widget>[
          UiIconButton(
            icon: Icons.arrow_back,
            size: UiSize.sm,
            tooltip: backTooltip,
            onPressed: leadingBack,
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
        ],
        if (leading != null) ...<Widget>[
          leading!,
          SizedBox(width: context.sp(theme.spacing.sm)),
        ],
        Expanded(
          child: onTitleTap == null
              ? titleBlock
              : UiInteractive(
                  onTap: onTitleTap,
                  builder: (BuildContext _, UiInteractiveState _) => titleBlock,
                ),
        ),
        for (final Widget action in trailing) ...<Widget>[
          SizedBox(width: context.sp(theme.spacing.xxs)),
          action,
        ],
      ],
    );

    final Widget padded = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: context.sp(dense ? theme.spacing.xs : theme.spacing.sm),
      ),
      child: row,
    );

    final Widget content = safeAreaTop
        ? SafeArea(bottom: false, child: padded)
        : padded;

    if (!showBorder) return content;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colors.border,
            width: theme.borders.hairline,
          ),
        ),
      ),
      child: content,
    );
  }
}
