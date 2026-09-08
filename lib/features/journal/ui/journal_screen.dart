import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// Required unified UI surfaces for feature pages.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/features/linking/link_graph_service.dart';

import '../data/journal_repository.dart';
import '../data/journal_templates.dart';
import 'journal_editor_screen.dart';
import 'journal_entry_screen.dart';

/// Which surface the journal destination is showing.
enum _JournalView { list, document, editor }

/// The trading journal — one index, two genuinely different surfaces.
///
/// **Desktop** is a workbench: a permanent index rail beside the open entry, and
/// on a very wide screen a third column for what the entry is linked to. Moving
/// between entries costs one click and never unloads the one being read.
///
/// **Mobile** is an index that opens an entry. A 340 dp rail cannot coexist with
/// a document on a phone, and hiding it behind a button buries the list, so the
/// list simply *is* the first screen and the entry is the second — a real back
/// step, reported to the shell through [onSubpageChanged] so the app bar names
/// it and the hardware back button unwinds it.
///
/// Everything on screen comes from [JournalRepository.watchAll] and
/// [AppLinkGraphService.watch]: a save in the editor, a delete in the document
/// and a link written from a note all land here without this screen asking.
class JournalScreen extends StatefulWidget {
  const JournalScreen({
    super.key,
    this.onSubpageChanged,
    this.onOpenRef,
    this.onOpenWriting,
    this.openRequest,
  });

  /// Lets the mobile shell draw the open entry's title, icon and back button.
  final void Function(String? title, IconData? icon, VoidCallback? onBack)?
  onSubpageChanged;

  /// Follows a link into another destination. Null when the shell cannot reach
  /// it for this role, in which case cross-kind links stay inert rather than
  /// pretending to navigate.
  final void Function(AppLinkRef ref)? onOpenRef;
  final ValueChanged<AppLinkRef>? onOpenWriting;

  /// A record the shell wants opened — how a link from a note or a playbook
  /// lands on the right entry.
  final AppLinkOpenRequest? openRequest;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  static const int _pageSize = 12;

  final JournalRepository _repo = JournalRepositoryScope.repository;
  final AppLinkGraphService _links = AppLinkGraphScope.service;
  final ScrollController _railScroll = ScrollController();

  StreamSubscription<List<AppTrade>>? _sub;
  StreamSubscription<AppLinkGraph>? _graphSub;

  List<AppTrade> _entries = const <AppTrade>[];
  late AppLinkGraph _graph = _links.current;
  bool _loading = true;

  String _query = '';
  AppOutcome? _outcome;
  String? _tag;
  String? _ticker;
  bool _onlyUnwritten = false;
  bool _onlyUnfiled = false;
  AppJournalSort _sort = AppJournalSort.recentFirst;
  int _visibleLimit = _pageSize;

  _JournalView _view = _JournalView.list;

  /// The open entry, held by id rather than by value so the stream stays the one
  /// source of truth — an edit made anywhere re-renders the document without
  /// this screen copying the record.
  String? _activeId;

  /// An entry that exists only in this screen: a template the trader picked and
  /// has not saved. It has no id, so it cannot come from the stream.
  AppTrade? _draft;

  JournalEditorMode _editorMode = JournalEditorMode.write;

  @override
  void initState() {
    super.initState();
    _sub = _repo.watchAll().listen(
      (List<AppTrade> entries) {
        if (!mounted) return;
        setState(() {
          _entries = entries;
          _loading = false;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _loading = false);
        UiToast.error(
          context,
          title: 'Could not load the journal',
          message: '$error',
        );
      },
    );
    _graphSub = _links.watch().listen((AppLinkGraph graph) {
      if (mounted) setState(() => _graph = graph);
    });
    final AppLinkOpenRequest? request = widget.openRequest;
    if (request != null) {
      // Deferred: the shell mounts this screen and hands over the request in the
      // same frame, and the mobile branch reports a subpage title while doing it.
      WidgetsBinding.instance.addPostFrameCallback((_) => _apply(request));
    }
  }

  @override
  void didUpdateWidget(JournalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final AppLinkOpenRequest? request = widget.openRequest;
    if (request != null && request != oldWidget.openRequest) _apply(request);
    // The shell rebuilt with a new callback identity while an entry is open, so
    // re-announce it or the app bar loses its title and its back button.
    if (oldWidget.onSubpageChanged != widget.onSubpageChanged) _announce();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _graphSub?.cancel();
    _railScroll.dispose();
    if (_view != _JournalView.list) {
      widget.onSubpageChanged?.call(null, null, null);
    }
    super.dispose();
  }

  // ── Derived state ──────────────────────────────────────────────────────────

  List<AppTrade> get _visible => JournalQuery.apply(
    _entries,
    query: _query,
    outcome: _outcome,
    tag: _tag,
    ticker: _ticker,
    onlyUnwritten: _onlyUnwritten,
    onlyUnfiled: _onlyUnfiled,
    sort: _sort,
  );

  /// The mobile list grows on scroll; the desktop rail is virtualised by its own
  /// [ListView] and shows everything.
  List<AppTrade> get _visibleBatch =>
      _visible.take(_visibleLimit).toList(growable: false);

  AppJournalStats get _stats => JournalQuery.statsOf(_visible);

  /// Running P/L over the slice on screen, oldest first — the shape of the
  /// filtered journal rather than of the whole account.
  List<double> get _equityCurve {
    final List<AppTrade> closed =
        _visible.where((AppTrade t) => !t.isOpen).toList()
          ..sort((AppTrade a, AppTrade b) => a.sortDate.compareTo(b.sortDate));
    double running = 0;
    return <double>[for (final AppTrade t in closed) running += t.pnl];
  }

  /// Entry id → how many trader notes it is linked to, resolved through the
  /// graph so a card can show edges the entry record itself never stored.
  Map<String, int> get _linkedNoteCounts => <String, int>{
    for (final AppTrade t in _visibleBatch)
      t.id: _graph.bundleForJournal(t).notes.length,
  };

  /// The stream's copy of the open entry, or the unsaved draft.
  AppTrade? get _active {
    final AppTrade? draft = _draft;
    if (draft != null) return draft;
    final String? id = _activeId;
    if (id == null) return null;
    for (final AppTrade t in _entries) {
      if (t.id == id) return t;
    }
    return null;
  }

  bool get _filtered =>
      _query.trim().isNotEmpty ||
      _outcome != null ||
      _tag != null ||
      _ticker != null ||
      _onlyUnwritten ||
      _onlyUnfiled;

  void _updateFilter(VoidCallback update) => setState(() {
    update();
    _visibleLimit = _pageSize;
  });

  void _clearFilters() => _updateFilter(() {
    _query = '';
    _outcome = null;
    _tag = null;
    _ticker = null;
    _onlyUnwritten = false;
    _onlyUnfiled = false;
  });

  // ── Navigation between the three surfaces ──────────────────────────────────

  /// Tells the shell what we are looking at.
  void _announce() {
    if (!mounted) return;
    if (_view == _JournalView.list) {
      widget.onSubpageChanged?.call(null, null, null);
      return;
    }
    final AppTrade? entry = _active;
    widget.onSubpageChanged?.call(
      entry == null
          ? 'Journal entry'
          : _view == _JournalView.editor
          ? (entry.id.isEmpty ? 'New entry' : 'Editing ${entry.ticker}')
          : entry.displayTitle,
      AppLinkKind.journal.icon,
      _view == _JournalView.editor ? _requestEditorClose : _backToIndex,
    );
  }

  /// Applies a request from the shell. A request for another kind can only mean
  /// the shell routed it here by mistake, and a missing id can only mean the
  /// record was deleted between the click and the switch, so both degrade to
  /// leaving the index alone.
  void _apply(AppLinkOpenRequest request) {
    if (request.kind != AppLinkKind.journal) return;
    final bool known = _entries.any((AppTrade t) => t.id == request.id);
    if (!known && !_loading) return;
    _open(request.id);
  }

  void _open(String id) {
    setState(() {
      _draft = null;
      _activeId = id;
      _view = _JournalView.document;
    });
    _announce();
  }

  void _edit(
    AppTrade entry, {
    JournalEditorMode mode = JournalEditorMode.write,
  }) {
    setState(() {
      _editorMode = mode;
      _editorKey = GlobalKey<JournalEditorScreenState>();
      _draft = entry.id.isEmpty ? entry : null;
      _activeId = entry.id.isEmpty ? null : entry.id;
      _view = _JournalView.editor;
    });
    _announce();
  }

  void _backToIndex() {
    if (!mounted) return;
    setState(() {
      _draft = null;
      _view = _JournalView.list;
    });
    _announce();
  }

  /// Back out of the editor. The editor itself owns the save-or-discard decision
  /// — it is the only thing that knows whether the body is dirty — so this asks
  /// it rather than closing over its head.
  void _requestEditorClose() => _editorKey.currentState?.close();

  /// Recreated every time the editor opens. A [GlobalKey] that outlived one
  /// entry would hand the next entry the previous one's text controllers.
  GlobalKey<JournalEditorScreenState> _editorKey =
      GlobalKey<JournalEditorScreenState>();

  /// The editor hands back what it saved, so closing lands on the entry the
  /// trader just wrote — including one created from a template, whose id this
  /// screen never saw. Nothing saved means there is nothing to read.
  void _closeEditor(AppTrade? saved) {
    if (!mounted) return;
    setState(() {
      _draft = null;
      if (saved != null) _activeId = saved.id;
      _view = saved == null && _activeId == null
          ? _JournalView.list
          : _JournalView.document;
    });
    _announce();
  }

  /// New entries start from the gallery rather than a blank form: a template is
  /// the fastest way to log a trade properly, and the only way a trader who has
  /// never written one up learns what belongs in it.
  void _newEntry() => _edit(JournalTemplates.blank.toDraft());

  /// Follows a link. Journal → journal stays here; anything else is another
  /// destination's record and goes back through the shell.
  void _openRef(AppLinkRef ref) {
    if (ref.missing) {
      UiToast.info(
        context,
        title: 'That record is gone',
        message: 'The link is kept so you can see it broke.',
      );
      return;
    }
    if (ref.kind == AppLinkKind.journal) {
      _open(ref.id);
      return;
    }
    final void Function(AppLinkRef ref)? jump = widget.onOpenRef;
    if (jump == null) {
      UiToast.info(
        context,
        title: ref.title,
        message: '${ref.kind.label} — not available from here.',
      );
      return;
    }
    jump(ref);
  }

  // ── Surfaces ───────────────────────────────────────────────────────────────

  /// Month headers only make sense over a chronological order. Over a list sorted
  /// by P/L they would be lying about the grouping.
  bool get _chronological =>
      _sort == AppJournalSort.recentFirst ||
      _sort == AppJournalSort.oldestFirst;

  @override
  Widget build(BuildContext context) {
    final AppTrade? active = _active;

    if (_view != _JournalView.list && active != null) {
      final bool editing = _view == _JournalView.editor;
      return PopScope(
        // The editor may need to save or ask before it lets go, so the pop is
        // always handled here rather than by the navigator.
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (didPop) return;
          editing ? _requestEditorClose() : _backToIndex();
        },
        child: editing ? _editor(active) : _document(active),
      );
    }

    return _index(context);
  }

  Widget _document(AppTrade entry) => JournalEntryScreen(
    key: ValueKey<String>('journal_document_${entry.id}'),
    entry: entry,
    onClose: _backToIndex,
    onEdit: () => _edit(entry),
    onEditWriting: widget.onOpenWriting == null
        ? null
        : () => widget.onOpenWriting!(
            AppLinkRef(
              kind: AppLinkKind.journal,
              id: entry.id,
              title: entry.displayTitle,
            ),
          ),
    onOpenLink: _openRef,
  );

  Widget _editor(AppTrade entry) => JournalEditorScreen(
    key: _editorKey,
    entry: entry,
    initialMode: _editorMode,
    detailsOnly: true,
    onClose: _closeEditor,
    onDeleted: _backToIndex,
  );

  /// The index: numbers, then one search field, then the entries. The
  /// stat strip and filters scroll away with the list.
  Widget _index(BuildContext context) {
    final UiTheme theme = context.ui;
    final AppJournalStats stats = _stats;
    final List<AppTrade> visible = _visible;
    final List<AppTrade> batch = _visibleBatch;
    final double gutter = context.sp(theme.spacing.md);

    return Stack(
      key: const ValueKey<String>('journal_index_mobile'),
      children: <Widget>[
        UiPage(
          scrollable: false,
          child: NotificationListener<ScrollNotification>(
            // The grid owns its own ListView, so paging reads the metrics of
            // whatever scrolled rather than driving a controller from here.
            onNotification: (ScrollNotification notification) {
              if (notification is! ScrollUpdateNotification) return false;
              if (_visibleLimit >= visible.length) return false;
              if (notification.metrics.extentAfter > context.sz(560)) {
                return false;
              }
              setState(() => _visibleLimit += _pageSize);
              return false;
            },
            child: AppJournalNoteGrid(
              entries: batch,
              onOpen: (AppTrade entry) => _open(entry.id),
              groupByMonth: _chronological,
              linkedNoteCounts: _linkedNoteCounts,
              padding: EdgeInsets.only(
                top: context.sp(theme.spacing.xs),
                bottom: context.uiPageBottomInset + context.sz(72),
              ),
              header: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppWorkspaceHeading(
                    eyebrow: 'Your trading practice',
                    title: 'Trade journal',
                    description:
                        'Capture the decision. Learn from the outcome.',
                  ),
                  const UiGap.v(20),
                  AppJournalNoteStatRow(
                    total: stats.total,
                    open: stats.open,
                    netPnl: stats.netPnl,
                    winRate: stats.winRate,
                    avgR: stats.avgR,
                    written: stats.written,
                    unfiled: stats.unfiled,
                    equityCurve: _equityCurve,
                    compact: true,
                  ),
                  SizedBox(height: gutter),
                  AppJournalNoteFilterBar(
                    query: _query,
                    sort: _sort,
                    outcome: _outcome,
                    tag: _tag,
                    ticker: _ticker,
                    onlyUnwritten: _onlyUnwritten,
                    onlyUnfiled: _onlyUnfiled,
                    availableTags: JournalQuery.tagsOf(_entries),
                    availableTickers: JournalQuery.tickersOf(_entries),
                    onQueryChanged: (String v) =>
                        _updateFilter(() => _query = v),
                    onOutcomeChanged: (AppOutcome? v) =>
                        _updateFilter(() => _outcome = v),
                    onTagChanged: (String? v) => _updateFilter(() => _tag = v),
                    onTickerChanged: (String? v) =>
                        _updateFilter(() => _ticker = v),
                    onSortChanged: (AppJournalSort v) =>
                        _updateFilter(() => _sort = v),
                    onOnlyUnwrittenChanged: (bool v) =>
                        _updateFilter(() => _onlyUnwritten = v),
                    onOnlyUnfiledChanged: (bool v) =>
                        _updateFilter(() => _onlyUnfiled = v),
                  ),
                  SizedBox(height: gutter),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _loading ? 'Loading…' : 'Entries',
                          style: context.uiText.subheading,
                        ),
                      ),
                      UiBadge(
                        label: batch.length == visible.length
                            ? '${visible.length} shown'
                            : '${batch.length} of ${visible.length}',
                        icon: Icons.menu_book_outlined,
                        variant: UiBadgeVariant.outline,
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.sm)),
                ],
              ),
              emptyState: Padding(
                padding: EdgeInsets.symmetric(vertical: gutter * 2),
                child: UiEmptyState(
                  icon: _filtered
                      ? Icons.filter_alt_off_rounded
                      : Icons.menu_book_outlined,
                  title: _filtered ? 'Nothing matches' : 'No entries yet',
                  message: _filtered
                      ? 'Clear the filters to see the whole journal.'
                      : 'Log the trade you just closed and write what you saw '
                            'while it is still fresh.',
                  action: _filtered
                      ? UiButton(
                          label: 'Clear filters',
                          variant: UiVariant.secondary,
                          onPressed: _clearFilters,
                        )
                      : UiButton(
                          label: 'New entry',
                          leadingIcon: Icons.add_rounded,
                          onPressed: _newEntry,
                        ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: gutter,
          bottom: MediaQuery.paddingOf(context).bottom + gutter,
          child: UiButton.icon(
            key: const ValueKey<String>('journal_new_entry_fab'),
            icon: Icons.add_rounded,
            label: 'New entry',
            variant: UiVariant.primary,
            size: UiSize.lg,
            onPressed: _newEntry,
          ),
        ),
      ],
    );
  }
}
