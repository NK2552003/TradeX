import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/auth/data/repositories/auth_otp_repository.dart';
import 'package:tradex/features/auth/models/otp_purpose.dart';

/// Real Supabase-backed implementation of [AuthOtpRepository].
/// Handles email verification and password recovery OTPs using Supabase Auth.
class SupabaseAuthOtpRepository implements AuthOtpRepository {
  SupabaseAuthOtpRepository({this._client});

  final SupabaseClient? _client;
  SupabaseClient? get client => _client ?? SupabaseConfig.client;

  final AuthOtpRepository _fallback = AuthOtpRepositoryImpl();

  @override
  Future<void> sendOtp({
    required String identifier,
    required OtpPurpose purpose,
  }) async {
    final activeClient = client;
    if (activeClient == null || !SupabaseConfig.isConfigured) {
      if (CustomerDataPolicy.allowDemo) {
        debugPrint(
          '[SupabaseAuthOtpRepository] Supabase not configured. Using fallback in demo mode.',
        );
        return _fallback.sendOtp(identifier: identifier, purpose: purpose);
      }
      throw StateError('Authentication service is unconfigured. Please check connection.');
    }

    try {
      final cleanEmail = identifier.trim().toLowerCase();
      if (purpose == OtpPurpose.signupVerification) {
        await activeClient.auth.resend(type: OtpType.signup, email: cleanEmail);
      } else if (purpose == OtpPurpose.passwordReset) {
        await activeClient.auth.resetPasswordForEmail(cleanEmail);
      }
    } on AuthException catch (e) {
      debugPrint(
        '[SupabaseAuthOtpRepository] sendOtp AuthException: ${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint('[SupabaseAuthOtpRepository] sendOtp error: $e');
      if (CustomerDataPolicy.allowDemo) {
        return _fallback.sendOtp(identifier: identifier, purpose: purpose);
      }
      throw StateError('Could not send verification code. Please check your network connection.');
    }
  }

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String identifier,
    required OtpPurpose purpose,
    required String code,
  }) async {
    final activeClient = client;
    if (activeClient == null || !SupabaseConfig.isConfigured) {
      if (CustomerDataPolicy.allowDemo) {
        debugPrint(
          '[SupabaseAuthOtpRepository] Supabase not configured. Using fallback in demo mode.',
        );
        return _fallback.verifyOtp(
          identifier: identifier,
          purpose: purpose,
          code: code,
        );
      }
      return const OtpVerifyResult(
        success: false,
        errorMessage: 'Authentication service is unavailable. Please check connection.',
      );
    }

    try {
      final cleanEmail = identifier.trim().toLowerCase();
      final OtpType type = switch (purpose) {
        OtpPurpose.signupVerification => OtpType.signup,
        OtpPurpose.passwordReset => OtpType.recovery,
      };

      AuthResponse response;
      try {
        response = await activeClient.auth.verifyOTP(
          email: cleanEmail,
          token: code.trim(),
          type: type,
        );
      } on AuthException {
        // Fallback to OtpType.email in case the project's Supabase email
        // template issued a generic email OTP token rather than signup/recovery.
        response = await activeClient.auth.verifyOTP(
          email: cleanEmail,
          token: code.trim(),
          type: OtpType.email,
        );
      }

      if (response.user != null || response.session != null) {
        return OtpVerifyResult(
          success: true,
          token: response.session?.accessToken,
        );
      }

      return const OtpVerifyResult(
        success: false,
        errorMessage:
            'Invalid or expired verification code. Please check and try again.',
      );
    } on AuthException catch (e) {
      debugPrint(
        '[SupabaseAuthOtpRepository] verifyOtp AuthException: ${e.message}',
      );
      return OtpVerifyResult(success: false, errorMessage: e.message);
    } catch (e) {
      debugPrint('[SupabaseAuthOtpRepository] verifyOtp error: $e');
      // Only permit mock OTP fallback during explicit isolated development demo mode.
      if (CustomerDataPolicy.allowDemo) {
        return _fallback.verifyOtp(
          identifier: identifier,
          purpose: purpose,
          code: code,
        );
      }
      // Fail closed: Never accept arbitrary codes on network or system errors in production.
      return const OtpVerifyResult(
        success: false,
        errorMessage: 'Verification failed due to a network error. Please try again.',
      );
    }
  }

  @override
  Future<void> resendOtp({
    required String identifier,
    required OtpPurpose purpose,
  }) {
    return sendOtp(identifier: identifier, purpose: purpose);
  }
}
