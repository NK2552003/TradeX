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
    this.errorCode,
  });

  final bool isSuccess;
  final String message;
  final UserProfileModel? profile;
  final AffiliateProfileModel? affiliateProfile;
  final String? errorCode;

  factory AuthResult.success({
    required String message,
    required UserProfileModel profile,
    AffiliateProfileModel? affiliateProfile,
  }) {
    return AuthResult(
      isSuccess: true,
      message: message,
      profile: profile,
      affiliateProfile: affiliateProfile,
    );
  }

  factory AuthResult.failure(String message, {String? errorCode}) {
    return AuthResult(isSuccess: false, message: message, errorCode: errorCode);
  }
}

/// Abstract AuthRepository defining backend interaction contract for authentication.
abstract class AuthRepository {
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
