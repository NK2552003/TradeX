import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';

/// Form label with optional required marker and helper/error text.
class UiLabel extends StatelessWidget {
  const UiLabel({
    super.key,
    required this.text,
    bool required = false,
    bool? isRequired,
    this.disabled = false,
    this.helper,
    this.maxLines = 2,
  }) : required = isRequired ?? required;

  final String text;
  final bool required;
  final bool disabled;
  final String? helper;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final Color color = disabled
        ? theme.colors.disabledForeground
        : theme.colors.foreground;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text.rich(
          TextSpan(
            style: context.uiText.label.copyWith(color: color),
            children: <InlineSpan>[
              TextSpan(text: text),
              if (required)
                TextSpan(
                  text: ' *',
                  style: context.uiText.label.copyWith(
                    color: theme.colors.destructive,
                  ),
                ),
            ],
          ),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
        if (helper != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            helper!,
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
        ],
      ],
    );
  }
}
