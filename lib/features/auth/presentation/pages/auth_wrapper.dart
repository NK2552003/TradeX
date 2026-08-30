import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/session_trader.dart';
import 'package:tradex/core/widgets/app_scaffold.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_application_page.dart';
import 'package:tradex/features/auth/data/repositories/auth_repository.dart';
import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:tradex/features/auth/models/auth_state.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/models/otp_purpose.dart';
import 'package:tradex/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:tradex/features/auth/presentation/pages/get_started_page.dart';
import 'package:tradex/features/auth/presentation/pages/login_page.dart';
import 'package:tradex/features/auth/presentation/pages/otp_verification_page.dart';
import 'package:tradex/features/auth/presentation/pages/signup_page.dart';
import 'package:tradex/features/auth/presentation/pages/splash_screen.dart';
import 'package:tradex/features/auth/presentation/pages/subscription_pricing_page.dart';

/// Central Auth Wrapper controlling the dynamic navigation flow across:
/// Splash -> Onboarding (Get Started) -> Login / Signup / Forgot Password -> Subscription -> Authenticated AppScaffold Shell.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({
    super.key,
    this.initialStage = AuthStage.splash,
    this.authRepository,
  });

  final AuthStage initialStage;
  final AuthRepository? authRepository;

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late AuthSessionState _sessionState;
  late final AuthRepository _authRepository;

  @override
  void initState() {
    super.initState();
    _authRepository =
        widget.authRepository ?? SupabaseAuthBackendService.instance;
    final String? preview = kDebugMode
        ? Uri.base.queryParameters['preview']
        : null;
    final AuthStage initialStage = switch (preview) {
      'application' => AuthStage.affiliateApplication,
      'pricing' || 'subscription' => AuthStage.subscription,
      'customer' || 'affiliate' || 'admin' => AuthStage.authenticated,
      _ => widget.initialStage,
    };
    final UserRole initialRole = switch (preview) {
      'affiliate' => UserRole.affiliate,
      'admin' => UserRole.userAdmin,
      'application' => UserRole.affiliate,
      _ => UserRole.customer,
    };
    // Identity is empty until the backend resolves a profile. The only literals
    // here belong to the debug `?preview=` deep link, which has no account to
    // read from and must still key an affiliate application consistently.
    _sessionState = AuthSessionState(
      stage: initialStage,
      role: initialRole,
      email: preview == null ? '' : 'design.preview@tradex.local',
      userId: preview == null ? '' : 'usr_design_preview',
      displayName: preview == null ? '' : 'Design Preview',
    );
  }

  void _navigateToStage(AuthStage stage, {UserRole? role, String? email}) {
    final activeService = SupabaseAuthBackendService.instance;
    setState(() {
      _sessionState = _sessionState.copyWith(
        stage: stage,
        role: role ?? _sessionState.role,
        email: email ?? _sessionState.email,
        profile: activeService.currentUserProfile,
        affiliateProfile: activeService.currentAffiliateProfile,
      );
    });
  }

  void _handleLogout() async {
    await _authRepository.signOut();
    setState(() {
      _sessionState = _sessionState.copyWith(stage: AuthStage.login);
    });
  }

  void _handleSwitchRole(UserRole newRole) {
    setState(() {
      _sessionState = _sessionState.copyWith(role: newRole);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;

    if (_sessionState.stage == AuthStage.splash) {
      return ColoredBox(
        color: colors.background,
        child: SplashScreen(
          onFinish: () => _navigateToStage(AuthStage.onboarding),
        ),
      );
    }

    final activeProfile =
        _sessionState.profile ??
        SupabaseAuthBackendService.instance.currentUserProfile;

    final Widget stageWidget = KeyedSubtree(
      key: ValueKey<AuthStage>(_sessionState.stage),
      child: Builder(
        builder: (context) {
          switch (_sessionState.stage) {
            case AuthStage.splash:
              return const SizedBox.shrink();

            case AuthStage.onboarding:
              return AppBlurFade(
                child: GetStartedPage(
                  onGetStarted: (role) =>
                      _navigateToStage(AuthStage.signup, role: role),
                  onSignIn: () => _navigateToStage(AuthStage.login),
                  onViewFullPricing: () =>
                      _navigateToStage(AuthStage.subscription),
                ),
              );

            case AuthStage.login:
              return LoginPage(
                initialRole: _sessionState.role,
                authRepository: _authRepository,
                onLoginSuccess: (role, email) {
                  _navigateToStage(
                    AuthStage.authenticated,
                    role: role,
                    email: email,
                  );
                },
                onNavigateToSignup: (role) {
                  _navigateToStage(AuthStage.signup, role: role);
                },
                onNavigateToForgotPassword: () {
                  _navigateToStage(AuthStage.forgotPassword);
                },
                onNavigateBack: () => _navigateToStage(AuthStage.onboarding),
              );

            case AuthStage.signup:
              return SignupPage(
                initialRole: _sessionState.role,
                authRepository: _authRepository,
                onSignupSuccess: (role, email) {
                  // Account is created but not yet verified — route through
                  // the OTP screen before granting access.
                  _navigateToStage(
                    AuthStage.signupVerification,
                    role: role,
                    email: email,
                  );
                },
                onNavigateToLogin: (role) {
                  _navigateToStage(AuthStage.login, role: role);
                },
                onNavigateBack: () => _navigateToStage(AuthStage.onboarding),
              );

            case AuthStage.signupVerification:
              return OtpVerificationPage(
                identifier: _sessionState.email,
                purpose: OtpPurpose.signupVerification,
                onVerified: (token) {
                  // Backend contract: persist/exchange `token` if the API issues
                  // a session token here instead of a separate login step.
                  _navigateToStage(
                    _sessionState.role == UserRole.affiliate
                        ? AuthStage.affiliateApplication
                        : AuthStage.subscription,
                    role: _sessionState.role,
                    email: _sessionState.email,
                  );
                },
                onBack: () =>
                    _navigateToStage(AuthStage.signup, role: _sessionState.role),
              );

            case AuthStage.affiliateApplication:
              return AffiliateApplicationPage(
                userId: activeProfile?.id ?? _sessionState.userId,
                email: activeProfile?.email ?? _sessionState.email,
                displayName:
                    activeProfile?.displayName ?? _sessionState.displayName,
                onCancel: () => _navigateToStage(
                  AuthStage.subscription,
                  role: UserRole.customer,
                ),
                onDone: () => _navigateToStage(
                  AuthStage.subscription,
                  role: UserRole.customer,
                ),
              );

            case AuthStage.subscription:
              return SubscriptionPricingPage(
                isPostSignup: true,
                onBack: () => _navigateToStage(AuthStage.onboarding),
                onContinue: () => _navigateToStage(
                  AuthStage.authenticated,
                  role: _sessionState.role,
                  email: _sessionState.email,
                ),
              );

            case AuthStage.forgotPassword:
              return ForgotPasswordPage(
                authRepository: _authRepository,
                onBackToLogin: () => _navigateToStage(AuthStage.login),
              );

            case AuthStage.authenticated:
              return AppScaffold(
                userRole: _sessionState.role,
                userId: activeProfile?.id ?? _sessionState.userId,
                userDisplayName:
                    activeProfile?.displayName ?? _sessionState.displayName,
                subscriptionTier:
                    appTierFromId(activeProfile?.subscriptionTier ?? ''),
                userEmail: activeProfile?.email ?? _sessionState.email,
                onLogout: _handleLogout,
                onRoleChanged: _handleSwitchRole,
                onReturnToAuth: () => _navigateToStage(AuthStage.login),
              );
          }
        },
      ),
    );

    return ColoredBox(
      color: colors.background,
      child: UiStaggeredPageTransition(
        child: stageWidget,
      ),
    );
  }
}
