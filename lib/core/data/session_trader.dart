import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';

/// Parses the tier string stored on the profile into the design-system enum.
AppTier appTierFromId(String id) => switch (id.trim().toLowerCase()) {
  'premium' || 'pro' => AppTier.premium,
  'enterprise' || 'desk' => AppTier.enterprise,
  _ => AppTier.free,
};

/// Maps the authenticated profile onto the social [AppTrader] shape so the feed,
/// composer, messages and copilot all render the same identity.
///
/// Social counters (followers, win rate) still come from the demo source until
/// the backend exposes them; identity fields always come from the profile.
AppTrader appTraderFromProfile(
  UserProfileModel profile, {
  DemoDataSource? source,
}) {
  final DemoDataSource data = source ?? DemoDataSource.instance;
  final AppTrader base = data.me(
    id: profile.id,
    handle: profile.handle,
    displayName: profile.displayName,
    tier: appTierFromId(profile.subscriptionTier),
    bio: profile.bio,
  );
  return AppTrader(
    id: base.id,
    handle: base.handle,
    displayName: base.displayName,
    avatarUrl: profile.avatarUrl,
    bio: base.bio,
    tier: base.tier,
    followers: base.followers,
    following: base.following,
    winRate: base.winRate,
    verified: base.verified,
    isFollowing: false,
    tradingStyle: profile.tradingStyle ?? base.tradingStyle,
  );
}
