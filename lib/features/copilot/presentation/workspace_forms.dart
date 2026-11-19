import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

import '../data/copilot_controller.dart';
import '../models/workspace.dart';

Future<Json?> showWorkspaceTextForm(
  BuildContext context,
  CopilotController controller, {
  required String title,
  required String action,
  required Map<String, String> fields,
  Json initial = const {},
  Set<String> multiline = const {},
}) => UiDialog.show<Json>(
  context,
  maxWidth: 560,
  child: _TextForm(
    controller: controller,
    title: title,
    action: action,
    fields: fields,
    initial: initial,
    multiline: multiline,
  ),
);

Future<void> confirmWorkspaceDelete(
  BuildContext context,
  CopilotController controller,
  String action,
  String id,
  String title,
) async {
  final confirmed = await UiDialog.confirm(
    context,
    title: 'Delete $title?',
    description: 'This removes it from your workspace.',
  );
  if (confirmed) await controller.action({'action': action, 'id': id});
}

class _TextForm extends StatefulWidget {
  const _TextForm({
    required this.controller,
    required this.title,
    required this.action,
    required this.fields,
    required this.initial,
    required this.multiline,
  });
  final CopilotController controller;
  final String title;
  final String action;
  final Map<String, String> fields;
  final Json initial;
  final Set<String> multiline;
  @override
  State<_TextForm> createState() => _TextFormState();
}

class _TextFormState extends State<_TextForm> {
  late final Json _values = {...widget.initial};
  bool _saving = false;
  String? _error;
  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await widget.controller.action({
      ..._values,
      'action': widget.action,
    });
    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop(result);
    } else {
      setState(() {
        _saving = false;
        _error = widget.controller.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => UiDialog(
    title: widget.title,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in widget.fields.entries) ...[
          UiInput(
            label: entry.value,
            value: textOf(_values, entry.key),
            minLines: widget.multiline.contains(entry.key) ? 3 : 1,
            maxLines: widget.multiline.contains(entry.key) ? 7 : 1,
            onChanged: (v) => _values[entry.key] = v,
          ),
          UiGap.v(context.ui.spacing.md),
        ],
        if (_error != null)
          UiCallout(
            title: 'Not saved',
            message: _error!,
            intent: UiIntent.warning,
          ),
      ],
    ),
    actions: [
      UiButton(
        label: 'Cancel',
        variant: UiVariant.ghost,
        onPressed: () => Navigator.of(context).pop(),
      ),
      UiButton(
        label: 'Save',
        loading: _saving,
        onPressed: _saving ? null : _save,
      ),
    ],
  );
}
