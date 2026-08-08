import 'package:flutter/material.dart';

import '../themes/ui_theme.dart';

/// Vertical/horizontal spacer driven by the spacing scale.
class UiGap extends StatelessWidget {
  const UiGap.v(this.value, {super.key}) : horizontal = false;
  const UiGap.h(this.value, {super.key}) : horizontal = true;

  final double value;
  final bool horizontal;

  @override
  Widget build(BuildContext context) => horizontal
      ? SizedBox(width: context.sp(value))
      : SizedBox(height: context.sp(value));
}
