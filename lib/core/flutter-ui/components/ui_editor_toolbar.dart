import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';
import 'ui_divider.dart';
import 'ui_icon_button.dart';

/// Formatting actions a rich-text editor toolbar can expose.
enum UiEditorAction {
  bold,
  italic,
  underline,
  strikethrough,
  heading,
  quote,
  bulletList,
  numberedList,
  codeBlock,
  link,
  image,
  chart,
  attachment,
  undo,
  redo,
}

extension UiEditorActionX on UiEditorAction {
  IconData get icon => switch (this) {
        UiEditorAction.bold => Icons.format_bold,
        UiEditorAction.italic => Icons.format_italic,
        UiEditorAction.underline => Icons.format_underlined,
        UiEditorAction.strikethrough => Icons.format_strikethrough,
        UiEditorAction.heading => Icons.title,
        UiEditorAction.quote => Icons.format_quote,
        UiEditorAction.bulletList => Icons.format_list_bulleted,
        UiEditorAction.numberedList => Icons.format_list_numbered,
        UiEditorAction.codeBlock => Icons.code,
        UiEditorAction.link => Icons.link,
        UiEditorAction.image => Icons.image_outlined,
        UiEditorAction.chart => Icons.candlestick_chart_outlined,
        UiEditorAction.attachment => Icons.attach_file,
        UiEditorAction.undo => Icons.undo,
        UiEditorAction.redo => Icons.redo,
      };

  String get label => switch (this) {
        UiEditorAction.bold => 'Bold',
        UiEditorAction.italic => 'Italic',
        UiEditorAction.underline => 'Underline',
        UiEditorAction.strikethrough => 'Strikethrough',
        UiEditorAction.heading => 'Heading',
        UiEditorAction.quote => 'Quote',
        UiEditorAction.bulletList => 'Bullet list',
        UiEditorAction.numberedList => 'Numbered list',
        UiEditorAction.codeBlock => 'Code block',
        UiEditorAction.link => 'Link',
        UiEditorAction.image => 'Insert image',
        UiEditorAction.chart => 'Insert chart',
        UiEditorAction.attachment => 'Attach file',
        UiEditorAction.undo => 'Undo',
        UiEditorAction.redo => 'Redo',
      };
}

/// Rich-text editor toolbar. Scrolls horizontally on phones; the editor body
/// itself is supplied by the caller (e.g. a Quill surface).
class UiEditorToolbar extends StatelessWidget {
  const UiEditorToolbar({
    super.key,
    required this.onAction,
    this.actions = const <UiEditorAction>[
      UiEditorAction.bold,
      UiEditorAction.italic,
      UiEditorAction.underline,
      UiEditorAction.heading,
      UiEditorAction.quote,
      UiEditorAction.bulletList,
      UiEditorAction.numberedList,
      UiEditorAction.codeBlock,
      UiEditorAction.link,
      UiEditorAction.image,
      UiEditorAction.chart,
    ],
    this.activeActions = const <UiEditorAction>{},
    this.trailing,
  });

  final ValueChanged<UiEditorAction> onAction;
  final List<UiEditorAction> actions;
  final Set<UiEditorAction> activeActions;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Container(
      decoration: BoxDecoration(
        color: theme.colors.surfaceMuted,
        borderRadius: context.radius(theme.radii.lg),
        border: Border.all(
          color: theme.colors.border,
          width: theme.borders.hairline,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.xs),
        vertical: context.sp(theme.spacing.xxs),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final UiEditorAction a in actions)
                    Container(
                      margin: EdgeInsets.only(right: context.sp(theme.spacing.xxs)),
                      decoration: BoxDecoration(
                        color: activeActions.contains(a)
                            ? UiIntent.primary.surface(context)
                            : null,
                        borderRadius: context.radius(theme.radii.md),
                      ),
                      child: UiIconButton(
                        icon: a.icon,
                        tooltip: a.label,
                        size: UiSize.sm,
                        variant: UiVariant.ghost,
                        onPressed: () => onAction(a),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (trailing != null) ...<Widget>[
            const UiDivider(vertical: true),
            trailing!,
          ],
        ],
      ),
    );
  }
}
