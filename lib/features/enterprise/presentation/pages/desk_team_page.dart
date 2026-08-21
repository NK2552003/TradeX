import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/enterprise/data/repositories/desk_repository.dart';

/// Admin team management: the roster, seat licences, invites, and per-member
/// role and status changes. Filters round-trip through [DeskRepository] so the
/// table always shows what the backend would return for the same query.
class DeskTeamPage extends StatefulWidget {
  const DeskTeamPage({
    super.key,
    this.repository,
    this.onOpenAudit,
    this.onUpgrade,
  });

  final DeskRepository? repository;
  final VoidCallback? onOpenAudit;
  final VoidCallback? onUpgrade;

  @override
  State<DeskTeamPage> createState() => _DeskTeamPageState();
}

class _DeskTeamPageState extends State<DeskTeamPage> {
  late final DeskRepository _repo = widget.repository ?? DeskRepositoryImpl();

  List<AppTeamMember> _rows = const <AppTeamMember>[];
  DeskSnapshot? _snapshot;
  String _query = '';
  AppTeamRole? _role;
  AppMemberStatus? _status;
  bool _loading = true;
  bool _filtering = false;

  /// Id of the member a write is in flight for, so only that row shows a
  /// spinner instead of the whole table flashing.
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _repo.getMembers(),
      _repo.getSnapshot(),
    ]);
    if (!mounted) return;
    setState(() {
      _rows = results[0]! as List<AppTeamMember>;
      _snapshot = results[1]! as DeskSnapshot;
      _loading = false;
    });
  }

  /// Re-queries the roster. The response is dropped when the filters moved on
  /// while the request was in flight.
  Future<void> _reload({bool silent = false}) async {
    final String query = _query;
    final AppTeamRole? role = _role;
    final AppMemberStatus? status = _status;
    if (!silent) setState(() => _filtering = true);
    final List<AppTeamMember> rows = await _repo.getMembers(
      query: query,
      role: role,
      status: status,
    );
    if (!mounted || _query != query || _role != role || _status != status) {
      return;
    }
    setState(() {
      _rows = rows;
      _filtering = false;
    });
  }

  /// Seat counts and the audit tail live on the snapshot, so any write that can
  /// move them refreshes it too.
  Future<void> _refreshSnapshot() async {
    final DeskSnapshot snapshot = await _repo.getSnapshot();
    if (!mounted) return;
    setState(() => _snapshot = snapshot);
  }

  int get _seatsLeft => _snapshot?.seatsLeft ?? 0;
  bool get _canInvite => !_loading && _seatsLeft > 0;

  int _countWhere(bool Function(AppTeamMember) test) =>
      _rows.where(test).length;

  bool get _hasFilters =>
      _query.trim().isNotEmpty || _role != null || _status != null;

  String get _subtitle {
    if (_loading) return 'Loading the roster…';
    final List<String> parts = <String>[
      '${_rows.length} member${_rows.length == 1 ? '' : 's'}',
      '${_countWhere((AppTeamMember m) => m.status == AppMemberStatus.active)} active',
      if (_countWhere(
            (AppTeamMember m) => m.status == AppMemberStatus.invited,
          ) >
          0)
        '${_countWhere((AppTeamMember m) => m.status == AppMemberStatus.invited)} invited',
      '$_seatsLeft seat${_seatsLeft == 1 ? '' : 's'} left',
    ];
    return parts.join(' · ');
  }

  Future<void> _invite() async {
    final ({String email, AppTeamRole role})? request =
        await UiDialog.show<({String email, AppTeamRole role})>(
          context,
          child: _InviteSheet(
            seatsLeft: _seatsLeft,
            takenEmails: _rows
                .map((AppTeamMember m) => m.email.toLowerCase())
                .toSet(),
          ),
        );
    if (request == null || !mounted) return;
    final AppTeamMember member = await _repo.inviteMember(
      request.email,
      request.role,
    );
    if (!mounted) return;
    await Future.wait<void>(<Future<void>>[
      _reload(silent: true),
      _refreshSnapshot(),
    ]);
    if (!mounted) return;
    UiToast.show(
      context,
      title: 'Invite sent',
      message:
          '${member.email} was invited as ${appTeamRoleLabel(member.role)}.',
      intent: UiIntent.success,
    );
  }

  Future<void> _changeRole(AppTeamMember member) async {
    final AppTeamRole? role = await UiDialog.show<AppTeamRole>(
      context,
      child: _RoleSheet(member: member),
    );
    if (role == null || role == member.role || !mounted) return;
    setState(() => _busyId = member.id);
    final AppTeamMember updated = await _repo.changeRole(member.id, role);
    if (!mounted) return;
    setState(() => _busyId = null);
    await Future.wait<void>(<Future<void>>[
      _reload(silent: true),
      _refreshSnapshot(),
    ]);
    if (!mounted) return;
    UiToast.show(
      context,
      title: '${updated.name} is now ${appTeamRoleLabel(updated.role)}',
      message: 'The change is recorded in the audit trail.',
      intent: UiIntent.success,
    );
  }

  Future<void> _setStatus(AppTeamMember member, AppMemberStatus status) async {
    if (status == AppMemberStatus.suspended) {
      final bool confirmed = await UiDialog.confirm(
        context,
        title: 'Suspend ${member.name}?',
        description:
            'They lose access immediately and their seat is freed for someone '
            'else. Journals and trades they logged stay on the desk.',
        confirmLabel: 'Suspend',
        confirmVariant: UiVariant.destructive,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _busyId = member.id);
    final AppTeamMember updated = await _repo.setStatus(member.id, status);
    if (!mounted) return;
    setState(() => _busyId = null);
    await Future.wait<void>(<Future<void>>[
      _reload(silent: true),
      _refreshSnapshot(),
    ]);
    if (!mounted) return;
    UiToast.show(
      context,
      title: '${updated.name} is ${_statusLabel(updated.status).toLowerCase()}',
      message: switch (updated.status) {
        AppMemberStatus.active => 'Access restored and a seat is in use again.',
        AppMemberStatus.invited =>
          'The invite was re-sent to ${updated.email}.',
        AppMemberStatus.suspended => 'A seat was released back to the plan.',
      },
      intent: updated.status == AppMemberStatus.suspended
          ? UiIntent.warning
          : UiIntent.success,
    );
  }

  Future<void> _remove(AppTeamMember member) async {
    final bool confirmed = await UiDialog.confirm(
      context,
      title: 'Remove ${member.name}?',
      description:
          'This deletes their seat and API access. You will need a fresh invite '
          'to bring them back.',
      confirmLabel: 'Remove',
      confirmVariant: UiVariant.destructive,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busyId = member.id);
    await _repo.removeMember(member.id);
    if (!mounted) return;
    setState(() => _busyId = null);
    await Future.wait<void>(<Future<void>>[
      _reload(silent: true),
      _refreshSnapshot(),
    ]);
    if (!mounted) return;
    UiToast.show(
      context,
      title: '${member.name} was removed',
      message: '$_seatsLeft seat${_seatsLeft == 1 ? '' : 's'} now available.',
      intent: UiIntent.neutral,
    );
  }

  Future<void> _copyEmail(AppTeamMember member) async {
    await Clipboard.setData(ClipboardData(text: member.email));
    if (!mounted) return;
    UiToast.show(
      context,
      title: 'Email copied',
      message: member.email,
      intent: UiIntent.success,
    );
  }

  Future<void> _openMember(AppTeamMember member) async {
    final _MemberAction? action = await UiDialog.show<_MemberAction>(
      context,
      child: _MemberSheet(member: member, seatsLeft: _seatsLeft),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _MemberAction.changeRole:
        await _changeRole(member);
      case _MemberAction.suspend:
        await _setStatus(member, AppMemberStatus.suspended);
      case _MemberAction.activate:
        await _setStatus(member, AppMemberStatus.active);
      case _MemberAction.resendInvite:
        await _setStatus(member, AppMemberStatus.invited);
      case _MemberAction.copyEmail:
        await _copyEmail(member);
      case _MemberAction.remove:
        await _remove(member);
    }
  }

  static String _statusLabel(AppMemberStatus status) => switch (status) {
    AppMemberStatus.active => 'Active',
    AppMemberStatus.invited => 'Invited',
    AppMemberStatus.suspended => 'Suspended',
  };

  static UiIntent _statusIntent(AppMemberStatus status) => switch (status) {
    AppMemberStatus.active => UiIntent.bullish,
    AppMemberStatus.invited => UiIntent.warning,
    AppMemberStatus.suspended => UiIntent.bearish,
  };

  /// What each role can do, kept beside the enum so adding a role forces the
  /// copy to be written too.
  static String _roleDescription(AppTeamRole role) => switch (role) {
    AppTeamRole.owner =>
      'Full control: billing, seats, risk limits and API keys.',
    AppTeamRole.admin =>
      'Everything except billing — manages seats, risk and audit exports.',
    AppTeamRole.analyst =>
      'Reads every seat\'s trades and publishes desk-wide strategies.',
    AppTeamRole.member =>
      'Trades their own book and shares journals with the desk.',
    AppTeamRole.viewer => 'Read-only access to dashboards and reports.',
  };
  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return AppPageBlock(
      title: 'Team & seats',
      subtitle: _subtitle,
      actions: <Widget>[
        UiButton(
          label: 'Invite teammate',
          leadingIcon: Icons.person_add_alt_1_rounded,
          size: UiSize.sm,
          onPressed: _canInvite ? _invite : null,
        ),
        UiButton(
          label: 'Audit trail',
          variant: UiVariant.secondary,
          leadingIcon: Icons.receipt_long_rounded,
          size: UiSize.sm,
          hideLabelOnMobile: true,
          onPressed: widget.onOpenAudit,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!_loading && _seatsLeft == 0) ...<Widget>[
            AppFadeIn(
              child: UiCallout(
                title: 'Every licensed seat is in use',
                message:
                    'Suspend a seat or add licences before sending another invite.',
                intent: UiIntent.warning,
                icon: Icons.event_seat_rounded,
                action: UiButton(
                  label: 'Add licences',
                  size: UiSize.sm,
                  variant: UiVariant.outline,
                  expandOnMobile: false,
                  onPressed: widget.onUpgrade,
                ),
              ),
            ),
            UiGap.v(theme.spacing.md),
          ],
          AppFadeIn(delay: AppMotion.step, child: _seatMeter()),
          UiGap.v(theme.spacing.lg),
          AppFadeIn(
            delay: AppMotion.step * 2,
            child: AppDashboardLayoutBlock(
              main: <Widget>[_rosterCard()],
              side: <Widget>[_roleReferenceCard(), _inviteHygieneCard()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seatMeter() {
    final UiTheme theme = context.ui;
    final int used = _snapshot?.seatsUsed ?? 0;
    final int licences = _snapshot?.seatLicences ?? 0;
    final double ratio = licences == 0 ? 0 : (used / licences).clamp(0, 1);
    final UiIntent intent = ratio >= 1
        ? UiIntent.danger
        : (ratio >= 0.8 ? UiIntent.warning : UiIntent.success);

    return UiCard(
      title: 'Seat licences',
      subtitle: licences == 0
          ? 'Reading the plan…'
          : '$used of $licences seats consumed by anyone who is not suspended',
      trailing: UiBadge(label: '$_seatsLeft left', intent: intent),
      actions: <Widget>[
        UiButton(
          label: 'Invite teammate',
          variant: UiVariant.ghost,
          size: UiSize.sm,
          leadingIcon: Icons.person_add_alt_1_rounded,
          onPressed: _canInvite ? _invite : null,
        ),
        UiButton(
          label: 'Add licences',
          variant: UiVariant.ghost,
          size: UiSize.sm,
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: widget.onUpgrade,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiProgressBar(
            value: ratio,
            intent: intent,
            valueFormatter: (num _) => '${AppTokens.percent(ratio * 100)} used',
          ),
          UiGap.v(theme.spacing.lg),
          _roleSplit(),
        ],
      ),
    );
  }

  /// Role mix across the roster. Built from the rows the repository returned so
  /// it always agrees with the table underneath it.
  Widget _roleSplit() {
    final Map<AppTeamRole, int> counts = <AppTeamRole, int>{};
    for (final AppTeamMember member in _rows) {
      counts[member.role] = (counts[member.role] ?? 0) + 1;
    }
    if (counts.isEmpty) {
      return UiSkeleton(height: context.sz(28));
    }
    final List<AppTeamRole> roles = AppTeamRole.values
        .where((AppTeamRole r) => (counts[r] ?? 0) > 0)
        .toList(growable: false);
    return UiCategoryBar(
      segments: <UiCategorySegment>[
        for (final AppTeamRole role in roles)
          UiCategorySegment(
            value: counts[role]!.toDouble(),
            label: '${appTeamRoleLabel(role)} · ${counts[role]}',
            color: appTeamRoleIntent(role).color(context),
          ),
      ],
    );
  }

  Widget _rosterCard() {
    final UiTheme theme = context.ui;
    return UiCard(
      title: 'Roster',
      subtitle: _hasFilters
          ? '${_rows.length} match${_rows.length == 1 ? '' : 'es'} for the current filters'
          : 'Everyone with access to this desk',
      trailing: _filtering
          ? UiSkeleton(width: context.sz(72), height: context.sz(20))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _filters(),
          UiGap.v(theme.spacing.lg),
          UiTable<AppTeamMember>(
            rows: _rows,
            loading: _loading,
            stackOnMobile: true,
            stickyHeader: true,
            pageSize: 10,
            onRowTap: _openMember,
            emptyLabel: _hasFilters
                ? 'No members match those filters'
                : 'Invite your first teammate to share this desk',
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
      hintText: 'Search name or email',
      onChanged: (String value) {
        setState(() => _query = value);
        _reload();
      },
    );
    final Widget roles = UiSelect<AppTeamRole?>(
      value: _role,
      hintText: 'All roles',
      leadingIcon: Icons.badge_outlined,
      onChanged: (AppTeamRole? value) {
        setState(() => _role = value);
        _reload();
      },
      options: <UiOption<AppTeamRole?>>[
        const UiOption<AppTeamRole?>(value: null, label: 'All roles'),
        for (final AppTeamRole role in AppTeamRole.values)
          UiOption<AppTeamRole?>(
            value: role,
            label: appTeamRoleLabel(role),
            description: _roleDescription(role),
          ),
      ],
    );
    final Widget statuses = UiToggleGroup<AppMemberStatus?>(
      value: _status,
      onChanged: (AppMemberStatus? value) {
        setState(() => _status = value == _status ? null : value);
        _reload();
      },
      options: <UiToggleOption<AppMemberStatus?>>[
        const UiToggleOption<AppMemberStatus?>(value: null, label: 'All'),
        for (final AppMemberStatus status in AppMemberStatus.values)
          UiToggleOption<AppMemberStatus?>(
            value: status,
            label: _statusLabel(status),
            intent: _statusIntent(status),
          ),
      ],
    );
    final Widget clear = UiButton(
      label: 'Clear filters',
      variant: UiVariant.ghost,
      size: UiSize.sm,
      leadingIcon: Icons.filter_alt_off_outlined,
      onPressed: () {
        setState(() {
          _query = '';
          _role = null;
          _status = null;
        });
        _reload();
      },
    );

    if (context.uiRes.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          search,
          UiGap.v(theme.spacing.sm),
          roles,
          UiGap.v(theme.spacing.sm),
          statuses,
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
            Expanded(child: roles),
          ],
        ),
        UiGap.v(theme.spacing.sm),
        Row(
          children: <Widget>[
            Expanded(child: statuses),
            if (_hasFilters) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.sm)),
              clear,
            ],
          ],
        ),
      ],
    );
  }

  List<UiTableColumn<AppTeamMember>> _columns() {
    final UiTheme theme = context.ui;
    return <UiTableColumn<AppTeamMember>>[
      UiTableColumn<AppTeamMember>(
        header: 'Member',
        flex: 2,
        compare: (AppTeamMember a, AppTeamMember b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        cell: (BuildContext ctx, AppTeamMember m) => Row(
          children: <Widget>[
            UiAvatar(imageUrl: m.avatarUrl, name: m.name, size: UiSize.sm),
            SizedBox(width: ctx.sp(theme.spacing.sm)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    m.name,
                    style: ctx.uiText.bodyStrong,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    m.email,
                    overflow: TextOverflow.ellipsis,
                    style: ctx.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      UiTableColumn<AppTeamMember>(
        header: 'Role',
        compare: (AppTeamMember a, AppTeamMember b) =>
            a.role.index.compareTo(b.role.index),
        cell: (BuildContext ctx, AppTeamMember m) => UiBadge(
          label: appTeamRoleLabel(m.role),
          intent: appTeamRoleIntent(m.role),
          onTap: () => _changeRole(m),
        ),
      ),
      UiTableColumn<AppTeamMember>(
        header: 'Status',
        hideBelow: UiTableVisibility.tabletUp,
        compare: (AppTeamMember a, AppTeamMember b) =>
            a.status.index.compareTo(b.status.index),
        cell: (BuildContext ctx, AppTeamMember m) => UiBadge(
          label: _statusLabel(m.status),
          intent: _statusIntent(m.status),
        ),
      ),
      UiTableColumn<AppTeamMember>(
        header: 'Last active',
        hideBelow: UiTableVisibility.desktopUp,
        compare: (AppTeamMember a, AppTeamMember b) =>
            (a.lastActiveAt ?? DateTime(0)).compareTo(
              b.lastActiveAt ?? DateTime(0),
            ),
        cell: (BuildContext ctx, AppTeamMember m) => Text(
          m.lastActiveAt == null
              ? 'Never signed in'
              : AppTokens.relativeTime(m.lastActiveAt!),
          style: ctx.uiText.caption.copyWith(
            color: theme.colors.foregroundMuted,
          ),
        ),
      ),
      UiTableColumn<AppTeamMember>(
        header: '',
        width: context.sz(44),
        cell: (BuildContext ctx, AppTeamMember m) => _busyId == m.id
            ? UiSkeleton(width: ctx.sz(20), height: ctx.sz(20), circle: true)
            : _rowMenu(m),
      ),
    ];
  }

  /// Row-level actions. Suspending is the only destructive-looking entry that
  /// stays available for an owner, so the seat can always be freed.
  Widget _rowMenu(AppTeamMember member) => UiDropdownMenu(
    alignRight: true,
    semanticLabel: 'Actions for ${member.name}',
    items: <UiMenuItem>[
      UiMenuItem(
        label: 'Open member',
        icon: Icons.open_in_new_rounded,
        onTap: () => _openMember(member),
      ),
      UiMenuItem(
        label: 'Change role',
        icon: Icons.badge_outlined,
        description: appTeamRoleLabel(member.role),
        onTap: () => _changeRole(member),
      ),
      UiMenuItem(
        label: 'Copy email',
        icon: Icons.mail_outline_rounded,
        onTap: () => _copyEmail(member),
      ),
      const UiMenuItem.divider(),
      if (member.status == AppMemberStatus.invited)
        UiMenuItem(
          label: 'Re-send invite',
          icon: Icons.send_outlined,
          onTap: () => _setStatus(member, AppMemberStatus.invited),
        ),
      if (member.status == AppMemberStatus.suspended)
        UiMenuItem(
          label: 'Restore access',
          icon: Icons.lock_open_rounded,
          enabled: _seatsLeft > 0,
          description: _seatsLeft > 0 ? null : 'No seats left on the plan',
          onTap: () => _setStatus(member, AppMemberStatus.active),
        )
      else
        UiMenuItem(
          label: 'Suspend access',
          icon: Icons.lock_outline_rounded,
          intent: UiIntent.warning,
          onTap: () => _setStatus(member, AppMemberStatus.suspended),
        ),
      UiMenuItem(
        label: 'Remove from desk',
        icon: Icons.person_remove_outlined,
        destructive: true,
        onTap: () => _remove(member),
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
  Widget _roleReferenceCard() => UiCard(
    title: 'What each role can do',
    subtitle: 'Roles are enforced on the server, not just in this console',
    child: UiAccordion(
      items: <UiAccordionItem>[
        for (final AppTeamRole role in AppTeamRole.values)
          UiAccordionItem(
            title: appTeamRoleLabel(role),
            badge: '${_countWhere((AppTeamMember m) => m.role == role)}',
            intent: appTeamRoleIntent(role),
            leadingIcon: switch (role) {
              AppTeamRole.owner => Icons.workspace_premium_outlined,
              AppTeamRole.admin => Icons.admin_panel_settings_outlined,
              AppTeamRole.analyst => Icons.insights_outlined,
              AppTeamRole.member => Icons.person_outline_rounded,
              AppTeamRole.viewer => Icons.visibility_outlined,
            },
            content: Text(
              _roleDescription(role),
              style: context.uiText.body.copyWith(
                color: context.ui.colors.foregroundMuted,
              ),
            ),
          ),
      ],
    ),
  );

  /// Seats worth acting on: invites nobody accepted, and seats idle past the
  /// desk's own policy window.
  Widget _inviteHygieneCard() {
    final UiTheme theme = context.ui;
    final int idleDays = _snapshot?.idleSeatDays ?? 0;
    final DateTime cutoff = DateTime.now().subtract(Duration(days: idleDays));
    final List<AppTeamMember> pending = _rows
        .where((AppTeamMember m) => m.status == AppMemberStatus.invited)
        .toList(growable: false);
    final List<AppTeamMember> idle = idleDays == 0
        ? const <AppTeamMember>[]
        : _rows
              .where(
                (AppTeamMember m) =>
                    m.status == AppMemberStatus.active &&
                    (m.lastActiveAt == null ||
                        m.lastActiveAt!.isBefore(cutoff)),
              )
              .toList(growable: false);

    return UiCard(
      title: 'Seat hygiene',
      subtitle: idleDays == 0
          ? 'Checking the desk policy…'
          : 'Invites still open and seats quiet for $idleDays+ days',
      child: UiAsyncView(
        loading: _loading,
        isEmpty: pending.isEmpty && idle.isEmpty,
        emptyTitle: 'Nothing to chase',
        emptyMessage: 'Every invite was accepted and every seat is being used.',
        emptyIcon: Icons.verified_outlined,
        builder: (BuildContext ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (pending.isNotEmpty)
              _hygieneGroup(
                label: 'Awaiting acceptance',
                members: pending,
                actionLabel: 'Re-send',
                onAction: (AppTeamMember m) =>
                    _setStatus(m, AppMemberStatus.invited),
              ),
            if (pending.isNotEmpty && idle.isNotEmpty)
              UiGap.v(theme.spacing.md),
            if (idle.isNotEmpty)
              _hygieneGroup(
                label: 'Idle for $idleDays+ days',
                members: idle,
                actionLabel: 'Suspend',
                onAction: (AppTeamMember m) =>
                    _setStatus(m, AppMemberStatus.suspended),
              ),
          ],
        ),
      ),
    );
  }

  Widget _hygieneGroup({
    required String label,
    required List<AppTeamMember> members,
    required String actionLabel,
    required ValueChanged<AppTeamMember> onAction,
  }) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '$label · ${members.length}',
          style: context.uiText.label.copyWith(
            color: theme.colors.foregroundMuted,
          ),
        ),
        UiGap.v(theme.spacing.sm),
        for (final AppTeamMember member in members)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
            child: Row(
              children: <Widget>[
                UiAvatar(
                  imageUrl: member.avatarUrl,
                  name: member.name,
                  size: UiSize.sm,
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        member.name,
                        style: context.uiText.bodyStrong,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        member.lastActiveAt == null
                            ? 'Never signed in'
                            : 'Last seen ${AppTokens.relativeTime(member.lastActiveAt!)}',
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.foregroundSubtle,
                        ),
                      ),
                    ],
                  ),
                ),
                UiButton(
                  label: actionLabel,
                  variant: UiVariant.outline,
                  size: UiSize.sm,
                  expandOnMobile: false,
                  loading: _busyId == member.id,
                  onPressed: () => onAction(member),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// What the member sheet asks the page to do once it closes, so every write
/// stays in one place instead of being duplicated inside the dialog.
enum _MemberAction {
  changeRole,
  suspend,
  activate,
  resendInvite,
  copyEmail,
  remove,
}

class _MemberSheet extends StatelessWidget {
  const _MemberSheet({required this.member, required this.seatsLeft});

  final AppTeamMember member;
  final int seatsLeft;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiDialog(
      title: member.name,
      description: member.email,
      icon: Icons.person_outline_rounded,
      intent: appTeamRoleIntent(member.role),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Wrap(
            spacing: context.sp(theme.spacing.sm),
            runSpacing: context.sp(theme.spacing.sm),
            children: <Widget>[
              UiBadge(
                label: appTeamRoleLabel(member.role),
                intent: appTeamRoleIntent(member.role),
              ),
              UiBadge(
                label: _DeskTeamPageState._statusLabel(member.status),
                intent: _DeskTeamPageState._statusIntent(member.status),
              ),
              UiBadge(
                label: member.lastActiveAt == null
                    ? 'Never signed in'
                    : 'Active ${AppTokens.relativeTime(member.lastActiveAt!)}',
                intent: UiIntent.neutral,
              ),
            ],
          ),
          UiGap.v(theme.spacing.md),
          Text(
            _DeskTeamPageState._roleDescription(member.role),
            style: context.uiText.body.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
          UiGap.v(theme.spacing.lg),
          UiDivider(),
          UiGap.v(theme.spacing.md),
          _action(
            context,
            icon: Icons.badge_outlined,
            label: 'Change role',
            detail: 'Currently ${appTeamRoleLabel(member.role)}',
            action: _MemberAction.changeRole,
          ),
          _action(
            context,
            icon: Icons.mail_outline_rounded,
            label: 'Copy email',
            detail: member.email,
            action: _MemberAction.copyEmail,
          ),
          if (member.status == AppMemberStatus.invited)
            _action(
              context,
              icon: Icons.send_outlined,
              label: 'Re-send invite',
              detail: 'Sends a fresh link to ${member.email}',
              action: _MemberAction.resendInvite,
            ),
          if (member.status == AppMemberStatus.suspended)
            _action(
              context,
              icon: Icons.lock_open_rounded,
              label: 'Restore access',
              detail: seatsLeft > 0
                  ? 'Uses one of the $seatsLeft available seats'
                  : 'No seats left on the plan',
              action: _MemberAction.activate,
              enabled: seatsLeft > 0,
            )
          else
            _action(
              context,
              icon: Icons.lock_outline_rounded,
              label: 'Suspend access',
              detail: 'Frees their seat and blocks sign-in',
              action: _MemberAction.suspend,
              intent: UiIntent.warning,
            ),
          _action(
            context,
            icon: Icons.person_remove_outlined,
            label: 'Remove from desk',
            detail: 'Deletes the seat and any API access',
            action: _MemberAction.remove,
            intent: UiIntent.danger,
          ),
        ],
      ),
    );
  }

  Widget _action(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String detail,
    required _MemberAction action,
    UiIntent intent = UiIntent.primary,
    bool enabled = true,
  }) {
    final UiTheme theme = context.ui;
    final Color tint = enabled
        ? intent.color(context)
        : theme.colors.disabledForeground;
    return Padding(
      padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
      child: InkWell(
        onTap: enabled ? () => Navigator.of(context).pop(action) : null,
        borderRadius: context.radius(theme.radii.lg),
        child: Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
          child: Row(
            children: <Widget>[
              Icon(icon, size: context.sz(18), color: tint),
              SizedBox(width: context.sp(theme.spacing.md)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      label,
                      style: context.uiText.bodyStrong.copyWith(color: tint),
                    ),
                    Text(
                      detail,
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled)
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

/// Role picker. Every role is described in place so the person changing it can
/// see what they are granting without leaving the dialog.
class _RoleSheet extends StatefulWidget {
  const _RoleSheet({required this.member});

  final AppTeamMember member;

  @override
  State<_RoleSheet> createState() => _RoleSheetState();
}

class _RoleSheetState extends State<_RoleSheet> {
  late AppTeamRole _role = widget.member.role;

  @override
  Widget build(BuildContext context) {
    final bool changed = _role != widget.member.role;
    return UiDialog(
      title: 'Role for ${widget.member.name}',
      description:
          'Currently ${appTeamRoleLabel(widget.member.role)} · changes take effect immediately',
      icon: Icons.badge_outlined,
      content: Flexible(
        child: SingleChildScrollView(
          child: UiRadioCardGroup<AppTeamRole>(
            value: _role,
            onChanged: (AppTeamRole value) => setState(() => _role = value),
            mobileColumns: 1,
            tabletColumns: 1,
            desktopColumns: 2,
            options: <UiOption<AppTeamRole>>[
              for (final AppTeamRole role in AppTeamRole.values)
                UiOption<AppTeamRole>(
                  value: role,
                  label: appTeamRoleLabel(role),
                  description: _DeskTeamPageState._roleDescription(role),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        UiButton(
          label: 'Cancel',
          variant: UiVariant.secondary,
          expandOnMobile: false,
          onPressed: () => Navigator.of(context).pop(),
        ),
        UiButton(
          label: changed ? 'Save as ${appTeamRoleLabel(_role)}' : 'Save',
          expandOnMobile: false,
          onPressed: changed ? () => Navigator.of(context).pop(_role) : null,
        ),
      ],
    );
  }
}

/// Invite flow. Validates against the roster it was given so a duplicate never
/// reaches the repository, and states which seat the invite will consume.
class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.seatsLeft, required this.takenEmails});

  final int seatsLeft;
  final Set<String> takenEmails;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final TextEditingController _email = TextEditingController();
  AppTeamRole _role = AppTeamRole.member;
  bool _touched = false;

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String get _value => _email.text.trim();

  String? get _error {
    if (_value.isEmpty) return 'Enter a work email address';
    if (!_emailPattern.hasMatch(_value)) {
      return 'That does not look like an email address';
    }
    if (widget.takenEmails.contains(_value.toLowerCase())) {
      return 'Someone with that email is already on the desk';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String? error = _touched ? _error : null;
    return UiDialog(
      title: 'Invite a teammate',
      description:
          '${widget.seatsLeft} seat${widget.seatsLeft == 1 ? '' : 's'} left on the plan',
      icon: Icons.person_add_alt_1_rounded,
      content: Flexible(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              UiField(
                label: 'Work email',
                required: true,
                error: error,
                helper: error == null
                    ? 'They receive a sign-in link and appear as Invited until they accept.'
                    : null,
                child: UiInput(
                  controller: _email,
                  hintText: 'name@company.com',
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  error: error != null,
                  onChanged: (String _) => setState(() => _touched = true),
                  onSubmitted: (String _) => _submit(),
                ),
              ),
              UiGap.v(theme.spacing.lg),
              UiRadioCardGroup<AppTeamRole>(
                label: 'Role',
                value: _role,
                onChanged: (AppTeamRole value) => setState(() => _role = value),
                mobileColumns: 1,
                tabletColumns: 1,
                desktopColumns: 2,
                options: <UiOption<AppTeamRole>>[
                  for (final AppTeamRole role in AppTeamRole.values)
                    UiOption<AppTeamRole>(
                      value: role,
                      label: appTeamRoleLabel(role),
                      description: _DeskTeamPageState._roleDescription(role),
                    ),
                ],
              ),
              if (widget.seatsLeft == 1) ...<Widget>[
                UiGap.v(theme.spacing.md),
                const UiCallout(
                  title: 'This is the last seat',
                  message:
                      'Add licences before inviting anyone else, or suspend an idle seat first.',
                  intent: UiIntent.warning,
                  icon: Icons.event_seat_rounded,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        UiButton(
          label: 'Cancel',
          variant: UiVariant.secondary,
          expandOnMobile: false,
          onPressed: () => Navigator.of(context).pop(),
        ),
        UiButton(
          label: 'Send invite',
          leadingIcon: Icons.send_rounded,
          expandOnMobile: false,
          onPressed: _error == null ? _submit : null,
        ),
      ],
    );
  }

  void _submit() {
    setState(() => _touched = true);
    if (_error != null) return;
    Navigator.of(context).pop((email: _value, role: _role));
  }
}
