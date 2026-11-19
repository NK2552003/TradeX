import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/linking/link_graph.dart';
import 'package:alphajournal/features/linking/link_graph_service.dart';

/// References the source documents directly; no copied note bodies or tickers.
class RecordWritingLibrary extends StatefulWidget {
  const RecordWritingLibrary({
    super.key,
    required this.kind,
    required this.onWrite,
    this.onOpen,
  });
  final AppLinkKind kind;
  final ValueChanged<AppLinkRef> onWrite;
  final ValueChanged<AppLinkRef>? onOpen;
  @override
  State<RecordWritingLibrary> createState() => _RecordWritingLibraryState();
}

class _RecordWritingLibraryState extends State<RecordWritingLibrary> {
  String query = '';
  @override
  Widget build(BuildContext context) => StreamBuilder<AppLinkGraph>(
    stream: AppLinkGraphScope.service.watch(),
    initialData: AppLinkGraphScope.service.current,
    builder: (context, snapshot) {
      final graph = snapshot.data ?? AppLinkGraph.empty;
      final trade = widget.kind == AppLinkKind.journal;
      final refs =
          (trade
                  ? graph.journalList.map(graph.journalRef)
                  : graph.strategyList.map(graph.strategyRef))
              .where(
                (ref) => '${ref.title} ${ref.subtitle}'.toLowerCase().contains(
                  query.toLowerCase(),
                ),
              )
              .toList();
      return UiPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppWorkspaceHeading(
              eyebrow: 'Your writing, one place',
              title: trade ? 'Trade reviews' : 'Strategy playbooks',
              description: trade
                  ? 'Write the reasoning here. Trade details and results stay in your journal.'
                  : 'Write the rules here. Instruments, status and performance stay with the strategy.',
            ),
            const UiGap.v(16),
            UiInput.search(
              value: query,
              hintText: trade ? 'Find a trade review' : 'Find a playbook',
              onChanged: (value) => setState(() => query = value),
            ),
            const UiGap.v(16),
            if (refs.isEmpty)
              UiEmptyState(
                title: 'No ${trade ? 'trades' : 'strategies'} found',
                message:
                    'Create the record in ${trade ? 'Journal' : 'Strategies'}, then write its ${trade ? 'review' : 'playbook'} here.',
              ),
            for (final ref in refs) ...[
              UiCard(
                padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
                child: UiHeader(
                  title: ref.title,
                  subtitle: ref.subtitle,
                  actions: [
                    if (widget.onOpen != null)
                      UiIconButton(
                        icon: Icons.open_in_new_rounded,
                        tooltip: 'Open ${trade ? 'trade' : 'strategy'} details',
                        onPressed: () => widget.onOpen!(ref),
                      ),
                    UiButton(
                      label: trade ? 'Edit review' : 'Edit playbook',
                      size: UiSize.sm,
                      leadingIcon: Icons.edit_note_rounded,
                      onPressed: () => widget.onWrite(ref),
                    ),
                  ],
                ),
              ),
              const UiGap.v(12),
            ],
          ],
        ),
      );
    },
  );
}
