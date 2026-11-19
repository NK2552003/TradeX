import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

String adminDate(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return 'Not recorded';
  final local = date.toLocal();
  return '${UiDatePicker.format(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String adminValue(Object? value) => switch (value) {
  null => 'Not recorded',
  bool flag => flag ? 'Yes' : 'No',
  List items => items.isEmpty ? 'None' : items.join(', '),
  _ => value.toString().isEmpty ? 'Not recorded' : value.toString(),
};

class AdminFacts extends StatelessWidget {
  const AdminFacts({super.key, required this.values});
  final Map<String, String> values;
  @override
  Widget build(BuildContext context) => UiTable<MapEntry<String, String>>(
    rows: values.entries.toList(),
    columns: [
      UiTableColumn(header: 'Field', flex: 2, valueGetter: (row) => row.key),
      UiTableColumn(
        header: 'Value',
        flex: 3,
        cell: (context, row) =>
            SelectableText(row.value, style: context.uiText.body),
      ),
    ],
  );
}

class AdminSection extends StatelessWidget {
  const AdminSection({
    super.key,
    required this.title,
    required this.child,
    this.description,
  });
  final String title;
  final String? description;
  final Widget child;
  @override
  Widget build(BuildContext context) => UiCard(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: context.uiText.subheading),
        if (description != null) ...[
          const UiGap.v(6),
          Text(
            description!,
            style: context.uiText.body.copyWith(
              color: context.ui.colors.foregroundMuted,
            ),
          ),
        ],
        const UiGap.v(16),
        child,
      ],
    ),
  );
}
