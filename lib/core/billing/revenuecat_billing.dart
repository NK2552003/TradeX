import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:alphajournal/core/config/env_config.dart';
import 'package:alphajournal/core/config/supabase_config.dart';

/// Mobile store billing. A store entitlement is never written to Supabase by
/// this client; the verified RevenueCat webhook owns that database transition.
class RevenueCatBilling {
  RevenueCatBilling._();

  static const entitlementId = 'alphajournal_pro';
  static const legacyEntitlementId = 'tradex_pro';
  static bool _configured = false;
  static bool get isConfigured => _configured;

  static Future<void> initialize() async {
    if (_configured || kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }
    final key = kReleaseMode
        ? (Platform.isAndroid
              ? EnvConfig.revenueCatAndroidApiKey
              : EnvConfig.revenueCatIosApiKey)
        : EnvConfig.revenueCatTestApiKey;
    if (key.isEmpty || (kReleaseMode && key.startsWith('test_'))) return;
    await Purchases.configure(PurchasesConfiguration(key));
    _configured = true;
  }

  static Future<void> identify(String userId) async {
    if (!_configured || userId.isEmpty) return;
    await Purchases.logIn(userId);
  }

  static Future<void> clearIdentity() async {
    if (!_configured) return;
    await Purchases.logOut();
  }

  static Future<CustomerInfo?> customerInfo() async {
    if (!_configured) return null;
    return Purchases.getCustomerInfo();
  }

  static Future<bool> hasProEntitlement() async {
    final info = await customerInfo();
    final active = info?.entitlements.active;
    return active?.containsKey(entitlementId) == true ||
        active?.containsKey(legacyEntitlementId) == true;
  }

  static Future<Offering?> currentOffering() async {
    if (!_configured) return null;
    return (await Purchases.getOfferings()).current;
  }

  /// Requires the two supported subscription packages.
  static Future<PaywallResult> presentPaywall() async {
    if (!_configured) {
      throw StateError('Mobile store billing is not configured.');
    }
    final offering = await currentOffering();
    if (offering == null ||
        offering.monthly == null ||
        offering.annual == null) {
      throw StateError(
        'The monthly and yearly store packages must be published first.',
      );
    }
    final userId = SupabaseConfig.client?.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in before opening the store offer.');
    }
    await identify(userId);
    return RevenueCatUI.presentPaywallIfNeeded(
      entitlementId,
      offering: offering,
      displayCloseButton: true,
    );
  }

  static Future<CustomerInfo> restore() async {
    if (!_configured) {
      throw StateError('Mobile store billing is not configured.');
    }
    return Purchases.restorePurchases();
  }

  static Future<void> presentCustomerCenter() async {
    if (!_configured) {
      throw StateError('Mobile store billing is not configured.');
    }
    await RevenueCatUI.presentCustomerCenter();
  }
}
