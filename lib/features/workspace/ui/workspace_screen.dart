import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// Required unified primitive import for every writing workspace surface.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/features/strategies/data/strategies_repository.dart';

/// The Writing Desk landing page — an editorial command centre that opens with
/// a masthead, a week-at-a-glance date strip, quick links, and the three
/// writing surfaces (Notes, Journal, Strategy notes) stacked as focused
/// sections.
///
/// Every size, spacing, duration and column count on this screen is derived
/// from [UiTheme] / [UiResponsive] rather than being written as a literal, so
/// the page rescales automatically for phones, tablets, desktops and large
/// desktops, follows the system light/dark preference, and stays in sync if the
/// design system's tokens ever change. Layout is composed from reusable
/// app-ui blocks ([AppWorkspaceMasthead], [AppWeekStrip], [AppQuickLinkStrip],
/// [AppDeskSectionHeader]) so nothing here is bespoke chrome.
class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, required this.onOpenFeature});

  final ValueChanged<String> onOpenFeature;

  @override
  State<WorkspaceScreen> createState() => WorkspaceScreenState();
}

class WorkspaceScreenState extends State<WorkspaceScreen> {
  final JournalRepository _journal = JournalRepositoryScope.repository;
  final StrategiesRepository _strategies = StrategiesRepositoryScope.repository;
  final NotesRepository _notes = NotesRepositoryScope.repository;

  StreamSubscription<List<AppTrade>>? _journalSub;
  StreamSubscription<List<AppStrategy>>? _strategySub;
  StreamSubscription<List<AppNote>>? _noteSub;
  List<AppTrade> _entries = const <AppTrade>[];
  List<AppStrategy> _playbooks = const <AppStrategy>[];
  List<AppNote> _allNotes = const <AppNote>[];
  bool _loading = true;

  /// The day the week strip is focused on. Drives the Journal section, which is
  /// inherently day-scoped (trades happen on a date).
  DateTime _selectedDay = AppTokens.dateOnly(DateTime.now());

  /// Notes section visibility filter: false = private working notes, true =
  /// published notes (which also reveals engagement analytics).
  bool _showPublicNotes = false;

  @override
  void initState() {
    super.initState();
    _journalSub = _journal.watchAll().listen((List<AppTrade> value) {
      if (!mounted) return;
      setState(() {
        _entries = value;
        _loading = false;
      });
    });
    _strategySub = _strategies.watchAll().listen((List<AppStrategy> value) {
      if (mounted) setState(() => _playbooks = value);
    });
    _noteSub = _notes.watchAll().listen((List<AppNote> value) {
      if (mounted) setState(() => _allNotes = value);
    });
  }

  @override
  void dispose() {
    _journalSub?.cancel();
    _strategySub?.cancel();
    _noteSub?.cancel();
    super.dispose();
  }

  // ─── Derived data ───────────────────────────────────────────────────

  /// Newest-first notes, used by both scopes of the Notes section.
  List<AppNote> get _sortedNotes {
    final List<AppNote> sorted = List<AppNote>.of(_allNotes)
      ..sort((AppNote a, AppNote b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }

  /// Notes matching the current public/private toggle.
  List<AppNote> get _scopedNotes => _sortedNotes
      .where((AppNote n) => n.isPublic == _showPublicNotes)
      .toList(growable: false);

  int get _publicNoteCount =>
      _allNotes.where((AppNote n) => n.isPublic).length;

  int get _openTradeCount =>
      _entries.where((AppTrade t) => t.isOpen).length;

  List<AppStrategy> get _livePlaybooks => _playbooks
      .where((AppStrategy s) => s.status == AppStrategyStatus.live)
      .toList(growable: false);

  /// Live playbooks if there are any, otherwise the most recently touched — the
  /// section should never sit empty just because nothing is flagged live.
  List<AppStrategy> get _strategyFeed {
    if (_livePlaybooks.isNotEmpty) return _livePlaybooks;
    final DateTime epoch = DateTime.fromMillisecondsSinceEpoch(0);
    final List<AppStrategy> sorted = List<AppStrategy>.of(_playbooks)
      ..sort((AppStrategy a, AppStrategy b) =>
          (b.updatedAt ?? epoch).compareTo(a.updatedAt ?? epoch));
    return sorted;
  }

  DateTime _tradeDay(AppTrade t) => AppTokens.dateOnly(t.closedAt ?? t.openedAt);

  /// Closed and open trades that fall on [_selectedDay].
  List<AppTrade> get _tradesForSelectedDay => _entries
      .where((AppTrade t) => AppTokens.isSameDay(_tradeDay(t), _selectedDay))
      .toList(growable: false);

  /// Calendar days carrying any activity, so the week strip can flag them.
  Set<DateTime> get _activityDays {
    final Set<DateTime> days = <DateTime>{};
    for (final AppTrade t in _entries) {
      days.add(_tradeDay(t));
    }
    for (final AppNote n in _allNotes) {
      days.add(AppTokens.dateOnly(n.updatedAt));
    }
    return days;
  }

  // ─── Responsive content density ────────────────────────────────────

  int _sectionColumns(BuildContext context) =>
      context.uiRes.pick<int>(mobile: 1, tablet: 2, desktop: 3);

  int _noteLimit(BuildContext context) =>
      context.uiRes.pick<int>(mobile: 3, tablet: 4, desktop: 6);

  int _tradeLimit(BuildContext context) =>
      context.uiRes.pick<int>(mobile: 3, tablet: 4, desktop: 6);

  int _strategyLimit(BuildContext context) =>
      context.uiRes.pick<int>(mobile: 2, tablet: 3, desktop: 3);

  // ─── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double sectionGap = context.sp(theme.spacing.lg);

    return UiPage(
      maxWidth: theme.sizes.maxContentWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── Masthead ─────────────────────────────────────────────
          AppWorkspaceMasthead(
            eyebrow: 'Workspace',
            title: 'Writing Desk',
            description:
                'Your notes, trade journal, and playbooks in one connected place.',
            trailing: _MastheadMenu(onOpenFeature: widget.onOpenFeature),
          ),
          SizedBox(height: sectionGap),

          // ── Week strip ───────────────────────────────────────────
          AppFadeIn(
            child: AppWeekStrip(
              selected: _selectedDay,
              markers: _activityDays,
              onSelect: (DateTime day) => setState(
                () => _selectedDay = AppTokens.dateOnly(day),
              ),
            ),
          ),
          SizedBox(height: sectionGap),

          // ── Quick links ──────────────────────────────────────────
          AppFadeIn(child: _buildQuickLinks(context)),
          SizedBox(height: sectionGap),

          // ── Notes ────────────────────────────────────────────────
          _buildNotesSection(context),
          SizedBox(height: sectionGap),

          // ── Journal (day-scoped by the week strip) ───────────────
          _buildJournalSection(context),
          SizedBox(height: sectionGap),

          // ── Strategy notes ───────────────────────────────────────
          _buildStrategySection(context),
          SizedBox(height: context.uiPageBottomInset),
        ],
      ),
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

  // ─── Notes section ──────────────────────────────────────────────────

  Widget _buildNotesSection(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<AppNote> notes =
        _scopedNotes.take(_noteLimit(context)).toList(growable: false);
    final AppNoteDensity density = context.uiRes.isMobile
        ? AppNoteDensity.titleOnly
        : AppNoteDensity.comfortable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppDeskSectionHeader(
          title: 'Notes',
          icon: Icons.edit_note_rounded,
          subtitle: _showPublicNotes
              ? '$_publicNoteCount published'
              : '${_allNotes.length - _publicNoteCount} private',
          trailing: UiToggleGroup<bool>(
            value: _showPublicNotes,
            size: UiSize.sm,
            onChanged: (bool value) =>
                setState(() => _showPublicNotes = value),
            options: const <UiToggleOption<bool>>[
              UiToggleOption<bool>(
                value: false,
                label: 'Private',
                icon: Icons.lock_outline_rounded,
              ),
              UiToggleOption<bool>(
                value: true,
                label: 'Public',
                icon: Icons.public_rounded,
              ),
            ],
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // A little reach analytics, only when the published view is active.
        if (_showPublicNotes) ...<Widget>[
          AppNoteEngagementRow(notes: _allNotes, loading: _loading),
          SizedBox(height: context.sp(theme.spacing.md)),
        ],

        if (notes.isEmpty)
          UiEmptyState(
            title: _showPublicNotes ? 'No published notes' : 'No notes yet',
            message: _showPublicNotes
                ? 'Publish a note to share your research and track its reach.'
                : 'Create your first research note to start building your knowledge base.',
            icon: Icons.edit_note_rounded,
          )
        else
          _CardWrap(
            columns: _sectionColumns(context),
            children: <Widget>[
              for (final AppNote note in notes)
                AppNoteCard(
                  note: note,
                  density: density,
                  onTap: () => widget.onOpenFeature('notes'),
                ),
            ],
          ),
      ],
    );
  }

  // ─── Journal section ────────────────────────────────────────────────

  Widget _buildJournalSection(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isToday =
        AppTokens.isSameDay(_selectedDay, AppTokens.dateOnly(DateTime.now()));
    final String dayLabel =
        isToday ? 'Today' : AppTokens.shortDate(_selectedDay);
    final List<AppTrade> trades =
        _tradesForSelectedDay.take(_tradeLimit(context)).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppDeskSectionHeader(
          title: 'Journal',
          icon: Icons.receipt_long_outlined,
          subtitle: '$dayLabel · ${_tradesForSelectedDay.length} '
              '${_tradesForSelectedDay.length == 1 ? 'entry' : 'entries'}',
          trailing: UiButton(
            label: 'View all',
            variant: UiVariant.ghost,
            size: UiSize.sm,
            expandOnMobile: false,
            onPressed: () => widget.onOpenFeature('journal'),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        if (trades.isEmpty)
          UiEmptyState(
            title: 'No trades on $dayLabel',
            message: isToday
                ? 'Log a trade, or pick another day on the strip above.'
                : 'Pick another day on the strip above to review its trades.',
            icon: Icons.event_busy_rounded,
          )
        else
          _CardWrap(
            columns: _sectionColumns(context),
            children: <Widget>[
              for (final AppTrade trade in trades)
                AppTradeCard(
                  trade: trade,
                  dense: true,
                  onTap: () => widget.onOpenFeature('journal'),
                ),
            ],
          ),
      ],
    );
  }

  // ─── Strategy notes section ─────────────────────────────────────────

  Widget _buildStrategySection(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<AppStrategy> strategies =
        _strategyFeed.take(_strategyLimit(context)).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppDeskSectionHeader(
          title: 'Strategy notes',
          icon: Icons.account_tree_outlined,
          subtitle: _livePlaybooks.isNotEmpty
              ? '${_livePlaybooks.length} live'
              : '${_playbooks.length} total',
          trailing: UiButton(
            label: 'View all',
            variant: UiVariant.ghost,
            size: UiSize.sm,
            expandOnMobile: false,
            onPressed: () => widget.onOpenFeature('strategies'),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        if (strategies.isEmpty)
          const UiEmptyState(
            title: 'No playbooks yet',
            message:
                'Document your first strategy so trades can be filed against it.',
            icon: Icons.account_tree_outlined,
          )
        else
          _CardWrap(
            columns: _sectionColumns(context),
            children: <Widget>[
              for (final AppStrategy strategy in strategies)
                AppStrategyCard(
                  strategy: strategy,
                  dense: true,
                  onTap: () => widget.onOpenFeature('strategies'),
                ),
            ],
          ),
      ],
    );
  }
}

// ─── Masthead overflow menu ───────────────────────────────────────────

/// The single dropdown control on the masthead: a compact icon trigger that
/// opens create + jump-to actions, replacing a row of buttons.
class _MastheadMenu extends StatelessWidget {
  const _MastheadMenu({required this.onOpenFeature});

  final ValueChanged<String> onOpenFeature;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiDropdownMenu(
      alignRight: true,
      semanticLabel: 'Workspace actions',
      items: <UiMenuItem>[
        const UiMenuItem.section('Create'),
        UiMenuItem(
          label: 'New note',
          icon: Icons.edit_note_rounded,
          onTap: () => onOpenFeature('notes'),
        ),
        UiMenuItem(
          label: 'New trade',
          icon: Icons.add_chart_rounded,
          onTap: () => onOpenFeature('journal'),
        ),
        UiMenuItem(
          label: 'New playbook',
          icon: Icons.account_tree_outlined,
          onTap: () => onOpenFeature('strategies'),
        ),
        const UiMenuItem.divider(),
        const UiMenuItem.section('Jump to'),
        UiMenuItem(
          label: 'Notes',
          icon: Icons.notes_rounded,
          onTap: () => onOpenFeature('notes'),
        ),
        UiMenuItem(
          label: 'Journal',
          icon: Icons.receipt_long_outlined,
          onTap: () => onOpenFeature('journal'),
        ),
        UiMenuItem(
          label: 'Strategies',
          icon: Icons.account_tree_outlined,
          onTap: () => onOpenFeature('strategies'),
        ),
      ],
      child: Container(
        padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
        decoration: BoxDecoration(
          color: theme.colors.surface,
          borderRadius: context.radius(theme.radii.md),
          border: Border.all(
            color: theme.colors.border,
            width: theme.borders.hairline,
          ),
        ),
        child: Icon(
          Icons.more_vert_rounded,
          size: context.sz(theme.sizes.iconMd),
          color: theme.colors.foregroundMuted,
        ),
      ),
    );
  }
}

// ─── Responsive card wrap ─────────────────────────────────────────────

/// Lays [children] out in [columns] equal-width tracks that keep each card at
/// its natural height, sidestepping the fixed-aspect overflow a grid would
/// impose on variable-height cards. Collapses to a single stretched column when
/// [columns] is 1 (phones).
class _CardWrap extends StatelessWidget {
  const _CardWrap({required this.children, required this.columns});

  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final double gap = context.sp(context.ui.spacing.md);
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int cols = columns < 1
            ? 1
            : (columns > children.length ? children.length : columns);
        if (cols <= 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0) SizedBox(height: gap),
                children[i],
              ],
            ],
          );
        }
        final double width =
            (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final Widget child in children)
              SizedBox(width: width > 0 ? width : constraints.maxWidth, child: child),
          ],
        );
      },
    );
  }
}
