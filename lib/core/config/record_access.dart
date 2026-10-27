import 'customer_data_policy.dart';
import 'supabase_config.dart';
import 'package:tradex/features/auth/data/services/auth_backend_service.dart';
import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';

/// UI permissions use record ownership; route flags never confer ownership.
class RecordAccess {
  RecordAccess._();

  static bool owns(String ownerId, {String? actorId}) {
    if (ownerId.isEmpty) return true;
    final actor =
        actorId ??
        SupabaseConfig.client?.auth.currentUser?.id ??
        SupabaseAuthBackendService.instance.currentUserProfile?.id ??
        AuthBackendService.instance.currentUserProfile?.id;
    if (actor != null && actor.isNotEmpty) {
      return ownerId == actor;
    }
    return CustomerDataPolicy.allowDemo;
  }

  static bool canRead(
    String ownerId,
    bool isPublic, {
    bool publicContext = false,
    String? actorId,
  }) => isPublic || (!publicContext && owns(ownerId, actorId: actorId));

  static void requireOwner(String ownerId) {
    if (!owns(ownerId)) {
      throw StateError('Only the owner can change this record.');
    }
  }

  static void requireService() {
    if (!SupabaseConfig.isConfigured && !CustomerDataPolicy.allowDemo) {
      throw StateError('Connect to your account to save this change.');
    }
  }
}
