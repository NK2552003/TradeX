import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/enterprise/data/repositories/desk_repository.dart';

/// Admin home surface: the desk-wide snapshot an owner opens first. Everything
/// on it is derived from [DeskRepository] so the console, the team screen and
/// the risk screen never disagree about seats, breaches or the review queue.
class DeskOverviewPage extends StatefulWidget {
  const DeskOverviewPage({
    super.key,
    this.repository,
    this.deskName,
    this.onOpenTeam,
    this.onOpenRisk,
    this.onOpenAudit,
    this.onOpenAnalytics,
    this.onOpenAffiliateReviews,
    this.onUpgrade,
  });

  final DeskRepository? repository;

  /// Shown in the page title so the console reads as *this* desk, not a
  /// generic admin screen.
  final String? deskName;
  final VoidCallback? onOpenTeam;
  final VoidCallback? onOpenRisk;
  final VoidCallback? onOpenAudit;
  final VoidCallback? onOpenAnalytics;
  final VoidCallback? onOpenAffiliateReviews;
  final VoidCallback? onUpgrade;

  @override
  State<DeskOverviewPage> createState() => _DeskOverviewPageState();
}

class _DeskOverviewPageState extends State<DeskOverviewPage> {
  late final DeskRepository _repo = widget.repository ?? DeskRepositoryImpl();

  DeskSnapshot? _snapshot;
  bool _loading = true;
  int _breakdown = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final DeskSnapshot snapshot = await _repo.getSnapshot();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _loading = false;
    });
  }

  Future<void> _exportAudit() async {
    final String file = await _repo.exportAuditLog();
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    UiToast.show(
      context,
      title: 'Audit log exported',
      message: file,
      intent: UiIntent.success,
    );
  }

  String get _subtitle {
    final DeskSnapshot? snapshot = _snapshot;
    if (snapshot == null) return 'Loading desk activity…';
    final List<String> parts = <String>[
      '${snapshot.seatsUsed} of ${snapshot.seatLicences} seats in use',
      if (snapshot.breachedLimits.isEmpty)
        'risk limits healthy'
      else
        '${snapshot.breachedLimits.length} risk limit(s) breached',
      if (snapshot.pendingAffiliates > 0)
        '${snapshot.pendingAffiliates} application(s) to review',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final DeskSnapshot? snapshot = _snapshot;

    return AppPageBlock(
      title: widget.deskName == null
          ? 'Desk console'
          : '${widget.deskName} desk',
      subtitle: _subtitle,
      actions: <Widget>[
        UiButton(
          label: 'Invite teammate',
          leadingIcon: Icons.person_add_alt_1_rounded,
          size: UiSize.sm,
          onPressed: widget.onOpenTeam,
        ),
        UiButton(
          label: 'Export audit',
          variant: UiVariant.secondary,
          leadingIcon: Icons.download_rounded,
          size: UiSize.sm,
          hideLabelOnMobile: true,
          onPressed: _loading ? null : _exportAudit,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (snapshot != null &&
              snapshot.breachedLimits.isNotEmpty) ...<Widget>[
            AppFadeIn(child: _breachCallout(snapshot)),
            UiGap.v(theme.spacing.md),
          ],
          if (snapshot != null && snapshot.pendingAffiliates > 0) ...<Widget>[
            AppFadeIn(
              delay: AppMotion.step,
              child: UiCallout(
                title:
                    '${snapshot.pendingAffiliates} affiliate application(s) waiting',
                message:
                    'Partners cannot start referring until someone on the desk approves them.',
                intent: UiIntent.warning,
                icon: Icons.how_to_reg_rounded,
                action: UiButton(
                  label: 'Review queue',
                  size: UiSize.sm,
                  variant: UiVariant.outline,
                  expandOnMobile: false,
                  onPressed: widget.onOpenAffiliateReviews,
                ),
              ),
            ),
            UiGap.v(theme.spacing.md),
          ],
          AppFadeIn(
            delay: AppMotion.step * 2,
            child: AppStatGridBlock(
              stats: snapshot?.stats ?? const <AppStat>[],
              loading: _loading,
            ),
          ),
          UiGap.v(theme.spacing.lg),
          AppFadeIn(delay: AppMotion.step * 3, child: _seatCard(snapshot)),
          UiGap.v(theme.spacing.lg),
          AppFadeIn(
            delay: AppMotion.step * 4,
            child: AppDashboardLayoutBlock(
              main: <Widget>[
                AppEquityCurveBlock(
                  title: 'Desk equity',
                  series: snapshot?.equity ?? const <AppSeriesPoint>[],
                ),
                _breakdownCard(snapshot),
                AppPnlCalendarBlock(
                  title: 'Desk P/L calendar',
                  days: snapshot?.days ?? const <AppDayPnl>[],
                  onDayTap: (AppDayPnl day) => UiToast.show(
                    context,
                    title: AppTokens.shortDate(day.date),
                    message:
                        '${day.trades} trade${day.trades == 1 ? '' : 's'} · ${AppTokens.signedMoney(day.pnl)}',
                    intent: AppTokens.plIntent(day.pnl),
                  ),
                ),
              ],
              side: <Widget>[
                AppTeamMembersBlock(
                  members: snapshot?.members ?? const <AppTeamMember>[],
                  loading: _loading,
                  onInvite: widget.onOpenTeam,
                  onMemberTap: (AppTeamMember _) => widget.onOpenTeam?.call(),
                ),
                AppUsageBlock(
                  metrics: snapshot?.usage ?? const <AppUsageMetric>[],
                  onUpgrade: widget.onUpgrade,
                ),
                AppAuditLogBlock(
                  entries: snapshot?.recentAudit ?? const <AppAuditEntry>[],
                  loading: _loading,
                  onExport: _loading ? null : _exportAudit,
                ),
                _shortcutsCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _breachCallout(DeskSnapshot snapshot) => UiCallout(
    title: snapshot.breachedLimits.length == 1
        ? '${snapshot.breachedLimits.first.label} has been hit'
        : '${snapshot.breachedLimits.length} risk limits have been hit',
    message: snapshot.breachedLimits
        .map(
          (RiskLimit l) =>
              '${l.label}: ${l.format(l.used)} of ${l.format(l.value)}',
        )
        .join(' · '),
    intent: UiIntent.danger,
    icon: Icons.shield_outlined,
    action: UiButton(
      label: 'Open risk controls',
      size: UiSize.sm,
      variant: UiVariant.outline,
      expandOnMobile: false,
      onPressed: widget.onOpenRisk,
    ),
  );

  Widget _seatCard(DeskSnapshot? snapshot) {
    final UiTheme theme = context.ui;
    final int used = snapshot?.seatsUsed ?? 0;
    final int licences = snapshot?.seatLicences ?? 0;
    final int left = snapshot?.seatsLeft ?? 0;
    final double ratio = licences == 0 ? 0 : (used / licences).clamp(0, 1);
    final UiIntent intent = ratio >= 1
        ? UiIntent.danger
        : (ratio >= 0.8 ? UiIntent.warning : UiIntent.success);

    return UiCard(
      title: 'Seat licences',
      subtitle: left == 0
          ? 'Every licensed seat is taken — add licences before inviting again.'
          : '$left seat${left == 1 ? '' : 's'} left on the current plan',
      trailing: UiBadge(label: '$used / $licences', intent: intent),
      actions: <Widget>[
        UiButton(
          label: 'Manage team',
          variant: UiVariant.ghost,
          size: UiSize.sm,
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: widget.onOpenTeam,
        ),
        if (left == 0)
          UiButton(
            label: 'Add licences',
            variant: UiVariant.outline,
            size: UiSize.sm,
            leadingIcon: Icons.upgrade_rounded,
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
          UiGap.v(theme.spacing.md),
          _seatFigures(snapshot),
        ],
      ),
    );
  }

  Widget _seatFigures(DeskSnapshot? snapshot) {
    final List<AppTeamMember> members =
        snapshot?.members ?? const <AppTeamMember>[];
    final int invited = members
        .where((AppTeamMember m) => m.status == AppMemberStatus.invited)
        .length;
    final int suspended = members
        .where((AppTeamMember m) => m.status == AppMemberStatus.suspended)
        .length;
    final List<({String label, String value})> figures =
        <({String label, String value})>[
          (label: 'Seats used', value: '${snapshot?.seatsUsed ?? 0}'),
          (label: 'Seats left', value: '${snapshot?.seatsLeft ?? 0}'),
          (label: 'Invites pending', value: '$invited'),
          (label: 'Suspended', value: '$suspended'),
        ];

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
                    Text(figure.value, style: context.uiText.subheading),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _breakdownCard(DeskSnapshot? snapshot) {
    final List<UiBarListItem> bySeat =
        snapshot?.bySeat ?? const <UiBarListItem>[];
    final List<UiBarListItem> byStrategy =
        snapshot?.byStrategy ?? const <UiBarListItem>[];
    final List<UiBarListItem> active = _breakdown == 0 ? bySeat : byStrategy;

    return UiCard(
      title: 'Where the P/L came from',
      subtitle: _breakdown == 0
          ? 'Closed P/L attributed to each active seat'
          : 'Closed P/L attributed to each strategy',
      actions: <Widget>[
        UiButton(
          label: 'Full analytics',
          variant: UiVariant.ghost,
          size: UiSize.sm,
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: widget.onOpenAnalytics,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiTabs(
            index: _breakdown,
            variant: UiTabsVariant.segmented,
            size: UiSize.sm,
            stretch: context.uiRes.isMobile,
            showPanel: false,
            onChanged: (int value) => setState(() => _breakdown = value),
            items: <UiTabItem>[
              UiTabItem(
                label: 'By seat',
                icon: Icons.groups_outlined,
                count: bySeat.length,
              ),
              UiTabItem(
                label: 'By strategy',
                icon: Icons.insights_outlined,
                count: byStrategy.length,
              ),
            ],
          ),
          UiGap.v(context.ui.spacing.md),
          UiAsyncView(
            loading: _loading,
            isEmpty: active.isEmpty,
            emptyTitle: 'Nothing closed yet',
            emptyMessage:
                'Attribution appears once desk seats close their first trades.',
            emptyIcon: Icons.bar_chart_outlined,
            builder: (BuildContext ctx) =>
                UiBarList(items: active, valueFormatter: AppTokens.signedMoney),
          ),
        ],
      ),
    );
  }

  Widget _shortcutsCard() {
    final UiTheme theme = context.ui;
    final List<
      ({IconData icon, String label, String detail, VoidCallback? tap})
    >
    shortcuts =
        <({IconData icon, String label, String detail, VoidCallback? tap})>[
          (
            icon: Icons.groups_rounded,
            label: 'Team & seats',
            detail: 'Invite, change roles, suspend access',
            tap: widget.onOpenTeam,
          ),
          (
            icon: Icons.shield_rounded,
            label: 'Risk controls',
            detail: 'Loss caps, position limits, leverage',
            tap: widget.onOpenRisk,
          ),
          (
            icon: Icons.receipt_long_rounded,
            label: 'Audit trail',
            detail: 'Search and export privileged actions',
            tap: widget.onOpenAudit,
          ),
          (
            icon: Icons.analytics_rounded,
            label: 'Desk analytics',
            detail: 'Attribution, usage and consistency',
            tap: widget.onOpenAnalytics,
          ),
        ];

    return UiCard(
      title: 'Jump to',
      child: Column(
        children: <Widget>[
          for (final ({
                IconData icon,
                String label,
                String detail,
                VoidCallback? tap,
              })
              shortcut
              in shortcuts)
            if (shortcut.tap != null)
              Padding(
                padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
                child: InkWell(
                  onTap: shortcut.tap,
                  borderRadius: context.radius(theme.radii.lg),
                  child: Padding(
                    padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          shortcut.icon,
                          size: context.sz(18),
                          color: theme.colors.primary,
                        ),
                        SizedBox(width: context.sp(theme.spacing.md)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                shortcut.label,
                                style: context.uiText.bodyStrong,
                              ),
                              Text(
                                shortcut.detail,
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
              ),
        ],
      ),
    );
  }
}
