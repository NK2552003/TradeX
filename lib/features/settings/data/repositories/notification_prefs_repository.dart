import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/settings/models/notification_prefs_model.dart';

abstract class NotificationPrefsRepository {
  Future<NotificationPrefsModel> getPreferences();
  Future<NotificationPrefsModel> updatePreferences(
    NotificationPrefsModel prefs,
  );
}

class NotificationPrefsRepositoryImpl implements NotificationPrefsRepository {
  NotificationPrefsModel _prefs = NotificationPrefsModel.defaultPrefs();

  SupabaseClient? get _client {
    if (SupabaseConfig.isConfigured) {
      try {
        return SupabaseConfig.client;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String? get _currentUserId => _client?.auth.currentUser?.id;

  @override
  Future<NotificationPrefsModel> getPreferences() async {
    final client = _client;
    final userId = _currentUserId;

    if (client != null && userId != null) {
      try {
        final data = await client
            .from('trader_preferences')
            .select('notification_settings')
            .eq('user_id', userId)
            .maybeSingle();

        if (data != null && data['notification_settings'] != null) {
          final settingsMap = data['notification_settings'] as Map<String, dynamic>;
          if (settingsMap.isNotEmpty) {
            _prefs = NotificationPrefsModel.fromJson(settingsMap);
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
    final client = _client;
    final userId = _currentUserId;

    if (client != null && userId != null) {
      try {
        await client.from('trader_preferences').upsert({
          'user_id': userId,
          'notification_settings': prefs.toJson(),
        });
      } catch (e) {
        debugPrint('NotificationPrefsRepositoryImpl.updatePreferences error: $e');
      }
    }
    return _prefs;
  }
}
