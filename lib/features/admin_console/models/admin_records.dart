import 'package:flutter/foundation.dart';

enum AdminResource {
  users('Users', 'Search name, email, handle or user ID'),
  applications('Affiliate applications', 'Search applicant or email'),
  affiliates('Affiliates', 'Search partner or email'),
  posts('Posts', 'Search post or author'),
  comments('Comments', 'Search comment or author'),
  subscriptions('Subscriptions', 'Search subscriber or email'),
  notes('Notes', 'Search note or author'),
  journal('Journal', 'Search journal entry or author'),
  strategies('Strategies', 'Search strategy or author'),
  messages('Messages', 'Search message or sender'),
  ai('AI conversations', 'Search conversation or user'),
  aiRequests('AI requests', 'Search request or user'),
  aiMessages('AI messages', 'Search message'),
  activity('Activity history', 'Search action, record or actor'),
  referrals('Referrals', 'Search referred user'),
  payouts('Payout history', 'Search partner'),
  deletions('Deletion requests', 'Search handle');

  const AdminResource(this.label, this.searchHint);
  final String label;
  final String searchHint;

  String get apiName => switch (this) {
    aiRequests => 'ai_requests',
    aiMessages => 'ai_messages',
    _ => name,
  };

  List<String> get statuses => switch (this) {
    users => ['active', 'suspended', 'pending_approval'],
    applications => ['pending', 'approved', 'rejected', 'draft', 'suspended'],
    affiliates => ['active', 'suspended', 'pending'],
    posts || comments => ['pending', 'approved', 'rejected'],
    notes || journal => ['private', 'public', 'restricted'],
    strategies => ['draft', 'live', 'archived', 'restricted'],
    messages => ['sent', 'delivered', 'read', 'failed', 'restricted'],
    ai => ['active', 'restricted'],
    aiRequests => ['recorded', 'reserved', 'completed', 'failed'],
    aiMessages => ['complete', 'failed'],
    subscriptions => [
      'free',
      'active',
      'trialing',
      'canceled',
      'past_due',
      'expired',
    ],
    deletions => [
      'pending',
      'grace_period',
      'processing',
      'failed',
      'completed',
      'cancelled',
    ],
    payouts => ['pending', 'processing', 'paid', 'failed', 'cancelled'],
    referrals => ['pending', 'converted', 'churned'],
    activity => [
      'administration',
      'users',
      'posts',
      'comments',
      'notes',
      'journal',
      'strategies',
      'messages',
      'ai',
      'affiliate',
      'access',
      'subscriptions',
    ],
  };
}

Map<String, dynamic> adminMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String adminLabel(String value) => value
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');

@immutable
class AdminRecord {
  AdminRecord(Map<String, dynamic> json) : values = Map.unmodifiable(json);
  final Map<String, dynamic> values;
  String text(String key, [String fallback = '']) =>
      values[key]?.toString() ?? fallback;
  int count(String key) => (values[key] as num?)?.toInt() ?? 0;
  bool flag(String key) => values[key] == true;
  String get id => text('id', text('user_id'));
  String? get userId => values['user_id']?.toString();
  String get title {
    for (final key in [
      'title',
      'display_name',
      'full_name',
      'handle',
      'target_label',
      'kind',
    ]) {
      if (text(key).trim().isNotEmpty) return text(key);
    }
    return id.isEmpty ? 'Record' : id;
  }

  String get status => text('status', text('moderation_status'));
}

@immutable
class AdminPageData {
  const AdminPageData({
    required this.rows,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  factory AdminPageData.fromJson(Map<String, dynamic> json) => AdminPageData(
    rows: (json['rows'] as List)
        .map((row) => AdminRecord(adminMap(row)))
        .toList(growable: false),
    total: (json['total'] as num).toInt(),
    page: (json['page'] as num).toInt(),
    pageSize: (json['page_size'] as num).toInt(),
  );
  final List<AdminRecord> rows;
  final int total;
  final int page;
  final int pageSize;
  int get totalPages => (total / pageSize).ceil().clamp(1, 1 << 30);
}

@immutable
class AdminUserDetail {
  AdminUserDetail(Map<String, dynamic> json) : values = Map.unmodifiable(json);
  final Map<String, dynamic> values;
  AdminRecord get profile => AdminRecord(adminMap(values['profile']));
  Map<String, dynamic> get controls =>
      adminMap(profile.values['admin_controls']);
  Map<String, dynamic> get counts => adminMap(values['counts']);
  Map<String, dynamic> get quota => adminMap(values['quota']);
  Map<String, dynamic> get subscription => adminMap(values['subscription']);
  Map<String, dynamic> get affiliate => adminMap(values['affiliate']);
  String get tier => values['effective_tier']?.toString() ?? 'free';
}
