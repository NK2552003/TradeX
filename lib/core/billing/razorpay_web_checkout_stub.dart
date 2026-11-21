import 'package:flutter/foundation.dart';

@immutable
class RazorpayCheckoutModalResult {
  const RazorpayCheckoutModalResult({
    required this.status,
    this.paymentId,
    this.subscriptionId,
    this.signature,
    this.errorMessage,
    this.errorCode,
  });

  /// 'success' | 'failed' | 'cancelled' | 'unavailable' | 'error'
  final String status;
  final String? paymentId;
  final String? subscriptionId;
  final String? signature;
  final String? errorMessage;
  final String? errorCode;

  bool get isSuccess => status == 'success';
  bool get isFailed => status == 'failed' || status == 'error';
  bool get isCancelled => status == 'cancelled';
  bool get isUnavailable => status == 'unavailable';
}

class RazorpayWebCheckout {
  RazorpayWebCheckout._();

  static bool get isSupported => false;

  static Future<RazorpayCheckoutModalResult> open({
    required String keyId,
    required String subscriptionId,
    required String planName,
    required String billingCycle,
    String? userEmail,
    String? userName,
    bool isDark = true,
    String? themeColor,
    String? backdropColor,
    String? surfaceColor,
    String? foregroundColor,
    String? borderColor,
    String? imageUrl,
  }) async {
    return const RazorpayCheckoutModalResult(
      status: 'unavailable',
      errorMessage: 'Web checkout modal is only available in browser builds.',
    );
  }
}
