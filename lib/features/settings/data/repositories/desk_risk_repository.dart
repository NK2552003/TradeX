import 'package:flutter/foundation.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/settings/models/desk_risk_model.dart';

abstract class DeskRiskRepository {
  Future<DeskRiskModel> getDeskRiskConfig();
  Future<DeskRiskModel> updateDeskRiskConfig(DeskRiskModel updated);
}

class DeskRiskRepositoryImpl implements DeskRiskRepository {
  static const String _demoUserId = '00000000-0000-0000-0000-000000000001';
  DeskRiskModel _config = DeskRiskModel.defaultConfig();

  @override
  Future<DeskRiskModel> getDeskRiskConfig() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? _demoUserId;

        final data = await client
            .from('desk_risk_policies')
            .select('*')
            .eq('admin_id', targetUserId)
            .maybeSingle();

        if (data != null) {
          _config = DeskRiskModel.fromJson(data);
          return _config;
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
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? _demoUserId;

        final jsonMap = updated.toJson();
        jsonMap['admin_id'] = targetUserId;
        jsonMap['updated_at'] = DateTime.now().toIso8601String();

        await client.from('desk_risk_policies').upsert(jsonMap);
      } catch (e) {
        debugPrint('DeskRiskRepositoryImpl.updateDeskRiskConfig error: $e');
      }
    }
    return _config;
  }
}
