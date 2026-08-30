import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import '../theme/ui_tokens.dart';

/// A sleek, customizable thin scrollbar component matching the design system.
class UiScrollbar extends StatelessWidget {
  const UiScrollbar({
    super.key,
    required this.child,
    this.controller,
    this.thumbVisibility,
    this.thickness,
    this.radius,
    this.interactive = true,
  });

  final Widget child;
  final ScrollController? controller;
  final bool? thumbVisibility;
  final double? thickness;
  final Radius? radius;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return RawScrollbar(
      controller: controller,
      thumbVisibility: thumbVisibility,
      thickness: thickness ?? 4.0,
      radius: radius ?? const Radius.circular(8.0),
      interactive: interactive,
      thumbColor: colors.border.withValues(alpha: 0.7),
      crossAxisMargin: 2.0,
      mainAxisMargin: 2.0,
      child: child,
    );
  }
}
