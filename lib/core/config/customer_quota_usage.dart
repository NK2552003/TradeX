import 'package:tradex/core/app-ui/theme/app_tokens.dart';
import 'package:tradex/core/config/customer_limitations.dart';
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
    this.watchlistsUsed = 0,
    this.watchlistsLimit = 1,
    this.alertsUsed = 0,
    this.alertsLimit = 3,
    this.communityPostsToday = 0,
    this.communityPostsPerDayLimit = 2,
    this.communityCommentsToday = 0,
    this.communityCommentsPerDayLimit = 10,
    this.allowPdfExport = false,
    this.allowAdvancedBacktest = false,
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
  final int watchlistsUsed;
  final int watchlistsLimit;
  final int alertsUsed;
  final int alertsLimit;
  final int communityPostsToday;
  final int communityPostsPerDayLimit;
  final int communityCommentsToday;
  final int communityCommentsPerDayLimit;
  final bool allowPdfExport;
  final bool allowAdvancedBacktest;

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
    final fallbackQuota = CustomerTierQuota.defaultsForTier(tier);
    int count(Map<String, dynamic> source, String key) {
      final value = source[key];
      if (value is! num || value < 0) {
        throw FormatException('Invalid $key count.');
      }
      return value.toInt();
    }

    int optionalCount(Map<String, dynamic> source, String key, int fallback) {
      final value = source[key];
      if (value is num && value >= 0) return value.toInt();
      return fallback;
    }

    bool optionalBool(
      Map<String, dynamic> source,
      String key,
      bool fallback,
    ) {
      final value = source[key];
      if (value is bool) return value;
      return fallback;
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
      watchlistsUsed: optionalCount(json, 'watchlists_used', 0),
      watchlistsLimit: optionalCount(
        limits,
        'watchlists',
        fallbackQuota.maxWatchlists,
      ),
      alertsUsed: optionalCount(json, 'alerts_used', 0),
      alertsLimit: optionalCount(limits, 'alerts', fallbackQuota.maxAlerts),
      communityPostsToday: optionalCount(json, 'community_posts_today', 0),
      communityPostsPerDayLimit: optionalCount(
        limits,
        'community_posts_per_day',
        fallbackQuota.maxCommunityPostsPerDay,
      ),
      communityCommentsToday: optionalCount(
        json,
        'community_comments_today',
        0,
      ),
      communityCommentsPerDayLimit: optionalCount(
        limits,
        'community_comments_per_day',
        fallbackQuota.maxCommunityCommentsPerDay,
      ),
      allowPdfExport: optionalBool(
        limits,
        'allow_pdf_export',
        fallbackQuota.allowPdfExport,
      ),
      allowAdvancedBacktest: optionalBool(
        limits,
        'allow_advanced_backtest',
        fallbackQuota.allowAdvancedBacktest,
      ),
    );
    if (result.userId == signedInId) {
      AppSession.instance.changeTier(result.tier);
      AppSession.instance.aiQueriesUsed.value = result.aiQueriesUsed;
    }
    return result;
  }
}
