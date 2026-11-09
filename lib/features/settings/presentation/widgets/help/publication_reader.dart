import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tradex/core/app-ui/app_ui.dart';
// Both unified libraries are required by the project UI contract.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/settings/data/publication_library.dart';

class PublicationReader extends StatefulWidget {
  const PublicationReader({super.key, required this.documentId});
  final String documentId;

  static void open(BuildContext context, String id) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push('/help/$id');
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(body: PublicationReader(documentId: id)),
        ),
      );
    }
  }

  @override
  State<PublicationReader> createState() => _PublicationReaderState();
}

class _PublicationReaderState extends State<PublicationReader> {
  late Future<List<PublicationDocument>> _documents = PublicationLibrary.load();
  Set<int> _expanded = {0};

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go('/help');
    }
  }

  @override
  Widget build(BuildContext context) => UiPage(
    title: 'Help and policies',
    actions: [
      UiButton(
        label: 'Back to help',
        variant: UiVariant.outline,
        onPressed: _back,
      ),
    ],
    child: FutureBuilder<List<PublicationDocument>>(
      future: _documents,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return UiEmptyState(
            title: 'Document could not be loaded',
            actionLabel: 'Retry',
            onActionPressed: () => setState(() {
              _documents = PublicationLibrary.load();
            }),
          );
        }
        if (!snapshot.hasData) return const UiSkeleton(height: 200);
        final matches = snapshot.data!.where((d) => d.id == widget.documentId);
        if (matches.isEmpty) {
          return const UiEmptyState(
            title: 'Document not found',
            message: 'Return to help to browse the available documents.',
          );
        }
        final document = matches.first;
        return SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiHeader(title: document.title, subtitle: document.intro),
              UiGap.v(context.ui.spacing.md),
              Text(
                'Updated ${document.updated}',
                style: context.uiText.caption,
              ),
              UiGap.v(context.ui.spacing.md),
              Wrap(
                spacing: context.sp(context.ui.spacing.sm),
                children: [
                  UiButton(
                    label: 'Expand all sections',
                    variant: UiVariant.outline,
                    onPressed: () => setState(
                      () => _expanded = Set.from(
                        List.generate(document.sections.length, (i) => i),
                      ),
                    ),
                  ),
                  UiButton(
                    label: 'Collapse sections',
                    variant: UiVariant.ghost,
                    onPressed: () => setState(() => _expanded = {}),
                  ),
                ],
              ),
              UiGap.v(context.ui.spacing.md),
              UiAccordion(
                allowMultiple: true,
                openIndices: _expanded,
                onChanged: (value) => setState(() => _expanded = value),
                items: [
                  for (final section in document.sections)
                    UiAccordionItem(
                      title: section.title,
                      content: Text(
                        section.body,
                        style: context.uiText.body.copyWith(height: 1.6),
                      ),
                    ),
                ],
              ),
              UiGap.v(context.ui.spacing.xl),
              Text(
                'Questions or privacy requests: h82292245@gmail.com',
                style: context.uiText.body,
              ),
              UiGap.v(context.uiDockInset),
            ],
          ),
        );
      },
    ),
  );
}
