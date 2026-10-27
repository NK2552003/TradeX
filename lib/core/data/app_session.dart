import 'package:flutter/foundation.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';

/// Multi-role profile bundle owned by the signed-in user.
enum UserProfileMode {
  /// Standard single-role Trader profile.
  traderOnly,

  /// Dual-role profile: Trader Terminal + Affiliate Partner Hub.
  traderAffiliate,

  /// Dual-role profile: Trader Terminal + Institutional Admin Console.
  traderAdmin,

  /// Full tri-role profile: Trader Terminal + Affiliate Partner Hub + Institutional Admin Console.
  traderAffiliateAdmin;

  String get label => switch (this) {
    UserProfileMode.traderOnly => 'Trader Only',
    UserProfileMode.traderAffiliate => 'Trader + Affiliate',
    UserProfileMode.traderAdmin => 'Trader + Admin',
    UserProfileMode.traderAffiliateAdmin => 'Trader + Affiliate + Admin',
  };

  String get shortLabel => switch (this) {
    UserProfileMode.traderOnly => 'Trader',
    UserProfileMode.traderAffiliate => 'Trader + Affiliate',
    UserProfileMode.traderAdmin => 'Trader + Admin',
    UserProfileMode.traderAffiliateAdmin => 'Trader + Affiliate + Admin',
  };

  List<UserRole> get allowedRoles => switch (this) {
    UserProfileMode.traderOnly => const <UserRole>[UserRole.customer],
    UserProfileMode.traderAffiliate => const <UserRole>[
      UserRole.customer,
      UserRole.affiliate,
    ],
    UserProfileMode.traderAdmin => const <UserRole>[
      UserRole.customer,
      UserRole.userAdmin,
    ],
    UserProfileMode.traderAffiliateAdmin => const <UserRole>[
      UserRole.customer,
      UserRole.affiliate,
      UserRole.userAdmin,
    ],
  };

  bool supportsRole(UserRole role) => allowedRoles.contains(role);

  /// Computes the exact profile bundle a user is eligible for based on their
  /// authenticated role, affiliate approval status, and admin clearance.
  static UserProfileMode fromEligibility({
    required UserRole baseRole,
    required bool isApprovedAffiliate,
    bool isAdmin = false,
  }) {
    final bool hasAdmin = baseRole == UserRole.userAdmin || isAdmin;
    final bool hasAffiliate =
        baseRole == UserRole.affiliate || isApprovedAffiliate;
    if (hasAdmin && hasAffiliate) {
      return UserProfileMode.traderAffiliateAdmin;
    }
    if (hasAdmin) {
      return UserProfileMode.traderAdmin;
    }
    if (hasAffiliate) {
      return UserProfileMode.traderAffiliate;
    }
    return UserProfileMode.traderOnly;
  }
}

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

  /// Multi-role profile bundle owned by the user (`Trader Only`,
  /// `Trader + Affiliate`, `Trader + Admin`, or `Trader + Affiliate + Admin`).
  final ValueNotifier<UserProfileMode> profileMode =
      ValueNotifier<UserProfileMode>(UserProfileMode.traderAffiliateAdmin);

  /// Whether [setProfileMode] was explicitly invoked by a test or dev preview.
  bool hasCustomProfileModeOverride = false;

  /// Active workspace role for the session.
  final ValueNotifier<UserRole> activeRole = ValueNotifier<UserRole>(
    UserRole.customer,
  );

  /// AI Copilot queries consumed in the current billing period.
  final ValueNotifier<int> aiQueriesUsed = ValueNotifier<int>(0);

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

  void setProfileMode(UserProfileMode mode) {
    hasCustomProfileModeOverride = true;
    profileMode.value = mode;
    if (!mode.supportsRole(activeRole.value)) {
      activeRole.value = UserRole.customer;
    }
  }

  /// Synchronizes [profileMode] with the signed-in user's real role eligibility
  /// unless overridden explicitly via [setProfileMode].
  void syncEligibility({
    required UserRole baseRole,
    required bool isApprovedAffiliate,
    bool isAdmin = false,
  }) {
    if (hasCustomProfileModeOverride) return;
    final UserProfileMode resolved = UserProfileMode.fromEligibility(
      baseRole: baseRole,
      isApprovedAffiliate: isApprovedAffiliate,
      isAdmin: isAdmin,
    );
    profileMode.value = resolved;
    if (!resolved.supportsRole(activeRole.value)) {
      activeRole.value = UserRole.customer;
    }
  }

  void cycleProfileMode() {
    final next = profileMode.value == UserProfileMode.traderAffiliate
        ? UserProfileMode.traderAffiliateAdmin
        : UserProfileMode.traderAffiliate;
    setProfileMode(next);
  }

  void recordAiQuery() {
    aiQueriesUsed.value = aiQueriesUsed.value + 1;
  }

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
    hasCustomProfileModeOverride = false;
    profileMode.value = UserProfileMode.traderAffiliateAdmin;
    activeRole.value = UserRole.customer;
    aiQueriesUsed.value = 0;
    billingCycle = _seedCycle;
    cancelAtPeriodEnd = false;
    renewedAt = _seedRenewedAt;
    expiresAt = _seedExpiresAt;
    discountCode = null;
    discountPercent = 0;
  }
}
