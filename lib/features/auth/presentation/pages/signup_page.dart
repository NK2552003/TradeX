import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/widgets/auth_background.dart';
import 'package:tradex/features/auth/widgets/auth_carousel_panel.dart';
import 'package:tradex/features/auth/widgets/role_selector_tab.dart';
import 'package:tradex/features/auth/widgets/social_auth_buttons.dart';

/// Responsive Signup Page — split card on desktop, single column on mobile.
class SignupPage extends StatefulWidget {
  const SignupPage({
    super.key,
    this.initialRole = UserRole.customer,
    required this.onSignupSuccess,
    required this.onNavigateToLogin,
  });

  final UserRole initialRole;
  final void Function(UserRole role, String email) onSignupSuccess;
  final void Function(UserRole role) onNavigateToLogin;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  late UserRole _selectedRole;
  final TextEditingController _handlerIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();
  final TextEditingController _adminKeyController = TextEditingController();

  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  @override
  void dispose() {
    _handlerIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    _adminKeyController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
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
      setState(() => _errorText = 'Password must be at least 8 characters long');
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

    // Simulate network registration request
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    setState(() => _isLoading = false);

    UiToast.show(
      context,
      title: 'Registration Successful',
      message: 'Account created successfully as ${_selectedRole.label}!',
      intent: UiIntent.success,
    );

    widget.onSignupSuccess(_selectedRole, email);
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
                                    
                                    // Header Title & Subtitle
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Create your account',
                                          textAlign: TextAlign.left,
                                          style: context.uiText.display.copyWith(
                                            fontSize: 28.0,
                                            fontWeight: FontWeight.w400,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        SizedBox(height: context.sp(theme.spacing.xxs)),
                                        Text(
                                          'Enter your email below to create your account',
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
                                        title: 'Registration Error',
                                        message: _errorText!,
                                        intent: UiIntent.danger,
                                      ),
                                      SizedBox(height: context.sp(theme.spacing.md)),
                                    ],

                                    // Handler ID Field
                                    UiField(
                                      label: 'Handler ID',
                                      required: true,
                                      child: UiInput(
                                        value: _handlerIdController.text,
                                        hintText: '@username',
                                        leadingIcon: Icons.alternate_email_rounded,
                                        onChanged: (v) => _handlerIdController.text = v,
                                      ),
                                    ),
                                    SizedBox(height: context.sp(theme.spacing.md)),

                                    // Email Field with Description
                                    UiField(
                                      label: 'Email',
                                      required: true,
                                      helper:
                                          "We'll use this to contact you. We will not share your email with anyone else.",
                                      child: UiInput(
                                        value: _emailController.text,
                                        hintText: 'm@example.com',
                                        keyboardType: TextInputType.emailAddress,
                                        onChanged: (v) => _emailController.text = v,
                                      ),
                                    ),
                                    SizedBox(height: context.sp(theme.spacing.md)),

                                    // Password & Confirm Password (2-column layout on desktop)
                                    if (showSidePanel)
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: UiField(
                                              label: 'Password',
                                              required: true,
                                              child: UiPasswordField(
                                                controller: _passwordController,
                                                onChanged: (v) =>
                                                    _passwordController.text = v,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: context.sp(theme.spacing.md)),
                                          Expanded(
                                            child: UiField(
                                              label: 'Confirm Password',
                                              required: true,
                                              child: UiPasswordField(
                                                controller: _confirmPasswordController,
                                                onChanged: (v) =>
                                                    _confirmPasswordController.text = v,
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
                                          controller: _passwordController,
                                          onChanged: (v) =>
                                              _passwordController.text = v,
                                        ),
                                      ),
                                      SizedBox(height: context.sp(theme.spacing.md)),
                                      UiField(
                                        label: 'Confirm Password',
                                        required: true,
                                        child: UiPasswordField(
                                          controller: _confirmPasswordController,
                                          onChanged: (v) =>
                                              _confirmPasswordController.text = v,
                                        ),
                                      ),
                                    ],
                                    SizedBox(height: context.sp(theme.spacing.xxs)),
                                    Text(
                                      'Must be at least 8 characters long.',
                                      style: context.uiText.caption.copyWith(
                                        color: colors.foregroundSubtle,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    SizedBox(height: context.sp(theme.spacing.md)),

                                    // Role Specific Optional/Required Inputs
                                    if (_selectedRole == UserRole.affiliate) ...[
                                      UiField(
                                        label: 'Partner Referral Code (Optional)',
                                        helper: 'Earn instant \$50 affiliate bonus credit',
                                        child: UiInput(
                                          value: _referralCodeController.text,
                                          hintText: 'REF-TRADEX-2026',
                                          onChanged: (v) =>
                                              _referralCodeController.text = v,
                                        ),
                                      ),
                                      SizedBox(height: context.sp(theme.spacing.md)),
                                    ] else if (_selectedRole == UserRole.userAdmin) ...[
                                      UiField(
                                        label: 'Master Admin Key (Required)',
                                        required: true,
                                        helper: 'Enter enterprise administrative authorization key',
                                        child: UiInput(
                                          value: _adminKeyController.text,
                                          hintText: 'LIC-ADMIN-XXXX',
                                          onChanged: (v) =>
                                              _adminKeyController.text = v,
                                        ),
                                      ),
                                      SizedBox(height: context.sp(theme.spacing.md)),
                                    ],

                                    // Create Account Submit Button
                                    UiButton(
                                      label: _isLoading
                                          ? 'Creating Account…'
                                          : 'Create Account',
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
                                      actionLabelPrefix: 'Sign up with',
                                    ),
                                    SizedBox(height: context.sp(theme.spacing.lg)),

                                    // Switch to Sign in Link
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      children: [
                                        Text(
                                          'Already have an account? ',
                                          style: context.uiText.body.copyWith(
                                            color: colors.foregroundMuted,
                                            fontSize: 13,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () =>
                                              widget.onNavigateToLogin(_selectedRole),
                                          child: Text(
                                            'Sign in',
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
          'TraderHub TradeX terms, customer privacy protection, and financial regulatory rules.',
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
