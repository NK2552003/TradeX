import 'dart:async';
import 'package:alphajournal/core/linking/link_graph.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/widgets/record_unavailable.dart';
import 'package:alphajournal/features/notes/data/notes_repository.dart';
import 'package:alphajournal/features/journal/data/journal_repository.dart';
import 'package:alphajournal/features/strategies/data/strategies_repository.dart';
import 'package:alphajournal/features/notes/ui/notes_screen.dart';
import 'package:alphajournal/features/journal/ui/journal_screen.dart';
import 'package:alphajournal/features/strategies/ui/strategies_screen.dart';

class _Notes extends Fake implements NotesRepository {
  AppNote? record = AppNote(
    id: 'shared',
    userId: 'someone-else',
    title: 'Shared note',
    content: 'Public writing',
    isPublic: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final changes = StreamController<List<AppNote>>.broadcast();
  @override
  Stream<List<AppNote>> watchAll() async* {
    yield [];
    yield* changes.stream;
  }

  @override
  Stream<List<AppNote>> watchPublic() => const Stream.empty();
  @override
  Future<AppNote?> getById(String id) async => record;
  @override
  Future<AppNote> recordView(String id) async => record!;
}

class _Journal extends Fake implements JournalRepository {
  AppTrade? record = AppTrade(
    id: 'shared',
    userId: 'someone-else',
    ticker: 'XAUUSD',
    title: 'Shared journal',
    content: 'Public writing',
    side: AppSide.short,
    entry: 3900,
    exit: null,
    isPublic: true,
    openedAt: DateTime(2026),
  );
  final changes = StreamController<List<AppTrade>>.broadcast();
  @override
  Stream<List<AppTrade>> watchAll() async* {
    yield [];
    yield* changes.stream;
  }

  @override
  Future<AppTrade?> getById(String id) async => record;
  @override
  AppJournalStats get stats => JournalQuery.statsOf([]);
}

class _Strategies extends Fake implements StrategiesRepository {
  AppStrategy? record = AppStrategy(
    id: 'shared',
    userId: 'someone-else',
    name: 'Shared strategy',
    content: 'Public writing',
    isPublic: true,
  );
  final changes = StreamController<List<AppStrategy>>.broadcast();
  @override
  Stream<List<AppStrategy>> watchAll() async* {
    yield [];
    yield* changes.stream;
  }

  @override
  Future<AppStrategy?> getById(String id) async => record;
  @override
  Future<List<AppStrategyVersion>> versions(String id) async => [];
}

void main() {
  for (final kind in [
    AppLinkKind.note,
    AppLinkKind.journal,
    AppLinkKind.strategy,
  ]) {
    testWidgets(
      '$kind public reader survives an empty owned stream and rechecks revocation',
      (tester) async {
        tester.view.physicalSize = const Size(1100, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final notes = _Notes(),
            journal = _Journal(),
            strategies = _Strategies();
        NotesRepositoryScope.override(notes);
        JournalRepositoryScope.override(journal);
        StrategiesRepositoryScope.override(strategies);
        addTearDown(() async {
          NotesRepositoryScope.override(null);
          JournalRepositoryScope.override(null);
          StrategiesRepositoryScope.override(null);
          await notes.changes.close();
          await journal.changes.close();
          await strategies.changes.close();
        });
        final request = AppLinkOpenRequest(
          kind: kind,
          id: 'shared',
          seq: 1,
          publicContext: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: switch (kind) {
                AppLinkKind.note => NotesScreen(openRequest: request),
                AppLinkKind.journal => JournalScreen(openRequest: request),
                _ => StrategiesScreen(openRequest: request),
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        notes.changes.add([]);
        journal.changes.add([]);
        strategies.changes.add([]);
        await tester.pumpAndSettle();
        expect(find.byType(RecordUnavailable), findsNothing);
        expect(find.textContaining('Public writing'), findsWidgets);
        notes.record = notes.record!.copyWith(isPublic: false);
        journal.record = journal.record!.copyWith(isPublic: false);
        strategies.record = strategies.record!.copyWith(isPublic: false);
        notes.changes.add([]);
        journal.changes.add([]);
        strategies.changes.add([]);
        await tester.pumpAndSettle();
        expect(find.byType(RecordUnavailable), findsOneWidget);
        expect(find.textContaining('Public writing'), findsNothing);
        expect(tester.getSize(find.byType(RecordUnavailable)).width, 1100);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
