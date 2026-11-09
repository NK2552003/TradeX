import 'package:flutter/material.dart';

import 'package:tradex/core/app-ui/app_ui.dart';
// Both unified libraries are required by the project UI contract.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/settings/data/publication_library.dart';
import 'publication_reader.dart';
import '../settings_nav_row.dart';

class HelpDocumentLibrary extends StatefulWidget {
  const HelpDocumentLibrary({super.key});
  @override
  State<HelpDocumentLibrary> createState() => _HelpDocumentLibraryState();
}

class _HelpDocumentLibraryState extends State<HelpDocumentLibrary> {
  late Future<List<PublicationDocument>> _documents = PublicationLibrary.load();
  String _query = '';
  String _group = 'All topics';

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<PublicationDocument>>(
    future: _documents,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return UiEmptyState(
          title: 'Library could not be loaded',
          actionLabel: 'Retry',
          onActionPressed: () =>
              setState(() => _documents = PublicationLibrary.load()),
        );
      }
      if (!snapshot.hasData) return const UiSkeleton(height: 180);
      final documents = snapshot.data!;
      final groups = ['All topics', ...documents.map((d) => d.group).toSet()];
      final visible = documents
          .where(
            (d) =>
                (_group == 'All topics' || d.group == _group) &&
                d.matches(_query),
          )
          .toList();
      return AppSettingsSectionBlock(
        title: 'Documentation and policies',
        description:
            'Browse ${documents.length} complete documents. Search includes the text inside every section.',
        children: [
          UiInput.search(
            value: _query,
            hintText: 'Search cookies, refunds, installation, privacy…',
            onChanged: (v) => setState(() => _query = v),
            onClear: () => setState(() => _query = ''),
          ),
          UiSelect<String>(
            value: _group,
            label: 'Topic',
            options: [for (final g in groups) UiOption(label: g, value: g)],
            onChanged: (v) => setState(() => _group = v),
          ),
          Text('${visible.length} documents', style: context.uiText.caption),
          if (visible.isEmpty)
            UiEmptyState(
              title: 'No matching documents',
              message: 'Try a shorter phrase or choose all topics.',
              actionLabel: 'Clear filters',
              onActionPressed: () => setState(() {
                _query = '';
                _group = 'All topics';
              }),
            ),
          for (final document in visible)
            SettingsNavRow(
              key: ValueKey(document.id),
              title: document.title,
              titleMaxLines: null,
              onTap: () => PublicationReader.open(context, document.id),
            ),
        ],
      );
    },
  );
}
