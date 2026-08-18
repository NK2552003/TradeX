import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/data/repositories/auth_otp_repository.dart';
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
      widget.repository ?? AuthOtpRepositoryImpl();
  final UiOtpFieldController _codeController = UiOtpFieldController();

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorText;
  int _timerSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
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

    setState(() => _isResending = true);
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.lg),
              vertical: context.sp(theme.spacing.xl),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.sz(460)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Compact brand row above the card.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const AppLogoMark(size: 16),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      Text(
                        'TradeX',
                        style: context.uiText.bodyStrong.copyWith(
                          fontSize: 15,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.xl)),

                  // Back button header
                  Align(
                    alignment: Alignment.centerLeft,
                    child: UiButton(
                      label: widget.purpose.backLabel,
                      leadingIcon: Icons.arrow_back_rounded,
                      variant: UiVariant.ghost,
                      intent: UiIntent.neutral,
                      onPressed: widget.onBack,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.lg)),

                  UiCard(
                    variant: UiCardVariant.surface,
                    child: Padding(
                      padding: EdgeInsets.all(
                        context.sp(
                          context.uiRes.isMobile
                              ? theme.spacing.lg
                              : theme.spacing.xl,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (_errorText != null) ...<Widget>[
                            UiCallout(
                              title: 'Error',
                              message: _errorText!,
                              intent: UiIntent.danger,
                            ),
                            SizedBox(height: context.sp(theme.spacing.md)),
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
                              fontSize: 26,
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
                              fontSize: 13,
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
                              onCompleted: (String code) => _handleVerify(code),
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
                                SizedBox(width: context.sp(theme.spacing.xs)),
                                GestureDetector(
                                  onTap: _isResending ? null : _handleResend,
                                  child: Text(
                                    _isResending ? 'Sending…' : 'Resend OTP',
                                    style: context.uiText.caption.copyWith(
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
                    children: <Widget>[
                      Icon(
                        Icons.verified_user_outlined,
                        size: context.sz(14),
                        color: colors.foregroundSubtle,
                      ),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      Text(
                        'Your data is encrypted end-to-end',
                        style: context.uiText.caption.copyWith(
                          color: colors.foregroundSubtle,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
