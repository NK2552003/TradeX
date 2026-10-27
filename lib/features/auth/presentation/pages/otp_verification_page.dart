import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/auth/data/repositories/auth_otp_repository.dart';
import 'package:tradex/features/auth/data/repositories/supabase_auth_otp_repository.dart';
import 'package:tradex/features/auth/models/otp_purpose.dart';
import 'package:tradex/features/auth/widgets/auth_step_icon.dart';

/// Standalone OTP / verification-code screen shared by every auth flow that
/// needs a one-time code confirmed before continuing — used for
/// signup e-mail verification and password resets (see [OtpPurpose]).
///
/// Deliberately mirrors [ForgotPasswordPage]'s single-column, no-marketing
/// -panel layout: this is a security-sensitive step, so the only job of the
/// layout is to keep the user's attention on the current code entry.
class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({
    super.key,
    required this.identifier,
    required this.purpose,
    required this.onVerified,
    required this.onBack,
    this.repository,
    this.codeLength = 6,
    this.resendCooldownSeconds = 60,
  });

  /// Email (or phone) the code was sent to — shown to the user and passed
  /// through to [AuthOtpRepository].
  final String identifier;
  final OtpPurpose purpose;

  /// Called once the backend confirms the code. [token] is whatever
  /// [AuthOtpRepository.verifyOtp] returned (session token / continuation
  /// token) so the caller can proceed — e.g. finish sign-in, or move on to
  /// "set new password".
  final void Function(String token) onVerified;
  final VoidCallback onBack;

  /// Swap in a real implementation once the backend endpoints exist. See
  /// the contract documented on [AuthOtpRepository].
  final AuthOtpRepository? repository;
  final int codeLength;
  final int resendCooldownSeconds;

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  late final AuthOtpRepository _repository =
      widget.repository ??
      (SupabaseConfig.isConfigured
          ? SupabaseAuthOtpRepository()
          : AuthOtpRepositoryImpl());
  final UiOtpFieldController _codeController = UiOtpFieldController();

  bool _isVerifying = false;
  bool _isResending = false;
  bool _isAlreadyConfirmed = false;
  String? _errorText;
  int _timerSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _checkVerificationStatus();
  }

  Future<void> _checkVerificationStatus() async {
    if (widget.purpose != OtpPurpose.signupVerification) return;
    try {
      final client = SupabaseConfig.client;
      if (client != null && SupabaseConfig.isConfigured) {
        final session = client.auth.currentSession;
        final user = client.auth.currentUser ?? session?.user;
        if (session != null ||
            (user != null && user.emailConfirmedAt != null)) {
          if (mounted) {
            setState(() {
              _isAlreadyConfirmed = true;
            });
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timerSeconds = widget.resendCooldownSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
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

  Future<void> _handleVerify([String? autoSubmittedCode]) async {
    final String code = autoSubmittedCode ?? _codeController.value;
    if (code.length < widget.codeLength) {
      setState(
        () => _errorText = 'Enter the full ${widget.codeLength}-digit code',
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    final OtpVerifyResult result = await _repository.verifyOtp(
      identifier: widget.identifier,
      purpose: widget.purpose,
      code: code,
    );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (!result.success) {
      setState(
        () => _errorText = result.errorMessage ?? 'Invalid or expired code.',
      );
      _codeController.clear();
      return;
    }

    widget.onVerified(result.token ?? '');
  }

  Future<void> _handleResend() async {
    if (_timerSeconds > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorText = null;
    });

    try {
      await _repository.resendOtp(
        identifier: widget.identifier,
        purpose: widget.purpose,
      );
      if (!mounted) return;

      setState(() {
        _isResending = false;
        _errorText = null;
      });
      _codeController.clear();
      _startResendTimer();

      UiToast.show(
        context,
        title: 'Code Sent',
        message: 'A new verification code was sent to ${widget.identifier}',
        intent: UiIntent.info,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResending = false;
        _errorText =
            'Unable to resend OTP: ${e.toString().replaceAll('AuthException: ', '')}';
      });
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
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(
                  responsive.isMobile ? theme.spacing.md : theme.spacing.lg,
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
                      children: <Widget>[
                        UiCard(
                          variant: UiCardVariant.surface,
                          child: Padding(
                            padding: EdgeInsets.all(
                              context.sp(
                                responsive.isMobile
                                    ? theme.spacing.lg
                                    : theme.spacing.xl,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                // Unified Header inside Card: Back Button, Logo & alphajournal
                                Row(
                                  children: <Widget>[
                                    UiIconButton(
                                      icon: Icons.arrow_back_rounded,
                                      size: UiSize.sm,
                                      tooltip: widget.purpose.backLabel,
                                      onPressed: widget.onBack,
                                    ),
                                    SizedBox(
                                      width: context.sp(theme.spacing.xs),
                                    ),
                                    const AppLogoMark(size: 20),
                                    SizedBox(
                                      width: context.sp(theme.spacing.xs),
                                    ),
                                    Text(
                                      'alphajournal',
                                      style: context.uiText.bodyStrong.copyWith(
                                        fontSize: 16,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_errorText != null) ...<Widget>[
                                  UiCallout(
                                    title: 'Error',
                                    message: _errorText!,
                                    intent: UiIntent.danger,
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.md),
                                  ),
                                ],
                                if (_isAlreadyConfirmed) ...<Widget>[
                                  UiCallout(
                                    title: 'Email Already Verified',
                                    message:
                                        'Your email (${widget.identifier}) is already verified in Supabase! You can proceed directly without entering a code.',
                                    intent: UiIntent.success,
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.md),
                                  ),
                                  UiButton(
                                    label: 'Continue to Account Setup',
                                    variant: UiVariant.primary,
                                    intent: UiIntent.success,
                                    size: UiSize.lg,
                                    onPressed: () =>
                                        widget.onVerified('already_confirmed'),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.lg),
                                  ),
                                  UiDivider(label: 'OR ENTER CODE'),
                                  SizedBox(
                                    height: context.sp(theme.spacing.md),
                                  ),
                                ],

                                const AuthStepIcon(
                                  icon: Icons.mark_email_read_outlined,
                                  intent: UiIntent.info,
                                ),
                                SizedBox(height: context.sp(theme.spacing.md)),
                                Text(
                                  widget.purpose.title,
                                  textAlign: TextAlign.center,
                                  style: context.uiText.display.copyWith(
                                    fontSize: 28.0,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(height: context.sp(theme.spacing.xxs)),
                                Text(
                                  '${widget.purpose.subtitle} ${widget.identifier}',
                                  textAlign: TextAlign.center,
                                  style: context.uiText.body.copyWith(
                                    color: colors.foregroundMuted,
                                    fontSize: 13.5,
                                  ),
                                ),
                                SizedBox(height: context.sp(theme.spacing.xl)),

                                Center(
                                  child: UiOtpField(
                                    controller: _codeController,
                                    length: widget.codeLength,
                                    autofocus: true,
                                    enabled: !_isVerifying,
                                    error: _errorText != null,
                                    onChanged: (_) {
                                      if (_errorText != null) {
                                        setState(() => _errorText = null);
                                      }
                                    },
                                    onCompleted: (String code) =>
                                        _handleVerify(code),
                                  ),
                                ),
                                SizedBox(height: context.sp(theme.spacing.lg)),

                                Wrap(
                                  alignment: WrapAlignment.center,
                                  runSpacing: context.sp(theme.spacing.xs),
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: <Widget>[
                                    Text(
                                      _timerSeconds > 0
                                          ? 'Resend code in ${_timerSeconds}s'
                                          : "Didn't get a code?",
                                      style: context.uiText.caption.copyWith(
                                        color: colors.foregroundSubtle,
                                      ),
                                    ),
                                    if (_timerSeconds == 0) ...<Widget>[
                                      SizedBox(
                                        width: context.sp(theme.spacing.xs),
                                      ),
                                      GestureDetector(
                                        onTap: _isResending
                                            ? null
                                            : _handleResend,
                                        child: Text(
                                          _isResending
                                              ? 'Sending…'
                                              : 'Resend OTP',
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
                                SizedBox(height: context.sp(theme.spacing.lg)),

                                UiButton(
                                  label: _isVerifying
                                      ? 'Verifying…'
                                      : 'Verify & Continue',
                                  variant: UiVariant.primary,
                                  intent: UiIntent.primary,
                                  size: UiSize.lg,
                                  onPressed: _isVerifying
                                      ? null
                                      : () => _handleVerify(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.lg)),

                        // Trust footer — same reassurance note used by the rest of
                        // the security-sensitive auth flows.
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
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
