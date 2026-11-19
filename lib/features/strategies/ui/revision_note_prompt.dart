import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// Required unified UI surfaces for feature pages.
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

/// One line of text, asked for in a dialog.
///
/// Returns null if the trader backs out, and an empty string if they confirm
/// without typing anything — the two are different answers, so they are
/// different return values. Callers decide what an empty line means.
Future<String?> showSingleLinePrompt(
  BuildContext context, {
  required String title,
  required String description,
  required String fieldLabel,
  required String hintText,
  required String confirmLabel,
  String? fieldHelper,
  IconData icon = Icons.edit_outlined,
  int maxLength = 120,
}) => UiDialog.show<String>(
  context,
  maxWidth: 520,
  child: _SingleLinePrompt(
    title: title,
    description: description,
    fieldLabel: fieldLabel,
    fieldHelper: fieldHelper,
    hintText: hintText,
    confirmLabel: confirmLabel,
    icon: icon,
    maxLength: maxLength,
  ),
);

/// Asks for the one line that goes on a playbook revision.
///
/// Returns null if the trader backs out, and an empty string if they choose to
/// save without a line — the two are different answers, so they are different
/// return values. Callers save the revision on either, and only skip on null.
///
/// A revision list of eight untitled entries is barely better than no history at
/// all. Asking here, at the moment the rules change, is the only time the trader
/// still knows why.
Future<String?> showRevisionNotePrompt(
  BuildContext context, {
  String title = 'Save a revision',
  String description =
      'One line on what changed and why. This is what the history list shows '
      'six months from now.',
  String hintText = 'Tightened the stop to the level, not the round number',
  String confirmLabel = 'Save revision',
}) => showSingleLinePrompt(
  context,
  title: title,
  description: description,
  fieldLabel: 'Changelog line',
  fieldHelper: 'Optional, but a named revision is worth ten unnamed ones.',
  hintText: hintText,
  confirmLabel: confirmLabel,
  icon: Icons.history_rounded,
);

class _SingleLinePrompt extends StatefulWidget {
  const _SingleLinePrompt({
    required this.title,
    required this.description,
    required this.fieldLabel,
    required this.fieldHelper,
    required this.hintText,
    required this.confirmLabel,
    required this.icon,
    required this.maxLength,
  });

  final String title;
  final String description;
  final String fieldLabel;
  final String? fieldHelper;
  final String hintText;
  final String confirmLabel;
  final IconData icon;
  final int maxLength;

  @override
  State<_SingleLinePrompt> createState() => _SingleLinePromptState();
}

class _SingleLinePromptState extends State<_SingleLinePrompt> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_note.text.trim());

  @override
  Widget build(BuildContext context) => UiDialog(
    title: widget.title,
    description: widget.description,
    icon: widget.icon,
    content: UiField(
      label: widget.fieldLabel,
      helper: widget.fieldHelper,
      child: UiInput(
        controller: _note,
        hintText: widget.hintText,
        autofocus: true,
        maxLength: widget.maxLength,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
    ),
    actions: <Widget>[
      UiButton(
        label: 'Cancel',
        variant: UiVariant.ghost,
        onPressed: () => Navigator.of(context).pop(),
      ),
      UiButton(
        label: widget.confirmLabel,
        leadingIcon: Icons.check_rounded,
        onPressed: _submit,
      ),
    ],
  );
}
