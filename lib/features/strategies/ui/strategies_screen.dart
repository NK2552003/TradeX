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
import 'strategy_template_gallery.dart';

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
    this.onAttachToPost,
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
  final AppWritingPostAttachmentHandler? onAttachToPost;

  /// A record the shell wants opened — how a link from a note or a trade lands
  /// on the right playbook.
  final AppLinkOpenRequest? openRequest;

  @override
  State<StrategiesScreen> createState() => StrategiesScreenState();
}

class StrategiesScreenState extends State<StrategiesScreen> {
  /// Public entry point so host workspaces (like Writing Desk) can trigger
  /// new playbook creation.
  void newPlaybook() => _newPlaybook();

  /// Public entry point for the unified Writing Desk help action.
  void showGuide() => _showGuide();

  void showGuideWithTargets(List<GlobalKey> targets) =>
      FeatureGuideSpotlight.show(
        context,
        feature: FeatureId.strategies,
        steps: FeatureGuideSteps.strategies,
        targets: targets,
        onStepAction: _onGuideStepAction,
      );

  void setSearchQuery(String value) {
    if (_query == value || !mounted) return;
    _updateFilter(() => _query = value);
  }

  void showFilters() => _strategyFilterBar().showFilters(context);

  void performGuideStep(FeatureGuideStep step) => _onGuideStepAction(step);

  static const int _pageSize = 8;

  final StrategiesRepository _repo = StrategiesRepositoryScope.repository;
  final AppLinkGraphService _links = AppLinkGraphScope.service;
  final GlobalKey _guideFilterKey = GlobalKey();

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

  /// The tab a freshly-opened document should land on. Set by guide actions and
  /// next-best-action chips that point at a specific face of a playbook, and
  /// reset to [StrategyDetailTab.playbook] by ordinary opens.
  StrategyDetailTab _initialDetailTab = StrategyDetailTab.playbook;

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
    if (oldWidget.onSubpageChanged != widget.onSubpageChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _graphSub?.cancel();
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

  AppStrategyNoteFilterBar _strategyFilterBar({
    bool compact = false,
    bool showSearch = true,
    bool showFilterControl = true,
    VoidCallback? onNew,
  }) => AppStrategyNoteFilterBar(
    key: _guideFilterKey,
    compact: compact,
    showSearch: showSearch,
    showFilterControl: showFilterControl,
    query: _query,
    sort: _sort,
    status: _status,
    tag: _tag,
    ticker: _ticker,
    onlyFavorites: _onlyFavorites,
    availableTags: StrategiesQuery.tagsOf(_strategies),
    availableTickers: StrategiesQuery.tickersOf(_strategies),
    onQueryChanged: (String v) => _updateFilter(() => _query = v),
    onStatusChanged: (AppStrategyStatus? v) => _updateFilter(() => _status = v),
    onTagChanged: (String? v) => _updateFilter(() => _tag = v),
    onTickerChanged: (String? v) => _updateFilter(() => _ticker = v),
    onSortChanged: (AppStrategySort v) => _updateFilter(() => _sort = v),
    onOnlyFavoritesChanged: (bool v) => _updateFilter(() => _onlyFavorites = v),
    onNew: onNew,
  );

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

  void _open(String id) => _openWithTab(id, StrategyDetailTab.playbook);

  void _openWithTab(String id, StrategyDetailTab tab) {
    setState(() {
      _draft = null;
      _activeId = id;
      _initialDetailTab = tab;
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
      _activeId = null;
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
      // A document opened from the editor always lands on the playbook body, not
      // a stale tab left over from a guide action or a next-best-action chip.
      _initialDetailTab = StrategyDetailTab.playbook;
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
  ///
  /// This is also the guide's "Start from a template" step: it returns to the
  /// library unchanged when the trader backs out of the gallery.
  Future<void> _newPlaybook() async {
    final AppStrategyTemplate? template = await showStrategyTemplateGallery(
      context,
    );
    if (template == null || !mounted) return;
    _edit(template.toDraft());
  }

  /// Straight to a blank draft — the guide's "Write your rules" step, which
  /// deliberately skips the gallery so the action lands exactly where it says.
  void _newBlankPlaybook() => _edit(StrategyTemplates.blank.toDraft());

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

  // ── Guide ──────────────────────────────────────────────────────────────────

  /// Opens the strategies walkthrough, at any time, from the header help action
  /// or the banner's "Show guide" button. The owning screen resolves each step's
  /// action into real navigation below.
  void _showGuide() {
    FeatureGuideSpotlight.show(
      context,
      feature: FeatureId.strategies,
      steps: FeatureGuideSteps.strategies,
      targets: <GlobalKey>[_guideFilterKey],
      onStepAction: _onGuideStepAction,
    );
  }

  /// Maps a guide step to the real screen it describes. The sheet already marks
  /// the step done when its action button is pressed; this only navigates — it
  /// never fakes completion, and a step with nothing to act on navigates nowhere
  /// and says so.
  void _onGuideStepAction(FeatureGuideStep step) {
    switch (step.id) {
      case 'template':
        _newPlaybook();
      case 'rules':
        _newBlankPlaybook();
      case 'testing':
        _promoteToTesting();
      case 'file-entries':
        _openJournalLinks();
      case 'live':
        _reviewRecord();
      default:
        break;
    }
  }

  /// "Promote to Testing" — the first draft, open on its status control. If the
  /// draft is already the open document the status control is right there on its
  /// masthead, so there is nowhere to navigate; if there are no drafts there is
  /// nothing to promote, so the step stays put rather than pretending.
  void _promoteToTesting() {
    final AppStrategy? draft = _firstWhere(
      (AppStrategy s) => s.status == AppStrategyStatus.draft,
    );
    if (draft == null) {
      UiToast.info(
        context,
        title: 'No drafts to promote',
        message: 'Write a playbook first, then promote it to Testing.',
      );
      return;
    }
    if (_activeId == draft.id) return;
    _edit(draft);
  }

  /// "File journal entries" — filing happens on the playbook's Links surface,
  /// so the step lands on the playbook most in need of one: a testing playbook
  /// with nothing filed yet, then any testing playbook, then the newest.
  void _openJournalLinks() {
    final AppStrategy? target =
        _firstWhere(
          (AppStrategy s) =>
              s.status == AppStrategyStatus.testing && s.trades == 0,
        ) ??
        _firstWhere((AppStrategy s) => s.status == AppStrategyStatus.testing) ??
        (_strategies.isEmpty ? null : _strategies.first);
    if (target == null) {
      UiToast.info(
        context,
        title: 'Nothing to file under',
        message: 'Write a playbook and promote it to Testing first.',
      );
      return;
    }
    _openWithTab(target.id, StrategyDetailTab.links);
  }

  /// "Review the record" — the newest testing playbook that actually has one,
  /// straight onto the Performance tab.
  void _reviewRecord() {
    final AppStrategy? target = _firstWhere(
      (AppStrategy s) => s.status == AppStrategyStatus.testing && s.trades > 0,
    );
    if (target == null) {
      UiToast.info(
        context,
        title: 'Nothing to review yet',
        message:
            'Promote a playbook to Testing and file trades under it first.',
      );
      return;
    }
    _openWithTab(target.id, StrategyDetailTab.playbook);
  }

  /// First playbook matching [test], in the repository's recently-updated order
  /// — so "first" means "most recently edited", which is the one the trader is
  /// most likely to mean.
  AppStrategy? _firstWhere(bool Function(AppStrategy s) test) {
    for (final AppStrategy s in _strategies) {
      if (test(s)) return s;
    }
    return null;
  }

  // ── Next-best action ───────────────────────────────────────────────────────

  /// The pipeline nudges shown as compact chips between the header and the list.
  ///
  /// Derived from the **whole library** (`_strategies`, the repository stream
  /// already sorted recently-updated) plus the link graph — never from the
  /// filtered slice, because "2 drafts to finish" is true of the shelf even
  /// while a search narrows what is on screen. Ordered Define → Execute →
  /// Review:
  ///
  ///  1. Drafts → open the newest one in the editor.
  ///  2. Testing/live playbooks with no trades → open the newest on Links, where
  ///     a trade is filed.
  ///  3. Testing playbooks with a record → open the newest on Performance.
  ///
  /// Empty while the stream is still loading or when there is nothing to act on,
  /// so the row never advertises a zero.
  List<_NextAction> get _nextActions {
    if (_loading) return const <_NextAction>[];
    final List<AppStrategy> drafts = _strategies
        .where((AppStrategy s) => s.status == AppStrategyStatus.draft)
        .toList(growable: false);
    final List<AppStrategy> untested = _strategies
        .where(
          (AppStrategy s) =>
              (s.status == AppStrategyStatus.testing ||
                  s.status == AppStrategyStatus.live) &&
              s.trades == 0,
        )
        .toList(growable: false);
    final List<AppStrategy> ready = _strategies
        .where(
          (AppStrategy s) =>
              s.status == AppStrategyStatus.testing && s.trades > 0,
        )
        .toList(growable: false);

    return <_NextAction>[
      if (drafts.isNotEmpty)
        _NextAction(
          label: drafts.length == 1
              ? '1 draft to finish'
              : '${drafts.length} drafts to finish',
          icon: Icons.edit_note_rounded,
          intent: UiIntent.primary,
          onTap: () => _edit(drafts.first),
        ),
      if (untested.isNotEmpty)
        _NextAction(
          label: untested.length == 1
              ? '1 playbook has no trades — file one'
              : '${untested.length} playbooks have no trades — file one',
          icon: Icons.add_link_rounded,
          intent: UiIntent.warning,
          onTap: () => _openWithTab(untested.first.id, StrategyDetailTab.links),
        ),
      if (ready.isNotEmpty)
        _NextAction(
          label: ready.length == 1
              ? '1 testing playbook ready for review'
              : '${ready.length} testing playbooks ready for review',
          icon: Icons.insights_rounded,
          intent: UiIntent.bullish,
          onTap: () => _openWithTab(ready.first.id, StrategyDetailTab.playbook),
        ),
    ];
  }

  Widget _nextActionChips(BuildContext context) {
    final List<_NextAction> actions = _nextActions;
    if (actions.isEmpty) return const SizedBox.shrink();
    final UiTheme theme = context.ui;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (int i = 0; i < actions.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: context.sp(theme.spacing.xs)),
            UiButton(
              label: actions[i].label,
              leadingIcon: actions[i].icon,
              variant: UiVariant.soft,
              intent: actions[i].intent,
              size: UiSize.xs,
              onPressed: actions[i].onTap,
            ),
          ],
        ],
      ),
    );
  }

  // ── Surfaces ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final AppStrategy? active = _active;

    // The editor is a full-surface step on every width: it owns its own
    // save-or-discard decision and must not share the workbench's pane.
    if (_view == _StrategyView.editor && active != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (didPop) return;
          _requestEditorClose();
        },
        child: AppWorkbenchScope(
          embeddedHeader: widget.onSubpageChanged != null,
          child: _editor(active),
        ),
      );
    }

    if (_view == _StrategyView.document && active != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (didPop) return;
          _backToIndex();
        },
        child: AppWorkbenchScope(
          embeddedHeader: widget.onSubpageChanged != null,
          child: _document(active),
        ),
      );
    }
    return _index(context);
  }

  Widget _document(AppStrategy strategy) => StrategyDetailScreen(
    key: ValueKey<String>('strategy_document_${strategy.id}'),
    strategy: strategy,
    initialTab: _initialDetailTab,
    onClose: _backToIndex,
    onEdit: () => _edit(strategy, mode: StrategyEditorMode.write),
    onEditWriting: () {
      if (widget.onOpenWriting != null) {
        widget.onOpenWriting!(
          AppLinkRef(
            kind: AppLinkKind.strategy,
            id: strategy.id,
            title: strategy.name,
          ),
        );
      } else {
        _edit(strategy, mode: StrategyEditorMode.write);
      }
    },
    onOpenLink: _openRef,
    onAttachToPost: widget.onAttachToPost,
  );

  Widget _editor(AppStrategy strategy) => StrategyEditorScreen(
    key: _editorKey,
    strategy: strategy,
    initialMode: _editorMode,
    detailsOnly: false,
    onClose: _closeEditor,
    onDeleted: _backToIndex,
  );

  /// The library: the record, then one search field, then the playbooks.
  /// The stat strip and filters scroll away with the list.
  Widget _index(BuildContext context) {
    final UiTheme theme = context.ui;
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
              header: _indexHeader(context, batch: batch, visible: visible),
              emptyState: Padding(
                padding: EdgeInsets.symmetric(vertical: gutter * 2),
                child: const UiEmptyState(
                  title: 'No strategies found',
                  message:
                      'Try adjusting your filters or create a new strategy.',
                  icon: Icons.lightbulb_outline,
                ),
              ),
            ),
          ),
        ),
        if (!context.uiRes.isDesktop && !AppWritingDeskScope.isHosted(context))
          Positioned(
            right: gutter,
            bottom: MediaQuery.paddingOf(context).bottom + gutter,
            child: UiIconButton(
              key: const ValueKey<String>('strategy_new_fab'),
              icon: Icons.add_rounded,
              variant: UiVariant.primary,
              size: UiSize.lg,
              tooltip: 'New playbook',
              onPressed: _newPlaybook,
            ),
          ),
      ],
    );
  }

  Widget _indexHeader(
    BuildContext context, {
    required List<AppStrategy> batch,
    required List<AppStrategy> visible,
  }) {
    final UiTheme theme = context.ui;
    final double gutter = context.sp(theme.spacing.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(height: context.sp(theme.spacing.xs)),
        _strategyFilterBar(
          showSearch: !AppWritingDeskScope.isHosted(context),
          showFilterControl: !AppWritingDeskScope.isHosted(context),
          onNew:
              context.uiRes.isDesktop && !AppWritingDeskScope.isHosted(context)
              ? _newPlaybook
              : null,
        ),
        SizedBox(height: gutter),
        _nextActionChips(context),
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

/// One pipeline nudge in the "next best action" chip row. Private data, computed
/// by [_StrategiesScreenState._nextActions] from the live repository stream and
/// link graph — nothing here is hardcoded.
class _NextAction {
  const _NextAction({
    required this.label,
    required this.icon,
    required this.intent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final UiIntent intent;
  final VoidCallback onTap;
}
