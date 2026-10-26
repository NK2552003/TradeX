import 'package:flutter/foundation.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:tradex/features/settings/models/notification_prefs_model.dart';

abstract class NotificationPrefsRepository {
  Future<NotificationPrefsModel> getPreferences();
  Future<NotificationPrefsModel> updatePreferences(
    NotificationPrefsModel prefs,
  );
}

class NotificationPrefsRepositoryImpl implements NotificationPrefsRepository {
  NotificationPrefsModel _prefs = NotificationPrefsModel.defaultPrefs();

  String get _targetUserId =>
      SupabaseConfig.client?.auth.currentUser?.id ??
      SupabaseAuthBackendService.instance.currentUserProfile?.id ??
      '';

  @override
  Future<NotificationPrefsModel> getPreferences() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _targetUserId;
        if (targetUserId.isEmpty) return _prefs;

        final data = await client
            .from('trader_preferences')
            .select('notification_settings')
            .eq('user_id', targetUserId)
            .maybeSingle();

        if (data != null && data['notification_settings'] != null) {
          final settingsMap =
              data['notification_settings'] as Map<String, dynamic>;
          if (settingsMap.isNotEmpty) {
            _prefs = NotificationPrefsModel.fromJson(settingsMap);
            return _prefs;
          }
        }
      } catch (e) {
        debugPrint('NotificationPrefsRepositoryImpl.getPreferences error: $e');
      }
    }
    return _prefs;
  }

  @override
  Future<NotificationPrefsModel> updatePreferences(
    NotificationPrefsModel prefs,
  ) async {
    _prefs = prefs;
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _targetUserId;
        if (targetUserId.isEmpty) return _prefs;

        await client.from('trader_preferences').upsert({
          'user_id': targetUserId,
          'notification_settings': prefs.toJson(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint(
          'NotificationPrefsRepositoryImpl.updatePreferences error: $e',
        );
      }
    }
    return _prefs;
  }
}
