import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// A bounded, tolerant renderer for research output contracts.
class ResearchPanel extends StatelessWidget {
  const ResearchPanel({super.key, required this.data, this.onTapUrl});
  final Map<String, dynamic> data;
  final ValueChanged<String>? onTapUrl;

  static List<String> strings(dynamic value) => value is List
      ? value
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .take(24)
            .toList()
      : const [];
  static String text(dynamic value) => value is String ? value : '';
  static bool safeUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        ['https', 'http'].contains(uri.scheme) &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.ui.spacing;
    final columns = strings(data['columns']).take(6).toList();
    final rows = data['rows'] is List
        ? (data['rows'] as List)
              .whereType<List>()
              .take(60)
              .map(
                (row) => List.generate(
                  columns.length,
                  (i) => i < row.length && row[i] != null
                      ? '${row[i]}'
                      : 'Not supplied',
                ),
              )
              .toList()
        : <List<String>>[];
    final evidence = data['evidence'] is List
        ? (data['evidence'] as List).whereType<Map>().take(24).toList()
        : <Map>[];
    final caveats = strings(data['caveats']);
    final nextSteps = strings(data['nextSteps']);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(spacing.sm)),
      child: UiCard(
        variant: UiCardVariant.outlined,
        accentColor: context.ui.colors.primary,
        title: text(data['title']).isEmpty
            ? 'Research brief'
            : text(data['title']),
        subtitle: text(data['asOf']).isEmpty
            ? null
            : 'Data as of ${text(data['asOf'])}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (text(data['summary']).isNotEmpty) ...[
              SelectableText(
                text(data['summary']),
                style: context.uiText.body.copyWith(height: 1.6),
              ),
              UiGap.v(spacing.md),
            ],
            if (columns.isNotEmpty && rows.isNotEmpty) ...[
              UiTable<List<String>>(
                columns: [
                  for (var i = 0; i < columns.length; i++)
                    UiTableColumn(
                      header: columns[i],
                      valueGetter: (row) => row[i],
                      compare: (a, b) => a[i].compareTo(b[i]),
                    ),
                ],
                rows: rows,
                stackOnMobile: true,
                pageSize: 12,
                density: UiDensity.compact,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: UiButton(
                  label: 'Copy table',
                  icon: Icons.table_chart_outlined,
                  size: UiSize.xs,
                  variant: UiVariant.ghost,
                  onPressed: () async {
                    String cell(String s) =>
                        s.replaceAll('\t', ' ').replaceAll('\n', ' ');
                    final tsv = [
                      columns,
                      ...rows,
                    ].map((row) => row.map(cell).join('\t')).join('\n');
                    await Clipboard.setData(ClipboardData(text: tsv));
                    if (context.mounted) {
                      UiToast.success(context, title: 'Table copied');
                    }
                  },
                ),
              ),
              UiGap.v(spacing.sm),
            ],
            if (evidence.isNotEmpty ||
                caveats.isNotEmpty ||
                nextSteps.isNotEmpty)
              UiAccordion(
                allowMultiple: true,
                variant: UiAccordionVariant.ghost,
                items: [
                  if (evidence.isNotEmpty)
                    UiAccordionItem(
                      title: 'Evidence trail',
                      badge: '${evidence.length}',
                      leadingIcon: Icons.link,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final item in evidence)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: context.sp(spacing.md),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    text(item['claim']),
                                    style: context.uiText.body,
                                  ),
                                  if (text(item['publishedAt']).isNotEmpty ||
                                      text(item['eventDate']).isNotEmpty)
                                    Text(
                                      'Published: ${text(item['publishedAt']).isEmpty ? "Unknown" : text(item['publishedAt'])} · Event: ${text(item['eventDate']).isEmpty ? "Unknown" : text(item['eventDate'])}',
                                      style: context.uiText.caption,
                                    ),
                                  if (safeUrl(text(item['sourceUrl'])))
                                    UiButton(
                                      label: text(item['sourceTitle']).isEmpty
                                          ? Uri.parse(
                                              text(item['sourceUrl']),
                                            ).host
                                          : text(item['sourceTitle']),
                                      icon: Icons.open_in_new,
                                      variant: UiVariant.link,
                                      size: UiSize.sm,
                                      onPressed: onTapUrl == null
                                          ? null
                                          : () => onTapUrl!(
                                              text(item['sourceUrl']),
                                            ),
                                    )
                                  else
                                    Text(
                                      'Supporting link not supplied',
                                      style: context.uiText.caption,
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (caveats.isNotEmpty)
                    UiAccordionItem(
                      title: 'Limitations & uncertainty',
                      leadingIcon: Icons.info_outline,
                      initiallyOpen: true,
                      content: UiCallout(
                        title: 'What to keep in mind',
                        message: caveats.map((c) => '• $c').join('\n'),
                        intent: UiIntent.warning,
                      ),
                    ),
                  if (nextSteps.isNotEmpty)
                    UiAccordionItem(
                      title: 'Next steps',
                      leadingIcon: Icons.checklist,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < nextSteps.length; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: context.sp(spacing.xs),
                              ),
                              child: Text(
                                '${i + 1}. ${nextSteps[i]}',
                                style: context.uiText.body,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            if (rows.isEmpty &&
                evidence.isEmpty &&
                text(data['summary']).isEmpty)
              const UiEmptyState(
                title: 'No research details supplied',
                message: 'Ask a follow-up with the missing context.',
                icon: Icons.description_outlined,
              ),
          ],
        ),
      ),
    );
  }
}
