import 'package:flutter/foundation.dart';
import '../app-ui/theme/app_tokens.dart';
import '../config/env_config.dart';
import '../data/account_access_repository.dart';
import '../privacy/consent_preferences.dart';
import '../../features/auth/models/auth_user_role.dart';

enum AdPlacement {
  feedInline('feed_inline', 'ADSENSE_SLOT_FEED_INLINE'),
  feedFooter('feed_footer', 'ADSENSE_SLOT_FEED_FOOTER'),
  communityRail('community_rail', 'ADSENSE_SLOT_COMMUNITY_RAIL'),
  articleFooter('article_footer', 'ADSENSE_SLOT_ARTICLE_FOOTER'),
  publicNoteFooter('public_note_footer', 'ADSENSE_SLOT_PUBLIC_NOTE_FOOTER');

  const AdPlacement(this.id, this.environmentKey);
  final String id;
  final String environmentKey;
  bool get isFeed => this == feedInline || this == feedFooter;
}

class AdConfig {
  const AdConfig({
    this.enabled = false,
    this.preview = false,
    this.publisherId = '',
    this.cmpScriptUrl = '',
    this.slots = const {},
  });
  factory AdConfig.environment() => AdConfig(
    enabled: EnvConfig.adSetting('ADSENSE_ENABLED') == 'true',
    preview: !kReleaseMode && EnvConfig.adSetting('ADSENSE_PREVIEW') == 'true',
    publisherId: EnvConfig.adSetting('ADSENSE_PUBLISHER_ID'),
    cmpScriptUrl: EnvConfig.adSetting('ADSENSE_CMP_SCRIPT_URL'),
    slots: {
      for (final p in AdPlacement.values)
        p: EnvConfig.adSetting(p.environmentKey),
    },
  );
  final bool enabled;
  final bool preview;
  final String publisherId;
  final String cmpScriptUrl;
  final Map<AdPlacement, String> slots;
  bool get validPublisher => RegExp(r'^ca-pub-\d{16}$').hasMatch(publisherId);
  bool configured(AdPlacement p) =>
      enabled &&
      validPublisher &&
      RegExp(r'^\d{1,20}$').hasMatch(slots[p] ?? '');
  Map<String, Object> toJson() => {
    'enabled': enabled,
    'publisherId': publisherId,
    'cmpScriptUrl': cmpScriptUrl,
    'slots': {for (final entry in slots.entries) entry.key.id: entry.value},
  };
}

/// Ads require a freshly verified free customer account and a public surface.
/// Unknown access, paid plans, admin/affiliate modes and private routes fail closed.
class AdEligibility {
  static bool publicDestination(
    String destination, {
    bool publicRecord = false,
  }) =>
      const {
        'community',
        'community_feed',
        'community_explore',
        'market',
        'market_news',
      }.contains(destination) ||
      (destination == 'notes' && publicRecord);

  static bool freeAccount(
    AccountAccess? access,
    AppTier displayedTier,
    String userId,
  ) =>
      access != null &&
      userId.isNotEmpty &&
      access.userId == userId &&
      access.isActive &&
      access.role == UserRole.customer &&
      access.tier == AppTier.free &&
      displayedTier == AppTier.free;

  static bool consentAllows(ConsentController controller) =>
      controller.loaded &&
      !controller.saving &&
      controller.error == null &&
      controller.value.isCurrent(DateTime.now()) &&
      controller.value.advertising;
}
