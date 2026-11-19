import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

import '../models/research_format.dart';

Future<String?> pickResearchFormat(
  BuildContext context, {
  String subject = '',
}) => UiDialog.show<String>(
  context,
  maxWidth: 840,
  pinFooter: true,
  child: ResearchFormatPicker(subject: subject),
);

class ResearchFormatPicker extends StatefulWidget {
  const ResearchFormatPicker({super.key, this.subject = ''});
  final String subject;
  @override
  State<ResearchFormatPicker> createState() => _ResearchFormatPickerState();
}

class _ResearchFormatPickerState extends State<ResearchFormatPicker> {
  String _query = '';
  String _category = 'All';
  late String _subject = widget.subject;
  ResearchFormat? _selected;

  @override
  Widget build(BuildContext context) {
    final spacing = context.ui.spacing;
    final results = ResearchFormat.values
        .where(
          (f) =>
              (_category == 'All' || f.category == _category) &&
              '${f.title} ${f.directive}'.toLowerCase().contains(
                _query.toLowerCase(),
              ),
        )
        .toList();
    final selected = _selected;
    return UiDialog(
      title: selected == null ? 'Research studio' : selected.title,
      description: selected == null
          ? '60 ways to turn a question into useful, sourced research.'
          : 'Personalize the topic, review the prompt, then add it to your draft.',
      icon: Icons.auto_awesome_outlined,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selected == null) ...[
            UiInput.search(
              value: _query,
              hintText: 'Find a format, e.g. risks, earnings, evidence',
              onChanged: (v) => setState(() => _query = v),
              onClear: () => setState(() => _query = ''),
            ),
            UiGap.v(spacing.sm),
            Wrap(
              spacing: context.sp(spacing.xs),
              runSpacing: context.sp(spacing.xs),
              children: [
                for (final category in ResearchFormat.categories)
                  UiButton(
                    label: category,
                    size: UiSize.sm,
                    variant: _category == category
                        ? UiVariant.soft
                        : UiVariant.ghost,
                    onPressed: () => setState(() => _category = category),
                  ),
              ],
            ),
            UiGap.v(spacing.sm),
            Text(
              '${results.length} ${results.length == 1 ? 'format' : 'formats'}',
              style: context.uiText.caption,
            ),
            if (results.isEmpty)
              const UiEmptyState(
                title: 'No matching formats',
                message: 'Try another keyword or category.',
                icon: Icons.search_off,
              ),
            for (final format in results)
              AppIndexRow(
                title: format.title,
                subtitle: format.directive,
                onTap: () => setState(() => _selected = format),
              ),
          ] else ...[
            UiInput(
              label: 'Topic or question',
              value: _subject,
              hintText: 'A company, market, question, or your supplied records',
              onChanged: (v) => setState(() => _subject = v),
            ),
            UiGap.v(spacing.md),
            UiCard(
              variant: UiCardVariant.subtle,
              title: 'Your research prompt',
              child: SelectableText(
                selected.prompt(_subject),
                style: context.uiText.body,
              ),
            ),
            UiGap.v(spacing.sm),
            Text(
              'The prompt stays editable in the composer. Sending uses an AI query.',
              style: context.uiText.caption,
            ),
          ],
        ],
      ),
      footer: Padding(
        padding: EdgeInsets.only(top: context.sp(spacing.md)),
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: context.sp(spacing.sm),
          runSpacing: context.sp(spacing.xs),
          children: [
            if (selected != null) ...[
              UiButton(
                label: 'Back to formats',
                variant: UiVariant.ghost,
                onPressed: () => setState(() => _selected = null),
              ),
              UiButton(
                label: 'Copy prompt',
                variant: UiVariant.outline,
                icon: Icons.copy,
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: selected.prompt(_subject)),
                  );
                  if (context.mounted) {
                    UiToast.success(context, title: 'Prompt copied');
                  }
                },
              ),
              UiButton(
                label: 'Use prompt',
                icon: Icons.arrow_forward,
                onPressed: () =>
                    Navigator.of(context).pop(selected.prompt(_subject)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
