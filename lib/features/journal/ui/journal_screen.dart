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

import '../data/journal_repository.dart';
import '../data/journal_templates.dart';
import 'journal_editor_screen.dart';
import 'journal_entry_screen.dart';
import 'journal_template_gallery.dart';

/// Which surface the journal destination is showing.
enum _JournalView { list, document, editor }

/// Presentation mode for the journal entries: cards grid vs table spreadsheet.
enum _ViewMode { cards, table }

/// The redesigned trading journal & playbook dashboard.
///
/// Implements the complete dashboard experience:
/// - Actionable notification pills (unfiled playbooks, open trades, unreviewed notes)
/// - 4 dynamic performance metric cards (Month Net Realized, Win Rate, Profit Factor, Execution Discipline)
/// - Date navigator (Month picker & previous/next controls)
/// - View toggle (Responsive card grid vs sortable table spreadsheet)
/// - Filter bar with outcome pills, playbook selector, asset/ticker selector, and search
/// - Tailwind-spec cards with profit/loss indicators, R-multiples, checklist status, and outlier glow
/// - Dedicated bottom-right floating action button for logging trades
/// - Updated Spotlight Guidelines targeting the floating button, notification pills, discipline card, and filter controls
/// - Fully responsive across mobile, tablet, and desktop form factors
class JournalScreen extends StatefulWidget {
  const JournalScreen({
    super.key,
    this.onSubpageChanged,
    this.onReturnToOrigin,
    this.onOpenRef,
    this.onOpenWriting,
    this.onAttachToPost,
    this.openRequest,
  });

  final void Function(String? title, IconData? icon, VoidCallback? onBack)?
  onSubpageChanged;

  final void Function(AppLinkRef ref)? onOpenRef;
  final ValueChanged<AppLinkRef>? onOpenWriting;
  final AppWritingPostAttachmentHandler? onAttachToPost;

  final AppLinkOpenRequest? openRequest;

  final VoidCallback? onReturnToOrigin;

  @override
  State<JournalScreen> createState() => JournalScreenState();
}

class JournalScreenState extends State<JournalScreen> {
  /// The saved record currently displayed, for browser history and sharing.
  AppLinkRef? get openedRef {
    final record = _active;
    if (_view == _JournalView.list || record == null || record.id.isEmpty) {
      return null;
    }
    return AppLinkRef(
      kind: AppLinkKind.journal,
      id: record.id,
      title: record.ticker,
      isPublicContext: _isPublicContext,
    );
  }

  /// Public entry point so host workspaces can trigger new entry creation.
  void newEntry() => _newEntry();

  /// Public entry point for the unified Writing Desk help action.
  void showGuide() {
    FeatureGuideSpotlight.show(
      context,
      feature: FeatureId.journal,
      steps: FeatureGuideSteps.journal,
      targets: <GlobalKey>[
        _fabKey,
        _notificationBarKey,
        _disciplineStatKey,
        _filterBarKey,
        _outcomesKey,
      ],
      onStepAction: _onGuideStepAction,
    );
  }

  void showGuideWithTargets(List<GlobalKey> targets) => showGuide();

  /// Public entry points owned by command bar / shortcuts.
  void setSearchQuery(String value) {
    if (_query == value || !mounted) return;
    _updateFilter(() => _query = value);
  }

  void showFilters() => _openFiltersDrawer(context);

  void performGuideStep(FeatureGuideStep step) => _onGuideStepAction(step);

  static const int _itemsPerPage = 12;

  final JournalRepository _repo = JournalRepositoryScope.repository;
  final AppLinkGraphService _links = AppLinkGraphScope.service;

  // Spotlight Guidelines Target Keys
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _notificationBarKey = GlobalKey();
  final GlobalKey _disciplineStatKey = GlobalKey();
  final GlobalKey _filterBarKey = GlobalKey();
  final GlobalKey _outcomesKey = GlobalKey();

  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<List<AppTrade>>? _sub;
  StreamSubscription<AppLinkGraph>? _graphSub;

  List<AppTrade> _entries = const <AppTrade>[];
  List<AppTrade> _accessibleRecords = [];
  AppTrade? _linkedRecord;
  String? _accessError;
  int _accessRevision = 0;
  late AppLinkGraph _graph = _links.current;
  bool _loading = true;

  String _query = '';
  AppOutcome? _outcome;
  String? _tag;
  String? _ticker;
  String? _strategyId;
  bool _onlyUnwritten = false;
  bool _onlyUnfiled = false;
  AppJournalSort _sort = AppJournalSort.recentFirst;

  DateTime? _selectedMonth;
  _ViewMode _viewMode = _ViewMode.cards;
  int _currentPage = 1;
  bool _dismissedSuggestions = false;

  _JournalView _view = _JournalView.list;
  bool _isPublicContext = false;
  String? _activeId;
  AppTrade? _draft;
  JournalEditorMode _editorMode = JournalEditorMode.write;
  bool _editorDetailsOnly = false;

  GlobalKey<JournalEditorScreenState> _editorKey =
      GlobalKey<JournalEditorScreenState>();

  @override
  void initState() {
    super.initState();
    _sub = _repo.watchAll().listen(
      (List<AppTrade> entries) {
        if (!mounted) return;
        setState(() {
          _accessibleRecords = entries;
          if (_linkedRecord != null) {
            final latest = entries
                .where((record) => record.id == _linkedRecord!.id)
                .firstOrNull;
            if (latest != null) _linkedRecord = latest;
            if (_isPublicContext && (latest == null || !latest.isPublic)) {
              _accessError = 'This record is no longer public.';
            }
          }
          _entries = entries
              .where((record) => RecordAccess.owns(record.userId))
              .toList();
          _loading = false;
          if (_selectedMonth == null && entries.isNotEmpty) {
            final DateTime newest = entries.first.sortDate;
            _selectedMonth = DateTime(newest.year, newest.month);
          }
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _apply(request));
    }
  }

  @override
  void didUpdateWidget(JournalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final AppLinkOpenRequest? request = widget.openRequest;
    if (request != null && request != oldWidget.openRequest) _apply(request);
    if (oldWidget.onSubpageChanged != widget.onSubpageChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _graphSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ── Derived state ──────────────────────────────────────────────────────────

  List<AppTrade> get _monthScopedEntries {
    if (_selectedMonth == null) return _entries;
    return _entries
        .where(
          (AppTrade t) =>
              t.sortDate.year == _selectedMonth!.year &&
              t.sortDate.month == _selectedMonth!.month,
        )
        .toList(growable: false);
  }

  List<AppTrade> get _visible => JournalQuery.apply(
    _monthScopedEntries,
    query: _query,
    outcome: _outcome,
    tag: _tag,
    ticker: _ticker,
    strategyId: _strategyId,
    onlyUnwritten: _onlyUnwritten,
    onlyUnfiled: _onlyUnfiled,
    sort: _sort,
  );

  List<AppTrade> get _pageBatch {
    final List<AppTrade> visible = _visible;
    if (visible.isEmpty) return const <AppTrade>[];
    final int start = ((_currentPage - 1) * _itemsPerPage).clamp(
      0,
      visible.length,
    );
    return visible.skip(start).take(_itemsPerPage).toList(growable: false);
  }

  Map<String, int> get _linkedNoteCounts => <String, int>{
    for (final AppTrade t in _entries)
      t.id: _graph.bundleForJournal(t).notes.length,
  };

  AppTrade? get _active {
    if (_linkedRecord?.id == _activeId) return _linkedRecord;
    final AppTrade? draft = _draft;
    if (draft != null) return draft;
    final String? id = _activeId;
    if (id == null) return null;
    for (final AppTrade t in _accessibleRecords) {
      if (t.id == id) return t;
    }
    return null;
  }

  bool get _hasActiveFilters =>
      _query.trim().isNotEmpty ||
      _outcome != null ||
      _tag != null ||
      _ticker != null ||
      _strategyId != null ||
      _onlyUnwritten ||
      _onlyUnfiled;

  void _updateFilter(VoidCallback update) => setState(() {
    update();
    _currentPage = 1;
  });

  void _clearFilters() => _updateFilter(() {
    _query = '';
    _searchController.clear();
    _outcome = null;
    _tag = null;
    _ticker = null;
    _strategyId = null;
    _onlyUnwritten = false;
    _onlyUnfiled = false;
  });

  List<DateTime> get _availableMonths {
    final Set<String> seen = <String>{};
    final List<DateTime> months = <DateTime>[];
    for (final AppTrade t in _entries) {
      final String key = '${t.sortDate.year}-${t.sortDate.month}';
      if (seen.add(key)) {
        months.add(DateTime(t.sortDate.year, t.sortDate.month));
      }
    }
    months.sort((DateTime a, DateTime b) => b.compareTo(a));
    return months;
  }

  void _prevMonth() {
    if (_selectedMonth == null) {
      if (_entries.isNotEmpty) {
        final DateTime newest = _entries.first.sortDate;
        _selectedMonth = DateTime(newest.year, newest.month - 1);
      }
    } else {
      _selectedMonth = DateTime(
        _selectedMonth!.year,
        _selectedMonth!.month - 1,
      );
    }
    setState(() => _currentPage = 1);
  }

  void _nextMonth() {
    if (_selectedMonth == null) {
      if (_entries.isNotEmpty) {
        final DateTime newest = _entries.first.sortDate;
        _selectedMonth = DateTime(newest.year, newest.month + 1);
      }
    } else {
      _selectedMonth = DateTime(
        _selectedMonth!.year,
        _selectedMonth!.month + 1,
      );
    }
    setState(() => _currentPage = 1);
  }

  static String _monthLabel(DateTime date) {
    const List<String> months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  static String _monthShort(int month) {
    const List<String> list = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return list[(month - 1).clamp(0, 11)];
  }

  // ── Navigation between surfaces ────────────────────────────────────────────

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

  Future<void> _apply(AppLinkOpenRequest request) async {
    if (request.kind != AppLinkKind.journal) return;
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
    bool detailsOnly = false,
  }) {
    if (entry.id.isNotEmpty && !RecordAccess.owns(entry.userId)) return;
    setState(() {
      _editorMode = mode;
      _editorDetailsOnly = detailsOnly;
      _editorKey = GlobalKey<JournalEditorScreenState>();
      _draft = entry.id.isEmpty ? entry : null;
      _activeId = entry.id.isEmpty ? null : entry.id;
      _view = _JournalView.editor;
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
      _view = _JournalView.list;
    });
    _announce();
  }

  void _requestEditorClose() => _editorKey.currentState?.close();

  void _closeEditor(AppTrade? saved) {
    if (!mounted) return;
    setState(() {
      _draft = null;
      _editorDetailsOnly = false;
      if (saved != null) _activeId = saved.id;
      _view = saved == null && _activeId == null
          ? _JournalView.list
          : _JournalView.document;
    });
    _announce();
  }

  Future<void> _newEntry() async {
    final AppJournalTemplate? template = await showJournalTemplateGallery(
      context,
    );
    if (template == null || !mounted) return;
    _edit(template.toDraft());
  }

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
    final bool isPublic = ref.isPublicContext || _isPublicContext;
    final AppLinkRef forwarded = isPublic && !ref.isPublicContext
        ? ref.copyWith(isPublicContext: true)
        : ref;
    jump(forwarded);
  }

  // ── Guide Step Actions ─────────────────────────────────────────────────────

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

  AppTrade? _firstWhere(bool Function(AppTrade t) test) {
    for (final AppTrade t in _entries) {
      if (test(t)) return t;
    }
    return null;
  }

  Future<void> _openFiltersDrawer(BuildContext context) async {
    final List<String> tickers = JournalQuery.tickersOf(_entries);
    final List<String> tags = JournalQuery.tagsOf(_entries);

    await UiDrawer.show<void>(
      context,
      title: 'Filter Journal',
      child: StatefulBuilder(
        builder: (BuildContext panelCtx, StateSetter setModalState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              UiField(
                label: 'Outcome',
                child: UiSelect<String>(
                  value: _outcome?.name ?? 'all',
                  onChanged: (String val) {
                    _updateFilter(() {
                      _outcome = val == 'all'
                          ? null
                          : AppOutcome.values.byName(val);
                    });
                    setModalState(() {});
                  },
                  options: <UiOption<String>>[
                    const UiOption<String>(value: 'all', label: 'Any outcome'),
                    for (final AppOutcome o in AppOutcome.values)
                      UiOption<String>(
                        value: o.name,
                        label: AppTokens.outcomeLabel(o),
                      ),
                  ],
                ),
              ),
              UiGap.v(context.uiSpace.md),
              UiField(
                label: 'Sort by',
                child: UiSelect<AppJournalSort>(
                  value: _sort,
                  onChanged: (AppJournalSort val) {
                    _updateFilter(() => _sort = val);
                    setModalState(() {});
                  },
                  options: <UiOption<AppJournalSort>>[
                    for (final AppJournalSort s in AppJournalSort.values)
                      UiOption<AppJournalSort>(value: s, label: s.label),
                  ],
                ),
              ),
              if (tickers.isNotEmpty) ...<Widget>[
                UiGap.v(context.uiSpace.md),
                UiField(
                  label: 'Instrument',
                  child: UiSelect<String>(
                    value: _ticker ?? 'all',
                    onChanged: (String val) {
                      _updateFilter(() => _ticker = val == 'all' ? null : val);
                      setModalState(() {});
                    },
                    options: <UiOption<String>>[
                      const UiOption<String>(
                        value: 'all',
                        label: 'Any instrument',
                      ),
                      for (final String s in tickers)
                        UiOption<String>(value: s, label: s),
                    ],
                  ),
                ),
              ],
              if (tags.isNotEmpty) ...<Widget>[
                UiGap.v(context.uiSpace.md),
                UiField(
                  label: 'Tag',
                  child: UiSelect<String>(
                    value: _tag ?? 'all',
                    onChanged: (String val) {
                      _updateFilter(() => _tag = val == 'all' ? null : val);
                      setModalState(() {});
                    },
                    options: <UiOption<String>>[
                      const UiOption<String>(value: 'all', label: 'Any tag'),
                      for (final String t in tags)
                        UiOption<String>(value: t, label: '#$t'),
                    ],
                  ),
                ),
              ],
              UiGap.v(context.uiSpace.md),
              Text('Review filters', style: context.uiText.label),
              UiGap.v(context.uiSpace.xs),
              Wrap(
                spacing: context.sp(context.uiSpace.xs),
                runSpacing: context.sp(context.uiSpace.xs),
                children: <Widget>[
                  UiBadge(
                    label: 'Needs write-up',
                    icon: Icons.edit_note_rounded,
                    intent: UiIntent.warning,
                    variant: _onlyUnwritten
                        ? UiBadgeVariant.solid
                        : UiBadgeVariant.outline,
                    onTap: () {
                      _updateFilter(() => _onlyUnwritten = !_onlyUnwritten);
                      setModalState(() {});
                    },
                  ),
                  UiBadge(
                    label: 'Unfiled',
                    icon: Icons.folder_off_outlined,
                    intent: UiIntent.info,
                    variant: _onlyUnfiled
                        ? UiBadgeVariant.solid
                        : UiBadgeVariant.outline,
                    onTap: () {
                      _updateFilter(() => _onlyUnfiled = !_onlyUnfiled);
                      setModalState(() {});
                    },
                  ),
                ],
              ),
              UiGap.v(context.uiSpace.xl),
              UiButton(
                label: 'Clear all filters',
                variant: UiVariant.outline,
                onPressed: () {
                  _clearFilters();
                  setModalState(() {});
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Build Methods ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_accessError != null) {
      return UiEmptyState(
        title: 'Record unavailable',
        message: _accessError,
        action: UiButton(label: 'Back', onPressed: _backToIndex),
      );
    }
    final AppTrade? active = _active;

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

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyN): _newEntry,
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          key: const ValueKey<String>('journal_dashboard_stack'),
          children: <Widget>[
            UiPage(scrollable: true, child: _buildDashboardContent(context)),
            _buildFloatingActionButton(context),
          ],
        ),
      ),
    );
  }

  Widget _document(AppTrade entry) => JournalEntryScreen(
    key: ValueKey<String>('journal_document_${entry.id}'),
    entry: entry,
    canEdit: !_isPublicContext && RecordAccess.owns(entry.userId),
    isPublicContext: _isPublicContext,
    onClose: _backToIndex,
    onEdit: () =>
        _edit(entry, mode: JournalEditorMode.write, detailsOnly: true),
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
        _edit(entry, mode: JournalEditorMode.write, detailsOnly: false);
      }
    },
    onOpenLink: _openRef,
    onAttachToPost: widget.onAttachToPost,
  );

  Widget _editor(AppTrade entry) => JournalEditorScreen(
    key: _editorKey,
    entry: entry,
    initialMode: _editorMode,
    detailsOnly: _editorDetailsOnly,
    onClose: _closeEditor,
    onDeleted: _backToIndex,
  );

  Widget _buildDashboardContent(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<AppTrade> periodTrades = _monthScopedEntries;
    final List<AppTrade> visible = _visible;
    final List<AppTrade> batch = _pageBatch;
    final double gap = context.sp(theme.spacing.md);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(height: context.sp(theme.spacing.xs)),
            // 1. Quick Notification Bar (Actionable Pills)
            _quickNotificationBar(context),
            SizedBox(height: gap),

            // 2. Quick Stats Overview (4 Metric Cards)
            _quickStatsOverview(context, periodTrades),
            SizedBox(height: gap),

            // 3. Journal Header & Control Bar
            _journalControlBar(
              context,
              periodTrades: periodTrades,
              visible: visible,
              maxWidth: constraints.maxWidth,
            ),
            SizedBox(height: gap),

            // 4. Section Divider
            _sectionHeadingLabel(context),
            SizedBox(height: context.sp(theme.spacing.sm)),

            // 5. Entries Content (Cards Grid or Table Spreadsheet)
            if (_loading)
              _buildLoadingState(context)
            else if (visible.isEmpty)
              _buildEmptyState(context)
            else if (_viewMode == _ViewMode.table &&
                constraints.maxWidth >= context.sz(600))
              _buildTableView(context, batch)
            else
              _buildCardsGridView(context, batch, constraints.maxWidth),

            // 6. Pagination Bar
            if (!_loading && visible.isNotEmpty) ...<Widget>[
              SizedBox(height: gap),
              _paginationBar(context, visible.length),
            ],

            // 7. Broker Status Bar Footer
            _statusBarFooter(context),
            SizedBox(height: context.uiPageBottomInset + context.sz(48)),
          ],
        );
      },
    );
  }

  // ── 1. Actionable Notification Pills ───────────────────────────────────────

  Widget _quickNotificationBar(BuildContext context) {
    if (_loading || _entries.isEmpty || _dismissedSuggestions) {
      return const SizedBox.shrink();
    }

    final List<AppTrade> unfiled = _entries
        .where((AppTrade t) => t.strategyId == null || t.strategyId!.isEmpty)
        .toList(growable: false);
    final List<AppTrade> open = _entries
        .where((AppTrade t) => t.isOpen)
        .toList(growable: false);
    final List<AppTrade> unreviewed = _entries
        .where((AppTrade t) => _graph.bundleForJournal(t).notes.isEmpty)
        .toList(growable: false);

    if (unfiled.isEmpty && open.isEmpty && unreviewed.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      key: _notificationBarKey,
      child: DeskNotificationBanner(
        actions: <DeskNotificationAction>[
          if (unfiled.isNotEmpty)
            DeskNotificationAction(
              label: '${unfiled.length} entries not filed under a playbook',
              icon: Icons.sell_outlined,
              intent: UiIntent.info,
              badge: _onlyUnfiled ? 'Filtered' : null,
              onTap: () => _updateFilter(() => _onlyUnfiled = !_onlyUnfiled),
            ),
          if (open.isNotEmpty)
            DeskNotificationAction(
              label: '${open.length} open trades to close out',
              icon: Icons.schedule_rounded,
              intent: UiIntent.warning,
              badge: 'Active',
              onTap: () => _updateFilter(() {
                _outcome = _outcome == AppOutcome.open ? null : AppOutcome.open;
              }),
            ),
          if (unreviewed.isNotEmpty)
            DeskNotificationAction(
              label: '${unreviewed.length} trades with no review note',
              icon: Icons.edit_note_rounded,
              intent: UiIntent.primary,
              badge: _onlyUnwritten ? 'Filtered' : null,
              onTap: () =>
                  _updateFilter(() => _onlyUnwritten = !_onlyUnwritten),
            ),
        ],
        onDismiss: () => setState(() => _dismissedSuggestions = true),
        dismissLabel: 'Dismiss suggestions',
      ),
    );
  }

  // ── 2. Performance Metrics Strip (4 Cards) ─────────────────────────────────

  Widget _quickStatsOverview(
    BuildContext context,
    List<AppTrade> periodTrades,
  ) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    final double netPnl = periodTrades
        .where((AppTrade t) => !t.isOpen)
        .fold(0.0, (double sum, AppTrade t) => sum + t.pnl);
    final double totalR = periodTrades
        .where((AppTrade t) => t.rMultiple != null)
        .fold(0.0, (double sum, AppTrade t) => sum + t.rMultiple!);
    final double grossWins = periodTrades
        .where((AppTrade t) => t.pnl > 0)
        .fold(0.0, (double sum, AppTrade t) => sum + t.pnl);
    final double grossLosses = periodTrades
        .where((AppTrade t) => t.pnl < 0)
        .fold(0.0, (double sum, AppTrade t) => sum + t.pnl.abs());
    final int closedCount = periodTrades
        .where((AppTrade t) => !t.isOpen)
        .length;
    final double taxAndCharges = closedCount * 125.0;
    final double grossDisplay = netPnl >= 0
        ? netPnl + taxAndCharges
        : netPnl - taxAndCharges;

    final int wins = periodTrades
        .where((AppTrade t) => t.outcome == AppOutcome.win)
        .length;
    final int losses = periodTrades
        .where((AppTrade t) => t.outcome == AppOutcome.loss)
        .length;
    final int breakeven = periodTrades
        .where((AppTrade t) => t.outcome == AppOutcome.breakeven)
        .length;
    final int totalDecided = wins + losses;
    final double winRate = totalDecided > 0 ? (wins / totalDecided) * 100 : 0.0;

    final List<AppTrade> wonTrades = periodTrades
        .where(
          (AppTrade t) => t.outcome == AppOutcome.win && t.rMultiple != null,
        )
        .toList(growable: false);
    final List<AppTrade> lostTrades = periodTrades
        .where(
          (AppTrade t) => t.outcome == AppOutcome.loss && t.rMultiple != null,
        )
        .toList(growable: false);
    final double avgWinR = wonTrades.isNotEmpty
        ? wonTrades.fold(0.0, (double sum, AppTrade t) => sum + t.rMultiple!) /
              wonTrades.length
        : 0.0;
    final double avgLossR = lostTrades.isNotEmpty
        ? lostTrades.fold(
                0.0,
                (double sum, AppTrade t) => sum + t.rMultiple!.abs(),
              ) /
              lostTrades.length
        : 0.0;

    final double profitFactor = grossLosses > 0
        ? (grossWins / grossLosses)
        : (grossWins > 0 ? 99.0 : 0.0);
    final String pfRating = profitFactor >= 2.0
        ? 'Excellent'
        : (profitFactor >= 1.5
              ? 'Good'
              : (profitFactor >= 1.0 ? 'Moderate' : 'Underperforming'));

    final int scoredCount = periodTrades
        .where((AppTrade t) => t.psychologyScore != null)
        .length;
    final double disciplineScore = scoredCount > 0
        ? (periodTrades
                      .where((AppTrade t) => t.psychologyScore != null)
                      .fold(
                        0,
                        (int sum, AppTrade t) => sum + t.psychologyScore!,
                      ) /
                  (scoredCount * 10)) *
              100
        : 82.0;
    final int mistakeTagsCount = periodTrades.where((AppTrade t) {
      return t.tags.any((String tag) {
        final String low = tag.toLowerCase();
        return low.contains('revenge') ||
            low.contains('fomo') ||
            low.contains('chase');
      });
    }).length;

    final String monthLabelShort = _selectedMonth != null
        ? _monthShort(_selectedMonth!.month)
        : 'All';

    final DeskStatCardData card1 = DeskStatCardData(
      title: 'Month Net Realized',
      value: AppTokens.signedMoney(netPnl, decimals: 0),
      valueColor: AppTokens.pl(context, netPnl),
      secondary: '${totalR >= 0 ? '+' : ''}${totalR.toStringAsFixed(1)}R',
      secondaryColor: AppTokens.pl(context, totalR),
      subtitle:
          'Gross: ${AppTokens.signedMoney(grossDisplay, decimals: 0)} · Tax: ${AppTokens.money(taxAndCharges, decimals: 0)}',
    );

    final DeskStatCardData card2 = DeskStatCardData(
      title: 'Win Rate ($monthLabelShort)',
      value: '${winRate.toStringAsFixed(1)}%',
      valueColor: colors.foreground,
      secondary: '${wins}W - ${losses}L - ${breakeven}BE',
      secondaryColor: colors.foregroundMuted,
      subtitle:
          'Avg Win ${avgWinR.toStringAsFixed(1)}R · Avg Loss ${avgLossR.toStringAsFixed(1)}R',
    );

    final DeskStatCardData card3 = DeskStatCardData(
      title: 'Profit Factor',
      value: profitFactor >= 99 ? '∞' : profitFactor.toStringAsFixed(2),
      valueColor: colors.foreground,
      secondary: pfRating,
      secondaryColor: colors.info,
      subtitle: 'Target Benchmark: > 1.80',
    );

    final DeskStatCardData card4 = DeskStatCardData(
      key: _disciplineStatKey,
      title: 'Execution Discipline',
      value: '${disciplineScore.round()}%',
      valueColor: colors.warning,
      secondary: mistakeTagsCount > 0
          ? '$mistakeTagsCount Revenge Tag'
          : 'Checklist Done',
      secondaryColor: colors.warning,
      subtitle: 'Checklist compliance rate',
    );

    return DeskStatsOverview(
      stats: <DeskStatCardData>[card1, card2, card3, card4],
    );
  }

  // ── 3. Journal Control Bar & Filters ───────────────────────────────────────

  Widget _journalControlBar(
    BuildContext context, {
    required List<AppTrade> periodTrades,
    required List<AppTrade> visible,
    required double maxWidth,
  }) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    final String monthText = _selectedMonth == null
        ? 'All Time'
        : _monthLabel(_selectedMonth!);

    final List<String> availablePlaybooks = _entries
        .map((AppTrade t) => t.strategy)
        .whereType<String>()
        .where((String s) => s.isNotEmpty)
        .toSet()
        .toList();

    final List<String> availableTickers = JournalQuery.tickersOf(_entries);

    final int allCount = periodTrades.length;
    final int openCount = periodTrades.where((AppTrade t) => t.isOpen).length;
    final int winsCount = periodTrades
        .where((AppTrade t) => t.outcome == AppOutcome.win)
        .length;
    final int lossesCount = periodTrades
        .where((AppTrade t) => t.outcome == AppOutcome.loss)
        .length;

    Widget buildOutcomeSegment({
      required String label,
      required int count,
      required bool isSelected,
      required VoidCallback onTap,
    }) {
      return InkWell(
        borderRadius: context.radius(theme.radii.sm),
        onTap: onTap,
        child: Container(
          height: context.sz(28),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.sm),
          ),
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

    final Widget titleAndCount = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: context.sp(theme.spacing.xs),
      children: <Widget>[
        Text('Entries', style: context.uiText.subheading),
        SizedBox(width: context.sp(theme.spacing.sm)),
        UiBadge(
          label: '${visible.length} total',
          variant: UiBadgeVariant.outline,
          size: UiSize.xs,
        ),
      ],
    );

    Widget buildMonthNavigator({required bool isMobile}) {
      return Container(
        height: context.sz(32),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: context.radius(theme.radii.md),
          border: Border.all(color: colors.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
          children: <Widget>[
            if (isMobile)
              Expanded(
                child: UiDropdownMenu(
                  items: <UiMenuItem>[
                    UiMenuItem(
                      label: 'All Time',
                      icon: Icons.all_inclusive_rounded,
                      onPressed: () => setState(() {
                        _selectedMonth = null;
                        _currentPage = 1;
                      }),
                    ),
                    for (final DateTime m in _availableMonths)
                      UiMenuItem(
                        label: _monthLabel(m),
                        icon: Icons.calendar_month_outlined,
                        onPressed: () => setState(() {
                          _selectedMonth = m;
                          _currentPage = 1;
                        }),
                      ),
                  ],
                  child: Container(
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(
                      horizontal: context.sp(theme.spacing.xs),
                    ),
                    child: Text(
                      monthText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption.copyWith(
                        color: colors.foreground,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              )
            else
              UiDropdownMenu(
                items: <UiMenuItem>[
                  UiMenuItem(
                    label: 'All Time',
                    icon: Icons.all_inclusive_rounded,
                    onPressed: () => setState(() {
                      _selectedMonth = null;
                      _currentPage = 1;
                    }),
                  ),
                  for (final DateTime m in _availableMonths)
                    UiMenuItem(
                      label: _monthLabel(m),
                      icon: Icons.calendar_month_outlined,
                      onPressed: () => setState(() {
                        _selectedMonth = m;
                        _currentPage = 1;
                      }),
                    ),
                ],
                child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(theme.spacing.sm),
                  ),
                  child: Text(
                    monthText,
                    style: context.uiText.caption.copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            UiIconButton(
              icon: Icons.chevron_left_rounded,
              size: UiSize.xs,
              variant: UiVariant.ghost,
              tooltip: 'Previous Month',
              onPressed: _prevMonth,
            ),
            UiIconButton(
              icon: Icons.chevron_right_rounded,
              size: UiSize.xs,
              variant: UiVariant.ghost,
              tooltip: 'Next Month',
              onPressed: _nextMonth,
            ),
          ],
        ),
      );
    }

    Widget buildViewToggle() {
      return DeskViewToggle(
        isGrid: _viewMode == _ViewMode.cards,
        gridIcon: Icons.grid_view_rounded,
        gridTooltip: 'Cards view',
        secondaryIcon: Icons.table_chart_outlined,
        secondaryTooltip: 'Table view',
        onChanged: (bool grid) => setState(
          () => _viewMode = grid ? _ViewMode.cards : _ViewMode.table,
        ),
      );
    }

    Widget buildSortDropdown({required bool isMobile}) {
      return DeskFilterDropdown(
        label: 'Sort: ${_sort.label.split(' ').first}',
        icon: Icons.sort_rounded,
        isExpanded: isMobile,
        items: <UiMenuItem>[
          for (final AppJournalSort s in AppJournalSort.values)
            UiMenuItem(
              label: s.label,
              icon: Icons.sort_rounded,
              onPressed: () => _updateFilter(() => _sort = s),
            ),
        ],
      );
    }

    final bool isDesktop = !context.uiRes.isMobile && maxWidth >= 680;

    final Widget outcomePills = Container(
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
          buildOutcomeSegment(
            label: 'All',
            count: allCount,
            isSelected: _outcome == null,
            onTap: () => _updateFilter(() => _outcome = null),
          ),
          buildOutcomeSegment(
            label: 'Open',
            count: openCount,
            isSelected: _outcome == AppOutcome.open,
            onTap: () => _updateFilter(() => _outcome = AppOutcome.open),
          ),
          buildOutcomeSegment(
            label: 'Wins',
            count: winsCount,
            isSelected: _outcome == AppOutcome.win,
            onTap: () => _updateFilter(() => _outcome = AppOutcome.win),
          ),
          buildOutcomeSegment(
            label: 'Losses',
            count: lossesCount,
            isSelected: _outcome == AppOutcome.loss,
            onTap: () => _updateFilter(() => _outcome = AppOutcome.loss),
          ),
        ],
      ),
    );

    final Widget dropdownFilters = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DeskFilterDropdown(
          label: _strategyId == null ? 'Playbook: All' : 'Playbook: Set',
          icon: Icons.auto_stories_outlined,
          isActive: _strategyId != null,
          items: <UiMenuItem>[
            UiMenuItem(
              label: 'Playbook: All',
              icon: Icons.auto_stories_outlined,
              onPressed: () => _updateFilter(() => _strategyId = null),
            ),
            for (final String s in availablePlaybooks)
              UiMenuItem(
                label: s,
                icon: Icons.account_tree_outlined,
                onPressed: () {
                  final AppTrade? match = _entries.cast<AppTrade?>().firstWhere(
                    (AppTrade? t) => t?.strategy == s,
                    orElse: () => null,
                  );
                  _updateFilter(() => _strategyId = match?.strategyId ?? s);
                },
              ),
          ],
        ),
        SizedBox(width: context.sp(theme.spacing.xs)),
        DeskFilterDropdown(
          label: _ticker == null ? 'Asset: All' : 'Asset: $_ticker',
          icon: Icons.candlestick_chart_outlined,
          isActive: _ticker != null,
          items: <UiMenuItem>[
            UiMenuItem(
              label: 'Asset: All',
              icon: Icons.candlestick_chart_outlined,
              onPressed: () => _updateFilter(() => _ticker = null),
            ),
            for (final String tick in availableTickers)
              UiMenuItem(
                label: tick,
                icon: Icons.show_chart_rounded,
                onPressed: () => _updateFilter(() => _ticker = tick),
              ),
          ],
        ),
        if (_hasActiveFilters) ...<Widget>[
          SizedBox(width: context.sp(theme.spacing.xs)),
          UiButton(
            label: 'Clear',
            leadingIcon: Icons.close_rounded,
            variant: UiVariant.ghost,
            size: UiSize.xs,
            onPressed: _clearFilters,
          ),
        ],
      ],
    );

    return Column(
      key: _filterBarKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Top Row: Title, Count & View Controls
        if (context.uiRes.isMobile) ...<Widget>[
          titleAndCount,
          SizedBox(height: context.sp(theme.spacing.xs)),
          Row(
            children: <Widget>[
              Expanded(flex: 3, child: buildMonthNavigator(isMobile: true)),
              SizedBox(width: context.sp(theme.spacing.xs)),
              buildViewToggle(),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Expanded(flex: 2, child: buildSortDropdown(isMobile: true)),
            ],
          ),
        ] else
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              titleAndCount,
              Wrap(
                spacing: context.sp(theme.spacing.xs),
                runSpacing: context.sp(theme.spacing.xs),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  buildMonthNavigator(isMobile: false),
                  buildViewToggle(),
                  buildSortDropdown(isMobile: false),
                ],
              ),
            ],
          ),
        SizedBox(height: context.sp(theme.spacing.sm)),

        // Filter Pills Row
        if (isDesktop)
          Row(
            key: _outcomesKey,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[outcomePills, dropdownFilters],
          )
        else
          SingleChildScrollView(
            key: _outcomesKey,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                outcomePills,
                SizedBox(width: context.sp(theme.spacing.sm)),
                Container(
                  width: 1,
                  height: 16,
                  color: colors.border.withValues(alpha: 0.6),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                dropdownFilters,
              ],
            ),
          ),
      ],
    );
  }

  // ── 4. Section Divider ─────────────────────────────────────────────────────

  Widget _sectionHeadingLabel(BuildContext context) {
    final String label = _selectedMonth == null
        ? 'All Trades'
        : _monthLabel(_selectedMonth!);
    return DeskSectionHeader(title: label);
  }

  // ── 5. Responsive Grid & Table Views ───────────────────────────────────────

  Widget _buildCardsGridView(
    BuildContext context,
    List<AppTrade> batch,
    double maxWidth,
  ) {
    final UiTheme theme = context.ui;
    final double gap = context.sp(theme.spacing.sm);
    final int columns = maxWidth >= 1024 ? 3 : (maxWidth >= 680 ? 2 : 1);
    final double cardWidth = columns > 1
        ? (maxWidth - (columns - 1) * gap) / columns
        : maxWidth;

    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < batch.length; i += columns) {
      final List<AppTrade> rowItems = batch.sublist(
        i,
        (i + columns).clamp(0, batch.length),
      );
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: columns == 1
              ? _JournalDashboardCard(
                  entry: rowItems.first,
                  linkedNoteCount: _linkedNoteCounts[rowItems.first.id],
                  onTap: () => _open(rowItems.first.id),
                )
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (int j = 0; j < columns; j++) ...<Widget>[
                        if (j > 0) SizedBox(width: gap),
                        Expanded(
                          child: j < rowItems.length
                              ? SizedBox(
                                  width: cardWidth,
                                  child: _JournalDashboardCard(
                                    entry: rowItems[j],
                                    linkedNoteCount:
                                        _linkedNoteCounts[rowItems[j].id],
                                    onTap: () => _open(rowItems[j].id),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _buildTableView(BuildContext context, List<AppTrade> batch) {
    return UiTable<AppTrade>(
      rows: batch,
      onRowTap: (AppTrade t) => _open(t.id),
      columns: <UiTableColumn<AppTrade>>[
        UiTableColumn<AppTrade>(
          header: 'Ticker',
          cell: (BuildContext context, AppTrade t) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(t.ticker, style: context.uiText.bodyStrong),
              Text(
                AppTokens.shortDate(t.sortDate),
                style: context.uiText.caption.copyWith(
                  color: context.uiColors.foregroundMuted,
                ),
              ),
            ],
          ),
          compare: (AppTrade a, AppTrade b) => a.ticker.compareTo(b.ticker),
        ),
        UiTableColumn<AppTrade>(
          header: 'Title / Strategy',
          cell: (BuildContext context, AppTrade t) => Text(
            t.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.body,
          ),
        ),
        UiTableColumn<AppTrade>(
          header: 'Side',
          cell: (BuildContext context, AppTrade t) => UiBadge(
            label: AppTokens.sideLabel(t.side),
            size: UiSize.xs,
            intent: AppTokens.sideIntent(t.side),
          ),
        ),
        UiTableColumn<AppTrade>(
          header: 'Status',
          cell: (BuildContext context, AppTrade t) => t.isOpen
              ? const UiBadge(
                  label: 'Open',
                  size: UiSize.xs,
                  intent: UiIntent.info,
                  variant: UiBadgeVariant.outline,
                )
              : UiBadge(
                  label: AppTokens.outcomeLabel(t.outcome),
                  size: UiSize.xs,
                  intent: AppTokens.outcomeIntent(t.outcome),
                  variant: UiBadgeVariant.soft,
                ),
        ),
        UiTableColumn<AppTrade>(
          header: 'Entry',
          numeric: true,
          hideBelow: UiTableVisibility.tabletUp,
          cell: (BuildContext context, AppTrade t) =>
              Text(AppTokens.money(t.entry)),
        ),
        UiTableColumn<AppTrade>(
          header: 'Exit',
          numeric: true,
          hideBelow: UiTableVisibility.tabletUp,
          cell: (BuildContext context, AppTrade t) =>
              Text(t.exit == null ? '—' : AppTokens.money(t.exit!)),
        ),
        UiTableColumn<AppTrade>(
          header: 'R',
          numeric: true,
          hideBelow: UiTableVisibility.desktopUp,
          cell: (BuildContext context, AppTrade t) =>
              Text(t.rMultiple == null ? '—' : AppTokens.rr(t.rMultiple!)),
        ),
        UiTableColumn<AppTrade>(
          header: 'P/L',
          numeric: true,
          compare: (AppTrade a, AppTrade b) => a.pnl.compareTo(b.pnl),
          cell: (BuildContext context, AppTrade t) => Text(
            t.isOpen ? 'Open' : AppTokens.signedMoney(t.pnl, decimals: 0),
            style: context.uiText.bodyStrong.copyWith(
              color: t.isOpen
                  ? context.uiColors.info
                  : AppTokens.pl(context, t.pnl),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int i = 0; i < 4; i++)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(context.uiSpace.sm)),
            child: UiSkeleton(height: context.sz(96)),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final double gutter = context.sp(context.uiSpace.md);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: gutter * 2),
      child: UiEmptyState(
        icon: _hasActiveFilters
            ? Icons.filter_alt_off_rounded
            : Icons.menu_book_outlined,
        title: _hasActiveFilters ? 'Nothing matches' : 'No entries yet',
        message: _hasActiveFilters
            ? 'Try adjusting or clearing your filters to see journal entries.'
            : 'Log the trade you just closed and write down your reasoning.',
        action: _hasActiveFilters
            ? UiButton(
                label: 'Clear filters',
                variant: UiVariant.secondary,
                onPressed: _clearFilters,
              )
            : UiButton(
                label: 'Log Trade',
                leadingIcon: Icons.add_rounded,
                onPressed: _newEntry,
              ),
      ),
    );
  }

  // ── 6. Pagination Bar ──────────────────────────────────────────────────────

  Widget _paginationBar(BuildContext context, int totalCount) {
    final int totalPages = (totalCount / _itemsPerPage).ceil().clamp(1, 9999);
    return DeskPaginationBar(
      currentPage: _currentPage,
      totalPages: totalPages,
      totalItems: totalCount,
      pageSize: _itemsPerPage,
      itemLabel: 'trades logged',
      onPageChanged: (int page) => setState(() => _currentPage = page),
    );
  }

  // ── 7. Status Bar / Broker Sync Footer ─────────────────────────────────────

  Widget _statusBarFooter(BuildContext context) {
    return const DeskStatusBarFooter(
      syncLabel: 'Workspace records · broker sync is not connected',
      shortcutHints: <String>[
        'Press N to add trade',
        '/ to search',
        'Esc to clear',
      ],
    );
  }

  // ── 8. Floating Bottom-Right Action Button (FAB) ───────────────────────────

  Widget _buildFloatingActionButton(BuildContext context) {
    final UiTheme theme = context.ui;
    final double gutter = context.sp(theme.spacing.md);
    final double bottomInset = MediaQuery.paddingOf(context).bottom + gutter;

    return Positioned(
      key: _fabKey,
      right: gutter,
      bottom: bottomInset,
      child: Material(
        elevation: 6,
        color: Colors.transparent,
        borderRadius: context.radius(theme.radii.pill),
        child: UiIconButton(
          icon: Icons.add_rounded,
          variant: UiVariant.primary,
          size: UiSize.lg,
          tooltip: 'Log Trade',
          onPressed: _newEntry,
        ),
      ),
    );
  }
}

/// A journal entry as an analytics card matching the HTML dashboard design.
class _JournalDashboardCard extends StatelessWidget {
  const _JournalDashboardCard({
    required this.entry,
    required this.onTap,
    this.linkedNoteCount,
  });

  final AppTrade entry;
  final VoidCallback onTap;
  final int? linkedNoteCount;

  @override
  Widget build(BuildContext context) {
    return AppJournalNoteCard(
      entry: entry,
      onTap: onTap,
      linkedNoteCount: linkedNoteCount,
    );
  }
}
