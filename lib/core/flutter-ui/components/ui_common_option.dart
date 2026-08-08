import 'package:flutter/material.dart';

import '../themes/ui_theme.dart';

class UiOption<T> {
  const UiOption({
    required this.value,
    required this.label,
    this.description,
    this.icon,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? description;
  final IconData? icon;
  final bool enabled;
}
