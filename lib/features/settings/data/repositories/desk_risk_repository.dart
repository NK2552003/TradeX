import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/settings/models/desk_risk_model.dart';

abstract class DeskRiskRepository {
  Future<DeskRiskModel> getDeskRiskConfig();
  Future<DeskRiskModel> updateDeskRiskConfig(DeskRiskModel updated);
}

class DeskRiskRepositoryImpl implements DeskRiskRepository {
  DeskRiskModel _config = DeskRiskModel.defaultConfig();

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
  Future<DeskRiskModel> getDeskRiskConfig() async {
    final client = _client;
    final userId = _currentUserId;
    if (client != null && userId != null) {
      try {
        final data = await client
            .from('desk_risk_policies')
            .select('*')
            .eq('admin_id', userId)
            .maybeSingle();

        if (data != null) {
          _config = DeskRiskModel.fromJson(data);
        }
      } catch (e) {
        debugPrint('DeskRiskRepositoryImpl.getDeskRiskConfig error: $e');
      }
    }
    return _config;
  }

  @override
  Future<DeskRiskModel> updateDeskRiskConfig(DeskRiskModel updated) async {
    _config = updated;
    final client = _client;
    final userId = _currentUserId;

    if (client != null && userId != null) {
      try {
        final jsonMap = updated.toJson();
        jsonMap['admin_id'] = userId;
        await client.from('desk_risk_policies').upsert(jsonMap);
      } catch (e) {
        debugPrint('DeskRiskRepositoryImpl.updateDeskRiskConfig error: $e');
      }
    }
    return _config;
  }
}
