import 'dart:async';

import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';
import 'package:tradex/features/linking/entity_ticker_links_repository.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/features/strategies/data/strategies_repository.dart';

/// Turns the three feature repositories into one [AppLinkGraph].
///
/// Lives in `features/` rather than `core/` on purpose: `core/linking` is a pure
/// function of three lists and must not know that repositories exist. This file
/// is the only place that knows all three, which is also why it is the only
/// place that can answer "what is linked to this" without a screen having to
/// listen to three streams and join them itself.
///
/// No rx: the service holds the latest snapshot of each list and re-emits a
/// rebuilt graph whenever any of them changes. Rebuilding is cheap — it is three
/// map constructions over a few hundred records — and it keeps the invariant
/// that a graph is always internally consistent. A graph assembled from a stale
/// note list and a fresh journal would render edges pointing at records the user
/// just deleted.
class AppLinkGraphService {
  AppLinkGraphService({
    NotesRepository? notes,
    JournalRepository? journal,
    StrategiesRepository? strategies,
    List<AppTicker>? tickers,
  }) : _notes = notes ?? NotesRepositoryScope.repository,
       _journal = journal ?? JournalRepositoryScope.repository,
       _strategies = strategies ?? StrategiesRepositoryScope.repository,
       // Tickers are reference data, not user records: the watchlist is a market
       // feed, so the graph takes a snapshot rather than subscribing.
       _tickers = tickers ?? DemoDataSource.instance.tickers();

  /// The app-wide instance. Screens read [current] for a synchronous answer and
  /// [watch] when they need to rebuild on change.
  static final AppLinkGraphService instance = AppLinkGraphService();

  final NotesRepository _notes;
  final JournalRepository _journal;
  final StrategiesRepository _strategies;
  final List<AppTicker> _tickers;

  final StreamController<AppLinkGraph> _out =
      StreamController<AppLinkGraph>.broadcast();

  List<AppNote> _noteList = const <AppNote>[];
  List<AppTrade> _journalList = const <AppTrade>[];
  List<AppStrategy> _strategyList = const <AppStrategy>[];

  StreamSubscription<List<AppNote>>? _noteSub;
  StreamSubscription<List<AppTrade>>? _journalSub;
  StreamSubscription<List<AppStrategy>>? _strategySub;

  AppLinkGraph _graph = AppLinkGraph.empty;
  bool _listening = false;

  /// The latest graph. Safe to read during `build`.
  AppLinkGraph get current {
    _listen();
    return _graph;
  }

  /// Emits the current graph immediately, then again on every change to any of
  /// the three sources.
  Stream<AppLinkGraph> watch() {
    _listen();
    return Stream<AppLinkGraph>.multi((
      MultiStreamController<AppLinkGraph> controller,
    ) {
      controller.add(_graph);
      final StreamSubscription<AppLinkGraph> sub = _out.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = sub.cancel;
    });
  }

  void _listen() {
    if (_listening) return;
    _listening = true;
    // Subscribed once for the life of the process. Each repository's stream
    // replays its current value to a new listener, so the first three events
    // arrive synchronously enough that the graph is populated before the first
    // frame that reads it.
    _noteSub = _notes.watchAll().listen((List<AppNote> items) {
      _noteList = items;
      _rebuild();
    });
    _journalSub = _journal.watchAll().listen((List<AppTrade> items) {
      _journalList = items;
      _rebuild();
    });
    _strategySub = _strategies.watchAll().listen((List<AppStrategy> items) {
      _strategyList = items;
      _rebuild();
    });
  }

  void _rebuild() {
    _graph = AppLinkGraph(
      notes: _noteList,
      journal: _journalList,
      strategies: _strategyList,
      tickers: _tickers,
    );
    if (!_out.isClosed) _out.add(_graph);
  }

  /// Writes an edge from both ends, so the link survives either side failing to
  /// save. See the note at the top of `core/linking/link_graph.dart`: the
  /// redundancy is the design, not an oversight.
  Future<void> link({
    required AppLinkKind fromKind,
    required String fromId,
    required AppLinkKind toKind,
    required String toId,
  }) => _edge(fromKind, fromId, toKind, toId, attach: true);

  /// Removes an edge from both ends.
  Future<void> unlink({
    required AppLinkKind fromKind,
    required String fromId,
    required AppLinkKind toKind,
    required String toId,
  }) => _edge(fromKind, fromId, toKind, toId, attach: false);

  Future<void> _edge(
    AppLinkKind fromKind,
    String fromId,
    AppLinkKind toKind,
    String toId, {
    required bool attach,
  }) async {
    // Normalised so `link(note→journal)` and `link(journal→note)` are one
    // operation. Twelve directional cases collapse to four pairs.
    final Set<AppLinkKind> pair = <AppLinkKind>{fromKind, toKind};

    if (pair.containsAll(<AppLinkKind>{AppLinkKind.note, AppLinkKind.journal})) {
      final String noteId = fromKind == AppLinkKind.note ? fromId : toId;
      final String entryId = fromKind == AppLinkKind.journal ? fromId : toId;
      await _noteJournal(noteId, entryId, attach: attach);
      return;
    }
    if (pair.containsAll(<AppLinkKind>{
      AppLinkKind.note,
      AppLinkKind.strategy,
    })) {
      final String noteId = fromKind == AppLinkKind.note ? fromId : toId;
      final String strategyId = fromKind == AppLinkKind.strategy ? fromId : toId;
      await _noteStrategy(noteId, strategyId, attach: attach);
      return;
    }
    if (pair.containsAll(<AppLinkKind>{
      AppLinkKind.journal,
      AppLinkKind.strategy,
    })) {
      final String entryId = fromKind == AppLinkKind.journal ? fromId : toId;
      final String strategyId = fromKind == AppLinkKind.strategy ? fromId : toId;
      await _journalStrategy(entryId, strategyId, attach: attach);
      return;
    }
    if (pair.contains(AppLinkKind.ticker)) {
      final String symbol =
          (fromKind == AppLinkKind.ticker ? fromId : toId).toUpperCase();
      final AppLinkKind ownerKind = fromKind == AppLinkKind.ticker
          ? toKind
          : fromKind;
      final String ownerId = fromKind == AppLinkKind.ticker ? toId : fromId;
      await _ticker(ownerKind, ownerId, symbol, attach: attach);
      return;
    }
    // note↔note and the other same-kind pairs are not edges TradeX stores;
    // related notes are derived from shared tags instead.
  }

  Future<void> _noteJournal(
    String noteId,
    String entryId, {
    required bool attach,
  }) async {
    final AppNote? note = await _notes.getById(noteId);
    if (note != null) {
      final List<String> ids = attach
          ? <String>{...note.linkedJournalIds, entryId}.toList(growable: false)
          : note.linkedJournalIds
                .where((String id) => id != entryId)
                .toList(growable: false);
      await _notes.update(note.copyWith(linkedJournalIds: ids));
    }
    if (attach) {
      await _journal.linkNote(entryId, noteId);
    } else {
      await _journal.unlinkNote(entryId, noteId);
    }
  }

  Future<void> _noteStrategy(
    String noteId,
    String strategyId, {
    required bool attach,
  }) async {
    final AppStrategy? strategy = await _strategies.getById(strategyId);
    final AppNote? note = await _notes.getById(noteId);
    if (note != null) {
      await _notes.update(
        attach
            ? note.copyWith(
                strategyId: strategyId,
                strategyName: strategy?.name,
              )
            : note.copyWith(clearStrategy: true),
      );
    }
    if (attach) {
      await _strategies.linkNote(strategyId, noteId);
    } else {
      await _strategies.unlinkNote(strategyId, noteId);
    }
  }

  Future<void> _journalStrategy(
    String entryId,
    String strategyId, {
    required bool attach,
  }) async {
    final AppStrategy? strategy = await _strategies.getById(strategyId);
    await _journal.attachStrategy(
      entryId,
      attach ? strategyId : null,
      strategyName: attach ? strategy?.name : null,
    );
    if (attach) {
      await _strategies.linkJournal(strategyId, entryId);
    } else {
      await _strategies.unlinkJournal(strategyId, entryId);
    }
  }

  Future<void> _ticker(
    AppLinkKind ownerKind,
    String ownerId,
    String symbol, {
    required bool attach,
  }) async {
    switch (ownerKind) {
      case AppLinkKind.note:
        final AppNote? note = await _notes.getById(ownerId);
        if (note == null) return;
        await _notes.update(
          note.copyWith(
            linkedTickers: _withSymbol(note.linkedTickers, symbol, attach),
          ),
        );
      case AppLinkKind.strategy:
        final AppStrategy? s = await _strategies.getById(ownerId);
        if (s == null) return;
        await _strategies.update(
          s.copyWith(
            linkedTickers: _withSymbol(s.linkedTickers, symbol, attach),
          ),
        );
      case AppLinkKind.journal:
      // A journal entry's instrument is the trade's own ticker, not a link the
      // trader adds or removes. Changing it means editing the trade.
      case AppLinkKind.ticker:
      case AppLinkKind.aiCopilot:
        return;
      case AppLinkKind.communityPost:
        if (attach) {
          await EntityTickerLinksRepository.instance.recordLinks(
            entityType: 'community_post',
            entityId: ownerId,
            tickers: <String>[symbol],
            contextSource: 'manual',
          );
        } else {
          await EntityTickerLinksRepository.instance.removeLinks(
            entityType: 'community_post',
            entityId: ownerId,
            ticker: symbol,
          );
        }
      case AppLinkKind.messageThread:
        if (attach) {
          await EntityTickerLinksRepository.instance.recordLinks(
            entityType: 'message',
            entityId: ownerId,
            tickers: <String>[symbol],
            contextSource: 'manual',
          );
        } else {
          await EntityTickerLinksRepository.instance.removeLinks(
            entityType: 'message',
            entityId: ownerId,
            ticker: symbol,
          );
        }
    }
  }

  static List<String> _withSymbol(
    List<String> current,
    String symbol,
    bool attach,
  ) => attach
      ? <String>{
          ...current.map((String s) => s.toUpperCase()),
          symbol,
        }.toList(growable: false)
      : current
            .where((String s) => s.toUpperCase() != symbol)
            .toList(growable: false);

  /// Only used by tests; the app-wide instance lives for the whole process.
  Future<void> dispose() async {
    await _noteSub?.cancel();
    await _journalSub?.cancel();
    await _strategySub?.cancel();
    _listening = false;
    await _out.close();
  }
}

/// The single place a screen reaches the link graph.
class AppLinkGraphScope {
  const AppLinkGraphScope._();

  static AppLinkGraphService? _override;

  static AppLinkGraphService get service =>
      _override ?? AppLinkGraphService.instance;

  static void override(AppLinkGraphService? replacement) =>
      _override = replacement;
}
