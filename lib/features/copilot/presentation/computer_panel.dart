import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../data/copilot_controller.dart';
import '../models/workspace.dart';

class CopilotComputerPanel extends StatefulWidget {
  const CopilotComputerPanel({super.key, required this.controller});
  final CopilotController controller;
  @override
  State<CopilotComputerPanel> createState() => _CopilotComputerPanelState();
}

class _CopilotComputerPanelState extends State<CopilotComputerPanel> {
  late String? _specialist = widget.controller.specialist?.id;
  Json _status = {};
  Json? _output;
  String? _error;
  bool _busy = false;
  String _action = 'navigate';
  String _input = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_specialist == null) return;
    try {
      final status = await widget.controller.api.computer(_specialist!);
      if (mounted) setState(() => _status = status);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _run(String action, [Json input = const {}]) async {
    if (_specialist == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.controller.api.computer(
        _specialist!,
        action: action,
        input: input,
      );
      if (mounted &&
          ![
            'permissions',
            'start',
            'stop',
            'take',
            'release',
          ].contains(action)) {
        setState(() => _output = result);
      }
      await _load();
      await widget.controller.reload(quiet: true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    Json input;
    if (_action == 'navigate') {
      input = {'url': _input};
    } else if (_action == 'exec') {
      input = {'command': _input, 'timeoutMs': 30000};
    } else if (_action.startsWith('files_') && _action != 'files_write') {
      input = {'path': _input};
    } else {
      try {
        input = jsonDecode(_input.isEmpty ? '{}' : _input) as Json;
      } catch (_) {
        setState(() => _error = 'Enter a JSON object for this action.');
        return;
      }
    }
    await _run(_action, input);
  }

  @override
  Widget build(BuildContext context) {
    final permissions = Map<String, dynamic>.from(_status['permissions'] ?? {});
    final holder = (_status['control'] as Map?)?['holder'];
    final rawImage =
        (_output?['base64'] is String
            ? 'data:image/png;base64,${_output!["base64"]}'
            : null) ??
        _output?['dataUrl'] ??
        _output?['screenshot'] ??
        _output?['image'];
    final image = rawImage is String && rawImage.startsWith('data:image/')
        ? rawImage
        : null;
    return ListView(
      children: [
        UiSelect<String>(
          label: 'Specialist computer',
          value: _specialist,
          expand: true,
          options: [
            for (final specialist in widget.controller.workspace.specialists)
              UiOption(label: specialist.name, value: specialist.id),
          ],
          onChanged: (id) {
            setState(() {
              _specialist = id;
              _output = null;
            });
            _load();
          },
        ),
        UiGap.v(context.ui.spacing.md),
        UiBadge(
          label: textOf(_status, 'state', 'Connecting'),
          size: UiSize.xs,
          intent: switch (textOf(_status, 'state', 'Connecting')) {
            'running' => UiIntent.success,
            'stopped' => UiIntent.neutral,
            'error' || 'failed' => UiIntent.danger,
            _ => UiIntent.info,
          },
        ),
        if (_status['configured'] == false) ...[
          UiGap.v(context.ui.spacing.md),
          const UiCallout(
            title: 'Connect an isolated computer',
            message:
                'Configure the OpenBot supervisor in the Dart service to give each specialist its own persistent browser and files. No commands run on this device.',
            intent: UiIntent.neutral,
          ),
        ],
        UiGap.v(context.ui.spacing.md),
        for (final permission in ['enabled', 'browser', 'files', 'shell'])
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(context.ui.spacing.sm)),
            child: UiSwitch(
              label: switch (permission) {
                'enabled' => 'Enable computer',
                'browser' => 'Browser',
                'files' => 'Workspace files',
                _ => 'Terminal',
              },
              value: permissions[permission] == true,
              enabled: !_busy,
              onChanged: (v) =>
                  _run('permissions', {...permissions, permission: v}),
            ),
          ),
        UiGap.v(context.ui.spacing.xs),
        Wrap(
          spacing: context.sp(context.ui.spacing.xs),
          runSpacing: context.sp(context.ui.spacing.xs),
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            UiButton(
              label: _status['state'] == 'running' ? 'Stop' : 'Start',
              icon: Icons.power_settings_new,
              variant: UiVariant.outline,
              onPressed: _busy
                  ? null
                  : () =>
                        _run(_status['state'] == 'running' ? 'stop' : 'start'),
            ),
            UiButton(
              label: holder == 'human' ? 'Release control' : 'Take control',
              variant: UiVariant.ghost,
              onPressed: _busy || _status['state'] != 'running'
                  ? null
                  : () => _run(holder == 'human' ? 'release' : 'take'),
            ),
            UiIconButton(
              icon: Icons.refresh,
              tooltip: 'Refresh computer',
              onPressed: _load,
            ),
          ],
        ),
        if (_status['state'] == 'running') ...[
          UiGap.v(context.ui.spacing.md),
          UiSelect<String>(
            label: 'Action',
            value: _action,
            expand: true,
            options: const [
              UiOption(label: 'Open a website', value: 'navigate'),
              UiOption(label: 'Read page', value: 'read'),
              UiOption(label: 'Browser snapshot', value: 'snapshot'),
              UiOption(label: 'Screenshot', value: 'screenshot'),
              UiOption(label: 'List files', value: 'files_list'),
              UiOption(label: 'Read file', value: 'files_read'),
              UiOption(label: 'Write file (JSON)', value: 'files_write'),
              UiOption(label: 'Run command', value: 'exec'),
              UiOption(label: 'Click (JSON coordinates)', value: 'human_click'),
              UiOption(label: 'Type (JSON)', value: 'human_type'),
              UiOption(label: 'Press key (JSON)', value: 'human_key'),
              UiOption(label: 'Scroll (JSON)', value: 'human_scroll'),
            ],
            onChanged: (v) => setState(() {
              _action = v;
              _input = '';
            }),
          ),
          UiGap.v(context.ui.spacing.sm),
          UiInput(
            key: ValueKey(_action),
            label: _action == 'exec'
                ? 'Command in the isolated computer'
                : 'URL, relative path, or action input',
            value: _input,
            onChanged: (v) => _input = v,
          ),
          UiGap.v(context.ui.spacing.sm),
          UiButton(
            label: 'Run action',
            loading: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
        if (_error != null)
          UiCallout(
            title: 'Computer unavailable',
            message: _error!,
            intent: UiIntent.warning,
          ),
        if (image != null)
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: context.sp(context.ui.spacing.md),
            ),
            child: Image.memory(
              base64Decode(image.split(',').last),
              errorBuilder: (_, _, _) =>
                  const Text('Screenshot could not be displayed.'),
            ),
          ),
        if (_output != null)
          UiCard(
            variant: UiCardVariant.subtle,
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert({
                for (final entry in _output!.entries)
                  if (![
                    'base64',
                    'dataUrl',
                    'screenshot',
                    'image',
                  ].contains(entry.key))
                    entry.key: entry.value,
              }),
              style: context.uiText.mono,
            ),
          ),
        if (records(_status['activity']).isNotEmpty)
          UiAccordion(
            sections: [
              UiAccordionSection(
                title: 'Computer activity',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in records(_status['activity']))
                      Text(
                        '${item['action']} · ${item['actor']} · ${item['outcome']}',
                        style: context.uiText.caption,
                      ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}
