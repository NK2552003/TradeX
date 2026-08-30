import 'package:flutter/foundation.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Process-wide entitlement state shared by every repository and page.
///
/// Plan gating shows up on a lot of surfaces (direct messages, copilot credits,
/// analytics depth, desk seats). Before this holder existed each repository kept
/// its own copy of the tier, so the billing page could report Premium while the
/// messages page still rendered the free-plan gate. One owner keeps them
/// honest: change the plan anywhere and every gate reacts to the same value.
///
/// The rest of the subscription — billing cycle, renewal date, whether renewal
/// has been stopped, any coupon — lives here for the same reason. Pages build
/// their own repository instances, so state kept on an instance would let the
/// plan chooser sell an annual plan the billing page then reports as monthly.
///
/// The backend replaces this with the entitlement claim carried on the session
/// token — repositories keep reading [tier] at call time, so nothing above this
/// layer has to change.
class AppSession {
  AppSession._();

  static final AppSession instance = AppSession._();

  /// Entitlement the demo account starts on. This is the one place the seed
  /// lives; the profile and subscription repositories both read it rather than
  /// declaring a plan of their own.
  static const AppTier seedTier = AppTier.premium;

  /// Current plan. Listen to it to rebuild a gate the moment billing changes.
  final ValueNotifier<AppTier> tier = ValueNotifier<AppTier>(seedTier);

  /// 'monthly' | 'annual'. The cycle the account is currently billed on.
  String billingCycle = _seedCycle;

  /// Renewal has been stopped but the paid period has not run out yet.
  bool cancelAtPeriodEnd = false;

  /// Start of the current paid period.
  DateTime renewedAt = _seedRenewedAt;

  /// End of the current paid period, which is also the date access stops once
  /// renewal has been cancelled.
  DateTime expiresAt = _seedExpiresAt;

  /// Coupon applied to the subscription, with the percentage it takes off.
  String? discountCode;
  int discountPercent = 0;

  static const String _seedCycle = 'monthly';
  static DateTime get _seedRenewedAt =>
      DateTime.now().subtract(const Duration(days: 12));
  static DateTime get _seedExpiresAt =>
      DateTime.now().add(const Duration(days: 18));

  /// True when the plan clears [required] — the shape every gate check uses so
  /// the ordering of [AppTier] stays a single decision.
  bool allows(AppTier required) => tier.value.index >= required.index;

  void changeTier(AppTier value) => tier.value = value;

  /// Records a completed checkout: the plan, the cycle it was bought on and the
  /// period it paid for. Renewal is live again and any coupon carries over.
  void startPeriod(AppTier value, String cycle) {
    tier.value = value;
    billingCycle = cycle;
    cancelAtPeriodEnd = false;
    renewedAt = DateTime.now();
    expiresAt = DateTime.now().add(
      Duration(days: cycle == 'annual' ? 365 : 30),
    );
  }

  /// Restores the seed subscription. Used by tests and the prototype's reset
  /// action; every field above is covered so no state leaks between tests.
  void reset() {
    tier.value = seedTier;
    billingCycle = _seedCycle;
    cancelAtPeriodEnd = false;
    renewedAt = _seedRenewedAt;
    expiresAt = _seedExpiresAt;
    discountCode = null;
    discountPercent = 0;
  }
}
