import 'package:tradex/features/auth/models/otp_purpose.dart';

/// Result of an OTP verify attempt.
class OtpVerifyResult {
  const OtpVerifyResult({required this.success, this.errorMessage, this.token});

  final bool success;

  /// User-facing message on failure (e.g. "Invalid or expired code.").
  final String? errorMessage;

  /// Continuation token returned by the backend on success — e.g. a
  /// short-lived token that authorizes the "set new password" step, or a
  /// session token once signup e-mail verification completes. May be null
  /// if the given purpose doesn't need one.
  final String? token;
}

/// ---------------------------------------------------------------------
/// BACKEND INTEGRATION CONTRACT
/// ---------------------------------------------------------------------
/// This is the single seam every OTP screen in the app talks to
/// (`OtpVerificationPage` for signup e-mail verification, and
/// `ForgotPasswordPage` for password-reset codes). Replace
/// [AuthOtpRepositoryImpl] with a real implementation — nothing in the UI
/// layer needs to change as long as the method signatures below are kept.
///
/// Suggested REST contract (adjust to match your actual API/Supabase/
/// Firebase setup):
///
///   `POST /auth/otp/send`
///     `body   { "identifier": "email|phone", "purpose": "signup|reset|login" }`
///     `200    { "expiresInSeconds": 60 }`
///     `4xx    { "message": "..." }`
///
///   `POST /auth/otp/verify`
///     `body   { "identifier": "email|phone", "purpose": "signup|reset|login", "code": "123456" }`
///     `200    { "token": "continuation or session token" }`
///     `4xx    { "message": "Invalid or expired code" }`
///
///   `POST /auth/otp/resend`
///     `body   { "identifier": "email|phone", "purpose": "signup|reset|login" }`
///     `200    { "expiresInSeconds": 60 }`
///     `429    { "message": "Please wait before requesting another code" }`
///
/// Notes for the backend implementation:
/// - Codes should be single-use and expire (5–10 minutes is typical).
/// - Rate-limit send/resend per identifier (the UI already enforces a
///   client-side resend cooldown, but that is not a substitute for a
///   server-side limit).
/// - Nothing in the current `database/` schema models this yet — consider
///   an `otp_codes` table: (identifier, purpose, code_hash, expires_at,
///   attempt_count, consumed_at, created_at).
/// - [OtpPurpose.apiValue] is the string to send as `purpose`.
/// ---------------------------------------------------------------------
abstract class AuthOtpRepository {
  /// Triggers the backend to send a fresh code to [identifier].
  Future<void> sendOtp({
    required String identifier,
    required OtpPurpose purpose,
  });

  /// Verifies [code] for [identifier]/[purpose].
  Future<OtpVerifyResult> verifyOtp({
    required String identifier,
    required OtpPurpose purpose,
    required String code,
  });

  /// Re-sends a new code, invalidating any previously issued one.
  Future<void> resendOtp({
    required String identifier,
    required OtpPurpose purpose,
  });
}

/// Mock implementation used until the backend endpoints above exist.
///
/// Any 6-digit code is accepted **except `000000`**, which always fails —
/// that's intentional, so the UI's error / shake / clear-and-retry states
/// stay exercisable during frontend development and QA.
class AuthOtpRepositoryImpl implements AuthOtpRepository {
  @override
  Future<void> sendOtp({
    required String identifier,
    required OtpPurpose purpose,
  }) async {
    // Backend contract: POST /auth/otp/send { identifier, purpose: purpose.apiValue }
    await Future.delayed(const Duration(milliseconds: 700));
  }

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String identifier,
    required OtpPurpose purpose,
    required String code,
  }) async {
    // Backend contract: POST /auth/otp/verify { identifier, purpose: purpose.apiValue, code }
    await Future.delayed(const Duration(milliseconds: 600));
    if (code == '000000') {
      return const OtpVerifyResult(
        success: false,
        errorMessage: 'Invalid or expired code. Please try again.',
      );
    }
    return const OtpVerifyResult(success: true, token: 'mock-otp-token');
  }

  @override
  Future<void> resendOtp({
    required String identifier,
    required OtpPurpose purpose,
  }) {
    // Backend contract: POST /auth/otp/resend { identifier, purpose: purpose.apiValue }
    return sendOtp(identifier: identifier, purpose: purpose);
  }
}
