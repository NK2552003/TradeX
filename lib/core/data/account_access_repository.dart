import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/app-ui/theme/app_tokens.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';

/// Current access comes from the account record, not stale JWT role claims.
class AccountAccess {
  const AccountAccess({
    required this.userId,
    required this.status,
    required this.role,
    required this.tier,
    required this.features,
    this.affiliateApproved = false,
  });

  factory AccountAccess.fromJson(Map<String, dynamic> json) {
    final tier = AppTier.values.where((tier) => tier.name == json['tier']);
    if (json['user_id'] is! String ||
        json['status'] is! String ||
        json['role'] is! String ||
        json['features'] is! Map ||
        tier.isEmpty) {
      throw const FormatException('Invalid account access response.');
    }
    return AccountAccess(
      userId: json['user_id'] as String,
      status: json['status'] as String,
      role: UserRole.fromId(json['role'] as String),
      tier: tier.single,
      features: Map<String, bool>.from(json['features'] as Map),
      affiliateApproved: json['affiliate_approved'] == true,
    );
  }

  final String userId;
  final String status;
  final UserRole role;
  final AppTier tier;
  final Map<String, bool> features;
  final bool affiliateApproved;
  bool get isActive => status == 'active';
  bool allows(String feature) => isActive && features[feature] == true;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'user_id': userId,
    'status': status,
    'role': role.id,
    'tier': tier.name,
    'features': features,
    'affiliate_approved': affiliateApproved,
  };
}

class AccountAccessRepository {
  AccountAccessRepository({this._client});
  final SupabaseClient? _client;

  SupabaseClient get _connection =>
      _client ??
      SupabaseConfig.client ??
      (throw StateError('Sign in to continue.'));

  Future<AccountAccess> load() async {
    final client = _connection;
    final actor = client.auth.currentUser?.id;
    if (actor == null) throw StateError('Sign in to continue.');
    final raw = await client.rpc('get_my_admin_access');
    if (raw is! Map) {
      throw const FormatException('Invalid account access response.');
    }
    final access = AccountAccess.fromJson(Map<String, dynamic>.from(raw));
    if (access.userId != actor || client.auth.currentUser?.id != actor) {
      throw StateError('Your account changed. Please sign in again.');
    }
    return access;
  }

  Future<void> recordDestination(String destination) async {
    await _connection.rpc(
      'record_account_activity',
      params: {'p_destination': destination},
    );
  }
}
