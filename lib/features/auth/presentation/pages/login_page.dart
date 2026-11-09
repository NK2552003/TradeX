import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/data/repositories/auth_repository.dart';
import 'package:tradex/features/auth/data/services/auth_backend_service.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/widgets/auth_carousel_panel.dart';
import 'package:tradex/features/auth/widgets/role_selector_tab.dart';
import 'package:tradex/features/settings/presentation/widgets/help/publication_reader.dart';

/// Responsive Login Page — split card on desktop, single column on mobile.
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.initialRole = UserRole.customer,
    this.authRepository,
    this.notice,
    required this.onLoginSuccess,
    required this.onNavigateToSignup,
    required this.onNavigateToForgotPassword,
    required this.onNavigateBack,
  });

  final UserRole initialRole;
  final AuthRepository? authRepository;

  /// Optional context banner (e.g. "Sign in to view this post").
  final String? notice;
  final void Function(UserRole role, String email) onLoginSuccess;
  final void Function(UserRole role) onNavigateToSignup;
  final VoidCallback onNavigateToForgotPassword;
  final VoidCallback onNavigateBack;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late UserRole _selectedRole;
  late final AuthRepository _repository;
  final TextEditingController _emailController = TextEditingController(
    text: '',
  );
  final TextEditingController _passwordController = TextEditingController(
    text: '',
  );
  final TextEditingController _adminKeyController = TextEditingController(
    text: '',
  );

  bool _isLoading = false;
  bool _isSignupOpen = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
    _repository = widget.authRepository ?? AuthBackendService.instance;
    _checkSignupCapacity();
  }

  Future<void> _checkSignupCapacity() async {
    final open = await _repository.isSignupOpen();
    if (mounted) {
      setState(() => _isSignupOpen = open);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _adminKeyController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(
        () => _errorText = 'Please enter a valid email address or Handler ID',
      );
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorText = 'Please enter your password');
      return;
    }

    if (_selectedRole == UserRole.userAdmin &&
        _adminKeyController.text.trim().isEmpty) {
      setState(
        () => _errorText =
            'Admin Security Clearance Key is required for User Admin sign in.',
      );
      return;
    }

    setState(() {
      _errorText = null;
      _isLoading = true;
    });

    final result = await _repository.signIn(
      role: _selectedRole,
      emailOrHandle: email,
      password: password,
      adminKey: _selectedRole == UserRole.userAdmin
          ? _adminKeyController.text.trim()
          : null,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (!result.isSuccess) {
      setState(() => _errorText = result.message);
      return;
    }

    UiToast.show(
      context,
      title: 'Login Successful',
      message: result.message,
      intent: UiIntent.success,
    );

    final UserRole verifiedRole =
        result.profile?.role ??
        (_selectedRole == UserRole.userAdmin
            ? UserRole.customer
            : _selectedRole);

    widget.onLoginSuccess(verifiedRole, result.profile?.email ?? email);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final responsive = context.uiRes;

    // A true desktop viewport, not merely "not mobile" — this keeps the
    // split layout from squeezing onto tablet-width screens.
    final bool showSidePanel = responsive.width >= 900;
    final double maxWidth = showSidePanel ? context.sz(940) : context.sz(440);

    return Scaffold(
      backgroundColor: colors.background,
      body: AlphaThreadBackdrop(
        allSides: true,
        phase: 12.7,
        thickness: 64,
        desktopHeight: 320,
        mobileHeight: 200,
        opacity: 0.5,
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
                              if (widget.notice != null) ...[
                                UiCallout(
                                  title: 'Sign in required',
                                  message: widget.notice,
                                  intent: UiIntent.info,
                                  icon: Icons.lock_outline_rounded,
                                ),
                                SizedBox(height: context.sp(theme.spacing.md)),
                              ],
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
                                                    roles: <UserRole>[
                                                      UserRole.customer,
                                                      UserRole.affiliate,
                                                      if (widget.initialRole ==
                                                              UserRole
                                                                  .userAdmin ||
                                                          _selectedRole ==
                                                              UserRole
                                                                  .userAdmin)
                                                        UserRole.userAdmin,
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

                                              // Header Title & Description
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Welcome back',
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
                                                    'Login to your alphajournal account',
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
                                                  title: 'Authentication Error',
                                                  message: _errorText!,
                                                  intent: UiIntent.danger,
                                                ),
                                                SizedBox(
                                                  height: context.sp(
                                                    theme.spacing.md,
                                                  ),
                                                ),
                                              ],

                                              // Email or Handler ID Field
                                              UiField(
                                                label: 'Email or Handler ID',
                                                required: true,
                                                child: UiInput(
                                                  value: _emailController.text,
                                                  hintText:
                                                      'm@example.com or @username',
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

                                              // Password Field with "Forgot password?" Link Header
                                              UiField(
                                                label: 'Password',
                                                required: true,
                                                headerAction: MouseRegion(
                                                  cursor:
                                                      SystemMouseCursors.click,
                                                  child: GestureDetector(
                                                    behavior:
                                                        HitTestBehavior.opaque,
                                                    onTap: widget
                                                        .onNavigateToForgotPassword,
                                                    child: Text(
                                                      responsive.isMobile
                                                          ? 'Forgot?'
                                                          : 'Forgot your password?',
                                                      style: context
                                                          .uiText
                                                          .caption
                                                          .copyWith(
                                                            color:
                                                                colors.primary,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                child: UiPasswordField(
                                                  controller:
                                                      _passwordController,
                                                  showStrength: false,
                                                ),
                                              ),
                                              SizedBox(
                                                height: context.sp(
                                                  theme.spacing.md,
                                                ),
                                              ),

                                              // Extra role specific security field for User Admin
                                              if (_selectedRole ==
                                                  UserRole.userAdmin) ...[
                                                UiField(
                                                  label:
                                                      'Admin Security Clearance Key',
                                                  required: true,
                                                  helper:
                                                      'Required for administrative operations',
                                                  child: UiInput(
                                                    value: _adminKeyController
                                                        .text,
                                                    hintText: 'ADM-XXXX-KEY',
                                                    onChanged: (v) =>
                                                        _adminKeyController
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

                                              // Submit Button
                                              UiButton(
                                                label: _isLoading
                                                    ? 'Logging in…'
                                                    : 'Login',
                                                variant: UiVariant.primary,
                                                intent:
                                                    _selectedRole.badgeIntent,
                                                size: UiSize.lg,
                                                expand: true,
                                                onPressed: _isLoading
                                                    ? null
                                                    : _handleSubmit,
                                              ),
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
                                                label: 'Sign in with Google',
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
                                              SizedBox(
                                                height: context.sp(
                                                  theme.spacing.lg,
                                                ),
                                              ),

                                              // Switch to Signup Link (hidden/disabled once 100-user cap is reached)
                                              if (_isSignupOpen)
                                                Wrap(
                                                  alignment:
                                                      WrapAlignment.center,
                                                  children: [
                                                    Text(
                                                      "Don't have an account? ",
                                                      style: context.uiText.body
                                                          .copyWith(
                                                            color: colors
                                                                .foregroundMuted,
                                                            fontSize: 13,
                                                          ),
                                                    ),
                                                    GestureDetector(
                                                      onTap: () => widget
                                                          .onNavigateToSignup(
                                                            _selectedRole,
                                                          ),
                                                      child: Text(
                                                        'Sign up',
                                                        style: context
                                                            .uiText
                                                            .bodyStrong
                                                            .copyWith(
                                                              color: colors
                                                                  .primary,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 13,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              else
                                                UiCallout(
                                                  title: 'Registration Closed',
                                                  message:
                                                      'Maximum capacity of ${AuthRepository.maxRegisteredUsersCap} active users reached. Only existing registered users can sign in.',
                                                  intent: UiIntent.warning,
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
                                                    width:
                                                        theme.borders.hairline,
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
                                                    decoration: TextDecoration.underline,
                                                    decorationColor: colors.primary.withValues(alpha: 0.5),
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
                                                    decoration: TextDecoration.underline,
                                                    decorationColor: colors.primary.withValues(alpha: 0.5),
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
        redirectTo: kIsWeb ? Uri.base.origin : 'tradex://auth/callback',
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
