import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../data/copilot_controller.dart';
import '../models/workspace.dart';
import 'workspace_forms.dart';

Future<void> showSpecialistEditor(
  BuildContext context,
  CopilotController controller, {
  Specialist? specialist,
}) => UiDialog.show<void>(
  context,
  maxWidth: 640,
  child: _SpecialistEditor(controller: controller, specialist: specialist),
);

class _SpecialistEditor extends StatefulWidget {
  const _SpecialistEditor({required this.controller, this.specialist});
  final CopilotController controller;
  final Specialist? specialist;
  @override
  State<_SpecialistEditor> createState() => _SpecialistEditorState();
}

class _SpecialistEditorState extends State<_SpecialistEditor> {
  late final Json _values = {...?widget.specialist?.json};
  late List<String> _spaces =
      widget.specialist?.spaceIds ??
      (widget.controller.workspace.spaces.firstOrNull?['id'] != null
          ? <String>[
              widget.controller.workspace.spaces.first['id'] as String,
            ]
          : <String>[]);
  bool _saving = false;
  String? _error;
  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await widget.controller.action({
      ..._values,
      'spaceIds': _spaces,
      'action': 'specialist.save',
    });
    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = widget.controller.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => UiDialog(
    title: widget.specialist == null ? 'A new perspective' : 'Edit specialist',
    description:
        'Give your specialist a purpose and choose what it can access.',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final field in {
          'name': 'Name',
          'role': 'Role',
          'instructions': 'Instructions',
        }.entries) ...[
          UiInput(
            label: field.value,
            value: textOf(_values, field.key),
            minLines: field.key == 'instructions' ? 3 : 1,
            maxLines: field.key == 'instructions' ? 6 : 1,
            onChanged: (v) => _values[field.key] = v,
          ),
          UiGap.v(context.ui.spacing.md),
        ],
        UiSelect<String>(
          label: 'Permitted spaces',
          multiple: true,
          values: _spaces,
          expand: true,
          options: [
            for (final space in widget.controller.workspace.spaces)
              UiOption(label: space['name'], value: space['id']),
          ],
          onValuesChanged: (v) => setState(() => _spaces = v),
        ),
        UiGap.v(context.ui.spacing.md),
        UiSelect<String>(
          label: 'Default save destination',
          value: _spaces.contains(_values['defaultSpaceId'])
              ? _values['defaultSpaceId']
              : _spaces.firstOrNull,
          expand: true,
          options: [
            for (final space in widget.controller.workspace.spaces.where(
              (s) => _spaces.contains(s['id']),
            ))
              UiOption(label: space['name'], value: space['id']),
          ],
          onChanged: (value) =>
              setState(() => _values['defaultSpaceId'] = value),
        ),
        UiGap.v(context.ui.spacing.md),
        for (final entry in {
          'research': 'Search the web',
          'code': 'Analyze data & create files',
          'memory': 'Use my saved preferences',
          'apps': 'Use connected apps',
          'learning': 'Suggest reusable lessons',
        }.entries)
          Padding(
            padding: EdgeInsets.only(
              bottom: context.sp(context.ui.spacing.sm),
            ),
            child: UiSwitch(
              label: entry.value,
              value: _values[entry.key] == true,
              onChanged: (v) => setState(() => _values[entry.key] = v),
            ),
          ),
        if (_error != null)
          UiCallout(
            title: 'Not saved',
            message: _error!,
            intent: UiIntent.warning,
          ),
      ],
    ),
    actions: [
      if (widget.specialist != null)
        UiButton(
          label: 'Delete',
          variant: UiVariant.ghost,
          intent: UiIntent.danger,
          onPressed: () async {
            await confirmWorkspaceDelete(
              context,
              widget.controller,
              'specialist.delete',
              widget.specialist!.id,
              widget.specialist!.name,
            );
            if (context.mounted && widget.controller.error == null) {
              Navigator.of(context).pop();
            }
          },
        ),
      UiButton(
        label: 'Cancel',
        variant: UiVariant.ghost,
        onPressed: () => Navigator.of(context).pop(),
      ),
      UiButton(
        label: 'Save specialist',
        loading: _saving,
        onPressed: _saving ? null : _save,
      ),
    ],
  );
}
