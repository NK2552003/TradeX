import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/auth/presentation/pages/auth_wrapper.dart';
import 'package:alphajournal/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:alphajournal/features/settings/models/active_session_model.dart';
import 'package:alphajournal/features/settings/models/connected_account_model.dart';
import 'package:alphajournal/features/settings/presentation/pages/shared/delete_account_page.dart';
import 'package:alphajournal/features/settings/presentation/widgets/settings_subpage_scope.dart';

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
  StreamSubscription<AuthState>? _authSub;
  bool _loading = true;
  bool _hasEmailIdentity = true;
  String? _managingProvider;
  String? _oauthLinkError;
  int _passwordFormVersion = 0;
  String _currentEmail = 'nitish@alphajournal.in';
  List<ConnectedAccount> _connectedAccounts = [];
  List<ActiveDeviceSession> _activeSessions = [];
  SecurityPreferencesModel _securityPrefs = const SecurityPreferencesModel();
  String? _revokingSessionId;
  bool _revokingOthers = false;
  bool _refreshingSessions = false;

  // Controllers for password change
  final TextEditingController _curPwdController = TextEditingController();
  final TextEditingController _newPwdController = TextEditingController();
  final TextEditingController _confirmPwdController = TextEditingController();
  bool _changingPassword = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ProfileSettingsRepositoryImpl();
    _captureInitialOAuthError();
    if (SupabaseConfig.isConfigured) {
      _authSub = SupabaseConfig.client?.auth.onAuthStateChange.listen((data) {
        if (!mounted) return;
        if (data.event == AuthChangeEvent.userUpdated ||
            data.event == AuthChangeEvent.signedIn ||
            data.event == AuthChangeEvent.tokenRefreshed) {
          _loadSecurityData();
        }
      });
    }
    _loadSecurityData();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _curPwdController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    super.dispose();
  }

  void _captureInitialOAuthError() {
    final pending = AuthWrapper.consumePendingOAuthError();
    if (pending != null && pending.isNotEmpty) {
      _oauthLinkError = pending;
      return;
    }
    if (!kIsWeb) return;
    final uri = Uri.base;
    final fragmentParams = uri.fragment.contains('=')
        ? Uri.splitQueryString(uri.fragment)
        : const <String, String>{};
    final err =
        uri.queryParameters['error_description'] ??
        uri.queryParameters['error'] ??
        fragmentParams['error_description'] ??
        fragmentParams['error'];
    if (err != null && err.isNotEmpty) {
      _oauthLinkError = err;
    }
  }

  Future<bool> _hasEmailIdentitySafe() async {
    try {
      return await _repo.hasEmailIdentity();
    } catch (_) {
      return true;
    }
  }

  Future<List<ActiveDeviceSession>> _getActiveSessionsSafe() async {
    try {
      return await _repo.getActiveSessions();
    } catch (_) {
      return const <ActiveDeviceSession>[];
    }
  }

  Future<SecurityPreferencesModel> _getSecurityPrefsSafe() async {
    try {
      return await _repo.getSecurityPreferences();
    } catch (_) {
      return const SecurityPreferencesModel();
    }
  }

  Future<void> _loadSecurityData() async {
    if (_connectedAccounts.isEmpty && _loading == false) {
      // keep existing UI if refreshing in background
    } else if (_connectedAccounts.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      final profile = await _repo.getProfile();
      final connected = await _repo.getConnectedAccounts();
      final hasEmail = await _hasEmailIdentitySafe();
      final sessions = await _getActiveSessionsSafe();
      final secPrefs = await _getSecurityPrefsSafe();
      if (mounted) {
        setState(() {
          _currentEmail =
              SupabaseConfig.client?.auth.currentUser?.email ?? profile.email;
          _connectedAccounts = connected;
          _hasEmailIdentity = hasEmail;
          _activeSessions = sessions;
          _securityPrefs = secPrefs;
          _loading = false;
        });
        final pendingErr = _oauthLinkError;
        if (pendingErr != null && pendingErr.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            UiToast.show(
              context,
              title: 'Account linking error',
              message: pendingErr,
              intent: UiIntent.warning,
            );
          });
        }
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
              if (_hasEmailIdentity) ...[
                SizedBox(height: context.sp(context.ui.spacing.sm)),
                UiField(
                  label: 'Current Password',
                  child: UiPasswordField(
                    hintText: 'Enter your current password',
                    onChanged: (v) => passwordController.text = v,
                  ),
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
              label: 'Send Verification Code',
              intent: UiIntent.primary,
              loading: isSubmitting,
              onPressed: () async {
                final newEmail = emailController.text.trim();
                final pwd = passwordController.text;
                if (newEmail.isEmpty || (_hasEmailIdentity && pwd.isEmpty)) {
                  UiToast.show(
                    context,
                    title: 'Missing Fields',
                    message: _hasEmailIdentity
                        ? 'Please fill in both email and password.'
                        : 'Please enter the new email address.',
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

  String _providerLabel(String provider) =>
      provider == 'google' ? 'Google' : 'Apple';

  Future<void> _manageIdentity(String provider, bool linked) async {
    if (_managingProvider != null) return;
    final label = _providerLabel(provider);

    if (linked) {
      final canUnlink = _hasEmailIdentity || _connectedAccounts.length > 1;
      if (!canUnlink) {
        UiToast.show(
          context,
          title: 'Cannot Unlink Only Sign-In Method',
          message:
              'Set an account password above or link another provider before unlinking $label.',
          intent: UiIntent.warning,
        );
        return;
      }

      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (ctx) => UiDialog(
              title: 'Unlink $label?',
              content: Text(
                'You will no longer be able to sign in with this $label account unless you link it again.',
                style: context.uiText.body,
              ),
              actions: [
                UiButton(
                  label: 'Cancel',
                  variant: UiVariant.outline,
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
                UiButton(
                  label: 'Unlink $label',
                  intent: UiIntent.danger,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed || !mounted) return;
    }

    setState(() {
      _managingProvider = provider;
      _oauthLinkError = null;
    });
    try {
      if (linked) {
        await _repo.unlinkConnectedAccount(provider);
      } else {
        await _repo.linkConnectedAccount(provider);
      }
      final fresh = await _repo.getConnectedAccounts();
      final hasEmail = await _hasEmailIdentitySafe();
      if (mounted) {
        setState(() {
          _connectedAccounts = fresh;
          _hasEmailIdentity = hasEmail;
        });
        UiToast.show(
          context,
          title: linked ? '$label Unlinked' : '$label Linked',
          message: linked
              ? '$label sign-in has been removed from your account.'
              : '$label is now connected to your AlphaJournal account.',
          intent: UiIntent.success,
        );
      }
    } catch (error) {
      if (mounted) {
        final msg = error is AuthException
            ? error.message
            : error.toString().replaceFirst('Bad state: ', '');
        setState(() => _oauthLinkError = msg);
        UiToast.show(
          context,
          title: linked ? 'Unlink failed' : 'Account linking failed',
          message: msg,
          intent: UiIntent.warning,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _managingProvider = null);
      }
    }
  }

  Future<void> _handleChangePassword() async {
    final cur = _curPwdController.text;
    final nw = _newPwdController.text;
    final cf = _confirmPwdController.text;

    if ((_hasEmailIdentity && cur.isEmpty) || nw.isEmpty || cf.isEmpty) {
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
      final hasEmail = await _hasEmailIdentitySafe();
      if (mounted) {
        setState(() {
          _changingPassword = false;
          _hasEmailIdentity = hasEmail;
          _passwordFormVersion++;
          _curPwdController.clear();
          _newPwdController.clear();
          _confirmPwdController.clear();
        });
        UiToast.show(
          context,
          title: 'Password Updated',
          message: 'Your password has been saved successfully.',
          intent: UiIntent.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _changingPassword = false);
        UiToast.show(
          context,
          title: 'Update Failed',
          message: e is AuthException
              ? e.message
              : e.toString().replaceAll('Exception: ', ''),
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
                title: _hasEmailIdentity
                    ? 'Change Password'
                    : 'Set Account Password',
                description: _hasEmailIdentity
                    ? 'Ensure your account uses a long, unique password to prevent unauthorized access.'
                    : 'Your account uses OAuth sign-in. Set a password to enable email sign-in or safely unlink providers.',
                children: [
                  UiCard(
                    child: KeyedSubtree(
                      key: ValueKey('pwd_form_$_passwordFormVersion'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_hasEmailIdentity) ...[
                            UiField(
                              label: 'Current Password',
                              child: UiPasswordField(
                                hintText: '••••••••',
                                onChanged: (v) => _curPwdController.text = v,
                              ),
                            ),
                            SizedBox(height: context.sp(theme.spacing.sm)),
                          ],
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
                              label: _hasEmailIdentity
                                  ? 'Update Password'
                                  : 'Set Password',
                              intent: UiIntent.primary,
                              loading: _changingPassword,
                              expand: true,
                              onPressed: _changingPassword
                                  ? null
                                  : _handleChangePassword,
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                UiButton(
                                  label: _hasEmailIdentity
                                      ? 'Update Password'
                                      : 'Set Password',
                                  intent: UiIntent.primary,
                                  loading: _changingPassword,
                                  onPressed: _changingPassword
                                      ? null
                                      : _handleChangePassword,
                                ),
                              ],
                            ),
                        ],
                      ),
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
                  if (_oauthLinkError != null &&
                      _oauthLinkError!.isNotEmpty) ...[
                    UiCallout(
                      title: 'Account Linking Notice',
                      message: _oauthLinkError!,
                      intent: UiIntent.warning,
                      onClose: () => setState(() => _oauthLinkError = null),
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                  ],
                  AppSettingCard(
                    title: 'Google',
                    description: hasGoogle
                        ? _connectedAccounts
                                  .where((a) => a.provider == 'google')
                                  .first
                                  .email ??
                              'Connected to Google'
                        : 'Not linked',
                    icon: Icons.g_mobiledata_rounded,
                    control: UiButton(
                      label: hasGoogle ? 'Unlink' : 'Link Google',
                      variant: hasGoogle
                          ? UiVariant.outline
                          : UiVariant.primary,
                      size: UiSize.sm,
                      loading: _managingProvider == 'google',
                      onPressed: _managingProvider != null
                          ? null
                          : () => _manageIdentity('google', hasGoogle),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Apple',
                    description: hasApple
                        ? (_connectedAccounts
                                  .where((a) => a.provider == 'apple')
                                  .first
                                  .email ??
                              'Connected to Apple ID')
                        : 'Not linked',
                    icon: Icons.apple_rounded,
                    control: UiButton(
                      label: hasApple ? 'Unlink' : 'Link Apple',
                      variant: hasApple ? UiVariant.outline : UiVariant.primary,
                      size: UiSize.sm,
                      loading: _managingProvider == 'apple',
                      onPressed: _managingProvider != null
                          ? null
                          : () => _manageIdentity('apple', hasApple),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.xl)),

              // Logged-in Devices & Active Sessions
              _buildActiveDevicesSection(theme, isMobile),
              SizedBox(height: context.sp(theme.spacing.xl)),

              // Session & Sign-in Protection Preferences
              _buildSessionProtectionSection(isMobile),
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

  Future<void> _refreshActiveSessions() async {
    if (_refreshingSessions) return;
    setState(() => _refreshingSessions = true);
    final sessions = await _getActiveSessionsSafe();
    if (!mounted) return;
    setState(() {
      _activeSessions = sessions;
      _refreshingSessions = false;
    });
  }

  Future<void> _updateSecurityPrefs(
    SecurityPreferencesModel updated,
    String toastTitle,
  ) async {
    setState(() => _securityPrefs = updated);
    try {
      await _repo.updateSecurityPreferences(updated);
      if (mounted) {
        UiToast.show(
          context,
          title: toastTitle,
          message: 'Security preference saved.',
          intent: UiIntent.success,
        );
      }
    } catch (e) {
      if (mounted) {
        UiToast.show(
          context,
          title: 'Could Not Save Preference',
          message: '$e',
          intent: UiIntent.danger,
        );
      }
    }
  }

  Future<void> _confirmRevokeSession(ActiveDeviceSession session) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => UiDialog(
        title: session.isCurrent
            ? 'Log Out of This Device?'
            : 'Log Out Device Session?',
        content: Text(
          session.isCurrent
              ? 'This will end the active session on "${session.deviceName}" and return you to the sign-in screen.'
              : 'This will immediately sign out "${session.deviceName}" and revoke its refresh token.',
          style: context.uiText.body,
        ),
        actions: [
          UiButton(
            label: 'Cancel',
            variant: UiVariant.outline,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          UiButton(
            label: session.isCurrent ? 'Log Out This Device' : 'Log Out Device',
            intent: UiIntent.danger,
            variant: UiVariant.primary,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _revokingSessionId = session.sessionId);
    try {
      final bool signedOutCurrent = await _repo.revokeSession(
        session.sessionId,
      );
      if (!mounted) return;
      if (signedOutCurrent || session.isCurrent) {
        setState(() => _revokingSessionId = null);
        widget.onAccountDeleted?.call();
        return;
      }
      final updated = await _getActiveSessionsSafe();
      if (!mounted) return;
      setState(() {
        _revokingSessionId = null;
        _activeSessions = updated
            .where((s) => s.sessionId != session.sessionId)
            .toList();
      });
      UiToast.show(
        context,
        title: 'Device Logged Out',
        message: 'Ended active session on ${session.deviceName}.',
        intent: UiIntent.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _revokingSessionId = null);
      UiToast.show(
        context,
        title: 'Log Out Failed',
        message: '$e',
        intent: UiIntent.danger,
      );
    }
  }

  Future<void> _confirmRevokeOtherSessions() async {
    final otherCount = _activeSessions.where((s) => !s.isCurrent).length;
    if (otherCount <= 0) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => UiDialog(
        title: 'Log Out All Other Devices?',
        content: Text(
          'This will sign out $otherCount other active device${otherCount == 1 ? '' : 's'} while keeping your current session signed in.',
          style: context.uiText.body,
        ),
        actions: [
          UiButton(
            label: 'Cancel',
            variant: UiVariant.outline,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          UiButton(
            label: 'Log Out Other Devices',
            intent: UiIntent.danger,
            variant: UiVariant.primary,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _revokingOthers = true);
    try {
      await _repo.revokeOtherSessions();
      final remaining = await _getActiveSessionsSafe();
      if (!mounted) return;
      setState(() {
        _revokingOthers = false;
        _activeSessions =
            remaining.where((s) => s.isCurrent).toList().isNotEmpty
            ? remaining
            : _activeSessions.where((s) => s.isCurrent).toList();
      });
      UiToast.show(
        context,
        title: 'Other Devices Signed Out',
        message: 'Only this device remains signed in to your account.',
        intent: UiIntent.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _revokingOthers = false);
      UiToast.show(
        context,
        title: 'Action Failed',
        message: '$e',
        intent: UiIntent.danger,
      );
    }
  }

  IconData _deviceIcon(String platform) => switch (platform.toLowerCase()) {
    'ios' => Icons.phone_iphone_rounded,
    'android' => Icons.phone_android_rounded,
    'macos' => Icons.laptop_mac_rounded,
    'windows' => Icons.desktop_windows_outlined,
    'linux' => Icons.computer_outlined,
    _ => Icons.devices_outlined,
  };

  String _formatRelativeTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'Active now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _buildActiveDevicesSection(UiTheme theme, bool isMobile) {
    final colors = theme.colors;
    final int count = _activeSessions.length;
    final int otherCount = _activeSessions.where((s) => !s.isCurrent).length;

    return AppSettingsSectionBlock(
      title: 'Logged-in Devices & Active Sessions',
      description:
          'Monitor every device currently signed in to your account and remotely log out unfamiliar sessions.',
      children: [
        UiCard(
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: context.sp(theme.spacing.sm),
            runSpacing: context.sp(theme.spacing.sm),
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: context.sp(theme.spacing.sm),
                runSpacing: context.sp(theme.spacing.xs),
                children: [
                  Icon(
                    Icons.devices_other_rounded,
                    size: context.sz(20),
                    color: colors.primary,
                  ),
                  Text('Active Devices', style: context.uiText.bodyStrong),
                  UiBadge(
                    label: '$count active device${count == 1 ? '' : 's'}',
                    intent: count > 1 ? UiIntent.warning : UiIntent.success,
                    size: UiSize.xs,
                  ),
                ],
              ),
              Wrap(
                spacing: context.sp(theme.spacing.xs),
                runSpacing: context.sp(theme.spacing.xs),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  UiIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh active devices',
                    variant: UiVariant.ghost,
                    size: UiSize.sm,
                    onPressed: _refreshingSessions
                        ? null
                        : _refreshActiveSessions,
                  ),
                  if (otherCount > 0)
                    UiButton(
                      label:
                          'Log out $otherCount other device${otherCount == 1 ? '' : 's'}',
                      variant: UiVariant.outline,
                      intent: UiIntent.danger,
                      size: UiSize.sm,
                      loading: _revokingOthers,
                      onPressed: _revokingOthers
                          ? null
                          : _confirmRevokeOtherSessions,
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_activeSessions.isEmpty)
          const UiCallout(
            title: 'No Active Sessions Detected',
            message: 'Sign in again or refresh to view active device sessions.',
            intent: UiIntent.neutral,
          )
        else
          for (final session in _activeSessions)
            _buildDeviceSessionCard(session, theme, isMobile),
      ],
    );
  }

  Widget _buildDeviceSessionCard(
    ActiveDeviceSession session,
    UiTheme theme,
    bool isMobile,
  ) {
    final colors = theme.colors;
    final bool revoking = _revokingSessionId == session.sessionId;
    final String metaLine =
        'Last active: ${_formatRelativeTime(session.lastActiveAt)} · Signed in ${_formatDate(session.createdAt)}';

    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: context.sp(theme.spacing.xs),
          runSpacing: context.sp(theme.spacing.xs),
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(session.deviceName, style: context.uiText.bodyStrong),
            if (session.isCurrent)
              const UiBadge(
                label: 'This device',
                intent: UiIntent.success,
                size: UiSize.xs,
              ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.xxs)),
        Text(
          session.subtitle,
          style: context.uiText.caption.copyWith(color: colors.foregroundMuted),
        ),
        SizedBox(height: context.sp(theme.spacing.xxs)),
        Text(
          metaLine,
          style: context.uiText.caption.copyWith(color: colors.foregroundMuted),
        ),
      ],
    );

    final Widget logoutButton = UiButton(
      label: 'Log out',
      variant: session.isCurrent ? UiVariant.outline : UiVariant.soft,
      intent: UiIntent.danger,
      size: UiSize.sm,
      expand: isMobile,
      loading: revoking,
      onPressed: (_revokingSessionId != null || _revokingOthers)
          ? null
          : () => _confirmRevokeSession(session),
    );

    return UiCard(
      accentColor: session.isCurrent ? colors.bullish : null,
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _deviceIcon(session.platform),
                      size: context.sz(22),
                      color: session.isCurrent
                          ? colors.bullish
                          : colors.foregroundMuted,
                    ),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Expanded(child: details),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.md)),
                logoutButton,
              ],
            )
          : Row(
              children: [
                Icon(
                  _deviceIcon(session.platform),
                  size: context.sz(22),
                  color: session.isCurrent
                      ? colors.bullish
                      : colors.foregroundMuted,
                ),
                SizedBox(width: context.sp(theme.spacing.md)),
                Expanded(child: details),
                SizedBox(width: context.sp(theme.spacing.md)),
                logoutButton,
              ],
            ),
    );
  }

  Widget _buildSessionProtectionSection(bool isMobile) {
    return AppSettingsSectionBlock(
      title: 'Session & Sign-In Protection',
      description:
          'Configure session security alerts, trusted device persistence, and idle lock timing.',
      children: [
        AppSettingCard(
          title: 'New Device Sign-In Alerts',
          description:
              'Notify you whenever your account is accessed from an unrecognized device or browser.',
          icon: Icons.notification_important_outlined,
          control: UiSwitch(
            value: _securityPrefs.loginAlertsEnabled,
            onChanged: (val) => _updateSecurityPrefs(
              _securityPrefs.copyWith(loginAlertsEnabled: val),
              val ? 'Sign-In Alerts Enabled' : 'Sign-In Alerts Paused',
            ),
          ),
        ),
        AppSettingCard(
          title: 'Confirm Sensitive Account Changes',
          description:
              'Require explicit verification before changing email, linking providers, or exporting account data.',
          icon: Icons.verified_user_outlined,
          control: UiSwitch(
            value: _securityPrefs.requireReauthForSensitiveActions,
            onChanged: (val) => _updateSecurityPrefs(
              _securityPrefs.copyWith(requireReauthForSensitiveActions: val),
              val
                  ? 'Extra Verification Enabled'
                  : 'Extra Verification Disabled',
            ),
          ),
        ),
        AppSettingCard(
          title: 'Remember Trusted Devices',
          description:
              'Keep verified devices signed in across browser restarts unless manually logged out above.',
          icon: Icons.devices_rounded,
          control: UiSwitch(
            value: _securityPrefs.rememberTrustedDevices,
            onChanged: (val) => _updateSecurityPrefs(
              _securityPrefs.copyWith(rememberTrustedDevices: val),
              val
                  ? 'Trusted Devices Remembered'
                  : 'Trusted Device Persistence Off',
            ),
          ),
        ),
        AppSettingCard(
          title: 'Idle Session Auto-Lock',
          description:
              'Automatically lock sensitive workspace views after prolonged inactivity.',
          icon: Icons.timer_outlined,
          control: UiSelect<int>(
            width: isMobile ? null : 210,
            value: _securityPrefs.autoLockMinutes,
            options: const <UiOption<int>>[
              UiOption(label: 'Never (Stay signed in)', value: 0),
              UiOption(label: 'After 15 minutes', value: 15),
              UiOption(label: 'After 30 minutes', value: 30),
              UiOption(label: 'After 60 minutes', value: 60),
            ],
            onChanged: (val) => _updateSecurityPrefs(
              _securityPrefs.copyWith(autoLockMinutes: val),
              'Auto-Lock Updated',
            ),
          ),
        ),
      ],
    );
  }
}
