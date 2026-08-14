import 'package:tradex/features/auth/models/auth_user_role.dart';

/// Navigation stages in the auth lifecycle.
enum AuthStage {
  splash,
  onboarding,
  login,
  signup,

  /// OTP verification shown right after signup, before the account is
  /// considered active. See `OtpVerificationPage`.
  signupVerification,
  forgotPassword,
  authenticated,
}

/// Represents the current auth session state.
class AuthSessionState {
  const AuthSessionState({
    required this.stage,
    this.role = UserRole.customer,
    this.email = '',
    this.displayName = 'Nitish Kumar',
    this.hasCompletedOnboarding = false,
  });

  final AuthStage stage;
  final UserRole role;
  final String email;
  final String displayName;
  final bool hasCompletedOnboarding;

  AuthSessionState copyWith({
    AuthStage? stage,
    UserRole? role,
    String? email,
    String? displayName,
    bool? hasCompletedOnboarding,
  }) {
    return AuthSessionState(
      stage: stage ?? this.stage,
      role: role ?? this.role,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }
}
