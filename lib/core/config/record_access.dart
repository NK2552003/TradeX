import 'customer_data_policy.dart';
import 'supabase_config.dart';
import 'package:alphajournal/features/auth/data/services/auth_backend_service.dart';
import 'package:alphajournal/features/auth/data/services/supabase_auth_backend_service.dart';

/// UI permissions use record ownership; route flags never confer ownership.
class RecordAccess {
  RecordAccess._();

  static bool owns(String ownerId, {String? actorId}) {
    final isLocalDemo =
        CustomerDataPolicy.allowDemo && !SupabaseConfig.isConfigured;
    if (ownerId.trim().isEmpty) return isLocalDemo;
    final actor =
        actorId ??
        SupabaseConfig.client?.auth.currentUser?.id ??
        (isLocalDemo
            ? SupabaseAuthBackendService.instance.currentUserProfile?.id ??
                  AuthBackendService.instance.currentUserProfile?.id
            : null);
    if (actor != null && actor.isNotEmpty) {
      return ownerId == actor;
    }
    return isLocalDemo &&
        (ownerId == 'demo_user' ||
            ownerId == '00000000-0000-0000-0000-000000000001');
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
