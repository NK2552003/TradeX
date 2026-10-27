import 'package:tradex/core/app-ui/theme/app_tokens.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/data/app_session.dart';

/// Server-counted usage for one authenticated account. The database function
/// checks the caller's identity before returning any other user's totals.
class CustomerQuotaUsage {
  const CustomerQuotaUsage({
    required this.userId,
    required this.tier,
    required this.notesUsed,
    required this.tradesUsed,
    required this.livePlaybooksUsed,
    required this.aiQueriesUsed,
    required this.notesLimit,
    required this.tradesLimit,
    required this.livePlaybooksLimit,
    required this.aiQueriesLimit,
  });

  final String userId;
  final AppTier tier;
  final int notesUsed;
  final int tradesUsed;
  final int livePlaybooksUsed;
  final int aiQueriesUsed;
  final int notesLimit;
  final int tradesLimit;
  final int livePlaybooksLimit;
  final int aiQueriesLimit;

  static Future<CustomerQuotaUsage> fetch({String? userId}) async {
    final client = SupabaseConfig.client;
    final signedInId = client?.auth.currentUser?.id;
    if (client == null || signedInId == null) {
      throw StateError('Sign in to load your plan usage.');
    }
    final raw = await client.rpc(
      'get_customer_quota_usage',
      params: {'target_user_id': userId},
    );
    if (raw is! Map) throw const FormatException('Invalid quota response.');
    final json = Map<String, dynamic>.from(raw);
    final tier = AppTier.values.firstWhere(
      (candidate) => candidate.name == json['tier'],
      orElse: () => throw const FormatException('Invalid account tier.'),
    );
    final limits = Map<String, dynamic>.from(json['limits'] as Map);
    int count(Map<String, dynamic> source, String key) {
      final value = source[key];
      if (value is! num || value < 0) {
        throw FormatException('Invalid $key count.');
      }
      return value.toInt();
    }

    final result = CustomerQuotaUsage(
      userId: json['user_id'].toString(),
      tier: tier,
      notesUsed: count(json, 'notes_used'),
      tradesUsed: count(json, 'trades_used'),
      livePlaybooksUsed: count(json, 'live_playbooks_used'),
      aiQueriesUsed: count(json, 'ai_queries_used'),
      notesLimit: count(limits, 'notes'),
      tradesLimit: count(limits, 'trades'),
      livePlaybooksLimit: count(limits, 'live_playbooks'),
      aiQueriesLimit: count(limits, 'ai_queries_per_month'),
    );
    if (result.userId == signedInId) {
      AppSession.instance.changeTier(result.tier);
      AppSession.instance.aiQueriesUsed.value = result.aiQueriesUsed;
    }
    return result;
  }
}
