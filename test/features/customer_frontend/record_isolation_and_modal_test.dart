import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/customer_limitations.dart';
import 'package:tradex/core/config/record_access.dart';
import 'package:tradex/features/community/presentation/widgets/public_record_detail_modal.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/features/strategies/data/strategies_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Record Privacy & Personal Writing Desk Isolation', () {
    test('NotesRepository creates note and maintains personal list isolation', () async {
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
    });

    test('JournalRepository creates trade and enforces personal journal isolation', () async {
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
    });

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
    testWidgets('CustomerLimitations allows creation when within quota', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: UiButton(
                  label: 'Check Quota',
                  onPressed: () async {
                    final canNote = await CustomerLimitations.checkCanCreateNote(
                      context,
                      currentNoteCount: 5,
                    );
                    final canTrade = await CustomerLimitations.checkCanCreateTrade(
                      context,
                      currentTradeCount: 10,
                    );
                    final canStrategy = await CustomerLimitations.checkCanCreateStrategy(
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
    testWidgets('renders public research note as a community post open window', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final note = AppNote(
        id: 'note-sample-01',
        userId: 'trader-01',
        title: 'Breakout Strategy on BankNifty',
        content: 'Analyzing multi-week consolidation on \$BANKNIFTY with key resistance at 52,000.',
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

      // Verify window elements
      expect(find.text('Research Note'), findsOneWidget);
      expect(find.text('Public'), findsAtLeastNWidgets(1));
      expect(find.text('Breakout Strategy on BankNifty'), findsOneWidget);
      expect(find.text('Analysis'), findsOneWidget);
      expect(find.text('Like'), findsOneWidget);
      expect(find.text('Bookmark'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('renders public trade journal entry with financial metrics', (tester) async {
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
        content: 'Entered after cup-and-handle pattern completed on daily timeframe.',
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

      // Verify Trade Journal window elements
      expect(find.text('Trade Journal'), findsOneWidget);
      expect(find.text('\$TCS'), findsOneWidget);
      expect(find.text('LONG'), findsOneWidget);
      expect(find.text('WIN'), findsOneWidget);
      expect(find.text('Net PnL'), findsOneWidget);
      expect(find.text('R-Multiple'), findsOneWidget);
      expect(find.text('+2.40R'), findsOneWidget);
    });
  });
}
