import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

/// Floating accessory bar shown above the keyboard formatting toolbar when
/// text is selected in the note or journal editor.
class AiRefactorBar extends StatelessWidget {
  const AiRefactorBar({
    super.key,
    required this.refactoring,
    required this.selectedCharCount,
    required this.onQuickRefactor,
    required this.onCustomPrompt,
    required this.onDismiss,
  });

  final bool refactoring;
  final int selectedCharCount;
  final VoidCallback onQuickRefactor;
  final VoidCallback onCustomPrompt;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.uiColors;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.primary.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 16, color: c.primary),
            const SizedBox(width: 8),
            Text(
              selectedCharCount > 0 ? '$selectedCharCount chars' : 'Selected',
              style: context.uiText.caption.copyWith(
                color: c.foregroundMuted,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
            const Spacer(),
            if (refactoring) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(c.primary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'AI Writing…',
                style: context.uiText.caption.copyWith(
                  color: c.primary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ] else ...[
              // Custom Prompt button
              GestureDetector(
                onTap: onCustomPrompt,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: c.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_note_rounded, size: 15, color: c.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Prompt AI',
                        style: context.uiText.caption.copyWith(
                          color: c.primary,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Quick enhance button
              GestureDetector(
                onTap: onQuickRefactor,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 13,
                        color: c.onPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Enhance',
                        style: context.uiText.caption.copyWith(
                          color: c.onPrimary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDismiss,
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: c.foregroundMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Interactive modal bottom sheet where users can type custom instructions to
/// rewrite, expand, or format the selected text with AI.
class AiCustomPromptSheet extends StatefulWidget {
  const AiCustomPromptSheet({
    super.key,
    required this.selectedText,
    required this.onApply,
    this.suggestions = traderSuggestions,
  });

  final String selectedText;

  /// Preset prompts offered as chips. The caller supplies them so the sheet
  /// stays free of any one feature's vocabulary — a strategy note and a market
  /// recap want different presets.
  final List<String> suggestions;
  final Future<void> Function(String prompt) onApply;

  /// Presets written for a trading notebook, used when the caller has no
  /// opinion.
  static const List<String> traderSuggestions = <String>[
    'Turn this into a structured trade plan with entry, stop and target',
    'Summarise the setup into a checklist I can run pre-market',
    'Critique this thesis and list what would invalidate it',
    'Fix grammar and tighten the writing, keep every number intact',
    'Extract the risk rules mentioned here into a bullet list',
    'Expand this into a full post-trade review with lessons learned',
  ];

  @override
  State<AiCustomPromptSheet> createState() => _AiCustomPromptSheetState();
}

class _AiCustomPromptSheetState extends State<AiCustomPromptSheet> {
  final TextEditingController _promptController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _submit(String prompt) async {
    final String text = prompt.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onApply(text);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final preview = widget.selectedText.length > 160
        ? '${widget.selectedText.substring(0, 160)}…'
        : widget.selectedText;
    return UiDialog(
      title: 'Transform with AI',
      description: 'Type your prompt or choose a preset.',
      icon: Icons.auto_awesome_rounded,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          UiCard(
            padding: EdgeInsets.all(context.sp(theme.spacing.md)),
            child: Text(preview, style: context.uiText.caption),
          ),
          UiGap.v(theme.spacing.md),
          UiTextarea(
            controller: _promptController,
            label: 'Your instructions',
            hintText:
                'Summarise the thesis, make a checklist, or improve the writing…',
            autofocus: true,
            rows: 3,
            maxRows: 6,
          ),
          UiGap.v(theme.spacing.md),
          Text('Quick prompts', style: context.uiText.label),
          for (final suggestion in widget.suggestions) ...[
            UiGap.v(theme.spacing.xs),
            UiCard(
              padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
              onTap: () {
                _promptController.text = suggestion;
                _promptController.selection = TextSelection.collapsed(
                  offset: suggestion.length,
                );
              },
              child: Text(suggestion, style: context.uiText.caption),
            ),
          ],
        ],
      ),
      actions: [
        UiButton(
          label: _submitting ? 'Generating with AI…' : 'Transform selection',
          leadingIcon: Icons.auto_awesome_rounded,
          loading: _submitting,
          onPressed: _submitting ? null : () => _submit(_promptController.text),
        ),
      ],
    );
  }
}
