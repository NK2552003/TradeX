import 'package:flutter/foundation.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/features/auth/data/services/auth_backend_service.dart';
import 'package:alphajournal/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/settings/models/desk_risk_model.dart';

abstract class DeskRiskRepository {
  Future<DeskRiskModel> getDeskRiskConfig();
  Future<DeskRiskModel> updateDeskRiskConfig(DeskRiskModel updated);
}

class DeskRiskRepositoryImpl implements DeskRiskRepository {
  DeskRiskModel _config = DeskRiskModel.defaultConfig();

  String _resolveUserId() =>
      SupabaseConfig.client?.auth.currentUser?.id ??
      SupabaseAuthBackendService.instance.currentUserProfile?.id ??
      AuthBackendService.instance.currentUserProfile?.id ??
      '';

  Future<bool> _isCurrentUserAdmin() async {
    final profile =
        SupabaseAuthBackendService.instance.currentUserProfile ??
        AuthBackendService.instance.currentUserProfile;
    if (profile != null) {
      return profile.role == UserRole.userAdmin;
    }

    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client;
      final userId = client?.auth.currentUser?.id;
      if (client != null && userId != null && userId.isNotEmpty) {
        try {
          final isAdminRes = await client.rpc('is_admin');
          if (isAdminRes is bool) {
            return isAdminRes;
          }
        } catch (_) {}

        try {
          final row = await client
              .from('profiles')
              .select('role')
              .eq('id', userId)
              .maybeSingle();
          final role = row?['role']?.toString();
          return role == UserRole.userAdmin.id || role == 'admin';
        } catch (_) {}
      }
    }

    return false;
  }

  @override
  Future<DeskRiskModel> getDeskRiskConfig() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _resolveUserId();
        if (targetUserId.isEmpty) return _config;

        try {
          final configRow = await client
              .from('desk_risk_configs')
              .select(
                'id, firm_name, base_currency, max_firm_leverage, '
                'max_daily_loss_percent, max_total_drawdown_percent, '
                'circuit_breaker_threshold_percent, auto_freeze_on_breach, '
                'allow_crypto, allow_options, require_manager_order_approval, '
                'approval_threshold_inr, updated_by, updated_at',
              )
              .order('updated_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (configRow != null) {
            _config = DeskRiskModel.fromJson(configRow);
            return _config;
          }
        } catch (_) {}

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
    final bool isAdmin = await _isCurrentUserAdmin();
    if (!isAdmin) {
      throw StateError(
        'Only administrators can modify desk risk configuration.',
      );
    }

    final targetUserId = _resolveUserId();
    if (targetUserId.isEmpty) {
      throw StateError(
        'Authenticated administrator session required to update desk risk configuration.',
      );
    }

    _config = updated;
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final nowIso = DateTime.now().toUtc().toIso8601String();
        final configPayload = <String, dynamic>{
          ...updated.toJson(),
          'updated_by': targetUserId,
          'updated_at': nowIso,
        };

        try {
          await client.from('desk_risk_configs').upsert(configPayload);
        } catch (_) {
          final policyPayload = <String, dynamic>{
            ...updated.toJson(),
            'admin_id': targetUserId,
            'updated_at': nowIso,
          };
          await client.from('desk_risk_policies').upsert(policyPayload);
        }
      } catch (e) {
        debugPrint('DeskRiskRepositoryImpl.updateDeskRiskConfig error: $e');
        rethrow;
      }
    }
    return _config;
  }
}
