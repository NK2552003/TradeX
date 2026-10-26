import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/admin_console/data/admin_console_repository.dart';
import 'package:tradex/features/admin_console/models/admin_console_models.dart';
import 'package:tradex/features/affiliate_program/data/affiliate_workspace_repository.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_application_model.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_workspace.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';

class AdminTeamSeatsPage extends StatefulWidget {
  const AdminTeamSeatsPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<AdminTeamSeatsPage> createState() => _AdminTeamSeatsPageState();
}

class _AdminTeamSeatsPageState extends State<AdminTeamSeatsPage> {
  final AdminConsoleRepository _repo = AdminConsoleRepository.instance;

  bool _loading = true;
  String _activeTab = 'consumers'; // consumers | seats | affiliates | deletions
  String _searchQuery = '';
  String _selectedPlan = 'All'; // All | Enterprise | Pro | Basic

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
          debugPrint(
            'AdminTeamSeatsPage getAffiliateWorkspaceSnapshot error: $e',
          );
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

  // ─────────────────────────────────────────────────────────────────────────
  // Right-Side Overlay Subpages
  // ─────────────────────────────────────────────────────────────────────────

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
    String? formError;

    final bool? created = await DeskOverlaySheet.show<bool>(
      context: context,
      title: 'Provision Institutional Trader Seat',
      subtitle:
          'Assign risk envelope, hard drawdown caps, and division permissions.',
      actions: <Widget>[
        Builder(
          builder: (BuildContext ctx) => UiButton(
            label: 'Cancel',
            variant: UiVariant.outline,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ),
        StatefulBuilder(
          builder: (BuildContext ctx, StateSetter _) => UiButton(
            label: 'Provision Seat',
            intent: UiIntent.primary,
            variant: UiVariant.solid,
            onPressed: () {
              final capital = double.tryParse(
                capitalCtrl.text.replaceAll(',', '').trim(),
              );
              final drawdown = double.tryParse(drawdownCtrl.text.trim());
              if (nameCtrl.text.trim().isEmpty ||
                  !RegExp(
                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                  ).hasMatch(emailCtrl.text.trim()) ||
                  capital == null ||
                  !capital.isFinite ||
                  capital <= 0 ||
                  drawdown == null ||
                  !drawdown.isFinite ||
                  drawdown <= 0 ||
                  drawdown > 100) {
                formError =
                    'Enter a name, valid email, positive capital and a drawdown cap between 0 and 100%.';
                (ctx as Element).markNeedsBuild();
                return;
              }
              Navigator.of(ctx).pop(true);
            },
          ),
        ),
      ],
      child: StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setModalState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (formError != null) ...[
              UiCallout(
                title: 'Check seat details',
                message: formError,
                intent: UiIntent.warning,
              ),
              UiGap.v(ctx.ui.spacing.md),
            ],
            UiField(
              label: 'Trader Full Name',
              required: true,
              child: UiInput(
                controller: nameCtrl,
                hintText: 'e.g. Karan Oberoi',
                onChanged: (_) {
                  if (formError != null) {
                    setModalState(() => formError = null);
                  }
                },
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
                onChanged: (_) {
                  if (formError != null) {
                    setModalState(() => formError = null);
                  }
                },
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
                  UiOption(
                    value: 'analyst',
                    label: 'Quant / Research Analyst',
                  ),
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

  Future<void> _openConsumerDetailsOverlay(AdminConsumerAccount consumer) async {
    final theme = context.ui;
    final c = theme.colors;

    await DeskOverlaySheet.show<void>(
      context: context,
      title: 'Trader Account · ${consumer.displayName}',
      subtitle: '@${consumer.handle} · ${consumer.email}',
      actions: <Widget>[
        Builder(
          builder: (BuildContext ctx) => UiButton(
            label: 'Close',
            variant: UiVariant.outline,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Account Status & Plan Card
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.md)),
            decoration: BoxDecoration(
              border: Border.all(color: c.border, width: theme.borders.hairline),
              borderRadius: context.radius(theme.radii.md),
              color: c.surface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Subscription Plan',
                      style: context.uiText.caption.copyWith(color: c.foregroundMuted),
                    ),
                    UiBadge(
                      label: consumer.subscriptionTier.toUpperCase(),
                      intent: consumer.subscriptionTier == 'Enterprise'
                          ? UiIntent.primary
                          : consumer.subscriptionTier == 'Pro'
                          ? UiIntent.info
                          : UiIntent.neutral,
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                Text(
                  '${formatInrAmount(consumer.monthlySubscriptionInr)}/month',
                  style: context.uiText.heading.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.sm)),
                Wrap(
                  spacing: context.sp(theme.spacing.xs),
                  runSpacing: context.sp(theme.spacing.xs),
                  children: <Widget>[
                    if (consumer.subscriptionTier != 'Basic')
                      UiButton(
                        label: 'Set Basic (₹0)',
                        size: UiSize.xs,
                        variant: UiVariant.outline,
                        onPressed: () async {
                          await _repo.updateConsumerAccount(
                            userId: consumer.userId,
                            subscriptionTier: 'Basic',
                          );
                          await _load();
                          if (mounted) {
                            Navigator.of(context).pop();
                            UiToast.show(
                              context,
                              title: '${consumer.displayName} is now on Basic',
                              intent: UiIntent.info,
                            );
                          }
                        },
                      ),
                    if (consumer.subscriptionTier != 'Pro')
                      UiButton(
                        label: 'Set Pro (₹2,499)',
                        size: UiSize.xs,
                        variant: UiVariant.outline,
                        intent: UiIntent.info,
                        onPressed: () async {
                          await _repo.updateConsumerAccount(
                            userId: consumer.userId,
                            subscriptionTier: 'Pro',
                          );
                          await _load();
                          if (mounted) {
                            Navigator.of(context).pop();
                            UiToast.show(
                              context,
                              title: '${consumer.displayName} is now on Pro',
                              intent: UiIntent.success,
                            );
                          }
                        },
                      ),
                    if (consumer.subscriptionTier != 'Enterprise')
                      UiButton(
                        label: 'Grant Enterprise (₹7,999)',
                        size: UiSize.xs,
                        variant: UiVariant.solid,
                        intent: UiIntent.primary,
                        onPressed: () async {
                          await _repo.updateConsumerAccount(
                            userId: consumer.userId,
                            subscriptionTier: 'Enterprise',
                          );
                          await _load();
                          if (mounted) {
                            Navigator.of(context).pop();
                            UiToast.show(
                              context,
                              title: '${consumer.displayName} now has Enterprise',
                              intent: UiIntent.success,
                            );
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),

          // Usage Telemetry
          Text('Platform Activity', style: context.uiText.bodyStrong),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Row(
            children: <Widget>[
              Expanded(
                child: _UsageBox(
                  label: 'Journals',
                  value: '${consumer.journalsCount}',
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Expanded(
                child: _UsageBox(
                  label: 'Strategies',
                  value: '${consumer.strategiesCount}',
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Expanded(
                child: _UsageBox(
                  label: 'AI Copilot',
                  value: '${consumer.aiQueriesUsed}',
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),

          // Attribution
          Text('Attribution Source', style: context.uiText.bodyStrong),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            consumer.referredBySlug != null
                ? 'Referred via partner link: /r/${consumer.referredBySlug}'
                : 'Organic direct registration',
            style: context.uiText.caption.copyWith(color: c.foregroundMuted),
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Suspension Control
          UiButton(
            label: consumer.status == 'active'
                ? 'Suspend Account Access'
                : 'Activate Account Access',
            variant: UiVariant.outline,
            intent: consumer.status == 'active'
                ? UiIntent.danger
                : UiIntent.success,
            onPressed: () async {
              final newStatus = consumer.status == 'active' ? 'suspended' : 'active';
              await _repo.updateConsumerAccount(
                userId: consumer.userId,
                status: newStatus,
              );
              await _load();
              if (mounted) {
                Navigator.of(context).pop();
                UiToast.show(
                  context,
                  title: consumer.status == 'active'
                      ? '${consumer.displayName} suspended'
                      : '${consumer.displayName} activated',
                  intent: consumer.status == 'active'
                      ? UiIntent.warning
                      : UiIntent.success,
                );
              }
            },
          ),
        ],
      ),
    );
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

    final bool? saved = await DeskOverlaySheet.show<bool>(
      context: context,
      title: 'Manage Seat · ${seat.displayName}',
      subtitle: '@${seat.handle} · ${seat.deskDivision}',
      actions: <Widget>[
        Builder(
          builder: (BuildContext ctx) => UiButton(
            label: 'Cancel',
            variant: UiVariant.outline,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ),
        Builder(
          builder: (BuildContext ctx) => UiButton(
            label: 'Save Changes',
            intent: UiIntent.primary,
            variant: UiVariant.solid,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ),
      ],
      child: StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setModalState) => Column(
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
                  UiOption(value: 'risk_manager', label: 'Desk Risk Manager'),
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
                  UiOption(value: 'frozen', label: 'Frozen (Close-Only Mode)'),
                  UiOption(value: 'suspended', label: 'Suspended (Access Locked)'),
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
      ),
    );

    if (saved == true) {
      final double cap =
          double.tryParse(capitalCtrl.text.replaceAll(',', '').trim()) ??
          seat.allocatedCapitalInr;
      final double dd =
          double.tryParse(drawdownCtrl.text.trim()) ?? seat.maxDrawdownLimitPct;
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

  Future<void> _openAffiliateOverlay(AffiliateApplicationModel app) async {
    final theme = context.ui;
    final c = theme.colors;

    await DeskOverlaySheet.show<void>(
      context: context,
      title: 'Partner Review · ${app.fullName}',
      subtitle: '${app.primaryPlatform} · ${app.channelHandle}',
      actions: <Widget>[
        Builder(
          builder: (BuildContext ctx) => UiButton(
            label: 'Close',
            variant: UiVariant.outline,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ),
        UiButton(
          label: 'Promote to Platinum (35%)',
          intent: UiIntent.primary,
          variant: UiVariant.solid,
          onPressed: () async {
            await AffiliateWorkspaceRepository.instance.adminUpdatePartnerTier(
              tierId: 'platinum',
              commissionRate: 0.35,
            );
            await _load();
            if (mounted) {
              Navigator.of(context).pop();
              UiToast.show(
                context,
                title: 'Partner Tier Upgraded',
                message: 'Promoted ${app.fullName} to Platinum (35%).',
                intent: UiIntent.success,
              );
            }
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.md)),
            decoration: BoxDecoration(
              border: Border.all(color: c.border, width: theme.borders.hairline),
              borderRadius: context.radius(theme.radii.md),
              color: c.surface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Audience & Reach', style: context.uiText.bodyStrong),
                SizedBox(height: context.sp(theme.spacing.xxs)),
                Text(
                  '${app.city}, ${app.state} · ${app.audienceReach}',
                  style: context.uiText.caption.copyWith(color: c.foregroundMuted),
                ),
                SizedBox(height: context.sp(theme.spacing.sm)),
                Text('Indian Bank Payout Rail (INR)', style: context.uiText.bodyStrong),
                SizedBox(height: context.sp(theme.spacing.xxs)),
                Text(
                  '${app.bankName} · ${app.maskedAccountNumber}\nIFSC: ${app.ifscCode}',
                  style: context.uiText.caption.copyWith(color: c.foregroundMuted),
                ),
                SizedBox(height: context.sp(theme.spacing.sm)),
                Text('Compliance & KYC', style: context.uiText.bodyStrong),
                SizedBox(height: context.sp(theme.spacing.xxs)),
                Text(
                  'PAN verified. SEBI / ASCI compliance declared.',
                  style: context.uiText.caption.copyWith(color: c.foregroundMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDeletionOverlay(AccountDeletionRequestModel req) async {
    final theme = context.ui;
    final c = theme.colors;

    await DeskOverlaySheet.show<void>(
      context: context,
      title: 'DPDP Data Purge Inspection',
      subtitle: '${req.userDisplayName} (${req.userEmail})',
      actions: <Widget>[
        Builder(
          builder: (BuildContext ctx) => UiButton(
            label: 'Close',
            variant: UiVariant.outline,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.md)),
            decoration: BoxDecoration(
              border: Border.all(color: c.border, width: theme.borders.hairline),
              borderRadius: context.radius(theme.radii.md),
              color: c.surface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Selected Condition: ${req.conditionLabel}', style: context.uiText.bodyStrong),
                SizedBox(height: context.sp(theme.spacing.xxs)),
                Text(
                  'Reason: ${req.reason}${(req.feedback ?? "").isNotEmpty ? " — \"${req.feedback}\"" : ""}',
                  style: context.uiText.caption.copyWith(color: c.foregroundMuted),
                ),
                SizedBox(height: context.sp(theme.spacing.sm)),
                Text('Scheduled Purge Date', style: context.uiText.bodyStrong),
                SizedBox(height: context.sp(theme.spacing.xxs)),
                Text(
                  AppTokens.shortDate(req.scheduledPurgeAt),
                  style: context.uiText.caption.copyWith(color: c.foregroundMuted),
                ),
              ],
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          if (req.status != 'data_purged' && req.status != 'cancelled') ...[
            UiButton(
              label: 'Cancel & Restore Account',
              variant: UiVariant.outline,
              onPressed: () async {
                await _repo.processDeletionRequest(
                  requestId: req.id,
                  action: 'cancel_deletion',
                  adminNotes: 'Restored from Desk Overlay.',
                );
                await _load();
                if (mounted) {
                  Navigator.of(context).pop();
                  UiToast.show(context, title: 'Account Deletion Cancelled', intent: UiIntent.success);
                }
              },
            ),
            SizedBox(height: context.sp(theme.spacing.xs)),
            UiButton(
              label: 'Execute Conditional Data Purge Now',
              intent: UiIntent.danger,
              variant: UiVariant.destructive,
              onPressed: () async {
                await _repo.processDeletionRequest(
                  requestId: req.id,
                  action: 'execute_purge',
                  adminNotes: 'Purge executed from Desk Overlay.',
                );
                await _load();
                if (mounted) {
                  Navigator.of(context).pop();
                  UiToast.show(context, title: 'Conditional Data Purge Executed', intent: UiIntent.warning);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;

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
    final int paidCount = _consumers
        .where((c) => c.status == 'active' && c.subscriptionTier != 'Basic')
        .length;
    final int pendingDeletions = _deletions
        .where((d) => d.status != 'data_purged' && d.status != 'cancelled')
        .length;

    return Scaffold(
      backgroundColor: c.background,
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.md),
                vertical: context.sp(theme.spacing.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Header
                  Padding(
                    padding: EdgeInsets.only(
                      top: context.sp(theme.spacing.sm),
                      bottom: context.sp(theme.spacing.md),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Traders, seats & accounts',
                                style: context.uiText.title.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 30,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.xxs)),
                              Text(
                                'Manage desk seats, consumer plans, INR affiliate partners and data-deletion requests.',
                                style: context.uiText.caption.copyWith(
                                  color: c.foregroundMuted,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: context.sp(theme.spacing.md)),
                        Wrap(
                          spacing: context.sp(theme.spacing.xs),
                          runSpacing: context.sp(theme.spacing.xs),
                          children: <Widget>[
                            UiButton(
                              label: 'Refresh',
                              variant: UiVariant.outline,
                              size: UiSize.sm,
                              onPressed: () {
                                _load();
                                UiToast.show(
                                  context,
                                  title: 'List refreshed',
                                  intent: UiIntent.info,
                                );
                              },
                            ),
                            UiButton(
                              label: 'Provision trader seat',
                              intent: UiIntent.primary,
                              variant: UiVariant.solid,
                              size: UiSize.sm,
                              onPressed: _openProvisionSeatDialog,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 4-column Ledger
                  DeskLedgerBlock(
                    items: <DeskLedgerItem>[
                      DeskLedgerItem(
                        label: 'Active desk seats',
                        value: '${_seats.length} seats',
                        subtext: 'Deployed ${formatInrCompact(totalCapitalInr)}',
                      ),
                      DeskLedgerItem(
                        label: 'Consumer accounts',
                        value: '${_consumers.length} traders',
                        subtext:
                            'MRR ${formatInrAmount(consumerMrrInr)}/mo · $paidCount paid',
                      ),
                      DeskLedgerItem(
                        label: 'Affiliate partners (INR)',
                        value: '${_applications.length} partner',
                        subtext: 'Gold tier, 25% commission',
                      ),
                      DeskLedgerItem(
                        label: 'Account deletion queue',
                        value: '$pendingDeletions pending',
                        subtext:
                            '${_deletions.length} deletion records in total',
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.md)),

                  // Tab Switcher
                  UiToggleGroup<String>(
                    value: _activeTab,
                    expand: context.uiRes.isMobile,
                    options: <UiToggleOption<String>>[
                      UiToggleOption(
                        value: 'consumers',
                        label: 'Consumers (${_consumers.length})',
                      ),
                      UiToggleOption(
                        value: 'seats',
                        label: 'Desk Seats (${_seats.length})',
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
                  SizedBox(height: context.sp(theme.spacing.md)),

                  // Tab Content Body
                  switch (_activeTab) {
                    'seats' => _buildSeatsTable(context),
                    'consumers' => _buildConsumersTable(context),
                    'affiliates' => _buildAffiliatesSection(context),
                    'deletions' => _buildDeletionsQueue(context),
                    _ => _buildConsumersTable(context),
                  },
                  SizedBox(height: context.sp(theme.spacing.xxl)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tab 1: Consumers Table
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildConsumersTable(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;

    final String q = _searchQuery.trim().toLowerCase();
    final List<AdminConsumerAccount> filtered = _consumers.where((item) {
      if (_selectedPlan != 'All' && item.subscriptionTier != _selectedPlan) {
        return false;
      }
      if (q.isEmpty) return true;
      return item.displayName.toLowerCase().contains(q) ||
          item.handle.toLowerCase().contains(q) ||
          item.email.toLowerCase().contains(q);
    }).toList();

    final int enterpriseCount =
        _consumers.where((u) => u.subscriptionTier == 'Enterprise').length;
    final int proCount =
        _consumers.where((u) => u.subscriptionTier == 'Pro').length;
    final int basicCount =
        _consumers.where((u) => u.subscriptionTier == 'Basic').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Filter bar: Search input + Plan Chips
        Wrap(
          spacing: context.sp(theme.spacing.sm),
          runSpacing: context.sp(theme.spacing.xs),
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.uiRes.isMobile ? double.infinity : 380,
              ),
              child: UiInput.search(
                value: _searchQuery,
                hintText: 'Search name, @handle or email',
                onChanged: (String v) => setState(() => _searchQuery = v),
                onClear: () => setState(() => _searchQuery = ''),
              ),
            ),
            Wrap(
              spacing: context.sp(theme.spacing.xxs),
              children: <Widget>[
                _PlanChip(
                  label: 'All ${_consumers.length}',
                  isSelected: _selectedPlan == 'All',
                  onTap: () => setState(() => _selectedPlan = 'All'),
                ),
                _PlanChip(
                  label: 'Enterprise $enterpriseCount',
                  isSelected: _selectedPlan == 'Enterprise',
                  onTap: () => setState(() => _selectedPlan = 'Enterprise'),
                ),
                _PlanChip(
                  label: 'Pro $proCount',
                  isSelected: _selectedPlan == 'Pro',
                  onTap: () => setState(() => _selectedPlan = 'Pro'),
                ),
                _PlanChip(
                  label: 'Basic $basicCount',
                  isSelected: _selectedPlan == 'Basic',
                  onTap: () => setState(() => _selectedPlan = 'Basic'),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Data Table
        UiTable<AdminConsumerAccount>(
          rows: filtered,
          rowKey: (item) => item.userId,
          onRowTap: (item) => _openConsumerDetailsOverlay(item),
          stackOnMobile: true,
          columns: <UiTableColumn<AdminConsumerAccount>>[
            UiTableColumn<AdminConsumerAccount>(
              id: 'trader',
              label: 'Trader',
              flex: 2,
              cellBuilder: (BuildContext ctx, AdminConsumerAccount u) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    u.displayName,
                    style: ctx.uiText.bodyStrong.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '@${u.handle} · ${u.email}',
                    style: ctx.uiText.caption.copyWith(
                      color: c.foregroundMuted,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            UiTableColumn<AdminConsumerAccount>(
              id: 'plan',
              label: 'Plan',
              cellBuilder: (BuildContext ctx, AdminConsumerAccount u) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  UiBadge(
                    label: u.subscriptionTier,
                    intent: u.subscriptionTier == 'Enterprise'
                        ? UiIntent.primary
                        : (u.subscriptionTier == 'Pro'
                            ? UiIntent.info
                            : UiIntent.neutral),
                    size: UiSize.xs,
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${formatInrAmount(u.monthlySubscriptionInr)}/mo',
                    style: ctx.uiText.caption.copyWith(
                      color: c.foregroundMuted,
                      fontSize: 12,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            UiTableColumn<AdminConsumerAccount>(
              id: 'usage',
              label: 'Usage',
              valueGetter: (u) =>
                  '${u.journalsCount} journals · ${u.strategiesCount} strategies · ${u.aiQueriesUsed} AI',
            ),
            UiTableColumn<AdminConsumerAccount>(
              id: 'source',
              label: 'Source',
              valueGetter: (u) => u.referredBySlug != null
                  ? '/r/${u.referredBySlug}'
                  : 'Organic direct',
            ),
            UiTableColumn<AdminConsumerAccount>(
              id: 'status',
              label: 'Status',
              cellBuilder: (BuildContext ctx, AdminConsumerAccount u) => UiBadge(
                label: u.status == 'active' ? 'Active' : 'Suspended',
                intent: u.status == 'active' ? UiIntent.success : UiIntent.warning,
                size: UiSize.xs,
              ),
            ),
            UiTableColumn<AdminConsumerAccount>(
              id: 'actions',
              label: 'Actions',
              cellBuilder: (BuildContext ctx, AdminConsumerAccount u) {
                final bool isEnt = u.subscriptionTier == 'Enterprise';
                final bool isActive = u.status == 'active';
                return Wrap(
                  spacing: ctx.sp(theme.spacing.xxs),
                  children: <Widget>[
                    UiButton(
                      label: isEnt ? 'Set Pro' : 'Grant Enterprise',
                      size: UiSize.xs,
                      variant: UiVariant.outline,
                      onPressed: () async {
                        final String newPlan = isEnt ? 'Pro' : 'Enterprise';
                        await _repo.updateConsumerAccount(
                          userId: u.userId,
                          subscriptionTier: newPlan,
                        );
                        await _load();
                        if (context.mounted) {
                          UiToast.show(
                            context,
                            title: isEnt
                                ? '${u.displayName} is now on Pro'
                                : '${u.displayName} now has Enterprise',
                            intent: UiIntent.success,
                          );
                        }
                      },
                    ),
                    UiButton(
                      label: isActive ? 'Suspend' : 'Activate',
                      size: UiSize.xs,
                      variant: UiVariant.ghost,
                      intent: isActive ? UiIntent.danger : UiIntent.success,
                      onPressed: () async {
                        final String newStatus = isActive ? 'suspended' : 'active';
                        await _repo.updateConsumerAccount(
                          userId: u.userId,
                          status: newStatus,
                        );
                        await _load();
                        if (context.mounted) {
                          UiToast.show(
                            context,
                            title: isActive
                                ? '${u.displayName} suspended'
                                : '${u.displayName} activated',
                            intent: isActive ? UiIntent.warning : UiIntent.success,
                          );
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        Text(
          'Showing ${filtered.length} of ${_consumers.length} traders',
          style: context.uiText.caption.copyWith(color: c.foregroundMuted),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tab 2: Desk Seats Table
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSeatsTable(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;

    final String q = _searchQuery.trim().toLowerCase();
    final List<AdminTraderSeat> filtered = _seats.where((s) {
      if (q.isEmpty) return true;
      return s.displayName.toLowerCase().contains(q) ||
          s.handle.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q) ||
          s.deskDivision.toLowerCase().contains(q) ||
          s.role.toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiTable<AdminTraderSeat>(
          rows: filtered,
          rowKey: (s) => s.userId,
          onRowTap: (s) => _openEditSeatDialog(s),
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
                          style: ctx.uiText.bodyStrong.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '@${s.handle} · ${s.role.toUpperCase()}',
                          style: ctx.uiText.caption.copyWith(
                            color: c.foregroundMuted,
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
                      color: c.foregroundMuted,
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
                  color: s.monthlyPnlInr >= 0 ? c.bullish : c.bearish,
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
                intent: s.isDrawdownNearLimit ? UiIntent.danger : UiIntent.neutral,
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
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tab 3: Affiliates Section
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAffiliatesSection(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;
    final AffiliateWorkspace? ws = _affiliateWorkspace;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (ws != null)
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.md)),
            decoration: BoxDecoration(
              border: Border.all(color: c.border, width: theme.borders.hairline),
              borderRadius: context.radius(theme.radii.md),
              color: c.surface,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Active Partner Ledger · ${ws.profile.displayName} (/r/${ws.profile.referralSlug})',
                        style: context.uiText.bodyStrong.copyWith(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: context.sp(theme.spacing.xxs)),
                      Text(
                        'Tier: ${ws.profile.tier.toUpperCase()} (${(ws.profile.commissionRate * 100).toStringAsFixed(0)}% Commission) · Unpaid: ${formatInrAmount(ws.profile.unpaidBalance)} · Paid Out: ${formatInrAmount(ws.profile.totalPaidOut)}',
                        style: context.uiText.caption.copyWith(color: c.foregroundMuted),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                UiButton(
                  label: 'Review Affiliates',
                  size: UiSize.xs,
                  intent: UiIntent.primary,
                  onPressed: () => widget.onNavigate?.call('affiliate_reviews'),
                ),
              ],
            ),
          ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiTable<AffiliateApplicationModel>(
          rows: _applications,
          rowKey: (a) => a.id,
          onRowTap: (a) => _openAffiliateOverlay(a),
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

  // ─────────────────────────────────────────────────────────────────────────
  // Tab 4: Data Purge Queue
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDeletionsQueue(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;

    if (_deletions.isEmpty) {
      return const UiEmptyState(
        icon: Icons.delete_sweep_outlined,
        title: 'No account deletion requests',
        message: 'No pending statutory data purge requests.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _deletions.map((req) {
        return Container(
          margin: EdgeInsets.only(bottom: context.sp(theme.spacing.md)),
          padding: EdgeInsets.all(context.sp(theme.spacing.md)),
          decoration: BoxDecoration(
            border: Border.all(color: c.border, width: theme.borders.hairline),
            borderRadius: context.radius(theme.radii.md),
            color: c.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    '${req.userDisplayName} (${req.userEmail})',
                    style: context.uiText.bodyStrong.copyWith(fontWeight: FontWeight.w600),
                  ),
                  UiBadge(
                    label: req.status.toUpperCase(),
                    intent: req.status == 'data_purged'
                        ? UiIntent.danger
                        : (req.status == 'cancelled'
                            ? UiIntent.success
                            : UiIntent.warning),
                    size: UiSize.xs,
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.xxs)),
              Text(
                'Condition: ${req.conditionLabel} · Scheduled: ${AppTokens.shortDate(req.scheduledPurgeAt)}',
                style: context.uiText.caption.copyWith(color: c.foregroundMuted),
              ),
              SizedBox(height: context.sp(theme.spacing.sm)),
              Align(
                alignment: Alignment.centerRight,
                child: UiButton(
                  label: 'Inspect & Action',
                  size: UiSize.xs,
                  variant: UiVariant.outline,
                  onPressed: () => _openDeletionOverlay(req),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.sm),
          vertical: context.sp(theme.spacing.xxs),
        ),
        decoration: BoxDecoration(
          color: isSelected ? c.foreground : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isSelected ? c.foreground : c.border,
            width: theme.borders.hairline,
          ),
        ),
        child: Text(
          label,
          style: context.uiText.caption.copyWith(
            color: isSelected ? c.background : c.foreground,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _UsageBox extends StatelessWidget {
  const _UsageBox({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;

    return Container(
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: context.radius(theme.radii.sm),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: context.uiText.bodyStrong.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: context.uiText.caption.copyWith(
              color: c.foregroundMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
