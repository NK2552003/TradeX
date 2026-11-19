import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/linking/link_graph.dart';

import 'link_graph_service.dart';

/// One picker for every editor, including links between notes of the same kind.
Future<AppLinkRef?> showRecordLinkPicker(
  BuildContext context, {
  AppLinkKind? sourceKind,
  String? sourceId,
}) => UiDialog.show<AppLinkRef>(
  context,
  maxWidth: 580,
  child: _RecordLinkPicker(sourceKind: sourceKind, sourceId: sourceId),
);

class _RecordLinkPicker extends StatefulWidget {
  const _RecordLinkPicker({this.sourceKind, this.sourceId});
  final AppLinkKind? sourceKind;
  final String? sourceId;
  @override
  State<_RecordLinkPicker> createState() => _RecordLinkPickerState();
}

class _RecordLinkPickerState extends State<_RecordLinkPicker> {
  String query = '';
  AppLinkKind? kind;

  @override
  Widget build(BuildContext context) => StreamBuilder<AppLinkGraph>(
    stream: AppLinkGraphScope.service.watch(),
    initialData: AppLinkGraphScope.service.current,
    builder: (context, snapshot) {
      final graph = snapshot.data ?? AppLinkGraph.empty;
      final refs = <String, AppLinkRef>{};
      for (final type in AppLinkKind.values) {
        for (final ref in graph.options(type, query: query)) {
          refs['${type.name}:${ref.id}'] = ref;
        }
      }

      final visible = refs.values
          .where(
            (r) =>
                (kind == null || r.kind == kind) &&
                !(r.kind == widget.sourceKind && r.id == widget.sourceId),
          )
          .toList();
      return UiDialog(
        title: 'Link your thinking',
        description:
            'Connect a note, trade, playbook or instrument. Backlinks update automatically when you save.',
        content: SizedBox(
          height: context.sz(370),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiInput.search(
                value: query,
                hintText: 'Find a title or symbol',
                onChanged: (v) => setState(() => query = v),
              ),
              const UiGap.v(12),
              UiSelect<String>(
                value: kind?.name ?? 'all',
                expand: true,
                options: [
                  const UiOption(value: 'all', label: 'Everything'),
                  for (final type in AppLinkKind.values)
                    UiOption(value: type.name, label: type.plural),
                ],
                onChanged: (v) => setState(
                  () => kind = v == 'all' ? null : AppLinkKind.values.byName(v),
                ),
              ),
              const UiGap.v(12),
              Expanded(
                child: visible.isEmpty
                    ? const UiEmptyState(
                        title: 'No matching records',
                        message: 'Try another title or symbol.',
                      )
                    : ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, i) => AppLinkRefTile(
                          ref: visible[i],
                          onTap: () => Navigator.of(context).pop(visible[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
        actions: [
          UiButton(
            label: 'Cancel',
            variant: UiVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    },
  );
}
