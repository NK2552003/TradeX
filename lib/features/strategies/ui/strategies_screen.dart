import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// Required unified UI surfaces for feature pages.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/features/linking/link_graph_service.dart';

import '../data/strategies_repository.dart';
import '../data/strategy_templates.dart';
import 'strategy_detail_screen.dart';
import 'strategy_editor_screen.dart';

/// Which surface the strategies destination is showing.
enum _StrategyView { list, document, editor }

/// The playbook library — one index, two genuinely different surfaces.
///
/// **Desktop** is a workbench: a permanent, status-grouped index rail beside the
/// open playbook, and on a very wide screen a third column for the trades and
/// notes attached to it. Comparing two playbooks is what a trader actually does
/// here, and that costs one click rather than a back-and-forward.
///
/// **Mobile** is a library that opens a playbook. A 340 dp rail cannot coexist
/// with a document on a phone, so the grid *is* the first screen and the playbook
/// is the second — a real back step, reported to the shell through
/// [onSubpageChanged] so the app bar names it and the hardware back button
/// unwinds it.
///
/// Everything on screen comes from [StrategiesRepository.watchAll] and
/// [AppLinkGraphService.watch]: a save in the editor, a status change in the
/// header and a trade filed from the journal all land here without this screen
/// asking for them.
class StrategiesScreen extends StatefulWidget {
  const StrategiesScreen({
    super.key,
    this.onSubpageChanged,
    this.onOpenRef,
    this.onOpenWriting,
    this.openRequest,
  });

  /// Lets the mobile shell draw the open playbook's title, icon and back button.
  final void Function(String? title, IconData? icon, VoidCallback? onBack)?
  onSubpageChanged;

  /// Follows a link into another destination. Null when the shell cannot reach
  /// it for this role, in which case cross-kind links stay inert rather than
  /// pretending to navigate.
  final void Function(AppLinkRef ref)? onOpenRef;
  final ValueChanged<AppLinkRef>? onOpenWriting;

  /// A record the shell wants opened — how a link from a note or a trade lands
  /// on the right playbook.
  final AppLinkOpenRequest? openRequest;

  @override
  State<StrategiesScreen> createState() => _StrategiesScreenState();
}

class _StrategiesScreenState extends State<StrategiesScreen> {
  static const int _pageSize = 8;

  final StrategiesRepository _repo = StrategiesRepositoryScope.repository;
  final AppLinkGraphService _links = AppLinkGraphScope.service;
  final ScrollController _railScroll = ScrollController();

  StreamSubscription<List<AppStrategy>>? _sub;
  StreamSubscription<AppLinkGraph>? _graphSub;

  List<AppStrategy> _strategies = const <AppStrategy>[];
  late AppLinkGraph _graph = _links.current;
  bool _loading = true;

  String _query = '';
  AppStrategyStatus? _status;
  String? _tag;
  String? _ticker;
  bool _onlyFavorites = false;
  AppStrategySort _sort = AppStrategySort.recentlyUpdated;
  int _visibleLimit = _pageSize;

  _StrategyView _view = _StrategyView.list;

  /// The open playbook, held by id rather than by value so the stream stays the
  /// one source of truth — an edit made anywhere re-renders the document without
  /// this screen copying the record.
  String? _activeId;

  /// A playbook that exists only in this screen: a template the trader picked
  /// and has not saved. It has no id, so it cannot come from the stream.
  AppStrategy? _draft;

  StrategyEditorMode _editorMode = StrategyEditorMode.write;

  @override
  void initState() {
    super.initState();
    _sub = _repo.watchAll().listen(
      (List<AppStrategy> items) {
        if (!mounted) return;
        setState(() {
          _strategies = items;
          _loading = false;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _loading = false);
        UiToast.error(
          context,
          title: 'Could not load the library',
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
  void didUpdateWidget(StrategiesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final AppLinkOpenRequest? request = widget.openRequest;
    if (request != null && request != oldWidget.openRequest) _apply(request);
    // The shell rebuilt with a new callback identity while a playbook is open, so
    // re-announce it or the app bar loses its title and its back button.
    if (oldWidget.onSubpageChanged != widget.onSubpageChanged) _announce();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _graphSub?.cancel();
    _railScroll.dispose();
    if (_view != _StrategyView.list) {
      widget.onSubpageChanged?.call(null, null, null);
    }
    super.dispose();
  }
  // ── Derived state ──────────────────────────────────────────────────────────

  /// The current slice, filtered and sorted by [StrategiesQuery] so the rail,
  /// the grid and the counts can never disagree about what "visible" means.
  List<AppStrategy> get _visible => StrategiesQuery.apply(
    _strategies,
    query: _query,
    status: _status,
    tag: _tag,
    ticker: _ticker,
    onlyFavorites: _onlyFavorites,
    sort: _sort,
  );

  /// What the phone has actually built. The rail renders the whole slice — a
  /// desktop list view is cheap — but a phone grid of document cards is not, so
  /// it grows a page at a time as the trader scrolls.
  List<AppStrategy> get _visibleBatch {
    final List<AppStrategy> visible = _visible;
    return visible.length <= _visibleLimit
        ? visible
        : visible.sublist(0, _visibleLimit);
  }

  AppStrategy? get _active {
    final AppStrategy? draft = _draft;
    if (draft != null) return draft;
    final String? id = _activeId;
    if (id == null) return null;
    for (final AppStrategy s in _strategies) {
      if (s.id == id) return s;
    }
    return null;
  }


  /// Status grouping is honest only over the default order. Sorted by win rate,
  /// a "Live" header above a block that also contains drafts would be a lie.
  bool get _grouped => _sort == AppStrategySort.recentlyUpdated;

  /// Library-level numbers, over the current slice rather than the whole shelf,
  /// so filtering to one instrument answers "how does this playbook family
  /// actually do" instead of restating the account.
  ///
  /// There is no `AppStrategyStats` in the model layer because these figures are
  /// only ever shown here: each playbook already carries its own record, derived
  /// on the way in from the trades filed under it, and this only adds them up.
  _LibraryStats get _stats {
    final List<AppStrategy> slice = _visible;
    int live = 0;
    int testing = 0;
    int drafts = 0;
    int entries = 0;
    int untested = 0;
    double net = 0;
    // Weighted by trade count on purpose: averaging the per-playbook win rates
    // would let a playbook with two trades outvote one with two hundred.
    double wins = 0;
    for (final AppStrategy s in slice) {
      switch (s.status) {
        case AppStrategyStatus.live:
          live++;
        case AppStrategyStatus.testing:
          testing++;
        case AppStrategyStatus.draft:
          drafts++;
        case AppStrategyStatus.retired:
          break;
      }
      entries += s.trades;
      net += s.netPnl;
      // AppStrategy.winRate is a 0..100 percentage; the stat row wants 0..1.
      wins += s.winRate / 100 * s.trades;
      if (s.trades == 0) untested++;
    }
    return _LibraryStats(
      total: slice.length,
      live: live,
      testing: testing,
      drafts: drafts,
      tradedEntries: entries,
      netPnl: net,
      winRate: entries == 0 ? 0 : wins / entries,
      unusedPlaybooks: untested,
    );
  }

  /// How many trader notes hang off each playbook, for the badge on the card.
  /// Read from the graph rather than from `linkedNoteIds` so a note deleted
  /// elsewhere stops being counted here without this screen hearing about it.
  Map<String, int> get _linkedNoteCounts => <String, int>{
    for (final AppStrategy s in _strategies)
      if (s.id.isNotEmpty) s.id: _graph.bundleForStrategy(s).notes.length,
  };

  void _updateFilter(VoidCallback update) => setState(() {
    update();
    _visibleLimit = _pageSize;
  });


  // ── Navigation between the three surfaces ──────────────────────────────────

  /// Tells the shell what we are looking at.
  void _announce() {
    if (!mounted) return;
    if (_view == _StrategyView.list) {
      widget.onSubpageChanged?.call(null, null, null);
      return;
    }
    final AppStrategy? strategy = _active;
    widget.onSubpageChanged?.call(
      strategy == null
          ? 'Playbook'
          : _view == _StrategyView.editor
          ? (strategy.id.isEmpty ? 'New playbook' : 'Editing ${strategy.name}')
          : strategy.name,
      AppLinkKind.strategy.icon,
      _view == _StrategyView.editor ? _requestEditorClose : _backToIndex,
    );
  }

  /// Applies a request from the shell. A request for another kind can only mean
  /// the shell routed it here by mistake, and a missing id can only mean the
  /// playbook was deleted between the click and the switch, so both degrade to
  /// leaving the library alone.
  void _apply(AppLinkOpenRequest request) {
    if (request.kind != AppLinkKind.strategy) return;
    final bool known = _strategies.any((AppStrategy s) => s.id == request.id);
    if (!known && !_loading) return;
    _open(request.id);
  }

  void _open(String id) {
    setState(() {
      _draft = null;
      _activeId = id;
      _view = _StrategyView.document;
    });
    _announce();
  }

  void _edit(
    AppStrategy strategy, {
    StrategyEditorMode mode = StrategyEditorMode.write,
  }) {
    setState(() {
      _editorMode = mode;
      _editorKey = GlobalKey<StrategyEditorScreenState>();
      _draft = strategy.id.isEmpty ? strategy : null;
      _activeId = strategy.id.isEmpty ? null : strategy.id;
      _view = _StrategyView.editor;
    });
    _announce();
  }

  void _backToIndex() {
    if (!mounted) return;
    setState(() {
      _draft = null;
      _view = _StrategyView.list;
    });
    _announce();
  }

  /// Back out of the editor. The editor owns the save-or-discard decision — it is
  /// the only thing that knows whether the rules are dirty — so this asks it
  /// rather than closing over its head.
  void _requestEditorClose() => _editorKey.currentState?.close();

  /// Recreated every time the editor opens. A [GlobalKey] that outlived one
  /// playbook would hand the next one the previous one's text controllers.
  GlobalKey<StrategyEditorScreenState> _editorKey =
      GlobalKey<StrategyEditorScreenState>();

  /// The editor hands back what it saved, so closing lands on the playbook the
  /// trader just wrote — including one created from a template, whose id this
  /// screen never saw. Nothing saved means there is nothing to read.
  void _closeEditor(AppStrategy? saved) {
    if (!mounted) return;
    setState(() {
      _draft = null;
      if (saved != null) _activeId = saved.id;
      _view = saved == null && _activeId == null
          ? _StrategyView.list
          : _StrategyView.document;
    });
    _announce();
  }

  /// New playbooks start from the gallery rather than a blank page. A template
  /// carries the section headings a set of rules needs — entry, invalidation,
  /// stop, sizing, exit — which is the difference between a playbook and a note
  /// that says "buy breakouts".
  void _newPlaybook() => _edit(StrategyTemplates.blank.toDraft());

  Future<void> _toggleFavorite(AppStrategy strategy) async {
    if (strategy.id.isEmpty) return;
    try {
      await _repo.toggleFavorite(strategy.id);
    } catch (error) {
      if (!mounted) return;
      UiToast.error(
        context,
        title: 'Could not update the playbook',
        message: '$error',
      );
    }
  }

  /// Follows a link. Strategy → strategy stays here; anything else belongs to
  /// another destination and goes back through the shell.
  void _openRef(AppLinkRef ref) {
    if (ref.missing) {
      UiToast.info(
        context,
        title: 'That record is gone',
        message: 'The link is kept so you can see it broke.',
      );
      return;
    }
    if (ref.kind == AppLinkKind.strategy) {
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

  @override
  Widget build(BuildContext context) {
    final AppStrategy? active = _active;

    if (_view != _StrategyView.list && active != null) {
      final bool editing = _view == _StrategyView.editor;
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

  Widget _document(AppStrategy strategy) => StrategyDetailScreen(
    key: ValueKey<String>('strategy_document_${strategy.id}'),
    strategy: strategy,
    onClose: _backToIndex,
    onEdit: () => _edit(strategy),
    onEditWriting: widget.onOpenWriting == null
        ? null
        : () => widget.onOpenWriting!(
            AppLinkRef(
              kind: AppLinkKind.strategy,
              id: strategy.id,
              title: strategy.name,
            ),
          ),
    onOpenLink: _openRef,
  );

  Widget _editor(AppStrategy strategy) => StrategyEditorScreen(
    key: _editorKey,
    strategy: strategy,
    initialMode: _editorMode,
    detailsOnly: true,
    onClose: _closeEditor,
    onDeleted: _backToIndex,
  );

  /// The library: the record, then one search field, then the playbooks.
  /// The stat strip and filters scroll away with the list.
  Widget _index(BuildContext context) {
    final UiTheme theme = context.ui;
    final _LibraryStats stats = _stats;
    final List<AppStrategy> visible = _visible;
    final List<AppStrategy> batch = _visibleBatch;
    final double gutter = context.sp(theme.spacing.md);

    return Stack(
      key: const ValueKey<String>('strategy_index_mobile'),
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
            child: AppStrategyNoteGrid(
              strategies: batch,
              onOpen: (AppStrategy s) => _open(s.id),
              onToggleFavorite: _toggleFavorite,
              groupByStatus: _grouped,
              linkedNoteCounts: _linkedNoteCounts,
              padding: EdgeInsets.only(
                top: context.sp(theme.spacing.xs),
                bottom: context.uiPageBottomInset + context.sz(72),
              ),
              header: _indexHeader(
                context,
                stats: stats,
                batch: batch,
                visible: visible,
              ),
              emptyState: Padding(
                padding: EdgeInsets.symmetric(vertical: gutter * 2),
                child: const UiEmptyState(
                  title: 'No strategies found',
                  message: 'Try adjusting your filters or create a new strategy.',
                  icon: Icons.lightbulb_outline,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: gutter,
          bottom: MediaQuery.paddingOf(context).bottom + gutter,
          child: UiButton.icon(
            key: const ValueKey<String>('strategy_new_fab'),
            icon: Icons.add_rounded,
            label: 'New playbook',
            variant: UiVariant.primary,
            size: UiSize.lg,
            onPressed: _newPlaybook,
          ),
        ),
      ],
    );
  }

  Widget _indexHeader(
    BuildContext context, {
    required _LibraryStats stats,
    required List<AppStrategy> batch,
    required List<AppStrategy> visible,
  }) {
    final UiTheme theme = context.ui;
    final double gutter = context.sp(theme.spacing.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppWorkspaceHeading(
          eyebrow: 'Your trading practice',
          title: 'Strategy playbooks',
          description: 'Turn your best setups into repeatable decisions.',
        ),
        const UiGap.v(20),
        AppStrategyNoteStatRow(
          total: stats.total,
          live: stats.live,
          testing: stats.testing,
          drafts: stats.drafts,
          tradedEntries: stats.tradedEntries,
          netPnl: stats.netPnl,
          winRate: stats.winRate,
          unusedPlaybooks: stats.unusedPlaybooks,
          compact: true,
        ),
        SizedBox(height: gutter),
        AppStrategyNoteFilterBar(
          query: _query,
          sort: _sort,
          status: _status,
          tag: _tag,
          ticker: _ticker,
          onlyFavorites: _onlyFavorites,
          availableTags: StrategiesQuery.tagsOf(_strategies),
          availableTickers: StrategiesQuery.tickersOf(_strategies),
          onQueryChanged: (String v) => _updateFilter(() => _query = v),
          onStatusChanged: (AppStrategyStatus? v) =>
              _updateFilter(() => _status = v),
          onTagChanged: (String? v) => _updateFilter(() => _tag = v),
          onTickerChanged: (String? v) => _updateFilter(() => _ticker = v),
          onSortChanged: (AppStrategySort v) => _updateFilter(() => _sort = v),
          onOnlyFavoritesChanged: (bool v) =>
              _updateFilter(() => _onlyFavorites = v),
          onNew: _newPlaybook,
        ),
        SizedBox(height: gutter),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _loading ? 'Loading…' : 'Playbooks',
                style: context.uiText.subheading,
              ),
            ),
            UiBadge(
              label: batch.length == visible.length
                  ? '${visible.length} shown'
                  : '${batch.length} of ${visible.length}',
              icon: Icons.account_tree_outlined,
              variant: UiBadgeVariant.outline,
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
      ],
    );
  }
}

/// Library totals over the visible slice.
///
/// Deliberately private and deliberately not in the model layer: these are one
/// screen's summary of rows that already carry their own derived record, not a
/// new domain concept the repositories or the backend need to know about.
class _LibraryStats {
  const _LibraryStats({
    required this.total,
    required this.live,
    required this.testing,
    required this.drafts,
    required this.tradedEntries,
    required this.netPnl,
    required this.winRate,
    required this.unusedPlaybooks,
  });

  final int total;
  final int live;
  final int testing;
  final int drafts;

  /// Journal entries filed under any playbook in the slice.
  final int tradedEntries;
  final double netPnl;

  /// 0..1, weighted by trade count — see [AppStrategyNoteStatRow.winRate].
  final double winRate;

  /// Playbooks with no trades filed at all: rules nobody has tested.
  final int unusedPlaybooks;
}
