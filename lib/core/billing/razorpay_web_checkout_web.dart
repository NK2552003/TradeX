import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('globalThis.alphajournalRazorpay')
external JSObject? get _razorpayBridge;

@JS('globalThis.alphajournalRazorpay.openCheckout')
external JSPromise<JSString> _openCheckoutJs(JSString optionsJson);

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

  static bool get isSupported => kIsWeb && _razorpayBridge != null;

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
    if (!isSupported || keyId.trim().isEmpty) {
      return const RazorpayCheckoutModalResult(
        status: 'unavailable',
        errorMessage: 'Inline Razorpay Checkout bridge is not available.',
      );
    }

    final cycleLabel = billingCycle == 'annual' ? 'Annual' : 'Monthly';
    final payload = jsonEncode(<String, dynamic>{
      'key_id': keyId.trim(),
      'subscription_id': subscriptionId.trim(),
      'name': 'AlphaJournal',
      'description': 'AlphaJournal $planName — $cycleLabel Subscription',
      'tier': planName,
      'billing_cycle': billingCycle,
      'email': userEmail ?? '',
      'user_name': userName ?? '',
      'is_dark': isDark,
      'theme_color': ?themeColor,
      'backdrop_color': ?backdropColor,
      'surface_color': ?surfaceColor,
      'foreground_color': ?foregroundColor,
      'border_color': ?borderColor,
      'image': ?imageUrl,
    });

    try {
      final rawJson = (await _openCheckoutJs(payload.toJS).toDart).toDart;
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      return RazorpayCheckoutModalResult(
        status: decoded['status']?.toString() ?? 'error',
        paymentId: decoded['razorpay_payment_id']?.toString(),
        subscriptionId:
            decoded['razorpay_subscription_id']?.toString() ?? subscriptionId,
        signature: decoded['razorpay_signature']?.toString(),
        errorMessage: decoded['error']?.toString(),
        errorCode: decoded['code']?.toString(),
      );
    } catch (error) {
      return RazorpayCheckoutModalResult(
        status: 'error',
        errorMessage: error.toString(),
      );
    }
  }
}
