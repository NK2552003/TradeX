import 'package:tradex/features/auth/models/auth_user_role.dart';

/// Account status state.
enum ProfileStatus { active, suspended, pendingApproval }

/// Data model representing a user profile in TraderHub TradeX platform.
class UserProfileModel {
  const UserProfileModel({
    required this.id,
    required this.handle,
    required this.email,
    required this.displayName,
    required this.role,
    this.status = ProfileStatus.active,
    this.adminKey,
    this.referralCode,
    this.referredByCode,
    this.bio,
    this.avatarUrl,
    this.experienceLevel,
    this.tradingStyle,
    this.location,
    this.website,
    this.avgHoldDuration,
    this.primaryMarket,
    this.topStrategy,
    this.riskMantra,
    this.publicJournals = false,
    this.subscriptionTier = 'free',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String handle;
  final String email;
  final String displayName;
  final UserRole role;
  final ProfileStatus status;
  final String? adminKey;
  final String? referralCode;
  final String? referredByCode;
  final String? bio;
  final String? avatarUrl;
  final String? experienceLevel;
  final String? tradingStyle;
  final String? location;
  final String? website;
  final String? avgHoldDuration;
  final String? primaryMarket;
  final String? topStrategy;
  final String? riskMantra;
  final bool publicJournals;
  final String subscriptionTier;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String,
      handle: json['handle'] as String,
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      role: UserRole.fromId(json['role'] as String? ?? 'customer'),
      status: _statusFromString(json['status'] as String?),
      adminKey: json['admin_key'] as String?,
      referralCode: json['referral_code'] as String?,
      referredByCode: json['referred_by_code'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      experienceLevel: json['experience_level'] as String?,
      tradingStyle: json['trading_style'] as String?,
      location: json['location'] as String?,
      website: json['website'] as String?,
      avgHoldDuration: json['avg_hold_duration'] as String?,
      primaryMarket: json['primary_market'] as String?,
      topStrategy: json['top_strategy'] as String?,
      riskMantra: json['risk_mantra'] as String?,
      publicJournals: json['public_journals'] as bool? ?? false,
      subscriptionTier: json['subscription_tier'] as String? ?? 'free',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'handle': handle,
      'email': email,
      'display_name': displayName,
      'role': role.id,
      'status': status.name,
      'admin_key': adminKey,
      'referral_code': referralCode,
      'referred_by_code': referredByCode,
      'bio': bio,
      'avatar_url': avatarUrl,
      'experience_level': experienceLevel,
      'trading_style': tradingStyle,
      'location': location,
      'website': website,
      'avg_hold_duration': avgHoldDuration,
      'primary_market': primaryMarket,
      'top_strategy': topStrategy,
      'risk_mantra': riskMantra,
      'public_journals': publicJournals,
      'subscription_tier': subscriptionTier,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  UserProfileModel copyWith({
    String? id,
    String? handle,
    String? email,
    String? displayName,
    UserRole? role,
    ProfileStatus? status,
    String? adminKey,
    String? referralCode,
    String? referredByCode,
    String? bio,
    String? avatarUrl,
    String? experienceLevel,
    String? tradingStyle,
    String? location,
    String? website,
    String? avgHoldDuration,
    String? primaryMarket,
    String? topStrategy,
    String? riskMantra,
    bool? publicJournals,
    String? subscriptionTier,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      handle: handle ?? this.handle,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      status: status ?? this.status,
      adminKey: adminKey ?? this.adminKey,
      referralCode: referralCode ?? this.referralCode,
      referredByCode: referredByCode ?? this.referredByCode,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      tradingStyle: tradingStyle ?? this.tradingStyle,
      location: location ?? this.location,
      website: website ?? this.website,
      avgHoldDuration: avgHoldDuration ?? this.avgHoldDuration,
      primaryMarket: primaryMarket ?? this.primaryMarket,
      topStrategy: topStrategy ?? this.topStrategy,
      riskMantra: riskMantra ?? this.riskMantra,
      publicJournals: publicJournals ?? this.publicJournals,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static ProfileStatus _statusFromString(String? value) {
    switch (value) {
      case 'suspended':
        return ProfileStatus.suspended;
      case 'pending_approval':
        return ProfileStatus.pendingApproval;
      case 'active':
      default:
        return ProfileStatus.active;
    }
  }
}
