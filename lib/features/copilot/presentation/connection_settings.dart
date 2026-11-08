import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../data/copilot_controller.dart';
import '../models/workspace.dart';
import 'workspace_forms.dart';

class CopilotConnections extends StatelessWidget {
  const CopilotConnections({
    super.key,
    required this.controller,
    required this.query,
  });
  final CopilotController controller;
  final String query;
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      UiButton(
        label: 'Connect an MCP server',
        icon: Icons.add,
        variant: UiVariant.outline,
        onPressed: () => _edit(context),
      ),
      UiGap.v(context.ui.spacing.md),
      Text(
        'Bring your apps into the conversation. Choose a specialist, allow specific tools, and review actions before they run.',
        style: context.uiText.body,
      ),
      UiGap.v(context.ui.spacing.md),
      for (final connection in controller.workspace.connections.where(
        (c) => textOf(c, 'name').toLowerCase().contains(query.toLowerCase()),
      ))
        UiCard(
          variant: UiCardVariant.outlined,
          title: textOf(connection, 'name'),
          subtitle: textOf(connection, 'url'),
          trailing: UiBadge(
            label: connection['enabled'] == true ? 'Enabled' : 'Disabled',
            intent: UiIntent.neutral,
          ),
          child: Wrap(
            children: [
              UiButton(
                label: 'Settings & tools',
                icon: Icons.tune,
                variant: UiVariant.ghost,
                onPressed: () => _edit(context, connection),
              ),
              UiButton(
                label: 'Disconnect',
                variant: UiVariant.ghost,
                intent: UiIntent.danger,
                onPressed: () => confirmWorkspaceDelete(
                  context,
                  controller,
                  'connection.delete',
                  connection['id'],
                  textOf(connection, 'name'),
                ),
              ),
            ],
          ),
        ),
      UiGap.v(context.ui.spacing.lg),
      const UiCallout(
        title: 'Accounts are connected separately',
        message:
            'An OpenAI key powers the AI. Email, calendar, GitHub, and Slack need an authorized MCP endpoint for the account you want to use.',
        intent: UiIntent.neutral,
      ),
      UiGap.v(context.ui.spacing.md),
      const UiCallout(
        title: 'Computer access',
        message:
            'Open Computer in the workspace to manage browser, files, terminal permissions, and human control for an isolated computer.',
        intent: UiIntent.neutral,
      ),
      UiGap.v(context.ui.spacing.md),
      UiCard(
        variant: UiCardVariant.outlined,
        title: 'Slack',
        trailing: UiBadge(
          label: controller.workspace.setup['slack'] == true
              ? 'Configured'
              : 'Not connected',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mention your specialist in Slack and continue in the same thread. Workspace actions still come here for review.',
              style: context.uiText.body,
            ),
            UiGap.v(context.ui.spacing.sm),
            Text(
              controller.workspace.setup['slack'] == true
                  ? textOf(
                      controller.workspace.json['slackStatus'] as Json? ?? {},
                      'message',
                      'Waiting for an authorized Slack event.',
                    )
                  : 'A workspace administrator can connect a Slack bot using the setup guide in docs/copilot.md.',
              style: context.uiText.caption,
            ),
          ],
        ),
      ),
    ],
  );
  Future<void> _edit(BuildContext context, [Json? connection]) =>
      UiDialog.show<void>(
        context,
        maxWidth: 640,
        child: _ConnectionEditor(
          controller: controller,
          connection: connection,
        ),
      );
}

class _ConnectionEditor extends StatefulWidget {
  const _ConnectionEditor({required this.controller, this.connection});
  final CopilotController controller;
  final Json? connection;
  @override
  State<_ConnectionEditor> createState() => _ConnectionEditorState();
}

class _ConnectionEditorState extends State<_ConnectionEditor> {
  late final Json _values = {
    ...?widget.connection,
    'specialistId':
        widget.connection?['specialistId'] ?? widget.controller.specialist?.id,
    'enabled': widget.connection?['enabled'] ?? true,
    'allTools':
        widget.connection?['allTools'] ??
        (widget.connection?['allowedTools'] as List? ?? []).isEmpty,
  };
  late String _allowed = (widget.connection?['allowedTools'] as List? ?? [])
      .join(', ');
  late String _readOnly = (widget.connection?['readOnlyTools'] as List? ?? [])
      .join(', ');
  bool _saving = false;
  String? _error;
  List<String> _names(String text) => text
      .split(',')
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toSet()
      .toList();
  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await widget.controller.action({
      ..._values,
      'action': 'connection.save',
      'allowedTools': _names(_allowed),
      'readOnlyTools': _names(_readOnly),
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
    title: 'Connect a tool server',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiInput(
          label: 'Name',
          value: textOf(_values, 'name'),
          onChanged: (v) => _values['name'] = v,
        ),
        UiGap.v(context.ui.spacing.md),
        UiInput(
          label: 'HTTPS MCP endpoint',
          value: textOf(_values, 'url'),
          onChanged: (v) => _values['url'] = v,
        ),
        UiGap.v(context.ui.spacing.md),
        UiInput(
          label: widget.connection?['hasToken'] == true
              ? 'Replace token (leave blank to keep)'
              : 'Access token (if required)',
          obscure: true,
          onChanged: (v) => _values['token'] = v,
        ),
        UiGap.v(context.ui.spacing.md),
        UiSelect<String>(
          label: 'Specialist',
          value: _values['specialistId'],
          expand: true,
          options: [
            for (final specialist in widget.controller.workspace.specialists)
              UiOption(label: specialist.name, value: specialist.id),
          ],
          onChanged: (v) => setState(() => _values['specialistId'] = v),
        ),
        UiGap.v(context.ui.spacing.md),
        UiSwitch(
          label: 'Allow all server tools',
          value: _values['allTools'] == true,
          onChanged: (value) => setState(() {
            _values['allTools'] = value;
            _allowed = '';
          }),
        ),
        if (_values['allTools'] != true &&
            records(widget.connection?['tools']).isNotEmpty)
          for (final tool in records(widget.connection?['tools']))
            UiCheckbox(
              label: textOf(tool, 'name'),
              value: _names(_allowed).contains(tool['name']),
              onChanged: (value) => setState(() {
                final selected = _names(_allowed).toSet();
                if (value == true) {
                  selected.add(textOf(tool, 'name'));
                } else {
                  selected.remove(tool['name']);
                }
                _allowed = selected.join(', ');
              }),
            ),
        if (_values['allTools'] != true)
          UiInput(
            label: 'Allowed tools',
            helperText:
                'Comma-separated names. No selected tools means no access. Discovered tools appear after the first conversation uses this server.',
            value: _allowed,
            onChanged: (v) => _allowed = v,
          ),
        UiGap.v(context.ui.spacing.md),
        UiInput(
          label: 'Trusted read-only tools',
          helperText:
              'These tools can run without approval. All others require your review.',
          value: _readOnly,
          onChanged: (v) => _readOnly = v,
        ),
        UiSwitch(
          label: 'Enable connection',
          value: _values['enabled'] == true,
          onChanged: (v) => setState(() => _values['enabled'] = v),
        ),
        if (_error != null)
          UiCallout(
            title: 'Not connected',
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
        label: 'Save connection',
        loading: _saving,
        onPressed: _saving ? null : _save,
      ),
    ],
  );
}
