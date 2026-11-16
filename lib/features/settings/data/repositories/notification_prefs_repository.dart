import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/settings/models/notification_prefs_model.dart';

abstract class NotificationPrefsRepository {
  Future<NotificationPrefsModel> getPreferences();
  Future<NotificationPrefsModel> updatePreferences(
    NotificationPrefsModel prefs,
  );
}

class NotificationPrefsRepositoryImpl implements NotificationPrefsRepository {
  static final NotificationPrefsRepositoryImpl instance =
      NotificationPrefsRepositoryImpl._();

  NotificationPrefsRepositoryImpl._();

  factory NotificationPrefsRepositoryImpl() => instance;

  static const String _cacheKeyPrefix = 'tradex_notification_prefs_v1:';

  NotificationPrefsModel _prefs = NotificationPrefsModel.defaultPrefs();
  final ValueNotifier<NotificationPrefsModel> notifier =
      ValueNotifier<NotificationPrefsModel>(
        NotificationPrefsModel.defaultPrefs(),
      );

  NotificationPrefsModel get cachedPreferences => _prefs;

  String get _targetUserId =>
      SupabaseConfig.client?.auth.currentUser?.id ??
      SupabaseAuthBackendService.instance.currentUserProfile?.id ??
      '';

  String get _storageKey =>
      '$_cacheKeyPrefix${_targetUserId.isEmpty ? 'local' : _targetUserId}';

  Future<void> _saveLocalCache(NotificationPrefsModel prefs) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_storageKey, jsonEncode(prefs.toJson()));
    } catch (_) {}
  }

  Future<NotificationPrefsModel?> _loadLocalCache() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_storageKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return NotificationPrefsModel.fromJson(decoded);
      }
      if (decoded is Map) {
        return NotificationPrefsModel.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {}
    return null;
  }

  void _applyPrefs(NotificationPrefsModel prefs) {
    _prefs = prefs;
    notifier.value = prefs;
  }

  /// Evaluates whether an incoming live notification banner/toast should be
  /// surfaced according to the trader's push category switches and Quiet Hours.
  bool shouldSurfaceInApp(CommunityNotificationType type, {DateTime? now}) {
    if (type == CommunityNotificationType.security ||
        type == CommunityNotificationType.system) {
      return true;
    }

    final category = switch (type) {
      CommunityNotificationType.tradeExecution ||
      CommunityNotificationType.marginAlert => 'trade',
      CommunityNotificationType.signal => 'price_alert',
      CommunityNotificationType.message => 'message',
      CommunityNotificationType.like ||
      CommunityNotificationType.comment ||
      CommunityNotificationType.reply ||
      CommunityNotificationType.repost ||
      CommunityNotificationType.follow ||
      CommunityNotificationType.mention => 'community',
      CommunityNotificationType.security ||
      CommunityNotificationType.system => 'system',
    };

    if (_prefs.pushByCategory[category] == false) {
      return false;
    }

    if (_prefs.quietHoursEnabled &&
        isWithinQuietHours(
          now ?? DateTime.now(),
          start: _prefs.quietHoursStart,
          end: _prefs.quietHoursEnd,
        )) {
      return false;
    }

    return true;
  }

  static bool isWithinQuietHours(
    DateTime when, {
    required String? start,
    required String? end,
  }) {
    final startMin = _parseMinutes(start);
    final endMin = _parseMinutes(end);
    if (startMin == null || endMin == null || startMin == endMin) {
      return false;
    }
    final curMin = when.hour * 60 + when.minute;
    if (startMin < endMin) {
      return curMin >= startMin && curMin < endMin;
    }
    return curMin >= startMin || curMin < endMin;
  }

  static int? _parseMinutes(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }

  @override
  Future<NotificationPrefsModel> getPreferences() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _targetUserId;
        if (targetUserId.isEmpty) {
          final cached = await _loadLocalCache();
          if (cached != null) _applyPrefs(cached);
          return _prefs;
        }

        final data = await client
            .from('trader_preferences')
            .select('notification_settings')
            .eq('user_id', targetUserId)
            .maybeSingle();

        if (data != null && data['notification_settings'] != null) {
          final settingsMap =
              data['notification_settings'] as Map<String, dynamic>;
          if (settingsMap.isNotEmpty) {
            final parsed = NotificationPrefsModel.fromJson(settingsMap);
            _applyPrefs(parsed);
            await _saveLocalCache(parsed);
            return _prefs;
          }
        }
      } catch (e) {
        debugPrint('NotificationPrefsRepositoryImpl.getPreferences error: $e');
      }
    }
    final local = await _loadLocalCache();
    if (local != null) {
      _applyPrefs(local);
    }
    return _prefs;
  }

  @override
  Future<NotificationPrefsModel> updatePreferences(
    NotificationPrefsModel prefs,
  ) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _targetUserId;
        if (targetUserId.isEmpty) {
          throw StateError('Sign in to save preferences.');
        }

        await client.from('trader_preferences').upsert({
          'user_id': targetUserId,
          'notification_settings': prefs.toJson(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Notification preferences could not be saved: $e');
        rethrow;
      }
    }
    _applyPrefs(prefs);
    await _saveLocalCache(prefs);
    return _prefs;
  }
}
