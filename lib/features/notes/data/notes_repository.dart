import 'dart:async';
import 'dart:io';

import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/features/linking/entity_ticker_links_repository.dart';

/// Everything the notes feature needs from storage.
///
/// Backend hand-off: implement this interface against Supabase (`trader_notes`
/// + the `note-attachments` bucket) and swap the one line in
/// [NotesRepositoryScope.repository]. No widget constructs an implementation
/// itself, so nothing above this file changes.
abstract class NotesRepository {
  /// Emits the full note list, newest edit first, and re-emits after every
  /// mutation. The list screen listens rather than polling so an edit made in
  /// the editor is reflected the moment the reader navigates back.
  Stream<List<AppNote>> watchAll();

  Stream<List<AppNote>> watchPublic();

  Future<List<AppNote>> fetchAll();

  Future<AppNote?> getById(String id);

  Future<AppNote> create(AppNote draft);

  Future<AppNote> update(AppNote note);

  Future<void> delete(String id);

  Future<AppNote> recordView(String id);

  Future<AppNote> toggleLike(String id);

  Future<AppNote> toggleFavorite(String id);

  Future<AppNote> setVisibility(String id, bool isPublic);

  Future<AppNote> addComment(String id, String body);

  /// Stores an attachment and returns the storage reference to embed in the
  /// markdown body (`![alt](ref)`).
  Future<String> uploadAttachment(String noteId, File file);

  /// Turns a stored reference back into something the preview can load. Local
  /// file paths come back unchanged; a Supabase implementation returns a signed
  /// URL here.
  Future<String> resolveAttachmentUrl(String ref);
}

/// In-memory implementation backed by [DemoDataSource].
///
/// Seeded once on first read, then mutated in place, so a note created in one
/// screen is visible in every other for the lifetime of the process.
class NotesRepositoryImpl implements NotesRepository {
  NotesRepositoryImpl._();

  /// Shared so the list, the editor and the preview all observe the same notes.
  static final NotesRepositoryImpl instance = NotesRepositoryImpl._();

  final List<AppNote> _notes = <AppNote>[];
  final StreamController<List<AppNote>> _changes =
      StreamController<List<AppNote>>.broadcast();
  bool _seeded = false;
  int _nextId = 0;

  void _seed() {
    if (_seeded) return;
    _seeded = true;
    _notes.addAll(DemoDataSource.instance.notes());
    _nextId = _notes.length;
    for (final AppNote n in _notes) {
      final Set<String> tickers = <String>{
        ...n.linkedTickers,
        ...EntityTickerLinksRepository.extractTickers(n.content),
      };
      if (tickers.isNotEmpty) {
        EntityTickerLinksRepository.instance.recordLinks(
          entityType: 'note',
          entityId: n.id,
          tickers: tickers,
        );
      }
    }
  }

  List<AppNote> _snapshot() {
    final List<AppNote> copy = List<AppNote>.of(_notes)
      ..sort((AppNote a, AppNote b) => b.updatedAt.compareTo(a.updatedAt));
    return List<AppNote>.unmodifiable(copy);
  }

  void _publish() {
    if (!_changes.isClosed) _changes.add(_snapshot());
  }

  @override
  Stream<List<AppNote>> watchAll() {
    _seed();
    // Seeded value first so a fresh listener paints immediately instead of
    // sitting on a spinner until the next mutation.
    return Stream<List<AppNote>>.multi((
      MultiStreamController<List<AppNote>> controller,
    ) {
      controller.add(_snapshot());
      final StreamSubscription<List<AppNote>> sub = _changes.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Stream<List<AppNote>> watchPublic() => watchAll().map(
    (List<AppNote> notes) =>
        notes.where((AppNote note) => note.isPublic).toList(growable: false),
  );

  @override
  Future<List<AppNote>> fetchAll() async {
    _seed();
    return _snapshot();
  }

  @override
  Future<AppNote?> getById(String id) async {
    _seed();
    for (final AppNote note in _notes) {
      if (note.id == id) return note;
    }
    return null;
  }

  @override
  Future<AppNote> create(AppNote draft) async {
    _seed();
    final DateTime now = DateTime.now();
    final AppNote saved = draft
        .copyWith(
          id: draft.id.isEmpty
              ? 'note_new_${(++_nextId).toString().padLeft(3, '0')}'
              : draft.id,
          createdAt: now,
          updatedAt: now,
        )
        .withDerivedCounts();
    _notes.insert(0, saved);
    _publish();

    final Set<String> tickers = <String>{
      ...saved.linkedTickers,
      ...EntityTickerLinksRepository.extractTickers(saved.content),
    };
    if (tickers.isNotEmpty) {
      unawaited(
        EntityTickerLinksRepository.instance.recordLinks(
          entityType: 'note',
          entityId: saved.id,
          tickers: tickers,
          contextSource: saved.linkedTickers.isNotEmpty ? 'manual' : 'inline',
        ),
      );
    } else {
      unawaited(
        EntityTickerLinksRepository.instance.removeLinks(
          entityType: 'note',
          entityId: saved.id,
        ),
      );
    }

    return saved;
  }

  @override
  Future<AppNote> update(AppNote note) async {
    _seed();
    final AppNote saved = note
        .copyWith(updatedAt: DateTime.now())
        .withDerivedCounts();
    final int at = _notes.indexWhere((AppNote n) => n.id == note.id);
    if (at == -1) {
      _notes.insert(0, saved);
    } else {
      _notes[at] = saved;
    }
    _publish();

    final Set<String> tickers = <String>{
      ...saved.linkedTickers,
      ...EntityTickerLinksRepository.extractTickers(saved.content),
    };
    if (tickers.isNotEmpty) {
      unawaited(
        EntityTickerLinksRepository.instance.recordLinks(
          entityType: 'note',
          entityId: saved.id,
          tickers: tickers,
          contextSource: saved.linkedTickers.isNotEmpty ? 'manual' : 'inline',
        ),
      );
    } else {
      unawaited(
        EntityTickerLinksRepository.instance.removeLinks(
          entityType: 'note',
          entityId: saved.id,
        ),
      );
    }

    return saved;
  }

  @override
  Future<void> delete(String id) async {
    _seed();
    _notes.removeWhere((AppNote n) => n.id == id);
    _publish();
    unawaited(
      EntityTickerLinksRepository.instance.removeLinks(
        entityType: 'note',
        entityId: id,
      ),
    );
  }

  AppNote _mutate(String id, AppNote Function(AppNote note) change) {
    final int index = _notes.indexWhere((AppNote note) => note.id == id);
    if (index < 0) throw StateError('Note not found: $id');
    final AppNote updated = change(_notes[index]);
    _notes[index] = updated;
    _publish();
    return updated;
  }

  @override
  Future<AppNote> recordView(String id) async => _mutate(
    id,
    (AppNote note) =>
        note.isPublic ? note.copyWith(viewCount: note.viewCount + 1) : note,
  );

  @override
  Future<AppNote> toggleLike(String id) async => _mutate(id, (AppNote note) {
    if (!note.isPublic) return note;
    return note.copyWith(
      liked: !note.liked,
      likeCount: (note.likeCount + (note.liked ? -1 : 1)).clamp(0, 1 << 30),
    );
  });

  @override
  Future<AppNote> toggleFavorite(String id) async =>
      _mutate(id, (AppNote note) => note.copyWith(isFavorite: !note.isFavorite));

  @override
  Future<AppNote> setVisibility(String id, bool isPublic) async =>
      _mutate(id, (AppNote note) => note.copyWith(isPublic: isPublic));

  @override
  Future<AppNote> addComment(String id, String body) async =>
      _mutate(id, (AppNote note) {
        final String content = body.trim();
        if (content.isEmpty) return note;
        return note.copyWith(
          comments: <AppNoteComment>[
            ...note.comments,
            AppNoteComment(
              id: 'note_comment_${DateTime.now().microsecondsSinceEpoch}',
              userId: 'current-user',
              authorName: 'You',
              body: content,
              createdAt: DateTime.now(),
            ),
          ],
        );
      });


  @override
  Future<String> uploadAttachment(String noteId, File file) async {
    // Prototype: the picked file already lives in a readable cache directory,
    // so the note embeds its path. A real implementation uploads to the
    // `note-attachments` bucket and returns `<noteId>/<uuid><ext>`.
    return file.path;
  }

  @override
  Future<String> resolveAttachmentUrl(String ref) async => ref;
}

/// The single place a screen reaches the repository.
///
/// Deliberately not a provider framework — TradeX has no Riverpod and no
/// router, so features resolve their dependencies through a static accessor and
/// hold state in `StatefulWidget`s. Tests (and, later, the Supabase wiring)
/// replace the instance through [override].
class NotesRepositoryScope {
  const NotesRepositoryScope._();

  static NotesRepository? _override;

  static NotesRepository get repository =>
      _override ?? NotesRepositoryImpl.instance;

  /// Swap the implementation. Pass `null` to restore the demo repository.
  static void override(NotesRepository? replacement) => _override = replacement;
}

/// Pure functions the list screen uses to turn the full note set into what is
/// on screen. Kept out of the widget so the filtering rules can be unit-tested
/// without pumping a frame.
class NotesQuery {
  const NotesQuery._();

  static List<AppNote> apply(
    List<AppNote> notes, {
    String query = '',
    AppNoteType? type,
    String? tag,
    AppNoteSort sort = AppNoteSort.recentlyUpdated,
  }) {
    final String needle = query.trim().toLowerCase();
    final List<AppNote> out = notes.where((AppNote note) {
      if (type != null && note.noteType != type) return false;
      if (tag != null && !note.tags.contains(tag)) return false;
      if (needle.isEmpty) return true;
      // Body included on purpose: notes are long, and the thing a reader
      // remembers is usually a phrase from inside one, not its title.
      return note.title.toLowerCase().contains(needle) ||
          note.content.toLowerCase().contains(needle) ||
          note.tags.any((String t) => t.toLowerCase().contains(needle)) ||
          note.linkedTickers.any(
            (String t) => t.toLowerCase().contains(needle),
          ) ||
          (note.strategyName ?? '').toLowerCase().contains(needle);
    }).toList();

    out.sort(switch (sort) {
      AppNoteSort.recentlyUpdated =>
        (AppNote a, AppNote b) => b.updatedAt.compareTo(a.updatedAt),
      AppNoteSort.recentlyCreated =>
        (AppNote a, AppNote b) => b.createdAt.compareTo(a.createdAt),
      AppNoteSort.titleAscending =>
        (AppNote a, AppNote b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      AppNoteSort.longestFirst =>
        (AppNote a, AppNote b) => b.wordCount.compareTo(a.wordCount),
    });
    return out;
  }

  /// Every tag in use, most frequent first, for the filter chips.
  static List<String> tagsOf(List<AppNote> notes) {
    final Map<String, int> counts = <String, int>{};
    for (final AppNote note in notes) {
      for (final String tag in note.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final List<String> tags = counts.keys.toList()
      ..sort((String a, String b) {
        final int byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    return tags;
  }
}
