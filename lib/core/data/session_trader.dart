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
  return AppTrader(
    id: profile.id,
    handle: profile.handle,
    displayName: profile.displayName,
    avatarUrl: profile.avatarUrl,
    bio: profile.bio,
    tier: appTierFromId(profile.subscriptionTier),
    followers: profile.followers,
    following: profile.following,
    winRate: profile.winRate,
    verified: profile.verified,
    isFollowing: false,
    tradingStyle: profile.tradingStyle,
    location: profile.location,
    website: profile.website,
    avgHoldDuration: profile.avgHoldDuration,
    primaryMarket: profile.primaryMarket,
    topStrategy: profile.topStrategy,
    riskMantra: profile.riskMantra,
    createdAt: profile.createdAt,
    postsCount: profile.postsCount,
  );
}
