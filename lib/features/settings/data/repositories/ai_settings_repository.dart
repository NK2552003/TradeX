import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/copilot/data/copilot_controller.dart';
import 'package:tradex/features/settings/models/ai_settings_model.dart';

abstract class AiSettingsRepository extends ChangeNotifier {
  AiSettingsModel get cachedSettings;
  Future<AiSettingsModel> getSettings({CopilotController? copilotController});
  Future<AiSettingsModel> updateSettings(
    AiSettingsModel settings, {
    CopilotController? copilotController,
    bool syncCopilotWorkspace = true,
  });
}

/// Persistent store for AI & Copilot settings, bridging `SharedPreferences`,
/// Supabase `user_app_preferences`, and the live `CopilotController` workspace.
class AiSettingsRepositoryImpl extends AiSettingsRepository {
  static const String _prefsKey = 'tradex_ai_settings_v1';

  static final AiSettingsRepositoryImpl instance = AiSettingsRepositoryImpl._();
  AiSettingsRepositoryImpl._() {
    unawaited(_hydrateLocal());
  }
  factory AiSettingsRepositoryImpl() => instance;

  AiSettingsModel _cached = const AiSettingsModel();

  @override
  AiSettingsModel get cachedSettings => _cached;

  Future<void> _hydrateLocal() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_prefsKey);
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

  Future<void> _persistLocal(AiSettingsModel settings) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_prefsKey, jsonEncode(settings.toJson()));
    } catch (_) {}
  }

  @override
  Future<AiSettingsModel> getSettings({
    CopilotController? copilotController,
  }) async {
    await _hydrateLocal();

    if (copilotController != null && copilotController.connected) {
      _cached = _cached.mergeWorkspaceSettings(
        copilotController.workspace.settings,
      );
    }

    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client;
      final uid = client?.auth.currentUser?.id;
      if (client != null && uid != null) {
        try {
          final row = await client
              .from('user_app_preferences')
              .select('ai_settings')
              .eq('user_id', uid)
              .maybeSingle();
          final rawAi = row?['ai_settings'];
          if (rawAi is Map && rawAi.isNotEmpty) {
            _cached = AiSettingsModel.fromJson(
              Map<String, dynamic>.from(rawAi),
            );
            if (copilotController != null && copilotController.connected) {
              _cached = _cached.mergeWorkspaceSettings(
                copilotController.workspace.settings,
              );
            }
            await _persistLocal(_cached);
          }
        } catch (e) {
          debugPrint('[AiSettingsRepository] getSettings warning: $e');
        }
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
    _cached = settings;
    notifyListeners();
    await _persistLocal(settings);

    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client;
      final uid = client?.auth.currentUser?.id;
      if (client != null && uid != null) {
        try {
          await client.from('user_app_preferences').upsert({
            'user_id': uid,
            'ai_settings': settings.toJson(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (e) {
          debugPrint('[AiSettingsRepository] Supabase save warning: $e');
        }
      }
    }

    if (syncCopilotWorkspace && copilotController != null) {
      final payload = settings.toWorkspaceSettingsPayload();
      copilotController.applyLocalSettings(payload);
      try {
        await copilotController.action(
          {'action': 'settings.save', ...payload},
          refresh: true,
          reportError: false,
        );
      } catch (e) {
        // Keep the saved local/cloud settings active even if an offline worker
        // isn't running yet; workspace UI reflects applyLocalSettings().
        debugPrint('[AiSettingsRepository] Copilot workspace sync info: $e');
      }
    }

    return _cached;
  }
}
