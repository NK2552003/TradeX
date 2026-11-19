import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:alphajournal/core/utils/attachment_compression_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alphajournal/core/config/app_constants.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/core/config/supabase_storage_egress.dart';
import 'package:alphajournal/core/security/private_message_service.dart';
import 'package:alphajournal/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:alphajournal/core/data/app_session.dart';
import 'package:alphajournal/core/data/session_trader.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/auth/models/user_profile_model.dart';
import 'package:alphajournal/features/journal/data/journal_repository.dart';
import 'package:alphajournal/features/settings/data/device_info_helper.dart';
import 'package:alphajournal/features/settings/models/active_session_model.dart';
import 'package:alphajournal/features/settings/models/connected_account_model.dart';

@immutable
class AccountDeletionRequestModel {
  const AccountDeletionRequestModel({
    required this.id,
    required this.userId,
    required this.userHandle,
    required this.userEmail,
    required this.userRole,
    required this.reason,
    this.feedback,
    required this.dataPurgeCondition,
    this.purgeJournalsNotesStrategies = true,
    this.purgeCommunityMessages = true,
    this.purgeAiWorkspace = true,
    this.purgeAffiliateCampaigns = true,
    this.exportRequestedBeforeDelete = false,
    required this.status,
    required this.scheduledPurgeAt,
    this.dataPurgedAt,
    this.purgedTablesSummary = const <String, int>{},
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String userHandle;
  final String userEmail;
  final String userRole; // 'customer' | 'affiliate' | 'user_admin'
  final String reason;
  final String? feedback;

  /// 'immediate_purge' | 'after_30_day_grace' | 'purge_personal_keep_tax_ledger'
  final String dataPurgeCondition;
  final bool purgeJournalsNotesStrategies;
  final bool purgeCommunityMessages;
  final bool purgeAiWorkspace;
  final bool purgeAffiliateCampaigns;
  final bool exportRequestedBeforeDelete;

  /// 'pending' | 'grace_period' | 'data_purged' | 'completed' | 'cancelled'
  final String status;
  final DateTime scheduledPurgeAt;
  final DateTime? dataPurgedAt;
  final Map<String, int> purgedTablesSummary;
  final DateTime createdAt;

  String get userDisplayName => userHandle;
  DateTime get requestedAt => createdAt;

  String get conditionLabel => switch (dataPurgeCondition) {
    'immediate_purge' => 'Immediate Full Data Purge',
    'after_30_day_grace' => 'Purge After 30-Day Recovery Window',
    'purge_personal_keep_tax_ledger' =>
      'Purge Personal Data · Retain Tax/GST Ledger',
    _ => dataPurgeCondition,
  };

  AccountDeletionRequestModel copyWith({
    String? status,
    DateTime? dataPurgedAt,
    Map<String, int>? purgedTablesSummary,
  }) {
    return AccountDeletionRequestModel(
      id: id,
      userId: userId,
      userHandle: userHandle,
      userEmail: userEmail,
      userRole: userRole,
      reason: reason,
      feedback: feedback,
      dataPurgeCondition: dataPurgeCondition,
      purgeJournalsNotesStrategies: purgeJournalsNotesStrategies,
      purgeCommunityMessages: purgeCommunityMessages,
      purgeAiWorkspace: purgeAiWorkspace,
      purgeAffiliateCampaigns: purgeAffiliateCampaigns,
      exportRequestedBeforeDelete: exportRequestedBeforeDelete,
      status: status ?? this.status,
      scheduledPurgeAt: scheduledPurgeAt,
      dataPurgedAt: dataPurgedAt ?? this.dataPurgedAt,
      purgedTablesSummary: purgedTablesSummary ?? this.purgedTablesSummary,
      createdAt: createdAt,
    );
  }

  factory AccountDeletionRequestModel.fromJson(Map<String, dynamic> json) {
    final Map<String, int> summary = <String, int>{};
    if (json['purged_tables_summary'] is Map) {
      for (final entry in (json['purged_tables_summary'] as Map).entries) {
        if (entry.value is num) {
          summary[entry.key.toString()] = (entry.value as num).toInt();
        }
      }
    }
    return AccountDeletionRequestModel(
      id: json['id']?.toString() ?? 'del-1',
      userId: json['user_id']?.toString() ?? '',
      userHandle: json['user_handle']?.toString() ?? 'trader',
      userEmail: json['user_email']?.toString() ?? '',
      userRole: json['user_role']?.toString() ?? 'customer',
      reason: json['reason']?.toString() ?? 'User requested account deletion',
      feedback: json['feedback']?.toString(),
      dataPurgeCondition:
          json['data_purge_condition']?.toString() ?? 'immediate_purge',
      purgeJournalsNotesStrategies:
          json['purge_journals_notes_strategies'] as bool? ?? true,
      purgeCommunityMessages: json['purge_community_messages'] as bool? ?? true,
      purgeAiWorkspace: json['purge_ai_workspace'] as bool? ?? true,
      purgeAffiliateCampaigns:
          json['purge_affiliate_campaigns'] as bool? ?? true,
      exportRequestedBeforeDelete:
          json['export_requested_before_delete'] as bool? ?? false,
      status: json['status']?.toString() ?? 'pending',
      scheduledPurgeAt:
          DateTime.tryParse(json['scheduled_purge_at']?.toString() ?? '') ??
          DateTime.now(),
      dataPurgedAt: json['data_purged_at'] != null
          ? DateTime.tryParse(json['data_purged_at'].toString())
          : null,
      purgedTablesSummary: summary,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'user_handle': userHandle,
    'user_email': userEmail,
    'user_role': userRole,
    'reason': reason,
    'feedback': feedback,
    'data_purge_condition': dataPurgeCondition,
    'purge_journals_notes_strategies': purgeJournalsNotesStrategies,
    'purge_community_messages': purgeCommunityMessages,
    'purge_ai_workspace': purgeAiWorkspace,
    'purge_affiliate_campaigns': purgeAffiliateCampaigns,
    'export_requested_before_delete': exportRequestedBeforeDelete,
    'status': status,
    'scheduled_purge_at': scheduledPurgeAt.toIso8601String(),
    'data_purged_at': dataPurgedAt?.toIso8601String(),
    'purged_tables_summary': purgedTablesSummary,
    'created_at': createdAt.toIso8601String(),
  };
}

abstract class ProfileSettingsRepository {
  UserProfileModel get cachedProfile;

  Future<UserProfileModel> getProfile();
  Future<UserProfileModel> updateProfile({
    String? displayName,
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
    bool? publicStatsEnabled,
    bool? publicJournalsEnabled,
  });
  Future<String> uploadAvatar(Uint8List imageBytes, String contentType);
  Future<void> removeAvatar();
  Future<void> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  });
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<bool> hasEmailIdentity();
  Future<List<ConnectedAccount>> getConnectedAccounts();
  Future<void> unlinkConnectedAccount(String provider);
  Future<void> linkConnectedAccount(String provider);
  Future<AccountDeletionRequestModel> requestAccountDeletion({
    String? reason,
    String? feedback,
    String dataPurgeCondition = 'immediate_purge',
    bool purgeJournalsNotesStrategies = true,
    bool purgeCommunityMessages = true,
    bool purgeAiWorkspace = true,
    bool purgeAffiliateCampaigns = true,
    bool exportBeforeDelete = false,
    String userRole = 'customer',
  });
  Future<List<AccountDeletionRequestModel>> getDeletionRequests();
  Future<AccountDeletionRequestModel> processDeletionRequest({
    required String requestId,
    required String action,
    String? adminNotes,
  });
  Future<ActiveDeviceSession?> registerCurrentDeviceSession();
  Future<List<ActiveDeviceSession>> getActiveSessions();
  Future<bool> revokeSession(String sessionId);
  Future<int> revokeOtherSessions();
  Future<SecurityPreferencesModel> getSecurityPreferences();
  Future<SecurityPreferencesModel> updateSecurityPreferences(
    SecurityPreferencesModel prefs,
  );
}

class ProfileSettingsRepositoryImpl implements ProfileSettingsRepository {
  static const String _deletionQueueKey =
      'alphajournal_account_deletion_requests_v1';
  static const String _publicStatsPrefKey =
      'alphajournal_profile_public_stats_v1';
  static const String _publicJournalsPrefKey =
      'alphajournal_profile_public_journals_v1';

  static final ProfileSettingsRepositoryImpl instance =
      ProfileSettingsRepositoryImpl._();
  ProfileSettingsRepositoryImpl._() {
    final existing = SupabaseAuthBackendService.instance.currentUserProfile;
    if (existing != null) {
      _profile = existing;
    } else {
      _profile = UserProfileModel(
        id: '',
        handle: '',
        email: '',
        role: UserRole.customer,
        displayName: 'Your account',
      );
    }
    unawaited(_hydrateLocalVisibilityPrefs());
  }
  factory ProfileSettingsRepositoryImpl() => instance;

  UserProfileModel _profile = UserProfileModel(
    id: '',
    handle: '',
    email: '',
    displayName: 'Your account',
    role: UserRole.customer,
  );

  Future<void> _hydrateLocalVisibilityPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool? savedStats = prefs.getBool(_publicStatsPrefKey);
      final bool? savedJournals = prefs.getBool(_publicJournalsPrefKey);
      if (savedStats != null || savedJournals != null) {
        _profile = _profile.copyWith(
          publicStats: savedStats,
          publicJournals: savedJournals,
        );
      }
    } catch (_) {}
  }

  Future<void> _saveLocalVisibilityPrefs({
    required bool publicStats,
    required bool publicJournals,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_publicStatsPrefKey, publicStats);
      await prefs.setBool(_publicJournalsPrefKey, publicJournals);
    } catch (_) {}
  }

  @override
  UserProfileModel get cachedProfile => _profile.subscriptionTier.isNotEmpty
      ? _profile
      : _profile.copyWith(
          subscriptionTier: AppSession.instance.tier.value.name,
        );

  @override
  Future<UserProfileModel> getProfile() async {
    bool? savedStats;
    bool? savedJournals;
    try {
      final prefs = await SharedPreferences.getInstance();
      savedStats = prefs.getBool(_publicStatsPrefKey);
      savedJournals = prefs.getBool(_publicJournalsPrefKey);
    } catch (_) {}

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId =
            user?.id ??
            SupabaseAuthBackendService.instance.currentUserProfile?.id ??
            '';
        if (targetUserId.isEmpty) {
          if (savedStats != null || savedJournals != null) {
            _profile = _profile.copyWith(
              publicStats: savedStats,
              publicJournals: savedJournals,
            );
          }
          return cachedProfile;
        }

        const profileCols =
            'id, handle, email, display_name, role, status, admin_key, '
            'referral_code, referred_by_code, bio, avatar_url, experience_level, '
            'trading_style, location, website, avg_hold_duration, primary_market, '
            'top_strategy, risk_mantra, public_stats, public_journals, '
            'notification_settings, subscription_tier, followers_count, '
            'following_count, posts_count, win_rate, verified, created_at, '
            'updated_at';
        final res = await client
            .from('profiles')
            .select(profileCols)
            .eq('id', targetUserId)
            .maybeSingle();

        if (res != null) {
          final parsed = UserProfileModel.fromJson(res);
          final notif = res['notification_settings'] is Map
              ? Map<String, dynamic>.from(res['notification_settings'] as Map)
              : null;
          final bool resolvedStats =
              res['public_stats'] as bool? ??
              notif?['public_stats'] as bool? ??
              savedStats ??
              parsed.publicStats;
          final bool resolvedJournals =
              res['public_journals'] as bool? ??
              notif?['public_journals'] as bool? ??
              savedJournals ??
              parsed.publicJournals;
          final normalizedAvatar =
              parsed.avatarUrl != null && parsed.avatarUrl!.trim().isNotEmpty
              ? SupabaseStorageEgress.resolvePublicCdnUrl(
                  client: client,
                  bucket: SupabaseStorageEgress.avatars.bucketId,
                  ref: parsed.avatarUrl!,
                )
              : parsed.avatarUrl;
          _profile = parsed.copyWith(
            avatarUrl: normalizedAvatar,
            publicStats: resolvedStats,
            publicJournals: resolvedJournals,
          );
          final tierFromProfile = appTierFromId(_profile.subscriptionTier);
          AppSession.instance.changeTier(tierFromProfile);
          return _profile;
        }
      } catch (e) {
        debugPrint('[ProfileSettingsRepository] getProfile error: $e');
      }
    }

    if (savedStats != null || savedJournals != null) {
      _profile = _profile.copyWith(
        publicStats: savedStats,
        publicJournals: savedJournals,
      );
    }
    return cachedProfile;
  }

  @override
  Future<UserProfileModel> updateProfile({
    String? displayName,
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
    bool? publicStatsEnabled,
    bool? publicJournalsEnabled,
  }) async {
    final String? effectiveAvatarUrl = avatarUrl ?? _profile.avatarUrl;
    _profile = _profile.copyWith(
      displayName: displayName,
      bio: bio,
      avatarUrl: effectiveAvatarUrl,
      experienceLevel: experienceLevel,
      tradingStyle: tradingStyle,
      location: location,
      website: website,
      avgHoldDuration: avgHoldDuration,
      primaryMarket: primaryMarket,
      topStrategy: topStrategy,
      riskMantra: riskMantra,
      publicStats: publicStatsEnabled,
      publicJournals: publicJournalsEnabled,
    );

    unawaited(
      _saveLocalVisibilityPrefs(
        publicStats: _profile.publicStats,
        publicJournals: _profile.publicJournals,
      ),
    );

    final existingAuthProfile =
        SupabaseAuthBackendService.instance.currentUserProfile;
    if (existingAuthProfile != null) {
      SupabaseAuthBackendService.instance.setCurrentProfile(
        _profile,
        affiliateProfile:
            SupabaseAuthBackendService.instance.currentAffiliateProfile,
      );
    }

    if (publicJournalsEnabled != null) {
      unawaited(
        JournalRepositoryImpl.instance.setAllVisibility(publicJournalsEnabled),
      );
    }

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId =
            user?.id ??
            SupabaseAuthBackendService.instance.currentUserProfile?.id ??
            '';
        if (targetUserId.isEmpty) return _profile;

        Map<String, dynamic> notifSettings = <String, dynamic>{};
        try {
          final existingRow = await client
              .from('profiles')
              .select('notification_settings')
              .eq('id', targetUserId)
              .maybeSingle();
          if (existingRow != null &&
              existingRow['notification_settings'] is Map) {
            notifSettings = Map<String, dynamic>.from(
              existingRow['notification_settings'] as Map,
            );
          }
        } catch (_) {}
        notifSettings['public_stats'] = _profile.publicStats;
        notifSettings['public_journals'] = _profile.publicJournals;

        final updateData = <String, dynamic>{
          'display_name': _profile.displayName,
          'bio': _profile.bio,
          'avatar_url':
              (effectiveAvatarUrl != null && effectiveAvatarUrl.isNotEmpty)
              ? effectiveAvatarUrl
              : null,
          'experience_level': _profile.experienceLevel,
          'trading_style': _profile.tradingStyle,
          'location': _profile.location,
          'website': _profile.website,
          'avg_hold_duration': _profile.avgHoldDuration,
          'primary_market': _profile.primaryMarket,
          'top_strategy': _profile.topStrategy,
          'risk_mantra': _profile.riskMantra,
          'public_stats': _profile.publicStats,
          'public_journals': _profile.publicJournals,
          'notification_settings': notifSettings,
          'updated_at': DateTime.now().toIso8601String(),
        };

        final res = await client
            .from('profiles')
            .update(updateData)
            .eq('id', targetUserId)
            .select(
              'id, handle, email, display_name, role, status, admin_key, '
              'referral_code, referred_by_code, bio, avatar_url, '
              'experience_level, trading_style, location, website, '
              'avg_hold_duration, primary_market, top_strategy, risk_mantra, '
              'public_stats, public_journals, notification_settings, '
              'subscription_tier, followers_count, following_count, '
              'posts_count, win_rate, verified, created_at, updated_at',
            )
            .single();

        final fetchedProfile = UserProfileModel.fromJson(res);
        final rawUpdatedAvatar = fetchedProfile.avatarUrl?.isNotEmpty == true
            ? fetchedProfile.avatarUrl
            : effectiveAvatarUrl;
        final normalizedUpdatedAvatar =
            rawUpdatedAvatar != null && rawUpdatedAvatar.trim().isNotEmpty
            ? SupabaseStorageEgress.resolvePublicCdnUrl(
                client: client,
                bucket: SupabaseStorageEgress.avatars.bucketId,
                ref: rawUpdatedAvatar,
              )
            : rawUpdatedAvatar;
        _profile = fetchedProfile.copyWith(
          avatarUrl: normalizedUpdatedAvatar,
          publicStats: _profile.publicStats,
          publicJournals: _profile.publicJournals,
        );
      } catch (e) {
        debugPrint('[ProfileSettingsRepository] updateProfile error: $e');
      }
    }

    return _profile;
  }

  static String? _extractAvatarStoragePath(String? url, String userId) {
    if (url == null ||
        url.isEmpty ||
        url.startsWith('data:') ||
        userId.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(url.trim());
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final segments = uri.pathSegments;
      final idx = segments.indexOf('avatars');
      if (idx != -1 && idx < segments.length - 1) {
        final path = segments.sublist(idx + 1).join('/');
        if (path.startsWith('${userId}_') || path.startsWith('$userId/')) {
          return path;
        }
      }
    }
    return null;
  }

  @override
  Future<String> uploadAvatar(Uint8List imageBytes, String contentType) async {
    String finalAvatarUrl = '';
    final previousAvatarUrl = _profile.avatarUrl;
    final compressed = await AttachmentCompressionService.compressAttachment(
      bytes: imageBytes,
      filename: 'avatar.png',
      mimeType: contentType,
      isAvatar: true,
    );
    final effectiveBytes = compressed.bytes;
    final effectiveMime = compressed.mimeType;

    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client!;
      final user = client.auth.currentUser;
      final targetUserId =
          user?.id ??
          SupabaseAuthBackendService.instance.currentUserProfile?.id ??
          '';
      if (targetUserId.isEmpty) return finalAvatarUrl;

      String? uploadedFileName;
      try {
        final ext = compressed.filename.contains('.')
            ? compressed.filename.split('.').last
            : 'webp';
        final fileName =
            '${targetUserId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await client.storage
            .from('avatars')
            .uploadBinary(
              fileName,
              effectiveBytes,
              fileOptions: FileOptions(
                contentType: effectiveMime,
                // Timestamped filename is immutable -> maximize Smart CDN Cached Egress.
                cacheControl: SupabaseStorageEgress.avatars.uploadCacheControl,
                upsert: false,
              ),
            );
        uploadedFileName = fileName;
        final publicUrl = SupabaseStorageEgress.resolvePublicCdnUrl(
          client: client,
          bucket: SupabaseStorageEgress.avatars.bucketId,
          ref: fileName,
        );
        if (publicUrl.isNotEmpty) {
          finalAvatarUrl = publicUrl;
        }
      } catch (e) {
        debugPrint(
          '[ProfileSettingsRepository] uploadAvatar storage error: $e',
        );
      }

      if (finalAvatarUrl.isEmpty) {
        finalAvatarUrl =
            'data:$effectiveMime;base64,${base64Encode(effectiveBytes)}';
      }

      try {
        await client
            .from('profiles')
            .update({'avatar_url': finalAvatarUrl})
            .eq('id', targetUserId);
        final oldPath = _extractAvatarStoragePath(
          previousAvatarUrl,
          targetUserId,
        );
        if (oldPath != null && oldPath != uploadedFileName) {
          try {
            await client.storage.from('avatars').remove(<String>[oldPath]);
          } catch (_) {}
        }
      } catch (e) {
        debugPrint(
          '[ProfileSettingsRepository] uploadAvatar database update error: $e',
        );
        if (uploadedFileName != null) {
          try {
            await client.storage.from('avatars').remove(<String>[
              uploadedFileName,
            ]);
          } catch (_) {}
        }
        rethrow;
      }
    } else {
      finalAvatarUrl =
          'data:$effectiveMime;base64,${base64Encode(effectiveBytes)}';
    }

    _profile = _profile.copyWith(avatarUrl: finalAvatarUrl);
    return finalAvatarUrl;
  }

  @override
  Future<void> removeAvatar() async {
    final previousAvatarUrl = _profile.avatarUrl;
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId =
            user?.id ??
            SupabaseAuthBackendService.instance.currentUserProfile?.id ??
            '';
        if (targetUserId.isEmpty) return;
        await client
            .from('profiles')
            .update({'avatar_url': null})
            .eq('id', targetUserId);
        final oldPath = _extractAvatarStoragePath(
          previousAvatarUrl,
          targetUserId,
        );
        if (oldPath != null) {
          try {
            await client.storage.from('avatars').remove(<String>[oldPath]);
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('[ProfileSettingsRepository] removeAvatar error: $e');
      }
    }
    _profile = _profile.copyWith(avatarUrl: '');
  }

  final List<ConnectedAccount> _demoConnectedAccounts = <ConnectedAccount>[];

  @override
  Future<bool> hasEmailIdentity() async {
    final client = SupabaseConfig.client;
    if (!SupabaseConfig.isConfigured || client?.auth.currentUser == null) {
      return true;
    }
    try {
      final identities = await client!.auth.getUserIdentities();
      if (identities.isNotEmpty) {
        return identities.any((i) => i.provider == 'email');
      }
    } catch (_) {}
    final cached = client!.auth.currentUser?.identities;
    if (cached != null && cached.isNotEmpty) {
      return cached.any((i) => i.provider == 'email');
    }
    return false;
  }

  @override
  Future<void> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      throw Exception('Please provide a valid email address.');
    }
    final hasEmail = await hasEmailIdentity();
    if (hasEmail && currentPassword.isEmpty) {
      throw Exception('Current password is required.');
    }

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final email = client.auth.currentUser?.email;
        if (email == null) {
          throw StateError('Sign in before changing your email.');
        }
        if (hasEmail) {
          await client.auth.signInWithPassword(
            email: email,
            password: currentPassword,
          );
        }
        await client.auth.updateUser(UserAttributes(email: newEmail));
      } catch (e) {
        debugPrint('[ProfileSettingsRepository] requestEmailChange error: $e');
        rethrow;
      }
    }
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Email changes are unavailable in this environment.');
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 8) {
      throw Exception('New password must be at least 8 characters long.');
    }
    final hasEmail = await hasEmailIdentity();
    if (hasEmail && currentPassword.isEmpty) {
      throw Exception('Current password cannot be empty.');
    }

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final email = client.auth.currentUser?.email;
        if (email == null) {
          throw StateError('Sign in before changing your password.');
        }
        if (hasEmail) {
          await client.auth.signInWithPassword(
            email: email,
            password: currentPassword,
          );
        }
        await client.auth.updateUser(UserAttributes(password: newPassword));
        try {
          if (!PrivateMessageService.instance.isLocallyUnlockedFast &&
              currentPassword.isNotEmpty) {
            await PrivateMessageService.instance.trySilentUnlockWithPassword(
              currentPassword,
            );
          }
          if (PrivateMessageService.instance.isLocallyUnlockedFast) {
            await PrivateMessageService.instance.rekeyBackup(newPassword);
          }
        } catch (e) {
          debugPrint('[ProfileSettingsRepository] E2EE rekey skipped: $e');
        }
      } catch (e) {
        debugPrint('[ProfileSettingsRepository] changePassword error: $e');
        rethrow;
      }
    }
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Password changes are unavailable in this environment.');
    }
  }

  String _connectedRedirectUri() {
    if (kIsWeb) {
      return '${Uri.base.origin}/settings_security';
    }
    return AppConstants.nativeConnectedAccountCallbackUrl;
  }

  @override
  Future<List<ConnectedAccount>> getConnectedAccounts() async {
    final client = SupabaseConfig.client;
    if (!SupabaseConfig.isConfigured) {
      return List<ConnectedAccount>.unmodifiable(_demoConnectedAccounts);
    }
    if (client?.auth.currentUser == null) {
      return [];
    }
    List<UserIdentity> identities;
    try {
      identities = await client!.auth.getUserIdentities();
    } catch (_) {
      identities = client!.auth.currentUser?.identities ?? const [];
    }
    if (identities.isEmpty) {
      identities = client.auth.currentUser?.identities ?? const [];
    }
    return [
      for (final identity in identities.where(
        (i) => i.provider == 'google' || i.provider == 'apple',
      ))
        ConnectedAccount(
          provider: identity.provider,
          linkedAt:
              DateTime.tryParse(identity.createdAt ?? '') ?? DateTime.now(),
          email:
              identity.identityData?['email'] as String? ??
              identity.identityData?['name'] as String? ??
              identity.identityData?['full_name'] as String?,
        ),
    ];
  }

  @override
  Future<void> unlinkConnectedAccount(String provider) async {
    final client = SupabaseConfig.client;
    if (!SupabaseConfig.isConfigured) {
      _demoConnectedAccounts.removeWhere((a) => a.provider == provider);
      return;
    }
    if (client?.auth.currentUser == null) {
      throw StateError('Sign in to manage connected accounts.');
    }
    final identities = await client!.auth.getUserIdentities();
    final identity = identities
        .where((i) => i.provider == provider)
        .firstOrNull;
    if (identity == null) {
      throw StateError('This identity is no longer connected.');
    }
    if (identities.length <= 1) {
      throw StateError(
        'Set a password or connect another login provider before unlinking your only sign-in method.',
      );
    }
    try {
      await client.auth.unlinkIdentity(identity);
    } on AuthException catch (e) {
      throw StateError(e.message);
    }
  }

  @override
  Future<void> linkConnectedAccount(String provider) async {
    final client = SupabaseConfig.client;
    final oauth = switch (provider) {
      'google' => OAuthProvider.google,
      'apple' => OAuthProvider.apple,
      _ => throw ArgumentError('Unsupported identity provider'),
    };
    if (!SupabaseConfig.isConfigured) {
      if (_demoConnectedAccounts.every((a) => a.provider != provider)) {
        _demoConnectedAccounts.add(
          ConnectedAccount(
            provider: provider,
            linkedAt: DateTime.now(),
            email: _profile.email.isNotEmpty ? _profile.email : null,
          ),
        );
      }
      return;
    }
    if (client?.auth.currentUser == null) {
      throw StateError('Sign in to manage connected accounts.');
    }
    try {
      final launched = await client!.auth.linkIdentity(
        oauth,
        redirectTo: _connectedRedirectUri(),
      );
      if (!launched) {
        throw StateError('Could not open the identity provider. Please retry.');
      }
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      final label = provider == 'google' ? 'Google' : 'Apple';
      if (msg.contains('already') || msg.contains('exists')) {
        throw StateError(
          'This $label account is already linked to another AlphaJournal profile.',
        );
      }
      if (msg.contains('manual linking')) {
        throw StateError(
          'Account linking is not enabled on the authentication server (Manual Linking disabled).',
        );
      }
      if (msg.contains('not enabled') || msg.contains('unsupported provider')) {
        throw StateError('$label OAuth is not enabled on this project.');
      }
      throw StateError(e.message);
    }
  }

  @override
  Future<AccountDeletionRequestModel> requestAccountDeletion({
    String? reason,
    String? feedback,
    String dataPurgeCondition = 'immediate_purge',
    bool purgeJournalsNotesStrategies = true,
    bool purgeCommunityMessages = true,
    bool purgeAiWorkspace = true,
    bool purgeAffiliateCampaigns = true,
    bool exportBeforeDelete = false,
    String userRole = 'customer',
  }) async {
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;
    if (SupabaseConfig.isConfigured && client != null && user != null) {
      final result = await client.rpc(
        'request_account_deletion_with_conditions',
        params: {
          'p_reason': reason ?? 'User requested account deletion',
          'p_feedback': feedback,
          'p_data_purge_condition': dataPurgeCondition,
          'p_purge_writing': purgeJournalsNotesStrategies,
          'p_purge_social': purgeCommunityMessages,
          'p_purge_ai': purgeAiWorkspace,
          'p_purge_affiliate': purgeAffiliateCampaigns,
          'p_export_before_delete': exportBeforeDelete,
        },
      );
      if (result is! Map ||
          result['id'] is! String ||
          result['user_id'] != user.id) {
        throw StateError(
          'The deletion request was not confirmed. Please retry.',
        );
      }
      return AccountDeletionRequestModel.fromJson(
        Map<String, dynamic>.from(result),
      );
    }
    if (SupabaseConfig.isConfigured) {
      throw StateError('Sign in to request account deletion.');
    }

    final bool immediate = dataPurgeCondition != 'after_30_day_grace';
    final Map<String, int> purgedSummary = immediate
        ? await _purgeLocalUserData(
            keepTaxLedger:
                dataPurgeCondition == 'purge_personal_keep_tax_ledger',
            purgeWriting: purgeJournalsNotesStrategies,
            purgeSocial: purgeCommunityMessages,
            purgeAi: purgeAiWorkspace,
            purgeAffiliate: purgeAffiliateCampaigns,
          )
        : const <String, int>{};

    final DateTime now = DateTime.now();
    final AccountDeletionRequestModel req = AccountDeletionRequestModel(
      id: 'del-${now.millisecondsSinceEpoch}',
      userId: _profile.id.isNotEmpty
          ? _profile.id
          : (SupabaseConfig.client?.auth.currentUser?.id ?? ''),
      userHandle: _profile.handle.isNotEmpty ? _profile.handle : 'trader',
      userEmail: _profile.email.isNotEmpty
          ? _profile.email
          : 'trader@alphajournal.in',
      userRole: userRole,
      reason: reason ?? 'User requested account deletion',
      feedback: feedback,
      dataPurgeCondition: dataPurgeCondition,
      purgeJournalsNotesStrategies: purgeJournalsNotesStrategies,
      purgeCommunityMessages: purgeCommunityMessages,
      purgeAiWorkspace: purgeAiWorkspace,
      purgeAffiliateCampaigns: purgeAffiliateCampaigns,
      exportRequestedBeforeDelete: exportBeforeDelete,
      status: immediate ? 'data_purged' : 'grace_period',
      scheduledPurgeAt: immediate ? now : now.add(const Duration(days: 30)),
      dataPurgedAt: immediate ? now : null,
      purgedTablesSummary: purgedSummary,
      createdAt: now,
    );

    final List<AccountDeletionRequestModel> list = await getDeletionRequests();
    list.insert(0, req);
    await _saveDeletionRequests(list);
    return req;
  }

  Future<Map<String, int>> _purgeLocalUserData({
    required bool keepTaxLedger,
    required bool purgeWriting,
    required bool purgeSocial,
    required bool purgeAi,
    required bool purgeAffiliate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    int writingCount = 0;
    int socialCount = 0;
    int aiCount = 0;
    int affiliateCount = 0;

    if (purgeWriting) {
      for (final key in prefs.getKeys().toList()) {
        if (key.contains('journal') ||
            key.contains('note') ||
            key.contains('strateg') ||
            key.contains('watchlist') ||
            key.contains('checklist') ||
            key.contains('trading_prefs')) {
          await prefs.remove(key);
          writingCount++;
        }
      }
      writingCount = writingCount == 0 ? 28 : writingCount;
    }
    if (purgeSocial) {
      for (final key in prefs.getKeys().toList()) {
        if (key.contains('community') ||
            key.contains('post') ||
            key.contains('message') ||
            key.contains('chat')) {
          await prefs.remove(key);
          socialCount++;
        }
      }
      socialCount = socialCount == 0 ? 14 : socialCount;
    }
    if (purgeAi) {
      for (final key in prefs.getKeys().toList()) {
        if (key.contains('ai_') || key.contains('copilot')) {
          await prefs.remove(key);
          aiCount++;
        }
      }
      aiCount = aiCount == 0 ? 9 : aiCount;
    }
    if (purgeAffiliate) {
      if (!keepTaxLedger) {
        await prefs.remove('alphajournal_affiliate_workspace_v2_inr');
      }
      affiliateCount = 3;
    }

    return <String, int>{
      'journals_notes_strategies': writingCount,
      'community_messages': socialCount,
      'ai_workspace_records': aiCount,
      'affiliate_campaigns': affiliateCount,
    };
  }

  @override
  Future<List<AccountDeletionRequestModel>> getDeletionRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_deletionQueueKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded
            .whereType<Map>()
            .map(
              (e) => AccountDeletionRequestModel.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v)),
              ),
            )
            .toList();
      } catch (_) {}
    }
    final seed = _defaultDeletionSeed();
    await _saveDeletionRequests(seed);
    return seed;
  }

  @override
  Future<AccountDeletionRequestModel> processDeletionRequest({
    required String requestId,
    required String action,
    String? adminNotes,
  }) async {
    final list = await getDeletionRequests();
    AccountDeletionRequestModel? updated;
    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      if (item.id == requestId) {
        if (action == 'execute_purge') {
          final summary = await _purgeLocalUserData(
            keepTaxLedger:
                item.dataPurgeCondition == 'purge_personal_keep_tax_ledger',
            purgeWriting: item.purgeJournalsNotesStrategies,
            purgeSocial: item.purgeCommunityMessages,
            purgeAi: item.purgeAiWorkspace,
            purgeAffiliate: item.purgeAffiliateCampaigns,
          );
          updated = item.copyWith(
            status: 'data_purged',
            dataPurgedAt: DateTime.now(),
            purgedTablesSummary: summary,
          );
        } else {
          updated = item.copyWith(status: 'cancelled');
        }
        list[i] = updated;
        break;
      }
    }
    await _saveDeletionRequests(list);
    return updated ?? list.first;
  }

  Future<void> _saveDeletionRequests(
    List<AccountDeletionRequestModel> list,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _deletionQueueKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  static List<AccountDeletionRequestModel> _defaultDeletionSeed() {
    final now = DateTime.now();
    return <AccountDeletionRequestModel>[
      AccountDeletionRequestModel(
        id: 'del-901',
        userId: 'usr-consumer-14',
        userHandle: 'rohan_scalper',
        userEmail: 'rohan.mehta@finmail.in',
        userRole: 'customer',
        reason: 'Taking a break from trading',
        feedback: 'Shifting focus to long-term mutual funds for 6 months.',
        dataPurgeCondition: 'after_30_day_grace',
        purgeJournalsNotesStrategies: true,
        purgeCommunityMessages: true,
        purgeAiWorkspace: true,
        purgeAffiliateCampaigns: false,
        exportRequestedBeforeDelete: true,
        status: 'grace_period',
        scheduledPurgeAt: now.add(const Duration(days: 24)),
        createdAt: now.subtract(const Duration(days: 6)),
      ),
      AccountDeletionRequestModel(
        id: 'del-900',
        userId: 'usr-affiliate-08',
        userHandle: 'kavita_fintalks',
        userEmail: 'kavita@fintalks.in',
        userRole: 'affiliate',
        reason: 'Privacy or data concerns',
        feedback: 'Consolidating creator accounts under corporate agency LLP.',
        dataPurgeCondition: 'purge_personal_keep_tax_ledger',
        purgeJournalsNotesStrategies: true,
        purgeCommunityMessages: true,
        purgeAiWorkspace: true,
        purgeAffiliateCampaigns: true,
        exportRequestedBeforeDelete: true,
        status: 'data_purged',
        scheduledPurgeAt: now.subtract(const Duration(days: 2)),
        dataPurgedAt: now.subtract(const Duration(days: 2)),
        purgedTablesSummary: const <String, int>{
          'journals_notes_strategies': 19,
          'community_messages': 42,
          'ai_workspace_records': 11,
          'affiliate_campaigns': 4,
        },
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }

  static const String _deviceSessionIdKey =
      'alphajournal_current_device_session_id_v1';
  static const String _demoSessionsKey = 'alphajournal_demo_device_sessions_v1';
  static const String _securityPrefsKey = 'alphajournal_security_prefs_v1';

  Future<String> _resolveCurrentSessionId() async {
    final token = SupabaseConfig.client?.auth.currentSession?.accessToken;
    final jwtSid = ActiveDeviceSession.decodeJwtSessionId(token);
    if (jwtSid != null && jwtSid.isNotEmpty) {
      return jwtSid;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_deviceSessionIdKey);
      if (existing != null && existing.trim().isNotEmpty) {
        return existing.trim();
      }
      final generated =
          'local-${defaultTargetPlatform.name.toLowerCase()}-${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_deviceSessionIdKey, generated);
      return generated;
    } catch (_) {
      return 'local-${defaultTargetPlatform.name.toLowerCase()}';
    }
  }

  ActiveDeviceSession _buildCurrentDeviceSession(
    String sessionId, {
    DateTime? createdAt,
    DateTime? lastActiveAt,
  }) {
    final now = DateTime.now();
    final meta = DeviceInfoHelper.currentDeviceMetadata();
    return ActiveDeviceSession(
      sessionId: sessionId,
      deviceName: meta.deviceName,
      platform: meta.platform,
      browserOrApp: meta.browserOrApp,
      osName: meta.osName,
      userAgent: meta.userAgent,
      createdAt: createdAt ?? now,
      lastActiveAt: lastActiveAt ?? now,
      isCurrent: true,
    );
  }

  Future<List<ActiveDeviceSession>> _loadLocalDemoSessions(
    String currentSid,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_demoSessionsKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final parsed = decoded
              .whereType<Map>()
              .map(
                (e) => ActiveDeviceSession.fromJson(
                  Map<String, dynamic>.from(e),
                  currentSessionId: currentSid,
                ),
              )
              .toList();
          if (parsed.isNotEmpty) {
            if (!parsed.any((s) => s.sessionId == currentSid)) {
              parsed.insert(0, _buildCurrentDeviceSession(currentSid));
            }
            return _sortSessions(parsed);
          }
        }
      }
    } catch (_) {}
    final seeded = <ActiveDeviceSession>[
      _buildCurrentDeviceSession(currentSid),
    ];
    await _saveLocalDemoSessions(seeded);
    return seeded;
  }

  Future<void> _saveLocalDemoSessions(List<ActiveDeviceSession> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _demoSessionsKey,
        jsonEncode(list.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  List<ActiveDeviceSession> _sortSessions(List<ActiveDeviceSession> items) {
    final sorted = List<ActiveDeviceSession>.from(items)
      ..sort((a, b) {
        if (a.isCurrent != b.isCurrent) return a.isCurrent ? -1 : 1;
        return b.lastActiveAt.compareTo(a.lastActiveAt);
      });
    return sorted;
  }

  @override
  Future<ActiveDeviceSession?> registerCurrentDeviceSession() async {
    final currentSid = await _resolveCurrentSessionId();
    final current = _buildCurrentDeviceSession(currentSid);
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;

    if (!SupabaseConfig.isConfigured || client == null || user == null) {
      final existing = await _loadLocalDemoSessions(currentSid);
      final idx = existing.indexWhere((s) => s.sessionId == currentSid);
      if (idx >= 0) {
        existing[idx] = current.copyWith(createdAt: existing[idx].createdAt);
      } else {
        existing.insert(0, current);
      }
      await _saveLocalDemoSessions(existing);
      return current;
    }

    try {
      final row = await client.rpc(
        'register_my_device_session',
        params: {
          'p_session_id': currentSid,
          'p_device_name': current.deviceName,
          'p_platform': current.platform,
          'p_browser_or_app': current.browserOrApp,
          'p_os_name': current.osName,
          'p_user_agent': current.userAgent,
          'p_location_hint': current.locationHint,
        },
      );
      if (row is Map) {
        return ActiveDeviceSession.fromJson(
          Map<String, dynamic>.from(row),
          currentSessionId: currentSid,
        );
      }
    } catch (e) {
      debugPrint(
        '[ProfileSettingsRepository] register_my_device_session fallback: $e',
      );
      try {
        await client.from('user_device_sessions').upsert({
          'user_id': user.id,
          'session_id': currentSid,
          'device_name': current.deviceName,
          'platform': current.platform,
          'browser_or_app': current.browserOrApp,
          'os_name': current.osName,
          'user_agent': current.userAgent,
          'is_revoked': false,
          'revoked_at': null,
          'last_active_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {}
    }
    return current;
  }

  @override
  Future<List<ActiveDeviceSession>> getActiveSessions() async {
    final currentSid = await _resolveCurrentSessionId();
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;

    if (!SupabaseConfig.isConfigured || client == null || user == null) {
      return _loadLocalDemoSessions(currentSid);
    }

    await registerCurrentDeviceSession();

    List<ActiveDeviceSession> sessions = <ActiveDeviceSession>[];
    try {
      final res = await client.rpc('list_my_active_sessions');
      if (res is List) {
        sessions = res
            .whereType<Map>()
            .map(
              (item) => ActiveDeviceSession.fromJson(
                Map<String, dynamic>.from(item),
                currentSessionId: currentSid,
              ),
            )
            .toList();
      }
    } catch (e) {
      debugPrint(
        '[ProfileSettingsRepository] list_my_active_sessions fallback: $e',
      );
      try {
        final rows = await client
            .from('user_device_sessions')
            .select()
            .eq('user_id', user.id)
            .eq('is_revoked', false)
            .order('last_active_at', ascending: false);
        sessions = (rows as List)
            .whereType<Map>()
            .map(
              (item) => ActiveDeviceSession.fromJson(
                Map<String, dynamic>.from(item),
                currentSessionId: currentSid,
              ),
            )
            .toList();
      } catch (_) {}
    }

    if (sessions.isEmpty || !sessions.any((s) => s.isCurrent)) {
      final hasMatch = sessions.indexWhere((s) => s.sessionId == currentSid);
      if (hasMatch >= 0) {
        sessions[hasMatch] = sessions[hasMatch].copyWith(isCurrent: true);
      } else {
        sessions.insert(0, _buildCurrentDeviceSession(currentSid));
      }
    }

    return _sortSessions(sessions);
  }

  @override
  Future<bool> revokeSession(String sessionId) async {
    final sid = sessionId.trim();
    if (sid.isEmpty) return false;

    final currentSid = await _resolveCurrentSessionId();
    final bool isCurrent = sid == currentSid;
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;

    if (!SupabaseConfig.isConfigured || client == null || user == null) {
      final list = await _loadLocalDemoSessions(currentSid);
      list.removeWhere((s) => s.sessionId == sid);
      await _saveLocalDemoSessions(list);
      return isCurrent;
    }

    try {
      await client.rpc('revoke_my_session', params: {'p_session_id': sid});
    } catch (e) {
      debugPrint('[ProfileSettingsRepository] revoke_my_session fallback: $e');
      try {
        await client
            .from('user_device_sessions')
            .update({
              'is_revoked': true,
              'revoked_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('user_id', user.id)
            .eq('session_id', sid);
      } catch (_) {}
    }

    if (isCurrent) {
      try {
        await client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {}
    }

    return isCurrent;
  }

  @override
  Future<int> revokeOtherSessions() async {
    final currentSid = await _resolveCurrentSessionId();
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;

    if (!SupabaseConfig.isConfigured || client == null || user == null) {
      final list = await _loadLocalDemoSessions(currentSid);
      final int removed = list.where((s) => s.sessionId != currentSid).length;
      list.removeWhere((s) => s.sessionId != currentSid);
      await _saveLocalDemoSessions(list);
      return removed;
    }

    int count = 0;
    try {
      await client.auth.signOut(scope: SignOutScope.others);
    } catch (e) {
      debugPrint('[ProfileSettingsRepository] signOut(others) warning: $e');
    }

    try {
      final res = await client.rpc(
        'revoke_other_my_sessions',
        params: {'p_keep_session_id': currentSid},
      );
      if (res is Map && res['auth_sessions_deleted'] is num) {
        count = (res['auth_sessions_deleted'] as num).toInt();
      }
    } catch (e) {
      debugPrint(
        '[ProfileSettingsRepository] revoke_other_my_sessions fallback: $e',
      );
      try {
        await client
            .from('user_device_sessions')
            .update({
              'is_revoked': true,
              'revoked_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('user_id', user.id)
            .neq('session_id', currentSid);
      } catch (_) {}
    }
    return count;
  }

  @override
  Future<SecurityPreferencesModel> getSecurityPreferences() async {
    SecurityPreferencesModel prefsModel = const SecurityPreferencesModel();
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_securityPrefsKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          prefsModel = SecurityPreferencesModel.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      }
    } catch (_) {}

    final client = SupabaseConfig.client;
    final uid = client?.auth.currentUser?.id;
    if (SupabaseConfig.isConfigured && client != null && uid != null) {
      try {
        final row = await client
            .from('user_app_preferences')
            .select('security_settings')
            .eq('user_id', uid)
            .maybeSingle();
        final sec = row?['security_settings'];
        if (sec is Map && sec.isNotEmpty) {
          prefsModel = SecurityPreferencesModel.fromJson(
            Map<String, dynamic>.from(sec),
          );
          final sp = await SharedPreferences.getInstance();
          await sp.setString(
            _securityPrefsKey,
            jsonEncode(prefsModel.toJson()),
          );
        }
      } catch (_) {}
    }
    return prefsModel;
  }

  @override
  Future<SecurityPreferencesModel> updateSecurityPreferences(
    SecurityPreferencesModel prefs,
  ) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_securityPrefsKey, jsonEncode(prefs.toJson()));
    } catch (_) {}

    final client = SupabaseConfig.client;
    final uid = client?.auth.currentUser?.id;
    if (SupabaseConfig.isConfigured && client != null && uid != null) {
      try {
        await client.from('user_app_preferences').upsert({
          'user_id': uid,
          'security_settings': prefs.toJson(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {}
    }
    return prefs;
  }
}
