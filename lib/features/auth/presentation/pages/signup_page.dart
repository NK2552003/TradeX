import 'package:tradex/features/affiliate_program/data/affiliate_attribution.dart';
import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/data/repositories/auth_repository.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/widgets/auth_carousel_panel.dart';
import 'package:tradex/features/auth/widgets/role_selector_tab.dart';

/// Responsive Signup Page — split card on desktop, single column on mobile.
class SignupPage extends StatefulWidget {
  const SignupPage({
    super.key,
    this.initialRole = UserRole.customer,
    this.authRepository,
    required this.onSignupSuccess,
    required this.onNavigateToLogin,
    required this.onNavigateBack,
  });

  final UserRole initialRole;
  final AuthRepository? authRepository;
  final void Function(UserRole role, String email, {bool requiresVerification})
  onSignupSuccess;
  final void Function(UserRole role) onNavigateToLogin;
  final VoidCallback onNavigateBack;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  late UserRole _selectedRole;
  late final AuthRepository _repository;
  final TextEditingController _handlerIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();

  bool _isLoading = false;
  bool _isSignupOpen = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    // Admin accounts are provisioned privately and can only use sign-in.
    _selectedRole = widget.initialRole == UserRole.userAdmin
        ? UserRole.customer
        : widget.initialRole;
    _repository = widget.authRepository ?? SupabaseAuthBackendService.instance;
    _checkSignupCapacity();
  }

  Future<void> _checkSignupCapacity() async {
    final open = await _repository.isSignupOpen();
    if (!mounted) return;
    setState(() {
      _isSignupOpen = open;
      if (!open) {
        _errorText =
            'Platform capacity reached (${AuthRepository.maxRegisteredUsersCap} users). New user registration is currently disabled.';
      }
    });
  }

  @override
  void dispose() {
    _handlerIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    if (!_isSignupOpen) {
      setState(
        () => _errorText =
            'Platform capacity reached (${AuthRepository.maxRegisteredUsersCap} users). New user registration is currently disabled.',
      );
      return;
    }
    final handlerId = _handlerIdController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (handlerId.isEmpty) {
      setState(() => _errorText = 'Please enter a valid Handler ID');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorText = 'Please enter a valid email address');
      return;
    }
    if (password.length < 8) {
      setState(
        () => _errorText = 'Password must be at least 8 characters long',
      );
      return;
    }
    if (password != confirmPassword) {
      setState(() => _errorText = 'Passwords do not match');
      return;
    }

    setState(() {
      _errorText = null;
      _isLoading = true;
    });

    final attribution = await AffiliateAttribution.load();
    final result = await _repository.signUp(
      role: _selectedRole,
      handle: handlerId,
      email: email,
      password: password,
      referralCode: _referralCodeController.text.trim().isNotEmpty
          ? _referralCodeController.text.trim()
          : attribution?['code'] as String?,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (!result.isSuccess) {
      setState(() => _errorText = result.message);
      return;
    }

    UiToast.show(
      context,
      title: 'Registration Successful',
      message: result.message,
      intent: UiIntent.success,
    );

    widget.onSignupSuccess(
      _selectedRole,
      email,
      requiresVerification: result.requiresEmailVerification,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final responsive = context.uiRes;

    // A true desktop viewport drives both the side panel and the
    // two-column password layout, so tablets get a clean single column.
    final bool showSidePanel = responsive.width >= 900;
    final double maxWidth = showSidePanel ? context.sz(960) : context.sz(440);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: constraints.maxWidth < 360
                            ? context.sp(theme.spacing.sm)
                            : context.sp(theme.spacing.md),
                        vertical: context.sp(theme.spacing.xl),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Main Card Container with split grid layout
                            UiCard(
                              variant: UiCardVariant.surface,
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Left Form Column (Full width on mobile, 50% on desktop)
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.all(
                                          context.sp(
                                            constraints.maxWidth < 360
                                                ? theme.spacing.md
                                                : (responsive.isMobile
                                                    ? theme.spacing.lg
                                                    : theme.spacing.xl),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Header with Back Button, Logo and Role Selector
                                            Wrap(
                                              alignment:
                                                  WrapAlignment.spaceBetween,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              spacing: context.sp(
                                                theme.spacing.sm,
                                              ),
                                              runSpacing: context.sp(
                                                theme.spacing.sm,
                                              ),
                                              children: [
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    UiIconButton(
                                                      icon: Icons
                                                          .arrow_back_rounded,
                                                      tooltip: 'Back',
                                                      size: UiSize.sm,
                                                      onPressed:
                                                          widget.onNavigateBack,
                                                    ),
                                                    SizedBox(
                                                      width: context.sp(
                                                        theme.spacing.xs,
                                                      ),
                                                    ),
                                                    const AppLogoMark(size: 20),
                                                    if (!responsive.isMobile) ...[
                                                      SizedBox(
                                                        width: context.sp(
                                                          theme.spacing.xs,
                                                        ),
                                                      ),
                                                      Text(
                                                        'alphajournal',
                                                        style: context
                                                            .uiText
                                                            .bodyStrong
                                                            .copyWith(
                                                              fontSize: 16,
                                                              letterSpacing: -0.2,
                                                            ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                RoleSelectorTab(
                                                  selectedRole: _selectedRole,
                                                  roles: const <UserRole>[
                                                    UserRole.customer,
                                                    UserRole.affiliate,
                                                  ],
                                                  onRoleChanged: (role) =>
                                                      setState(
                                                        () => _selectedRole =
                                                            role,
                                                      ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(
                                              height: context.sp(
                                                theme.spacing.xl,
                                              ),
                                            ),

                                            // Header Title & Subtitle
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Create your account',
                                                  textAlign: TextAlign.left,
                                                  style: context.uiText.display
                                                      .copyWith(
                                                        fontSize: 28.0,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        letterSpacing: -0.5,
                                                      ),
                                                ),
                                                SizedBox(
                                                  height: context.sp(
                                                    theme.spacing.xxs,
                                                  ),
                                                ),
                                                Text(
                                                  'Enter your email below to create your account',
                                                  textAlign: TextAlign.left,
                                                  style: context.uiText.body
                                                      .copyWith(
                                                        color: colors
                                                            .foregroundMuted,
                                                        fontSize: 13.5,
                                                      ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(
                                              height: context.sp(
                                                theme.spacing.lg,
                                              ),
                                            ),

                                            if (_errorText != null) ...[
                                              UiCallout(
                                                title: 'Registration Error',
                                                message: _errorText!,
                                                intent: UiIntent.danger,
                                              ),
                                              SizedBox(
                                                height: context.sp(
                                                  theme.spacing.md,
                                                ),
                                              ),
                                            ],

                                            // Handler ID Field
                                            UiField(
                                              label: 'Handler ID',
                                              required: true,
                                              child: UiInput(
                                                value:
                                                    _handlerIdController.text,
                                                hintText: '@username',
                                                leadingIcon: Icons
                                                    .alternate_email_rounded,
                                                onChanged: (v) =>
                                                    _handlerIdController.text =
                                                        v,
                                              ),
                                            ),
                                            SizedBox(
                                              height: context.sp(
                                                theme.spacing.md,
                                              ),
                                            ),

                                            // Email Field with Description
                                            UiField(
                                              label: 'Email',
                                              required: true,
                                              helper:
                                                  "We'll use this to contact you. We will not share your email with anyone else.",
                                              child: UiInput(
                                                value: _emailController.text,
                                                hintText: 'm@example.com',
                                                keyboardType:
                                                    TextInputType.emailAddress,
                                                onChanged: (v) =>
                                                    _emailController.text = v,
                                              ),
                                            ),
                                            SizedBox(
                                              height: context.sp(
                                                theme.spacing.md,
                                              ),
                                            ),

                                            // Password & Confirm Password (2-column layout on desktop)
                                            if (showSidePanel)
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: UiField(
                                                      label: 'Password',
                                                      required: true,
                                                      child: UiPasswordField(
                                                        controller:
                                                            _passwordController,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: context.sp(
                                                      theme.spacing.md,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: UiField(
                                                      label: 'Confirm Password',
                                                      required: true,
                                                      child: UiPasswordField(
                                                        controller:
                                                            _confirmPasswordController,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            else ...[
                                              UiField(
                                                label: 'Password',
                                                required: true,
                                                child: UiPasswordField(
                                                  controller:
                                                      _passwordController,
                                                ),
                                              ),
                                              SizedBox(
                                                height: context.sp(
                                                  theme.spacing.md,
                                                ),
                                              ),
                                              UiField(
                                                label: 'Confirm Password',
                                                required: true,
                                                child: UiPasswordField(
                                                  controller:
                                                      _confirmPasswordController,
                                                ),
                                              ),
                                            ],
                                            SizedBox(
                                              height: context.sp(
                                                theme.spacing.xxs,
                                              ),
                                            ),
                                            Text(
                                              'Must be at least 8 characters long.',
                                              style: context.uiText.caption
                                                  .copyWith(
                                                    color:
                                                        colors.foregroundSubtle,
                                                    fontSize: 11.5,
                                                  ),
                                            ),
                                            SizedBox(
                                              height: context.sp(
                                                theme.spacing.md,
                                              ),
                                            ),

                                            // Role Specific Optional/Required Inputs
                                            if (_selectedRole ==
                                                UserRole.affiliate) ...[
                                              UiField(
                                                label:
                                                    'Partner Referral Code (Optional)',
                                                // No figure here: nothing in the
                                                // app pays a signing bonus, so
                                                // quoting one would promise money
                                                // the payouts ledger never shows.
                                                helper:
                                                    'Credits your signup to the partner who referred you',
                                                child: UiInput(
                                                  value: _referralCodeController
                                                      .text,
                                                  hintText: 'REF-TRADEX-2026',
                                                  onChanged: (v) =>
                                                      _referralCodeController
                                                              .text =
                                                          v,
                                                ),
                                              ),
                                              SizedBox(
                                                height: context.sp(
                                                  theme.spacing.md,
                                                ),
                                              ),
                                            ],

                                            // Create Account Submit Button
                                            UiButton(
                                              label: !_isSignupOpen
                                                  ? 'Registration Closed (100/100 Full)'
                                                  : (_isLoading
                                                        ? 'Creating Account…'
                                                        : 'Create Account'),
                                              variant: UiVariant.primary,
                                              intent: _selectedRole.badgeIntent,
                                              size: UiSize.lg,
                                              expand: true,
                                              onPressed:
                                                  (_isLoading || !_isSignupOpen)
                                                  ? null
                                                  : _handleSubmit,
                                            ),
                                            if (_isSignupOpen) ...[
                                              SizedBox(
                                                height: context.sp(
                                                  theme.spacing.lg,
                                                ),
                                              ),

                                              // Divider
                                              const UiDivider(
                                                label: 'Or continue with',
                                              ),
                                              SizedBox(
                                                height: context.sp(
                                                  theme.spacing.md,
                                                ),
                                              ),

                                              // Social Authentication Buttons Grid
                                              UiButton(
                                                label: 'Sign up with Google',
                                                variant: UiVariant.outline,
                                                intent: UiIntent.neutral,
                                                size: UiSize.lg,
                                                expand: true,
                                                leading: const GoogleLogoMark(
                                                  size: 20,
                                                ),
                                                onPressed: () =>
                                                    _showSocialToast('Google'),
                                              ),
                                            ],
                                            SizedBox(
                                              height: context.sp(
                                                theme.spacing.lg,
                                              ),
                                            ),

                                            // Switch to Sign in Link
                                            Wrap(
                                              alignment: WrapAlignment.center,
                                              children: [
                                                Text(
                                                  'Already have an account? ',
                                                  style: context.uiText.body
                                                      .copyWith(
                                                        color: colors
                                                            .foregroundMuted,
                                                        fontSize: 13,
                                                      ),
                                                ),
                                                GestureDetector(
                                                  onTap: () =>
                                                      widget.onNavigateToLogin(
                                                        _selectedRole,
                                                      ),
                                                  child: Text(
                                                    'Sign in',
                                                    style: context
                                                        .uiText
                                                        .bodyStrong
                                                        .copyWith(
                                                          color: colors.primary,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Right Visual Window Column — desktop only.
                                    if (showSidePanel)
                                      Expanded(
                                        child: SizedBox(
                                          height:
                                              640, // Provide tight height for IntrinsicHeight
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border(
                                                left: BorderSide(
                                                  color: colors.border,
                                                  width: theme.borders.hairline,
                                                ),
                                              ),
                                            ),
                                            child: const AuthCarouselPanel(),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: context.sp(theme.spacing.md)),

                            // Terms of Service & Privacy Policy Footer
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: constraints.maxWidth < 360
                                    ? context.sp(theme.spacing.sm)
                                    : context.sp(theme.spacing.md),
                              ),
                              child: Text.rich(
                                TextSpan(
                                  text:
                                      'By clicking continue, you agree to our ',
                                  style: context.uiText.caption.copyWith(
                                    color: colors.foregroundSubtle,
                                    fontSize: 11.5,
                                  ),
                                  children: [
                                    WidgetSpan(
                                      child: GestureDetector(
                                        onTap: () => _showPolicyDialog(
                                          context,
                                          'Terms of Service',
                                        ),
                                        child: Text(
                                          'Terms of Service',
                                          style: context.uiText.caption
                                              .copyWith(
                                                color: colors.primary,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 11.5,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const TextSpan(text: ' and '),
                                    WidgetSpan(
                                      child: GestureDetector(
                                        onTap: () => _showPolicyDialog(
                                          context,
                                          'Privacy Policy',
                                        ),
                                        child: Text(
                                          'Privacy Policy',
                                          style: context.uiText.caption
                                              .copyWith(
                                                color: colors.primary,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 11.5,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const TextSpan(text: '.'),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Future<void> _showSocialToast(String provider) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final client = SupabaseConfig.client;
      if (!SupabaseConfig.isConfigured || client == null) {
        throw StateError(
          'Google sign-in is unavailable in this environment. Use email sign-in.',
        );
      }
      final launched = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? Uri.base.origin
            : 'tradex://auth/callback',
      );
      if (!launched) {
        throw StateError('Could not open Google sign-in. Please retry.');
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorText = error is AuthException
              ? error.message
              : error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPolicyDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) => UiDialog(
        title: title,
        content: Text(
          'alphajournal terms, customer privacy protection, and financial regulatory rules.',
          style: context.uiText.body,
        ),
        actions: [
          UiButton(
            label: 'Close',
            variant: UiVariant.primary,
            intent: UiIntent.primary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
