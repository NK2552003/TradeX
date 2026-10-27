import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:tradex/features/settings/models/connected_account_model.dart';
import 'package:tradex/features/settings/presentation/pages/shared/delete_account_page.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_subpage_scope.dart';

class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({
    super.key,
    this.userRole = UserRole.customer,
    this.repository,
    this.onAccountDeleted,
  });

  final UserRole userRole;
  final ProfileSettingsRepository? repository;
  final VoidCallback? onAccountDeleted;

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  late final ProfileSettingsRepository _repo;
  bool _loading = true;
  String _currentEmail = 'nitish@alphajournal.in';
  List<ConnectedAccount> _connectedAccounts = [];

  // Controllers for password change
  final TextEditingController _curPwdController = TextEditingController();
  final TextEditingController _newPwdController = TextEditingController();
  final TextEditingController _confirmPwdController = TextEditingController();
  bool _changingPassword = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ProfileSettingsRepositoryImpl();
    _loadSecurityData();
  }

  @override
  void dispose() {
    _curPwdController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    super.dispose();
  }

  Future<void> _loadSecurityData() async {
    setState(() => _loading = true);
    try {
      final profile = await _repo.getProfile();
      final connected = await _repo.getConnectedAccounts();
      if (mounted) {
        setState(() {
          _currentEmail =
              SupabaseConfig.client?.auth.currentUser?.email ?? profile.email;
          _connectedAccounts = connected;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showChangeEmailDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => UiDialog(
          title: 'Change Email Address',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'A verification OTP will be sent to your new email to confirm ownership.',
                style: context.uiText.caption.copyWith(
                  color: context.ui.colors.foregroundMuted,
                ),
              ),
              SizedBox(height: context.sp(context.ui.spacing.md)),
              UiField(
                label: 'New Email Address',
                child: UiInput(
                  hintText: 'new.email@example.com',
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (v) => emailController.text = v,
                ),
              ),
              SizedBox(height: context.sp(context.ui.spacing.sm)),
              UiField(
                label: 'Current Password',
                child: UiPasswordField(
                  hintText: 'Enter your current password',
                  onChanged: (v) => passwordController.text = v,
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
              label: 'Send Verification Code',
              intent: UiIntent.primary,
              loading: isSubmitting,
              onPressed: () async {
                final newEmail = emailController.text.trim();
                final pwd = passwordController.text;
                if (newEmail.isEmpty || pwd.isEmpty) {
                  UiToast.show(
                    context,
                    title: 'Missing Fields',
                    message: 'Please fill in both email and password.',
                    intent: UiIntent.warning,
                  );
                  return;
                }
                setDialogState(() => isSubmitting = true);
                try {
                  await _repo.requestEmailChange(
                    newEmail: newEmail,
                    currentPassword: pwd,
                  );
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                  if (mounted) {
                    _showEmailOtpDialog(newEmail);
                  }
                } catch (e) {
                  setDialogState(() => isSubmitting = false);
                  if (mounted) {
                    UiToast.show(
                      context,
                      title: 'Request Failed',
                      message: e.toString().replaceAll('Exception: ', ''),
                      intent: UiIntent.danger,
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEmailOtpDialog(String newEmail) {
    bool verifying = false;
    String code = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => UiDialog(
          title: 'Verify Email Address',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'We sent a 6-digit confirmation code to $newEmail. Please enter it below to confirm.',
                style: context.uiText.body,
              ),
              SizedBox(height: context.sp(context.ui.spacing.md)),
              UiField(
                label: 'Verification Code',
                child: UiInput(
                  hintText: '123456',
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onChanged: (value) => code = value.trim(),
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
              label: 'Verify & Update Email',
              intent: UiIntent.primary,
              loading: verifying,
              onPressed: () async {
                if (verifying) return;
                if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                  UiToast.show(
                    context,
                    title: 'Enter the 6-digit code',
                    intent: UiIntent.warning,
                  );
                  return;
                }
                setDialogState(() => verifying = true);
                try {
                  final client = SupabaseConfig.client;
                  if (!SupabaseConfig.isConfigured || client == null) {
                    throw StateError('Email verification is unavailable.');
                  }
                  await client.auth.verifyOTP(
                    email: newEmail,
                    token: code,
                    type: OtpType.emailChange,
                  );
                  if (!ctx.mounted || !mounted) return;
                  if (client.auth.currentUser?.email?.toLowerCase() !=
                      newEmail.toLowerCase()) {
                    throw StateError(
                      'Check both your current and new inboxes to complete this email change.',
                    );
                  }
                  Navigator.of(ctx).pop();
                  setState(() => _currentEmail = newEmail);
                  UiToast.show(
                    context,
                    title: 'Email Updated',
                    message: 'Your verified email is now $newEmail.',
                    intent: UiIntent.success,
                  );
                } catch (error) {
                  if (!ctx.mounted || !mounted) return;
                  setDialogState(() => verifying = false);
                  UiToast.show(
                    context,
                    title: 'Verification failed',
                    message: error is AuthException
                        ? error.message
                        : error.toString().replaceFirst('Bad state: ', ''),
                    intent: UiIntent.danger,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _manageIdentity(String provider, bool linked) async {
    try {
      if (linked) {
        await _repo.unlinkConnectedAccount(provider);
      } else {
        await _repo.linkConnectedAccount(provider);
      }
      final fresh = await _repo.getConnectedAccounts();
      if (mounted) setState(() => _connectedAccounts = fresh);
    } catch (error) {
      if (mounted) {
        UiToast.show(
          context,
          title: 'Account linking failed',
          message: error is AuthException
              ? error.message
              : error.toString().replaceFirst('Bad state: ', ''),
          intent: UiIntent.warning,
        );
      }
    }
  }

  Future<void> _handleChangePassword() async {
    final cur = _curPwdController.text;
    final nw = _newPwdController.text;
    final cf = _confirmPwdController.text;

    if (cur.isEmpty || nw.isEmpty || cf.isEmpty) {
      UiToast.show(
        context,
        title: 'Missing Fields',
        message: 'Please complete all password fields.',
        intent: UiIntent.warning,
      );
      return;
    }

    if (nw != cf) {
      UiToast.show(
        context,
        title: 'Passwords Do Not Match',
        message: 'New password and confirmation must match.',
        intent: UiIntent.danger,
      );
      return;
    }

    if (nw.length < 8) {
      UiToast.show(
        context,
        title: 'Password Too Short',
        message: 'New password must be at least 8 characters long.',
        intent: UiIntent.warning,
      );
      return;
    }

    setState(() => _changingPassword = true);
    try {
      await _repo.changePassword(currentPassword: cur, newPassword: nw);
      if (mounted) {
        setState(() {
          _changingPassword = false;
          _curPwdController.clear();
          _newPwdController.clear();
          _confirmPwdController.clear();
        });
        UiToast.show(
          context,
          title: 'Password Updated',
          message: 'Your password has been changed successfully.',
          intent: UiIntent.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _changingPassword = false);
        UiToast.show(
          context,
          title: 'Update Failed',
          message: e.toString().replaceAll('Exception: ', ''),
          intent: UiIntent.danger,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    if (_loading) {
      return UiSkeleton.settingsDetail(sections: 3, rowsPerSection: 3);
    }

    final bool hasGoogle = _connectedAccounts.any(
      (a) => a.provider == 'google',
    );
    final bool hasApple = _connectedAccounts.any((a) => a.provider == 'apple');
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
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Email Section
              AppSettingsSectionBlock(
                title: 'Account Email',
                description:
                    'Your primary login credential and recipient for execution notifications.',
                children: [
                  UiCard(
                    child: isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    size: context.sz(20),
                                    color: colors.primary,
                                  ),
                                  SizedBox(width: context.sp(theme.spacing.sm)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Primary Email',
                                          style: context.uiText.caption
                                              .copyWith(
                                                color: colors.foregroundMuted,
                                              ),
                                        ),
                                        Text(
                                          _currentEmail,
                                          style: context.uiText.bodyStrong,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: context.sp(theme.spacing.md)),
                              UiButton(
                                label: 'Change Email',
                                variant: UiVariant.outline,
                                expand: true,
                                onPressed: _showChangeEmailDialog,
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: context.sz(20),
                                color: colors.primary,
                              ),
                              SizedBox(width: context.sp(theme.spacing.md)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Primary Email',
                                      style: context.uiText.caption.copyWith(
                                        color: colors.foregroundMuted,
                                      ),
                                    ),
                                    Text(
                                      _currentEmail,
                                      style: context.uiText.bodyStrong,
                                    ),
                                  ],
                                ),
                              ),
                              UiButton(
                                label: 'Change Email',
                                variant: UiVariant.outline,
                                size: UiSize.sm,
                                onPressed: _showChangeEmailDialog,
                              ),
                            ],
                          ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Password Section
              AppSettingsSectionBlock(
                title: 'Change Password',
                description:
                    'Ensure your account uses a long, unique password to prevent unauthorized access.',
                children: [
                  UiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        UiField(
                          label: 'Current Password',
                          child: UiPasswordField(
                            hintText: '••••••••',
                            onChanged: (v) => _curPwdController.text = v,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        UiField(
                          label: 'New Password',
                          child: UiPasswordField(
                            hintText: 'At least 8 characters',
                            onChanged: (v) => _newPwdController.text = v,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        UiField(
                          label: 'Confirm New Password',
                          child: UiPasswordField(
                            hintText: 'Re-enter new password',
                            onChanged: (v) => _confirmPwdController.text = v,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.md)),
                        if (isMobile)
                          UiButton(
                            label: 'Update Password',
                            intent: UiIntent.primary,
                            loading: _changingPassword,
                            expand: true,
                            onPressed: _handleChangePassword,
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              UiButton(
                                label: 'Update Password',
                                intent: UiIntent.primary,
                                loading: _changingPassword,
                                onPressed: _handleChangePassword,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Connected Accounts
              AppSettingsSectionBlock(
                title: 'Connected Accounts',
                description:
                    'Sign in seamlessly using your existing OAuth identity providers.',
                children: [
                  AppSettingCard(
                    title: 'Google',
                    description: hasGoogle
                        ? _connectedAccounts
                                  .where((a) => a.provider == 'google')
                                  .first
                                  .email ??
                              'Connected'
                        : 'Not linked',
                    icon: Icons.g_mobiledata_rounded,
                    control: UiButton(
                      label: hasGoogle ? 'Unlink' : 'Link Google',
                      variant: hasGoogle
                          ? UiVariant.outline
                          : UiVariant.primary,
                      size: UiSize.sm,
                      onPressed: () => _manageIdentity('google', hasGoogle),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Apple',
                    description: hasApple
                        ? 'Connected to Apple ID'
                        : 'Not linked',
                    icon: Icons.apple_rounded,
                    control: UiButton(
                      label: hasApple ? 'Unlink' : 'Link Apple',
                      variant: hasApple ? UiVariant.outline : UiVariant.primary,
                      size: UiSize.sm,
                      onPressed: () => _manageIdentity('apple', hasApple),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.xl)),

              // Danger Zone Link
              AppSettingsSectionBlock(
                title: 'Danger Zone',
                children: [
                  UiCard(
                    accentColor: colors.bearish,
                    child: isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: colors.bearish,
                                  ),
                                  SizedBox(width: context.sp(theme.spacing.sm)),
                                  Expanded(
                                    child: Text(
                                      'Delete Account',
                                      style: context.uiText.bodyStrong.copyWith(
                                        color: colors.bearish,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: context.sp(theme.spacing.xs)),
                              Text(
                                'Permanently close your account, wipe all active API sessions, and schedule data deletion.',
                                style: context.uiText.caption.copyWith(
                                  color: colors.foregroundMuted,
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.md)),
                              UiButton(
                                label: 'Delete Account',
                                variant: UiVariant.soft,
                                intent: UiIntent.danger,
                                expand: true,
                                onPressed: () {
                                  openSettingsSubpage(
                                    context,
                                    title: 'Delete Account & Data Purge',
                                    subtitle:
                                        'Configure post-deletion data purge condition and close account',
                                    icon: Icons.delete_forever_outlined,
                                    page: DeleteAccountPage(
                                      userRole: widget.userRole,
                                      repository: _repo,
                                      onAccountDeleted: widget.onAccountDeleted,
                                    ),
                                  );
                                },
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: colors.bearish,
                              ),
                              SizedBox(width: context.sp(theme.spacing.md)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Delete Account',
                                      style: context.uiText.bodyStrong.copyWith(
                                        color: colors.bearish,
                                      ),
                                    ),
                                    Text(
                                      'Permanently close your account, wipe all active API sessions, and schedule data deletion.',
                                      style: context.uiText.caption.copyWith(
                                        color: colors.foregroundMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              UiButton(
                                label: 'Delete Account',
                                variant: UiVariant.soft,
                                intent: UiIntent.danger,
                                size: UiSize.sm,
                                onPressed: () {
                                  openSettingsSubpage(
                                    context,
                                    title: 'Delete Account & Data Purge',
                                    subtitle:
                                        'Configure post-deletion data purge condition and close account',
                                    icon: Icons.delete_forever_outlined,
                                    page: DeleteAccountPage(
                                      userRole: widget.userRole,
                                      repository: _repo,
                                      onAccountDeleted: widget.onAccountDeleted,
                                    ),
                                  );
                                },
                              ),
                            ],
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
