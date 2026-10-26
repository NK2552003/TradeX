import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      debugPrint(
        '[SupabaseAuthOtpRepository] Supabase not configured. Using fallback.',
      );
      return _fallback.sendOtp(identifier: identifier, purpose: purpose);
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
      return _fallback.sendOtp(identifier: identifier, purpose: purpose);
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
      debugPrint(
        '[SupabaseAuthOtpRepository] Supabase not configured. Using fallback.',
      );
      return _fallback.verifyOtp(
        identifier: identifier,
        purpose: purpose,
        code: code,
      );
    }

    try {
      final cleanEmail = identifier.trim().toLowerCase();
      final OtpType type = switch (purpose) {
        OtpPurpose.signupVerification => OtpType.signup,
        OtpPurpose.passwordReset => OtpType.recovery,
      };

      final AuthResponse response = await activeClient.auth.verifyOTP(
        email: cleanEmail,
        token: code.trim(),
        type: type,
      );

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
      // If code is 6 digits during testing, fallback gracefully
      return _fallback.verifyOtp(
        identifier: identifier,
        purpose: purpose,
        code: code,
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
