import 'package:flutter/foundation.dart';
import 'package:alphajournal/features/settings/models/active_session_model.dart';

import 'device_info_stub.dart'
    if (dart.library.js_interop) 'device_info_web.dart';

/// Describes the current client runtime (web browser or native app) for
/// active device session registration.
class DeviceInfoHelper {
  DeviceInfoHelper._();

  static ({
    String deviceName,
    String platform,
    String browserOrApp,
    String osName,
    String userAgent,
  })
  currentDeviceMetadata() {
    final String ua = currentBrowserUserAgentImpl().trim();
    if (kIsWeb && ua.isNotEmpty) {
      final parsed = ActiveDeviceSession.parseUserAgent(
        ua,
        fallbackPlatform: 'web',
      );
      return (
        deviceName: parsed.deviceName,
        platform: parsed.platform,
        browserOrApp: parsed.browserOrApp,
        osName: parsed.osName,
        userAgent: ua,
      );
    }

    final String platform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'linux',
    };
    final String osName = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.android => 'Android',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
    final String appLabel = kIsWeb ? 'Web Browser' : 'AlphaJournal App';
    return (
      deviceName: '$appLabel on $osName',
      platform: kIsWeb ? 'web' : platform,
      browserOrApp: appLabel,
      osName: osName,
      userAgent: ua,
    );
  }
}
