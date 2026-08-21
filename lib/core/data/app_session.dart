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

  /// True when the plan clears [required] — the shape every gate check uses so
  /// the ordering of [AppTier] stays a single decision.
  bool allows(AppTier required) => tier.value.index >= required.index;

  void changeTier(AppTier value) => tier.value = value;

  /// Restores the seed plan. Used by tests and the prototype's reset action.
  void reset() => tier.value = seedTier;
}
