import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/markdown_kit/markdown_preview.dart';

import '../data/copilot_controller.dart';

Future<void> showSavePageDialog(
  BuildContext context,
  CopilotController controller,
  String body,
) => UiDialog.show<void>(
  context,
  maxWidth: 680,
  child: _SavePage(controller: controller, body: body),
);

class _SavePage extends StatefulWidget {
  const _SavePage({required this.controller, required this.body});
  final CopilotController controller;
  final String body;
  @override
  State<_SavePage> createState() => _SavePageState();
}

class _SavePageState extends State<_SavePage> {
  String _title = 'Conversation notes';
  late String? _space =
      widget.controller.specialist?.json['defaultSpaceId'] as String? ??
      widget.controller.specialist?.spaceIds.firstOrNull ??
      widget.controller.workspace.spaces.firstOrNull?['id'] as String?;
  bool _saving = false;
  String? _error;
  Future<void> _save() async {
    setState(() => _saving = true);
    final page = await widget.controller.action({
      'action': 'page.save',
      'title': _title,
      'body': widget.body,
      'spaceId': _space,
    });
    if (!mounted) return;
    if (page != null) {
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
    title: 'Save to a space',
    description: 'Review the answer and keep a working copy.',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiInput(
          label: 'Page title',
          value: _title,
          onChanged: (v) => _title = v,
        ),
        UiGap.v(context.ui.spacing.md),
        UiSelect<String>(
          label: 'Space',
          value: _space,
          expand: true,
          options: [
            for (final space in widget.controller.workspace.spaces)
              UiOption(label: space['name'], value: space['id']),
          ],
          onChanged: (v) => setState(() => _space = v),
        ),
        UiGap.v(context.ui.spacing.md),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: context.sz(260)),
          child: SingleChildScrollView(
            child: RichMarkdownPreview(data: widget.body),
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
      UiButton(
        label: 'Cancel',
        variant: UiVariant.ghost,
        onPressed: () => Navigator.of(context).pop(),
      ),
      UiButton(
        label: 'Save page',
        loading: _saving,
        onPressed: _saving ? null : _save,
      ),
    ],
  );
}
