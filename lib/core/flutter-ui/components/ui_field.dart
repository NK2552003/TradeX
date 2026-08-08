import 'package:flutter/material.dart';

import '../themes/ui_theme.dart';
import 'ui_label.dart';

/// Wraps any input with label / helper / error, so all form rows align.
class UiField extends StatelessWidget {
  const UiField({
    super.key,
    required this.child,
    this.label,
    this.helper,
    this.error,
    this.required = false,
  });

  final Widget child;
  final String? label;
  final String? helper;
  final String? error;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label != null) ...<Widget>[
          UiLabel(text: label!, required: required),
          SizedBox(height: context.sp(theme.spacing.xs)),
        ],
        child,
        if (error != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            error!,
            style: context.uiText.caption
                .copyWith(color: theme.colors.destructive),
          ),
        ] else if (helper != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            helper!,
            style: context.uiText.caption
                .copyWith(color: theme.colors.foregroundMuted),
          ),
        ],
      ],
    );
  }
}
