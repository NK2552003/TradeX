import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/widgets/app_scaffold.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/community/presentation/community_root_screen.dart';
import 'package:alphajournal/features/community/presentation/views/community_feed_view.dart';
import 'package:alphajournal/features/community/presentation/widgets/public_record_detail_modal.dart';
import 'package:alphajournal/features/journal/ui/journal_entry_screen.dart';
import 'package:alphajournal/features/notes/ui/note_preview_screen.dart';
import 'package:alphajournal/features/notes/ui/notes_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  void viewport(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final width in [320.0, 390.0, 1440.0]) {
    for (final kind in [
      AppLinkKind.note,
      AppLinkKind.journal,
      AppLinkKind.strategy,
    ]) {
      testWidgets('$kind stays in Community at $width px and returns to feed', (
        tester,
      ) async {
        viewport(tester, width);
        final repo = CommunityRepository();
        addTearDown(repo.dispose);
        final external = <AppLinkRef>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CommunityRootScreen(
                repository: repo,
                onOpenRef: external.add,
                embedInScaffold: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final original = tester.state(find.byType(CommunityRootScreen));
        tester
            .widget<CommunityFeedView>(find.byType(CommunityFeedView))
            .onOpenRef!(
          AppLinkRef(
            kind: kind,
            id: 'unavailable-shared-record',
            title: 'Shared record',
          ),
        );
        await tester.pumpAndSettle();
        expect(external, isEmpty);
        expect(find.byType(PublicRecordDetailModal), findsOneWidget);
        final reader = tester.widget<PublicRecordDetailModal>(
          find.byType(PublicRecordDetailModal),
        );
        expect(reader.ref.isPublicContext, isTrue);
        expect(reader.onOpenEditor, isNull);
        final panel = find.byKey(const ValueKey('settings-side-sheet-surface'));
        expect(panel, findsOneWidget);
        expect(
          tester.getSize(panel).width,
          width > 900 ? lessThan(width) : width,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Back to Community'));
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(CommunityRootScreen)), same(original));
        expect(find.byType(PublicRecordDetailModal), findsNothing);
      });
    }
  }

  testWidgets(
    'app shell public record handler does not change destination or URL',
    (tester) async {
      viewport(tester, 1440);
      final opened = <AppLinkRef>[];
      await tester.pumpWidget(
        MaterialApp(
          home: AppScaffold(
            initialDestination: 'community',
            onOpenRecord: opened.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final shell = tester.widget<CommunityRootScreen>(
        find.byType(CommunityRootScreen),
      );
      shell.onOpenRef!(
        const AppLinkRef(
          kind: AppLinkKind.note,
          id: 'missing',
          title: 'Shared note',
        ),
      );
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(find.byType(PublicRecordDetailModal), findsOneWidget);
      expect(
        find.byType(CommunityRootScreen, skipOffstage: false),
        findsOneWidget,
      );
      await tester.tap(find.text('Back to Community'));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityRootScreen), findsOneWidget);
    },
  );

  testWidgets('app shell shared-record save updates Community bookmarks', (
    tester,
  ) async {
    viewport(tester, 1440);
    await tester.pumpWidget(
      const MaterialApp(home: AppScaffold(initialDestination: 'community')),
    );
    await tester.pumpAndSettle();
    final CommunityRootScreen community = tester.widget<CommunityRootScreen>(
      find.byType(CommunityRootScreen),
    );
    final CommunityRepository repository = community.repository!;
    final post = repository.forYouPosts.first;

    community.onOpenRef!(
      AppLinkRef(
        kind: AppLinkKind.note,
        id: 'missing-shared-note',
        title: 'Shared note',
        originPostId: post.id,
      ),
    );
    await tester.pump();

    final PublicRecordDetailModal modal = tester
        .widget<PublicRecordDetailModal>(find.byType(PublicRecordDetailModal));
    expect(modal.onSaveChanged, isNotNull);
    await modal.onSaveChanged!(true);
    expect(
      repository.bookmarkedPosts.any(
        (CommunityPost bookmarked) => bookmarked.id == post.id,
      ),
      isTrue,
    );
  });

  testWidgets('mobile shared note keeps title and close action inside sheet', (
    tester,
  ) async {
    viewport(tester, 320);
    var foreignEditCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => UiButton(
              label: 'Read note',
              onPressed: () => PublicRecordDetailModal.show(
                context,
                ref: const AppLinkRef(
                  kind: AppLinkKind.note,
                  id: 'note',
                  title: 'Shared thesis',
                  isPublicContext: true,
                ),
                initialNote: AppNote(
                  id: 'note',
                  userId: 'author',
                  title: 'Shared thesis',
                  content: 'A useful research note.',
                  createdAt: DateTime(2026),
                  updatedAt: DateTime(2026),
                  isPublic: true,
                ),
                onOpenEditor: () => foreignEditCount += 1,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Read note'));
    await tester.pumpAndSettle();
    expect(find.text('Shared thesis'), findsOneWidget);
    expect(find.byType(NotePreviewScreen), findsOneWidget);
    expect(find.byTooltip('Export as PDF'), findsOneWidget);
    expect(find.byTooltip('Back to notes'), findsOneWidget);
    expect(find.byTooltip('Edit in Writing Desk'), findsNothing);
    expect(foreignEditCount, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('mobile shared journal metrics fit inside reader', (
    tester,
  ) async {
    viewport(tester, 320);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PublicRecordDetailModal(
            ref: const AppLinkRef(
              kind: AppLinkKind.journal,
              id: 'trade',
              title: 'TCS journal',
              isPublicContext: true,
            ),
            initialTrade: AppTrade(
              id: 'trade',
              userId: 'author',
              ticker: 'TCS',
              side: AppSide.long,
              entry: 3850,
              exit: 3990,
              pnl: 14000,
              openedAt: DateTime(2026),
              outcome: AppOutcome.win,
              isPublic: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(JournalEntryScreen), findsOneWidget);
    expect(find.byTooltip('Export as PDF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only the owner can leave the reader for the real editor', (
    tester,
  ) async {
    viewport(tester, 1200);
    var editCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => UiButton(
              label: 'Read owned note',
              onPressed: () => PublicRecordDetailModal.show(
                context,
                ref: const AppLinkRef(
                  kind: AppLinkKind.note,
                  id: 'owned-note',
                  title: 'Owned note',
                  isPublicContext: true,
                ),
                initialNote: AppNote(
                  id: 'owned-note',
                  userId: 'demo_user',
                  title: 'Owned note',
                  content: 'Public owner content.',
                  createdAt: DateTime(2026),
                  updatedAt: DateTime(2026),
                  isPublic: true,
                ),
                onOpenEditor: () => editCount += 1,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Read owned note'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit in Writing Desk'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit in Writing Desk'));
    await tester.pumpAndSettle();
    expect(editCount, 1);
    expect(find.byType(PublicRecordDetailModal), findsNothing);
  });

  testWidgets('app shell owner edit callback opens Notes outside Community', (
    tester,
  ) async {
    viewport(tester, 1440);
    final opened = <AppLinkRef>[];
    await tester.pumpWidget(
      MaterialApp(
        home: AppScaffold(
          initialDestination: 'community',
          onOpenRecord: opened.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final community = tester.widget<CommunityRootScreen>(
      find.byType(CommunityRootScreen),
    );
    community.onOpenWriting!(
      const AppLinkRef(
        kind: AppLinkKind.note,
        id: 'owned-note',
        title: 'Owned note',
        isPublicContext: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NotesScreen), findsOneWidget);
    expect(opened.last.isPublicContext, isFalse);
  });
}
