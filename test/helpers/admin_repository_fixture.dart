import 'dart:math' as math;

import 'package:alphajournal/features/admin_console/data/admin_repository.dart';
import 'package:alphajournal/features/admin_console/models/admin_records.dart';

/// An in-memory I/O boundary for interaction tests. Production has no fixture
/// fallback; SQL authorization and quota behavior are tested separately.
class AdminRepositoryFixture extends AdminRepository {
  static const userId = '10000000-0000-4000-8000-000000000001';
  static const adminId = '10000000-0000-4000-8000-000000000002';
  static const recordId = '20000000-0000-4000-8000-000000000001';
  final profile = <String, dynamic>{
    'id': userId,
    'user_id': userId,
    'title': 'Review Trader',
    'display_name': 'Review Trader',
    'handle': 'review_trader',
    'email': 'review@example.com',
    'role': 'customer',
    'status': 'active',
    'tier': 'free',
    'created_at': '2026-10-01T10:00:00Z',
    'admin_controls': <String, dynamic>{},
  };
  final Map<AdminResource, List<Map<String, dynamic>>> records = {};
  final List<Map<String, dynamic>> changes = [];
  final List<Map<String, dynamic>> queries = [];
  bool failReads = false;
  bool failWrites = false;
  int overviewDays = 30;
  Map<String, dynamic> platformFeatures = {};
  Map<String, dynamic> affiliate = {};

  AdminRepositoryFixture() {
    for (final resource in AdminResource.values) {
      records[resource] = [
        {
          'id': recordId,
          'user_id': userId,
          'title': '${resource.label} example',
          'author': 'Review Trader',
          'status': resource.statuses.isEmpty
              ? 'recorded'
              : resource.statuses.first,
          'created_at': '2026-10-01T10:00:00Z',
          'body': 'Recorded content for review.',
          'moderation_status': 'pending',
          'word_count': 42,
          'views_count': 31,
          'likes_count': 5,
          'comments_count': 2,
          'parent_id': recordId,
          'thread_id': recordId,
          'actor_handle': 'review_trader',
          'target_type': 'community_posts',
          'target_id': recordId,
          'action': 'insert',
          'metadata': {'reason': 'Review reason', 'source': 'database'},
        },
      ];
    }
    records[AdminResource.users] = [profile];
    records[AdminResource.subscriptions] = [
      {...profile, 'status': 'free'},
    ];
    records[AdminResource.applications] = [
      {
        ...records[AdminResource.applications]!.single,
        'title': 'Review Trader',
        'full_name': 'Review Trader',
        'status': 'pending',
        'primary_platform': 'YouTube',
        'audience_reach': '10,000 – 100,000',
        'email': 'review@example.com',
        'account_last4': '9012',
      },
    ];
    records[AdminResource.deletions] = [
      {
        ...records[AdminResource.deletions]!.single,
        'title': 'review_trader',
        'user_handle': 'review_trader',
        'scheduled_purge_at': '2026-10-01T10:00:00Z',
      },
    ];
    records[AdminResource.payouts] = [
      {
        ...records[AdminResource.payouts]!.single,
        'amount': 1200,
        'currency': 'INR',
        'balance_reserved': true,
      },
    ];
  }

  @override
  String? get currentUserId => adminId;

  @override
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
  }) async {
    queries.add({
      'resource': resource,
      'userId': userId,
      'search': search,
      'status': status,
      'page': page,
      'parentId': parentId,
    });
    if (failReads) throw StateError('Connection unavailable');
    final matches = (records[resource] ?? [])
        .where(
          (row) =>
              (userId == null || row['user_id'] == userId) &&
              (parentId == null || row['parent_id'] == parentId) &&
              (status == 'all' || row['status'] == status) &&
              row.values.join(' ').toLowerCase().contains(search.toLowerCase()),
        )
        .toList();
    return AdminPageData(
      rows: matches
          .skip(page * pageSize)
          .take(pageSize)
          .map(AdminRecord.new)
          .toList(),
      total: matches.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<Map<String, dynamic>> overview({int days = 30}) async {
    if (failReads) throw StateError('Connection unavailable');
    overviewDays = days;
    return {
      'users': 137,
      'active_accounts': 124,
      'suspended_accounts': 13,
      'subscriptions': 23,
      'affiliates': 8,
      'new_users': 17,
      'active_users': 61,
      'posts': 86,
      'notes': 55,
      'journal': 98,
      'strategies': 12,
      'messages': 45,
      'ai_requests': 19,
      'access_grants': 4,
      'pending_posts': 3,
      'pending_comments': 2,
      'pending_applications': 1,
      'pending_deletions': 1,
      'trend': List.generate(
        math.min(days, 7),
        (i) => {
          'date': '2026-10-${(i + 1).toString().padLeft(2, '0')}',
          'users': i,
          'posts': i * 2,
          'messages': i * 3,
          'ai_requests': i,
        },
      ),
      'recent_activity': records[AdminResource.activity],
      'fetched_at': '2026-10-27T10:00:00Z',
    };
  }

  @override
  Future<AdminUserDetail> user(String id) async {
    if (failReads) throw StateError('Connection unavailable');
    final controls = adminMap(profile['admin_controls']);
    return AdminUserDetail({
      'profile': profile,
      'effective_tier':
          adminMap(controls['subscription_override'])['tier'] ?? 'free',
      'counts': {
        'posts': 3,
        'notes': 2,
        'journal': 1,
        'strategies': 1,
        'messages': 4,
        'ai': 2,
      },
      'quota': {
        'notes_used': 2,
        'trades_used': 1,
        'live_playbooks_used': 1,
        'ai_queries_used': 2,
        'limits': {
          'notes': 10,
          'trades': 50,
          'live_playbooks': 5,
          'ai_queries_per_month': 100,
        },
      },
      'subscription': {'tier': 'free', 'status': 'active'},
      'affiliate': affiliate,
      'features': controls['features'] ?? {},
      'last_sign_in_at': '2026-10-27T09:00:00Z',
    });
  }

  @override
  Future<Map<String, dynamic>> record(AdminResource resource, String id) async {
    if (failReads) throw StateError('Connection unavailable');
    final row = records[resource]!.firstWhere((row) => row['id'] == id);
    return {
      'record': {...row},
      'user_id': userId,
      'activity': [
        {
          'action': 'insert',
          'actor_handle': 'review_trader',
          'created_at': row['created_at'],
          'metadata': {'reason': 'Original record'},
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> settings() async {
    if (failReads) throw StateError('Connection unavailable');
    return {'features': platformFeatures, 'updated_at': '2026-10-01T10:00:00Z'};
  }

  @override
  Future<void> apply({
    required String action,
    required String reason,
    String? userId,
    String? recordId,
    Map<String, dynamic> value = const {},
  }) async {
    if (failWrites) throw StateError('Server rejected the change');
    changes.add({
      'action': action,
      'reason': reason,
      'userId': userId,
      'recordId': recordId,
      'value': value,
    });
    switch (action) {
      case 'controls':
        profile['admin_controls'] = {
          ...adminMap(profile['admin_controls']),
          ...value,
        };
      case 'account_status':
        profile['status'] = value['status'];
      case 'role':
        profile['role'] = value['role'];
      case 'subscription_access':
        profile['admin_controls'] = {
          ...adminMap(profile['admin_controls']),
          'subscription_override': value,
        };
      case 'clear_subscription_access':
        adminMap(profile['admin_controls']).remove('subscription_override');
      case 'settings':
        platformFeatures = adminMap(value['features']);
      case 'review_application':
        records[AdminResource.applications]!.single['status'] = value['status'];
      case 'moderate_post':
        records[AdminResource.posts]!.single.addAll({
          'moderation_status': value['status'],
          'status': value['status'],
        });
      case 'payout_status':
        records[AdminResource.payouts]!.single.addAll(value);
      case 'affiliate_controls':
        affiliate.addAll(value);
    }
  }

  @override
  Future<void> deleteAccount({
    required String requestId,
    required String handle,
    required String reason,
  }) async {
    if (failWrites) throw StateError('Deletion failed; retry is available.');
    changes.add({
      'action': 'delete_account',
      'recordId': requestId,
      'handle': handle,
      'reason': reason,
    });
  }
}
