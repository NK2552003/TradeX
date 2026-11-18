import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

String marketFieldLabel(String key) {
  final value = key
      .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll('_', ' ');
  return value.isEmpty
      ? value
      : '${value[0].toUpperCase()}${value.substring(1)}';
}

class MarketDataFields extends StatelessWidget {
  const MarketDataFields({super.key, required this.data});
  final Map data;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final nested = data.entries
          .where((e) => e.value is Map || e.value is List)
          .toList();
      if (data.isEmpty) {
        return const UiEmptyState(title: 'No data in this snapshot');
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: context.sp(context.ui.spacing.md),
            runSpacing: context.sp(context.ui.spacing.sm),
            children: [
              for (final entry in data.entries.where(
                (e) => e.value is! Map && e.value is! List,
              ))
                SizedBox(
                  width: constraints.maxWidth.clamp(0, context.sz(220)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        marketFieldLabel('${entry.key}'),
                        style: context.uiText.caption.copyWith(
                          color: context.ui.colors.foregroundMuted,
                        ),
                      ),
                      Text('${entry.value ?? '—'}', style: context.uiText.body),
                    ],
                  ),
                ),
            ],
          ),
          if (nested.isNotEmpty)
            UiAccordion(
              allowMultiple: true,
              items: [
                for (final entry in nested)
                  UiAccordionItem(
                    title: marketFieldLabel('${entry.key}'),
                    content: entry.value is Map
                        ? MarketDataFields(data: entry.value as Map)
                        : MarketDataRecords(rows: entry.value as List),
                  ),
              ],
            ),
        ],
      );
    },
  );
}

class MarketDataRecords extends StatelessWidget {
  const MarketDataRecords({super.key, required this.rows});
  final List rows;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const UiEmptyState(title: 'No data in this snapshot');
    }
    final records = rows.map((r) => r is Map ? r : {'value': r}).toList();
    final keys = <String>{
      for (final row in records)
        for (final key in row.keys)
          if (row[key] is! Map && row[key] is! List) '$key',
    }.take(5).toList();
    return UiTable<Map>(
      rows: records,
      pageSize: 10,
      stackOnMobile: true,
      expandableWhen: (_) => true,
      expandedBuilder: (c, row) => MarketDataFields(data: row),
      columns: [
        for (final key in keys)
          UiTableColumn(
            header: marketFieldLabel(key),
            cell: (c, row) => Text(
              '${row[key] ?? '—'}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
