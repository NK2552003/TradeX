import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Parsed metadata and activity state for a signed-in account device/session.
@immutable
class ActiveDeviceSession {
  const ActiveDeviceSession({
    required this.sessionId,
    required this.deviceName,
    required this.platform,
    this.browserOrApp = '',
    this.osName = '',
    this.userAgent = '',
    this.ipAddress = '',
    this.locationHint = '',
    required this.createdAt,
    required this.lastActiveAt,
    this.isCurrent = false,
  });

  final String sessionId;
  final String deviceName;

  /// Normalized platform key: `'web'`, `'macos'`, `'ios'`, `'android'`,
  /// `'windows'`, or `'linux'`.
  final String platform;
  final String browserOrApp;
  final String osName;
  final String userAgent;
  final String ipAddress;
  final String locationHint;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final bool isCurrent;

  /// Compact subtitle describing OS, client, and network metadata.
  String get subtitle {
    final parts = <String>[
      if (browserOrApp.isNotEmpty) browserOrApp,
      if (osName.isNotEmpty) osName,
      if (ipAddress.isNotEmpty) 'IP $ipAddress',
      if (locationHint.isNotEmpty) locationHint,
    ];
    if (parts.isEmpty) return platformLabel;
    return parts.join(' · ');
  }

  String get platformLabel => switch (platform.toLowerCase()) {
    'ios' => 'iPhone / iPad',
    'android' => 'Android',
    'macos' => 'macOS',
    'windows' => 'Windows',
    'linux' => 'Linux',
    _ => 'Web Browser',
  };

  ActiveDeviceSession copyWith({
    String? sessionId,
    String? deviceName,
    String? platform,
    String? browserOrApp,
    String? osName,
    String? userAgent,
    String? ipAddress,
    String? locationHint,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    bool? isCurrent,
  }) {
    return ActiveDeviceSession(
      sessionId: sessionId ?? this.sessionId,
      deviceName: deviceName ?? this.deviceName,
      platform: platform ?? this.platform,
      browserOrApp: browserOrApp ?? this.browserOrApp,
      osName: osName ?? this.osName,
      userAgent: userAgent ?? this.userAgent,
      ipAddress: ipAddress ?? this.ipAddress,
      locationHint: locationHint ?? this.locationHint,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'session_id': sessionId,
    'device_name': deviceName,
    'platform': platform,
    'browser_or_app': browserOrApp,
    'os_name': osName,
    'user_agent': userAgent,
    'ip_address': ipAddress,
    'location_hint': locationHint,
    'created_at': createdAt.toUtc().toIso8601String(),
    'last_active_at': lastActiveAt.toUtc().toIso8601String(),
    'is_current': isCurrent,
  };

  factory ActiveDeviceSession.fromJson(
    Map<String, dynamic> json, {
    String? currentSessionId,
  }) {
    final String sid =
        (json['session_id'] ?? json['id'] ?? '').toString().trim();
    final String rawUa = (json['user_agent'] as String?)?.trim() ?? '';
    final String rawPlatform = (json['platform'] as String?)?.trim() ?? '';
    final parsed = parseUserAgent(rawUa, fallbackPlatform: rawPlatform);

    final String rawName = (json['device_name'] as String?)?.trim() ?? '';
    final String effectiveName =
        (rawName.isNotEmpty &&
                rawName != 'Signed-in Device' &&
                rawName != 'Active Device' &&
                rawName != 'Unknown Device')
            ? rawName
            : parsed.deviceName;

    final String browserOrApp =
        ((json['browser_or_app'] as String?)?.trim().isNotEmpty ?? false)
            ? (json['browser_or_app'] as String).trim()
            : parsed.browserOrApp;

    final String osName =
        ((json['os_name'] as String?)?.trim().isNotEmpty ?? false)
            ? (json['os_name'] as String).trim()
            : parsed.osName;

    final DateTime created =
        DateTime.tryParse('${json['created_at'] ?? ''}')?.toLocal() ??
        DateTime.now();
    final DateTime lastActive =
        DateTime.tryParse('${json['last_active_at'] ?? ''}')?.toLocal() ??
        DateTime.tryParse('${json['updated_at'] ?? ''}')?.toLocal() ??
        created;

    final bool isCurr =
        (currentSessionId != null &&
            currentSessionId.isNotEmpty &&
            sid == currentSessionId) ||
        (json['is_current'] as bool? ?? false);

    return ActiveDeviceSession(
      sessionId: sid,
      deviceName: effectiveName,
      platform: rawPlatform.isNotEmpty ? rawPlatform : parsed.platform,
      browserOrApp: browserOrApp,
      osName: osName,
      userAgent: rawUa,
      ipAddress: (json['ip_address'] as String?)?.trim() ?? '',
      locationHint: (json['location_hint'] as String?)?.trim() ?? '',
      createdAt: created,
      lastActiveAt: lastActive,
      isCurrent: isCurr,
    );
  }

  /// Extracts the Supabase GoTrue `session_id` claim from an access JWT.
  static String? decodeJwtSessionId(String? accessToken) {
    if (accessToken == null || accessToken.trim().isEmpty) return null;
    try {
      final parts = accessToken.split('.');
      if (parts.length < 2) return null;
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      if (payload is Map<String, dynamic>) {
        final sid = payload['session_id']?.toString().trim();
        if (sid != null && sid.isNotEmpty) return sid;
      }
    } catch (_) {}
    return null;
  }

  /// Derives readable device details from a User-Agent string or Flutter runtime.
  static ({
    String deviceName,
    String platform,
    String browserOrApp,
    String osName,
  }) parseUserAgent(String userAgent, {String? fallbackPlatform}) {
    final lower = userAgent.toLowerCase();

    String osName = '';
    String platform = (fallbackPlatform ?? '').trim().toLowerCase();

    if (lower.contains('iphone') || lower.contains('ipad')) {
      osName = lower.contains('ipad') ? 'iPadOS' : 'iOS';
      if (platform.isEmpty) platform = 'ios';
    } else if (lower.contains('android')) {
      osName = 'Android';
      if (platform.isEmpty) platform = 'android';
    } else if (lower.contains('mac os x') || lower.contains('macintosh')) {
      osName = 'macOS';
      if (platform.isEmpty) platform = 'macos';
    } else if (lower.contains('windows')) {
      osName = 'Windows';
      if (platform.isEmpty) platform = 'windows';
    } else if (lower.contains('linux') || lower.contains('x11')) {
      osName = 'Linux';
      if (platform.isEmpty) platform = 'linux';
    }

    String browserOrApp = '';
    if (lower.contains('edg/') || lower.contains('edge/')) {
      browserOrApp = 'Microsoft Edge';
    } else if (lower.contains('opr/') || lower.contains('opera')) {
      browserOrApp = 'Opera';
    } else if (lower.contains('firefox/') || lower.contains('fxios')) {
      browserOrApp = 'Firefox';
    } else if (lower.contains('chrome/') || lower.contains('crios')) {
      browserOrApp = 'Chrome';
    } else if (lower.contains('safari/') &&
        !lower.contains('chrome/') &&
        !lower.contains('crios')) {
      browserOrApp = 'Safari';
    } else if (lower.contains('dart/') || lower.contains('tradex')) {
      browserOrApp = 'alphajournal App';
    } else if (lower.contains('mozilla/')) {
      browserOrApp = 'Web Browser';
    }

    if (platform.isEmpty) {
      if (browserOrApp == 'alphajournal App') {
        platform = defaultTargetPlatform.name.toLowerCase();
      } else {
        platform = 'web';
      }
    }

    if (osName.isEmpty) {
      osName = switch (platform) {
        'ios' => 'iOS',
        'android' => 'Android',
        'macos' => 'macOS',
        'windows' => 'Windows',
        'linux' => 'Linux',
        _ => 'Desktop Web',
      };
    }

    if (browserOrApp.isEmpty) {
      browserOrApp = kIsWeb && platform == 'web'
          ? 'Web Browser'
          : 'alphajournal App';
    }

    final String deviceName = osName.isNotEmpty
        ? '$browserOrApp on $osName'
        : browserOrApp;

    return (
      deviceName: deviceName,
      platform: platform,
      browserOrApp: browserOrApp,
      osName: osName,
    );
  }
}

/// Additional security preferences stored per account and cached locally.
@immutable
class SecurityPreferencesModel {
  const SecurityPreferencesModel({
    this.loginAlertsEnabled = true,
    this.requireReauthForSensitiveActions = false,
    this.autoLockMinutes = 0,
    this.rememberTrustedDevices = true,
  });

  final bool loginAlertsEnabled;
  final bool requireReauthForSensitiveActions;
  final int autoLockMinutes;
  final bool rememberTrustedDevices;

  SecurityPreferencesModel copyWith({
    bool? loginAlertsEnabled,
    bool? requireReauthForSensitiveActions,
    int? autoLockMinutes,
    bool? rememberTrustedDevices,
  }) {
    return SecurityPreferencesModel(
      loginAlertsEnabled: loginAlertsEnabled ?? this.loginAlertsEnabled,
      requireReauthForSensitiveActions:
          requireReauthForSensitiveActions ??
          this.requireReauthForSensitiveActions,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      rememberTrustedDevices:
          rememberTrustedDevices ?? this.rememberTrustedDevices,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'login_alerts_enabled': loginAlertsEnabled,
    'require_reauth_sensitive': requireReauthForSensitiveActions,
    'auto_lock_minutes': autoLockMinutes,
    'remember_trusted_devices': rememberTrustedDevices,
  };

  factory SecurityPreferencesModel.fromJson(Map<String, dynamic> json) {
    return SecurityPreferencesModel(
      loginAlertsEnabled: json['login_alerts_enabled'] as bool? ?? true,
      requireReauthForSensitiveActions:
          json['require_reauth_sensitive'] as bool? ?? false,
      autoLockMinutes: (json['auto_lock_minutes'] as num?)?.toInt() ?? 0,
      rememberTrustedDevices:
          json['remember_trusted_devices'] as bool? ?? true,
    );
  }
}
