import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/auth/data/repositories/auth_repository.dart';
import 'package:tradex/features/auth/data/repositories/auth_otp_repository.dart';
import 'package:tradex/features/auth/data/repositories/supabase_auth_otp_repository.dart';
import 'package:tradex/features/auth/models/otp_purpose.dart';
import 'package:tradex/features/auth/widgets/auth_step_icon.dart';

/// Forgot Password & Security Code Verification multi-step page.
///
/// Deliberately stays single-column with no marketing panel at every
/// breakpoint — this is a security-sensitive flow, so the only job of the
/// layout is to keep the user's attention on the current step.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    this.authRepository,
    this.otpRepository,
    this.completePasswordReset,
    required this.onBackToLogin,
  });

  final AuthRepository? authRepository;
  final Future<void> Function(String token, String password)?
  completePasswordReset;
  final AuthOtpRepository? otpRepository;
  final VoidCallback onBackToLogin;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  int _currentStep =
      0; // 0: Email Input, 1: OTP Entry, 2: New Password, 3: Success
  final TextEditingController _emailController = TextEditingController(
    text: '',
  );
  final UiOtpFieldController _otpController = UiOtpFieldController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  /// Single seam for the OTP send/verify/resend network calls — swap for a
  /// real implementation, see the contract documented on [AuthOtpRepository].
  late final AuthOtpRepository _otpRepository =
      widget.otpRepository ??
      (SupabaseConfig.isConfigured
          ? SupabaseAuthOtpRepository()
          : AuthOtpRepositoryImpl());

  /// Continuation token returned by [AuthOtpRepository.verifyOtp] once the
  /// code is confirmed. Backend contract: send this along with the new
  /// password on the "confirm reset" request so the server can prove the
  /// OTP step actually happened for this session.
  String? _resetToken;

  bool _isLoading = false;
  String? _errorText;
  int _timerSeconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final activeSession = SupabaseConfig.client?.auth.currentSession;
    if (activeSession != null && activeSession.accessToken.isNotEmpty) {
      _resetToken = activeSession.accessToken;
      _currentStep = 2;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timerSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_timerSeconds > 0) {
          _timerSeconds--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  void _handleSendResetLink() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorText = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      if (widget.otpRepository == null &&
          !SupabaseConfig.isConfigured &&
          !CustomerDataPolicy.allowDemo) {
        throw StateError(
          'Password recovery is unavailable in this environment.',
        );
      }
      await _otpRepository.sendOtp(
        identifier: email,
        purpose: OtpPurpose.passwordReset,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _currentStep = 1;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = 'Could not send a recovery code. Please retry.';
        });
      }
      return;
    }

    _otpController.clear();
    _startResendTimer();
    UiToast.show(
      context,
      title: 'Code Sent',
      message: 'Check your email for the recovery code.',
      intent: UiIntent.info,
    );
  }

  void _handleVerifyOtp([String? autoSubmittedCode]) async {
    if (_isLoading) return;
    final code = autoSubmittedCode ?? _otpController.value;
    if (code.length < 6) {
      setState(() => _errorText = 'Please enter the full 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final OtpVerifyResult result;
    try {
      result = await _otpRepository.verifyOtp(
        identifier: _emailController.text.trim(),
        purpose: OtpPurpose.passwordReset,
        code: code,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = 'Could not verify the code. Please retry.';
        });
      }
      return;
    }

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (!result.success) {
      setState(
        () => _errorText = result.errorMessage ?? 'Invalid or expired code.',
      );
      _otpController.clear();
      return;
    }

    _resetToken = result.token;
    setState(() => _currentStep = 2);
  }

  void _handleResetPassword() async {
    if (_isLoading) return;
    final pwd = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (pwd.length < 8) {
      setState(() => _errorText = 'Password must be at least 8 characters');
      return;
    }
    if (pwd != confirm) {
      setState(() => _errorText = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final token = _resetToken;
      if (token == null || token.isEmpty) {
        throw StateError('Verify a new recovery code first.');
      }
      if (widget.completePasswordReset != null) {
        await widget.completePasswordReset!(token, pwd);
      } else {
        final client = SupabaseConfig.client;
        final session = client?.auth.currentSession;
        if (!SupabaseConfig.isConfigured ||
            client == null ||
            session == null ||
            session.accessToken != token) {
          if (CustomerDataPolicy.allowDemo && token.isNotEmpty) {
            // In demo mode without live backend, permit mock reset completion.
          } else {
            throw StateError(
              'Your recovery session expired. Request another code.',
            );
          }
        } else {
          await client.auth.updateUser(UserAttributes(password: pwd));
          await client.auth.signOut();
        }
      }
      if (!mounted) return;
      _resetToken = null;
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() {
        _isLoading = false;
        _currentStep = 3;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = error is AuthException
              ? error.message
              : error.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final responsive = context.uiRes;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints viewportConstraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(
                  viewportConstraints.maxWidth < 360
                      ? theme.spacing.sm
                      : (responsive.isMobile
                            ? theme.spacing.md
                            : theme.spacing.lg),
                ),
                vertical: context.sp(theme.spacing.xl),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      (viewportConstraints.maxHeight -
                              context.sp(theme.spacing.xl) * 2)
                          .clamp(0.0, double.infinity),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: context.sz(460)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UiCard(
                          variant: UiCardVariant.surface,
                          child: Padding(
                            padding: EdgeInsets.all(
                              context.sp(
                                viewportConstraints.maxWidth < 360
                                    ? theme.spacing.md
                                    : (responsive.isMobile
                                          ? theme.spacing.lg
                                          : theme.spacing.xl),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Unified Header inside Card: Back Button, Logo, alphajournal & Step Badge
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: context.sp(theme.spacing.sm),
                                  runSpacing: context.sp(theme.spacing.sm),
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        UiIconButton(
                                          icon: Icons.arrow_back_rounded,
                                          size: UiSize.sm,
                                          tooltip: 'Back to Sign in',
                                          onPressed: widget.onBackToLogin,
                                        ),
                                        SizedBox(
                                          width: context.sp(theme.spacing.xs),
                                        ),
                                        const AppLogoMark(size: 20),
                                        if (!responsive.isMobile) ...[
                                          SizedBox(
                                            width: context.sp(theme.spacing.xs),
                                          ),
                                          Text(
                                            'AlphaJournal',
                                            style: context.uiText.bodyStrong
                                                .copyWith(
                                                  fontSize: 16,
                                                  letterSpacing: -0.2,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (_currentStep < 3)
                                      UiBadge(
                                        label: 'STEP ${_currentStep + 1} OF 3',
                                        intent: UiIntent.primary,
                                        variant: UiBadgeVariant.soft,
                                        size: UiSize.sm,
                                      ),
                                  ],
                                ),
                                if (_currentStep < 3) ...[
                                  SizedBox(
                                    height: context.sp(theme.spacing.lg),
                                  ),
                                  // Sleek Segmented Step Indicator
                                  Row(
                                    children: [
                                      for (int i = 0; i < 3; i++)
                                        Expanded(
                                          child: Container(
                                            height: 3.5,
                                            margin: EdgeInsets.only(
                                              right: i < 2 ? 6.0 : 0.0,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              color: i <= _currentStep
                                                  ? colors.primary
                                                  : colors.borderStrong
                                                        .withValues(alpha: 0.5),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                                SizedBox(height: context.sp(theme.spacing.xl)),
                                if (_errorText != null) ...[
                                  UiCallout(
                                    title: 'Error',
                                    message: _errorText!,
                                    intent: UiIntent.danger,
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.md),
                                  ),
                                ],

                                // Step 0: Email Input Form
                                if (_currentStep == 0) ...[
                                  const AuthStepIcon(
                                    icon: Icons.lock_reset_rounded,
                                    intent: UiIntent.primary,
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.md),
                                  ),
                                  Text(
                                    'Reset your password',
                                    textAlign: TextAlign.center,
                                    style: context.uiText.display.copyWith(
                                      fontSize: 28.0,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.xxs),
                                  ),
                                  Text(
                                    'Enter your email address and we will send you a 6-digit verification code.',
                                    textAlign: TextAlign.center,
                                    style: context.uiText.body.copyWith(
                                      color: colors.foregroundMuted,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.lg),
                                  ),
                                  UiField(
                                    label: 'Registered Email',
                                    required: true,
                                    child: UiInput(
                                      controller: _emailController,
                                      hintText: 'm@example.com',
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.lg),
                                  ),
                                  UiButton(
                                    label: _isLoading
                                        ? 'Sending Code…'
                                        : 'Send Reset Code',
                                    variant: UiVariant.primary,
                                    intent: UiIntent.primary,
                                    size: UiSize.lg,
                                    expand: true,
                                    onPressed: _isLoading
                                        ? null
                                        : _handleSendResetLink,
                                  ),
                                ],

                                // Step 1: Verification OTP Entry
                                if (_currentStep == 1) ...[
                                  const AuthStepIcon(
                                    icon: Icons.mark_email_read_outlined,
                                    intent: UiIntent.info,
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.md),
                                  ),
                                  Text(
                                    'Enter Verification Code',
                                    textAlign: TextAlign.center,
                                    style: context.uiText.display.copyWith(
                                      fontSize: 28.0,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.xxs),
                                  ),
                                  Text(
                                    'We sent a 6-digit code to ${_emailController.text}',
                                    textAlign: TextAlign.center,
                                    style: context.uiText.body.copyWith(
                                      color: colors.foregroundMuted,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.lg),
                                  ),
                                  Center(
                                    child: UiOtpField(
                                      controller: _otpController,
                                      length: 6,
                                      autofocus: true,
                                      enabled: !_isLoading,
                                      error: _errorText != null,
                                      onChanged: (_) {
                                        if (_errorText != null) {
                                          setState(() => _errorText = null);
                                        }
                                      },
                                      onCompleted: (code) =>
                                          _handleVerifyOtp(code),
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.md),
                                  ),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    runSpacing: context.sp(theme.spacing.xs),
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        _timerSeconds > 0
                                            ? 'Resend code in ${_timerSeconds}s'
                                            : "Didn't get a code?",
                                        style: context.uiText.caption.copyWith(
                                          color: colors.foregroundSubtle,
                                        ),
                                      ),
                                      if (_timerSeconds == 0) ...[
                                        SizedBox(
                                          width: context.sp(theme.spacing.xs),
                                        ),
                                        GestureDetector(
                                          onTap: _handleSendResetLink,
                                          child: Text(
                                            'Resend OTP',
                                            style: context.uiText.caption
                                                .copyWith(
                                                  color: colors.primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.lg),
                                  ),
                                  UiButton(
                                    label: _isLoading
                                        ? 'Verifying…'
                                        : 'Verify & Continue',
                                    variant: UiVariant.primary,
                                    intent: UiIntent.primary,
                                    size: UiSize.lg,
                                    expand: true,
                                    onPressed: _isLoading
                                        ? null
                                        : () => _handleVerifyOtp(),
                                  ),
                                ],

                                // Step 2: New Password Input
                                if (_currentStep == 2) ...[
                                  const AuthStepIcon(
                                    icon: Icons.password_rounded,
                                    intent: UiIntent.warning,
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.md),
                                  ),
                                  Text(
                                    'Set New Password',
                                    textAlign: TextAlign.center,
                                    style: context.uiText.display.copyWith(
                                      fontSize: 28.0,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.xxs),
                                  ),
                                  Text(
                                    'Must be at least 8 characters long.',
                                    textAlign: TextAlign.center,
                                    style: context.uiText.body.copyWith(
                                      color: colors.foregroundMuted,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.lg),
                                  ),
                                  UiField(
                                    label: 'New Password',
                                    required: true,
                                    child: UiPasswordField(
                                      controller: _newPasswordController,
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.md),
                                  ),
                                  UiField(
                                    label: 'Confirm New Password',
                                    required: true,
                                    child: UiPasswordField(
                                      controller: _confirmPasswordController,
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.lg),
                                  ),
                                  UiButton(
                                    label: _isLoading
                                        ? 'Resetting Password…'
                                        : 'Update Password',
                                    variant: UiVariant.primary,
                                    intent: UiIntent.primary,
                                    size: UiSize.lg,
                                    expand: true,
                                    onPressed: _isLoading
                                        ? null
                                        : _handleResetPassword,
                                  ),
                                ],

                                // Step 3: Success Confirmation State
                                if (_currentStep == 3) ...[
                                  const AuthStepIcon(
                                    icon: Icons.check_rounded,
                                    intent: UiIntent.bullish,
                                    large: true,
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.md),
                                  ),
                                  Text(
                                    'Password Updated!',
                                    textAlign: TextAlign.center,
                                    style: context.uiText.display.copyWith(
                                      fontSize: 28.0,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.xxs),
                                  ),
                                  Text(
                                    'Your account password has been successfully updated. You can now login with your new credentials.',
                                    textAlign: TextAlign.center,
                                    style: context.uiText.body.copyWith(
                                      color: colors.foregroundMuted,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.xl),
                                  ),
                                  UiButton(
                                    label: 'Sign In Now',
                                    variant: UiVariant.primary,
                                    intent: UiIntent.primary,
                                    size: UiSize.lg,
                                    expand: true,
                                    onPressed: widget.onBackToLogin,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.lg)),

                        // Trust footer — reassurance is the right note to end a
                        // security flow on, in place of any marketing panel.
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: context.sz(14),
                              color: colors.foregroundSubtle,
                            ),
                            SizedBox(width: context.sp(theme.spacing.xs)),
                            Flexible(
                              child: Text(
                                'Manage your account and privacy settings in alphajournal',
                                overflow: TextOverflow.ellipsis,
                                style: context.uiText.caption.copyWith(
                                  color: colors.foregroundSubtle,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
