import 'package:alphajournal/features/affiliate_program/data/affiliate_attribution.dart';
import 'package:alphajournal/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alphajournal/core/config/app_constants.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/auth/data/repositories/auth_repository.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/auth/widgets/auth_carousel_panel.dart';
import 'package:alphajournal/features/auth/widgets/role_selector_tab.dart';
import 'package:alphajournal/features/settings/presentation/widgets/help/publication_reader.dart';

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
  bool _hasReferralCode = false;
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
    _loadSavedReferralCode();
  }

  Future<void> _loadSavedReferralCode() async {
    try {
      final attribution = await AffiliateAttribution.load();
      final code = attribution?['code']?.toString().trim() ?? '';
      if (!mounted || code.isEmpty) return;
      setState(() {
        _referralCodeController.text = code.toUpperCase();
        if (_selectedRole == UserRole.customer) {
          _hasReferralCode = true;
        }
      });
    } catch (_) {}
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

    final attribution = _selectedRole == UserRole.customer
        ? await AffiliateAttribution.load()
        : null;
    final String? effectiveReferralCode = _selectedRole == UserRole.customer &&
            _hasReferralCode
        ? (_referralCodeController.text.trim().isNotEmpty
              ? _referralCodeController.text.trim().toUpperCase()
              : attribution?['code'] as String?)
        : null;
    final result = await _repository.signUp(
      role: _selectedRole,
      handle: handlerId,
      email: email,
      password: password,
      referralCode: effectiveReferralCode,
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
      body: AlphaThreadBackdrop.auth(
        phase: 83.1,
        child: SafeArea(
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
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
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
                              RepaintBoundary(
                                child: UiCard(
                                  variant: UiCardVariant.surface,
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Left Form Column (Full width on mobile, 50% on desktop)
                                        Expanded(
                                          child: RepaintBoundary(
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
                                                        onPressed: widget
                                                            .onNavigateBack,
                                                      ),
                                                      SizedBox(
                                                        width: context.sp(
                                                          theme.spacing.xs,
                                                        ),
                                                      ),
                                                      const AppLogoMark(
                                                        size: 20,
                                                      ),
                                                      if (!responsive
                                                          .isMobile) ...[
                                                        SizedBox(
                                                          width: context.sp(
                                                            theme.spacing.xs,
                                                          ),
                                                        ),
                                                        Text(
                                                          'AlphaJournal',
                                                          style: context
                                                              .uiText
                                                              .bodyStrong
                                                              .copyWith(
                                                                fontSize: 16,
                                                                letterSpacing:
                                                                    -0.2,
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
                                                    style: context
                                                        .uiText
                                                        .display
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
                                                      _handlerIdController
                                                              .text =
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
                                                  keyboardType: TextInputType
                                                      .emailAddress,
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
                                                        label:
                                                            'Confirm Password',
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
                                                      color: colors
                                                          .foregroundSubtle,
                                                      fontSize: 11.5,
                                                    ),
                                              ),
                                              SizedBox(
                                                height: context.sp(
                                                  theme.spacing.md,
                                                ),
                                              ),

                                              // Referral code prompt for Customers; prohibited for Affiliates
                                              if (_selectedRole ==
                                                  UserRole.customer) ...[
                                                Text(
                                                  'Do you have a referral code?',
                                                  style: context
                                                      .uiText
                                                      .bodyStrong
                                                      .copyWith(fontSize: 13),
                                                ),
                                                SizedBox(
                                                  height: context.sp(
                                                    theme.spacing.xs,
                                                  ),
                                                ),
                                                Row(
                                                  key: const ValueKey<String>(
                                                    'signup-has-referral-toggle',
                                                  ),
                                                  children: <Widget>[
                                                    Expanded(
                                                      child: UiButton(
                                                        label: 'No',
                                                        size: UiSize.sm,
                                                        expand: true,
                                                        variant:
                                                            !_hasReferralCode
                                                            ? UiVariant.soft
                                                            : UiVariant.outline,
                                                        intent:
                                                            !_hasReferralCode
                                                            ? UiIntent.primary
                                                            : UiIntent.neutral,
                                                        onPressed: () =>
                                                            setState(
                                                              () =>
                                                                  _hasReferralCode =
                                                                      false,
                                                            ),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: context.sp(
                                                        theme.spacing.xs,
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: UiButton(
                                                        label:
                                                            'Yes, I have one',
                                                        size: UiSize.sm,
                                                        expand: true,
                                                        variant:
                                                            _hasReferralCode
                                                            ? UiVariant.soft
                                                            : UiVariant.outline,
                                                        intent: _hasReferralCode
                                                            ? UiIntent.primary
                                                            : UiIntent.neutral,
                                                        onPressed: () =>
                                                            setState(
                                                              () =>
                                                                  _hasReferralCode =
                                                                      true,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (_hasReferralCode) ...[
                                                  SizedBox(
                                                    height: context.sp(
                                                      theme.spacing.sm,
                                                    ),
                                                  ),
                                                  UiField(
                                                    label:
                                                        'Referral Code (Optional)',
                                                    helper:
                                                        'Get Month 1 at ₹239 (Basic) or ₹399 (Pro) on monthly plans, then regular ₹299/₹499 renewal · 1 per account.',
                                                    child: UiInput(
                                                      key:
                                                          const ValueKey<
                                                            String
                                                          >(
                                                            'signup-referral-input',
                                                          ),
                                                      controller:
                                                          _referralCodeController,
                                                      hintText: 'PARTNER26',
                                                    ),
                                                  ),
                                                ],
                                                SizedBox(
                                                  height: context.sp(
                                                    theme.spacing.md,
                                                  ),
                                                ),
                                              ] else if (_selectedRole ==
                                                  UserRole.affiliate) ...[
                                                const UiCallout(
                                                  title:
                                                      'Affiliate Program Terms (Rev 2026.2-INR)',
                                                  message:
                                                      'Affiliate accounts cannot redeem their own or other partners\' referral/coupon codes. Complimentary Pro unlocks only after 50 referred users pay for Basic or Pro.',
                                                  intent: UiIntent.info,
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
                                                intent:
                                                    _selectedRole.badgeIntent,
                                                size: UiSize.lg,
                                                expand: true,
                                                onPressed:
                                                    (_isLoading ||
                                                        !_isSignupOpen)
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
                                                      _showSocialToast(
                                                        'Google',
                                                      ),
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
                                                    onTap: () => widget
                                                        .onNavigateToLogin(
                                                          _selectedRole,
                                                        ),
                                                    child: Text(
                                                      'Sign in',
                                                      style: context
                                                          .uiText
                                                          .bodyStrong
                                                          .copyWith(
                                                            color:
                                                                colors.primary,
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
                                      ),

                                      // Right Visual Window Column — desktop only.
                                      if (showSidePanel)
                                        Expanded(
                                          child: RepaintBoundary(
                                            child: SizedBox(
                                              height:
                                                  640, // Provide tight height for IntrinsicHeight
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    left: BorderSide(
                                                      color: colors.border,
                                                      width: theme
                                                          .borders
                                                          .hairline,
                                                    ),
                                                  ),
                                                ),
                                                child:
                                                    const AuthCarouselPanel(),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
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
                                        alignment: PlaceholderAlignment.middle,
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => PublicationReader.open(
                                              context,
                                              'terms',
                                            ),
                                            child: Text(
                                              'Terms of Service',
                                              style: context.uiText.caption
                                                  .copyWith(
                                                    color: colors.primary,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 11.5,
                                                    decoration: TextDecoration
                                                        .underline,
                                                    decorationColor: colors
                                                        .primary
                                                        .withValues(alpha: 0.5),
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const TextSpan(text: ' and '),
                                      WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => PublicationReader.open(
                                              context,
                                              'privacy',
                                            ),
                                            child: Text(
                                              'Privacy Policy',
                                              style: context.uiText.caption
                                                  .copyWith(
                                                    color: colors.primary,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 11.5,
                                                    decoration: TextDecoration
                                                        .underline,
                                                    decorationColor: colors
                                                        .primary
                                                        .withValues(alpha: 0.5),
                                                  ),
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
            : AppConstants.nativeAuthCallbackUrl,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.inAppBrowserView,
        queryParams: const <String, String>{'prompt': 'select_account'},
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
}
