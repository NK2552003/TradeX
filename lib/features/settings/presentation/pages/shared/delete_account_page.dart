import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart'
    show AppSettingCard, AppSettingsSectionBlock, AppTokens;
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/settings/data/repositories/privacy_repository.dart';
import 'package:alphajournal/features/settings/data/repositories/profile_settings_repository.dart';

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

  String _dataPurgeCondition = 'immediate_purge';

  bool _acknowledgedCondition = false;
  bool _exportingArchive = false;
  bool _archiveRequested = false;

  List<String> get _reasons => switch (widget.userRole) {
    UserRole.affiliate => const <String>[
      'Consolidating creator / agency accounts',
      'Switching primary content niche',
      'Payout or tax compliance preference',
      'Privacy or data erasure request',
      'Other reason',
    ],
    UserRole.userAdmin => const <String>[
      'Closing my administrator account',
      'Transferring administration to another person',
      'No longer managing the platform',
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
    UserRole.userAdmin => 'Delete Administrator Account & Data',
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
        _archiveRequested = true;
      });
      UiToast.show(
        context,
        title: 'Data export requested',
        message:
            'Your export request is queued. Check its status in Privacy settings before requesting account deletion.',
        intent: UiIntent.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _exportingArchive = false);
      UiToast.error(
        context,
        title: 'Export request could not be saved',
        message: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  void _showConfirmationDialog() {
    if (!_acknowledgedCondition) {
      UiToast.show(
        context,
        title: 'Confirm Data Deletion Condition',
        message:
            'Please acknowledge the account lock and administrator review before continuing.',
        intent: UiIntent.warning,
      );
      return;
    }

    final confirmTextController = TextEditingController();
    bool isDeleting = false;
    String? deletionError;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isMatch =
              confirmTextController.text.trim().toUpperCase() == 'DELETE';
          final spacing = context.sp(context.ui.spacing.sm);

          return UiDialog(
            title: 'Confirm account deletion request',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UiCallout(
                  title: _dataPurgeCondition == 'after_30_day_grace'
                      ? 'Request deletion after 30 days'
                      : 'Request deletion after administrator review',
                  message: _dataPurgeCondition == 'after_30_day_grace'
                      ? 'Your account will be locked. An administrator can process permanent deletion after 30 days. Contact an administrator before processing if you want to cancel.'
                      : 'Your account will be locked and your deletion preferences sent to an administrator for review. This step submits a request.',
                  intent: UiIntent.danger,
                ),
                SizedBox(height: spacing * 1.5),
                Text(
                  'To submit the deletion request, type DELETE below.',
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
                if (deletionError != null) ...[
                  const UiGap.v(12),
                  UiCallout(
                    title: 'Request could not be saved',
                    message: deletionError!,
                    intent: UiIntent.danger,
                  ),
                ],
              ],
            ),
            actions: [
              UiButton(
                label: 'Cancel',
                variant: UiVariant.outline,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              UiButton(
                label: 'Submit deletion request',
                intent: UiIntent.danger,
                variant: UiVariant.destructive,
                loading: isDeleting,
                disabled: !isMatch,
                onPressed: () async {
                  setDialogState(() {
                    isDeleting = true;
                    deletionError = null;
                  });
                  try {
                    final req = await _repo.requestAccountDeletion(
                      reason: _selectedReason,
                      feedback: _feedbackController.text.trim(),
                      dataPurgeCondition: _dataPurgeCondition,
                      purgeJournalsNotesStrategies: true,
                      purgeCommunityMessages: true,
                      purgeAiWorkspace: true,
                      purgeAffiliateCampaigns: true,
                      exportBeforeDelete: _archiveRequested,
                      userRole: widget.userRole.dbValue,
                    );
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                    if (mounted) {
                      UiToast.show(
                        this.context,
                        title: 'Deletion request submitted',
                        message: req.status == 'grace_period'
                            ? 'Your account is locked. An administrator can process deletion after ${AppTokens.shortDate(req.scheduledPurgeAt)}.'
                            : 'Your account is locked and the request is available for administrator review.',
                        intent: UiIntent.warning,
                      );
                      widget.onAccountDeleted?.call();
                      Navigator.of(this.context).maybePop();
                    }
                  } catch (error) {
                    if (ctx.mounted) {
                      setDialogState(() {
                        isDeleting = false;
                        deletionError = error.toString().replaceFirst(
                          'Bad state: ',
                          '',
                        );
                      });
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    ).whenComplete(confirmTextController.dispose);
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
                    ? 'Submitting a request locks your account and partner workspace. An administrator reviews the request before permanently removing your account and its linked data.'
                    : widget.userRole == UserRole.userAdmin
                    ? 'Another administrator must change your role before you can request deletion. This protects the platform from losing its administrator.'
                    : 'Submitting a request locks your account for administrator review. Permanent removal deletes its linked data. Any active provider subscription must be cancelled separately before deletion.',
                intent: UiIntent.danger,
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Deletion timing is reviewed and enforced by the server.
              AppSettingsSectionBlock(
                title: '1. Deletion timing',
                description:
                    'Choose when an administrator may process permanent account deletion.',
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
                              label: 'Request deletion after review',
                              description:
                                  'Lock the account now and add it to the administrator review queue. Deletion happens only when an administrator processes the request.',
                              icon: Icons.delete_forever_rounded,
                              badge: 'ADMIN REVIEW',
                            ),
                            UiOption<String>(
                              value: 'after_30_day_grace',
                              label: 'Wait 30 days before deletion',
                              description:
                                  'Lock the account now and require a 30-day waiting period. Contact an administrator to cancel the request before it is processed.',
                              icon: Icons.timer_outlined,
                              badge: '30-DAY GRACE',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              AppSettingsSectionBlock(
                title: '2. Data included',
                description:
                    'Full account deletion removes account-owned notes, journals, strategies, community content, messages, AI history, affiliate records and uploaded files.',
                children: const [
                  UiCallout(
                    title: 'Keep a copy of anything you need',
                    message:
                        'Export your records before submitting. Administrator activity and deletion receipts are retained. For changes to individual records, use their own delete controls.',
                    intent: UiIntent.warning,
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Step 3: Pre-Deletion Data Archive & Reason
              AppSettingsSectionBlock(
                title: '3. Export and feedback',
                description:
                    'Request an export and wait for it to be available in Privacy settings before submitting deletion.',
                children: [
                  AppSettingCard(
                    title: 'Request a data export',
                    description: _archiveRequested
                        ? 'Export requested. Check its status in Privacy settings.'
                        : 'Queue an export of your account data before requesting deletion.',
                    icon: Icons.folder_zip_outlined,
                    control: UiButton(
                      label: _archiveRequested
                          ? 'Export requested'
                          : 'Request export',
                      leadingIcon: _archiveRequested
                          ? Icons.check_circle_outline_rounded
                          : Icons.download_rounded,
                      size: UiSize.sm,
                      variant: UiVariant.outline,
                      loading: _exportingArchive,
                      onPressed: _archiveRequested ? null : _triggerDataArchive,
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
                          label: 'Additional feedback (optional)',
                          child: UiTextarea(
                            value: _feedbackController.text,
                            hintText:
                                'Tell the administrator about any help you need...',
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
                              'I understand that this request locks my account and that an administrator can permanently delete it and its linked data after review.',
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
                      label: 'Review deletion request',
                      intent: UiIntent.danger,
                      variant: UiVariant.destructive,
                      leadingIcon: Icons.delete_forever_rounded,
                      onPressed: widget.userRole == UserRole.userAdmin
                          ? null
                          : _showConfirmationDialog,
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
