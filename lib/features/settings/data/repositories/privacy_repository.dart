import 'package:flutter/foundation.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:tradex/features/settings/models/privacy_settings_model.dart';

abstract class PrivacyRepository {
  Future<PrivacySettingsModel> getPrivacySettings();
  Future<void> setPublicJournalsDefault(bool enabled);
  Future<void> setPublicStatsEnabled(bool enabled);
  Future<void> setMessagePermission(String permission);
  Future<void> setAllowMessageRequests(bool enabled);
  Future<void> setShowReadReceipts(bool enabled);
  Future<void> setShowActivityStatus(bool enabled);
  Future<void> setFilterSpamRequests(bool enabled);
  Future<List<AppTrader>> getBlockedUsers();
  Future<void> unblockUser(String userId);
  Future<DataExportRequest> requestDataExport();
  Future<DataExportRequest> getDataExportStatus();
}

class PrivacyRepositoryImpl implements PrivacyRepository {
  static final PrivacyRepositoryImpl instance = PrivacyRepositoryImpl._();

  PrivacyRepositoryImpl._() {
    _blockedUsers.clear();
  }

  factory PrivacyRepositoryImpl() => instance;

  String _resolveUserId() =>
      SupabaseConfig.client?.auth.currentUser?.id ??
      SupabaseAuthBackendService.instance.currentUserProfile?.id ??
      '';

  PrivacySettingsModel _settings = const PrivacySettingsModel(
    publicJournals: true,
    publicStatsEnabled: true,
  );

  final List<AppTrader> _blockedUsers = <AppTrader>[
    const AppTrader(
      id: 'blk_1',
      handle: 'spammer_bot99',
      displayName: 'Free Signals Official',
      bio: 'DM for 1000% daily returns telegram link',
      tier: AppTier.free,
    ),
    const AppTrader(
      id: 'blk_2',
      handle: 'toxic_scalper',
      displayName: 'Rage Trader',
      bio: 'Crypto maximalist. No DMs.',
      tier: AppTier.free,
    ),
  ];

  DataExportRequest _exportRequest = DataExportRequest(
    status: 'none',
    requestedAt: DateTime.now(),
  );

  @override
  Future<PrivacySettingsModel> getPrivacySettings() async {
    final profile = await ProfileSettingsRepositoryImpl.instance.getProfile();
    _settings = _settings.copyWith(
      publicJournals: profile.publicJournals,
      publicStatsEnabled: profile.publicStats,
    );
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _resolveUserId();
        if (targetUserId.isEmpty) return _settings;

        final res = await client
            .from('profiles')
            .select()
            .eq('id', targetUserId)
            .maybeSingle();

        if (res != null) {
          final notif = res['notification_settings'] is Map
              ? Map<String, dynamic>.from(res['notification_settings'] as Map)
              : <String, dynamic>{};
          final msgPriv = notif['message_privacy'] is Map
              ? Map<String, dynamic>.from(notif['message_privacy'] as Map)
              : <String, dynamic>{};
          _settings = PrivacySettingsModel(
            publicJournals: profile.publicJournals,
            publicStatsEnabled: profile.publicStats,
            messagePermission:
                msgPriv['message_permission'] as String? ??
                _settings.messagePermission,
            allowMessageRequests:
                msgPriv['allow_message_requests'] as bool? ??
                _settings.allowMessageRequests,
            showReadReceipts:
                msgPriv['show_read_receipts'] as bool? ??
                _settings.showReadReceipts,
            showActivityStatus:
                msgPriv['show_activity_status'] as bool? ??
                _settings.showActivityStatus,
            filterSpamRequests:
                msgPriv['filter_spam_requests'] as bool? ??
                _settings.filterSpamRequests,
          );
          return _settings;
        }
      } catch (e) {
        debugPrint('PrivacyRepositoryImpl.getPrivacySettings error: $e');
      }
    }
    return _settings;
  }

  Future<void> _persistMessagePrivacy() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _resolveUserId();
        if (targetUserId.isEmpty) return;

        final res = await client
            .from('profiles')
            .select('notification_settings')
            .eq('id', targetUserId)
            .maybeSingle();

        final notif = Map<String, dynamic>.from(
          res?['notification_settings'] as Map<String, dynamic>? ?? {},
        );
        notif['message_privacy'] = {
          'message_permission': _settings.messagePermission,
          'allow_message_requests': _settings.allowMessageRequests,
          'show_read_receipts': _settings.showReadReceipts,
          'show_activity_status': _settings.showActivityStatus,
          'filter_spam_requests': _settings.filterSpamRequests,
        };

        await client
            .from('profiles')
            .update({
              'notification_settings': notif,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', targetUserId);
      } catch (e) {
        debugPrint('PrivacyRepositoryImpl._persistMessagePrivacy error: $e');
      }
    }
  }

  @override
  Future<void> setMessagePermission(String permission) async {
    _settings = _settings.copyWith(messagePermission: permission);
    await _persistMessagePrivacy();
  }

  @override
  Future<void> setAllowMessageRequests(bool enabled) async {
    _settings = _settings.copyWith(allowMessageRequests: enabled);
    await _persistMessagePrivacy();
  }

  @override
  Future<void> setShowReadReceipts(bool enabled) async {
    _settings = _settings.copyWith(showReadReceipts: enabled);
    await _persistMessagePrivacy();
  }

  @override
  Future<void> setShowActivityStatus(bool enabled) async {
    _settings = _settings.copyWith(showActivityStatus: enabled);
    await _persistMessagePrivacy();
  }

  @override
  Future<void> setFilterSpamRequests(bool enabled) async {
    _settings = _settings.copyWith(filterSpamRequests: enabled);
    await _persistMessagePrivacy();
  }

  @override
  Future<void> setPublicJournalsDefault(bool enabled) async {
    _settings = _settings.copyWith(publicJournals: enabled);
    await ProfileSettingsRepositoryImpl.instance.updateProfile(
      publicJournalsEnabled: enabled,
    );
  }

  @override
  Future<void> setPublicStatsEnabled(bool enabled) async {
    _settings = _settings.copyWith(publicStatsEnabled: enabled);
    await ProfileSettingsRepositoryImpl.instance.updateProfile(
      publicStatsEnabled: enabled,
    );
  }

  @override
  Future<List<AppTrader>> getBlockedUsers() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _resolveUserId();
        if (targetUserId.isEmpty) return _blockedUsers;

        final res = await client
            .from('blocks')
            .select(
              'blocked_id, profiles!blocks_blocked_id_fkey(handle, display_name, bio, subscription_tier)',
            )
            .eq('blocker_id', targetUserId);

        if ((res as List).isNotEmpty) {
          final list = <AppTrader>[];
          for (final item in res) {
            final profileMap = item['profiles'] as Map<String, dynamic>? ?? {};
            final tierStr =
                profileMap['subscription_tier'] as String? ?? 'free';
            final tier = AppTier.values.firstWhere(
              (t) => t.name == tierStr,
              orElse: () => AppTier.free,
            );
            list.add(
              AppTrader(
                id: item['blocked_id'] as String,
                handle: profileMap['handle'] as String? ?? 'user',
                displayName:
                    profileMap['display_name'] as String? ??
                    profileMap['handle'] as String? ??
                    'User',
                bio: profileMap['bio'] as String? ?? '',
                tier: tier,
              ),
            );
          }
          return list;
        }
      } catch (e) {
        debugPrint('PrivacyRepositoryImpl.getBlockedUsers error: $e');
      }
    }
    return List<AppTrader>.from(_blockedUsers);
  }

  @override
  Future<void> unblockUser(String userId) async {
    _blockedUsers.removeWhere((u) => u.id == userId);
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _resolveUserId();
        if (targetUserId.isEmpty) return;

        await client
            .from('blocks')
            .delete()
            .eq('blocker_id', targetUserId)
            .eq('blocked_id', userId);
      } catch (e) {
        debugPrint('PrivacyRepositoryImpl.unblockUser error: $e');
      }
    }
  }

  @override
  Future<DataExportRequest> requestDataExport() async {
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;
    if (!SupabaseConfig.isConfigured || client == null || user == null) {
      throw StateError('Data export is not available in this environment.');
    }
    final row = await client
        .from('data_export_requests')
        .insert({
          'user_id': user.id,
          'status': 'pending',
          'requested_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    _exportRequest = DataExportRequest.fromJson(row);
    return _exportRequest;
  }

  @override
  Future<DataExportRequest> getDataExportStatus() async {
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;
    if (!SupabaseConfig.isConfigured || client == null || user == null) {
      return _exportRequest;
    }
    final row = await client
        .from('data_export_requests')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row != null) _exportRequest = DataExportRequest.fromJson(row);
    return _exportRequest;
  }
}
