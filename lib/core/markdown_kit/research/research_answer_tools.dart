import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../markdown_preview.dart';
import '../perplexity_parser.dart';

class ResearchAnswerTools extends StatelessWidget {
  const ResearchAnswerTools({
    super.key,
    required this.markdown,
    required this.meta,
    this.onSourceTap,
    this.onPrompt,
    this.sentAt,
  });
  final String markdown;
  final PerplexityAnswerMeta meta;
  final ValueChanged<String>? onSourceTap;
  final ValueChanged<String>? onPrompt;
  final DateTime? sentAt;

  @override
  Widget build(BuildContext context) {
    final words = markdown
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .length;
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: context.sp(context.ui.spacing.xs),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: context.sp(context.ui.spacing.sm),
        runSpacing: context.sp(context.ui.spacing.xs),
        children: [
          UiBadge(
            label: '~${(words / 220).ceil().clamp(1, 999)} min read',
            variant: UiBadgeVariant.soft,
            size: UiSize.xs,
          ),
          UiButton(
            label: 'Inspect answer',
            icon: Icons.manage_search,
            size: UiSize.xs,
            variant: UiVariant.ghost,
            onPressed: () => UiDialog.show(
              context,
              maxWidth: 900,
              child: _AnswerInspector(
                markdown: markdown,
                meta: meta,
                onSourceTap: onSourceTap,
                sentAt: sentAt,
              ),
            ),
          ),
          if (meta.sources.isNotEmpty)
            UiButton(
              label: 'Copy references',
              icon: Icons.link,
              size: UiSize.xs,
              variant: UiVariant.ghost,
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text: meta.sources
                        .map((s) => '[${s.index}] ${s.title}\n${s.url}')
                        .join('\n\n'),
                  ),
                );
                if (context.mounted) {
                  UiToast.success(context, title: 'References copied');
                }
              },
            ),
          if (onPrompt != null)
            UiButton(
              label: 'Check latest',
              icon: Icons.update,
              size: UiSize.xs,
              variant: UiVariant.ghost,
              onPressed: () => onPrompt!(
                'Search the web as of the current date and time to update this answer. '
                'Identify changed facts and compare publication, event, and data dates. Cite fresh primary sources. '
                'If no newer evidence exists, say so. Answer to check:\n${markdown.substring(0, markdown.length.clamp(0, 12000))}',
              ),
            ),
        ],
      ),
    );
  }
}

class _AnswerInspector extends StatefulWidget {
  const _AnswerInspector({
    required this.markdown,
    required this.meta,
    this.onSourceTap,
    this.sentAt,
  });
  final String markdown;
  final PerplexityAnswerMeta meta;
  final ValueChanged<String>? onSourceTap;
  final DateTime? sentAt;
  @override
  State<_AnswerInspector> createState() => _AnswerInspectorState();
}

class _AnswerInspectorState extends State<_AnswerInspector> {
  int _tab = 0;
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final meta = widget.meta;
    final spacing = context.ui.spacing;
    final sources = meta.sources
        .where(
          (s) => '${s.title} ${s.domain} ${s.snippet}'.toLowerCase().contains(
            _query.toLowerCase(),
          ),
        )
        .toList();
    final headings = RegExp(r'^#{1,6}\s+(.+)$', multiLine: true)
        .allMatches(
          meta.cleanMarkdown.replaceAll(RegExp(r'```[\s\S]*?```'), ''),
        )
        .map((m) => m.group(1)!)
        .toList();
    return UiDialog(
      title: 'Answer workspace',
      description:
          'Read, inspect the evidence, and keep the original Markdown.',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiTabs(
            tabs: const ['Read', 'Sources', 'Details', 'Markdown'],
            selectedIndex: _tab,
            onChanged: (v) => setState(() => _tab = v),
          ),
          UiGap.v(spacing.md),
          if (_tab == 0)
            RichMarkdownPreview(
              data: meta.cleanMarkdown,
              onTapLink: (_, href, _) {
                if (href != null &&
                    Uri.tryParse(href)?.hasAuthority == true &&
                    ['http', 'https'].contains(Uri.parse(href).scheme)) {
                  widget.onSourceTap?.call(href);
                }
              },
            )
          else if (_tab == 1) ...[
            UiInput.search(
              value: _query,
              hintText: 'Filter sources by title or domain',
              onChanged: (v) => setState(() => _query = v),
              onClear: () => setState(() => _query = ''),
            ),
            UiGap.v(spacing.sm),
            Text(
              '${sources.length} sources · ${sources.map((s) => s.domain).toSet().length} domains',
              style: context.uiText.caption,
            ),
            if (sources.isEmpty)
              const UiEmptyState(
                title: 'No matching sources',
                message:
                    'A linked source is not proof that every claim was verified.',
                icon: Icons.link_off,
              ),
            for (final source in sources)
              Padding(
                padding: EdgeInsets.symmetric(vertical: context.sp(spacing.xs)),
                child: UiCard(
                  variant: UiCardVariant.outlined,
                  title: '[${source.index}] ${source.title}',
                  subtitle: source.domain,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (source.snippet.isNotEmpty)
                        Text(source.snippet, style: context.uiText.body),
                      Text(
                        source.publishedAt.isEmpty
                            ? 'Publication date not supplied'
                            : 'Published ${source.publishedAt}',
                        style: context.uiText.caption,
                      ),
                      UiButton(
                        label: 'Open source',
                        icon: Icons.open_in_new,
                        variant: UiVariant.link,
                        size: UiSize.sm,
                        onPressed: widget.onSourceTap == null
                            ? null
                            : () => widget.onSourceTap!(source.url),
                      ),
                    ],
                  ),
                ),
              ),
          ] else if (_tab == 2) ...[
            UiCallout(
              title: 'Evidence, not a guarantee',
              message:
                  'Source counts describe linked references. They do not measure truth or independent verification. Check each source against the claim it supports.',
              intent: UiIntent.neutral,
            ),
            UiGap.v(spacing.md),
            if (widget.sentAt != null)
              Text(
                'Answer created: ${widget.sentAt!.toUtc().toIso8601String()} (UTC). This is not the date of the underlying data.',
                style: context.uiText.caption,
              ),
            UiGap.v(spacing.sm),
            Text(
              '${meta.cards.length} visual blocks · ${meta.sources.length} references',
              style: context.uiText.label,
            ),
            if (headings.isNotEmpty) ...[
              UiGap.v(spacing.md),
              Text('In this answer', style: context.uiText.label),
              for (final heading in headings)
                Text('• $heading', style: context.uiText.body),
            ],
            if (meta.steps.isNotEmpty) ...[
              UiGap.v(spacing.md),
              Text('Reported activity', style: context.uiText.label),
              for (final step in meta.steps)
                Text('• ${step.title}', style: context.uiText.body),
            ],
          ] else
            SelectableText(widget.markdown, style: context.uiText.body),
        ],
      ),
      actions: [
        UiButton(
          label: 'Copy Markdown',
          icon: Icons.copy,
          variant: UiVariant.outline,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: widget.markdown));
            if (context.mounted) {
              UiToast.success(context, title: 'Markdown copied');
            }
          },
        ),
      ],
    );
  }
}
