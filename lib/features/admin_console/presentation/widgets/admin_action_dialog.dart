import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../../data/admin_repository.dart';

Future<bool> runAdminAction(
  BuildContext context, {
  required String title,
  required Future<void> Function(String reason) submit,
  String? description,
  String? confirmation,
  Widget? additionalContent,
  bool destructive = false,
}) async =>
    await UiDialog.show<bool>(
      context,
      dismissible: false,
      child: _AdminActionDialog(
        title: title,
        description: description,
        confirmation: confirmation,
        additionalContent: additionalContent,
        destructive: destructive,
        submit: submit,
      ),
    ) ??
    false;

class _AdminActionDialog extends StatefulWidget {
  const _AdminActionDialog({
    required this.title,
    required this.submit,
    this.description,
    this.confirmation,
    this.additionalContent,
    this.destructive = false,
  });
  final String title;
  final String? description;
  final String? confirmation;
  final Widget? additionalContent;
  final bool destructive;
  final Future<void> Function(String) submit;
  @override
  State<_AdminActionDialog> createState() => _AdminActionDialogState();
}

class _AdminActionDialogState extends State<_AdminActionDialog> {
  String _reason = '';
  String _confirmation = '';
  String? _error;
  bool _saving = false;

  Future<void> _submit() async {
    if (_saving) return;
    if (_reason.trim().length < 3 || _reason.trim().length > 2000) {
      setState(() => _error = 'Enter a reason between 3 and 2000 characters.');
      return;
    }
    if (widget.confirmation != null &&
        _confirmation.trim() != widget.confirmation) {
      setState(() => _error = 'Enter ${widget.confirmation} to confirm.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.submit(_reason.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = adminError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => UiDialog(
    title: widget.title,
    description: widget.description,
    intent: widget.destructive ? UiIntent.danger : UiIntent.primary,
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.additionalContent != null) ...[
          widget.additionalContent!,
          const UiGap.v(12),
        ],
        UiTextarea(
          label: 'Reason for this change',
          value: _reason,
          onChanged: (value) => setState(() => _reason = value),
          maxLines: 3,
        ),
        if (widget.confirmation != null) ...[
          const UiGap.v(12),
          UiInput(
            label: 'Type ${widget.confirmation} to confirm',
            value: _confirmation,
            onChanged: (value) => setState(() => _confirmation = value),
          ),
        ],
        if (_error != null) ...[
          const UiGap.v(12),
          UiCallout(
            title: 'Change not saved',
            message: _error!,
            intent: UiIntent.danger,
          ),
        ],
      ],
    ),
    actions: [
      UiButton(
        label: 'Cancel',
        variant: UiVariant.ghost,
        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
      ),
      UiButton(
        label: _saving ? 'Saving…' : 'Confirm',
        loading: _saving,
        intent: widget.destructive ? UiIntent.danger : UiIntent.primary,
        onPressed: _saving ? null : _submit,
      ),
    ],
  );
}
