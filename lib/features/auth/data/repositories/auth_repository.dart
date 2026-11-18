import 'package:tradex/features/auth/models/affiliate_profile_model.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';

/// Authentication result object containing status, message, and profile payload.
class AuthResult {
  const AuthResult({
    required this.isSuccess,
    required this.message,
    this.profile,
    this.affiliateProfile,
    this.workspaceRole,
    this.errorCode,
    this.requiresEmailVerification = false,
  });

  final bool isSuccess;
  final String message;
  final UserProfileModel? profile;
  final AffiliateProfileModel? affiliateProfile;
  final UserRole? workspaceRole;
  final String? errorCode;
  final bool requiresEmailVerification;

  factory AuthResult.success({
    required String message,
    required UserProfileModel profile,
    AffiliateProfileModel? affiliateProfile,
    UserRole? workspaceRole,
    bool requiresEmailVerification = false,
  }) {
    return AuthResult(
      isSuccess: true,
      message: message,
      profile: profile,
      affiliateProfile: affiliateProfile,
      workspaceRole: workspaceRole,
      requiresEmailVerification: requiresEmailVerification,
    );
  }

  factory AuthResult.failure(String message, {String? errorCode}) {
    return AuthResult(isSuccess: false, message: message, errorCode: errorCode);
  }
}

/// Abstract AuthRepository defining backend interaction contract for authentication.
abstract class AuthRepository {
  /// Maximum number of non-admin user accounts permitted before new signups are
  /// automatically disabled to protect platform capacity.
  static const int maxRegisteredUsersCap = 100;

  /// Returns true when total registered non-admin users is below
  /// [maxRegisteredUsersCap] and new user signups are open.
  Future<bool> isSignupOpen() async => true;

  /// Returns the current count of registered non-admin users.
  Future<int> getRegisteredUserCount() async => 0;

  /// Register a new user with role, handler ID, email, password, and optional partner code or admin key.
  Future<AuthResult> signUp({
    required UserRole role,
    required String handle,
    required String email,
    required String password,
    String? referralCode,
    String? adminKey,
  });

  /// Authenticate an existing user by email OR handle, password, and optional admin key.
  Future<AuthResult> signIn({
    required UserRole role,
    required String emailOrHandle,
    required String password,
    String? adminKey,
  });

  /// Sign out the current user session.
  Future<void> signOut();

  /// Trigger a password reset email for the given address.
  Future<AuthResult> resetPassword(String email);

  /// Fetch user profile details by ID.
  Future<UserProfileModel?> getProfile(String userId);

  /// Fetch affiliate metrics by profile ID.
  Future<AffiliateProfileModel?> getAffiliateProfile(String affiliateId);
}
