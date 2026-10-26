import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/settings/data/repositories/privacy_repository.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({
    super.key,
    this.userRole = UserRole.customer,
    this.repository,
    this.privacyRepository,
    this.onAccountDeleted,
  });

  final UserRole userRole;
  final ProfileSettingsRepository? repository;
  final PrivacyRepository? privacyRepository;
  final VoidCallback? onAccountDeleted;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  late final ProfileSettingsRepository _repo;
  late final PrivacyRepository _privacyRepo;

  String _selectedReason = 'Taking a break from trading';
  final TextEditingController _feedbackController = TextEditingController();

  /// Condition controlling when and how associated user data is purged after account deletion:
  /// - 'immediate_purge': Immediately cascade-delete all personal & workspace data upon account deletion
  /// - 'after_30_day_grace': Lock account now and permanently delete all data after 30-day recovery window
  /// - 'purge_personal_keep_tax_ledger': Purge personal/workspace data immediately, anonymize & retain statutory INR GST/TDS ledger
  String _dataPurgeCondition = 'immediate_purge';

  bool _purgeWritingDesk = true;
  bool _purgeCommunityMessages = true;
  bool _purgeAiWorkspace = true;
  bool _purgeAffiliateCampaigns = true;
  final bool _exportBeforeDelete = true;
  bool _acknowledgedCondition = false;
  bool _exportingArchive = false;
  bool _archiveReady = false;

  List<String> get _reasons => switch (widget.userRole) {
    UserRole.affiliate => const <String>[
      'Consolidating creator / agency accounts',
      'Switching primary content niche',
      'Payout or tax compliance preference',
      'Privacy or data erasure request',
      'Other reason',
    ],
    UserRole.userAdmin => const <String>[
      'Dissolving or migrating institutional desk',
      'Transferring desk ownership to another administrator',
      'Regulatory or compliance restructuring',
      'Privacy or data erasure request',
      'Other reason',
    ],
    UserRole.customer => const <String>[
      'Taking a break from trading',
      'Switching to another platform',
      'Subscription cost is too high',
      'Missing features or integrations',
      'Privacy or data concerns',
      'Other reason',
    ],
  };

  String get _roleTitle => switch (widget.userRole) {
    UserRole.affiliate => 'Delete Affiliate Partner Account & Data',
    UserRole.userAdmin => 'Delete Institutional Admin Account & Data',
    UserRole.customer => 'Delete Trader Account & Data',
  };

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ProfileSettingsRepositoryImpl();
    _privacyRepo = widget.privacyRepository ?? PrivacyRepositoryImpl();
    _selectedReason = _reasons.first;
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _triggerDataArchive() async {
    setState(() => _exportingArchive = true);
    try {
      await _privacyRepo.requestDataExport();
      if (!mounted) return;
      setState(() {
        _exportingArchive = false;
        _archiveReady = true;
      });
      UiToast.show(
        context,
        title: 'Pre-Deletion Data Archive Prepared',
        message:
            'Your JSON/CSV archive (journals, notes, strategies & INR ledger) has been queued for download.',
        intent: UiIntent.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _exportingArchive = false);
    }
  }

  void _showConfirmationDialog() {
    if (!_acknowledgedCondition) {
      UiToast.show(
        context,
        title: 'Confirm Data Deletion Condition',
        message:
            'Please acknowledge the post-deletion data purge condition checkbox before continuing.',
        intent: UiIntent.warning,
      );
      return;
    }

    final confirmTextController = TextEditingController();
    bool isDeleting = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isMatch =
              confirmTextController.text.trim().toUpperCase() == 'DELETE';
          final spacing = context.sp(context.ui.spacing.sm);

          return UiDialog(
            title: 'Confirm Account & Conditional Data Purge',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UiCallout(
                  title: _dataPurgeCondition == 'after_30_day_grace'
                      ? 'Condition: 30-Day Grace Window Before Permanent Data Purge'
                      : _dataPurgeCondition == 'purge_personal_keep_tax_ledger'
                      ? 'Condition: Immediate Personal Data Purge + Statutory INR Tax Retention'
                      : 'Condition: Immediate Cascade Data Purge Upon Account Deletion',
                  message: _dataPurgeCondition == 'after_30_day_grace'
                      ? 'Your account will be locked immediately and all selected data domains will be permanently purged in 30 days unless cancelled.'
                      : 'All selected data domains (journals, notes, strategies, community posts, AI history, and campaigns) will be purged immediately once confirmed.',
                  intent: UiIntent.danger,
                ),
                SizedBox(height: spacing * 1.5),
                Text(
                  'To verify your intent and execute this data deletion condition, type DELETE in uppercase below.',
                  style: context.uiText.body,
                ),
                SizedBox(height: spacing),
                UiField(
                  label: 'Type "DELETE" to confirm',
                  child: UiInput(
                    hintText: 'DELETE',
                    onChanged: (val) {
                      setDialogState(() {
                        confirmTextController.text = val;
                      });
                    },
                  ),
                ),
              ],
            ),
            actions: [
              UiButton(
                label: 'Cancel',
                variant: UiVariant.outline,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              UiButton(
                label: _dataPurgeCondition == 'after_30_day_grace'
                    ? 'Delete Account & Schedule Purge'
                    : 'Delete Account & Purge Data Now',
                intent: UiIntent.danger,
                variant: UiVariant.destructive,
                loading: isDeleting,
                disabled: !isMatch,
                onPressed: () async {
                  setDialogState(() => isDeleting = true);
                  final req = await _repo.requestAccountDeletion(
                    reason: _selectedReason,
                    feedback: _feedbackController.text.trim(),
                    dataPurgeCondition: _dataPurgeCondition,
                    purgeJournalsNotesStrategies: _purgeWritingDesk,
                    purgeCommunityMessages: _purgeCommunityMessages,
                    purgeAiWorkspace: _purgeAiWorkspace,
                    purgeAffiliateCampaigns: _purgeAffiliateCampaigns,
                    exportBeforeDelete: _exportBeforeDelete,
                    userRole: widget.userRole.dbValue,
                  );
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                  if (mounted) {
                    UiToast.show(
                      this.context,
                      title: req.status == 'data_purged'
                          ? 'Account Deleted & Data Purged'
                          : 'Account Deletion & 30-Day Purge Scheduled',
                      message: req.status == 'data_purged'
                          ? 'Your account and selected workspace data have been permanently purged.'
                          : 'Your account is locked and scheduled for permanent data purge on ${AppTokens.shortDate(req.scheduledPurgeAt)}.',
                      intent: UiIntent.warning,
                    );
                    widget.onAccountDeleted?.call();
                    Navigator.of(this.context).maybePop();
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double bottomInset = isMobile
        ? (keyboardInset > 0 ? keyboardInset + 24.0 : context.uiDockInset)
        : context.sp(theme.spacing.lg);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg),
        bottomInset,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Role-aware Warning Callout
              UiCallout(
                title: _roleTitle,
                message: widget.userRole == UserRole.affiliate
                    ? 'Deleting your Affiliate Partner account revokes your custom referral links (/r/:slug), pauses active campaigns, and purges your workspace data according to the condition you select below.'
                    : widget.userRole == UserRole.userAdmin
                    ? 'Deleting your Institutional Desk Administrator account revokes desk governance access, deactivates seat supervision, and purges your personal workspace data according to the condition you select below.'
                    : 'Deleting your Trader account cancels active subscriptions, revokes workspace access, and purges your journals, strategies, notes, and social activity according to the condition you select below.',
                intent: UiIntent.danger,
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Step 1: Post-Deletion Data Purge Condition (Required by User Request)
              AppSettingsSectionBlock(
                title: '1. Condition to Delete Data After Deleting Account',
                description:
                    'Choose the exact condition under which your personal, trading, community, and affiliate data is purged.',
                children: [
                  UiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        UiRadioCardGroup<String>(
                          value: _dataPurgeCondition,
                          desktopColumns: 1,
                          tabletColumns: 1,
                          mobileColumns: 1,
                          onChanged: (v) =>
                              setState(() => _dataPurgeCondition = v),
                          options: const [
                            UiOption<String>(
                              value: 'immediate_purge',
                              label:
                                  'Condition A: Delete All Data Immediately After Account Deletion',
                              description:
                                  'Executes an immediate cascade purge of your journals, notes, strategies, watchlists, community posts, messages, and AI history the moment account deletion is confirmed.',
                              icon: Icons.delete_forever_rounded,
                              badge: 'IMMEDIATE PURGE',
                            ),
                            UiOption<String>(
                              value: 'after_30_day_grace',
                              label:
                                  'Condition B: Delete All Data After 30-Day Recovery Grace Period',
                              description:
                                  'Immediately deactivates your account and locks public visibility, then permanently purges all data if you do not sign back in within 30 days.',
                              icon: Icons.timer_outlined,
                              badge: '30-DAY GRACE',
                            ),
                            UiOption<String>(
                              value: 'purge_personal_keep_tax_ledger',
                              label:
                                  'Condition C: Purge Personal & Trading Data Immediately · Retain Statutory INR Tax Ledger',
                              description:
                                  'Immediately deletes all personal profile, journals, strategies, chats, and campaigns while anonymizing statutory Indian GST & Form 16A TDS payout invoices required under Income Tax law.',
                              icon: Icons.account_balance_outlined,
                              badge: 'TAX COMPLIANT',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Step 2: Granular Data Scope Selection
              AppSettingsSectionBlock(
                title: '2. Data Domains Bound to Deletion Condition',
                description:
                    'Select the specific data repositories to purge when your deletion condition triggers.',
                children: [
                  UiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        UiCheckbox(
                          value: _purgeWritingDesk,
                          onChanged: (v) =>
                              setState(() => _purgeWritingDesk = v),
                          label:
                              'Purge Trading Journals, Strategy Playbooks, Trader Notes & Watchlists',
                          description:
                              'Deletes all execution logs, chart screenshots, R-multiple analytics, and private checklist rules.',
                        ),
                        UiDivider(),
                        UiCheckbox(
                          value: _purgeCommunityMessages,
                          onChanged: (v) =>
                              setState(() => _purgeCommunityMessages = v),
                          label:
                              'Purge Community Posts, Comments, Likes & Direct Messages',
                          description:
                              'Removes your published trade setups, social comments, follower links, and chat history.',
                        ),
                        UiDivider(),
                        UiCheckbox(
                          value: _purgeAiWorkspace,
                          onChanged: (v) =>
                              setState(() => _purgeAiWorkspace = v),
                          label:
                              'Purge AI Copilot Threads, Chart Setups & Prompt History',
                          description:
                              'Deletes all saved AI assistant conversations, technical evaluations, and quota logs.',
                        ),
                        if (widget.userRole == UserRole.affiliate ||
                            widget.userRole == UserRole.userAdmin) ...[
                          UiDivider(),
                          UiCheckbox(
                            value: _purgeAffiliateCampaigns,
                            onChanged: (v) =>
                                setState(() => _purgeAffiliateCampaigns = v),
                            label:
                                'Purge Affiliate Referral Campaigns, Custom Slugs & Attribution Links',
                            description:
                                'Releases your custom /r/:slug URL and deletes UTM campaign tracking links.',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Step 3: Pre-Deletion Data Archive & Reason
              AppSettingsSectionBlock(
                title: '3. Pre-Deletion Archive & Exit Feedback',
                description:
                    'Optionally export your workspace archive before your data deletion condition executes.',
                children: [
                  AppSettingCard(
                    title: 'Export Full Workspace Archive (JSON / CSV)',
                    description: _archiveReady
                        ? 'Archive prepared and queued for your registered email.'
                        : 'Download a copy of your trades, notes, strategies, and INR tax statements before deletion.',
                    icon: Icons.folder_zip_outlined,
                    control: UiButton(
                      label: _archiveReady
                          ? 'Archive Ready'
                          : 'Prepare Archive',
                      leadingIcon: _archiveReady
                          ? Icons.check_circle_outline_rounded
                          : Icons.download_rounded,
                      size: UiSize.sm,
                      variant: UiVariant.outline,
                      loading: _exportingArchive,
                      onPressed: _archiveReady ? null : _triggerDataArchive,
                    ),
                  ),
                  UiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        UiField(
                          label: 'Primary Reason for Leaving',
                          child: UiSelect<String>(
                            value: _selectedReason,
                            options: _reasons
                                .map(
                                  (r) => UiOption<String>(label: r, value: r),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedReason = v),
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.md)),
                        UiField(
                          label:
                              'Additional Feedback or Compliance Notes (Optional)',
                          child: UiTextarea(
                            value: _feedbackController.text,
                            hintText:
                                'Let our engineering or compliance desk know if you need any specific assistance...',
                            minLines: 3,
                            maxLines: 5,
                            onChanged: (v) => _feedbackController.text = v,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.md)),
                        UiCheckbox(
                          value: _acknowledgedCondition,
                          onChanged: (v) =>
                              setState(() => _acknowledgedCondition = v),
                          label:
                              'I understand that my account will be deleted and my selected data domains will be purged once my chosen condition is met.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.xl)),

              // Action Buttons
              Wrap(
                alignment: WrapAlignment.end,
                spacing: context.sp(theme.spacing.sm),
                runSpacing: context.sp(theme.spacing.sm),
                children: [
                  SizedBox(
                    width: isMobile ? double.infinity : null,
                    child: UiButton(
                      label: 'Keep My Account',
                      variant: UiVariant.outline,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : null,
                    child: UiButton(
                      label: 'Proceed to Delete Account & Data',
                      intent: UiIntent.danger,
                      variant: UiVariant.destructive,
                      leadingIcon: Icons.delete_forever_rounded,
                      onPressed: _showConfirmationDialog,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
