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

  /// Reserved for a future login two-factor step.
  login,
}

extension OtpPurposeCopy on OtpPurpose {
  String get title {
    switch (this) {
      case OtpPurpose.signupVerification:
        return 'Verify your email';
      case OtpPurpose.passwordReset:
        return 'Enter verification code';
      case OtpPurpose.login:
        return 'Two-step verification';
    }
  }

  String get subtitle {
    switch (this) {
      case OtpPurpose.signupVerification:
        return "We've sent a 6-digit confirmation code to";
      case OtpPurpose.passwordReset:
        return 'We sent a 6-digit code to';
      case OtpPurpose.login:
        return 'Enter the 6-digit code sent to';
    }
  }

  String get backLabel {
    switch (this) {
      case OtpPurpose.signupVerification:
        return 'Back to Sign up';
      case OtpPurpose.passwordReset:
      case OtpPurpose.login:
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
      case OtpPurpose.login:
        return 'login';
    }
  }
}
