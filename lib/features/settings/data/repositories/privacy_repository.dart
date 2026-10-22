import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/settings/models/privacy_settings_model.dart';

abstract class PrivacyRepository {
  Future<PrivacySettingsModel> getPrivacySettings();
  Future<void> setPublicJournalsDefault(bool enabled);
  Future<void> setPublicStatsEnabled(bool enabled);
  Future<List<AppTrader>> getBlockedUsers();
  Future<void> unblockUser(String userId);
  Future<DataExportRequest> requestDataExport();
  Future<DataExportRequest> getDataExportStatus();
}

class PrivacyRepositoryImpl implements PrivacyRepository {
  PrivacyRepositoryImpl() {
    if (!CustomerDataPolicy.allowDemo) _blockedUsers.clear();
  }
  static const String _demoUserId = '00000000-0000-0000-0000-000000000001';

  PrivacySettingsModel _settings = const PrivacySettingsModel(
    publicJournals: true,
    publicStatsEnabled: false,
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
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? _demoUserId;

        final res = await client
            .from('profiles')
            .select('public_journals, public_stats')
            .eq('id', targetUserId)
            .maybeSingle();

        if (res != null) {
          _settings = PrivacySettingsModel(
            publicJournals: res['public_journals'] as bool? ?? true,
            publicStatsEnabled: res['public_stats'] as bool? ?? false,
          );
          return _settings;
        }
      } catch (e) {
        debugPrint('PrivacyRepositoryImpl.getPrivacySettings error: $e');
      }
    }
    return _settings;
  }

  @override
  Future<void> setPublicJournalsDefault(bool enabled) async {
    _settings = _settings.copyWith(publicJournals: enabled);
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? _demoUserId;

        await client
            .from('profiles')
            .update({
              'public_journals': enabled,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', targetUserId);
      } catch (e) {
        debugPrint('PrivacyRepositoryImpl.setPublicJournalsDefault error: $e');
      }
    }
  }

  @override
  Future<void> setPublicStatsEnabled(bool enabled) async {
    _settings = _settings.copyWith(publicStatsEnabled: enabled);
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? _demoUserId;

        await client
            .from('profiles')
            .update({
              'public_stats': enabled,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', targetUserId);
      } catch (e) {
        debugPrint('PrivacyRepositoryImpl.setPublicStatsEnabled error: $e');
      }
    }
  }

  @override
  Future<List<AppTrader>> getBlockedUsers() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? _demoUserId;

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
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? _demoUserId;

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
