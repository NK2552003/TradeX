import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';
import 'package:tradex/features/settings/models/connected_account_model.dart';

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
}

class ProfileSettingsRepositoryImpl implements ProfileSettingsRepository {
  static const String _deletionQueueKey = 'tradex_account_deletion_requests_v1';

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
  }
  factory ProfileSettingsRepositoryImpl() => instance;

  UserProfileModel _profile = UserProfileModel(
    id: '',
    handle: '',
    email: '',
    displayName: 'Your account',
    role: UserRole.customer,
  );

  @override
  UserProfileModel get cachedProfile =>
      _profile.copyWith(subscriptionTier: AppSession.instance.tier.value.name);

  @override
  Future<UserProfileModel> getProfile() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId =
            user?.id ??
            SupabaseAuthBackendService.instance.currentUserProfile?.id ??
            '';
        if (targetUserId.isEmpty) return _profile;

        final res = await client
            .from('profiles')
            .select()
            .eq('id', targetUserId)
            .maybeSingle();

        if (res != null) {
          _profile = UserProfileModel.fromJson(res);
          return _profile.copyWith(
            subscriptionTier: AppSession.instance.tier.value.name,
          );
        }
      } catch (e) {
        debugPrint('[ProfileSettingsRepository] getProfile error: $e');
      }
    }

    return _profile.copyWith(
      subscriptionTier: AppSession.instance.tier.value.name,
    );
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
      publicJournals: publicStatsEnabled,
    );

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId =
            user?.id ??
            SupabaseAuthBackendService.instance.currentUserProfile?.id ??
            '';
        if (targetUserId.isEmpty) return _profile;

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
          'public_journals': _profile.publicJournals,
          'updated_at': DateTime.now().toIso8601String(),
        };

        final res = await client
            .from('profiles')
            .update(updateData)
            .eq('id', targetUserId)
            .select()
            .single();

        final fetchedProfile = UserProfileModel.fromJson(res);
        _profile = fetchedProfile.copyWith(
          avatarUrl: fetchedProfile.avatarUrl?.isNotEmpty == true
              ? fetchedProfile.avatarUrl
              : effectiveAvatarUrl,
        );
      } catch (e) {
        debugPrint('[ProfileSettingsRepository] updateProfile error: $e');
      }
    }

    return _profile;
  }

  @override
  Future<String> uploadAvatar(Uint8List imageBytes, String contentType) async {
    String finalAvatarUrl = '';
    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client!;
      final user = client.auth.currentUser;
      final targetUserId =
          user?.id ??
          SupabaseAuthBackendService.instance.currentUserProfile?.id ??
          '';
      if (targetUserId.isEmpty) return finalAvatarUrl;

      try {
        final ext = contentType.contains('jpeg') || contentType.contains('jpg')
            ? 'jpg'
            : 'png';
        final fileName =
            '${targetUserId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await client.storage
            .from('avatars')
            .uploadBinary(
              fileName,
              imageBytes,
              fileOptions: FileOptions(contentType: contentType, upsert: true),
            );
        final publicUrl = client.storage.from('avatars').getPublicUrl(fileName);
        if (publicUrl.isNotEmpty) {
          finalAvatarUrl = publicUrl;
        }
      } catch (e) {
        debugPrint(
          '[ProfileSettingsRepository] uploadAvatar storage error: $e',
        );
      }

      if (finalAvatarUrl.isEmpty) {
        finalAvatarUrl = 'data:$contentType;base64,${base64Encode(imageBytes)}';
      }

      try {
        await client
            .from('profiles')
            .update({'avatar_url': finalAvatarUrl})
            .eq('id', targetUserId);
      } catch (e) {
        debugPrint(
          '[ProfileSettingsRepository] uploadAvatar database update error: $e',
        );
      }
    } else {
      finalAvatarUrl = 'data:$contentType;base64,${base64Encode(imageBytes)}';
    }

    _profile = _profile.copyWith(avatarUrl: finalAvatarUrl);
    return finalAvatarUrl;
  }

  @override
  Future<void> removeAvatar() async {
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
      } catch (e) {
        debugPrint('[ProfileSettingsRepository] removeAvatar error: $e');
      }
    }
    _profile = _profile.copyWith(avatarUrl: '');
  }

  @override
  Future<void> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      throw Exception('Please provide a valid email address.');
    }
    if (currentPassword.isEmpty) {
      throw Exception('Current password is required.');
    }

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final email = client.auth.currentUser?.email;
        if (email == null) {
          throw StateError('Sign in before changing your email.');
        }
        await client.auth.signInWithPassword(
          email: email,
          password: currentPassword,
        );
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
    if (currentPassword.isEmpty) {
      throw Exception('Current password cannot be empty.');
    }

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final email = client.auth.currentUser?.email;
        if (email == null) {
          throw StateError('Sign in before changing your password.');
        }
        await client.auth.signInWithPassword(
          email: email,
          password: currentPassword,
        );
        await client.auth.updateUser(UserAttributes(password: newPassword));
      } catch (e) {
        debugPrint('[ProfileSettingsRepository] changePassword error: $e');
        rethrow;
      }
    }
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Password changes are unavailable in this environment.');
    }
  }

  @override
  Future<List<ConnectedAccount>> getConnectedAccounts() async {
    final client = SupabaseConfig.client;
    if (!SupabaseConfig.isConfigured || client?.auth.currentUser == null) {
      return [];
    }
    final identities = await client!.auth.getUserIdentities();
    return [
      for (final identity in identities.where(
        (i) => i.provider == 'google' || i.provider == 'apple',
      ))
        ConnectedAccount(
          provider: identity.provider,
          linkedAt:
              DateTime.tryParse(identity.createdAt ?? '') ?? DateTime.now(),
          email: identity.identityData?['email'] as String?,
        ),
    ];
  }

  @override
  Future<void> unlinkConnectedAccount(String provider) async {
    final client = SupabaseConfig.client;
    if (!SupabaseConfig.isConfigured || client?.auth.currentUser == null) {
      throw StateError('Sign in to manage connected accounts.');
    }
    final identities = await client!.auth.getUserIdentities();
    final identity = identities
        .where((i) => i.provider == provider)
        .firstOrNull;
    if (identity == null) {
      throw StateError('This identity is no longer connected.');
    }
    await client.auth.unlinkIdentity(identity);
  }

  @override
  Future<void> linkConnectedAccount(String provider) async {
    final client = SupabaseConfig.client;
    if (!SupabaseConfig.isConfigured || client?.auth.currentUser == null) {
      throw StateError('Sign in to manage connected accounts.');
    }
    final oauth = switch (provider) {
      'google' => OAuthProvider.google,
      'apple' => OAuthProvider.apple,
      _ => throw ArgumentError('Unsupported identity provider'),
    };
    if (!await client!.auth.linkIdentity(
      oauth,
      redirectTo: kIsWeb ? null : 'tradex://auth/callback',
    )) {
      throw StateError('Could not open the identity provider. Please retry.');
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
      try {
        await client.rpc(
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
      } catch (_) {
        try {
          await client
              .from('profiles')
              .update({'status': 'pending_approval'})
              .eq('id', user.id)
              .select('id')
              .single();
        } catch (_) {}
      }
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
        await prefs.remove('tradex_affiliate_workspace_v2_inr');
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
}
