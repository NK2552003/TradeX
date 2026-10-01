/// The relationship layer between trader notes, journal entries and strategy
/// playbooks.
///
/// TradeX stores every edge on **both** ends: a note lists the journal entries
/// it discusses, and those entries list the note back. That is redundant on
/// purpose. A single-sided edge is one failed write away from disappearing, and
/// a trader who cannot get from a losing trade back to the plan that produced it
/// has a folder of documents, not a journal. This library unions the two
/// directions, so an edge written by either side still resolves — and so a
/// half-migrated backend degrades to "the link still works" instead of "the link
/// is gone".
///
/// Pure by design: it takes three lists and answers questions about them. No
/// repositories, no streams, no `BuildContext`. `AppLinkGraphService` in
/// `lib/features/linking/` owns the live wiring.
library;

import 'package:markdown/markdown.dart' as md;

import '../app-ui/models/app_models.dart';
import '../app-ui/theme/app_tokens.dart';
import '../flutter-ui/components/ui_common.dart';

/// Reads and writes the internal `tradex://` URL space.
///
/// Editors write these into markdown bodies (`[$RELIANCE](tradex://ticker/…)`),
/// so a note's cross-references survive being exported, copied into another note
/// or round-tripped through the backend as plain text. The graph walks parsed
/// Markdown link nodes and resolves their URLs through this shared codec.
class AppDeepLink {
  const AppDeepLink._();

  static const String scheme = 'tradex';

  /// The canonical URL for one record.
  static Uri of(AppLinkKind kind, String id) =>
      Uri(scheme: scheme, host: kind.host, path: '/$id');

  static bool isInternal(Uri uri) => uri.scheme == scheme;

  /// The record a URL points at, or null if this is not a `tradex://` link the
  /// app understands. An unknown host is treated as "not ours" rather than
  /// guessed at, so a future `tradex://watchlist/…` opens nothing instead of
  /// opening the wrong thing.
  static ({AppLinkKind kind, String id})? target(Uri uri) {
    if (!isInternal(uri)) return null;
    final AppLinkKind? kind = AppLinkKind.fromHost(uri.host);
    if (kind == null) return null;
    final String id = uri.pathSegments.isEmpty
        ? ''
        : uri.pathSegments.join('/');
    if (id.trim().isEmpty) return null;
    return (kind: kind, id: id.trim());
  }

  /// Markdown for a link a human will read. The label is what the reader sees,
  /// so it carries the record's own title rather than its id.
  static String markdown({
    required AppLinkKind kind,
    required String id,
    required String label,
  }) =>
      '[${label.replaceAll('\\', r'\\').replaceAll('[', r'\[').replaceAll(']', r'\]')}](${of(kind, id)})';
}

/// A request to open one record, handed from one destination to another.
///
/// The shell has no router, so a link that crosses destinations cannot be a
/// push: the shell swaps which screen is mounted, and that screen then has to be
/// told what to open. [seq] makes two requests for the same record distinct, so
/// following the same link a second time reopens the record instead of being
/// swallowed as "nothing changed".
class AppLinkOpenRequest {
  const AppLinkOpenRequest({
    required this.kind,
    required this.id,
    required this.seq,
    this.editWriting = false,
  });

  final AppLinkKind kind;
  final String id;

  /// Monotonic per shell. Only compared, never interpreted.
  final int seq;

  /// Open the source document in the shared Notes writing workspace.
  final bool editWriting;

  @override
  bool operator ==(Object other) =>
      other is AppLinkOpenRequest &&
      other.kind == kind &&
      other.id == id &&
      other.seq == seq &&
      other.editWriting == editWriting;

  @override
  int get hashCode => Object.hash(kind, id, seq, editWriting);

  @override
  String toString() => 'AppLinkOpenRequest(${kind.host}/$id #$seq)';
}

/// An immutable snapshot of every record and every edge between them.
class AppLinkGraph {
  AppLinkGraph({
    List<AppNote> notes = const <AppNote>[],
    List<AppTrade> journal = const <AppTrade>[],
    List<AppStrategy> strategies = const <AppStrategy>[],
    List<AppTicker> tickers = const <AppTicker>[],
  }) : _notes = <String, AppNote>{for (final AppNote n in notes) n.id: n},
       _journal = <String, AppTrade>{for (final AppTrade t in journal) t.id: t},
       _strategies = <String, AppStrategy>{
         for (final AppStrategy s in strategies) s.id: s,
       },
       _tickers = <String, AppTicker>{
         for (final AppTicker t in tickers) t.symbol.toUpperCase(): t,
       },
       noteList = List<AppNote>.unmodifiable(notes),
       journalList = List<AppTrade>.unmodifiable(journal),
       strategyList = List<AppStrategy>.unmodifiable(strategies);

  static final AppLinkGraph empty = AppLinkGraph();

  final Map<String, AppNote> _notes;
  final Map<String, AppTrade> _journal;
  final Map<String, AppStrategy> _strategies;
  final Map<String, AppTicker> _tickers;

  final List<AppNote> noteList;
  final List<AppTrade> journalList;
  final List<AppStrategy> strategyList;

  bool get isEmpty =>
      noteList.isEmpty && journalList.isEmpty && strategyList.isEmpty;

  // ── Record lookup ──────────────────────────────────────────────────────────

  AppNote? note(String id) => _notes[id];
  AppTrade? entry(String id) => _journal[id];
  AppStrategy? strategy(String id) => _strategies[id];
  AppTicker? ticker(String symbol) => _tickers[symbol.toUpperCase()];

  // ── Refs ───────────────────────────────────────────────────────────────────

  AppLinkRef noteRef(AppNote n) => AppLinkRef(
    kind: AppLinkKind.note,
    id: n.id,
    title: n.title.trim().isEmpty ? 'Untitled note' : n.title.trim(),
    subtitle: n.noteType.label,
    meta: AppTokens.relativeTime(n.updatedAt),
    intent: n.noteType.intent,
    icon: n.noteType.icon,
  );

  AppLinkRef journalRef(AppTrade t) => AppLinkRef(
    kind: AppLinkKind.journal,
    id: t.id,
    title: t.displayTitle,
    subtitle: t.isOpen
        ? 'Open · ${AppTokens.shortDate(t.openedAt)}'
        : '${AppTokens.outcomeLabel(t.outcome)} · ${AppTokens.shortDate(t.sortDate)}',
    meta: t.isOpen ? null : AppTokens.signedMoney(t.pnl),
    intent: t.isOpen ? UiIntent.neutral : AppTokens.plIntent(t.pnl),
    icon: AppLinkKind.journal.icon,
  );

  AppLinkRef strategyRef(AppStrategy s) => AppLinkRef(
    kind: AppLinkKind.strategy,
    id: s.id,
    title: s.name,
    subtitle: '${s.status.label} · ${s.trades} trades',
    meta: s.trades == 0 ? null : AppTokens.percent(s.winRate),
    icon: AppLinkKind.strategy.icon,
  );

  AppLinkRef tickerRef(String symbol) {
    final AppTicker? t = ticker(symbol);
    return AppLinkRef(
      kind: AppLinkKind.ticker,
      id: symbol.toUpperCase(),
      title: symbol.toUpperCase(),
      subtitle: t?.name,
      meta: t == null ? null : AppTokens.signedPercent(t.changePercent),
      intent: t == null ? null : AppTokens.plIntent(t.changePercent),
    );
  }

  /// Resolves one edge. Unresolvable ids come back as [AppLinkRef.missing]
  /// rather than null so callers render the broken edge instead of hiding it.
  AppLinkRef refFor(AppLinkKind kind, String id) {
    switch (kind) {
      case AppLinkKind.note:
        final AppNote? n = note(id);
        return n == null ? AppLinkRef.missing(kind, id) : noteRef(n);
      case AppLinkKind.journal:
        final AppTrade? t = entry(id);
        return t == null ? AppLinkRef.missing(kind, id) : journalRef(t);
      case AppLinkKind.strategy:
        final AppStrategy? s = strategy(id);
        return s == null ? AppLinkRef.missing(kind, id) : strategyRef(s);
      case AppLinkKind.ticker:
        return tickerRef(id);
      case AppLinkKind.aiCopilot:
        return AppLinkRef(
          kind: AppLinkKind.aiCopilot,
          id: id.isNotEmpty ? id : 'ai_copilot',
          title: 'AI Trading Copilot',
          subtitle: 'Quantitative Assistant',
          icon: AppLinkKind.aiCopilot.icon,
          intent: AppLinkKind.aiCopilot.intent,
        );
      case AppLinkKind.communityPost:
        return AppLinkRef(
          kind: AppLinkKind.communityPost,
          id: id,
          title: 'Community Post #$id',
          subtitle: 'Shared Post',
          icon: AppLinkKind.communityPost.icon,
          intent: AppLinkKind.communityPost.intent,
        );
      case AppLinkKind.messageThread:
        return AppLinkRef(
          kind: AppLinkKind.messageThread,
          id: id,
          title: 'Direct Message',
          subtitle: 'Conversation',
          icon: AppLinkKind.messageThread.icon,
          intent: AppLinkKind.messageThread.intent,
        );
    }
  }

  /// Resolves a `tradex://` URL against this snapshot.
  AppLinkRef? resolve(Uri uri) {
    final ({AppLinkKind kind, String id})? t = AppDeepLink.target(uri);
    return t == null ? null : refFor(t.kind, t.id);
  }

  // ── Bundles: everything linked to one record ───────────────────────────────

  /// Notes, journal entries, strategies and tickers attached to [note].
  AppLinkBundle bundleForNote(AppNote note) {
    final bool isPub = note.isPublic;
    final Set<String> journalIds = <String>{
      for (final String id in note.linkedJournalIds)
        if (!isPub || (entry(id)?.isPublic ?? false)) id,
      for (final AppTrade t in journalList)
        if (t.linkedNoteIds.contains(note.id) && (!isPub || t.isPublic)) t.id,
    };
    final Set<String> strategyIds = <String>{
      if (note.strategyId != null && note.strategyId!.isNotEmpty)
        if (!isPub || (strategy(note.strategyId!)?.isPublic ?? false))
          note.strategyId!,
      for (final AppStrategy s in strategyList)
        if (s.linkedNoteIds.contains(note.id) && (!isPub || s.isPublic)) s.id,
    };
    final AppLinkBundle bundle = _withInline(
      AppLinkKind.note,
      note.id,
      AppLinkBundle(
        strategies: <AppLinkRef>[
          for (final String id in strategyIds) refFor(AppLinkKind.strategy, id),
        ],
        journal: _sortedJournal(journalIds),
        tickers: <AppLinkRef>[
          for (final String s in note.linkedTickers) tickerRef(s),
        ],
      ),
    );
    if (!isPub) return bundle;
    return AppLinkBundle(
      strategies: bundle.strategies
          .where((AppLinkRef r) => strategy(r.id)?.isPublic ?? false)
          .toList(growable: false),
      journal: bundle.journal
          .where((AppLinkRef r) => entry(r.id)?.isPublic ?? false)
          .toList(growable: false),
      notes: bundle.notes
          .where((AppLinkRef r) => this.note(r.id)?.isPublic ?? false)
          .toList(growable: false),
      tickers: bundle.tickers,
    );
  }

  /// Notes, strategies and tickers attached to a journal [entry].
  AppLinkBundle bundleForJournal(AppTrade entry) {
    final bool isPub = entry.isPublic;
    final Set<String> noteIds = <String>{
      for (final String id in entry.linkedNoteIds)
        if (!isPub || (note(id)?.isPublic ?? false)) id,
      for (final AppNote n in noteList)
        if (n.linkedJournalIds.contains(entry.id) && (!isPub || n.isPublic)) n.id,
    };
    final Set<String> strategyIds = <String>{
      if (entry.strategyId != null && entry.strategyId!.isNotEmpty)
        if (!isPub || (strategy(entry.strategyId!)?.isPublic ?? false))
          entry.strategyId!,
      for (final AppStrategy s in strategyList)
        if (s.linkedJournalIds.contains(entry.id) && (!isPub || s.isPublic)) s.id,
    };
    final AppLinkBundle bundle = _withInline(
      AppLinkKind.journal,
      entry.id,
      AppLinkBundle(
        strategies: <AppLinkRef>[
          for (final String id in strategyIds) refFor(AppLinkKind.strategy, id),
        ],
        notes: _sortedNotes(noteIds),
        tickers: <AppLinkRef>[tickerRef(entry.ticker)],
      ),
    );
    if (!isPub) return bundle;
    return AppLinkBundle(
      strategies: bundle.strategies
          .where((AppLinkRef r) => strategy(r.id)?.isPublic ?? false)
          .toList(growable: false),
      journal: bundle.journal
          .where((AppLinkRef r) => this.entry(r.id)?.isPublic ?? false)
          .toList(growable: false),
      notes: bundle.notes
          .where((AppLinkRef r) => note(r.id)?.isPublic ?? false)
          .toList(growable: false),
      tickers: bundle.tickers,
    );
  }

  /// Notes, journal entries and tickers attached to [strategy]. Tickers are the
  /// union of the ones the playbook names and the ones its entries were actually
  /// traded on — a playbook written for the index that keeps getting traded on
  /// bank futures is worth seeing.
  AppLinkBundle bundleForStrategy(AppStrategy strategy) {
    final bool isPub = strategy.isPublic;
    final Set<String> noteIds = <String>{
      for (final String id in strategy.linkedNoteIds)
        if (!isPub || (note(id)?.isPublic ?? false)) id,
      for (final AppNote n in noteList)
        if (n.strategyId == strategy.id && (!isPub || n.isPublic)) n.id,
    };
    final Set<String> journalIds = <String>{
      for (final String id in strategy.linkedJournalIds)
        if (!isPub || (entry(id)?.isPublic ?? false)) id,
      for (final AppTrade t in journalList)
        if (t.strategyId == strategy.id && (!isPub || t.isPublic)) t.id,
    };
    final Set<String> symbols = <String>{
      for (final String s in strategy.linkedTickers) s.toUpperCase(),
      for (final String id in journalIds)
        if (entry(id) != null) entry(id)!.ticker.toUpperCase(),
    };
    final AppLinkBundle bundle = _withInline(
      AppLinkKind.strategy,
      strategy.id,
      AppLinkBundle(
        journal: _sortedJournal(journalIds),
        notes: _sortedNotes(noteIds),
        tickers: <AppLinkRef>[for (final String s in symbols) tickerRef(s)],
      ),
    );
    if (!isPub) return bundle;
    return AppLinkBundle(
      strategies: bundle.strategies
          .where((AppLinkRef r) => this.strategy(r.id)?.isPublic ?? false)
          .toList(growable: false),
      journal: bundle.journal
          .where((AppLinkRef r) => entry(r.id)?.isPublic ?? false)
          .toList(growable: false),
      notes: bundle.notes
          .where((AppLinkRef r) => note(r.id)?.isPublic ?? false)
          .toList(growable: false),
      tickers: bundle.tickers,
    );
  }

  /// The bundle for any record, addressed by kind and id.
  AppLinkBundle bundleFor(AppLinkKind kind, String id) => switch (kind) {
    AppLinkKind.note =>
      note(id) == null ? AppLinkBundle.empty : bundleForNote(note(id)!),
    AppLinkKind.journal =>
      entry(id) == null ? AppLinkBundle.empty : bundleForJournal(entry(id)!),
    AppLinkKind.strategy =>
      strategy(id) == null
          ? AppLinkBundle.empty
          : bundleForStrategy(strategy(id)!),
    AppLinkKind.ticker => bundleForTicker(id),
    _ => AppLinkBundle.empty,
  };

  /// Everything that mentions one instrument. Tickers own no record of their
  /// own, so this is derived entirely from the other three.
  AppLinkBundle bundleForTicker(String symbol) {
    final String s = symbol.toUpperCase();
    return _withInline(
      AppLinkKind.ticker,
      symbol.toUpperCase(),
      AppLinkBundle(
        strategies: <AppLinkRef>[
          for (final AppStrategy st in strategyList)
            if (st.linkedTickers.any((String t) => t.toUpperCase() == s))
              strategyRef(st),
        ],
        journal: <AppLinkRef>[
          for (final AppTrade t in journalList)
            if (t.ticker.toUpperCase() == s) journalRef(t),
        ],
        notes: <AppLinkRef>[
          for (final AppNote n in noteList)
            if (n.linkedTickers.any((String t) => t.toUpperCase() == s))
              noteRef(n),
        ],
      ),
    );
  }

  /// Markdown links are durable relationships too. Build one adjacency index
  /// per immutable graph, and expose both outgoing links and automatic backlinks.
  /// The Markdown parser ignores fenced/inline code, so examples create no edges.
  late final Map<(AppLinkKind, String), Set<(AppLinkKind, String)>>
  _inlineEdges = _indexInlineLinks();

  Map<(AppLinkKind, String), Set<(AppLinkKind, String)>> _indexInlineLinks() {
    final edges = <(AppLinkKind, String), Set<(AppLinkKind, String)>>{};
    final documents = <(AppLinkKind, String), String>{
      for (final note in noteList) (AppLinkKind.note, note.id): note.content,
      for (final trade in journalList)
        (AppLinkKind.journal, trade.id): trade.content,
      for (final strategy in strategyList)
        (AppLinkKind.strategy, strategy.id): strategy.content,
    };
    for (final document in documents.entries) {
      void visit(md.Node node) {
        if (node is! md.Element) return;
        if (node.tag == 'a') {
          final uri = Uri.tryParse(node.attributes['href'] ?? '');
          final target = uri == null ? null : AppDeepLink.target(uri);
          if (target != null) {
            final to = (
              target.kind,
              target.kind == AppLinkKind.ticker
                  ? target.id.toUpperCase()
                  : target.id,
            );
            if (to != document.key) {
              edges.putIfAbsent(document.key, () => {}).add(to);
              edges.putIfAbsent(to, () => {}).add(document.key);
            }
          }
        }
        for (final child in node.children ?? <md.Node>[]) {
          visit(child);
        }
      }

      for (final node in md.Document().parseLines(document.value.split('\n'))) {
        visit(node);
      }
    }
    return edges;
  }

  bool hasInlineConnection(
    AppLinkKind from,
    String fromId,
    AppLinkKind to,
    String toId,
  ) => _inlineEdges[(from, fromId)]?.contains((to, toId)) ?? false;

  AppLinkBundle _withInline(AppLinkKind kind, String id, AppLinkBundle base) {
    final refs = <(AppLinkKind, String), AppLinkRef>{
      for (final ref in base.all) (ref.kind, ref.id): ref,
      for (final target
          in _inlineEdges[(kind, id)] ?? <(AppLinkKind, String)>{})
        target: refFor(target.$1, target.$2),
    };
    List<AppLinkRef> group(AppLinkKind kind) =>
        refs.values.where((r) => r.kind == kind).toList();
    return AppLinkBundle(
      notes: group(AppLinkKind.note),
      journal: group(AppLinkKind.journal),
      strategies: group(AppLinkKind.strategy),
      tickers: group(AppLinkKind.ticker),
    );
  }

  // ── Neighbours: same-kind records worth reading next ───────────────────────

  /// Other entries traded under the same playbook, newest first.
  List<AppLinkRef> siblingEntries(AppTrade entry, {int limit = 4}) {
    final String? sid = entry.strategyId;
    if (sid == null || sid.isEmpty) return const <AppLinkRef>[];
    final List<AppTrade> peers =
        journalList
            .where((AppTrade t) => t.id != entry.id && t.strategyId == sid)
            .toList()
          ..sort((AppTrade a, AppTrade b) => b.sortDate.compareTo(a.sortDate));
    return <AppLinkRef>[
      for (final AppTrade t in peers.take(limit)) journalRef(t),
    ];
  }

  /// Notes sharing at least one tag with [note], most overlap first.
  List<AppLinkRef> relatedNotes(AppNote note, {int limit = 4}) {
    if (note.tags.isEmpty) return const <AppLinkRef>[];
    final Set<String> tags = note.tags
        .map((String t) => t.toLowerCase())
        .toSet();
    final List<({AppNote note, int shared})> scored =
        <({AppNote note, int shared})>[
          for (final AppNote n in noteList)
            if (n.id != note.id)
              (
                note: n,
                shared: n.tags
                    .where((String t) => tags.contains(t.toLowerCase()))
                    .length,
              ),
        ]..removeWhere((({AppNote note, int shared}) e) => e.shared == 0);
    scored.sort((
      ({AppNote note, int shared}) a,
      ({AppNote note, int shared}) b,
    ) {
      final int byShared = b.shared.compareTo(a.shared);
      return byShared != 0
          ? byShared
          : b.note.updatedAt.compareTo(a.note.updatedAt);
    });
    return <AppLinkRef>[
      for (final ({AppNote note, int shared}) e in scored.take(limit))
        noteRef(e.note),
    ];
  }

  // ── Pickers ────────────────────────────────────────────────────────────────

  /// Candidate targets for a "link a record" picker, minus what is already
  /// linked. Ordered the way the picker should list them: most recent first.
  List<AppLinkRef> options(
    AppLinkKind kind, {
    Iterable<String> exclude = const <String>[],
    String query = '',
  }) {
    final Set<String> skip = exclude.toSet();
    final String q = query.trim().toLowerCase();
    bool matches(AppLinkRef r) =>
        q.isEmpty ||
        r.title.toLowerCase().contains(q) ||
        (r.subtitle?.toLowerCase().contains(q) ?? false);

    final List<AppLinkRef> refs = switch (kind) {
      AppLinkKind.note => <AppLinkRef>[
        for (final AppNote n in _byUpdated(noteList)) noteRef(n),
      ],
      AppLinkKind.journal => <AppLinkRef>[
        for (final AppTrade t in _byDate(journalList)) journalRef(t),
      ],
      AppLinkKind.strategy => <AppLinkRef>[
        for (final AppStrategy s in _byStrategyUpdated(strategyList))
          strategyRef(s),
      ],
      AppLinkKind.ticker => <AppLinkRef>[
        for (final AppTicker t in _tickers.values) tickerRef(t.symbol),
      ],
      AppLinkKind.aiCopilot => <AppLinkRef>[
        const AppLinkRef(
          kind: AppLinkKind.aiCopilot,
          id: 'ai_copilot',
          title: 'AI Trading Copilot',
          subtitle: 'Quantitative Assistant',
        ),
      ],
      AppLinkKind.communityPost => <AppLinkRef>[],
      AppLinkKind.messageThread => <AppLinkRef>[],
    };
    return refs
        .where((AppLinkRef r) => !skip.contains(r.id) && matches(r))
        .toList(growable: false);
  }

  // ── Health: what the graph says about the workspace ────────────────────────

  /// Total edges, counting each pair once.
  int get edgeCount {
    int count = 0;
    for (final AppNote n in noteList) {
      count += bundleForNote(n).length;
    }
    for (final AppTrade t in journalList) {
      count += bundleForJournal(t).strategies.length;
    }
    return count;
  }

  /// Records with nothing attached. The single most useful prompt a linked
  /// workspace can show: a trade with no plan and no note is the one that will
  /// be repeated.
  ///
  /// Tickers do not count. Naming an instrument is a topic tag, not a
  /// relationship to the trader's own records — a note that mentions `RELIANCE`
  /// and nothing else is exactly the note this prompt exists to catch.
  List<AppLinkRef> orphans({int limit = 6}) {
    final List<AppLinkRef> out = <AppLinkRef>[
      for (final AppTrade t in _byDate(journalList))
        if (_isUnlinked(bundleForJournal(t))) journalRef(t),
      for (final AppNote n in _byUpdated(noteList))
        if (_isUnlinked(bundleForNote(n))) noteRef(n),
      for (final AppStrategy s in strategyList)
        if (bundleForStrategy(s).journal.isEmpty) strategyRef(s),
    ];
    return out.take(limit).toList(growable: false);
  }

  static bool _isUnlinked(AppLinkBundle b) =>
      b.notes.isEmpty && b.journal.isEmpty && b.strategies.isEmpty;

  /// How many journal entries carry a write-up. A journal of numbers with no
  /// words is the failure mode this whole feature exists to prevent.
  double get journalCoverage {
    if (journalList.isEmpty) return 0;
    final int written = journalList.where((AppTrade t) => t.hasStory).length;
    return written / journalList.length;
  }

  // ── Sorting helpers ────────────────────────────────────────────────────────

  List<AppLinkRef> _sortedNotes(Iterable<String> ids) {
    final List<AppNote> found = <AppNote>[
      for (final String id in ids)
        if (_notes[id] != null) _notes[id]!,
    ];
    final List<String> missing = <String>[
      for (final String id in ids)
        if (_notes[id] == null) id,
    ];
    return <AppLinkRef>[
      for (final AppNote n in _byUpdated(found)) noteRef(n),
      for (final String id in missing) AppLinkRef.missing(AppLinkKind.note, id),
    ];
  }

  List<AppLinkRef> _sortedJournal(Iterable<String> ids) {
    final List<AppTrade> found = <AppTrade>[
      for (final String id in ids)
        if (_journal[id] != null) _journal[id]!,
    ];
    final List<String> missing = <String>[
      for (final String id in ids)
        if (_journal[id] == null) id,
    ];
    return <AppLinkRef>[
      for (final AppTrade t in _byDate(found)) journalRef(t),
      for (final String id in missing)
        AppLinkRef.missing(AppLinkKind.journal, id),
    ];
  }

  static List<AppNote> _byUpdated(List<AppNote> notes) =>
      notes.toList()
        ..sort((AppNote a, AppNote b) => b.updatedAt.compareTo(a.updatedAt));

  static List<AppTrade> _byDate(List<AppTrade> trades) =>
      trades.toList()
        ..sort((AppTrade a, AppTrade b) => b.sortDate.compareTo(a.sortDate));

  static List<AppStrategy> _byStrategyUpdated(List<AppStrategy> items) =>
      items.toList()..sort((AppStrategy a, AppStrategy b) {
        final DateTime x = b.updatedAt ?? b.createdAt ?? DateTime(1970);
        final DateTime y = a.updatedAt ?? a.createdAt ?? DateTime(1970);
        return x.compareTo(y);
      });
}
