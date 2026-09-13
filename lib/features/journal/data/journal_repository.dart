import 'dart:async';
import 'dart:io';

import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';

/// Everything the journal feature needs from storage.
///
/// A journal entry is a trade **and** the write-up attached to it. The two are
/// one record on purpose: the numbers without the reasoning are a broker
/// statement, and the reasoning without the numbers is a diary. Splitting them
/// into two tables would let one exist without the other, which is the failure
/// mode this feature exists to prevent.
///
/// Backend hand-off: implement against Supabase (`journal_entries` +
/// `note_journal_links`) and swap the one line in
/// [JournalRepositoryScope.repository]. Nothing above this file changes.
abstract class JournalRepository {
  /// Emits the full journal, newest trade first, and re-emits after every
  /// mutation so an edit made in the editor shows up on the index without the
  /// list screen polling for it.
  Stream<List<AppTrade>> watchAll();

  /// Entries the owner has explicitly allowed a public post to reference.
  Stream<List<AppTrade>> watchPublic();

  Future<List<AppTrade>> fetchAll();

  Future<AppTrade?> getById(String id);

  Future<AppTrade> create(AppTrade draft);

  Future<AppTrade> update(AppTrade entry);

  Future<AppTrade> toggleFavorite(String id);

  Future<AppTrade> setVisibility(String id, bool isPublic);

  Future<void> delete(String id);

  /// Attaches a trader note to [entryId]. Idempotent — linking twice is the
  /// same as linking once, because the caller is usually a picker the trader
  /// can reopen.
  Future<AppTrade> linkNote(String entryId, String noteId);

  Future<AppTrade> unlinkNote(String entryId, String noteId);

  /// Files [entryId] under a playbook, or clears it when [strategyId] is null.
  /// [strategyName] is denormalised onto the entry so a list row can render the
  /// playbook without resolving the graph first.
  Future<AppTrade> attachStrategy(
    String entryId,
    String? strategyId, {
    String? strategyName,
  });

  /// Stores a chart screenshot or document against [entryId] and returns the
  /// opaque reference the markdown body embeds.
  ///
  /// A journal entry's attachments belong to the journal, not to the notes
  /// bucket: a trader who deletes a note must not lose the screenshot that
  /// proves what a trade looked like. Backend hand-off: upload to
  /// `journal-attachments/<entryId>/<uuid><ext>` and return that path.
  Future<String> uploadAttachment(String entryId, File file);

  /// Turns a stored reference back into something the preview can load. Local
  /// paths come back unchanged; a Supabase implementation returns a signed URL.
  Future<String> resolveAttachmentUrl(String ref);
}

/// In-memory implementation backed by [DemoDataSource].
class JournalRepositoryImpl implements JournalRepository {
  JournalRepositoryImpl._();

  /// Shared so the index, the reader and the editor observe one journal.
  static final JournalRepositoryImpl instance = JournalRepositoryImpl._();

  final List<AppTrade> _entries = <AppTrade>[];
  final StreamController<List<AppTrade>> _changes =
      StreamController<List<AppTrade>>.broadcast();
  bool _seeded = false;
  int _nextId = 0;

  void _seed() {
    if (_seeded) return;
    _seeded = true;
    _entries.addAll(DemoDataSource.instance.trades());
    _nextId = _entries.length;
  }

  List<AppTrade> _snapshot() {
    final List<AppTrade> copy = List<AppTrade>.of(_entries)
      ..sort((AppTrade a, AppTrade b) => b.sortDate.compareTo(a.sortDate));
    return List<AppTrade>.unmodifiable(copy);
  }

  void _publish() {
    if (!_changes.isClosed) _changes.add(_snapshot());
  }

  @override
  Stream<List<AppTrade>> watchAll() {
    _seed();
    return Stream<List<AppTrade>>.multi((
      MultiStreamController<List<AppTrade>> controller,
    ) {
      controller.add(_snapshot());
      final StreamSubscription<List<AppTrade>> sub = _changes.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Stream<List<AppTrade>> watchPublic() => watchAll().map(
    (List<AppTrade> entries) => entries
        .where((AppTrade entry) => entry.isPublic)
        .toList(growable: false),
  );

  @override
  Future<List<AppTrade>> fetchAll() async {
    _seed();
    return _snapshot();
  }

  @override
  Future<AppTrade?> getById(String id) async {
    _seed();
    for (final AppTrade entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  @override
  Future<AppTrade> create(AppTrade draft) async {
    _seed();
    final AppTrade saved = draft
        .copyWith(
          id: draft.id.isEmpty
              ? 'trd_new_${(++_nextId).toString().padLeft(3, '0')}'
              : draft.id,
          updatedAt: DateTime.now(),
        )
        .withDerivedCounts();
    _entries.insert(0, saved);
    _publish();
    return saved;
  }

  @override
  Future<AppTrade> update(AppTrade entry) async {
    _seed();
    final AppTrade saved = entry
        .copyWith(updatedAt: DateTime.now())
        .withDerivedCounts();
    final int at = _entries.indexWhere((AppTrade t) => t.id == entry.id);
    if (at == -1) {
      _entries.insert(0, saved);
    } else {
      _entries[at] = saved;
    }
    _publish();
    return saved;
  }

  @override
  Future<AppTrade> toggleFavorite(String id) async =>
      _mutate(id, (AppTrade entry) => entry.copyWith(isFavorite: !entry.isFavorite));

  @override
  Future<AppTrade> setVisibility(String id, bool isPublic) async =>
      _mutate(id, (AppTrade entry) => entry.copyWith(isPublic: isPublic));

  @override
  Future<void> delete(String id) async {
    _seed();
    _entries.removeWhere((AppTrade t) => t.id == id);
    _publish();
  }

  AppTrade _mutate(String id, AppTrade Function(AppTrade entry) change) {
    _seed();
    final int at = _entries.indexWhere((AppTrade t) => t.id == id);
    if (at < 0) throw StateError('Journal entry not found: $id');
    final AppTrade updated = change(
      _entries[at],
    ).copyWith(updatedAt: DateTime.now());
    _entries[at] = updated;
    _publish();
    return updated;
  }

  @override
  Future<AppTrade> linkNote(String entryId, String noteId) async =>
      _mutate(entryId, (AppTrade entry) {
        if (entry.linkedNoteIds.contains(noteId)) return entry;
        return entry.copyWith(
          linkedNoteIds: <String>[...entry.linkedNoteIds, noteId],
        );
      });

  @override
  Future<AppTrade> unlinkNote(String entryId, String noteId) async =>
      _mutate(entryId, (AppTrade entry) {
        return entry.copyWith(
          linkedNoteIds: entry.linkedNoteIds
              .where((String id) => id != noteId)
              .toList(growable: false),
        );
      });

  @override
  Future<AppTrade> attachStrategy(
    String entryId,
    String? strategyId, {
    String? strategyName,
  }) async => _mutate(entryId, (AppTrade entry) {
    if (strategyId == null || strategyId.isEmpty) {
      return entry.copyWith(clearStrategy: true);
    }
    return entry.copyWith(strategyId: strategyId, strategy: strategyName);
  });

  @override
  Future<String> uploadAttachment(String entryId, File file) async {
    // Prototype: the staged file already lives in a readable directory, so the
    // entry embeds its path. A real implementation uploads to the
    // `journal-attachments` bucket and returns `<entryId>/<uuid><ext>`.
    return file.path;
  }

  @override
  Future<String> resolveAttachmentUrl(String ref) async => ref;
}

/// The single place a screen reaches the journal repository.
class JournalRepositoryScope {
  const JournalRepositoryScope._();

  static JournalRepository? _override;

  static JournalRepository get repository =>
      _override ?? JournalRepositoryImpl.instance;

  /// Swap the implementation. Pass `null` to restore the demo repository.
  static void override(JournalRepository? replacement) =>
      _override = replacement;
}

/// Pure functions the index screen uses to turn the full journal into what is
/// on screen. Kept out of the widget so the rules are testable without pumping
/// a frame.
class JournalQuery {
  const JournalQuery._();

  static List<AppTrade> apply(
    List<AppTrade> entries, {
    String query = '',
    AppOutcome? outcome,
    String? tag,
    String? ticker,
    String? strategyId,
    bool onlyUnwritten = false,
    bool onlyUnfiled = false,
    AppJournalSort sort = AppJournalSort.recentFirst,
  }) {
    final String needle = query.trim().toLowerCase();
    final List<AppTrade> out = entries.where((AppTrade entry) {
      if (outcome != null && entry.outcome != outcome) return false;
      if (tag != null && !entry.tags.contains(tag)) return false;
      if (ticker != null &&
          entry.ticker.toUpperCase() != ticker.toUpperCase()) {
        return false;
      }
      if (strategyId != null && entry.strategyId != strategyId) return false;
      // The two prompts that make the journal useful: what has no write-up, and
      // what was never filed under a plan.
      if (onlyUnwritten && entry.hasStory) return false;
      if (onlyUnfiled &&
          (entry.strategyId != null && entry.strategyId!.isNotEmpty)) {
        return false;
      }
      if (needle.isEmpty) return true;
      // Body included: the thing a trader remembers about an entry three weeks
      // later is a phrase from inside it, not its title.
      return entry.displayTitle.toLowerCase().contains(needle) ||
          entry.ticker.toLowerCase().contains(needle) ||
          entry.content.toLowerCase().contains(needle) ||
          (entry.notes ?? '').toLowerCase().contains(needle) ||
          (entry.strategy ?? '').toLowerCase().contains(needle) ||
          entry.tags.any((String t) => t.toLowerCase().contains(needle));
    }).toList();

    out.sort(switch (sort) {
      AppJournalSort.recentFirst =>
        (AppTrade a, AppTrade b) => b.sortDate.compareTo(a.sortDate),
      AppJournalSort.oldestFirst =>
        (AppTrade a, AppTrade b) => a.sortDate.compareTo(b.sortDate),
      AppJournalSort.biggestWin => (AppTrade a, AppTrade b) => b.pnl.compareTo(
        a.pnl,
      ),
      AppJournalSort.biggestLoss => (AppTrade a, AppTrade b) => a.pnl.compareTo(
        b.pnl,
      ),
      AppJournalSort.bestR =>
        (AppTrade a, AppTrade b) =>
            (b.rMultiple ?? 0).compareTo(a.rMultiple ?? 0),
      AppJournalSort.worstR =>
        (AppTrade a, AppTrade b) =>
            (a.rMultiple ?? 0).compareTo(b.rMultiple ?? 0),
      AppJournalSort.tickerAscending =>
        (AppTrade a, AppTrade b) => a.ticker.compareTo(b.ticker),
    });
    return out;
  }

  /// Every tag in use, most frequent first, for the filter chips.
  static List<String> tagsOf(List<AppTrade> entries) {
    final Map<String, int> counts = <String, int>{};
    for (final AppTrade entry in entries) {
      for (final String tag in entry.tags) {
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

  /// Every instrument traded, most traded first.
  static List<String> tickersOf(List<AppTrade> entries) {
    final Map<String, int> counts = <String, int>{};
    for (final AppTrade entry in entries) {
      final String symbol = entry.ticker.toUpperCase();
      counts[symbol] = (counts[symbol] ?? 0) + 1;
    }
    final List<String> symbols = counts.keys.toList()
      ..sort((String a, String b) {
        final int byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    return symbols;
  }

  /// The headline numbers for whatever slice is on screen. Computed over the
  /// filtered list rather than the whole journal, so the stats answer the
  /// question the trader just asked with the filters.
  static AppJournalStats statsOf(List<AppTrade> entries) {
    final List<AppTrade> closed = entries
        .where((AppTrade t) => !t.isOpen)
        .toList(growable: false);
    final List<AppTrade> wins = closed
        .where((AppTrade t) => t.pnl > 0)
        .toList(growable: false);
    final double net = closed.fold<double>(
      0,
      (double sum, AppTrade t) => sum + t.pnl,
    );
    final Iterable<double> rs = closed
        .where((AppTrade t) => t.rMultiple != null)
        .map((AppTrade t) => t.rMultiple!);
    final int written = entries.where((AppTrade t) => t.hasStory).length;
    return AppJournalStats(
      total: entries.length,
      open: entries.length - closed.length,
      netPnl: net,
      winRate: closed.isEmpty ? 0 : wins.length / closed.length,
      avgR: rs.isEmpty
          ? 0
          : rs.reduce((double a, double b) => a + b) / rs.length,
      written: written,
      unfiled: entries
          .where((AppTrade t) => t.strategyId == null || t.strategyId!.isEmpty)
          .length,
    );
  }
}

/// The summary strip above the journal index.
class AppJournalStats {
  const AppJournalStats({
    this.total = 0,
    this.open = 0,
    this.netPnl = 0,
    this.winRate = 0,
    this.avgR = 0,
    this.written = 0,
    this.unfiled = 0,
  });

  final int total;
  final int open;
  final double netPnl;
  final double winRate;
  final double avgR;

  /// Entries carrying a write-up. The gap between this and [total] is the
  /// prompt the journal leads with.
  final int written;

  /// Entries with no playbook attached.
  final int unfiled;

  double get coverage => total == 0 ? 0 : written / total;

  bool get isEmpty => total == 0;
}
