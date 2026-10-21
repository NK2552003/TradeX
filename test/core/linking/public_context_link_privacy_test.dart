import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';

void main() {
  group('AppLinkRef & AppLinkOpenRequest public context tests', () {
    test('AppLinkRef.copyWith(isPublicContext: true) retains all attributes', () {
      const ref = AppLinkRef(
        id: 'strat_trend',
        kind: AppLinkKind.strategy,
        title: 'Trend Following',
        subtitle: 'Breakouts',
        isPublicContext: false,
      );

      final forwarded = ref.copyWith(isPublicContext: true);
      expect(forwarded.id, 'strat_trend');
      expect(forwarded.kind, AppLinkKind.strategy);
      expect(forwarded.title, 'Trend Following');
      expect(forwarded.subtitle, 'Breakouts');
      expect(forwarded.isPublicContext, isTrue);
    });

    test('AppLinkOpenRequest accepts and stores publicContext', () {
      const req = AppLinkOpenRequest(
        kind: AppLinkKind.note,
        id: 'note_123',
        seq: 1,
        publicContext: true,
      );

      expect(req.id, 'note_123');
      expect(req.kind, AppLinkKind.note);
      expect(req.publicContext, isTrue);
    });
  });

  group('AppLinkGraph Privacy Bundle Filtering Tests', () {
    late AppLinkGraph graph;
    late AppStrategy publicStrategy;
    late AppNote publicNote;
    late AppNote privateNote;
    late AppTrade publicTrade;
    late AppTrade privateTrade;

    setUp(() {
      final now = DateTime.now();

      publicStrategy = const AppStrategy(
        id: 'strat_vol',
        name: 'Volatility Expansion',
        status: AppStrategyStatus.live,
        isPublic: true,
        wordCount: 150,
        versionCount: 1,
        trades: 2,
        winRate: 65.0,
        avgR: 2.1,
        netPnl: 1500.0,
        linkedNoteIds: <String>['note_pub', 'note_priv'],
      );

      publicNote = AppNote(
        id: 'note_pub',
        title: 'Public Market Thesis',
        content: 'Macro overview for public scrutiny #macro',
        createdAt: now,
        updatedAt: now,
        isPublic: true,
        wordCount: 100,
        tags: const <String>['macro'],
        strategyId: 'strat_vol',
      );

      privateNote = AppNote(
        id: 'note_priv',
        title: 'Confidential Risk Margin Note',
        content: 'Internal secret notes and personal sizing limits',
        createdAt: now,
        updatedAt: now,
        isPublic: false,
        wordCount: 50,
        strategyId: 'strat_vol',
      );

      publicTrade = AppTrade(
        id: 'trade_pub',
        ticker: 'NIFTY',
        entry: 24500,
        exit: 24650,
        openedAt: now,
        side: AppSide.long,
        strategy: 'Volatility Expansion',
        strategyId: 'strat_vol',
        isPublic: true,
        outcome: AppOutcome.win,
        pnl: 1200,
        linkedNoteIds: const <String>['note_pub', 'note_priv'],
      );

      privateTrade = AppTrade(
        id: 'trade_priv',
        ticker: 'BANKNIFTY',
        entry: 51200,
        exit: 51000,
        openedAt: now,
        side: AppSide.short,
        strategy: 'Volatility Expansion',
        strategyId: 'strat_vol',
        isPublic: false,
        outcome: AppOutcome.loss,
        pnl: -800,
        linkedNoteIds: const <String>['note_pub', 'note_priv'],
      );

      graph = AppLinkGraph(
        notes: <AppNote>[publicNote, privateNote],
        strategies: <AppStrategy>[publicStrategy],
        journal: <AppTrade>[publicTrade, privateTrade],
      );
    });

    test('bundleForStrategy with onlyPublic: false returns all notes and trades', () {
      final bundle = graph.bundleForStrategy(publicStrategy, onlyPublic: false);
      expect(bundle.notes.length, 2);
      expect(bundle.notes.map((r) => r.id), containsAll(<String>['note_pub', 'note_priv']));
      expect(bundle.journal.length, 2);
      expect(bundle.journal.map((r) => r.id), containsAll(<String>['trade_pub', 'trade_priv']));
    });

    test('bundleForStrategy with onlyPublic: true strictly excludes private records', () {
      final bundle = graph.bundleForStrategy(publicStrategy, onlyPublic: true);
      expect(bundle.notes.length, 1);
      expect(bundle.notes.first.id, 'note_pub');
      expect(bundle.notes.any((r) => r.id == 'note_priv'), isFalse);

      expect(bundle.journal.length, 1);
      expect(bundle.journal.first.id, 'trade_pub');
      expect(bundle.journal.any((r) => r.id == 'trade_priv'), isFalse);
    });

    test('siblingEntries with onlyPublic: true hides private trades under the same playbook', () {
      final allSiblings = graph.siblingEntries(publicTrade, onlyPublic: false);
      expect(allSiblings.any((r) => r.id == 'trade_priv'), isTrue);

      final publicSiblings = graph.siblingEntries(publicTrade, onlyPublic: true);
      expect(publicSiblings.any((r) => r.id == 'trade_priv'), isFalse);
    });

    test('bundleForNote with onlyPublic: true excludes private peer notes and trades', () {
      final bundlePub = graph.bundleForNote(publicNote, onlyPublic: true);
      expect(bundlePub.notes.any((r) => r.id == 'note_priv'), isFalse);
      expect(bundlePub.journal.any((r) => r.id == 'trade_priv'), isFalse);
      expect(bundlePub.strategies.map((r) => r.id), contains('strat_vol'));
    });

    test('bundleForJournal with onlyPublic: true excludes private notes', () {
      final bundlePub = graph.bundleForJournal(publicTrade, onlyPublic: true);
      expect(bundlePub.notes.length, 1);
      expect(bundlePub.notes.first.id, 'note_pub');
      expect(bundlePub.notes.any((r) => r.id == 'note_priv'), isFalse);
    });
  });
}
