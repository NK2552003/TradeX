import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/affiliate_program/data/affiliate_application_repository.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_application_model.dart';

class AffiliateApprovalsPage extends StatefulWidget {
  const AffiliateApprovalsPage({super.key, this.repository});

  final AffiliateApplicationRepository? repository;

  @override
  State<AffiliateApprovalsPage> createState() => _AffiliateApprovalsPageState();
}

class _AffiliateApprovalsPageState extends State<AffiliateApprovalsPage> {
  late final AffiliateApplicationRepository _repository;
  List<AffiliateApplicationModel> _applications = <AffiliateApplicationModel>[];
  AffiliateApplicationStatus? _filter = AffiliateApplicationStatus.pending;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? AffiliateApplicationRepositoryImpl.instance;
    _load();
  }

  Future<void> _load() async {
    final List<AffiliateApplicationModel> applications = await _repository
        .listApplications();
    if (!mounted) return;
    setState(() {
      _applications = applications;
      _loading = false;
    });
  }

  Future<void> _review(
    AffiliateApplicationModel application,
    bool approve,
  ) async {
    final TextEditingController notes = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
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
    await _repository.review(
      applicationId: application.id,
      approve: approve,
      notes: notes.text,
    );
    notes.dispose();
    if (!mounted) return;
    UiToast.show(
      context,
      title: approve ? 'Affiliate approved' : 'Application rejected',
      message: approve
          ? '${application.fullName} can now access the Partner Hub.'
          : '${application.fullName} was notified and can revise their application.',
      intent: approve ? UiIntent.success : UiIntent.warning,
    );
    await _load();
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
            'Review creator identity, reach, payout readiness, and unlock partner access.',
        leading: Icon(Icons.fact_check_outlined, color: theme.colors.primary),
        actions: <Widget>[
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
          UiCardGrid(
            mobileColumns: 1,
            tabletColumns: 3,
            desktopColumns: 3,
            largeColumns: 3,
            childAspectRatio: context.uiRes.isMobile ? 2.4 : 2.0,
            children: <Widget>[
              UiMetricCard(
                label: 'Pending review',
                value: '$pending',
                icon: Icons.pending_actions_outlined,
              ),
              UiMetricCard(
                label: 'Approved partners',
                value: '$approved',
                icon: Icons.verified_user_outlined,
              ),
              UiMetricCard(
                label: 'Total applications',
                value: '${_applications.length}',
                icon: Icons.group_add_outlined,
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
          '${application.bankName} · ${application.maskedAccountNumber}',
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
      children: <Widget>[
        Icon(
          icon,
          size: context.sz(16),
          color: context.ui.colors.foregroundMuted,
        ),
        SizedBox(width: context.sp(context.ui.spacing.xs)),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sz(260)),
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
