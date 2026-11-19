import 'package:alphajournal/features/auth/models/affiliate_profile_model.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/auth/models/user_profile_model.dart';

/// Navigation stages in the auth lifecycle.
enum AuthStage {
  splash,
  onboarding,
  login,
  signup,

  /// OTP verification shown right after signup, before the account is
  /// considered active. See `OtpVerificationPage`.
  signupVerification,
  affiliateApplication,
  subscription,
  forgotPassword,
  authenticated,
}

/// Represents the current auth session state.
class AuthSessionState {
  const AuthSessionState({
    required this.stage,
    this.role = UserRole.customer,
    this.email = '',
    this.userId = '',
    this.displayName = '',
    this.hasCompletedOnboarding = false,
    this.profile,
    this.affiliateProfile,
  });

  final AuthStage stage;
  final UserRole role;
  final String email;

  /// Account id issued by the backend. Empty until sign-in resolves, which is
  /// the shell's cue to fall back to the profile repository rather than render a
  /// stand-in identity.
  final String userId;
  final String displayName;
  final bool hasCompletedOnboarding;
  final UserProfileModel? profile;
  final AffiliateProfileModel? affiliateProfile;

  AuthSessionState copyWith({
    AuthStage? stage,
    UserRole? role,
    String? email,
    String? userId,
    String? displayName,
    bool? hasCompletedOnboarding,
    UserProfileModel? profile,
    AffiliateProfileModel? affiliateProfile,
  }) {
    return AuthSessionState(
      stage: stage ?? this.stage,
      role: role ?? this.role,
      email: email ?? this.email,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      profile: profile ?? this.profile,
      affiliateProfile: affiliateProfile ?? this.affiliateProfile,
    );
  }
}
