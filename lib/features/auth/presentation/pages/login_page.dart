import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/widgets/auth_background.dart';
import 'package:tradex/features/auth/widgets/auth_carousel_panel.dart';
import 'package:tradex/features/auth/widgets/role_selector_tab.dart';
import 'package:tradex/features/auth/widgets/social_auth_buttons.dart';

/// Responsive Login Page — split card on desktop, single column on mobile.
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.initialRole = UserRole.customer,
    required this.onLoginSuccess,
    required this.onNavigateToSignup,
    required this.onNavigateToForgotPassword,
  });

  final UserRole initialRole;
  final void Function(UserRole role, String email) onLoginSuccess;
  final void Function(UserRole role) onNavigateToSignup;
  final VoidCallback onNavigateToForgotPassword;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late UserRole _selectedRole;
  final TextEditingController _emailController =
      TextEditingController(text: '');
  final TextEditingController _passwordController =
      TextEditingController(text: '');
  final TextEditingController _adminKeyController =
      TextEditingController(text: '');

  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
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
      setState(() => _errorText = 'Please enter a valid email address or Handler ID');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorText = 'Please enter your password');
      return;
    }

    setState(() {
      _errorText = null;
      _isLoading = true;
    });

    // Simulate network authentication request
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    setState(() => _isLoading = false);

    UiToast.show(
      context,
      title: 'Login Successful',
      message: 'Logged in successfully as ${_selectedRole.label}',
      intent: UiIntent.success,
    );

    widget.onLoginSuccess(_selectedRole, email);
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
      body: AuthBackground(
        child: SafeArea(
          child: Center(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.md),
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left Form Column (Full width on mobile, 50% on desktop)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.all(
                                  context.sp(responsive.isMobile
                                      ? theme.spacing.lg
                                      : theme.spacing.xl),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Header with Logo and Role Selector
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const AppLogoMark(size: 20),
                                            SizedBox(width: context.sp(theme.spacing.xs)),
                                            Text(
                                              'TradeX',
                                              style: context.uiText.bodyStrong.copyWith(
                                                fontSize: 16,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                        RoleSelectorTab(
                                          selectedRole: _selectedRole,
                                          onRoleChanged: (role) =>
                                              setState(() => _selectedRole = role),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: context.sp(theme.spacing.xl)),
                                    
                                    // Header Title & Description
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Welcome back',
                                          textAlign: TextAlign.left,
                                          style: context.uiText.display.copyWith(
                                            fontSize: 28.0,
                                            fontWeight: FontWeight.w400,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        SizedBox(height: context.sp(theme.spacing.xxs)),
                                        Text(
                                          'Login to your TradeX account',
                                          textAlign: TextAlign.left,
                                          style: context.uiText.body.copyWith(
                                            color: colors.foregroundMuted,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: context.sp(theme.spacing.lg)),

                                    if (_errorText != null) ...[
                                      UiCallout(
                                        title: 'Authentication Error',
                                        message: _errorText!,
                                        intent: UiIntent.danger,
                                      ),
                                      SizedBox(height: context.sp(theme.spacing.md)),
                                    ],

                                    // Email or Handler ID Field
                                    UiField(
                                      label: 'Email or Handler ID',
                                      required: true,
                                      child: UiInput(
                                        value: _emailController.text,
                                        hintText: 'm@example.com or @username',
                                        keyboardType: TextInputType.emailAddress,
                                        onChanged: (v) => _emailController.text = v,
                                      ),
                                    ),
                                    SizedBox(height: context.sp(theme.spacing.md)),

                                    // Password Field with "Forgot password?" Link Header
                                    UiField(
                                      label: 'Password',
                                      required: true,
                                      headerAction: GestureDetector(
                                        onTap: widget.onNavigateToForgotPassword,
                                        child: Text(
                                          'Forgot your password?',
                                          style: context.uiText.caption.copyWith(
                                            color: colors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      child: UiPasswordField(
                                        controller: _passwordController,
                                        onChanged: (v) => _passwordController.text = v,
                                      ),
                                    ),
                                    SizedBox(height: context.sp(theme.spacing.md)),

                                    // Extra role specific security field for User Admin
                                    if (_selectedRole == UserRole.userAdmin) ...[
                                      UiField(
                                        label: 'Admin Security Clearance Key',
                                        required: true,
                                        helper: 'Required for administrative operations',
                                        child: UiInput(
                                          value: _adminKeyController.text,
                                          hintText: 'ADM-XXXX-KEY',
                                          onChanged: (v) =>
                                              _adminKeyController.text = v,
                                        ),
                                      ),
                                      SizedBox(height: context.sp(theme.spacing.md)),
                                    ],

                                    // Submit Button
                                    UiButton(
                                      label: _isLoading ? 'Logging in…' : 'Login',
                                      variant: UiVariant.primary,
                                      intent: _selectedRole.badgeIntent,
                                      size: UiSize.lg,
                                      onPressed: _isLoading ? null : _handleSubmit,
                                    ),
                                    SizedBox(height: context.sp(theme.spacing.lg)),

                                    // Divider
                                    const UiDivider(label: 'Or continue with'),
                                    SizedBox(height: context.sp(theme.spacing.md)),

                                    // Social Authentication Buttons Grid
                                    const SocialAuthButtons(
                                      actionLabelPrefix: 'Login with',
                                    ),
                                    SizedBox(height: context.sp(theme.spacing.lg)),

                                    // Switch to Signup Link
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      children: [
                                        Text(
                                          "Don't have an account? ",
                                          style: context.uiText.body.copyWith(
                                            color: colors.foregroundMuted,
                                            fontSize: 13,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () =>
                                              widget.onNavigateToSignup(_selectedRole),
                                          child: Text(
                                            'Sign up',
                                            style: context.uiText.bodyStrong.copyWith(
                                              color: colors.primary,
                                              fontWeight: FontWeight.bold,
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
                                  height: 520, // Provide tight height for IntrinsicHeight
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
                        horizontal: context.sp(theme.spacing.md),
                      ),
                      child: Text.rich(
                        TextSpan(
                          text: 'By clicking continue, you agree to our ',
                          style: context.uiText.caption.copyWith(
                            color: colors.foregroundSubtle,
                            fontSize: 11.5,
                          ),
                          children: [
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () => _showPolicyDialog(context, 'Terms of Service'),
                                child: Text(
                                  'Terms of Service',
                                  style: context.uiText.caption.copyWith(
                                    color: colors.foregroundMuted,
                                    decoration: TextDecoration.underline,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () => _showPolicyDialog(context, 'Privacy Policy'),
                                child: Text(
                                  'Privacy Policy',
                                  style: context.uiText.caption.copyWith(
                                    color: colors.foregroundMuted,
                                    decoration: TextDecoration.underline,
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
      ),
    );
  }

  void _showPolicyDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) => UiDialog(
        title: title,
        content: Text(
          'TraderHub TradeX compliance, security, privacy policy, and user service agreement rules apply.',
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
