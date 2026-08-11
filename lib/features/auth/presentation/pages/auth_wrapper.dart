import 'package:flutter/material.dart';
import 'package:tradex/core/widgets/app_scaffold.dart';
import 'package:tradex/features/auth/models/auth_state.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:tradex/features/auth/presentation/pages/get_started_page.dart';
import 'package:tradex/features/auth/presentation/pages/login_page.dart';
import 'package:tradex/features/auth/presentation/pages/signup_page.dart';
import 'package:tradex/features/auth/presentation/pages/splash_screen.dart';

/// Central Auth Wrapper controlling the dynamic navigation flow across:
/// Splash -> Onboarding (Get Started) -> Login / Signup / Forgot Password -> Authenticated AppScaffold Shell.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({
    super.key,
    this.initialStage = AuthStage.splash,
  });

  final AuthStage initialStage;

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late AuthSessionState _sessionState;

  @override
  void initState() {
    super.initState();
    _sessionState = AuthSessionState(
      stage: widget.initialStage,
      role: UserRole.customer,
    );
  }

  void _navigateToStage(AuthStage stage, {UserRole? role, String? email}) {
    setState(() {
      _sessionState = _sessionState.copyWith(
        stage: stage,
        role: role ?? _sessionState.role,
        email: email ?? _sessionState.email,
      );
    });
  }

  void _handleLogout() {
    setState(() {
      _sessionState = _sessionState.copyWith(
        stage: AuthStage.login,
      );
    });
  }

  void _handleSwitchRole(UserRole newRole) {
    setState(() {
      _sessionState = _sessionState.copyWith(
        role: newRole,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionState.stage == AuthStage.authenticated) {
      return AppScaffold(
        userRole: _sessionState.role,
        userEmail: _sessionState.email.isNotEmpty
            ? _sessionState.email
            : 'nitish@tradex.ai',
        onLogout: _handleLogout,
        onRoleChanged: _handleSwitchRole,
        onReturnToAuth: () => _navigateToStage(AuthStage.login),
      );
    }

    return Builder(
      builder: (context) {
        switch (_sessionState.stage) {
          case AuthStage.splash:
            return SplashScreen(
              onFinish: () => _navigateToStage(AuthStage.onboarding),
            );

          case AuthStage.onboarding:
            return GetStartedPage(
              onGetStarted: (role) =>
                  _navigateToStage(AuthStage.signup, role: role),
              onSignIn: () => _navigateToStage(AuthStage.login),
            );

          case AuthStage.login:
            return LoginPage(
              initialRole: _sessionState.role,
              onLoginSuccess: (role, email) {
                _navigateToStage(AuthStage.authenticated,
                    role: role, email: email);
              },
              onNavigateToSignup: (role) {
                _navigateToStage(AuthStage.signup, role: role);
              },
              onNavigateToForgotPassword: () {
                _navigateToStage(AuthStage.forgotPassword);
              },
            );

          case AuthStage.signup:
            return SignupPage(
              initialRole: _sessionState.role,
              onSignupSuccess: (role, email) {
                _navigateToStage(AuthStage.authenticated,
                    role: role, email: email);
              },
              onNavigateToLogin: (role) {
                _navigateToStage(AuthStage.login, role: role);
              },
            );

          case AuthStage.forgotPassword:
            return ForgotPasswordPage(
              onBackToLogin: () => _navigateToStage(AuthStage.login),
            );

          case AuthStage.authenticated:
            return const SizedBox.shrink(); // Handled above
        }
      },
    );
  }
}
