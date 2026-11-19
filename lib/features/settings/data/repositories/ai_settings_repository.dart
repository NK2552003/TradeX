import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/features/copilot/data/copilot_controller.dart';
import 'package:alphajournal/features/settings/models/ai_settings_model.dart';

abstract class AiSettingsRepository extends ChangeNotifier {
  AiSettingsModel get cachedSettings;
  String? get lastSyncError => null;
  bool get hasCloudPreferences => false;
  Future<AiSettingsModel> getSettings({CopilotController? copilotController});
  Future<AiSettingsModel> updateSettings(
    AiSettingsModel settings, {
    CopilotController? copilotController,
    bool syncCopilotWorkspace = true,
  });
  Future<void> syncCopilotWorkspace(
    CopilotController copilotController,
  ) async {}
}

/// Persistent store for AI & Copilot settings, bridging `SharedPreferences`,
/// Supabase `user_app_preferences`, and the live `CopilotController` workspace.
class AiSettingsRepositoryImpl extends AiSettingsRepository {
  static const String _prefsKey = 'alphajournal_ai_settings_v1';

  static final AiSettingsRepositoryImpl instance = AiSettingsRepositoryImpl._();
  AiSettingsRepositoryImpl._() {
    unawaited(_hydrateLocal());
  }
  factory AiSettingsRepositoryImpl() => instance;

  AiSettingsModel _cached = const AiSettingsModel();
  String? _cachedUserId;
  String? _lastSyncError;
  bool _hasCloudPreferences = false;
  bool _hasExplicitCloudRow = false;

  @override
  AiSettingsModel get cachedSettings => _cached;

  @override
  String? get lastSyncError => _lastSyncError;

  @override
  bool get hasCloudPreferences => _hasCloudPreferences;

  String _storageKeyFor(String? uid) =>
      (uid == null || uid.isEmpty) ? _prefsKey : '${_prefsKey}_$uid';

  String? _activeUserId() => SupabaseConfig.isConfigured
      ? SupabaseConfig.client?.auth.currentUser?.id
      : null;

  void _ensureAccountScope(String? uid) {
    if (_cachedUserId == uid) return;
    _cachedUserId = uid;
    _cached = const AiSettingsModel();
    _lastSyncError = null;
    _hasCloudPreferences = false;
    _hasExplicitCloudRow = false;
  }

  static String _describeSyncError(Object error) {
    if (error is PostgrestException) {
      final combined =
          '${error.code ?? ''} ${error.message} ${error.details ?? ''}';
      if (combined.contains('PGRST205') ||
          combined.contains('42P01') ||
          combined.contains('user_app_preferences')) {
        return 'Supabase preferences table (user_app_preferences) is not deployed yet. Apply migration 20261116000000_user_device_sessions.sql.';
      }
      return error.message;
    }
    if (error is AuthException) {
      return error.message;
    }
    return '$error';
  }

  Future<void> _hydrateLocal() async {
    try {
      final uid = _activeUserId();
      _ensureAccountScope(uid);
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_storageKeyFor(uid)) ?? sp.getString(_prefsKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _cached = AiSettingsModel.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> _persistLocal(AiSettingsModel settings, {String? uid}) async {
    try {
      final effectiveUid = uid ?? _activeUserId();
      final sp = await SharedPreferences.getInstance();
      final encoded = jsonEncode(settings.toJson());
      await sp.setString(_storageKeyFor(effectiveUid), encoded);
      if (effectiveUid == null || effectiveUid.isEmpty) {
        await sp.setString(_prefsKey, encoded);
      }
    } catch (_) {}
  }

  bool _workspaceNeedsSettings(
    Map<String, dynamic> current,
    Map<String, dynamic> target,
  ) {
    for (final entry in target.entries) {
      if (current[entry.key] != entry.value) return true;
    }
    return false;
  }

  Future<void> _pushToCopilotWorkspace(
    CopilotController copilotController,
    AiSettingsModel settings, {
    bool refreshAfter = false,
  }) async {
    final payload = settings.toWorkspaceSettingsPayload();
    copilotController.applyLocalSettings(payload);
    if (!copilotController.connected) return;
    try {
      await copilotController.action(
        {'action': 'settings.save', ...payload},
        refresh: refreshAfter,
        reportError: false,
      );
    } catch (e) {
      debugPrint('[AiSettingsRepository] Copilot workspace sync info: $e');
      _lastSyncError ??=
          'Preferences saved to your account, but Copilot workspace sync failed: $e';
    }
  }

  @override
  Future<void> syncCopilotWorkspace(CopilotController copilotController) async {
    if (!copilotController.connected) return;
    if (_hasExplicitCloudRow) {
      final payload = _cached.toWorkspaceSettingsPayload();
      if (_workspaceNeedsSettings(
        copilotController.workspace.settings,
        payload,
      )) {
        await _pushToCopilotWorkspace(
          copilotController,
          _cached,
          refreshAfter: true,
        );
      }
    } else if (copilotController.workspace.settings.isNotEmpty) {
      _cached = _cached.mergeWorkspaceSettings(
        copilotController.workspace.settings,
      );
      await _persistLocal(_cached);
    }
    notifyListeners();
  }

  @override
  Future<AiSettingsModel> getSettings({
    CopilotController? copilotController,
  }) async {
    final uid = _activeUserId();
    _ensureAccountScope(uid);
    await _hydrateLocal();

    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client;
      if (client != null && uid != null) {
        try {
          final row = await client
              .from('user_app_preferences')
              .select('ai_settings')
              .eq('user_id', uid)
              .maybeSingle();
          _lastSyncError = null;
          _hasCloudPreferences = true;
          final rawAi = row?['ai_settings'];
          if (rawAi is Map && rawAi.isNotEmpty) {
            _hasExplicitCloudRow = true;
            _cached = AiSettingsModel.fromJson(
              Map<String, dynamic>.from(rawAi),
            );
            await _persistLocal(_cached, uid: uid);
          } else {
            _hasExplicitCloudRow = false;
          }
        } catch (e) {
          _hasCloudPreferences = false;
          _lastSyncError = _describeSyncError(e);
          debugPrint('[AiSettingsRepository] getSettings warning: $e');
        }
      }
    }

    if (copilotController != null) {
      if (_hasExplicitCloudRow) {
        await _pushToCopilotWorkspace(
          copilotController,
          _cached,
          refreshAfter: false,
        );
      } else if (copilotController.connected) {
        _cached = _cached.mergeWorkspaceSettings(
          copilotController.workspace.settings,
        );
        await _persistLocal(_cached, uid: uid);
      } else {
        copilotController.applyLocalSettings(
          _cached.toWorkspaceSettingsPayload(),
        );
      }
    }

    notifyListeners();
    return _cached;
  }

  @override
  Future<AiSettingsModel> updateSettings(
    AiSettingsModel settings, {
    CopilotController? copilotController,
    bool syncCopilotWorkspace = true,
  }) async {
    final uid = _activeUserId();
    _ensureAccountScope(uid);
    _cached = settings;
    _lastSyncError = null;
    notifyListeners();
    await _persistLocal(settings, uid: uid);

    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client;
      if (client != null && uid != null) {
        try {
          await client.from('user_app_preferences').upsert({
            'user_id': uid,
            'ai_settings': settings.toJson(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
          _hasCloudPreferences = true;
          _hasExplicitCloudRow = true;
        } catch (e) {
          _hasCloudPreferences = false;
          _lastSyncError = _describeSyncError(e);
          debugPrint('[AiSettingsRepository] Supabase save warning: $e');
        }
      }
    }

    if (syncCopilotWorkspace && copilotController != null) {
      final payload = settings.toWorkspaceSettingsPayload();
      copilotController.applyLocalSettings(payload);
      if (copilotController.connected || !SupabaseConfig.isConfigured) {
        try {
          await copilotController.action(
            {'action': 'settings.save', ...payload},
            refresh: true,
            reportError: false,
          );
        } catch (e) {
          debugPrint('[AiSettingsRepository] Copilot workspace sync info: $e');
          _lastSyncError ??=
              'Saved locally, but Copilot workspace sync failed: $e';
        }
      }
    }

    notifyListeners();
    return _cached;
  }
}
