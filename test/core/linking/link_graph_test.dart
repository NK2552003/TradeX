import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/core/linking/link_graph.dart';

/// Guards the link graph and the demo fixtures it is built from.
///
/// Two things are under test here, deliberately together. The first is
/// [AppLinkGraph] itself: that every edge resolves, that bundles never hand a
/// screen a ref pointing at a deleted record, that deep links round trip and
/// that pickers exclude what is already attached.
///
/// The second is the *shape of the mock data*, which is load-bearing while the
/// backend does not exist yet. The notes, journal and strategy surfaces are all
/// built to show linked records, partial coverage and the "unfiled trade" prompt,
/// so a fixture edit that silently links every trade to a playbook would make
/// three screens render states nobody has designed. The counted expectations
/// below exist to fail loudly when that happens — if you change a fixture on
/// purpose, change the count on purpose too.
void main() {
  final DemoDataSource demo = DemoDataSource.instance;
  final List<AppNote> notes = demo.notes();
  final List<AppTrade> journal = demo.trades();
  final List<AppStrategy> strategies = demo.strategies();
  final AppLinkGraph graph = AppLinkGraph(
    notes: notes,
    journal: journal,
    strategies: strategies,
    tickers: demo.tickers(),
  );

  test('note -> journal edges have their inverse on the entry', () {
    for (final AppNote n in notes) {
      for (final String id in n.linkedJournalIds) {
        final AppTrade? t = graph.entry(id);
        expect(t, isNotNull, reason: 'note ${n.id} points at missing $id');
        expect(
          t!.linkedNoteIds,
          contains(n.id),
          reason: 'entry $id does not point back at ${n.id}',
        );
      }
    }
  });

  test('journal -> strategy edges have their inverse on the playbook', () {
    final List<AppTrade> filed = journal
        .where((AppTrade t) => t.strategyId != null)
        .toList();
    expect(filed, isNotEmpty);
    expect(filed.length, lessThan(journal.length), reason: 'no unfiled trades');
    for (final AppTrade t in filed) {
      final AppStrategy? s = graph.strategy(t.strategyId!);
      expect(
        s,
        isNotNull,
        reason: 'entry ${t.id} points at missing ${t.strategyId}',
      );
      expect(s!.linkedJournalIds, contains(t.id));
    }
    for (final AppTrade t in journal.where(
      (AppTrade t) => t.strategyId == null,
    )) {
      expect(t.strategy, isNull, reason: 'unfiled ${t.id} still names a setup');
    }
  });

  test('note -> strategy edges have their inverse on the playbook', () {
    for (final AppNote n in notes.where((AppNote n) => n.strategyId != null)) {
      final AppStrategy? s = graph.strategy(n.strategyId!);
      expect(s, isNotNull);
      expect(s!.linkedNoteIds, contains(n.id));
      expect(n.strategyName, s.name);
    }
  });

  test('no bundle contains an unresolvable ref', () {
    for (final AppNote n in notes) {
      expect(
        graph.bundleForNote(n).all.any((AppLinkRef r) => r.missing),
        false,
      );
    }
    for (final AppTrade t in journal) {
      expect(
        graph.bundleForJournal(t).all.any((AppLinkRef r) => r.missing),
        false,
      );
    }
    for (final AppStrategy s in strategies) {
      expect(
        graph.bundleForStrategy(s).all.any((AppLinkRef r) => r.missing),
        false,
      );
    }
  });

  test('every surface shows real edges', () {
    expect(notes.where((AppNote n) => n.linkedJournalIds.isNotEmpty).length, 6);
    expect(notes.where((AppNote n) => n.strategyId != null).length, 8);
    expect(
      journal.where((AppTrade t) => t.linkedNoteIds.isNotEmpty).length,
      greaterThan(8),
    );
    for (final AppStrategy s in strategies) {
      expect(s.linkedJournalIds, isNotEmpty);
    }
    expect(graph.edgeCount, greaterThan(60));
  });

  test('journal coverage is partial so the prompt has something to say', () {
    expect(graph.journalCoverage, greaterThan(0.7));
    expect(graph.journalCoverage, lessThan(0.9));
    final List<AppLinkRef> orphans = graph.orphans();
    expect(orphans, isNotEmpty);
    expect(
      orphans.any((AppLinkRef r) => r.kind == AppLinkKind.journal),
      true,
      reason: 'a trade with no plan and no note is the orphan that matters',
    );
    for (final AppLinkRef r in orphans) {
      final AppLinkBundle b = graph.bundleFor(r.kind, r.id);
      if (r.kind == AppLinkKind.strategy) {
        expect(b.journal, isEmpty, reason: '${r.id} has traded entries');
      } else {
        expect(b.notes, isEmpty, reason: '${r.id} is linked to a note');
        expect(b.journal, isEmpty, reason: '${r.id} is linked to an entry');
        expect(b.strategies, isEmpty, reason: '${r.id} sits under a playbook');
      }
    }
  });

  test('journal entries carry derived counters and a title fallback', () {
    final List<AppTrade> written = journal
        .where((AppTrade t) => t.hasStory)
        .toList();
    expect(written.every((AppTrade t) => t.wordCount > 0), true);
    expect(written.any((AppTrade t) => t.hasChecklist), true);
    expect(written.any((AppTrade t) => t.hasCode), true);
    expect(journal.any((AppTrade t) => t.title.isEmpty), true);
    expect(journal.every((AppTrade t) => t.displayTitle.isNotEmpty), true);
  });

  test('playbooks carry bodies, statuses and version snapshots', () {
    expect(strategies.every((AppStrategy s) => s.hasPlaybook), true);
    expect(strategies.every((AppStrategy s) => s.wordCount > 150), true);
    expect(
      strategies.map((AppStrategy s) => s.status).toSet().length,
      greaterThanOrEqualTo(4),
    );
    for (final AppStrategy s in strategies) {
      final List<AppStrategyVersion> versions = demo.strategyVersions(s.id);
      expect(versions.first.isCurrent, true);
      expect(versions.first.content, s.content);
      expect(
        versions.map((AppStrategyVersion v) => v.content).toSet().length,
        versions.length,
      );
      expect(
        versions.every((AppStrategyVersion v) => v.strategyId == s.id),
        true,
      );
      expect(versions.every((AppStrategyVersion v) => v.wordCount > 0), true);
    }
  });

  test('deep links round trip through every kind', () {
    for (final AppLinkKind kind in AppLinkKind.values) {
      final Uri uri = AppDeepLink.of(kind, 'abc');
      expect(AppDeepLink.isInternal(uri), true);
      expect(AppDeepLink.target(uri)?.kind, kind);
      expect(AppDeepLink.target(uri)?.id, 'abc');
    }
    expect(AppDeepLink.target(Uri.parse('https://example.com/x')), isNull);
    expect(AppDeepLink.target(Uri.parse('tradex://watchlist/x')), isNull);
    expect(AppDeepLink.target(Uri.parse('tradex://note/')), isNull);
    expect(
      graph.resolve(AppDeepLink.of(AppLinkKind.note, notes.first.id))?.title,
      notes.first.title,
    );
  });

  test('pickers exclude what is already linked', () {
    final AppNote n = notes.firstWhere(
      (AppNote n) => n.linkedJournalIds.isNotEmpty,
    );
    final List<AppLinkRef> options = graph.options(
      AppLinkKind.journal,
      exclude: n.linkedJournalIds,
    );
    expect(options.length, journal.length - n.linkedJournalIds.length);
    expect(
      graph.options(AppLinkKind.strategy, query: 'gap').length,
      lessThan(strategies.length),
    );
  });
}
