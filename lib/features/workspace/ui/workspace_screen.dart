import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// Required unified primitive import for every writing workspace surface.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';
import 'package:tradex/features/journal/data/journal_templates.dart';
import 'package:tradex/features/journal/ui/journal_editor_screen.dart';
import 'package:tradex/features/journal/ui/journal_template_gallery.dart';
import 'package:tradex/features/notes/data/note_templates.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/features/notes/ui/note_editor_screen.dart';
import 'package:tradex/features/notes/ui/note_template_gallery.dart';
import 'package:tradex/features/strategies/data/strategies_repository.dart';
import 'package:tradex/features/strategies/data/strategy_templates.dart';
import 'package:tradex/features/strategies/ui/strategy_editor_screen.dart';
import 'package:tradex/features/strategies/ui/strategy_template_gallery.dart';
import 'package:tradex/features/workspace/data/workspace_post_service.dart';

/// The Writing Desk landing page — an editorial command centre that opens with
/// a masthead, an interactive calendar/week strip with activity dots, quick links,
/// social & linking analytics, and the three writing surfaces (Notes, Journal,
/// Strategy notes) presented in responsive, paginated carousels with direct
/// click-through navigation into each document.
class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.onOpenFeature,
    this.onOpenRef,
    this.onOpenWriting,
    this.onSubpageChanged,
  });

  final ValueChanged<String> onOpenFeature;
  final void Function(AppLinkRef ref)? onOpenRef;
  final void Function(AppLinkRef ref)? onOpenWriting;
  final void Function(String? title, IconData? icon, VoidCallback? onBack)?
      onSubpageChanged;

  @override
  State<WorkspaceScreen> createState() => WorkspaceScreenState();
}

class WorkspaceScreenState extends State<WorkspaceScreen> {
  final JournalRepository _journal = JournalRepositoryScope.repository;
  final StrategiesRepository _strategies = StrategiesRepositoryScope.repository;
  final NotesRepository _notes = NotesRepositoryScope.repository;
  final WorkspacePostService _postService = WorkspacePostService.instance;

  StreamSubscription<List<AppTrade>>? _journalSub;
  StreamSubscription<List<AppStrategy>>? _strategySub;
  StreamSubscription<List<AppNote>>? _noteSub;
  StreamSubscription<List<AppPostLinkInfo>>? _postSub;

  List<AppTrade> _entries = const <AppTrade>[];
  List<AppStrategy> _playbooks = const <AppStrategy>[];
  List<AppNote> _allNotes = const <AppNote>[];
  List<AppPostLinkInfo> _postLinks = const <AppPostLinkInfo>[];

  /// The day the calendar / week strip is focused on.
  DateTime _selectedDay = AppTokens.dateOnly(DateTime.now());

  /// Whether the full month calendar or the horizontal week strip is shown.
  bool _isMonthView = false;

  /// Whether to filter content strictly to the selected date. When false, shows all recent records.
  bool _filterByDate = true;

  /// Notes section visibility filter: 'private', 'public', 'all'.
  String _notesFilter = 'private';

  /// Journal section filter: 'all', 'open', 'win', 'loss'.
  String _journalFilter = 'all';

  /// Strategy section filter: 'all', 'live', 'testing', 'draft', 'retired'.
  String _strategyFilter = 'all';

  final GlobalKey<_WorkspaceFabState> _fabKey = GlobalKey<_WorkspaceFabState>();
  bool _isFabOpen = false;

  /// When set, replaces the landing page content with the full editor while
  /// preserving the outer AppShell (navigation rail and top chrome).
  Widget? _activeEditor;

  void _closeEditor() {
    if (!mounted) return;
    setState(() => _activeEditor = null);
    widget.onSubpageChanged?.call(null, null, null);
  }

  @override
  void initState() {
    super.initState();
    _journalSub = _journal.watchAll().listen((List<AppTrade> value) {
      if (!mounted) return;
      setState(() {
        _entries = value;
      });
    });
    _strategySub = _strategies.watchAll().listen((List<AppStrategy> value) {
      if (mounted) setState(() => _playbooks = value);
    });
    _noteSub = _notes.watchAll().listen((List<AppNote> value) {
      if (mounted) setState(() => _allNotes = value);
    });
    _postSub = _postService.watchLinks().listen((List<AppPostLinkInfo> value) {
      if (mounted) setState(() => _postLinks = value);
    });
    _postLinks = _postService.allLinks;
  }

  @override
  void dispose() {
    if (_activeEditor != null) {
      widget.onSubpageChanged?.call(null, null, null);
    }
    _journalSub?.cancel();
    _strategySub?.cancel();
    _noteSub?.cancel();
    _postSub?.cancel();
    super.dispose();
  }

  // ─── Direct Navigation Handlers ─────────────────────────────────────

  void _openNote(AppNote note) {
    if (widget.onOpenRef != null) {
      widget.onOpenRef!(
        AppLinkRef(
          kind: AppLinkKind.note,
          id: note.id,
          title: note.title.trim().isEmpty ? 'Untitled note' : note.title.trim(),
        ),
      );
    } else {
      widget.onOpenFeature('notes');
    }
  }

  void _openTrade(AppTrade trade) {
    if (widget.onOpenRef != null) {
      widget.onOpenRef!(
        AppLinkRef(
          kind: AppLinkKind.journal,
          id: trade.id,
          title: trade.displayTitle,
        ),
      );
    } else {
      widget.onOpenFeature('journal');
    }
  }

  void _openStrategy(AppStrategy strategy) {
    if (widget.onOpenRef != null) {
      widget.onOpenRef!(
        AppLinkRef(
          kind: AppLinkKind.strategy,
          id: strategy.id,
          title: strategy.name.trim().isEmpty
              ? 'Untitled strategy'
              : strategy.name.trim(),
        ),
      );
    } else {
      widget.onOpenFeature('strategies');
    }
  }

  // ─── Entry Creation Handlers ─────────────────────────────────────────

  Future<void> _handleNewNote() async {
    final AppNoteTemplate? template = await showNoteTemplateGallery(context);
    if (template == null || !mounted) return;
    final AppNote draft = template.toDraft();
    setState(() {
      _activeEditor = NoteEditorScreen(
        note: draft,
        onClose: (AppNote? saved) {
          _closeEditor();
          if (saved != null && widget.onOpenRef != null) {
            widget.onOpenRef!(
              AppLinkRef(
                kind: AppLinkKind.note,
                id: saved.id,
                title: saved.title.trim().isEmpty
                    ? 'Untitled note'
                    : saved.title.trim(),
              ),
            );
          }
        },
      );
    });
    widget.onSubpageChanged?.call(
      'New note',
      Icons.edit_note_rounded,
      _closeEditor,
    );
  }

  Future<void> _handleNewTrade() async {
    final AppJournalTemplate? template =
        await showJournalTemplateGallery(context);
    if (template == null || !mounted) return;
    final AppTrade draft = template.toDraft();
    setState(() {
      _activeEditor = JournalEditorScreen(
        entry: draft,
        onClose: (AppTrade? saved) {
          _closeEditor();
          if (saved != null && widget.onOpenRef != null) {
            widget.onOpenRef!(
              AppLinkRef(
                kind: AppLinkKind.journal,
                id: saved.id,
                title: saved.displayTitle,
              ),
            );
          }
        },
      );
    });
    widget.onSubpageChanged?.call(
      'New trade',
      Icons.receipt_long_outlined,
      _closeEditor,
    );
  }

  Future<void> _handleNewPlaybook() async {
    final AppStrategyTemplate? template =
        await showStrategyTemplateGallery(context);
    if (template == null || !mounted) return;
    final AppStrategy draft = template.toDraft();
    setState(() {
      _activeEditor = StrategyEditorScreen(
        strategy: draft,
        onClose: (AppStrategy? saved) {
          _closeEditor();
          if (saved != null && widget.onOpenRef != null) {
            widget.onOpenRef!(
              AppLinkRef(
                kind: AppLinkKind.strategy,
                id: saved.id,
                title: saved.name.trim().isEmpty
                    ? 'Untitled strategy'
                    : saved.name.trim(),
              ),
            );
          }
        },
      );
    });
    widget.onSubpageChanged?.call(
      'New playbook',
      Icons.auto_stories_outlined,
      _closeEditor,
    );
  }

  // ─── Derived Data & Filters ─────────────────────────────────────────

  bool get _isToday =>
      AppTokens.isSameDay(_selectedDay, AppTokens.dateOnly(DateTime.now()));

  DateTime _tradeDay(AppTrade t) =>
      AppTokens.dateOnly(t.closedAt ?? t.openedAt);

  int get _publicNoteCount =>
      _allNotes.where((AppNote n) => n.isPublic).length;

  int get _openTradeCount =>
      _entries.where((AppTrade t) => t.isOpen).length;

  List<AppStrategy> get _livePlaybooks => _playbooks
      .where((AppStrategy s) => s.status == AppStrategyStatus.live)
      .toList(growable: false);

  int get _totalNoteComments =>
      _allNotes.fold<int>(0, (int sum, AppNote n) => sum + n.comments.length);

  int get _notesLinkedToPostCount => _allNotes
      .where((AppNote n) => _postService.isLinked(AppLinkKind.note, n.id))
      .length;

  int get _tradesLinkedToPostCount => _entries
      .where((AppTrade t) => _postService.isLinked(AppLinkKind.journal, t.id))
      .length;

  int get _strategiesLinkedToPostCount => _playbooks
      .where((AppStrategy s) =>
          _postService.isLinked(AppLinkKind.strategy, s.id))
      .length;

  int get _tradesAttachedToStrategiesCount => _entries
      .where((AppTrade t) =>
          t.strategyId != null && t.strategyId!.trim().isNotEmpty)
      .length;

  /// Map of calendar day to list of distinct dot colors:
  /// - Note created/updated: Amber / Warning
  /// - Journal entry: Emerald / Success
  /// - Strategy created/updated: Purple / Primary
  Map<DateTime, List<Color>> _computeActivityDots(BuildContext context) {
    final UiColors c = context.uiColors;
    final Map<DateTime, Set<Color>> dotSets = <DateTime, Set<Color>>{};

    void addDot(DateTime? raw, Color color) {
      if (raw == null) return;
      final DateTime day = AppTokens.dateOnly(raw);
      (dotSets[day] ??= <Color>{}).add(color);
    }

    for (final AppNote n in _allNotes) {
      addDot(n.createdAt, c.warning);
      addDot(n.updatedAt, c.warning);
    }
    for (final AppTrade t in _entries) {
      addDot(t.sortDate, c.success);
    }
    for (final AppStrategy s in _playbooks) {
      addDot(s.createdAt, c.primary);
      addDot(s.updatedAt, c.primary);
    }

    final Map<DateTime, List<Color>> result = <DateTime, List<Color>>{};
    dotSets.forEach((DateTime day, Set<Color> colors) {
      result[day] = colors.toList(growable: false);
    });
    return result;
  }

  /// Calendar days carrying any activity for fallback markers.
  Set<DateTime> get _activityDays {
    final Set<DateTime> days = <DateTime>{};
    for (final AppTrade t in _entries) {
      days.add(_tradeDay(t));
    }
    for (final AppNote n in _allNotes) {
      days.add(AppTokens.dateOnly(n.updatedAt));
    }
    for (final AppStrategy s in _playbooks) {
      if (s.updatedAt != null) days.add(AppTokens.dateOnly(s.updatedAt!));
    }
    return days;
  }

  /// Filtered notes respecting both the public/private/all toggle and the selected date.
  List<AppNote> get _displayNotes {
    final List<AppNote> scoped;
    if (_notesFilter == 'public') {
      scoped = _allNotes.where((AppNote n) => n.isPublic).toList();
    } else if (_notesFilter == 'private') {
      scoped = _allNotes.where((AppNote n) => !n.isPublic).toList();
    } else {
      scoped = List<AppNote>.from(_allNotes);
    }
    scoped.sort((AppNote a, AppNote b) => b.updatedAt.compareTo(a.updatedAt));

    if (!_filterByDate) return scoped;

    return scoped.where((AppNote n) {
      final DateTime cDate = AppTokens.dateOnly(n.createdAt);
      final DateTime uDate = AppTokens.dateOnly(n.updatedAt);
      return AppTokens.isSameDay(cDate, _selectedDay) ||
          AppTokens.isSameDay(uDate, _selectedDay);
    }).toList(growable: false);
  }

  /// Filtered journal trades respecting the selected date and outcome filter.
  List<AppTrade> get _displayTrades {
    List<AppTrade> list = _entries;
    if (_filterByDate) {
      list = list
          .where((AppTrade t) => AppTokens.isSameDay(_tradeDay(t), _selectedDay))
          .toList();
    }
    if (_journalFilter == 'open') {
      list = list.where((AppTrade t) => t.isOpen).toList();
    } else if (_journalFilter == 'win') {
      list = list
          .where((AppTrade t) => !t.isOpen && t.outcome == AppOutcome.win)
          .toList();
    } else if (_journalFilter == 'loss') {
      list = list
          .where((AppTrade t) =>
              !t.isOpen &&
              (t.outcome == AppOutcome.loss ||
                  t.outcome == AppOutcome.breakeven))
          .toList();
    }
    return list;
  }

  /// Filtered playbooks respecting the selected date and status filter.
  List<AppStrategy> get _displayStrategies {
    List<AppStrategy> list;
    if (!_filterByDate) {
      final DateTime epoch = DateTime.fromMillisecondsSinceEpoch(0);
      list = List<AppStrategy>.of(_playbooks)
        ..sort((AppStrategy a, AppStrategy b) =>
            (b.updatedAt ?? epoch).compareTo(a.updatedAt ?? epoch));
    } else {
      list = _playbooks.where((AppStrategy s) {
        final DateTime? cDate =
            s.createdAt == null ? null : AppTokens.dateOnly(s.createdAt!);
        final DateTime? uDate =
            s.updatedAt == null ? null : AppTokens.dateOnly(s.updatedAt!);
        return (cDate != null && AppTokens.isSameDay(cDate, _selectedDay)) ||
            (uDate != null && AppTokens.isSameDay(uDate, _selectedDay));
      }).toList();
    }

    if (_strategyFilter == 'live') {
      list = list
          .where((AppStrategy s) => s.status == AppStrategyStatus.live)
          .toList();
    } else if (_strategyFilter == 'testing') {
      list = list
          .where((AppStrategy s) => s.status == AppStrategyStatus.testing)
          .toList();
    } else if (_strategyFilter == 'draft') {
      list = list
          .where((AppStrategy s) => s.status == AppStrategyStatus.draft)
          .toList();
    } else if (_strategyFilter == 'retired') {
      list = list
          .where((AppStrategy s) => s.status == AppStrategyStatus.retired)
          .toList();
    }
    return list;
  }

  // ─── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_activeEditor != null) {
      return _activeEditor!;
    }

    final UiTheme theme = context.ui;
    final double sectionGap = context.sp(theme.spacing.lg);
    final double gutter = context.sp(theme.spacing.md);
    final Map<DateTime, List<Color>> dots = _computeActivityDots(context);

    return Stack(
      children: <Widget>[
        UiPage(
          maxWidth: theme.sizes.maxContentWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(height: sectionGap),
              // ── Masthead ─────────────────────────────────────────────
              const AppWorkspaceMasthead(
                eyebrow: 'Workspace',
                title: 'Writing Desk',
                description:
                    'Your notes, trade journal, and playbooks in one connected place.',
              ),
              SizedBox(height: sectionGap),

              // ── Calendar Bar & View Toggler ──────────────────────────
              AppFadeIn(
                child: AppWorkspaceCalendarBar(
                  selectedDay: _selectedDay,
                  isMonthView: _isMonthView,
                  onToggleView: (bool value) =>
                      setState(() => _isMonthView = value),
                  onJumpToday: () => setState(
                    () => _selectedDay = AppTokens.dateOnly(DateTime.now()),
                  ),
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.xs)),

              // ── Calendar Strip (Week vs Month) with Colored Dots ─────
              AppFadeIn(
                child: _isMonthView
                    ? AppWorkspaceMonthCalendar(
                        selected: _selectedDay,
                        coloredMarkers: dots,
                        onSelect: (DateTime day) => setState(
                          () => _selectedDay = AppTokens.dateOnly(day),
                        ),
                      )
                    : AppWeekStrip(
                        selected: _selectedDay,
                        markers: _activityDays,
                        coloredMarkers: dots,
                        onSelect: (DateTime day) => setState(
                          () => _selectedDay = AppTokens.dateOnly(day),
                        ),
                      ),
              ),
              SizedBox(height: context.sp(theme.spacing.md)),

              // ── Quick Links ──────────────────────────────────────────
              AppFadeIn(child: _buildQuickLinks(context)),
              SizedBox(height: sectionGap),

              // ── Analytics & Post Linking Overview ────────────────────
              AppFadeIn(child: _buildAnalyticsPanel(context)),
              SizedBox(height: sectionGap),

              // ── Notes Section ────────────────────────────────────────
              _buildNotesSection(context),
              SizedBox(height: sectionGap),

              // ── Journal Section ──────────────────────────────────────
              _buildJournalSection(context),
              SizedBox(height: sectionGap),

              // ── Strategy Notes Section ───────────────────────────────
              _buildStrategySection(context),
              SizedBox(height: context.uiPageBottomInset + context.sz(64)),
            ],
          ),
        ),
        // ── Dismissible backdrop for floating action stack ────────────
        if (_isFabOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _fabKey.currentState?.close(),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.15),
              ),
            ),
          ),

        // ── Floating Action Button (+) with top stack ──────────────────
        Positioned(
          right: gutter,
          bottom: context.uiPageBottomInset + gutter,
          child: _WorkspaceFab(
            key: _fabKey,
            onNewNote: _handleNewNote,
            onNewTrade: _handleNewTrade,
            onNewPlaybook: _handleNewPlaybook,
            onOpenChanged: (bool open) => setState(() => _isFabOpen = open),
          ),
        ),
      ],
    );
  }

  // ─── Quick links ────────────────────────────────────────────────────

  Widget _buildQuickLinks(BuildContext context) {
    return AppQuickLinkStrip(
      links: <AppQuickLink>[
        AppQuickLink(
          icon: Icons.notes_rounded,
          label: 'Notes',
          value: '${_allNotes.length}',
          hint: '$_publicNoteCount public',
          intent: UiIntent.primary,
          onTap: () => widget.onOpenFeature('notes'),
        ),
        AppQuickLink(
          icon: Icons.receipt_long_outlined,
          label: 'Journal',
          value: '${_entries.length}',
          hint: _openTradeCount == 0 ? null : '$_openTradeCount open',
          intent: UiIntent.info,
          onTap: () => widget.onOpenFeature('journal'),
        ),
        AppQuickLink(
          icon: Icons.account_tree_outlined,
          label: 'Strategies',
          value: '${_playbooks.length}',
          hint: '${_livePlaybooks.length} live',
          intent: UiIntent.success,
          onTap: () => widget.onOpenFeature('strategies'),
        ),
      ],
    );
  }

  // ─── Analytics & Post Linking Panel ─────────────────────────────────

  Widget _buildAnalyticsPanel(BuildContext context) {
    final int totalPostLikes =
        _postLinks.fold<int>(0, (int sum, AppPostLinkInfo l) => sum + l.likesCount);
    final List<UiStat> stats = <UiStat>[
      UiStat(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Note Comments',
        value: '$_totalNoteComments',
        hint: '$_publicNoteCount public notes',
        intent: UiIntent.primary,
      ),
      UiStat(
        icon: Icons.share_rounded,
        label: 'Post Links',
        value: '${_postLinks.length}',
        hint: '$totalPostLikes post likes',
        intent: UiIntent.info,
      ),
      UiStat(
        icon: Icons.link_rounded,
        label: 'Attached Trades',
        value: '$_tradesAttachedToStrategiesCount',
        hint: '${_entries.length} total entries',
        intent: UiIntent.success,
      ),
      UiStat(
        icon: Icons.auto_graph_rounded,
        label: 'Active Strategies',
        value: '${_livePlaybooks.length}',
        hint: '$_strategiesLinkedToPostCount linked to post',
        intent: UiIntent.bullish,
      ),
    ];

    return UiDataPanel(
      label: 'Workspace & Social Reach Analytics',
      hint:
          'Interconnections between your notes, journal, strategies, and community posts.',
      leadingIcon: Icons.insights_rounded,
      padding: EdgeInsets.zero,
      child: UiStatStrip(
        stats: stats,
        columns: context.uiRes.isMobile ? 2 : 4,
        density: UiDensity.comfortable,
      ),
    );
  }

  // ─── Notes section ──────────────────────────────────────────────────

  Widget _buildNotesSection(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<AppNote> notes = _displayNotes;
    final String dayLabel =
        _isToday ? 'Today' : AppTokens.shortDate(_selectedDay);

    final String subtitle = _filterByDate
        ? '$dayLabel · ${notes.length} ${notes.length == 1 ? 'note' : 'notes'}'
        : switch (_notesFilter) {
            'public' =>
              '$_publicNoteCount published · $_totalNoteComments comments',
            'private' =>
              '${_allNotes.length - _publicNoteCount} private · $_notesLinkedToPostCount linked to post',
            _ => '${_allNotes.length} total notes · $_publicNoteCount published',
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // ── Date Scope Full-Width Segmented Toggle ─────────────────────
        UiToggleGroup<bool>(
          value: _filterByDate,
          expand: true,
          size: UiSize.sm,
          onChanged: (bool value) => setState(() => _filterByDate = value),
          options: <UiToggleOption<bool>>[
            UiToggleOption<bool>(
              value: true,
              label: _isToday ? 'Scope to Today' : 'Scope to $dayLabel',
              icon: Icons.calendar_today_rounded,
            ),
            const UiToggleOption<bool>(
              value: false,
              label: 'Show all',
              icon: Icons.grid_view_rounded,
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        AppWorkspaceSectionCarousel(
          title: 'Notes',
          icon: Icons.edit_note_rounded,
          subtitle: subtitle,
          trailing: UiToggleGroup<String>(
            value: _notesFilter,
            size: UiSize.xs,
            onChanged: (String value) {
              if (value == 'all' && _notesFilter == 'all') {
                widget.onOpenFeature('notes');
              } else {
                setState(() => _notesFilter = value);
              }
            },
            options: const <UiToggleOption<String>>[
              UiToggleOption<String>(
                value: 'private',
                label: 'Private',
                icon: Icons.lock_outline_rounded,
              ),
              UiToggleOption<String>(
                value: 'public',
                label: 'Public',
                icon: Icons.public_rounded,
              ),
              UiToggleOption<String>(
                value: 'all',
                label: 'View all',
                icon: Icons.grid_view_rounded,
              ),
            ],
          ),
          emptyPlaceholder: UiEmptyState(
            title: _filterByDate
                ? (_isToday ? 'No notes today' : 'No notes on $dayLabel')
                : switch (_notesFilter) {
                    'public' => 'No published notes',
                    'private' => 'No private notes',
                    _ => 'No notes yet',
                  },
            message: _filterByDate
                ? (_isToday
                    ? 'Capture market observations or analysis for today.'
                    : 'Pick another day on the calendar or create a new note.')
                : switch (_notesFilter) {
                    'public' =>
                      'Publish a note to share your research with the community.',
                    'private' =>
                      'Create your first private note to capture market observations.',
                    _ =>
                      'Create your first note to build your trading playbook.',
                  },
            icon: Icons.edit_note_rounded,
            action: _isToday
                ? UiButton(
                    label: 'New note',
                    leadingIcon: Icons.add_rounded,
                    onPressed: _handleNewNote,
                  )
                : null,
          ),
          maxCards: 6,
          cards: <Widget>[
            for (final AppNote note in notes)
              AppNoteCard(
                key: ValueKey<String>(note.id),
                note: note,
                density: AppNoteDensity.comfortable,
                onTap: () => _openNote(note),
              ),
          ],
        ),
      ],
    );
  }

  // ─── Journal section ────────────────────────────────────────────────

  Widget _buildJournalSection(BuildContext context) {
    final List<AppTrade> trades = _displayTrades;
    final String dayLabel =
        _isToday ? 'Today' : AppTokens.shortDate(_selectedDay);

    final String subtitle = _filterByDate
        ? '$dayLabel · ${trades.length} ${trades.length == 1 ? 'entry' : 'entries'}'
        : '${_entries.length} total entries · $_tradesLinkedToPostCount linked to post';

    return AppWorkspaceSectionCarousel(
      title: 'Journal',
      icon: Icons.receipt_long_outlined,
      subtitle: subtitle,
      trailing: UiToggleGroup<String>(
        value: _journalFilter,
        size: UiSize.xs,
        onChanged: (String value) {
          if (value == 'all' && _journalFilter == 'all') {
            widget.onOpenFeature('journal');
          } else {
            setState(() => _journalFilter = value);
          }
        },
        options: const <UiToggleOption<String>>[
          UiToggleOption<String>(value: 'all', label: 'All'),
          UiToggleOption<String>(value: 'open', label: 'Open'),
          UiToggleOption<String>(value: 'win', label: 'Win'),
          UiToggleOption<String>(value: 'loss', label: 'Loss'),
        ],
      ),
      emptyPlaceholder: UiEmptyState(
        title: _filterByDate
            ? (_isToday ? 'No entries today' : 'No trades on $dayLabel')
            : 'No entries yet',
        message: _filterByDate
            ? (_isToday
                ? 'Log a trade executed today to record entry, exit, and thesis.'
                : 'Pick another day on the calendar above to review logged trades.')
            : 'Log your first trade to begin tracking performance and PnL.',
        icon: Icons.event_busy_rounded,
        action: _isToday
            ? UiButton(
                label: 'New trade',
                leadingIcon: Icons.add_chart_rounded,
                onPressed: _handleNewTrade,
              )
            : null,
      ),
      maxCards: 6,
      cards: <Widget>[
        for (final AppTrade trade in trades)
          AppJournalNoteCard(
            key: ValueKey<String>(trade.id),
            entry: trade,
            showExcerpt: true,
            onTap: () => _openTrade(trade),
            trailing: _postService.isLinked(AppLinkKind.journal, trade.id)
                ? const UiBadge(
                    label: 'Post',
                    icon: Icons.share_rounded,
                    size: UiSize.xs,
                    intent: UiIntent.primary,
                  )
                : null,
            footerEngagement: _postService.isLinked(AppLinkKind.journal, trade.id)
                ? Builder(
                    builder: (BuildContext ctx) {
                      final AppPostLinkInfo? link = _postService
                          .getPrimaryLink(AppLinkKind.journal, trade.id);
                      return AppDeskEngagementRow(
                        isLinked: true,
                        likes: link?.likesCount ?? 0,
                        comments: link?.commentsCount ?? 0,
                      );
                    },
                  )
                : null,
          ),
      ],
    );
  }

  // ─── Strategy notes section ─────────────────────────────────────────

  Widget _buildStrategySection(BuildContext context) {
    final List<AppStrategy> strategies = _displayStrategies;
    final String dayLabel =
        _isToday ? 'Today' : AppTokens.shortDate(_selectedDay);

    final String subtitle = _filterByDate
        ? '$dayLabel · ${strategies.length} ${strategies.length == 1 ? 'playbook' : 'playbooks'}'
        : '${_livePlaybooks.length} live · $_strategiesLinkedToPostCount linked to post';

    return AppWorkspaceSectionCarousel(
      title: 'Strategy notes',
      icon: Icons.account_tree_outlined,
      subtitle: subtitle,
      trailing: UiToggleGroup<String>(
        value: _strategyFilter,
        size: UiSize.xs,
        onChanged: (String value) {
          if (value == 'all' && _strategyFilter == 'all') {
            widget.onOpenFeature('strategies');
          } else {
            setState(() => _strategyFilter = value);
          }
        },
        options: const <UiToggleOption<String>>[
          UiToggleOption<String>(value: 'all', label: 'All'),
          UiToggleOption<String>(value: 'live', label: 'Live'),
          UiToggleOption<String>(value: 'testing', label: 'Testing'),
          UiToggleOption<String>(value: 'draft', label: 'Draft'),
          UiToggleOption<String>(value: 'retired', label: 'Retired'),
        ],
      ),
      emptyPlaceholder: UiEmptyState(
        title: _filterByDate
            ? (_isToday ? 'No playbooks today' : 'No playbooks on $dayLabel')
            : 'No playbooks yet',
        message: _filterByDate
            ? (_isToday
                ? 'Document or update a quantitative trading playbook for today.'
                : 'Select another date on the calendar or view all strategies.')
            : 'Document your first strategy so trades can be filed against it.',
        icon: Icons.account_tree_outlined,
        action: _isToday
            ? UiButton(
                label: 'New playbook',
                leadingIcon: Icons.add_rounded,
                onPressed: _handleNewPlaybook,
              )
            : null,
      ),
      maxCards: 6,
      cards: <Widget>[
        for (final AppStrategy strategy in strategies)
          AppStrategyNoteCard(
            key: ValueKey<String>(strategy.id),
            strategy: strategy,
            showExcerpt: true,
            onTap: () => _openStrategy(strategy),
            footerEngagement:
                _postService.isLinked(AppLinkKind.strategy, strategy.id)
                    ? Builder(
                        builder: (BuildContext ctx) {
                          final AppPostLinkInfo? link = _postService
                              .getPrimaryLink(
                                AppLinkKind.strategy,
                                strategy.id,
                              );
                          return AppDeskEngagementRow(
                            isLinked: true,
                            likes: link?.likesCount ?? 0,
                            comments: link?.commentsCount ?? 0,
                          );
                        },
                      )
                    : null,
          ),
      ],
    );
  }
}

// ─── Floating Action Button (+) for Workspace ─────────────────────────

/// Floating action button with frosted glass capsule styling and `+` icon.
/// Tapping expands a top-stack speed dial displaying only options for
/// creating new entries (New note, New trade, New playbook).
class _WorkspaceFab extends StatefulWidget {
  const _WorkspaceFab({
    super.key,
    required this.onNewNote,
    required this.onNewTrade,
    required this.onNewPlaybook,
    this.onOpenChanged,
  });

  final VoidCallback onNewNote;
  final VoidCallback onNewTrade;
  final VoidCallback onNewPlaybook;
  final ValueChanged<bool>? onOpenChanged;

  @override
  State<_WorkspaceFab> createState() => _WorkspaceFabState();
}

class _WorkspaceFabState extends State<_WorkspaceFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _rotateAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _rotateAnimation =
        Tween<double>(begin: 0.0, end: 0.125).animate(_expandAnimation);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void toggle() {
    if (_isOpen) {
      close();
    } else {
      open();
    }
  }

  void open() {
    if (_isOpen) return;
    setState(() => _isOpen = true);
    _controller.forward();
    widget.onOpenChanged?.call(true);
  }

  void close() {
    if (!_isOpen) return;
    setState(() => _isOpen = false);
    _controller.reverse();
    widget.onOpenChanged?.call(false);
  }

  void _select(VoidCallback action) {
    close();
    action();
  }

  Widget _buildOptionItem({
    required BuildContext context,
    required UiTheme theme,
    required bool isDark,
    required String label,
    required IconData icon,
    required Color color,
    required double progress,
    required VoidCallback onTap,
  }) {
    return Transform.scale(
      scale: progress,
      alignment: Alignment.centerRight,
      child: Opacity(
        opacity: progress.clamp(0.0, 1.0),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Label capsule
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.sm),
                  vertical: context.sp(theme.spacing.xs),
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xEC1E1C1A)
                      : theme.colors.surface.withValues(alpha: 0.95),
                  borderRadius: context.radius(theme.radii.pill),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.1),
                    width: 1.0,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  label,
                  style: context.uiText.bodyStrong.copyWith(
                    fontSize: context.sz(13),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),

              // Action button circle — matches the 52x52 size, shape, shadow and alignment of the floating + button
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 18,
                      spreadRadius: 0,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? const Color(0xDC1A1817)
                          : theme.colors.surface.withValues(alpha: 0.92),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.18)
                            : Colors.black.withValues(alpha: 0.12),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Icon(icon, size: context.sz(24), color: color),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color activeFg = isDark ? Colors.white : theme.colors.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext ctx, Widget? child) {
        final double progress = _expandAnimation.value;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            // Floating options stacked on top of the + button
            if (progress > 0.01) ...<Widget>[
              // Option 3: New playbook
              _buildOptionItem(
                context: ctx,
                theme: theme,
                isDark: isDark,
                label: 'New playbook',
                icon: Icons.account_tree_outlined,
                color: theme.colors.primary,
                progress: progress,
                onTap: () => _select(widget.onNewPlaybook),
              ),
              SizedBox(height: ctx.sp(theme.spacing.sm)),

              // Option 2: New trade
              _buildOptionItem(
                context: ctx,
                theme: theme,
                isDark: isDark,
                label: 'New trade',
                icon: Icons.add_chart_rounded,
                color: theme.colors.success,
                progress: progress,
                onTap: () => _select(widget.onNewTrade),
              ),
              SizedBox(height: ctx.sp(theme.spacing.sm)),

              // Option 1: New note
              _buildOptionItem(
                context: ctx,
                theme: theme,
                isDark: isDark,
                label: 'New note',
                icon: Icons.edit_note_rounded,
                color: theme.colors.warning,
                progress: progress,
                onTap: () => _select(widget.onNewNote),
              ),
              SizedBox(height: ctx.sp(theme.spacing.sm)),
            ],

            // Main FAB Button (+)
            GestureDetector(
              onTap: toggle,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 18,
                      spreadRadius: 0,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? const Color(0xDC1A1817)
                          : theme.colors.surface.withValues(alpha: 0.92),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.18)
                            : Colors.black.withValues(alpha: 0.12),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: RotationTransition(
                        turns: _rotateAnimation,
                        child: Icon(
                          Icons.add_rounded,
                          size: ctx.sz(28),
                          color: activeFg,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
