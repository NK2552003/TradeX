import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/config/supabase_config.dart';

import '../models/admin_records.dart';

/// All administration reads and writes are checked against the caller's live
/// profile in PostgreSQL. There is intentionally no local or sample fallback.
class AdminRepository {
  AdminRepository({this._client});
  static final instance = AdminRepository();
  final SupabaseClient? _client;

  SupabaseClient get client {
    final result = _client ?? SupabaseConfig.client;
    if (result == null || result.auth.currentUser == null) {
      throw StateError('Sign in with an administrator account to continue.');
    }
    return result;
  }

  String? get currentUserId =>
      (_client ?? SupabaseConfig.client)?.auth.currentUser?.id;

  Future<Map<String, dynamic>> _rpc(
    String name, [
    Map<String, dynamic> params = const {},
  ]) async {
    final result = await client.rpc(name, params: params);
    if (result is! Map) {
      throw const FormatException(
        'The server returned an invalid administration response.',
      );
    }
    return Map<String, dynamic>.from(result);
  }

  Future<AdminPageData> list(
    AdminResource resource, {
    String? userId,
    String search = '',
    String status = 'all',
    int page = 0,
    int pageSize = 25,
    DateTime? from,
    DateTime? to,
    String? parentId,
  }) async => AdminPageData.fromJson(
    await _rpc('admin_list_records', {
      'p_resource': resource.apiName,
      'p_user': userId,
      'p_search': search.trim(),
      'p_status': status,
      'p_page': page,
      'p_page_size': pageSize,
      'p_from': from?.toUtc().toIso8601String(),
      'p_to': to?.toUtc().toIso8601String(),
      'p_parent': parentId,
    }),
  );

  Future<Map<String, dynamic>> overview({int days = 30}) =>
      _rpc('admin_get_overview', {'p_days': days});
  Future<AdminUserDetail> user(String id) async =>
      AdminUserDetail(await _rpc('admin_get_user', {'p_user': id}));
  Future<Map<String, dynamic>> record(AdminResource resource, String id) =>
      _rpc('admin_get_record', {'p_resource': resource.apiName, 'p_id': id});
  Future<Map<String, dynamic>> settings() => _rpc('admin_get_settings');

  Future<void> apply({
    required String action,
    required String reason,
    String? userId,
    String? recordId,
    Map<String, dynamic> value = const {},
  }) async {
    final result = await _rpc('admin_apply_action', {
      'p_action': action,
      'p_user': userId,
      'p_record': recordId,
      'p_value': value,
      'p_reason': reason.trim(),
    });
    if (result['saved'] != true) {
      throw StateError('The change was not saved. Refresh and try again.');
    }
  }

  Future<void> deleteAccount({
    required String requestId,
    required String handle,
    required String reason,
  }) async {
    final response = await client.functions.invoke(
      'admin-delete-user',
      body: {'request_id': requestId, 'confirmation': handle, 'reason': reason},
    );
    if (response.status != 200 || adminMap(response.data)['deleted'] != true) {
      throw StateError(
        adminMap(response.data)['error']?.toString() ??
            'Account deletion did not complete.',
      );
    }
  }
}

String adminError(Object error) {
  if (error is PostgrestException) {
    if (['PGRST202', 'PGRST205', '42883', '42P01'].contains(error.code)) {
      return 'Administration is unavailable until the database update is installed.';
    }
    return error.message;
  }
  if (error is FunctionException) {
    return adminMap(error.details)['error']?.toString() ??
        'The account operation could not be completed.';
  }
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}
