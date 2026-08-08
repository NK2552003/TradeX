import 'package:flutter/material.dart';

import 'ui_common.dart';
import 'ui_input.dart';

/// Multi-line text field (Textarea). Own component so screens read clearly;
/// the field chrome, focus ring and error state come from [UiInput].
class UiTextarea extends StatelessWidget {
  const UiTextarea({
    super.key,
    this.controller,
    this.hintText,
    this.value,
    this.onChanged,
    this.enabled = true,
    this.readOnly = false,
    this.error = false,
    this.size = UiSize.md,
    this.rows = 4,
    this.maxRows = 8,
    this.maxLength,
    this.autofocus = false,
    this.label,
  });

  final TextEditingController? controller;
  final String? hintText;
  final String? value;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool readOnly;
  final bool error;
  final UiSize size;

  /// Minimum visible rows.
  final int rows;

  /// Growth limit before the field scrolls internally.
  final int maxRows;
  final int? maxLength;
  final bool autofocus;
  final String? label;

  @override
  Widget build(BuildContext context) => UiInput.multiline(
        controller: controller,
        hintText: hintText,
        value: value,
        onChanged: onChanged,
        enabled: enabled,
        readOnly: readOnly,
        error: error,
        size: size,
        minLines: rows,
        maxLines: maxRows < rows ? rows : maxRows,
        maxLength: maxLength,
        autofocus: autofocus,
      );
}
