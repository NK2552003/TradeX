import 'package:flutter/foundation.dart';

@immutable
class OrgMember {
  const OrgMember({
    required this.userId,
    required this.handle,
    required this.displayName,
    required this.role,
    this.avatarUrl,
    required this.joinedAt,
  });

  final String userId;
  final String handle;
  final String displayName;

  /// 'owner' | 'admin' | 'trader' | 'viewer'
  final String role;
  final String? avatarUrl;
  final DateTime joinedAt;

  factory OrgMember.fromJson(Map<String, dynamic> json) {
    return OrgMember(
      userId: json['user_id'] as String,
      handle: json['handle'] as String,
      displayName: json['display_name'] as String? ?? json['handle'] as String,
      role: json['role'] as String? ?? 'trader',
      avatarUrl: json['avatar_url'] as String?,
      joinedAt: DateTime.tryParse(json['joined_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'handle': handle,
      'display_name': displayName,
      'role': role,
      'avatar_url': avatarUrl,
      'joined_at': joinedAt.toIso8601String(),
    };
  }
}

@immutable
class OrgBranding {
  const OrgBranding({
    required this.displayName,
    this.logoUrl,
    this.primaryColor,
  });

  final String displayName;
  final String? logoUrl;
  final String? primaryColor;

  factory OrgBranding.fromJson(Map<String, dynamic> json) {
    return OrgBranding(
      displayName: json['display_name'] as String? ?? 'TradeX Institutional',
      logoUrl: json['logo_url'] as String?,
      primaryColor: json['primary_color'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      'logo_url': logoUrl,
      'primary_color': primaryColor,
    };
  }

  OrgBranding copyWith({
    String? displayName,
    String? logoUrl,
    String? primaryColor,
  }) {
    return OrgBranding(
      displayName: displayName ?? this.displayName,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
    );
  }
}
