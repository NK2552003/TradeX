import 'package:flutter/foundation.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:tradex/features/settings/models/desk_risk_model.dart';

abstract class DeskRiskRepository {
  Future<DeskRiskModel> getDeskRiskConfig();
  Future<DeskRiskModel> updateDeskRiskConfig(DeskRiskModel updated);
}

class DeskRiskRepositoryImpl implements DeskRiskRepository {
  DeskRiskModel _config = DeskRiskModel.defaultConfig();

  String _resolveUserId() =>
      SupabaseConfig.client?.auth.currentUser?.id ??
      SupabaseAuthBackendService.instance.currentUserProfile?.id ??
      '';

  @override
  Future<DeskRiskModel> getDeskRiskConfig() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _resolveUserId();
        if (targetUserId.isEmpty) return _config;

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
        final targetUserId = _resolveUserId();
        if (targetUserId.isEmpty) return _config;

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
