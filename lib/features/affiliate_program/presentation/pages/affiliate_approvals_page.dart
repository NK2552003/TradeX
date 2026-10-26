import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/admin_console/data/admin_console_repository.dart';
import 'package:tradex/features/affiliate_program/data/affiliate_application_repository.dart';
import 'package:tradex/features/affiliate_program/data/affiliate_workspace_repository.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_application_model.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_workspace.dart';

class AffiliateApprovalsPage extends StatefulWidget {
  const AffiliateApprovalsPage({
    super.key,
    this.repository,
    this.workspaceRepository,
  });

  final AffiliateApplicationRepository? repository;
  final AffiliateWorkspaceRepository? workspaceRepository;

  @override
  State<AffiliateApprovalsPage> createState() => _AffiliateApprovalsPageState();
}

class _AffiliateApprovalsPageState extends State<AffiliateApprovalsPage> {
  late final AffiliateApplicationRepository _repository;
  late final AffiliateWorkspaceRepository _workspaceRepository;
  List<AffiliateApplicationModel> _applications = <AffiliateApplicationModel>[];
  AffiliateWorkspace? _workspace;
  AffiliateApplicationStatus? _filter = AffiliateApplicationStatus.pending;
  bool _loading = true;
  String? _error;
  bool _reviewing = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? AffiliateApplicationRepositoryImpl.instance;
    _workspaceRepository =
        widget.workspaceRepository ?? AffiliateWorkspaceRepository.instance;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final applications = await _repository.listApplications();
      AffiliateWorkspace? ws;
      try {
        ws = await _workspaceRepository.load();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _applications = applications;
          _workspace = ws;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Applications could not be loaded. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(
    AffiliateApplicationModel application,
    bool approve,
  ) async {
    if (_reviewing) return;
    final TextEditingController notes = TextEditingController();
    final bool? confirmed = await UiDialog.present<bool>(
      context: context,
      builder: (BuildContext dialogContext) => UiDialog(
        title: approve ? 'Approve affiliate access?' : 'Reject application?',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            UiCallout(
              title: approve
                  ? 'Partner capability will be unlocked'
                  : 'Applicant keeps customer access',
              message: approve
                  ? '${application.fullName} will gain the Affiliate Partner workspace while keeping all customer/trader capabilities.'
                  : '${application.fullName} will not gain partner tools. Their normal TradeX account remains active.',
              intent: approve ? UiIntent.success : UiIntent.warning,
            ),
            SizedBox(height: dialogContext.sp(dialogContext.ui.spacing.md)),
            UiField(
              label: 'Review notes',
              optionalLabel: approve ? 'Optional' : null,
              required: !approve,
              child: UiInput.multiline(
                controller: notes,
                hintText: approve
                    ? 'Internal approval note'
                    : 'Reason shown to the applicant',
                maxLines: 4,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          UiButton(
            label: 'Cancel',
            variant: UiVariant.outline,
            intent: UiIntent.neutral,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          UiButton(
            label: approve ? 'Approve access' : 'Reject application',
            intent: approve ? UiIntent.success : UiIntent.danger,
            onPressed: () {
              if (!approve && notes.text.trim().isEmpty) return;
              Navigator.of(dialogContext).pop(true);
            },
          ),
        ],
      ),
    );
    if (confirmed != true) {
      notes.dispose();
      return;
    }
    setState(() => _reviewing = true);
    try {
      await _repository.review(
        applicationId: application.id,
        approve: approve,
        notes: notes.text,
      );
      await AdminConsoleRepository.instance.recordAuditLog(
        category: 'affiliate_review',
        action: approve
            ? 'AFFILIATE_APPLICATION_APPROVED'
            : 'AFFILIATE_APPLICATION_REJECTED',
        targetType: 'affiliate_application',
        targetLabel: '${application.fullName} (${application.channelHandle})',
        severity: approve ? 'info' : 'warning',
        details: notes.text.trim().isEmpty
            ? (approve
                  ? 'Approved Indian affiliate partner access.'
                  : 'Rejected affiliate application.')
            : notes.text.trim(),
      );
      if (!mounted) return;
      UiToast.show(
        context,
        title: approve ? 'Affiliate approved' : 'Application rejected',
        message: approve
            ? '${application.fullName} can now access the Partner Hub.'
            : 'The review was saved. The applicant can revise their application.',
        intent: approve ? UiIntent.success : UiIntent.warning,
      );
    } catch (_) {
      if (mounted) {
        UiToast.show(
          context,
          title: 'Review could not be saved. Please try again.',
          intent: UiIntent.danger,
        );
      }
    } finally {
      notes.dispose();
      if (mounted) setState(() => _reviewing = false);
    }
    await _load();
  }

  Future<void> _settlePayoutModal(AffiliatePayout payout, bool approve) async {
    final TextEditingController refCtrl = TextEditingController(
      text: approve
          ? 'UTR${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}'
          : '',
    );
    final TextEditingController notesCtrl = TextEditingController(
      text: approve
          ? 'Settled via NPCI / NEFT after 5% TDS deduction u/s 194H.'
          : 'Returned to partner unpaid balance: Bank/UPI verification required.',
    );

    final bool? confirmed = await UiDialog.present<bool>(
      context: context,
      builder: (BuildContext ctx) => UiDialog(
        title: approve
            ? 'Settle Partner INR Payout?'
            : 'Reject & Refund INR Payout?',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            UiCallout(
              title:
                  'Gross: ${formatInrAmount(payout.grossAmount)} · Net Payable: ${formatInrAmount(payout.netAmount)}',
              message:
                  '5% TDS u/s 194H: -${formatInrAmount(payout.tdsAmount)}\n'
                  'Destination: ${payout.methodLabel} (${payout.destination})',
              intent: approve ? UiIntent.success : UiIntent.warning,
            ),
            SizedBox(height: ctx.sp(ctx.ui.spacing.md)),
            if (approve) ...<Widget>[
              UiField(
                label: 'Bank NEFT / IMPS / UPI UTR Reference',
                required: true,
                child: UiInput(
                  controller: refCtrl,
                  hintText: 'e.g. HDFCN52026102599102',
                ),
              ),
              SizedBox(height: ctx.sp(ctx.ui.spacing.md)),
            ],
            UiField(
              label: 'Settlement / Compliance Note',
              child: UiTextarea(
                controller: notesCtrl,
                minLines: 2,
                maxLines: 3,
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
            label: approve ? 'Confirm UTR Settlement' : 'Reject & Refund',
            intent: approve ? UiIntent.success : UiIntent.danger,
            variant: approve ? UiVariant.solid : UiVariant.destructive,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AdminConsoleRepository.instance.reviewAffiliatePayout(
        payoutId: payout.id,
        approve: approve,
        referenceCode: refCtrl.text.trim(),
        notes: notesCtrl.text.trim(),
      );
      await _load();
      if (mounted) {
        UiToast.show(
          context,
          title: approve
              ? 'INR Payout Settled'
              : 'Payout Rejected & Balance Refunded',
          message: approve
              ? 'UTR ${refCtrl.text.trim()} recorded on partner tax ledger.'
              : 'Refunded ${formatInrAmount(payout.amount)} to partner unpaid balance.',
          intent: approve ? UiIntent.success : UiIntent.warning,
        );
      }
    }
    refCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _publishAssetModal() async {
    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController badgeCtrl = TextEditingController(
      text: 'SEBI/ASCI Verified',
    );
    final TextEditingController bodyCtrl = TextEditingController();
    String category = 'social';

    final bool? published = await UiDialog.present<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setModalState) => UiDialog(
          title: 'Publish Partner Media Kit Copy Asset (INR)',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              UiField(
                label: 'Asset Title',
                required: true,
                child: UiInput(
                  controller: titleCtrl,
                  hintText: 'e.g. Diwali Muhurat Trading Journal Pitch',
                ),
              ),
              SizedBox(height: ctx.sp(ctx.ui.spacing.md)),
              UiField(
                label: 'Channel Category',
                child: UiSelect<String>(
                  value: category,
                  options: const <UiOption<String>>[
                    UiOption(value: 'social', label: 'Social / X / Threads'),
                    UiOption(value: 'video', label: 'YouTube Description'),
                    UiOption(value: 'email', label: 'Newsletter / Substack'),
                    UiOption(value: 'community', label: 'Telegram / Discord'),
                  ],
                  onChanged: (String? v) {
                    if (v != null) setModalState(() => category = v);
                  },
                ),
              ),
              SizedBox(height: ctx.sp(ctx.ui.spacing.md)),
              UiField(
                label: 'Compliance Badge Label',
                child: UiInput(controller: badgeCtrl),
              ),
              SizedBox(height: ctx.sp(ctx.ui.spacing.md)),
              UiField(
                label: 'Copy Body (Use {{referral_url}} placeholder)',
                required: true,
                child: UiTextarea(
                  controller: bodyCtrl,
                  hintText:
                      'Track NSE/BSE F&O setups in INR on TradeX: {{referral_url}}',
                  minLines: 3,
                  maxLines: 5,
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
              label: 'Publish to Partner Hub',
              intent: UiIntent.primary,
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty ||
                    bodyCtrl.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
            ),
          ],
        ),
      ),
    );

    if (published == true) {
      await _workspaceRepository.adminPublishMarketingAsset(
        title: titleCtrl.text,
        category: category,
        badge: badgeCtrl.text,
        body: bodyCtrl.text,
      );
      await _load();
      if (mounted) {
        UiToast.show(
          context,
          title: 'Media Kit Asset Published',
          message:
              'New INR marketing template is now live in the Affiliate Partner Hub.',
          intent: UiIntent.success,
        );
      }
    }
    titleCtrl.dispose();
    badgeCtrl.dispose();
    bodyCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<AffiliateApplicationModel> visible = _filter == null
        ? _applications
        : _applications
              .where((AffiliateApplicationModel item) => item.status == _filter)
              .toList();
    final int pending = _applications
        .where(
          (AffiliateApplicationModel item) =>
              item.status == AffiliateApplicationStatus.pending,
        )
        .length;
    final int approved = _applications
        .where(
          (AffiliateApplicationModel item) =>
              item.status == AffiliateApplicationStatus.approved,
        )
        .length;

    return UiPage(
      maxWidth: 1180,
      header: UiHeader(
        title: 'Affiliate Applications',
        subtitle:
            'Review creator identity, reach, Indian INR payout readiness, settle partner withdrawals, and govern commission tiers.',
        leading: Icon(Icons.fact_check_outlined, color: theme.colors.primary),
        actions: <Widget>[
          UiButton(
            label: 'Publish Media Kit Asset',
            leadingIcon: Icons.campaign_outlined,
            variant: UiVariant.outline,
            size: UiSize.sm,
            onPressed: _publishAssetModal,
          ),
          UiButton(
            label: 'Refresh',
            leadingIcon: Icons.refresh_rounded,
            variant: UiVariant.outline,
            size: UiSize.sm,
            onPressed: _load,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_error != null)
            UiCallout(
              title: 'Applications unavailable',
              message: _error,
              intent: UiIntent.danger,
            ),

          // Desk Ledger 3-Column Block
          DeskLedgerBlock(
            items: <DeskLedgerItem>[
              DeskLedgerItem(
                label: 'PENDING REVIEW',
                value: '$pending',
                valueColor: pending > 0
                    ? theme.colors.warning
                    : theme.colors.foreground,
                subtext: 'Awaiting compliance review',
                badgeText: pending > 0 ? 'NEEDS REVIEW' : 'CLEAR',
                badgeIntent: pending > 0
                    ? UiIntent.warning
                    : UiIntent.success,
              ),
              DeskLedgerItem(
                label: 'APPROVED PARTNERS',
                value: '$approved',
                valueColor: theme.colors.bullish,
                subtext: 'Active creator partners',
                badgeText: 'VERIFIED',
                badgeIntent: UiIntent.success,
              ),
              DeskLedgerItem(
                label: 'TOTAL APPLICATIONS',
                value: '${_applications.length}',
                subtext: 'Historical onboarding pipeline',
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          UiToggleGroup<AffiliateApplicationStatus?>(
            value: _filter,
            expand: context.uiRes.isMobile,
            options: const <UiToggleOption<AffiliateApplicationStatus?>>[
              UiToggleOption<AffiliateApplicationStatus?>(
                value: AffiliateApplicationStatus.pending,
                label: 'Pending',
              ),
              UiToggleOption<AffiliateApplicationStatus?>(
                value: AffiliateApplicationStatus.approved,
                label: 'Approved',
              ),
              UiToggleOption<AffiliateApplicationStatus?>(
                value: AffiliateApplicationStatus.rejected,
                label: 'Rejected',
              ),
              UiToggleOption<AffiliateApplicationStatus?>(
                value: null,
                label: 'All',
              ),
            ],
            onChanged: (AffiliateApplicationStatus? value) =>
                setState(() => _filter = value),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          if (_loading)
            const _ApplicationListSkeleton()
          else if (visible.isEmpty)
            UiEmptyState(
              icon: Icons.inbox_outlined,
              title: 'No applications in this queue',
              message:
                  'New affiliate submissions will appear here for administrator review.',
              action: UiButton(
                label: 'Refresh',
                leadingIcon: Icons.refresh_rounded,
                onPressed: _load,
              ),
            )
          else
            ...visible.map(
              (AffiliateApplicationModel application) => Padding(
                padding: EdgeInsets.only(bottom: context.sp(theme.spacing.md)),
                child: _ApplicationCard(
                  application: application,
                  onApprove:
                      application.status == AffiliateApplicationStatus.pending
                      ? () => _review(application, true)
                      : null,
                  onReject:
                      application.status == AffiliateApplicationStatus.pending
                      ? () => _review(application, false)
                      : null,
                ),
              ),
            ),

          if (_workspace != null && _workspace!.enrolled) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xl)),
            _buildInrPayoutGovernanceSection(context, _workspace!),
          ],
        ],
      ),
    );
  }

  Widget _buildInrPayoutGovernanceSection(
    BuildContext context,
    AffiliateWorkspace ws,
  ) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: 'Partner INR Payout Settlement & Tier Governance',
      subtitle:
          'Active Partner: ${ws.profile.displayName} (/r/${ws.profile.referralSlug}) · Unpaid Balance: ${formatInrAmount(ws.profile.unpaidBalance)} · Settled: ${formatInrAmount(ws.profile.totalPaidOut)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiTable<AffiliatePayout>(
            rows: ws.payouts,
            rowKey: (p) => p.id,
            stackOnMobile: true,
            columns: <UiTableColumn<AffiliatePayout>>[
              UiTableColumn<AffiliatePayout>(
                id: 'requested',
                label: 'Requested Date',
                valueGetter: (p) =>
                    p.requestedAt.toIso8601String().split('T').first,
              ),
              UiTableColumn<AffiliatePayout>(
                id: 'rail',
                label: 'Indian Payout Rail',
                valueGetter: (p) => '${p.methodLabel} · ${p.destination}',
              ),
              UiTableColumn<AffiliatePayout>(
                id: 'gross',
                label: 'Gross (₹)',
                numeric: true,
                valueGetter: (p) => formatInrAmount(p.grossAmount),
              ),
              UiTableColumn<AffiliatePayout>(
                id: 'tds',
                label: '5% TDS u/s 194H',
                numeric: true,
                valueGetter: (p) => '-${formatInrAmount(p.tdsAmount)}',
              ),
              UiTableColumn<AffiliatePayout>(
                id: 'net',
                label: 'Net Disbursed (₹)',
                numeric: true,
                valueGetter: (p) => formatInrAmount(p.netAmount),
              ),
              UiTableColumn<AffiliatePayout>(
                id: 'status',
                label: 'Settlement Action',
                cellBuilder: (BuildContext ctx, AffiliatePayout p) =>
                    p.status == 'pending' || p.status == 'processing'
                    ? Wrap(
                        spacing: ctx.sp(theme.spacing.xxs),
                        children: <Widget>[
                          UiButton(
                            label: 'Settle UTR',
                            size: UiSize.xs,
                            intent: UiIntent.success,
                            onPressed: () => _settlePayoutModal(p, true),
                          ),
                          UiButton(
                            label: 'Reject',
                            size: UiSize.xs,
                            variant: UiVariant.outline,
                            intent: UiIntent.danger,
                            onPressed: () => _settlePayoutModal(p, false),
                          ),
                        ],
                      )
                    : UiBadge(
                        label: '${p.status.toUpperCase()} · ${p.referenceCode}',
                        intent: p.status == 'paid'
                            ? UiIntent.success
                            : UiIntent.neutral,
                        size: UiSize.xs,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    this.onApprove,
    this.onReject,
  });

  final AffiliateApplicationModel application;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiIntent intent = switch (application.status) {
      AffiliateApplicationStatus.approved => UiIntent.success,
      AffiliateApplicationStatus.rejected ||
      AffiliateApplicationStatus.suspended => UiIntent.danger,
      AffiliateApplicationStatus.pending => UiIntent.warning,
      AffiliateApplicationStatus.draft => UiIntent.neutral,
    };
    final Widget identity = Row(
      children: <Widget>[
        UiAvatar(name: application.fullName, size: UiSize.lg),
        SizedBox(width: context.sp(theme.spacing.sm)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(application.fullName, style: context.uiText.bodyStrong),
              Text(
                '${application.primaryPlatform} · ${application.channelHandle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
        UiBadge(
          label: application.status.apiValue.toUpperCase(),
          intent: intent,
          size: UiSize.xs,
        ),
      ],
    );
    final Widget details = Wrap(
      spacing: context.sp(theme.spacing.lg),
      runSpacing: context.sp(theme.spacing.sm),
      children: <Widget>[
        _detail(context, Icons.people_outline, application.audienceReach),
        _detail(
          context,
          Icons.location_on_outlined,
          '${application.city}, ${application.state}',
        ),
        _detail(
          context,
          Icons.account_balance_outlined,
          '${application.bankName} · ${application.maskedAccountNumber} (${application.ifscCode})',
        ),
        _detail(
          context,
          Icons.category_outlined,
          application.niches.join(', '),
        ),
      ],
    );
    return UiCard(
      variant: UiCardVariant.outlined,
      intent: intent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          identity,
          SizedBox(height: context.sp(theme.spacing.md)),
          details,
          if (application.reviewNotes != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            UiCallout(
              title: 'Review notes',
              message: application.reviewNotes!,
              intent: intent,
            ),
          ],
          if (onApprove != null || onReject != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: context.sp(theme.spacing.sm),
              runSpacing: context.sp(theme.spacing.sm),
              children: <Widget>[
                UiButton(
                  label: 'Reject',
                  leadingIcon: Icons.close_rounded,
                  variant: UiVariant.outline,
                  intent: UiIntent.danger,
                  onPressed: onReject,
                ),
                UiButton(
                  label: 'Approve affiliate',
                  leadingIcon: Icons.verified_rounded,
                  intent: UiIntent.success,
                  onPressed: onApprove,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _detail(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: context.sz(16),
          color: context.ui.colors.foregroundMuted,
        ),
        UiGap.h(context.ui.spacing.xs),
        Flexible(
          child: Text(
            text,
            style: context.uiText.caption.copyWith(
              color: context.ui.colors.foregroundMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _ApplicationListSkeleton extends StatelessWidget {
  const _ApplicationListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(
        3,
        (int index) => Padding(
          padding: EdgeInsets.only(bottom: context.sp(context.ui.spacing.md)),
          child: UiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const UiSkeleton(width: 220, height: 20),
                SizedBox(height: context.sp(context.ui.spacing.sm)),
                const UiSkeleton(width: double.infinity, height: 14),
                SizedBox(height: context.sp(context.ui.spacing.xs)),
                const UiSkeleton(width: 320, height: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
