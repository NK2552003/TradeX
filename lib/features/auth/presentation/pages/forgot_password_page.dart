import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/widgets/auth_background.dart';

/// Forgot Password & Security Code Verification multi-step page.
///
/// Deliberately stays single-column with no marketing panel at every
/// breakpoint — this is a security-sensitive flow, so the only job of the
/// layout is to keep the user's attention on the current step.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    required this.onBackToLogin,
  });

  final VoidCallback onBackToLogin;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  int _currentStep = 0; // 0: Email Input, 1: OTP Entry, 2: New Password, 3: Success
  final TextEditingController _emailController =
      TextEditingController(text: 'nitish@tradex.ai');
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorText;
  int _timerSeconds = 60;
  Timer? _timer;

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
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorText = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _currentStep = 1;
    });

    _startResendTimer();
    UiToast.show(
      context,
      title: 'Code Sent',
      message: 'Verification code sent to $email',
      intent: UiIntent.info,
    );
  }

  void _handleVerifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length < 4) {
      setState(() => _errorText = 'Please enter valid 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _currentStep = 2;
    });
  }

  void _handleResetPassword() async {
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

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _currentStep = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final responsive = context.uiRes;

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
                  children: [
                    // Compact brand row above the card.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                        label: 'Back to Sign in',
                        leadingIcon: Icons.arrow_back_rounded,
                        variant: UiVariant.ghost,
                        intent: UiIntent.neutral,
                        onPressed: widget.onBackToLogin,
                      ),
                    ),
                    SizedBox(height: context.sp(theme.spacing.md)),

                    // Step Stepper Progress — auto-switches to a vertical
                    // list on phones (handled inside UiStepper itself).
                    if (_currentStep < 3)
                      UiStepper(
                        steps: const [
                          UiStepperStep(title: 'Request', subtitle: 'Enter email'),
                          UiStepperStep(title: 'Verify', subtitle: 'Enter OTP'),
                          UiStepperStep(title: 'Reset', subtitle: 'New Password'),
                        ],
                        currentIndex: _currentStep.clamp(0, 2),
                      ),
                    if (_currentStep < 3)
                      SizedBox(height: context.sp(theme.spacing.lg)),

                    UiCard(
                      variant: UiCardVariant.surface,
                      child: Padding(
                        padding: EdgeInsets.all(context.sp(
                          responsive.isMobile ? theme.spacing.lg : theme.spacing.xl,
                        )),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_errorText != null) ...[
                              UiCallout(
                                title: 'Error',
                                message: _errorText!,
                                intent: UiIntent.danger,
                              ),
                              SizedBox(height: context.sp(theme.spacing.md)),
                            ],

                            // Step 0: Email Input Form
                            if (_currentStep == 0) ...[
                              _StepIcon(
                                icon: Icons.lock_reset_rounded,
                                intent: UiIntent.primary,
                              ),
                              SizedBox(height: context.sp(theme.spacing.md)),
                              Text(
                                'Reset your password',
                                textAlign: TextAlign.center,
                                style: context.uiText.display.copyWith(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.xxs)),
                              Text(
                                'Enter your email address and we will send you a 6-digit verification code.',
                                textAlign: TextAlign.center,
                                style: context.uiText.body.copyWith(
                                  color: colors.foregroundMuted,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.lg)),
                              UiField(
                                label: 'Registered Email',
                                required: true,
                                child: UiInput(
                                  value: _emailController.text,
                                  hintText: 'm@example.com',
                                  keyboardType: TextInputType.emailAddress,
                                  onChanged: (v) => _emailController.text = v,
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.lg)),
                              UiButton(
                                label: _isLoading
                                    ? 'Sending Code…'
                                    : 'Send Reset Code',
                                variant: UiVariant.primary,
                                intent: UiIntent.primary,
                                size: UiSize.lg,
                                onPressed: _isLoading ? null : _handleSendResetLink,
                              ),
                            ],

                            // Step 1: Verification OTP Entry
                            if (_currentStep == 1) ...[
                              _StepIcon(
                                icon: Icons.mark_email_read_outlined,
                                intent: UiIntent.info,
                              ),
                              SizedBox(height: context.sp(theme.spacing.md)),
                              Text(
                                'Enter Verification Code',
                                textAlign: TextAlign.center,
                                style: context.uiText.display.copyWith(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.xxs)),
                              Text(
                                'We sent a 6-digit code to ${_emailController.text}',
                                textAlign: TextAlign.center,
                                style: context.uiText.body.copyWith(
                                  color: colors.foregroundMuted,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.lg)),
                              UiField(
                                label: 'Verification Code',
                                required: true,
                                child: UiInput(
                                  value: _otpController.text,
                                  hintText: '849204',
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => _otpController.text = v,
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.md)),
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                runSpacing: context.sp(theme.spacing.xs),
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    _timerSeconds > 0
                                        ? 'Resend code in ${_timerSeconds}s'
                                        : "Didn't get a code?",
                                    style: context.uiText.caption.copyWith(
                                      color: colors.foregroundSubtle,
                                    ),
                                  ),
                                  if (_timerSeconds == 0)
                                    GestureDetector(
                                      onTap: _handleSendResetLink,
                                      child: Text(
                                        'Resend OTP',
                                        style: context.uiText.caption.copyWith(
                                          color: colors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: context.sp(theme.spacing.lg)),
                              UiButton(
                                label: _isLoading ? 'Verifying…' : 'Verify & Continue',
                                variant: UiVariant.primary,
                                intent: UiIntent.primary,
                                size: UiSize.lg,
                                onPressed: _isLoading ? null : _handleVerifyOtp,
                              ),
                            ],

                            // Step 2: New Password Input
                            if (_currentStep == 2) ...[
                              _StepIcon(
                                icon: Icons.password_rounded,
                                intent: UiIntent.warning,
                              ),
                              SizedBox(height: context.sp(theme.spacing.md)),
                              Text(
                                'Set New Password',
                                textAlign: TextAlign.center,
                                style: context.uiText.display.copyWith(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.xxs)),
                              Text(
                                'Must be at least 8 characters long.',
                                textAlign: TextAlign.center,
                                style: context.uiText.body.copyWith(
                                  color: colors.foregroundMuted,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.lg)),
                              UiField(
                                label: 'New Password',
                                required: true,
                                child: UiPasswordField(
                                  controller: _newPasswordController,
                                  onChanged: (v) => _newPasswordController.text = v,
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.md)),
                              UiField(
                                label: 'Confirm New Password',
                                required: true,
                                child: UiPasswordField(
                                  controller: _confirmPasswordController,
                                  onChanged: (v) => _confirmPasswordController.text = v,
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.lg)),
                              UiButton(
                                label: _isLoading
                                    ? 'Resetting Password…'
                                    : 'Update Password',
                                variant: UiVariant.primary,
                                intent: UiIntent.primary,
                                size: UiSize.lg,
                                onPressed: _isLoading ? null : _handleResetPassword,
                              ),
                            ],

                            // Step 3: Success Confirmation State
                            if (_currentStep == 3) ...[
                              _StepIcon(
                                icon: Icons.check_rounded,
                                intent: UiIntent.bullish,
                                large: true,
                              ),
                              SizedBox(height: context.sp(theme.spacing.md)),
                              Text(
                                'Password Updated!',
                                textAlign: TextAlign.center,
                                style: context.uiText.display.copyWith(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.xxs)),
                              Text(
                                'Your account password has been successfully updated. You can now login with your new credentials.',
                                textAlign: TextAlign.center,
                                style: context.uiText.body.copyWith(
                                  color: colors.foregroundMuted,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.xl)),
                              UiButton(
                                label: 'Sign In Now',
                                variant: UiVariant.primary,
                                intent: UiIntent.primary,
                                size: UiSize.lg,
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
                      children: [
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

/// Small circular icon lockup used at the top of each step's card.
class _StepIcon extends StatelessWidget {
  const _StepIcon({
    required this.icon,
    required this.intent,
    this.large = false,
  });

  final IconData icon;
  final UiIntent intent;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final Color tint = switch (intent) {
      UiIntent.bullish => colors.bullish,
      UiIntent.warning => colors.warning,
      UiIntent.info => colors.info,
      UiIntent.danger => colors.destructive,
      _ => colors.primary,
    };
    final double dim = context.sz(large ? 56 : 44);

    return Center(
      child: Container(
        width: dim,
        height: dim,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tint.withValues(alpha: 0.12),
          border: Border.all(color: tint.withValues(alpha: 0.24)),
        ),
        child: Icon(icon, color: tint, size: context.sz(large ? 26 : 20)),
      ),
    );
  }
}
