import 'dart:async';
import 'dart:io';

import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';

/// Everything the strategies feature needs from storage.
///
/// A strategy is a **playbook**: the markdown that says what the setup is, when
/// it is valid, where the stop goes and when to stand aside. The performance
/// numbers on it are derived from the journal entries filed under it, never
/// entered by hand — a playbook that claims a 68% win rate no trade supports is
/// worse than one with no numbers at all.
///
/// Version history is first-class for the same reason: a rule changed after a
/// bad week is the single most useful thing to be able to read back, and a
/// playbook that silently overwrites itself cannot answer "what was I actually
/// following in March".
///
/// Backend hand-off: implement against Supabase (`strategies`,
/// `strategy_versions`, `note_strategy_links`) and swap the one line in
/// [StrategiesRepositoryScope.repository].
abstract class StrategiesRepository {
  /// Emits every playbook the trader owns, last edited first, re-emitting after
  /// each mutation.
  Stream<List<AppStrategy>> watchAll();

  /// The subset shared to the community feed.
  Stream<List<AppStrategy>> watchPublic();

  Future<List<AppStrategy>> fetchAll();

  Future<AppStrategy?> getById(String id);

  Future<AppStrategy> create(AppStrategy draft);

  /// Saves the playbook. Pass [versionNote] to cut a new revision at the same
  /// time — that is what the editor's "Save version" does.
  Future<AppStrategy> update(AppStrategy strategy, {String? versionNote});

  Future<void> delete(String id);

  Future<AppStrategy> toggleFavorite(String id);

  Future<AppStrategy> setStatus(String id, AppStrategyStatus status);

  Future<AppStrategy> setVisibility(String id, bool isPublic);

  /// Revisions newest first. The first entry is always the live playbook.
  Future<List<AppStrategyVersion>> versions(String strategyId);

  /// Snapshots the current body as a new revision.
  Future<AppStrategyVersion> saveVersion(String strategyId, {String? note});

  /// Copies an old revision's body back onto the live playbook, cutting a new
  /// revision as it goes. Restoring never deletes history: the revision the
  /// trader restored *from* is still there, and so is the one they replaced.
  Future<AppStrategy> restoreVersion(String strategyId, String versionId);

  Future<AppStrategy> linkNote(String strategyId, String noteId);

  Future<AppStrategy> unlinkNote(String strategyId, String noteId);

  Future<AppStrategy> linkJournal(String strategyId, String entryId);

  Future<AppStrategy> unlinkJournal(String strategyId, String entryId);

  /// Stores a diagram, chart or reference document against [strategyId] and
  /// returns the opaque reference the markdown body embeds.
  ///
  /// A playbook's own bucket, not the notes one: a shared playbook's images have
  /// to travel with it when it is published to the community feed, and a private
  /// research note's images must not. Backend hand-off: upload to
  /// `strategy-attachments/<strategyId>/<uuid><ext>` and return that path.
  Future<String> uploadAttachment(String strategyId, File file);

  /// Turns a stored reference back into something the preview can load. Local
  /// paths come back unchanged; a Supabase implementation returns a signed URL.
  Future<String> resolveAttachmentUrl(String ref);
}

/// In-memory implementation backed by [DemoDataSource].
class StrategiesRepositoryImpl implements StrategiesRepository {
  StrategiesRepositoryImpl._();

  static final StrategiesRepositoryImpl instance = StrategiesRepositoryImpl._();

  final List<AppStrategy> _strategies = <AppStrategy>[];
  final Map<String, List<AppStrategyVersion>> _versions =
      <String, List<AppStrategyVersion>>{};
  final StreamController<List<AppStrategy>> _changes =
      StreamController<List<AppStrategy>>.broadcast();
  bool _seeded = false;
  int _nextId = 0;

  void _seed() {
    if (_seeded) return;
    _seeded = true;
    final DemoDataSource demo = DemoDataSource.instance;
    _strategies.addAll(demo.strategies());
    for (final AppStrategy s in _strategies) {
      _versions[s.id] = List<AppStrategyVersion>.of(demo.strategyVersions(s.id));
    }
    _nextId = _strategies.length;
  }

  List<AppStrategy> _snapshot() {
    final List<AppStrategy> copy = List<AppStrategy>.of(_strategies)
      ..sort((AppStrategy a, AppStrategy b) => _editedAt(b).compareTo(_editedAt(a)));
    return List<AppStrategy>.unmodifiable(copy);
  }

  static DateTime _editedAt(AppStrategy s) =>
      s.updatedAt ?? s.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  void _publish() {
    if (!_changes.isClosed) _changes.add(_snapshot());
  }

  @override
  Stream<List<AppStrategy>> watchAll() {
    _seed();
    return Stream<List<AppStrategy>>.multi((
      MultiStreamController<List<AppStrategy>> controller,
    ) {
      controller.add(_snapshot());
      final StreamSubscription<List<AppStrategy>> sub = _changes.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Stream<List<AppStrategy>> watchPublic() => watchAll().map(
    (List<AppStrategy> items) =>
        items.where((AppStrategy s) => s.isPublic).toList(growable: false),
  );

  @override
  Future<List<AppStrategy>> fetchAll() async {
    _seed();
    return _snapshot();
  }

  @override
  Future<AppStrategy?> getById(String id) async {
    _seed();
    for (final AppStrategy s in _strategies) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Future<AppStrategy> create(AppStrategy draft) async {
    _seed();
    final DateTime now = DateTime.now();
    final String id = draft.id.isEmpty
        ? 'stg_new_${(++_nextId).toString().padLeft(3, '0')}'
        : draft.id;
    final AppStrategy saved = draft
        .copyWith(id: id, createdAt: now, updatedAt: now)
        .withDerivedCounts();
    _strategies.insert(0, saved);
    _versions[id] = <AppStrategyVersion>[
      _versionOf(saved, 1, isCurrent: true, note: 'Created'),
    ];
    _publish();
    return saved;
  }

  @override
  Future<AppStrategy> update(
    AppStrategy strategy, {
    String? versionNote,
  }) async {
    _seed();
    final AppStrategy saved = strategy
        .copyWith(updatedAt: DateTime.now())
        .withDerivedCounts();
    final int at = _strategies.indexWhere((AppStrategy s) => s.id == saved.id);
    if (at == -1) {
      _strategies.insert(0, saved);
    } else {
      _strategies[at] = saved;
    }
    final List<AppStrategyVersion> history =
        _versions[saved.id] ??= <AppStrategyVersion>[];
    if (versionNote != null) {
      _cutVersion(saved, note: versionNote);
    } else if (history.isNotEmpty) {
      // No changelog line: the live revision tracks the body rather than
      // spawning a revision per keystroke.
      history[0] = history[0].copyWith(
        content: saved.content,
        summary: saved.summary,
        wordCount: saved.wordCount,
        savedAt: saved.updatedAt ?? DateTime.now(),
      );
    }
    final AppStrategy withCount = saved.copyWith(
      versionCount: (_versions[saved.id] ?? const <AppStrategyVersion>[]).length,
    );
    final int again = _strategies.indexWhere((AppStrategy s) => s.id == saved.id);
    if (again >= 0) _strategies[again] = withCount;
    _publish();
    return withCount;
  }

  @override
  Future<void> delete(String id) async {
    _seed();
    _strategies.removeWhere((AppStrategy s) => s.id == id);
    _versions.remove(id);
    _publish();
  }

  AppStrategy _mutate(String id, AppStrategy Function(AppStrategy s) change) {
    _seed();
    final int at = _strategies.indexWhere((AppStrategy s) => s.id == id);
    if (at < 0) throw StateError('Strategy not found: $id');
    final AppStrategy updated = change(
      _strategies[at],
    ).copyWith(updatedAt: DateTime.now());
    _strategies[at] = updated;
    _publish();
    return updated;
  }

  @override
  Future<AppStrategy> toggleFavorite(String id) async =>
      _mutate(id, (AppStrategy s) => s.copyWith(isFavorite: !s.isFavorite));

  @override
  Future<AppStrategy> setStatus(String id, AppStrategyStatus status) async =>
      _mutate(id, (AppStrategy s) => s.copyWith(status: status));

  @override
  Future<AppStrategy> setVisibility(String id, bool isPublic) async =>
      _mutate(id, (AppStrategy s) => s.copyWith(isPublic: isPublic));

  @override
  Future<List<AppStrategyVersion>> versions(String strategyId) async {
    _seed();
    final List<AppStrategyVersion> history =
        _versions[strategyId] ?? const <AppStrategyVersion>[];
    final List<AppStrategyVersion> copy = List<AppStrategyVersion>.of(history)
      ..sort(
        (AppStrategyVersion a, AppStrategyVersion b) =>
            b.version.compareTo(a.version),
      );
    return List<AppStrategyVersion>.unmodifiable(copy);
  }

  @override
  Future<AppStrategyVersion> saveVersion(
    String strategyId, {
    String? note,
  }) async {
    _seed();
    final AppStrategy? s = await getById(strategyId);
    if (s == null) throw StateError('Strategy not found: $strategyId');
    final AppStrategyVersion cut = _cutVersion(s, note: note);
    _mutate(
      strategyId,
      (AppStrategy current) =>
          current.copyWith(versionCount: _versions[strategyId]!.length),
    );
    return cut;
  }

  /// Pushes a new current revision and demotes the previous one.
  AppStrategyVersion _cutVersion(AppStrategy s, {String? note}) {
    final List<AppStrategyVersion> history =
        _versions[s.id] ??= <AppStrategyVersion>[];
    final int next = history.fold<int>(
          0,
          (int max, AppStrategyVersion v) => v.version > max ? v.version : max,
        ) +
        1;
    for (int i = 0; i < history.length; i++) {
      if (history[i].isCurrent) {
        history[i] = history[i].copyWith(isCurrent: false);
      }
    }
    final AppStrategyVersion cut = _versionOf(
      s,
      next,
      isCurrent: true,
      note: note,
    );
    history.insert(0, cut);
    return cut;
  }

  static AppStrategyVersion _versionOf(
    AppStrategy s,
    int version, {
    required bool isCurrent,
    String? note,
  }) => AppStrategyVersion(
    id: '${s.id}_v$version',
    version: version,
    savedAt: DateTime.now(),
    author: 'You',
    note: note,
    isCurrent: isCurrent,
    strategyId: s.id,
    content: s.content,
    summary: s.summary,
    wordCount: AppMarkdownStats.of(s.content).wordCount,
  );

  @override
  Future<AppStrategy> restoreVersion(
    String strategyId,
    String versionId,
  ) async {
    _seed();
    final List<AppStrategyVersion> history =
        _versions[strategyId] ?? const <AppStrategyVersion>[];
    AppStrategyVersion? target;
    for (final AppStrategyVersion v in history) {
      if (v.id == versionId) {
        target = v;
        break;
      }
    }
    if (target == null) throw StateError('Version not found: $versionId');
    final String body = target.content;
    final String label = target.label;
    final AppStrategy restored = _mutate(
      strategyId,
      (AppStrategy s) => s.copyWith(content: body).withDerivedCounts(),
    );
    _cutVersion(restored, note: 'Restored $label');
    return _mutate(
      strategyId,
      (AppStrategy s) => s.copyWith(versionCount: _versions[strategyId]!.length),
    );
  }

  @override
  Future<AppStrategy> linkNote(String strategyId, String noteId) async =>
      _mutate(strategyId, (AppStrategy s) {
        if (s.linkedNoteIds.contains(noteId)) return s;
        return s.copyWith(
          linkedNoteIds: <String>[...s.linkedNoteIds, noteId],
        );
      });

  @override
  Future<AppStrategy> unlinkNote(String strategyId, String noteId) async =>
      _mutate(
        strategyId,
        (AppStrategy s) => s.copyWith(
          linkedNoteIds: s.linkedNoteIds
              .where((String id) => id != noteId)
              .toList(growable: false),
        ),
      );

  @override
  Future<AppStrategy> linkJournal(String strategyId, String entryId) async =>
      _mutate(strategyId, (AppStrategy s) {
        if (s.linkedJournalIds.contains(entryId)) return s;
        return s.copyWith(
          linkedJournalIds: <String>[...s.linkedJournalIds, entryId],
        );
      });

  @override
  Future<AppStrategy> unlinkJournal(String strategyId, String entryId) async =>
      _mutate(
        strategyId,
        (AppStrategy s) => s.copyWith(
          linkedJournalIds: s.linkedJournalIds
              .where((String id) => id != entryId)
              .toList(growable: false),
        ),
      );

  @override
  Future<String> uploadAttachment(String strategyId, File file) async {
    // Prototype: the staged file already lives in a readable directory, so the
    // playbook embeds its path. A real implementation uploads to the
    // `strategy-attachments` bucket and returns `<strategyId>/<uuid><ext>`.
    return file.path;
  }

  @override
  Future<String> resolveAttachmentUrl(String ref) async => ref;
}

/// The single place a screen reaches the strategies repository.
class StrategiesRepositoryScope {
  const StrategiesRepositoryScope._();

  static StrategiesRepository? _override;

  static StrategiesRepository get repository =>
      _override ?? StrategiesRepositoryImpl.instance;

  static void override(StrategiesRepository? replacement) =>
      _override = replacement;
}

/// Pure filtering and sorting for the strategies index.
class StrategiesQuery {
  const StrategiesQuery._();

  static List<AppStrategy> apply(
    List<AppStrategy> items, {
    String query = '',
    AppStrategyStatus? status,
    String? tag,
    String? ticker,
    bool onlyFavorites = false,
    AppStrategySort sort = AppStrategySort.recentlyUpdated,
  }) {
    final String needle = query.trim().toLowerCase();
    final List<AppStrategy> out = items.where((AppStrategy s) {
      if (status != null && s.status != status) return false;
      if (tag != null && !s.tags.contains(tag)) return false;
      if (ticker != null &&
          !s.linkedTickers.any(
            (String t) => t.toUpperCase() == ticker.toUpperCase(),
          )) {
        return false;
      }
      if (onlyFavorites && !s.isFavorite) return false;
      if (needle.isEmpty) return true;
      return s.name.toLowerCase().contains(needle) ||
          (s.summary ?? '').toLowerCase().contains(needle) ||
          s.content.toLowerCase().contains(needle) ||
          s.tags.any((String t) => t.toLowerCase().contains(needle)) ||
          s.linkedTickers.any((String t) => t.toLowerCase().contains(needle));
    }).toList();

    out.sort(switch (sort) {
      AppStrategySort.recentlyUpdated =>
        (AppStrategy a, AppStrategy b) =>
            StrategiesRepositoryImpl._editedAt(
              b,
            ).compareTo(StrategiesRepositoryImpl._editedAt(a)),
      AppStrategySort.bestWinRate =>
        (AppStrategy a, AppStrategy b) => b.winRate.compareTo(a.winRate),
      AppStrategySort.bestNetPnl =>
        (AppStrategy a, AppStrategy b) => b.netPnl.compareTo(a.netPnl),
      AppStrategySort.mostTraded =>
        (AppStrategy a, AppStrategy b) => b.trades.compareTo(a.trades),
      AppStrategySort.nameAscending =>
        (AppStrategy a, AppStrategy b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    });
    return out;
  }

  static List<String> tagsOf(List<AppStrategy> items) {
    final Map<String, int> counts = <String, int>{};
    for (final AppStrategy s in items) {
      for (final String tag in s.tags) {
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

  static List<String> tickersOf(List<AppStrategy> items) {
    final Set<String> symbols = <String>{
      for (final AppStrategy s in items)
        for (final String t in s.linkedTickers) t.toUpperCase(),
    };
    return symbols.toList()..sort();
  }
}
