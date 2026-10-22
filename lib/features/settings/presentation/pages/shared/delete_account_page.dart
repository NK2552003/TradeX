import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_subpage_scope.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key, this.repository});

  final ProfileSettingsRepository? repository;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  late final ProfileSettingsRepository _repo;
  bool _deleting = false;
  String _selectedReason = 'Taking a break from active trading';
  late final TextEditingController _customFeedbackController;

  final List<String> _reasons = const <String>[
    'Taking a break from active trading',
    'Moving to another platform or broker',
    'Subscription costs too high',
    'Technical issues or missing trading tools',
    'Other reason',
  ];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ProfileSettingsRepositoryImpl();
    _customFeedbackController = TextEditingController();
  }

  @override
  void dispose() {
    _customFeedbackController.dispose();
    super.dispose();
  }

  void _showFinalConfirmDialog() {
    bool confirmed = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => UiDialog(
          title: 'Confirm Account Deletion',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiCallout(
                title: 'Request account deletion',
                message:
                    'This submits an account deletion request for review and signs you out. Permanent erasure requires backend processing; this screen does not confirm that erasure is complete.',
                intent: UiIntent.bearish,
              ),
              SizedBox(height: context.sp(context.ui.spacing.md)),
              Text(
                'To confirm, please type "DELETE" below:',
                style: context.uiText.bodyStrong,
              ),
              SizedBox(height: context.sp(context.ui.spacing.xs)),
              UiInput(
                hintText: 'DELETE',
                onChanged: (v) {
                  setDialogState(() {
                    confirmed = v.trim().toUpperCase() == 'DELETE';
                  });
                },
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
              label: 'Submit Deletion Request',
              intent: UiIntent.danger,
              loading: _deleting,
              onPressed: confirmed
                  ? () async {
                      Navigator.of(ctx).pop();
                      setState(() => _deleting = true);
                      try {
                        await _repo.requestAccountDeletion(
                          reason:
                              '$_selectedReason: ${_customFeedbackController.text.trim()}',
                        );
                        await SupabaseAuthBackendService.instance.signOut();
                        if (mounted) {
                          setState(() => _deleting = false);
                          UiToast.show(
                            context,
                            title: 'Deletion requested',
                            message:
                                'Your request is pending review. You have been signed out.',
                            intent: UiIntent.info,
                          );
                          closeSettingsSubpage(context);
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _deleting = false);
                          UiToast.show(
                            context,
                            title: 'Error',
                            message:
                                'Failed to request deletion. Please try again.',
                            intent: UiIntent.danger,
                          );
                        }
                      }
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bool isMobile = context.uiRes.isMobile;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Danger Warning Banner
          UiCallout(
            title: 'Danger Zone: Account Termination',
            message:
                'Deleting your account will immediately revoke access to all active playbooks, backtests, and real-time feeds. If you have an active subscription, it will be automatically canceled.',
            intent: UiIntent.danger,
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Data Impact Summary
          UiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What happens when you delete your account:',
                  style: context.uiText.bodyStrong,
                ),
                SizedBox(height: context.sp(theme.spacing.sm)),
                _buildBulletItem(
                  context,
                  'Trade journals, chart snapshots, and setup notes are archived and scheduled for purge.',
                ),
                _buildBulletItem(
                  context,
                  'Your public profile, leaderboard ranks, and community shared playbooks are removed.',
                ),
                _buildBulletItem(
                  context,
                  'Recurring billing is stopped immediately; no further charges will occur.',
                ),
                _buildBulletItem(
                  context,
                  '30-Day Recovery Period: You can cancel deletion anytime within 30 days by logging back in.',
                ),
              ],
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          AppSettingsSectionBlock(
            title: 'Why are you leaving?',
            description:
                'Your feedback helps us improve TradeX for the entire community.',
            children: [
              UiRadioCardGroup<String>(
                value: _selectedReason,
                options: _reasons
                    .map((r) => UiOption<String>(label: r, value: r))
                    .toList(),
                onChanged: (v) {
                  setState(() => _selectedReason = v);
                },
              ),
              if (_selectedReason == 'Other reason') ...[
                SizedBox(height: context.sp(theme.spacing.sm)),
                UiField(
                  label: 'Additional Feedback (Optional)',
                  child: UiTextarea(
                    hintText: 'Tell us how we could have done better...',
                    rows: 3,
                    onChanged: (v) => _customFeedbackController.text = v,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              UiButton(
                label: 'Keep My Account',
                variant: UiVariant.outline,
                onPressed: () => closeSettingsSubpage(context),
              ),
              UiButton(
                label: 'Proceed to Deletion',
                intent: UiIntent.danger,
                variant: UiVariant.primary,
                onPressed: _showFinalConfirmDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBulletItem(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.sp(context.ui.spacing.xs)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6.0, right: 8.0),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.ui.colors.foregroundMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: context.uiText.body.copyWith(
                color: context.ui.colors.foregroundMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
