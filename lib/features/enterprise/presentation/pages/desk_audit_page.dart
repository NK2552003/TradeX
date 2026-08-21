import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/enterprise/data/repositories/desk_repository.dart';

/// Admin audit trail: every privileged action with search, actor and window
/// filters. Filtering happens in the repository so the export always matches
/// what the table is showing.
class DeskAuditPage extends StatefulWidget {
  const DeskAuditPage({
    super.key,
    this.repository,
    this.onOpenTeam,
    this.onOpenRisk,
  });

  final DeskRepository? repository;
  final VoidCallback? onOpenTeam;
  final VoidCallback? onOpenRisk;

  @override
  State<DeskAuditPage> createState() => _DeskAuditPageState();
}

/// Windows the console can ask the backend for, as day counts. `null` means the
/// whole retained history.
enum _AuditWindow { today, week, month, all }

class _DeskAuditPageState extends State<DeskAuditPage> {
  late final DeskRepository _repo = widget.repository ?? DeskRepositoryImpl();

  List<AppAuditEntry> _rows = const <AppAuditEntry>[];
  List<String> _actors = const <String>[];
  int _retentionDays = 0;
  String _query = '';
  String? _actor;
  _AuditWindow _window = _AuditWindow.month;
  bool _loading = true;
  bool _filtering = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _repo.getAuditLog(from: _from),
      _repo.getAuditActors(),
      _repo.getAuditRetentionDays(),
    ]);
    if (!mounted) return;
    setState(() {
      _rows = results[0]! as List<AppAuditEntry>;
      _actors = results[1]! as List<String>;
      _retentionDays = results[2]! as int;
      _loading = false;
    });
  }

  /// Start of the selected window, or null for everything still retained.
  DateTime? get _from {
    final DateTime now = DateTime.now();
    return switch (_window) {
      _AuditWindow.today => DateTime(now.year, now.month, now.day),
      _AuditWindow.week => now.subtract(const Duration(days: 7)),
      _AuditWindow.month => now.subtract(const Duration(days: 30)),
      _AuditWindow.all => null,
    };
  }

  static String _windowLabel(_AuditWindow window) => switch (window) {
    _AuditWindow.today => 'Today',
    _AuditWindow.week => '7 days',
    _AuditWindow.month => '30 days',
    _AuditWindow.all => 'All',
  };

  /// Re-queries the trail and drops the answer if the filters moved on.
  Future<void> _reload({bool silent = false}) async {
    final String query = _query;
    final String? actor = _actor;
    final _AuditWindow window = _window;
    if (!silent) setState(() => _filtering = true);
    final List<AppAuditEntry> rows = await _repo.getAuditLog(
      query: query,
      actor: actor,
      from: _from,
    );
    if (!mounted || _query != query || _actor != actor || _window != window) {
      return;
    }
    setState(() {
      _rows = rows;
      _filtering = false;
    });
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    final String file = await _repo.exportAuditLog(
      query: _query,
      actor: _actor,
      from: _from,
    );
    if (!mounted) return;
    setState(() => _exporting = false);
    // The export itself is an audited action, so the trail is re-read.
    await Future.wait<void>(<Future<void>>[
      _reload(silent: true),
      _refreshActors(),
    ]);
    if (!mounted) return;
    UiToast.show(
      context,
      title: 'Export ready',
      message: '$file · ${_rows.length} entr${_rows.length == 1 ? 'y' : 'ies'}',
      intent: UiIntent.success,
    );
  }

  Future<void> _refreshActors() async {
    final List<String> actors = await _repo.getAuditActors();
    if (!mounted) return;
    setState(() => _actors = actors);
  }

  Future<void> _copyEntry(AppAuditEntry entry) async {
    final String line = <String?>[
      entry.at.toIso8601String(),
      entry.actor,
      entry.action,
      entry.target,
      entry.ip,
    ].whereType<String>().join(' · ');
    await Clipboard.setData(ClipboardData(text: line));
    if (!mounted) return;
    UiToast.show(
      context,
      title: 'Entry copied',
      message: entry.action,
      intent: UiIntent.success,
    );
  }

  bool get _hasFilters =>
      _query.trim().isNotEmpty || _actor != null || _window != _AuditWindow.all;

  String get _subtitle {
    if (_loading) return 'Reading the trail…';
    final List<String> parts = <String>[
      '${_rows.length} entr${_rows.length == 1 ? 'y' : 'ies'}',
      '${_windowLabel(_window).toLowerCase()} window',
      '${_actors.length} actor${_actors.length == 1 ? '' : 's'}',
      if (_retentionDays > 0) 'retained $_retentionDays days',
    ];
    return parts.join(' · ');
  }

  /// Toggles an actor filter. Tapping the actor already applied clears it, so
  /// the table can be narrowed and widened from the rows themselves.
  void _filterActor(String actor) {
    setState(() => _actor = _actor == actor ? null : actor);
    _reload();
  }

  void _clearFilters() {
    setState(() {
      _query = '';
      _actor = null;
      _window = _AuditWindow.all;
    });
    _reload();
  }

  Future<void> _openEntry(AppAuditEntry entry) async {
    final _EntryAction? action = await UiDialog.show<_EntryAction>(
      context,
      child: _EntrySheet(entry: entry, actorApplied: _actor == entry.actor),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _EntryAction.copy:
        await _copyEntry(entry);
      case _EntryAction.filterActor:
        _filterActor(entry.actor);
      case _EntryAction.openTeam:
        widget.onOpenTeam?.call();
      case _EntryAction.openRisk:
        widget.onOpenRisk?.call();
    }
  }

  /// Counts the rows on screen by whatever key the caller picks, busiest first.
  /// Derived from `_rows` so every summary agrees with the table beneath it.
  List<MapEntry<String, int>> _tally(String Function(AppAuditEntry) key) {
    final Map<String, int> counts = <String, int>{};
    for (final AppAuditEntry entry in _rows) {
      final String bucket = key(entry);
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }
    return counts.entries.toList()..sort(
      (MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value),
    );
  }

  DateTime? get _latestAt => _rows.isEmpty
      ? null
      : _rows
            .map((AppAuditEntry e) => e.at)
            .reduce((DateTime a, DateTime b) => a.isAfter(b) ? a : b);
  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return AppPageBlock(
      title: 'Audit trail',
      subtitle: _subtitle,
      actions: <Widget>[
        UiButton(
          label: 'Export CSV',
          leadingIcon: Icons.download_rounded,
          size: UiSize.sm,
          loading: _exporting,
          onPressed: _loading || _rows.isEmpty ? null : _export,
        ),
        UiButton(
          label: 'Risk controls',
          variant: UiVariant.secondary,
          leadingIcon: Icons.shield_outlined,
          size: UiSize.sm,
          hideLabelOnMobile: true,
          onPressed: widget.onOpenRisk,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_retentionDays > 0 && _window == _AuditWindow.all) ...<Widget>[
            AppFadeIn(
              child: UiCallout(
                title: 'Showing everything still retained',
                message:
                    'This plan keeps $_retentionDays days of history. Anything older '
                    'was purged and cannot be exported — download a copy before it ages out.',
                intent: UiIntent.info,
                icon: Icons.inventory_2_outlined,
                action: UiButton(
                  label: 'Export CSV',
                  size: UiSize.sm,
                  variant: UiVariant.outline,
                  expandOnMobile: false,
                  loading: _exporting,
                  onPressed: _rows.isEmpty ? null : _export,
                ),
              ),
            ),
            UiGap.v(theme.spacing.md),
          ],
          AppFadeIn(delay: AppMotion.step, child: _pulseCard()),
          UiGap.v(theme.spacing.lg),
          AppFadeIn(
            delay: AppMotion.step * 2,
            child: AppDashboardLayoutBlock(
              main: <Widget>[_trailCard()],
              side: <Widget>[_actorCard(), _retentionCard()],
            ),
          ),
        ],
      ),
    );
  }

  /// Headline numbers for the current filter set, plus the mix of action kinds
  /// so an admin can see at a glance what the desk has been doing.
  Widget _pulseCard() {
    final UiTheme theme = context.ui;
    final List<MapEntry<String, int>> actors = _tally(
      (AppAuditEntry e) => e.actor,
    );
    final DateTime? latest = _latestAt;
    final List<({String label, String value})> figures =
        <({String label, String value})>[
          (label: 'Entries in window', value: '${_rows.length}'),
          (label: 'Actors involved', value: '${actors.length}'),
          (
            label: 'Busiest actor',
            value: actors.isEmpty ? '—' : actors.first.key.split('@').first,
          ),
          (
            label: 'Last action',
            value: latest == null ? '—' : AppTokens.relativeTime(latest),
          ),
        ];

    return UiCard(
      title: 'Activity in the ${_windowLabel(_window).toLowerCase()} window',
      subtitle: _hasFilters
          ? 'Filtered view — every number below matches the table'
          : 'Everything the desk still retains',
      trailing: _filtering
          ? UiSkeleton(width: context.sz(64), height: context.sz(20))
          : UiBadge(
              label: _windowLabel(_window),
              intent: UiIntent.neutral,
              icon: Icons.calendar_today_outlined,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _figures(figures),
          UiGap.v(theme.spacing.lg),
          _actionMix(),
        ],
      ),
    );
  }

  /// Two columns on a phone, four from tablet up, so the figures never wrap
  /// into an unreadable single file.
  Widget _figures(List<({String label, String value})> figures) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final UiTheme theme = context.ui;
        final double gap = context.sp(theme.spacing.md);
        final int columns = context.uiRes.pick<int>(
          mobile: 2,
          tablet: 4,
          desktop: 4,
        );
        final double width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final ({String label, String value}) figure in figures)
              SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      figure.label,
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                    Text(
                      figure.value,
                      style: context.uiText.subheading,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  /// Mix of action kinds in the current window. Anything past the top five is
  /// folded into one segment so the bar stays legible on a phone.
  Widget _actionMix() {
    final List<MapEntry<String, int>> actions = _tally(
      (AppAuditEntry e) => e.action,
    );
    if (actions.isEmpty) {
      return UiSkeleton(height: context.sz(28));
    }
    final List<MapEntry<String, int>> top = actions.take(5).toList();
    final int rest = actions
        .skip(5)
        .fold<int>(0, (int sum, MapEntry<String, int> e) => sum + e.value);
    return UiCategoryBar(
      segments: <UiCategorySegment>[
        for (final MapEntry<String, int> entry in top)
          UiCategorySegment(
            value: entry.value.toDouble(),
            label: '${entry.key} · ${entry.value}',
          ),
        if (rest > 0)
          UiCategorySegment(
            value: rest.toDouble(),
            label: 'Other · $rest',
            color: context.ui.colors.foregroundSubtle,
          ),
      ],
    );
  }

  Widget _trailCard() {
    final UiTheme theme = context.ui;
    return UiCard(
      title: 'Privileged actions',
      subtitle: _hasFilters
          ? '${_rows.length} match${_rows.length == 1 ? '' : 'es'} for the current filters'
          : 'Every seat change, risk edit, key and export on this desk',
      trailing: _filtering
          ? UiSkeleton(width: context.sz(72), height: context.sz(20))
          : null,
      actions: <Widget>[
        UiButton(
          label: 'Export CSV',
          variant: UiVariant.ghost,
          size: UiSize.sm,
          leadingIcon: Icons.download_rounded,
          loading: _exporting,
          onPressed: _loading || _rows.isEmpty ? null : _export,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _filters(),
          UiGap.v(theme.spacing.lg),
          UiTable<AppAuditEntry>(
            rows: _rows,
            loading: _loading,
            stackOnMobile: true,
            stickyHeader: true,
            pageSize: 12,
            onRowTap: _openEntry,
            emptyLabel: _hasFilters
                ? 'No entries match those filters'
                : 'Privileged actions appear here as soon as they happen',
            columns: _columns(),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    final UiTheme theme = context.ui;
    final Widget search = UiInput.search(
      value: _query,
      hintText: 'Search action, actor or target',
      onChanged: (String value) {
        setState(() => _query = value);
        _reload();
      },
    );
    final Widget actors = UiSelect<String?>(
      value: _actor,
      hintText: 'All actors',
      leadingIcon: Icons.person_outline_rounded,
      onChanged: (String? value) {
        setState(() => _actor = value);
        _reload();
      },
      options: <UiOption<String?>>[
        const UiOption<String?>(value: null, label: 'All actors'),
        for (final String actor in _actors)
          UiOption<String?>(value: actor, label: actor),
      ],
    );
    final Widget windows = UiToggleGroup<_AuditWindow>(
      value: _window,
      onChanged: (_AuditWindow value) {
        setState(() => _window = value);
        _reload();
      },
      options: <UiToggleOption<_AuditWindow>>[
        for (final _AuditWindow window in _AuditWindow.values)
          UiToggleOption<_AuditWindow>(
            value: window,
            label: _windowLabel(window),
          ),
      ],
    );
    final Widget clear = UiButton(
      label: 'Clear filters',
      variant: UiVariant.ghost,
      size: UiSize.sm,
      leadingIcon: Icons.filter_alt_off_outlined,
      onPressed: _clearFilters,
    );

    if (context.uiRes.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          search,
          UiGap.v(theme.spacing.sm),
          actors,
          UiGap.v(theme.spacing.sm),
          windows,
          if (_hasFilters) ...<Widget>[UiGap.v(theme.spacing.sm), clear],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 2, child: search),
            SizedBox(width: context.sp(theme.spacing.sm)),
            Expanded(child: actors),
          ],
        ),
        UiGap.v(theme.spacing.sm),
        Row(
          children: <Widget>[
            Expanded(child: windows),
            if (_hasFilters) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.sm)),
              clear,
            ],
          ],
        ),
      ],
    );
  }

  List<UiTableColumn<AppAuditEntry>> _columns() {
    final UiTheme theme = context.ui;
    return <UiTableColumn<AppAuditEntry>>[
      UiTableColumn<AppAuditEntry>(
        header: 'When',
        compare: (AppAuditEntry a, AppAuditEntry b) => a.at.compareTo(b.at),
        cell: (BuildContext ctx, AppAuditEntry e) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              AppTokens.relativeTime(e.at),
              style: ctx.uiText.bodyStrong,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              AppTokens.stamp(e.at),
              style: ctx.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
          ],
        ),
      ),
      UiTableColumn<AppAuditEntry>(
        header: 'Actor',
        compare: (AppAuditEntry a, AppAuditEntry b) =>
            a.actor.toLowerCase().compareTo(b.actor.toLowerCase()),
        cell: (BuildContext ctx, AppAuditEntry e) => UiBadge(
          label: e.actor,
          intent: _actor == e.actor ? UiIntent.primary : UiIntent.neutral,
          maxWidth: ctx.sz(180),
          tooltip: _actor == e.actor
              ? 'Clear the actor filter'
              : 'Show only ${e.actor}',
          onTap: () => _filterActor(e.actor),
        ),
      ),
      UiTableColumn<AppAuditEntry>(
        header: 'Action',
        flex: 2,
        compare: (AppAuditEntry a, AppAuditEntry b) =>
            a.action.toLowerCase().compareTo(b.action.toLowerCase()),
        cell: (BuildContext ctx, AppAuditEntry e) => Row(
          children: <Widget>[
            Icon(
              _actionIcon(e.action),
              size: ctx.sz(16),
              color: theme.colors.foregroundMuted,
            ),
            SizedBox(width: ctx.sp(theme.spacing.sm)),
            Expanded(
              child: Text(
                e.action,
                style: ctx.uiText.body,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      UiTableColumn<AppAuditEntry>(
        header: 'Target',
        hideBelow: UiTableVisibility.tabletUp,
        compare: (AppAuditEntry a, AppAuditEntry b) =>
            (a.target ?? '').compareTo(b.target ?? ''),
        cell: (BuildContext ctx, AppAuditEntry e) => Text(
          e.target ?? 'Desk-wide',
          overflow: TextOverflow.ellipsis,
          style: ctx.uiText.caption.copyWith(
            color: e.target == null
                ? theme.colors.foregroundSubtle
                : theme.colors.foregroundMuted,
          ),
        ),
      ),
      UiTableColumn<AppAuditEntry>(
        header: 'Source IP',
        hideBelow: UiTableVisibility.desktopUp,
        compare: (AppAuditEntry a, AppAuditEntry b) =>
            (a.ip ?? '').compareTo(b.ip ?? ''),
        cell: (BuildContext ctx, AppAuditEntry e) => Text(
          e.ip ?? 'Not recorded',
          style: ctx.uiText.numeric.copyWith(
            color: theme.colors.foregroundMuted,
          ),
        ),
      ),
      UiTableColumn<AppAuditEntry>(
        header: '',
        width: context.sz(44),
        cell: (BuildContext ctx, AppAuditEntry e) => _rowMenu(e),
      ),
    ];
  }

  /// Icon chosen from what the action mentions, so an action the backend adds
  /// later still renders sensibly instead of showing nothing.
  static IconData _actionIcon(String action) {
    final String value = action.toLowerCase();
    if (value.contains('risk') || value.contains('limit')) {
      return Icons.shield_outlined;
    }
    if (value.contains('key') || value.contains('token')) {
      return Icons.vpn_key_outlined;
    }
    if (value.contains('role') ||
        value.contains('member') ||
        value.contains('invite') ||
        value.contains('seat')) {
      return Icons.group_outlined;
    }
    if (value.contains('export') || value.contains('download')) {
      return Icons.download_outlined;
    }
    if (value.contains('sign') || value.contains('login')) {
      return Icons.login_rounded;
    }
    if (value.contains('plan') ||
        value.contains('billing') ||
        value.contains('licence')) {
      return Icons.credit_card_outlined;
    }
    return Icons.bolt_outlined;
  }

  /// Row-level shortcuts. Everything here is read-only — an audit trail is
  /// never editable from the console.
  Widget _rowMenu(AppAuditEntry entry) => UiDropdownMenu(
    alignRight: true,
    semanticLabel: 'Actions for ${entry.action}',
    items: <UiMenuItem>[
      UiMenuItem(
        label: 'Open details',
        icon: Icons.open_in_new_rounded,
        onTap: () => _openEntry(entry),
      ),
      UiMenuItem(
        label: 'Copy entry',
        icon: Icons.copy_all_outlined,
        description: 'Timestamp, actor, action, target and IP',
        onTap: () => _copyEntry(entry),
      ),
      UiMenuItem(
        label: _actor == entry.actor
            ? 'Clear actor filter'
            : 'Show only this actor',
        icon: Icons.filter_alt_outlined,
        description: entry.actor,
        onTap: () => _filterActor(entry.actor),
      ),
      if (widget.onOpenTeam != null || widget.onOpenRisk != null)
        const UiMenuItem.divider(),
      if (widget.onOpenTeam != null)
        UiMenuItem(
          label: 'Team & seats',
          icon: Icons.groups_outlined,
          onTap: widget.onOpenTeam,
        ),
      if (widget.onOpenRisk != null)
        UiMenuItem(
          label: 'Risk controls',
          icon: Icons.shield_outlined,
          onTap: widget.onOpenRisk,
        ),
    ],
    child: Padding(
      padding: EdgeInsets.all(context.sp(context.ui.spacing.xs)),
      child: Icon(
        Icons.more_horiz_rounded,
        size: context.sz(18),
        color: context.ui.colors.foregroundMuted,
      ),
    ),
  );

  /// Who is generating the privileged actions. Tapping a bar filters the table
  /// to that actor, which is the question this card usually raises.
  Widget _actorCard() {
    final List<MapEntry<String, int>> actors = _tally(
      (AppAuditEntry e) => e.actor,
    );
    return UiCard(
      title: 'Most active actors',
      subtitle: _actor == null
          ? 'Tap a bar to filter the trail'
          : 'Filtered to $_actor',
      actions: <Widget>[
        if (_actor != null)
          UiButton(
            label: 'Show everyone',
            variant: UiVariant.ghost,
            size: UiSize.sm,
            leadingIcon: Icons.filter_alt_off_outlined,
            onPressed: () {
              setState(() => _actor = null);
              _reload();
            },
          ),
      ],
      child: UiAsyncView(
        loading: _loading,
        isEmpty: actors.isEmpty,
        emptyTitle: 'Nobody has acted yet',
        emptyMessage: 'Actor activity appears once privileged actions land.',
        emptyIcon: Icons.people_outline_rounded,
        builder: (BuildContext ctx) => UiBarList(
          valueFormatter: (num value) =>
              '${value.toStringAsFixed(0)} action${value == 1 ? '' : 's'}',
          items: <UiBarListItem>[
            for (final MapEntry<String, int> entry in actors.take(6))
              UiBarListItem(
                label: entry.key,
                value: entry.value,
                onTap: () => _filterActor(entry.key),
              ),
          ],
        ),
      ),
    );
  }

  /// Retention is a plan property, so the console states it plainly and shows
  /// how much of the window the entries in view actually cover.
  Widget _retentionCard() {
    final UiTheme theme = context.ui;
    final DateTime? oldest = _rows.isEmpty
        ? null
        : _rows
              .map((AppAuditEntry e) => e.at)
              .reduce((DateTime a, DateTime b) => a.isBefore(b) ? a : b);
    final int coveredDays = oldest == null
        ? 0
        : DateTime.now().difference(oldest).inDays;
    final double ratio = _retentionDays <= 0
        ? 0
        : (coveredDays / _retentionDays).clamp(0, 1).toDouble();

    return UiCard(
      title: 'Retention & access',
      subtitle: _retentionDays == 0
          ? 'Reading the plan…'
          : 'This plan keeps $_retentionDays days of privileged history',
      actions: <Widget>[
        UiButton(
          label: 'Team & seats',
          variant: UiVariant.ghost,
          size: UiSize.sm,
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: widget.onOpenTeam,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiProgressBar(
            value: ratio,
            label: 'History in view',
            intent: UiIntent.info,
            valueFormatter: (num _) => oldest == null
                ? 'No entries in view'
                : '$coveredDays of $_retentionDays days',
          ),
          UiGap.v(theme.spacing.lg),
          _policyAccordion(),
        ],
      ),
    );
  }

  Widget _policyAccordion() => UiAccordion(
    items: <UiAccordionItem>[
      UiAccordionItem(
        title: 'What gets recorded',
        leadingIcon: Icons.fact_check_outlined,
        content: _bullets(<String>[
          'Seat changes: invites, role changes, suspensions and removals.',
          'Risk edits: every ceiling moved and every guardrail switched off.',
          'API keys: creation, scope changes and revocations.',
          'Exports: who downloaded the trail and how many entries they took.',
        ]),
      ),
      UiAccordionItem(
        title: 'Who can read it',
        leadingIcon: Icons.visibility_outlined,
        content: _bullets(<String>[
          'Owners and admins see the full trail and can export it.',
          'Analysts, members and viewers only see actions on their own seat.',
          'Entries cannot be edited or deleted from this console by anyone.',
        ]),
      ),
      UiAccordionItem(
        title: 'Retention and export',
        leadingIcon: Icons.inventory_2_outlined,
        intent: UiIntent.warning,
        content: _bullets(<String>[
          _retentionDays == 0
              ? 'The retention window comes from the plan.'
              : 'Entries older than $_retentionDays days are purged automatically.',
          'An export contains exactly the filtered rows shown in the table.',
          'The export itself is audited, so downloads are traceable too.',
        ]),
      ),
    ],
  );
  Widget _bullets(List<String> lines) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final String line in lines)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(top: context.sp(theme.spacing.xs)),
                  child: Icon(
                    Icons.circle,
                    size: context.sz(5),
                    color: theme.colors.foregroundSubtle,
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                Expanded(
                  child: Text(
                    line,
                    style: context.uiText.body.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// What the detail sheet asks the page to do once it closes, so navigation and
/// clipboard work stay in the page instead of inside the dialog.
enum _EntryAction { copy, filterActor, openTeam, openRisk }

/// Full record for one entry. Read-only by design — an audit trail that a
/// console can edit is not an audit trail.
class _EntrySheet extends StatelessWidget {
  const _EntrySheet({required this.entry, required this.actorApplied});

  final AppAuditEntry entry;

  /// Whether the table is already filtered to this entry's actor, so the sheet
  /// offers to clear the filter instead of re-applying it.
  final bool actorApplied;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiDialog(
      title: entry.action,
      description:
          '${AppTokens.stamp(entry.at)} · ${AppTokens.relativeTime(entry.at)}',
      icon: Icons.receipt_long_outlined,
      intent: UiIntent.info,
      content: Flexible(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _detail(context, 'Actor', entry.actor),
              _detail(context, 'Target', entry.target ?? 'Desk-wide'),
              _detail(context, 'Source IP', entry.ip ?? 'Not recorded'),
              _detail(context, 'Recorded at', entry.at.toIso8601String()),
              _detail(context, 'Entry id', entry.id),
              UiGap.v(theme.spacing.md),
              const UiDivider(),
              UiGap.v(theme.spacing.md),
              _action(
                context,
                icon: Icons.copy_all_outlined,
                label: 'Copy entry',
                detail: 'Puts the whole record on the clipboard',
                action: _EntryAction.copy,
              ),
              _action(
                context,
                icon: Icons.filter_alt_outlined,
                label: actorApplied
                    ? 'Clear actor filter'
                    : 'Show only this actor',
                detail: entry.actor,
                action: _EntryAction.filterActor,
              ),
              _action(
                context,
                icon: Icons.groups_outlined,
                label: 'Open team & seats',
                detail: 'Check the seat this action touched',
                action: _EntryAction.openTeam,
              ),
              _action(
                context,
                icon: Icons.shield_outlined,
                label: 'Open risk controls',
                detail: 'Review the guardrails behind this change',
                action: _EntryAction.openRisk,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(BuildContext context, String label, String value) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: context.sz(96),
            child: Text(
              label,
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
          Expanded(child: SelectableText(value, style: context.uiText.body)),
        ],
      ),
    );
  }

  Widget _action(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String detail,
    required _EntryAction action,
  }) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(action),
        borderRadius: context.radius(theme.radii.lg),
        child: Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
          child: Row(
            children: <Widget>[
              Icon(icon, size: context.sz(18), color: theme.colors.primary),
              SizedBox(width: context.sp(theme.spacing.md)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(label, style: context.uiText.bodyStrong),
                    Text(
                      detail,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: context.sz(18),
                color: theme.colors.foregroundSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
