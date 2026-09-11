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
import 'journal_template_gallery.dart';

/// Which surface the journal destination is showing.
enum _JournalView { list, document, editor }

/// The trading journal — one index, two genuinely different surfaces.
///
/// **Desktop** is a workbench: a permanent, month-grouped index rail beside the
/// open entry. Moving between entries costs one click and never unloads the one
/// being read, which is what comparing two trades on the same plan actually
/// takes.
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
    this.onAttachToPost,
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
  final AppWritingPostAttachmentHandler? onAttachToPost;

  /// A record the shell wants opened — how a link from a note or a playbook
  /// lands on the right entry.
  final AppLinkOpenRequest? openRequest;

  @override
  State<JournalScreen> createState() => JournalScreenState();
}

class JournalScreenState extends State<JournalScreen> {
  /// Public entry point so host workspaces (like Writing Desk) can trigger
  /// new entry creation.
  void newEntry() => _newEntry();

  /// Public entry point for the unified Writing Desk help action.
  void showGuide() => _showGuide();

  void showGuideWithTargets(List<GlobalKey> targets) =>
      FeatureGuideSpotlight.show(
        context,
        feature: FeatureId.journal,
        steps: FeatureGuideSteps.journal,
        targets: targets,
        onStepAction: _onGuideStepAction,
      );

  /// Public entry points owned by the single global Writing Desk command bar.
  void setSearchQuery(String value) {
    if (_query == value || !mounted) return;
    _updateFilter(() => _query = value);
  }

  void showFilters() => _journalFilterBar().showFilters(context);

  void performGuideStep(FeatureGuideStep step) => _onGuideStepAction(step);

  static const int _pageSize = 12;

  final JournalRepository _repo = JournalRepositoryScope.repository;
  final AppLinkGraphService _links = AppLinkGraphScope.service;
  final GlobalKey _guideFilterKey = GlobalKey();

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

  /// Entry id → how many trader notes it is linked to, resolved through the
  /// graph so a card can show edges the entry record itself never stored. Over
  /// the whole journal, not the filtered slice: a link is a fact about the
  /// record, not about the current search.
  Map<String, int> get _linkedNoteCounts => <String, int>{
    for (final AppTrade t in _entries)
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

  AppJournalNoteFilterBar _journalFilterBar({
    bool compact = false,
    bool showSearch = true,
    bool showFilterControl = true,
    VoidCallback? onNew,
  }) => AppJournalNoteFilterBar(
    key: _guideFilterKey,
    compact: compact,
    showSearch: showSearch,
    showFilterControl: showFilterControl,
    query: _query,
    sort: _sort,
    outcome: _outcome,
    tag: _tag,
    ticker: _ticker,
    onlyUnwritten: _onlyUnwritten,
    onlyUnfiled: _onlyUnfiled,
    availableTags: JournalQuery.tagsOf(_entries),
    availableTickers: JournalQuery.tickersOf(_entries),
    onQueryChanged: (String v) => _updateFilter(() => _query = v),
    onOutcomeChanged: (AppOutcome? v) => _updateFilter(() => _outcome = v),
    onTagChanged: (String? v) => _updateFilter(() => _tag = v),
    onTickerChanged: (String? v) => _updateFilter(() => _ticker = v),
    onSortChanged: (AppJournalSort v) => _updateFilter(() => _sort = v),
    onOnlyUnwrittenChanged: (bool v) => _updateFilter(() => _onlyUnwritten = v),
    onOnlyUnfiledChanged: (bool v) => _updateFilter(() => _onlyUnfiled = v),
    onNew: onNew,
  );

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
      _activeId = null;
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
  ///
  /// This is also the guide's "Log a trade" step: it returns to the library
  /// unchanged when the trader backs out of the gallery.
  Future<void> _newEntry() async {
    final AppJournalTemplate? template = await showJournalTemplateGallery(
      context,
    );
    if (template == null || !mounted) return;
    _edit(template.toDraft());
  }

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

  // ── Guide ──────────────────────────────────────────────────────────────────

  /// Opens the journal walkthrough, at any time, from the header help action or
  /// the banner's "Show guide" button. The owning screen resolves each step's
  /// action into real navigation below.
  void _showGuide() {
    FeatureGuideSpotlight.show(
      context,
      feature: FeatureId.journal,
      steps: FeatureGuideSteps.journal,
      targets: <GlobalKey>[_guideFilterKey],
      onStepAction: _onGuideStepAction,
    );
  }

  /// Maps a guide step to the real surface it describes. The sheet already marks
  /// the step done when its action button is pressed; this only navigates — it
  /// never fakes completion, and a step with nothing to act on navigates nowhere
  /// and says so.
  void _onGuideStepAction(FeatureGuideStep step) {
    switch (step.id) {
      case 'log':
        _newEntry();
      case 'file':
        _fileUnderPlaybook();
      case 'checklist':
        _openChecklist();
      case 'attach':
        _openAttach();
      case 'outcome':
        _markOutcome();
      default:
        break;
    }
  }

  /// "File under a playbook" — filing happens on the entry's Links surface (the
  /// document's linked-records aside), so the step lands on the entry most in
  /// need of one: the newest unfiled entry, then the newest entry.
  void _fileUnderPlaybook() {
    final AppTrade? target = _firstWhere(
      (AppTrade t) => t.strategyId == null || t.strategyId!.isEmpty,
    );
    if (target == null) {
      UiToast.info(
        context,
        title: 'Nothing to file',
        message: 'Log a trade first, then file it under a playbook.',
      );
      return;
    }
    if (_activeId == target.id) return;
    _open(target.id);
  }

  /// "Fill the checklist and psychology sections" — psychology is the editor's
  /// discipline slider, and the checklist lives in the write-up the editor owns
  /// the numbers for. Land on the newest entry, open in the editor.
  void _openChecklist() {
    final AppTrade? target = _firstWhere((AppTrade _) => true);
    if (target == null) {
      UiToast.info(
        context,
        title: 'Nothing to review yet',
        message: 'Log a trade first, then score its process.',
      );
      return;
    }
    _edit(target);
  }

  /// "Attach screenshots and tag it" — tags are the editor's tag field, and the
  /// write-up (where charts attach) is reached from the same entry. Land on the
  /// newest entry, open in the editor.
  void _openAttach() {
    final AppTrade? target = _firstWhere((AppTrade _) => true);
    if (target == null) {
      UiToast.info(
        context,
        title: 'Nothing to attach to yet',
        message: 'Log a trade first, then attach the chart you saw.',
      );
      return;
    }
    _edit(target);
  }

  /// "Mark the outcome" — the outcome is computed from the exit the editor
  /// collects, so the step lands on an open trade, ready to be closed out. If
  /// nothing is open there is nothing to mark, and the step stays put.
  void _markOutcome() {
    final AppTrade? target = _firstWhere((AppTrade t) => t.isOpen);
    if (target == null) {
      UiToast.info(
        context,
        title: 'No open trades',
        message: 'Every entry already has an outcome.',
      );
      return;
    }
    _edit(target);
  }

  /// First entry matching [test], in the repository's recently-first order — so
  /// "first" means "most recent", which is the one the trader is most likely to
  /// mean.
  AppTrade? _firstWhere(bool Function(AppTrade t) test) {
    for (final AppTrade t in _entries) {
      if (test(t)) return t;
    }
    return null;
  }

  // ── Next-best action ───────────────────────────────────────────────────────

  /// The pipeline nudges shown as compact chips between the header and the list.
  ///
  /// Derived from the **whole journal** (`_entries`, the repository stream
  /// already sorted recent-first) plus the link graph — never from the filtered
  /// slice, because "2 entries unfiled" is true of the journal even while a
  /// search narrows what is on screen. Ordered Execute → Review:
  ///
  ///  1. Entries not filed under a playbook → open the newest on its document,
  ///     where the links aside files it.
  ///  2. Open trades → open the newest in the editor, where the outcome is
  ///     computed from the exit.
  ///  3. Trades with no review note → open the newest on its document, where
  ///     notes attach.
  ///
  /// Empty while the stream is still loading or when there is nothing to act on,
  /// so the row never advertises a zero.
  List<_NextAction> get _nextActions {
    if (_loading) return const <_NextAction>[];
    final List<AppTrade> unfiled = _entries
        .where((AppTrade t) => t.strategyId == null || t.strategyId!.isEmpty)
        .toList(growable: false);
    final List<AppTrade> open = _entries
        .where((AppTrade t) => t.isOpen)
        .toList(growable: false);
    final List<AppTrade> unreviewed = _entries
        .where((AppTrade t) => _graph.bundleForJournal(t).notes.isEmpty)
        .toList(growable: false);

    return <_NextAction>[
      if (unfiled.isNotEmpty)
        _NextAction(
          label: unfiled.length == 1
              ? '1 entry not filed under a playbook'
              : '${unfiled.length} entries not filed under a playbook',
          icon: Icons.folder_off_outlined,
          intent: UiIntent.info,
          onTap: () => _open(unfiled.first.id),
        ),
      if (open.isNotEmpty)
        _NextAction(
          label: open.length == 1
              ? '1 open trade to close out'
              : '${open.length} open trades to close out',
          icon: Icons.schedule_rounded,
          intent: UiIntent.warning,
          onTap: () => _edit(open.first),
        ),
      if (unreviewed.isNotEmpty)
        _NextAction(
          label: unreviewed.length == 1
              ? '1 trade with no review note'
              : '${unreviewed.length} trades with no review note',
          icon: Icons.edit_note_rounded,
          intent: UiIntent.primary,
          onTap: () => _open(unreviewed.first.id),
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

  /// Month headers only make sense over a chronological order. Over a list sorted
  /// by P/L they would be lying about the grouping.
  bool get _chronological =>
      _sort == AppJournalSort.recentFirst ||
      _sort == AppJournalSort.oldestFirst;

  @override
  Widget build(BuildContext context) {
    final AppTrade? active = _active;

    // The editor is a full-surface step on every width: it owns its own
    // save-or-discard decision and must not share the workbench's pane.
    if (_view == _JournalView.editor && active != null) {
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

    if (_view == _JournalView.document && active != null) {
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

  Widget _document(AppTrade entry) => JournalEntryScreen(
    key: ValueKey<String>('journal_document_${entry.id}'),
    entry: entry,
    onClose: _backToIndex,
    onEdit: () => _edit(entry, mode: JournalEditorMode.write),
    onEditWriting: () {
      if (widget.onOpenWriting != null) {
        widget.onOpenWriting!(
          AppLinkRef(
            kind: AppLinkKind.journal,
            id: entry.id,
            title: entry.displayTitle,
          ),
        );
      } else {
        _edit(entry, mode: JournalEditorMode.write);
      }
    },
    onOpenLink: _openRef,
    onAttachToPost: widget.onAttachToPost,
  );

  Widget _editor(AppTrade entry) => JournalEditorScreen(
    key: _editorKey,
    entry: entry,
    initialMode: _editorMode,
    detailsOnly: false,
    onClose: _closeEditor,
    onDeleted: _backToIndex,
  );

  /// The index: numbers, then one search field, then the entries. The
  /// stat strip and filters scroll away with the list.
  Widget _index(BuildContext context) {
    final UiTheme theme = context.ui;
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
              header: _indexHeader(context, batch: batch, visible: visible),
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
        if (!context.uiRes.isDesktop && !AppWritingDeskScope.isHosted(context))
          Positioned(
            right: gutter,
            bottom: MediaQuery.paddingOf(context).bottom + gutter,
            child: UiIconButton(
              key: const ValueKey<String>('journal_new_entry_fab'),
              icon: Icons.add_rounded,
              variant: UiVariant.primary,
              size: UiSize.lg,
              tooltip: 'New entry',
              onPressed: _newEntry,
            ),
          ),
      ],
    );
  }

  Widget _indexHeader(
    BuildContext context, {
    required List<AppTrade> batch,
    required List<AppTrade> visible,
  }) {
    final UiTheme theme = context.ui;
    final double gutter = context.sp(theme.spacing.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(height: context.sp(theme.spacing.xs)),
        _journalFilterBar(
          showSearch: !AppWritingDeskScope.isHosted(context),
          showFilterControl: !AppWritingDeskScope.isHosted(context),
          onNew:
              context.uiRes.isDesktop && !AppWritingDeskScope.isHosted(context)
              ? _newEntry
              : null,
        ),
        SizedBox(height: gutter),
        _nextActionChips(context),
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
    );
  }
}

/// One pipeline nudge in the "next best action" chip row. Private data, computed
/// by [_JournalScreenState._nextActions] from the live repository stream and
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
