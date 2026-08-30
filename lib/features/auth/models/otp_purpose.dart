/// Which auth flow triggered the OTP verification screen.
///
/// This only drives copy and where the user is sent next — the network
/// contract (send / verify / resend) is identical for every purpose, see
/// `AuthOtpRepository`.
enum OtpPurpose {
  /// New-account e-mail confirmation, shown right after signup.
  signupVerification,

  /// Password-reset flow, shown after "Send Reset Code".
  passwordReset,
}

extension OtpPurposeCopy on OtpPurpose {
  String get title {
    switch (this) {
      case OtpPurpose.signupVerification:
        return 'Verify your email';
      case OtpPurpose.passwordReset:
        return 'Enter verification code';
    }
  }

  String get subtitle {
    switch (this) {
      case OtpPurpose.signupVerification:
        return "We've sent a 6-digit confirmation code to";
      case OtpPurpose.passwordReset:
        return 'We sent a 6-digit code to';
    }
  }

  String get backLabel {
    switch (this) {
      case OtpPurpose.signupVerification:
        return 'Back to Sign up';
      case OtpPurpose.passwordReset:
        return 'Back to Sign in';
    }
  }

  /// Backend-facing string sent as the `purpose` field on every OTP
  /// request. Keep this in sync with whatever the API expects.
  String get apiValue {
    switch (this) {
      case OtpPurpose.signupVerification:
        return 'signup';
      case OtpPurpose.passwordReset:
        return 'reset';
    }
  }
}
