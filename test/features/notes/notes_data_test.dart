import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/models/app_models.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';

/// Lets every queued microtask and the stream's own delivery hop run before an
/// assertion looks at what a listener received.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// Builds a note with only the fields a given test cares about.
AppNote _note({
  String id = 'n1',
  String title = 'Untitled',
  String content = '',
  AppNoteType type = AppNoteType.general,
  List<String> tags = const <String>[],
  List<String> tickers = const <String>[],
  String? strategyName,
  int wordCount = 0,
  int daysAgo = 0,
}) {
  final DateTime when = DateTime(2026, 1, 20).subtract(Duration(days: daysAgo));
  return AppNote(
    id: id,
    title: title,
    content: content,
    createdAt: when,
    updatedAt: when,
    noteType: type,
    tags: tags,
    linkedTickers: tickers,
    strategyName: strategyName,
    wordCount: wordCount,
  );
}

void main() {
  group('AppNoteType wire contract', () {
    // These are the exact values the `note_type` CHECK constraint in
    // database/migrations/007_trader_notes.sql accepts. Changing one here
    // without changing the migration silently downgrades stored notes to
    // `general`, so the mapping is pinned in both directions.
    test('wireId is snake case and matches the SQL CHECK constraint', () {
      expect(
        AppNoteType.values.map((AppNoteType t) => t.wireId).toList(),
        <String>[
          'general',
          'analysis',
          'plan',
          'review',
          'idea',
          'cheat_sheet',
        ],
      );
    });

    test('fromId round-trips wireId, tolerates enum names and junk', () {
      for (final AppNoteType type in AppNoteType.values) {
        expect(AppNoteType.fromId(type.wireId), type);
        // A client that predates `wireId` stored the raw enum name.
        expect(AppNoteType.fromId(type.name), type);
      }
      expect(AppNoteType.fromId('something_new'), AppNoteType.general);
      expect(AppNoteType.fromId(null), AppNoteType.general);
    });
  });

  group('AppNote.withDerivedCounts', () {
    test('counts words, checklist boxes and flags media', () {
      final AppNote note = _note(
        content:
            '# Plan\n\n'
            '- [x] Marked the level\n'
            '- [ ] Waited for the retest\n'
            '- [X] Sized it down\n\n'
            '![chart](local-image://abc)\n\n'
            '```dart\nvoid main() {}\n```\n',
      ).withDerivedCounts();

      expect(note.checklistTotal, 3);
      expect(note.checklistDone, 2, reason: 'x and X both count as done');
      expect(note.hasChecklist, isTrue);
      expect(note.hasImages, isTrue);
      expect(note.hasCode, isTrue);
      expect(note.wordCount, greaterThan(10));
    });

    test('a plain note has no checklist and no media', () {
      final AppNote note = _note(content: 'Two words').withDerivedCounts();

      expect(note.wordCount, 2);
      expect(note.checklistTotal, 0);
      expect(note.hasChecklist, isFalse);
      expect(note.hasImages, isFalse);
      expect(note.hasCode, isFalse);
    });
  });

  group('AppNote.copyWith', () {
    test('clearStrategy detaches, a bare null leaves the strategy alone', () {
      final AppNote linked = _note().copyWith(
        strategyId: 's1',
        strategyName: 'Opening range',
      );

      expect(linked.copyWith(title: 'Renamed').strategyId, 's1');
      expect(linked.copyWith(clearStrategy: true).strategyId, isNull);
      expect(linked.copyWith(clearStrategy: true).strategyName, isNull);
    });
  });

  group('NotesQuery.apply', () {
    final List<AppNote> notes = <AppNote>[
      _note(
        id: 'a',
        title: 'Breakout plan',
        content: 'Waiting on the daily close',
        type: AppNoteType.plan,
        tags: <String>['setup', 'momentum'],
        tickers: <String>['NIFTY'],
        wordCount: 120,
        daysAgo: 1,
      ),
      _note(
        id: 'b',
        title: 'Weekly review',
        content: 'Overtraded on Wednesday',
        type: AppNoteType.review,
        tags: <String>['discipline', 'setup'],
        strategyName: 'Opening range',
        wordCount: 400,
        daysAgo: 3,
      ),
      _note(
        id: 'c',
        title: 'ATR cheat sheet',
        content: 'Average true range refresher',
        type: AppNoteType.cheatSheet,
        tags: <String>['reference'],
        wordCount: 40,
        daysAgo: 10,
      ),
    ];

    List<String> ids(List<AppNote> result) =>
        result.map((AppNote n) => n.id).toList();

    test('an empty query keeps everything, newest edit first', () {
      expect(ids(NotesQuery.apply(notes)), <String>['a', 'b', 'c']);
    });

    test('search reaches the body, tags, tickers and strategy name', () {
      expect(ids(NotesQuery.apply(notes, query: 'breakout')), <String>['a']);
      expect(
        ids(NotesQuery.apply(notes, query: 'overtraded')),
        <String>['b'],
        reason: 'the phrase a reader remembers is usually inside the note',
      );
      expect(ids(NotesQuery.apply(notes, query: 'nifty')), <String>['a']);
      expect(ids(NotesQuery.apply(notes, query: 'opening range')), <String>[
        'b',
      ]);
      expect(ids(NotesQuery.apply(notes, query: 'setup')), <String>['a', 'b']);
      expect(
        NotesQuery.apply(notes, query: '   '),
        hasLength(3),
        reason: 'whitespace is not a filter',
      );
      expect(NotesQuery.apply(notes, query: 'nothing here'), isEmpty);
    });

    test('type and tag filters stack with the query', () {
      expect(ids(NotesQuery.apply(notes, type: AppNoteType.review)), <String>[
        'b',
      ]);
      expect(ids(NotesQuery.apply(notes, tag: 'setup')), <String>['a', 'b']);
      expect(
        ids(NotesQuery.apply(notes, tag: 'setup', type: AppNoteType.plan)),
        <String>['a'],
      );
      expect(NotesQuery.apply(notes, tag: 'setup', query: 'cheat'), isEmpty);
    });

    test('every sort order', () {
      expect(
        ids(NotesQuery.apply(notes, sort: AppNoteSort.recentlyCreated)),
        <String>['a', 'b', 'c'],
      );
      expect(
        ids(NotesQuery.apply(notes, sort: AppNoteSort.titleAscending)),
        <String>['c', 'a', 'b'],
      );
      expect(
        ids(NotesQuery.apply(notes, sort: AppNoteSort.longestFirst)),
        <String>['b', 'a', 'c'],
      );
    });

    test('tagsOf ranks by use, then alphabetically', () {
      expect(NotesQuery.tagsOf(notes), <String>[
        'setup',
        'discipline',
        'momentum',
        'reference',
      ]);
      expect(NotesQuery.tagsOf(const <AppNote>[]), isEmpty);
    });
  });

  group('NotesRepositoryImpl', () {
    final NotesRepository repo = NotesRepositoryImpl.instance;

    test('create assigns an id, derives counts and lands at the top', () async {
      final List<AppNote> before = await repo.fetchAll();

      final AppNote saved = await repo.create(
        _note(
          id: '',
          title: 'Fresh draft',
          content: 'Note body\n- [ ] follow up',
        ),
      );

      expect(saved.id, isNotEmpty, reason: 'a draft has no id until it saves');
      expect(saved.checklistTotal, 1);
      expect(saved.checklistDone, 0);
      expect(saved.wordCount, 7);

      final List<AppNote> after = await repo.fetchAll();
      expect(after, hasLength(before.length + 1));
      expect(after.first.id, saved.id, reason: 'newest edit sorts first');
      expect(await repo.getById(saved.id), isNotNull);

      await repo.delete(saved.id);
      expect(await repo.getById(saved.id), isNull);
      expect(await repo.fetchAll(), hasLength(before.length));
    });

    test('update replaces in place and re-derives counts', () async {
      final AppNote saved = await repo.create(_note(id: '', title: 'Editable'));
      final int count = (await repo.fetchAll()).length;

      final AppNote edited = await repo.update(
        saved.copyWith(title: 'Edited', content: '- [x] done\n- [ ] not yet'),
      );

      expect(edited.id, saved.id);
      expect(edited.title, 'Edited');
      expect(edited.checklistTotal, 2);
      expect(edited.checklistDone, 1);
      expect(
        await repo.fetchAll(),
        hasLength(count),
        reason: 'an update must not add a row',
      );
      expect((await repo.getById(saved.id))!.title, 'Edited');

      await repo.delete(saved.id);
    });

    test('watchAll emits immediately, then after every mutation', () async {
      final List<int> sizes = <int>[];
      final StreamSubscription<List<AppNote>> sub = repo.watchAll().listen(
        (List<AppNote> notes) => sizes.add(notes.length),
      );
      addTearDown(sub.cancel);

      // A fresh listener must paint without waiting for a change.
      await _settle();
      expect(sizes, hasLength(1));
      final int seeded = sizes.first;

      final AppNote saved = await repo.create(_note(id: '', title: 'Watched'));
      await _settle();
      expect(sizes.last, seeded + 1);

      await repo.update(saved.copyWith(title: 'Watched twice'));
      await _settle();
      expect(sizes.last, seeded + 1, reason: 'an update is not an insert');

      await repo.delete(saved.id);
      await _settle();
      expect(sizes.last, seeded);
      expect(sizes, hasLength(4));
    });

    test('the snapshot is sorted newest first and unmodifiable', () async {
      final List<AppNote> notes = await repo.fetchAll();

      for (int i = 1; i < notes.length; i++) {
        expect(
          notes[i - 1].updatedAt.isBefore(notes[i].updatedAt),
          isFalse,
          reason: 'note $i broke the newest-first order',
        );
      }
      expect(() => notes.add(_note()), throwsUnsupportedError);
    });

    test(
      'public notes track views, likes, comments, and public discovery',
      () async {
        final AppNote saved = await repo.create(
          _note(id: '', title: 'Shared thesis').copyWith(isPublic: true),
        );

        expect(
          await repo.watchPublic().first,
          contains(predicate<AppNote>((AppNote note) => note.id == saved.id)),
        );

        final AppNote viewed = await repo.recordView(saved.id);
        expect(viewed.viewCount, 1);

        final AppNote liked = await repo.toggleLike(saved.id);
        expect(liked.liked, isTrue);
        expect(liked.likeCount, 1);

        final AppNote commented = await repo.addComment(
          saved.id,
          'Useful setup',
        );
        expect(commented.comments.single.body, 'Useful setup');

        final AppNote unliked = await repo.toggleLike(saved.id);
        expect(unliked.liked, isFalse);
        expect(unliked.likeCount, 0);

        await repo.delete(saved.id);
      },
    );
  });

  group('NotesRepositoryScope', () {
    tearDown(() => NotesRepositoryScope.override(null));

    test('override swaps the implementation, null restores the demo', () {
      expect(NotesRepositoryScope.repository, NotesRepositoryImpl.instance);

      final _StubNotesRepository stub = _StubNotesRepository();
      NotesRepositoryScope.override(stub);
      expect(NotesRepositoryScope.repository, same(stub));

      NotesRepositoryScope.override(null);
      expect(NotesRepositoryScope.repository, NotesRepositoryImpl.instance);
    });
  });
}

/// Stands in for the Supabase implementation the backend will drop in: proof
/// that [NotesRepository] is the only seam a replacement has to satisfy.
class _StubNotesRepository implements NotesRepository {
  @override
  Stream<List<AppNote>> watchAll() => const Stream<List<AppNote>>.empty();

  @override
  Stream<List<AppNote>> watchPublic() => const Stream<List<AppNote>>.empty();

  @override
  Future<List<AppNote>> fetchAll() async => const <AppNote>[];

  @override
  Future<AppNote?> getById(String id) async => null;

  @override
  Future<AppNote> create(AppNote draft) async => draft;

  @override
  Future<AppNote> update(AppNote note) async => note;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<AppNote> recordView(String id) async => throw UnimplementedError();

  @override
  Future<AppNote> toggleLike(String id) async => throw UnimplementedError();

  @override
  Future<AppNote> addComment(String id, String body) async =>
      throw UnimplementedError();

  @override
  Future<String> uploadAttachment(String noteId, File file) async => file.path;

  @override
  Future<String> resolveAttachmentUrl(String ref) async => ref;
}
