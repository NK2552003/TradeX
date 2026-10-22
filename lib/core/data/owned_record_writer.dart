import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Confirms a server-owned write before a repository changes its cache.
class OwnedRecordWriter {
  OwnedRecordWriter({SupabaseClient? client, String? actorId})
    : client = client ?? SupabaseConfig.client!,
      actorId = actorId ?? SupabaseConfig.client?.auth.currentUser?.id ?? '';
  final SupabaseClient client;
  final String actorId;

  Future<Map<String, dynamic>> update(
    String table,
    String id,
    Map<String, dynamic> values, {
    String ownerColumn = 'user_id',
  }) async {
    if (actorId.isEmpty) throw StateError('Sign in to change this record.');
    return client
        .from(table)
        .update(values)
        .eq('id', id)
        .eq(ownerColumn, actorId)
        .select()
        .single();
  }

  Future<void> delete(
    String table,
    String id, {
    String ownerColumn = 'user_id',
  }) async {
    if (actorId.isEmpty) throw StateError('Sign in to delete this record.');
    await client
        .from(table)
        .delete()
        .eq('id', id)
        .eq(ownerColumn, actorId)
        .select('id')
        .single();
  }
}
