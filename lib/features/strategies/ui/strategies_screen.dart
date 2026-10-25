import 'package:tradex/core/config/customer_limitations.dart';
import 'package:tradex/core/config/record_access.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    this.onReturnToOrigin,
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

  final VoidCallback? onReturnToOrigin;

  @override
  State<StrategiesScreen> createState() => StrategiesScreenState();
}

class StrategiesScreenState extends State<StrategiesScreen> {
  /// The saved record currently displayed, for browser history and sharing.
  AppLinkRef? get openedRef {
    final record = _active;
    if (_view == _StrategyView.list || record == null || record.id.isEmpty) {
      return null;
    }
    return AppLinkRef(
      kind: AppLinkKind.strategy,
      id: record.id,
      title: record.name,
      isPublicContext: _isPublicContext,
    );
  }

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

  static const int _pageSize = 12;

  final StrategiesRepository _repo = StrategiesRepositoryScope.repository;
  final AppLinkGraphService _links = AppLinkGraphScope.service;
  final GlobalKey _guideFilterKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _bannerKey = GlobalKey();
  final GlobalKey _kpiBarKey = GlobalKey();
  final GlobalKey _filterBarKey = GlobalKey();
  final GlobalKey _gridKey = GlobalKey();

  bool _dismissedBanner = false;
  bool _isGridView = true;

  StreamSubscription<List<AppStrategy>>? _sub;
  StreamSubscription<AppLinkGraph>? _graphSub;

  List<AppStrategy> _strategies = const <AppStrategy>[];
  List<AppStrategy> _accessibleRecords = [];
  AppStrategy? _linkedRecord;
  String? _accessError;
  int _accessRevision = 0;
  late AppLinkGraph _graph = _links.current;
  bool _loading = true;

  String _query = '';
  AppStrategyStatus? _status;
  String? _tag;
  String? _ticker;
  bool _onlyFavorites = false;
  AppStrategySort _sort = AppStrategySort.recentlyUpdated;
  int _currentPage = 1;
  bool _isPublicContext = false;

  _StrategyView _view = _StrategyView.list;

  /// The open playbook, held by id rather than by value so the stream stays the
  /// one source of truth — an edit made anywhere re-renders the document without
  /// this screen copying the record.
  String? _activeId;

  /// A playbook that exists only in this screen: a template the trader picked
  /// and has not saved. It has no id, so it cannot come from the stream.
  AppStrategy? _draft;

  StrategyEditorMode _editorMode = StrategyEditorMode.write;
  bool _editorDetailsOnly = false;

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
          _accessibleRecords = items;
          if (_linkedRecord != null) {
            final latest = items
                .where((record) => record.id == _linkedRecord!.id)
                .firstOrNull;
            if (latest != null) _linkedRecord = latest;
            if (_isPublicContext && (latest == null || !latest.isPublic)) {
              _accessError = 'This record is no longer public.';
            }
          }
          _strategies = items
              .where((record) => RecordAccess.owns(record.userId))
              .toList();
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

  /// What the phone or grid has actually built for the current page slice.
  List<AppStrategy> get _visibleBatch {
    final List<AppStrategy> visible = _visible;
    if (visible.isEmpty) return const <AppStrategy>[];
    final int start = ((_currentPage - 1) * _pageSize).clamp(0, visible.length);
    return visible.skip(start).take(_pageSize).toList(growable: false);
  }

  AppStrategy? get _active {
    if (_linkedRecord?.id == _activeId) return _linkedRecord;
    final AppStrategy? draft = _draft;
    if (draft != null) return draft;
    final String? id = _activeId;
    if (id == null) return null;
    for (final AppStrategy s in _accessibleRecords) {
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
    _currentPage = 1;
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
  Future<void> _apply(AppLinkOpenRequest request) async {
    if (request.kind != AppLinkKind.strategy) return;
    final revision = ++_accessRevision;
    try {
      final record = await _repo.getById(request.id);
      if (!mounted || revision != _accessRevision) return;
      if (record == null ||
          !RecordAccess.canRead(
            record.userId,
            record.isPublic,
            publicContext: request.publicContext,
          )) {
        setState(
          () =>
              _accessError = 'This record is private, deleted, or unavailable.',
        );
        return;
      }
      if (request.editWriting &&
          (request.publicContext || !RecordAccess.owns(record.userId))) {
        setState(
          () => _accessError =
              'Only the owner can edit this record in their workspace.',
        );
        return;
      }
      setState(() {
        _accessError = null;
        _linkedRecord = record;
        _isPublicContext =
            request.publicContext || !RecordAccess.owns(record.userId);
      });
      if (request.editWriting) {
        _edit(record);
      } else {
        _open(record.id);
      }
    } catch (error) {
      if (mounted && revision == _accessRevision) {
        setState(
          () => _accessError = 'Could not open this record. Please retry.',
        );
      }
    }
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
    bool detailsOnly = false,
  }) {
    if (strategy.id.isNotEmpty && !RecordAccess.owns(strategy.userId)) return;
    setState(() {
      _editorMode = mode;
      _editorDetailsOnly = detailsOnly;
      _editorKey = GlobalKey<StrategyEditorScreenState>();
      _draft = strategy.id.isEmpty ? strategy : null;
      _activeId = strategy.id.isEmpty ? null : strategy.id;
      _view = _StrategyView.editor;
    });
    _announce();
  }

  void _backToIndex() {
    _accessError = null;
    _isPublicContext = false;
    _linkedRecord = null;
    _accessRevision++;
    if (widget.onReturnToOrigin != null) {
      widget.onReturnToOrigin!();
      return;
    }
    if (!mounted) return;
    setState(() {
      _draft = null;
      _activeId = null;
      _editorDetailsOnly = false;
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
      _editorDetailsOnly = false;
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
    final int liveCount = _strategies
        .where((AppStrategy s) => s.status == AppStrategyStatus.live)
        .length;
    final bool canCreate = await CustomerLimitations.checkCanCreateStrategy(
      context,
      currentLiveStrategyCount: liveCount,
    );
    if (!canCreate || !mounted) return;
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
    if (ref.id == 'ai_copilot' || ref.kind == AppLinkKind.aiCopilot) {
      widget.onOpenRef?.call(ref);
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
    final bool isPublic = ref.isPublicContext || _isPublicContext;
    final AppLinkRef forwarded = isPublic && !ref.isPublicContext
        ? ref.copyWith(isPublicContext: true)
        : ref;
    jump(forwarded);
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
      targets: <GlobalKey>[
        _fabKey,
        _bannerKey,
        _kpiBarKey,
        _filterBarKey,
        _gridKey,
      ],
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
              ? '1 draft playbook to finish'
              : '${drafts.length} draft playbooks to finish',
          icon: Icons.edit_note_rounded,
          intent: UiIntent.primary,
          badge: 'Draft',
          onTap: () => _edit(drafts.first),
        ),
      if (ready.isNotEmpty)
        _NextAction(
          label: ready.length == 1
              ? '1 testing playbook ready for review'
              : '${ready.length} testing playbooks ready for review',
          icon: Icons.insights_rounded,
          intent: UiIntent.bullish,
          badge: 'Ready',
          onTap: () => _openWithTab(ready.first.id, StrategyDetailTab.playbook),
        ),
      if (untested.isNotEmpty)
        _NextAction(
          label: untested.length == 1
              ? '1 playbook has no trades — file one'
              : '${untested.length} playbooks have no trades — file one',
          icon: Icons.add_link_rounded,
          intent: UiIntent.warning,
          badge: 'Untested',
          onTap: () => _openWithTab(untested.first.id, StrategyDetailTab.links),
        ),
    ];
  }

  Widget _notificationBannerStrip(BuildContext context) {
    if (_dismissedBanner) return const SizedBox.shrink();
    final List<_NextAction> actions = _nextActions;
    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      key: _bannerKey,
      child: DeskNotificationBanner(
        actions: <DeskNotificationAction>[
          for (final _NextAction a in actions)
            DeskNotificationAction(
              label: a.label,
              icon: a.icon,
              intent: a.intent,
              badge: a.badge,
              onTap: a.onTap,
            ),
        ],
        onDismiss: () => setState(() => _dismissedBanner = true),
        dismissLabel: 'Dismiss suggestions',
      ),
    );
  }

  Widget _executiveKpis(BuildContext context, {required double maxWidth}) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    final int totalCount = _strategies.length;
    final int liveCount = _strategies
        .where((AppStrategy s) => s.status == AppStrategyStatus.live)
        .length;
    final int testingCount = _strategies
        .where((AppStrategy s) => s.status == AppStrategyStatus.testing)
        .length;
    final int draftCount = _strategies
        .where((AppStrategy s) => s.status == AppStrategyStatus.draft)
        .length;
    final int activeCount = liveCount + testingCount;

    final List<AppStrategy> traded = _strategies
        .where((AppStrategy s) => s.trades > 0)
        .toList();
    traded.sort((AppStrategy a, AppStrategy b) => b.netPnl.compareTo(a.netPnl));
    final AppStrategy? topSetup = traded.isNotEmpty ? traded.first : null;

    int checklistDoneTotal = 0;
    int checklistItemsTotal = 0;
    int totalTrades = 0;
    for (final AppStrategy s in _strategies) {
      checklistDoneTotal += s.checklistDone;
      checklistItemsTotal += s.checklistTotal;
      totalTrades += s.trades;
    }
    final double adherenceRate = checklistItemsTotal > 0
        ? (checklistDoneTotal / checklistItemsTotal) * 100
        : (traded.isNotEmpty
              ? (traded
                        .map(
                          (AppStrategy s) =>
                              s.winRate > 1 ? s.winRate : s.winRate * 100,
                        )
                        .reduce((double a, double b) => a + b) /
                    traded.length)
              : 100.0);

    final double avgTargetR = traded.isNotEmpty
        ? traded
                  .map((AppStrategy s) => s.avgR)
                  .reduce((double a, double b) => a + b) /
              traded.length
        : 2.4;

    final DeskStatCardData kpi1 = DeskStatCardData(
      title: 'PLAYBOOK INVENTORY',
      customMetric: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: context.sp(theme.spacing.xxs),
        children: <Widget>[
          Text(
            '$activeCount Active',
            style: context.uiText.heading.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.foreground,
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          Text(
            'of $totalCount total',
            style: context.uiText.caption.copyWith(
              color: colors.foregroundSubtle,
            ),
          ),
        ],
      ),
      customBottom: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$liveCount Live',
              style: TextStyle(
                fontSize: 11,
                color: colors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              ' • ',
              style: TextStyle(color: colors.foregroundSubtle, fontSize: 11),
            ),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colors.warning,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$testingCount Testing',
              style: TextStyle(
                fontSize: 11,
                color: colors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              ' • ',
              style: TextStyle(color: colors.foregroundSubtle, fontSize: 11),
            ),
            Text(
              '$draftCount Draft',
              style: TextStyle(fontSize: 11, color: colors.foregroundSubtle),
            ),
          ],
        ),
      ),
    );

    final DeskStatCardData kpi2 = DeskStatCardData(
      title: 'BEST PERFORMING SETUP',
      customMetric: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            topSetup?.name ?? 'None yet',
            style: context.uiText.heading.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.foreground,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            topSetup != null
                ? AppTokens.signedMoney(topSetup.netPnl, decimals: 0)
                : '—',
            style: context.uiText.caption.copyWith(
              fontWeight: FontWeight.bold,
              color: topSetup != null
                  ? AppTokens.pl(context, topSetup.netPnl)
                  : colors.foregroundSubtle,
            ),
          ),
        ],
      ),
      customBottom: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(
            child: Text(
              'Win Rate: ${topSetup != null ? AppTokens.percent(topSetup.winRate > 1 ? topSetup.winRate : topSetup.winRate * 100, decimals: 0) : '—'}',
              style: context.uiText.caption.copyWith(
                color: colors.foregroundMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: colors.success.withValues(alpha: 0.12),
              borderRadius: context.radius(theme.radii.sm),
              border: Border.all(color: colors.success.withValues(alpha: 0.25)),
            ),
            child: Text(
              topSetup != null ? AppTokens.rr(topSetup.avgR) : '—',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: colors.success,
              ),
            ),
          ),
        ],
      ),
    );

    final DeskStatCardData kpi3 = DeskStatCardData(
      title: 'DISCIPLINE / RULE ADHERENCE',
      customMetric: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: context.sp(theme.spacing.xxs),
        children: <Widget>[
          Text(
            '${adherenceRate.toStringAsFixed(1)}%',
            style: context.uiText.heading.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.warning,
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          Text(
            'Follow-through',
            style: context.uiText.caption.copyWith(
              color: colors.foregroundSubtle,
            ),
          ),
        ],
      ),
      customBottom: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(
            child: Text(
              'Checklist logged',
              style: context.uiText.caption.copyWith(
                color: colors.foregroundMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              checklistItemsTotal > 0
                  ? '$checklistDoneTotal / $checklistItemsTotal checks'
                  : '$totalTrades trades logged',
              style: context.uiText.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.foreground,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );

    final DeskStatCardData kpi4 = DeskStatCardData(
      title: 'ALLOCATED CAPITAL & TARGET R:R',
      customMetric: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: context.sp(theme.spacing.xxs),
        children: <Widget>[
          Text(
            '$totalTrades Trades',
            style: context.uiText.heading.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.foreground,
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          Text(
            'in active play',
            style: context.uiText.caption.copyWith(
              color: colors.foregroundSubtle,
            ),
          ),
        ],
      ),
      customBottom: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(
            child: Text(
              'Target Reward / Risk',
              style: context.uiText.caption.copyWith(
                color: colors.foregroundMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '1 : ${avgTargetR.toStringAsFixed(1)} Avg R:R',
              style: context.uiText.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.success,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );

    return Container(
      key: _kpiBarKey,
      child: DeskStatsOverview(
        maxWidth: maxWidth,
        stats: <DeskStatCardData>[kpi1, kpi2, kpi3, kpi4],
      ),
    );
  }

  Widget _buildStatusSegmentButton({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return InkWell(
      borderRadius: context.radius(theme.radii.sm),
      onTap: onTap,
      child: Container(
        height: context.sz(28),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: context.sp(theme.spacing.sm)),
        decoration: BoxDecoration(
          color: isSelected ? colors.foreground : Colors.transparent,
          borderRadius: context.radius(theme.radii.sm),
        ),
        child: Text(
          '$label ($count)',
          style: context.uiText.caption.copyWith(
            color: isSelected ? colors.background : colors.foregroundMuted,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _controlsAndFiltersBar(
    BuildContext context, {
    required List<AppStrategy> batch,
    required List<AppStrategy> visible,
    required double maxWidth,
  }) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    final int totalCount = _strategies.length;
    final int liveCount = _strategies
        .where((AppStrategy s) => s.status == AppStrategyStatus.live)
        .length;
    final int testingCount = _strategies
        .where((AppStrategy s) => s.status == AppStrategyStatus.testing)
        .length;
    final int draftCount = _strategies
        .where((AppStrategy s) => s.status == AppStrategyStatus.draft)
        .length;
    final int retiredCount = _strategies
        .where((AppStrategy s) => s.status == AppStrategyStatus.retired)
        .length;

    final Widget titleAndCount = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: context.sp(theme.spacing.xs),
      children: <Widget>[
        Text('Playbooks', style: context.uiText.subheading),
        SizedBox(width: context.sp(theme.spacing.sm)),
        UiBadge(
          label: '${visible.length} total',
          variant: UiBadgeVariant.outline,
          size: UiSize.xs,
        ),
      ],
    );

    final Widget filterSegments = Container(
      height: context.sz(32),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: context.radius(theme.radii.md),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildStatusSegmentButton(
            label: 'All',
            count: totalCount,
            isSelected: _status == null,
            onTap: () => _updateFilter(() => _status = null),
          ),
          _buildStatusSegmentButton(
            label: 'Live',
            count: liveCount,
            isSelected: _status == AppStrategyStatus.live,
            onTap: () => _updateFilter(() => _status = AppStrategyStatus.live),
          ),
          _buildStatusSegmentButton(
            label: 'Testing',
            count: testingCount,
            isSelected: _status == AppStrategyStatus.testing,
            onTap: () =>
                _updateFilter(() => _status = AppStrategyStatus.testing),
          ),
          _buildStatusSegmentButton(
            label: 'Draft',
            count: draftCount,
            isSelected: _status == AppStrategyStatus.draft,
            onTap: () => _updateFilter(() => _status = AppStrategyStatus.draft),
          ),
          if (retiredCount > 0)
            _buildStatusSegmentButton(
              label: 'Archived',
              count: retiredCount,
              isSelected: _status == AppStrategyStatus.retired,
              onTap: () =>
                  _updateFilter(() => _status = AppStrategyStatus.retired),
            ),
        ],
      ),
    );

    final Widget tagsDropdown = DeskFilterDropdown(
      label: _tag == null ? 'All Tags' : '#$_tag',
      icon: Icons.tag_rounded,
      isActive: _tag != null,
      items: <UiMenuItem>[
        UiMenuItem(
          label: 'All Tags',
          icon: Icons.tag_rounded,
          onPressed: () => _updateFilter(() => _tag = null),
        ),
        for (final String t in StrategiesQuery.tagsOf(_strategies))
          UiMenuItem(
            label: '#$t',
            icon: Icons.tag_rounded,
            onPressed: () => _updateFilter(() => _tag = t),
          ),
      ],
    );

    final Widget tickersDropdown = DeskFilterDropdown(
      label: _ticker == null ? 'All Assets' : _ticker!,
      icon: Icons.candlestick_chart_outlined,
      isActive: _ticker != null,
      items: <UiMenuItem>[
        UiMenuItem(
          label: 'All Assets',
          icon: Icons.candlestick_chart_outlined,
          onPressed: () => _updateFilter(() => _ticker = null),
        ),
        for (final String tick in StrategiesQuery.tickersOf(_strategies))
          UiMenuItem(
            label: tick,
            icon: Icons.show_chart_rounded,
            onPressed: () => _updateFilter(() => _ticker = tick),
          ),
      ],
    );

    final Widget sortDropdown = DeskFilterDropdown(
      label: 'Sort: ${_sort.label.split(' ').first}',
      icon: Icons.sort_rounded,
      items: <UiMenuItem>[
        for (final AppStrategySort s in AppStrategySort.values)
          UiMenuItem(
            label: s.label,
            icon: Icons.sort_rounded,
            onPressed: () => _updateFilter(() => _sort = s),
          ),
      ],
    );

    final Widget viewToggle = DeskViewToggle(
      isGrid: _isGridView,
      onChanged: (bool grid) => setState(() => _isGridView = grid),
    );

    final bool isDesktop = maxWidth >= 1024;

    return Container(
      key: _filterBarKey,
      child: isDesktop
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        titleAndCount,
                        SizedBox(width: context.sp(theme.spacing.md)),
                        filterSegments,
                      ],
                    ),
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                Wrap(
                  spacing: context.sp(theme.spacing.xs),
                  runSpacing: context.sp(theme.spacing.xs),
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    tagsDropdown,
                    tickersDropdown,
                    sortDropdown,
                    viewToggle,
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: context.sp(theme.spacing.xs),
                  children: <Widget>[titleAndCount, viewToggle],
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      filterSegments,
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      tagsDropdown,
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      tickersDropdown,
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      sortDropdown,
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader({
    required String label,
    required int count,
    required Color accentColor,
    required IconData icon,
    bool isLive = false,
  }) {
    return DeskSectionHeader(
      title: label,
      countLabel: '$count',
      accentColor: accentColor,
    );
  }

  Widget _buildPlaybookCard(BuildContext context, AppStrategy strategy) {
    final int notes =
        _linkedNoteCounts[strategy.id] ?? strategy.linkedNoteIds.length;
    return PlaybookCard(
      strategy: strategy,
      linkedNoteCount: notes,
      onTap: () => _open(strategy.id),
      onToggleFavorite: () => _toggleFavorite(strategy),
      onEdit: () => _edit(strategy),
      onFileTrade: () => _openWithTab(strategy.id, StrategyDetailTab.links),
    );
  }

  Widget _buildPlaybooksContent(
    BuildContext context, {
    required List<AppStrategy> batch,
    required int columns,
    required double gap,
  }) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    if (batch.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xl)),
        child: const UiEmptyState(
          icon: Icons.auto_awesome_mosaic_outlined,
          title: 'No strategies found',
          message: 'Try adjusting your filters or create a new strategy.',
        ),
      );
    }

    if (!_isGridView) {
      return Column(
        children: <Widget>[
          for (final AppStrategy s in batch)
            Padding(
              padding: EdgeInsets.only(bottom: gap),
              child: AppStrategyNoteIndexRow(
                strategy: s,
                selected: s.id == _activeId,
                onTap: () => _open(s.id),
                onToggleFavorite: () => _toggleFavorite(s),
              ),
            ),
        ],
      );
    }

    if (_grouped && _status == null) {
      final List<AppStrategy> live = batch
          .where((AppStrategy s) => s.status == AppStrategyStatus.live)
          .toList();
      final List<AppStrategy> testing = batch
          .where((AppStrategy s) => s.status == AppStrategyStatus.testing)
          .toList();
      final List<AppStrategy> drafts = batch
          .where((AppStrategy s) => s.status == AppStrategyStatus.draft)
          .toList();
      final List<AppStrategy> retired = batch
          .where((AppStrategy s) => s.status == AppStrategyStatus.retired)
          .toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (live.isNotEmpty) ...<Widget>[
            _buildSectionHeader(
              label: 'Live Playbooks',
              count: live.length,
              accentColor: colors.success,
              icon: Icons.play_arrow_rounded,
              isLive: true,
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            _buildPlaybookCardGrid(context, live, columns: columns, gap: gap),
            SizedBox(height: context.sp(theme.spacing.lg)),
          ],
          if (testing.isNotEmpty) ...<Widget>[
            _buildSectionHeader(
              label: 'Testing / Forward Testing',
              count: testing.length,
              accentColor: colors.warning,
              icon: Icons.science_outlined,
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            _buildPlaybookCardGrid(
              context,
              testing,
              columns: columns,
              gap: gap,
            ),
            SizedBox(height: context.sp(theme.spacing.lg)),
          ],
          if (drafts.isNotEmpty) ...<Widget>[
            _buildSectionHeader(
              label: 'Drafts / Work In Progress',
              count: drafts.length,
              accentColor: colors.foregroundMuted,
              icon: Icons.edit_note_rounded,
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            _buildPlaybookCardGrid(context, drafts, columns: columns, gap: gap),
            SizedBox(height: context.sp(theme.spacing.lg)),
          ],
          if (retired.isNotEmpty) ...<Widget>[
            _buildSectionHeader(
              label: 'Archived / Retired',
              count: retired.length,
              accentColor: colors.foregroundSubtle,
              icon: Icons.inventory_2_outlined,
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            _buildPlaybookCardGrid(
              context,
              retired,
              columns: columns,
              gap: gap,
            ),
            SizedBox(height: context.sp(theme.spacing.lg)),
          ],
        ],
      );
    }

    return _buildPlaybookCardGrid(context, batch, columns: columns, gap: gap);
  }

  Widget _buildPlaybookCardGrid(
    BuildContext context,
    List<AppStrategy> items, {
    required int columns,
    required double gap,
  }) {
    if (columns == 1) {
      return Column(
        children: <Widget>[
          for (final AppStrategy s in items)
            Padding(
              padding: EdgeInsets.only(bottom: gap),
              child: _buildPlaybookCard(context, s),
            ),
        ],
      );
    }

    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < items.length; i += columns) {
      final List<AppStrategy> rowItems = items.sublist(
        i,
        (i + columns).clamp(0, items.length),
      );
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int j = 0; j < columns; j++) ...<Widget>[
                  if (j > 0) SizedBox(width: gap),
                  Expanded(
                    child: j < rowItems.length
                        ? _buildPlaybookCard(context, rowItems[j])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  // ── Surfaces ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_accessError != null) {
      return UiEmptyState(
        title: 'Record unavailable',
        message: _accessError,
        action: UiButton(label: 'Back', onPressed: _backToIndex),
      );
    }
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
    canEdit: !_isPublicContext && RecordAccess.owns(strategy.userId),
    isPublicContext: _isPublicContext,
    onClose: _backToIndex,
    onEdit: () =>
        _edit(strategy, mode: StrategyEditorMode.write, detailsOnly: true),
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
        _edit(strategy, mode: StrategyEditorMode.write, detailsOnly: false);
      }
    },
    onOpenLink: _openRef,
    onAttachToPost: widget.onAttachToPost,
  );

  Widget _editor(AppStrategy strategy) => StrategyEditorScreen(
    key: _editorKey,
    strategy: strategy,
    initialMode: _editorMode,
    detailsOnly: _editorDetailsOnly,
    onClose: _closeEditor,
    onDeleted: _backToIndex,
  );

  /// The redesigned strategies dashboard.
  Widget _index(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<AppStrategy> visible = _visible;
    final List<AppStrategy> batch = _visibleBatch;
    final double gutter = context.sp(theme.spacing.md);

    return Stack(
      key: const ValueKey<String>('strategy_index_root'),
      children: <Widget>[
        UiPage(
          scrollable: true,
          maxWidth: double.infinity,
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.keyP): _newPlaybook,
              const SingleActivator(LogicalKeyboardKey.keyG): () =>
                  setState(() => _isGridView = !_isGridView),
            },
            child: Focus(
              autofocus: true,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double maxWidth = constraints.maxWidth;
                  final int columns = maxWidth >= 1024
                      ? 3
                      : (maxWidth >= 640 ? 2 : 1);
                  final double gap = context.sp(theme.spacing.md);

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: gutter,
                      vertical: context.sp(theme.spacing.sm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _notificationBannerStrip(context),
                        SizedBox(height: context.sp(theme.spacing.md)),
                        _executiveKpis(context, maxWidth: maxWidth),
                        SizedBox(height: context.sp(theme.spacing.md)),
                        _controlsAndFiltersBar(
                          context,
                          batch: batch,
                          visible: visible,
                          maxWidth: maxWidth,
                        ),
                        SizedBox(height: context.sp(theme.spacing.md)),
                        Container(
                          key: _gridKey,
                          child: _buildPlaybooksContent(
                            context,
                            batch: batch,
                            columns: columns,
                            gap: gap,
                          ),
                        ),
                        if (visible.isNotEmpty) ...<Widget>[
                          SizedBox(height: context.sp(theme.spacing.md)),
                          DeskPaginationBar(
                            currentPage: _currentPage,
                            totalPages: (visible.length / _pageSize)
                                .ceil()
                                .clamp(1, 9999),
                            totalItems: visible.length,
                            pageSize: _pageSize,
                            itemLabel: 'playbooks',
                            onPageChanged: (int page) =>
                                setState(() => _currentPage = page),
                          ),
                        ],
                        SizedBox(height: context.sp(theme.spacing.xl)),
                        const DeskStatusBarFooter(
                          syncLabel:
                              'Workspace records · broker sync is not connected',
                          shortcutHints: <String>[
                            'Press P for new playbook',
                            '/ to search',
                            'G switch view',
                          ],
                        ),
                        SizedBox(
                          height: context.uiPageBottomInset + context.sz(72),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        // Floating Action Button on Bottom Right
        Positioned(
          right: gutter,
          bottom: MediaQuery.paddingOf(context).bottom + gutter,
          child: UiIconButton(
            key: _fabKey,
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
    this.badge,
  });

  final String label;
  final IconData icon;
  final UiIntent intent;
  final VoidCallback onTap;
  final String? badge;
}
