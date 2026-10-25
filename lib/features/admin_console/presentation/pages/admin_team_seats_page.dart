import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/admin_console/data/admin_console_repository.dart';
import 'package:tradex/features/admin_console/models/admin_console_models.dart';
import 'package:tradex/features/affiliate_program/data/affiliate_workspace_repository.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_application_model.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_workspace.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';

class AdminTeamSeatsPage extends StatefulWidget {
  const AdminTeamSeatsPage({
    super.key,
    this.onNavigate,
  });

  final ValueChanged<String>? onNavigate;

  @override
  State<AdminTeamSeatsPage> createState() => _AdminTeamSeatsPageState();
}

class _AdminTeamSeatsPageState extends State<AdminTeamSeatsPage> {
  final AdminConsoleRepository _repo = AdminConsoleRepository.instance;

  bool _loading = true;
  String _activeTab = 'seats'; // seats | consumers | affiliates | deletions
  String _searchQuery = '';

  List<AdminTraderSeat> _seats = const <AdminTraderSeat>[];
  List<AdminConsumerAccount> _consumers = const <AdminConsumerAccount>[];
  List<AffiliateApplicationModel> _applications =
      const <AffiliateApplicationModel>[];
  AffiliateWorkspace? _affiliateWorkspace;
  List<AccountDeletionRequestModel> _deletions =
      const <AccountDeletionRequestModel>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        _repo.listTraderSeats().catchError((e) {
          debugPrint('AdminTeamSeatsPage listTraderSeats error: $e');
          return <AdminTraderSeat>[];
        }),
        _repo.listConsumerAccounts().catchError((e) {
          debugPrint('AdminTeamSeatsPage listConsumerAccounts error: $e');
          return <AdminConsumerAccount>[];
        }),
        _repo.listAffiliateApplications().catchError((e) {
          debugPrint('AdminTeamSeatsPage listAffiliateApplications error: $e');
          return <AffiliateApplicationModel>[];
        }),
        _repo.getAffiliateWorkspaceSnapshot().catchError((e) {
          debugPrint('AdminTeamSeatsPage getAffiliateWorkspaceSnapshot error: $e');
          return AffiliateWorkspace.fromJson(const <String, Object?>{});
        }),
        _repo.listDeletionRequests().catchError((e) {
          debugPrint('AdminTeamSeatsPage listDeletionRequests error: $e');
          return <AccountDeletionRequestModel>[];
        }),
      ]);
      if (!mounted) return;
      setState(() {
        _seats = results[0] as List<AdminTraderSeat>;
        _consumers = results[1] as List<AdminConsumerAccount>;
        _applications = results[2] as List<AffiliateApplicationModel>;
        _affiliateWorkspace = results[3] as AffiliateWorkspace;
        _deletions = results[4] as List<AccountDeletionRequestModel>;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openProvisionSeatDialog() async {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController emailCtrl = TextEditingController();
    final TextEditingController capitalCtrl = TextEditingController(
      text: '25000000',
    );
    final TextEditingController drawdownCtrl = TextEditingController(
      text: '5.0',
    );
    String role = 'trader';
    String division = 'Index & Options Desk';

    final bool? created = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setModalState) => UiDialog(
          title: 'Provision Institutional Trader Seat',
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                UiField(
                  label: 'Trader Full Name',
                  required: true,
                  child: UiInput(
                    controller: nameCtrl,
                    hintText: 'e.g. Karan Oberoi',
                  ),
                ),
                SizedBox(height: ctx.sp(ctx.ui.spacing.md)),
                UiField(
                  label: 'Corporate Email',
                  required: true,
                  child: UiInput(
                    controller: emailCtrl,
                    hintText: 'karan.oberoi@tradex.in',
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                SizedBox(height: ctx.sp(ctx.ui.spacing.md)),
                UiField(
                  label: 'Institutional Role',
                  child: UiSelect<String>(
                    value: role,
                    options: const <UiOption<String>>[
                      UiOption(value: 'trader', label: 'Proprietary Trader'),
                      UiOption(
                        value: 'risk_manager',
                        label: 'Desk Risk Manager',
                      ),
                      UiOption(value: 'analyst', label: 'Quant / Research Analyst'),
                      UiOption(value: 'admin', label: 'Desk Administrator'),
                    ],
                    onChanged: (String? v) {
                      if (v != null) setModalState(() => role = v);
                    },
                  ),
                ),
                SizedBox(height: ctx.sp(ctx.ui.spacing.md)),
                UiField(
                  label: 'Desk Division',
                  child: UiSelect<String>(
                    value: division,
                    options: const <UiOption<String>>[
                      UiOption(
                        value: 'Index & Options Desk',
                        label: 'Index & Options Desk (NSE NFO)',
                      ),
                      UiOption(
                        value: 'Equities Momentum',
                        label: 'Equities Momentum (NSE/BSE)',
                      ),
                      UiOption(
                        value: 'Quant & Arbitrage',
                        label: 'Quant & Statistical Arbitrage',
                      ),
                      UiOption(
                        value: 'Commodities & FX',
                        label: 'Commodities & Macro FX (MCX)',
                      ),
                    ],
                    onChanged: (String? v) {
                      if (v != null) setModalState(() => division = v);
                    },
                  ),
                ),
                SizedBox(height: ctx.sp(ctx.ui.spacing.md)),
                UiField(
                  label: 'Allocated Capital Limit (INR ₹)',
                  helperText: 'Default ₹2,50,00,000 (₹2.50 Cr)',
                  child: UiInput(
                    controller: capitalCtrl,
                    prefixText: '₹ ',
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(height: ctx.sp(ctx.ui.spacing.md)),
                UiField(
                  label: 'Hard Drawdown Cap (%)',
                  child: UiInput(
                    controller: drawdownCtrl,
                    suffixText: '%',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            UiButton(
              label: 'Cancel',
              variant: UiVariant.outline,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            UiButton(
              label: 'Provision Seat',
              intent: UiIntent.primary,
              onPressed: () {
                if (emailCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(true);
              },
            ),
          ],
        ),
      ),
    );

    if (created == true) {
      final double cap =
          double.tryParse(capitalCtrl.text.replaceAll(',', '').trim()) ??
          25000000.0;
      final double dd = double.tryParse(drawdownCtrl.text.trim()) ?? 5.0;
      await _repo.inviteTraderSeat(
        displayName: nameCtrl.text,
        email: emailCtrl.text,
        role: role,
        deskDivision: division,
        allocatedCapitalInr: cap,
        maxDrawdownLimitPct: dd,
      );
      await _load();
      if (mounted) {
        UiToast.show(
          context,
          title: 'Trader Seat Provisioned',
          message:
              'Assigned ${formatInrCompact(cap)} INR capital in $division.',
          intent: UiIntent.success,
        );
      }
    }
    nameCtrl.dispose();
    emailCtrl.dispose();
    capitalCtrl.dispose();
    drawdownCtrl.dispose();
  }

  Future<void> _openEditSeatDialog(AdminTraderSeat seat) async {
    final TextEditingController capitalCtrl = TextEditingController(
      text: seat.allocatedCapitalInr.toStringAsFixed(0),
    );
    final TextEditingController drawdownCtrl = TextEditingController(
      text: seat.maxDrawdownLimitPct.toStringAsFixed(1),
    );
    String role = seat.role;
    String status = seat.status;

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setModalState) => UiDialog(
          title: 'Manage Seat · ${seat.displayName}',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              UiField(
                label: 'Seat Role',
                child: UiSelect<String>(
                  value: role,
                  options: const <UiOption<String>>[
                    UiOption(value: 'owner', label: 'Managing Partner (Owner)'),
                    UiOption(value: 'admin', label: 'Desk Administrator'),
                    UiOption(
                      value: 'risk_manager',
                      label: 'Desk Risk Manager',
                    ),
                    UiOption(value: 'trader', label: 'Proprietary Trader'),
                    UiOption(value: 'analyst', label: 'Quant Analyst'),
                  ],
                  onChanged: (String? v) {
                    if (v != null) setModalState(() => role = v);
                  },
                ),
              ),
              SizedBox(height: ctx.sp(ctx.ui.spacing.md)),
              UiField(
                label: 'Execution Status',
                child: UiSelect<String>(
                  value: status,
                  options: const <UiOption<String>>[
                    UiOption(value: 'active', label: 'Active (Trading Enabled)'),
                    UiOption(
                      value: 'frozen',
                      label: 'Frozen (Close-Only Mode)',
                    ),
                    UiOption(
                      value: 'suspended',
                      label: 'Suspended (Access Locked)',
                    ),
                  ],
                  onChanged: (String? v) {
                    if (v != null) setModalState(() => status = v);
                  },
                ),
              ),
              SizedBox(height: ctx.sp(ctx.ui.spacing.md)),
              UiField(
                label: 'Allocated Capital (INR ₹)',
                child: UiInput(
                  controller: capitalCtrl,
                  prefixText: '₹ ',
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(height: ctx.sp(ctx.ui.spacing.md)),
              UiField(
                label: 'Max Drawdown Cap (%)',
                child: UiInput(
                  controller: drawdownCtrl,
                  suffixText: '%',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            UiButton(
              label: 'Cancel',
              variant: UiVariant.outline,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            UiButton(
              label: 'Save Changes',
              intent: UiIntent.primary,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final double cap =
          double.tryParse(capitalCtrl.text.replaceAll(',', '').trim()) ??
          seat.allocatedCapitalInr;
      final double dd =
          double.tryParse(drawdownCtrl.text.trim()) ??
          seat.maxDrawdownLimitPct;
      await _repo.updateTraderSeat(
        userId: seat.userId,
        role: role,
        status: status,
        allocatedCapitalInr: cap,
        maxDrawdownLimitPct: dd,
      );
      await _load();
      if (mounted) {
        UiToast.show(
          context,
          title: 'Seat Governance Updated',
          message:
              '${seat.displayName} updated to ${status.toUpperCase()} (${formatInrCompact(cap)}).',
          intent: UiIntent.success,
        );
      }
    }
    capitalCtrl.dispose();
    drawdownCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    if (_loading) {
      return UiSkeleton.page();
    }

    final double totalCapitalInr = _seats.fold<double>(
      0,
      (sum, s) => sum + s.allocatedCapitalInr,
    );
    final double consumerMrrInr = _consumers
        .where((c) => c.status == 'active')
        .fold<double>(0, (sum, c) => sum + c.monthlySubscriptionInr);
    final int pendingDeletions = _deletions
        .where((d) => d.status != 'data_purged' && d.status != 'cancelled')
        .length;

    return UiPage(
      maxWidth: 1440,
      header: UiHeader(
        title: 'Traders, Seats & Account Governance',
        subtitle:
            'Manage institutional desk seats, consumer subscriptions, INR affiliate partners, and conditional DPDP data purges.',
        leading: Icon(Icons.badge_outlined, color: theme.colors.primary),
        actions: <Widget>[
          UiButton(
            label: 'Refresh',
            leadingIcon: Icons.refresh_rounded,
            variant: UiVariant.outline,
            size: UiSize.sm,
            onPressed: _load,
          ),
          UiButton(
            label: 'Provision Trader Seat',
            leadingIcon: Icons.person_add_alt_1_rounded,
            intent: UiIntent.primary,
            size: UiSize.sm,
            onPressed: _openProvisionSeatDialog,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiCardGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 4,
            largeColumns: 4,
            childAspectRatio: context.uiRes.isMobile ? 2.3 : 1.9,
            children: <Widget>[
              UiMetricCard(
                label: 'Active Desk Seats',
                value: '${_seats.length} Seats',
                caption: 'Deployed: ${formatInrCompact(totalCapitalInr)}',
                icon: Icons.badge_outlined,
              ),
              UiMetricCard(
                label: 'Consumer Accounts',
                value: '${_consumers.length} Traders',
                caption: 'MRR: ${formatInrAmount(consumerMrrInr)}/mo',
                icon: Icons.people_alt_outlined,
              ),
              UiMetricCard(
                label: 'Affiliate Partners (INR)',
                value: '${_applications.length} Partners',
                caption:
                    'Tier: ${_affiliateWorkspace?.profile.tier.toUpperCase() ?? "GOLD"} (${((_affiliateWorkspace?.profile.commissionRate ?? 0.25) * 100).toStringAsFixed(0)}%)',
                icon: Icons.handshake_outlined,
              ),
              UiMetricCard(
                label: 'Account Deletion Queue',
                value: '$pendingDeletions Pending',
                caption: '${_deletions.length} total deletion records',
                icon: Icons.delete_sweep_outlined,
                intent: pendingDeletions > 0
                    ? UiIntent.warning
                    : UiIntent.success,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Tab Switcher + Search Filter
          Wrap(
            spacing: context.sp(theme.spacing.md),
            runSpacing: context.sp(theme.spacing.sm),
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              UiToggleGroup<String>(
                value: _activeTab,
                expand: context.uiRes.isMobile,
                options: <UiToggleOption<String>>[
                  UiToggleOption(
                    value: 'seats',
                    label: 'Desk Seats (${_seats.length})',
                  ),
                  UiToggleOption(
                    value: 'consumers',
                    label: 'Consumers (${_consumers.length})',
                  ),
                  UiToggleOption(
                    value: 'affiliates',
                    label: 'Affiliates (${_applications.length})',
                  ),
                  UiToggleOption(
                    value: 'deletions',
                    label: 'Data Purge (${_deletions.length})',
                  ),
                ],
                onChanged: (String v) => setState(() => _activeTab = v),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.uiRes.isMobile ? double.infinity : 320,
                ),
                child: UiInput.search(
                  value: _searchQuery,
                  hintText: 'Filter by name, @handle, division, or email…',
                  onChanged: (String v) => setState(() => _searchQuery = v),
                  onClear: () => setState(() => _searchQuery = ''),
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),

          switch (_activeTab) {
            'seats' => _buildSeatsTable(context),
            'consumers' => _buildConsumersTable(context),
            'affiliates' => _buildAffiliatesSection(context),
            'deletions' => _buildDeletionsQueue(context),
            _ => _buildSeatsTable(context),
          },
        ],
      ),
    );
  }

  Widget _buildSeatsTable(BuildContext context) {
    final UiTheme theme = context.ui;
    final String q = _searchQuery.trim().toLowerCase();
    final List<AdminTraderSeat> filtered = _seats.where((s) {
      if (q.isEmpty) return true;
      return s.displayName.toLowerCase().contains(q) ||
          s.handle.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q) ||
          s.deskDivision.toLowerCase().contains(q) ||
          s.role.toLowerCase().contains(q);
    }).toList();

    return UiTable<AdminTraderSeat>(
      rows: filtered,
      rowKey: (s) => s.userId,
      stackOnMobile: true,
      columns: <UiTableColumn<AdminTraderSeat>>[
        UiTableColumn<AdminTraderSeat>(
          id: 'trader',
          label: 'Trader & Seat Role',
          flex: 2,
          cellBuilder: (BuildContext ctx, AdminTraderSeat s) => Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              UiAvatar(name: s.displayName, size: UiSize.sm),
              SizedBox(width: ctx.sp(theme.spacing.xs)),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      s.displayName,
                      style: ctx.uiText.bodyStrong,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '@${s.handle} · ${s.role.toUpperCase()}',
                      style: ctx.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        UiTableColumn<AdminTraderSeat>(
          id: 'division',
          label: 'Desk Division',
          valueGetter: (s) => s.deskDivision,
        ),
        UiTableColumn<AdminTraderSeat>(
          id: 'capital',
          label: 'Allocated Capital (₹)',
          numeric: true,
          sortValue: (s) => s.allocatedCapitalInr,
          cellBuilder: (BuildContext ctx, AdminTraderSeat s) => Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                formatInrCompact(s.allocatedCapitalInr),
                style: ctx.uiText.mono.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${s.marginUtilizationPct.toStringAsFixed(0)}% margin used',
                style: ctx.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
        UiTableColumn<AdminTraderSeat>(
          id: 'pnl',
          label: '30D Net P&L (₹)',
          numeric: true,
          sortValue: (s) => s.monthlyPnlInr,
          cellBuilder: (BuildContext ctx, AdminTraderSeat s) => Text(
            formatInrCompact(s.monthlyPnlInr, signed: true),
            style: ctx.uiText.mono.copyWith(
              color: s.monthlyPnlInr >= 0
                  ? theme.colors.bullish
                  : theme.colors.bearish,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        UiTableColumn<AdminTraderSeat>(
          id: 'drawdown',
          label: 'Drawdown / Cap',
          numeric: true,
          sortValue: (s) => s.currentDrawdownPct,
          cellBuilder: (BuildContext ctx, AdminTraderSeat s) => UiBadge(
            label:
                '${s.currentDrawdownPct.toStringAsFixed(1)}% / ${s.maxDrawdownLimitPct.toStringAsFixed(1)}%',
            intent: s.isDrawdownNearLimit
                ? UiIntent.danger
                : UiIntent.neutral,
            size: UiSize.xs,
          ),
        ),
        UiTableColumn<AdminTraderSeat>(
          id: 'status',
          label: 'Status',
          cellBuilder: (BuildContext ctx, AdminTraderSeat s) => UiBadge(
            label: s.status.toUpperCase(),
            intent: switch (s.status) {
              'active' => UiIntent.success,
              'frozen' => UiIntent.warning,
              _ => UiIntent.danger,
            },
            size: UiSize.xs,
          ),
        ),
        UiTableColumn<AdminTraderSeat>(
          id: 'actions',
          label: 'Governance',
          cellBuilder: (BuildContext ctx, AdminTraderSeat s) => Wrap(
            spacing: ctx.sp(theme.spacing.xxs),
            children: <Widget>[
              UiButton(
                label: 'Edit',
                size: UiSize.xs,
                variant: UiVariant.outline,
                onPressed: () => _openEditSeatDialog(s),
              ),
              if (s.role != 'owner')
                UiButton(
                  label: s.status == 'frozen' ? 'Unfreeze' : 'Freeze',
                  size: UiSize.xs,
                  variant: UiVariant.ghost,
                  intent: s.status == 'frozen'
                      ? UiIntent.success
                      : UiIntent.warning,
                  onPressed: () async {
                    await _repo.updateTraderSeat(
                      userId: s.userId,
                      status: s.status == 'frozen' ? 'active' : 'frozen',
                    );
                    await _load();
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConsumersTable(BuildContext context) {
    final UiTheme theme = context.ui;
    final String q = _searchQuery.trim().toLowerCase();
    final List<AdminConsumerAccount> filtered = _consumers.where((c) {
      if (q.isEmpty) return true;
      return c.displayName.toLowerCase().contains(q) ||
          c.handle.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q) ||
          c.subscriptionTier.toLowerCase().contains(q) ||
          (c.referredBySlug?.toLowerCase().contains(q) ?? false);
    }).toList();

    return UiTable<AdminConsumerAccount>(
      rows: filtered,
      rowKey: (c) => c.userId,
      stackOnMobile: true,
      columns: <UiTableColumn<AdminConsumerAccount>>[
        UiTableColumn<AdminConsumerAccount>(
          id: 'consumer',
          label: 'Trader Account',
          flex: 2,
          cellBuilder: (BuildContext ctx, AdminConsumerAccount c) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                c.displayName,
                style: ctx.uiText.bodyStrong,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '@${c.handle} · ${c.email}',
                style: ctx.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        UiTableColumn<AdminConsumerAccount>(
          id: 'tier',
          label: 'Subscription Plan (INR)',
          cellBuilder: (BuildContext ctx, AdminConsumerAccount c) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              UiBadge(
                label: c.subscriptionTier.toUpperCase(),
                intent: c.subscriptionTier == 'Enterprise'
                    ? UiIntent.primary
                    : c.subscriptionTier == 'Pro'
                    ? UiIntent.info
                    : UiIntent.neutral,
                size: UiSize.xs,
              ),
              Text(
                '${formatInrAmount(c.monthlySubscriptionInr)}/mo',
                style: ctx.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
        UiTableColumn<AdminConsumerAccount>(
          id: 'activity',
          label: 'Writing Desk & AI',
          valueGetter: (c) =>
              '${c.journalsCount} Journals · ${c.strategiesCount} Strategies · ${c.aiQueriesUsed} AI',
        ),
        UiTableColumn<AdminConsumerAccount>(
          id: 'affiliate_link',
          label: 'Affiliate Attribution',
          cellBuilder: (BuildContext ctx, AdminConsumerAccount c) =>
              c.referredBySlug != null
              ? UiBadge(
                  label: '/r/${c.referredBySlug}',
                  intent: UiIntent.success,
                  size: UiSize.xs,
                )
              : Text(
                  'Organic Direct',
                  style: ctx.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
        ),
        UiTableColumn<AdminConsumerAccount>(
          id: 'status',
          label: 'Status',
          cellBuilder: (BuildContext ctx, AdminConsumerAccount c) => UiBadge(
            label: c.status.toUpperCase(),
            intent: c.status == 'active'
                ? UiIntent.success
                : UiIntent.warning,
            size: UiSize.xs,
          ),
        ),
        UiTableColumn<AdminConsumerAccount>(
          id: 'actions',
          label: 'Actions',
          cellBuilder: (BuildContext ctx, AdminConsumerAccount c) => Wrap(
            spacing: ctx.sp(theme.spacing.xxs),
            children: <Widget>[
              UiButton(
                label: c.subscriptionTier == 'Enterprise'
                    ? 'Set Pro'
                    : 'Grant Enterprise',
                size: UiSize.xs,
                variant: UiVariant.outline,
                onPressed: () async {
                  await _repo.updateConsumerAccount(
                    userId: c.userId,
                    subscriptionTier: c.subscriptionTier == 'Enterprise'
                        ? 'Pro'
                        : 'Enterprise',
                  );
                  await _load();
                },
              ),
              UiButton(
                label: c.status == 'active' ? 'Suspend' : 'Activate',
                size: UiSize.xs,
                variant: UiVariant.ghost,
                intent: c.status == 'active'
                    ? UiIntent.danger
                    : UiIntent.success,
                onPressed: () async {
                  await _repo.updateConsumerAccount(
                    userId: c.userId,
                    status: c.status == 'active' ? 'suspended' : 'active',
                  );
                  await _load();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAffiliatesSection(BuildContext context) {
    final UiTheme theme = context.ui;
    final AffiliateWorkspace? ws = _affiliateWorkspace;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (ws != null)
          UiCard(
            child: Wrap(
              spacing: context.sp(theme.spacing.lg),
              runSpacing: context.sp(theme.spacing.md),
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Active Partner Ledger · ${ws.profile.displayName} (/r/${ws.profile.referralSlug})',
                      style: context.uiText.subheading,
                    ),
                    Text(
                      'Tier: ${ws.profile.tier.toUpperCase()} (${(ws.profile.commissionRate * 100).toStringAsFixed(0)}% INR Commission) · Lifetime: ${formatInrAmount(ws.profile.lifetimeEarnings)} · Unpaid Balance: ${formatInrAmount(ws.profile.unpaidBalance)} · Settled: ${formatInrAmount(ws.profile.totalPaidOut)}',
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: context.sp(theme.spacing.xs),
                  children: <Widget>[
                    UiButton(
                      label: 'Promote to Platinum (35%)',
                      size: UiSize.xs,
                      variant: UiVariant.outline,
                      onPressed: () async {
                        await AffiliateWorkspaceRepository.instance
                            .adminUpdatePartnerTier(
                              tierId: 'platinum',
                              commissionRate: 0.35,
                            );
                        await _load();
                        if (context.mounted) {
                          UiToast.show(
                            context,
                            title: 'Partner Tier Upgraded',
                            message:
                                'Upgraded partner to Platinum (35% recurring INR commission).',
                            intent: UiIntent.success,
                          );
                        }
                      },
                    ),
                    UiButton(
                      label: 'Open Affiliate Approvals & INR Payouts',
                      size: UiSize.xs,
                      intent: UiIntent.primary,
                      onPressed: () =>
                          widget.onNavigate?.call('affiliate_reviews'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiTable<AffiliateApplicationModel>(
          rows: _applications,
          rowKey: (a) => a.id,
          stackOnMobile: true,
          columns: <UiTableColumn<AffiliateApplicationModel>>[
            UiTableColumn<AffiliateApplicationModel>(
              id: 'partner',
              label: 'Partner & Channel',
              flex: 2,
              valueGetter: (a) =>
                  '${a.fullName} (${a.primaryPlatform} · ${a.channelHandle})',
            ),
            UiTableColumn<AffiliateApplicationModel>(
              id: 'region',
              label: 'Region & Reach',
              valueGetter: (a) => '${a.city}, ${a.state} · ${a.audienceReach}',
            ),
            UiTableColumn<AffiliateApplicationModel>(
              id: 'bank',
              label: 'Indian Payout Rail (INR)',
              valueGetter: (a) =>
                  '${a.bankName} · ${a.maskedAccountNumber} (${a.ifscCode})',
            ),
            UiTableColumn<AffiliateApplicationModel>(
              id: 'status',
              label: 'Application Status',
              cellBuilder: (BuildContext ctx, AffiliateApplicationModel a) =>
                  UiBadge(
                    label: a.status.apiValue.toUpperCase(),
                    intent: switch (a.status) {
                      AffiliateApplicationStatus.approved => UiIntent.success,
                      AffiliateApplicationStatus.pending => UiIntent.warning,
                      _ => UiIntent.danger,
                    },
                    size: UiSize.xs,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeletionsQueue(BuildContext context) {
    final UiTheme theme = context.ui;
    if (_deletions.isEmpty) {
      return const UiEmptyState(
        icon: Icons.delete_sweep_outlined,
        title: 'No account deletion requests',
        message:
            'When a Trader, Affiliate, or Admin requests account deletion with a data purge condition, it appears here.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _deletions
          .map(
            (req) => Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.md)),
              child: UiCard(
                variant: UiCardVariant.outlined,
                intent: req.status == 'data_purged'
                    ? UiIntent.neutral
                    : UiIntent.warning,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Wrap(
                      spacing: context.sp(theme.spacing.sm),
                      runSpacing: context.sp(theme.spacing.xs),
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            UiAvatar(
                              name: req.userDisplayName,
                              size: UiSize.md,
                            ),
                            SizedBox(width: context.sp(theme.spacing.sm)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  '${req.userDisplayName} (${req.userEmail})',
                                  style: context.uiText.bodyStrong,
                                ),
                                Text(
                                  'Role: ${req.userRole.toUpperCase()} · Requested ${AppTokens.shortDate(req.requestedAt)} · Scheduled Purge: ${AppTokens.shortDate(req.scheduledPurgeAt)}',
                                  style: context.uiText.caption.copyWith(
                                    color: theme.colors.foregroundMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        UiBadge(
                          label: req.status.toUpperCase(),
                          intent: req.status == 'data_purged'
                              ? UiIntent.danger
                              : req.status == 'cancelled'
                              ? UiIntent.success
                              : UiIntent.warning,
                          size: UiSize.xs,
                        ),
                      ],
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    UiCallout(
                      title: 'Selected Condition: ${req.conditionLabel}',
                      message:
                          'Reason: ${req.reason}${(req.feedback ?? '').isNotEmpty ? " — \"${req.feedback}\"" : ""}\n'
                          'Scopes Bound to Purge: '
                          '${[if (req.purgeJournalsNotesStrategies) "Journals/Strategies/Notes", if (req.purgeCommunityMessages) "Community/Messages", if (req.purgeAiWorkspace) "AI Copilot", if (req.purgeAffiliateCampaigns) "Affiliate Campaigns"].join(" · ")}',
                      intent: req.status == 'data_purged'
                          ? UiIntent.neutral
                          : UiIntent.warning,
                    ),
                    if (req.status != 'data_purged' &&
                        req.status != 'cancelled') ...<Widget>[
                      SizedBox(height: context.sp(theme.spacing.sm)),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: context.sp(theme.spacing.sm),
                        runSpacing: context.sp(theme.spacing.xs),
                        children: <Widget>[
                          UiButton(
                            label: 'Cancel & Restore Account',
                            size: UiSize.xs,
                            variant: UiVariant.outline,
                            onPressed: () async {
                              await _repo.processDeletionRequest(
                                requestId: req.id,
                                action: 'cancel_deletion',
                                adminNotes:
                                    'Cancelled and restored by Desk Admin.',
                              );
                              await _load();
                              if (context.mounted) {
                                UiToast.show(
                                  context,
                                  title: 'Account Deletion Cancelled',
                                  message:
                                      '${req.userDisplayName} account restored to active status.',
                                  intent: UiIntent.success,
                                );
                              }
                            },
                          ),
                          UiButton(
                            label: 'Execute Conditional Data Purge Now',
                            size: UiSize.xs,
                            intent: UiIntent.danger,
                            variant: UiVariant.destructive,
                            leadingIcon: Icons.delete_forever_rounded,
                            onPressed: () async {
                              await _repo.processDeletionRequest(
                                requestId: req.id,
                                action: 'execute_purge',
                                adminNotes:
                                    'Conditional data purge executed by Desk Admin.',
                              );
                              await _load();
                              if (context.mounted) {
                                UiToast.show(
                                  context,
                                  title: 'Conditional Data Purge Executed',
                                  message:
                                      'Purged selected data domains for ${req.userDisplayName} and logged SHA-256 compliance proof.',
                                  intent: UiIntent.warning,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
