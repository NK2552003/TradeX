import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/customer_limitations.dart';
import 'package:alphajournal/core/config/record_access.dart';
import 'package:alphajournal/core/linking/link_graph.dart';
import 'package:alphajournal/features/community/presentation/widgets/public_record_detail_modal.dart';
import 'package:alphajournal/features/journal/data/journal_repository.dart';
import 'package:alphajournal/features/journal/ui/journal_entry_screen.dart';
import 'package:alphajournal/features/notes/data/notes_repository.dart';
import 'package:alphajournal/features/notes/ui/note_preview_screen.dart';
import 'package:alphajournal/features/strategies/data/strategies_repository.dart';
import 'package:alphajournal/features/strategies/ui/strategy_detail_screen.dart';

class _DelayedLikeNotes extends Fake implements NotesRepository {
  _DelayedLikeNotes(this.note);

  AppNote note;
  final Completer<AppNote> likeResult = Completer<AppNote>();

  @override
  Stream<List<AppNote>> watchAll() =>
      Stream<List<AppNote>>.value(<AppNote>[note]);

  @override
  Stream<AppNote> watchById(String id) => Stream<AppNote>.value(note);

  @override
  Future<AppNote?> getById(String id) async => note;

  @override
  Future<AppNote> recordView(String id) async => note;

  @override
  Future<AppNote> toggleLike(String id) => likeResult.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Record Privacy & Personal Writing Desk Isolation', () {
    test(
      'NotesRepository creates note and maintains personal list isolation',
      () async {
        final repo = NotesRepositoryImpl.instance;
        final now = DateTime.now();
        final draft = AppNote(
          id: '',
          title: 'Personal Thesis on Nifty',
          content: 'Breakout above 25,000 with strong volume.',
          createdAt: now,
          updatedAt: now,
          isPublic: false,
        );

        final created = await repo.create(draft);
        expect(created.id, isNotEmpty);
        expect(created.title, equals('Personal Thesis on Nifty'));

        final all = await repo.fetchAll();
        expect(all.any((n) => n.id == created.id), isTrue);

        // Verify another user's note does not pollute the personal list
        final foreignNote = await repo.getById('non-existent-or-foreign-id');
        expect(foreignNote, isNull);
      },
    );

    test(
      'JournalRepository creates trade and enforces personal journal isolation',
      () async {
        final repo = JournalRepositoryImpl.instance;
        final now = DateTime.now();
        final draft = AppTrade(
          id: '',
          ticker: 'RELIANCE',
          side: AppSide.long,
          entry: 2950.0,
          exit: 3020.0,
          openedAt: now,
          outcome: AppOutcome.win,
          pnl: 7000.0,
          isPublic: true,
        );

        final created = await repo.create(draft);
        expect(created.id, isNotEmpty);
        expect(created.ticker, equals('RELIANCE'));
        expect(created.outcome, equals(AppOutcome.win));

        final all = await repo.fetchAll();
        expect(all.any((t) => t.id == created.id), isTrue);
      },
    );

    test('StrategiesRepository creates playbook and seeds version', () async {
      final repo = StrategiesRepositoryImpl.instance;
      final now = DateTime.now();
      final draft = AppStrategy(
        id: '',
        name: 'Opening Range Breakout (ORB)',
        content: 'Enter on 15-minute high breakout with stop at low.',
        status: AppStrategyStatus.live,
        isPublic: true,
        createdAt: now,
        updatedAt: now,
      );

      final created = await repo.create(draft);
      expect(created.id, isNotEmpty);
      expect(created.name, equals('Opening Range Breakout (ORB)'));

      final all = await repo.fetchAll();
      expect(all.any((s) => s.id == created.id), isTrue);
    });

    test('RecordAccess correctly recognizes ownership', () {
      expect(RecordAccess.owns('demo_user'), isTrue);
      expect(RecordAccess.owns('00000000-0000-0000-0000-000000000001'), isTrue);
      expect(RecordAccess.owns(''), isTrue);
    });
  });

  group('CustomerLimitations Quotas & Creation Unblocking', () {
    testWidgets('CustomerLimitations allows creation when within quota', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: UiButton(
                  label: 'Check Quota',
                  onPressed: () async {
                    final canNote =
                        await CustomerLimitations.checkCanCreateNote(
                          context,
                          currentNoteCount: 5,
                        );
                    final canTrade =
                        await CustomerLimitations.checkCanCreateTrade(
                          context,
                          currentTradeCount: 10,
                        );
                    final canStrategy =
                        await CustomerLimitations.checkCanCreateStrategy(
                          context,
                          currentLiveStrategyCount: 1,
                        );
                    expect(canNote, isTrue);
                    expect(canTrade, isTrue);
                    expect(canStrategy, isTrue);
                  },
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Check Quota'));
      await tester.pumpAndSettle();
    });
  });

  group('PublicRecordDetailModal Post-Style Open Window', () {
    testWidgets(
      'public note like updates immediately before the server reply',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final AppNote note = AppNote(
          id: 'note-like-test',
          userId: 'trader-01',
          title: 'Live engagement note',
          content: 'Public research content.',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          isPublic: true,
          liked: false,
          likeCount: 0,
        );
        final _DelayedLikeNotes repository = _DelayedLikeNotes(note);
        NotesRepositoryScope.override(repository);
        addTearDown(() => NotesRepositoryScope.override(null));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NotePreviewScreen(
                note: note,
                onClose: () {},
                onEdit: () {},
                canEdit: false,
                isPublicContext: true,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(UiButton, 'Like'));
        await tester.pump();

        expect(find.widgetWithText(UiButton, 'Liked'), findsOneWidget);
        expect(find.textContaining('1 likes'), findsOneWidget);

        repository.likeResult.complete(
          note.copyWith(liked: true, likeCount: 1),
        );
        await tester.pump();
        expect(find.widgetWithText(UiButton, 'Liked'), findsOneWidget);
      },
    );

    testWidgets('renders public research note as a community post open window', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final note = AppNote(
        id: 'note-sample-01',
        userId: 'trader-01',
        title: 'Breakout Strategy on BankNifty',
        content:
            'Analyzing multi-week consolidation on \$BANKNIFTY with key resistance at 52,000.',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        updatedAt: DateTime.now(),
        noteType: AppNoteType.analysis,
        isPublic: true,
        wordCount: 120,
        linkedTickers: const ['BANKNIFTY'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PublicRecordDetailModal(
              ref: const AppLinkRef(
                kind: AppLinkKind.note,
                id: 'note-sample-01',
                title: 'Breakout Strategy on BankNifty',
                isPublicContext: true,
              ),
              initialNote: note,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Community mounts the same complete reader as the Notes workspace.
      expect(find.byType(NotePreviewScreen), findsOneWidget);
      expect(find.text('Public'), findsAtLeastNWidgets(1));
      expect(find.text('Breakout Strategy on BankNifty'), findsOneWidget);
      expect(find.text('Analysis'), findsWidgets);
      expect(find.byTooltip('Export as PDF'), findsOneWidget);
      expect(find.byTooltip('Share note'), findsOneWidget);
    });

    testWidgets('renders public trade journal entry with financial metrics', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final trade = AppTrade(
        id: 'trade-sample-01',
        userId: 'trader-02',
        ticker: 'TCS',
        side: AppSide.long,
        entry: 3850.0,
        exit: 3990.0,
        openedAt: DateTime.now().subtract(const Duration(days: 1)),
        outcome: AppOutcome.win,
        pnl: 14000.0,
        pnlPercent: 3.6,
        rMultiple: 2.4,
        isPublic: true,
        content:
            'Entered after cup-and-handle pattern completed on daily timeframe.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PublicRecordDetailModal(
              ref: const AppLinkRef(
                kind: AppLinkKind.journal,
                id: 'trade-sample-01',
                title: 'TCS Long',
                isPublicContext: true,
              ),
              initialTrade: trade,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Community mounts the same complete reader as the Journal workspace.
      expect(find.byType(JournalEntryScreen), findsOneWidget);
      expect(find.text('TCS'), findsWidgets);
      expect(find.text('Long'), findsOneWidget);
      expect(find.text('The trade'), findsOneWidget);
      expect(find.text('Result'), findsOneWidget);
      expect(find.text('2.40R'), findsWidgets);
      expect(find.byTooltip('Export as PDF'), findsOneWidget);
    });

    testWidgets(
      'renders the complete strategy playbook with history and linked records',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final strategy = AppStrategy(
          id: 'strategy-sample-01',
          userId: 'trader-03',
          name: 'Opening Range Breakout',
          content: 'Trade the first clean range expansion.',
          status: AppStrategyStatus.live,
          isPublic: true,
          trades: 24,
          winRate: 62.5,
          avgR: 1.8,
          netPnl: 48000,
          linkedJournalIds: const <String>['linked-trade'],
        );
        final linkedTrade = AppTrade(
          id: 'linked-trade',
          userId: 'trader-03',
          ticker: 'NIFTY',
          title: 'Linked trade evidence',
          side: AppSide.long,
          entry: 25000,
          exit: null,
          openedAt: DateTime(2026),
          isPublic: true,
          strategyId: strategy.id,
          strategy: strategy.name,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PublicRecordDetailModal(
                ref: const AppLinkRef(
                  kind: AppLinkKind.strategy,
                  id: 'strategy-sample-01',
                  title: 'Opening Range Breakout',
                  isPublicContext: true,
                ),
                initialStrategy: strategy,
                initialLinkGraph: AppLinkGraph(
                  journal: <AppTrade>[linkedTrade],
                  strategies: <AppStrategy>[strategy],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(StrategyDetailScreen), findsOneWidget);
        expect(find.text('Opening Range Breakout'), findsOneWidget);
        expect(find.text('Playbook'), findsOneWidget);
        expect(find.text('History'), findsOneWidget);
        expect(find.text('Linked'), findsWidgets);
        expect(find.text('Linked trade evidence'), findsOneWidget);
        expect(find.byTooltip('Export as PDF'), findsOneWidget);
      },
    );
  });
}
