import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/admin_repository.dart';
import '../../models/admin_records.dart';
import '../widgets/admin_facts.dart';
import '../widgets/admin_record_actions.dart';
import '../widgets/admin_records_panel.dart';

class AdminRecordDetailPage extends StatefulWidget {
  const AdminRecordDetailPage({
    super.key,
    required this.resource,
    required this.recordId,
    required this.repository,
    required this.onBack,
    this.onOpenUser,
    this.showRelatedRecords = true,
  });
  final AdminResource resource;
  final String recordId;
  final AdminRepository repository;
  final VoidCallback onBack;
  final ValueChanged<String>? onOpenUser;
  final bool showRelatedRecords;
  @override
  State<AdminRecordDetailPage> createState() => _AdminRecordDetailPageState();
}

class _AdminRecordDetailPageState extends State<AdminRecordDetailPage> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  bool _deleted = false;
  String? _childId;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repository.record(
        widget.resource,
        widget.recordId,
      );
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
          _revision++;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = adminError(error);
          _loading = false;
        });
      }
    }
  }

  AdminResource? get _childResource => switch (widget.resource) {
    AdminResource.posts => AdminResource.comments,
    AdminResource.ai => AdminResource.aiMessages,
    AdminResource.messages => AdminResource.messages,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    if (_childId != null && _childResource != null) {
      return AdminRecordDetailPage(
        resource: _childResource!,
        recordId: _childId!,
        repository: widget.repository,
        onOpenUser: widget.onOpenUser,
        showRelatedRecords: widget.resource != AdminResource.messages,
        onBack: () {
          setState(() => _childId = null);
          _load();
        },
      );
    }
    return UiPage(
      title: '${widget.resource.label} · details',
      actions: [
        UiButton(
          label: 'Back',
          leadingIcon: Icons.arrow_back,
          variant: UiVariant.ghost,
          onPressed: widget.onBack,
        ),
        if (!_deleted)
          UiButton(
            label: 'Refresh',
            leadingIcon: Icons.refresh,
            variant: UiVariant.outline,
            onPressed: _loading ? null : _load,
          ),
      ],
      child: _deleted
          ? UiEmptyState(
              title: widget.resource == AdminResource.deletions
                  ? 'Account deleted'
                  : 'Record deleted',
              message: 'The deletion is recorded in activity history.',
              icon: Icons.check_circle_outline,
            )
          : UiAsyncView<Map<String, dynamic>>(
              loading: _loading,
              error: _error,
              data: _data,
              onRetry: _load,
              loadingMessage: 'Loading record and activity…',
              dataBuilder: (context, data) {
                final record = AdminRecord(adminMap(data['record']));
                final userId = data['user_id']?.toString();
                final body = record.values['body'] ?? record.values['content'];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(record.title, style: context.uiText.heading),
                    const UiGap.v(12),
                    if (widget.onOpenUser != null && userId != null) ...[
                      UiButton(
                        label: 'Manage this user',
                        leadingIcon: Icons.person_outline,
                        variant: UiVariant.outline,
                        onPressed: () => widget.onOpenUser!(userId),
                      ),
                      const UiGap.v(12),
                    ],
                    AdminRecordActions(
                      resource: widget.resource,
                      record: record,
                      userId: userId,
                      repository: widget.repository,
                      onSaved: _load,
                      onDeleted: () => setState(() => _deleted = true),
                    ),
                    const UiGap.v(20),
                    if (widget.resource == AdminResource.posts) ...[
                      UiCardGrid(
                        minTileWidth: 170,
                        children: [
                          for (final metric in [
                            ('Views', 'views_count'),
                            ('Likes', 'likes_count'),
                            ('Comments', 'comments_count'),
                            ('Reposts', 'reposts_count'),
                            ('Bookmarks', 'bookmarks_count'),
                          ])
                            UiMetricCard(
                              title: metric.$1,
                              value: '${record.count(metric.$2)}',
                              caption: 'Recorded total',
                            ),
                        ],
                      ),
                      const UiGap.v(20),
                    ],
                    if (record.flag('admin_hidden')) ...[
                      const UiCallout(
                        title: 'Record restricted',
                        message:
                            'Restore this record to make it available again.',
                        intent: UiIntent.warning,
                      ),
                      const UiGap.v(16),
                    ],
                    AdminSection(
                      title: 'Record details',
                      child: AdminFacts(
                        values: {
                          'Record ID': record.id,
                          for (final key in _fields)
                            if (record.values.containsKey(key))
                              adminLabel(key): key.endsWith('_at')
                                  ? adminDate(record.values[key])
                                  : adminValue(record.values[key]),
                        },
                      ),
                    ),
                    if (body != null) ...[
                      const UiGap.v(20),
                      AdminSection(
                        title: 'Content',
                        child: SelectableText(
                          _content(body),
                          style: context.uiText.body,
                        ),
                      ),
                    ],
                    if (widget.resource == AdminResource.aiRequests)
                      for (final entry in [
                        ('Prompt', 'prompt_text'),
                        ('Response', 'response_text'),
                      ])
                        if (record.text(entry.$2).isNotEmpty) ...[
                          const UiGap.v(20),
                          AdminSection(
                            title: entry.$1,
                            child: SelectableText(
                              record.text(entry.$2),
                              style: context.uiText.body,
                            ),
                          ),
                        ],
                    if (widget.resource == AdminResource.applications &&
                        record.text('sample_link').isNotEmpty) ...[
                      const UiGap.v(12),
                      UiButton(
                        label: 'Open application sample',
                        variant: UiVariant.outline,
                        onPressed: () async {
                          final uri = Uri.tryParse(record.text('sample_link'));
                          if (uri == null ||
                              !['https', 'http'].contains(uri.scheme)) {
                            UiToast.error(
                              context,
                              title: 'Invalid sample link',
                            );
                            return;
                          }
                          try {
                            if (!await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                ) &&
                                context.mounted) {
                              UiToast.error(
                                context,
                                title: 'Unable to open sample',
                              );
                            }
                          } catch (_) {
                            if (context.mounted) {
                              UiToast.error(
                                context,
                                title: 'Unable to open sample',
                              );
                            }
                          }
                        },
                      ),
                    ],
                    const UiGap.v(20),
                    AdminSection(
                      title: 'Recent record history',
                      child: UiTable<AdminRecord>(
                        stackOnMobile: true,
                        rows: (data['activity'] as List? ?? [])
                            .map((row) => AdminRecord(adminMap(row)))
                            .toList(),
                        emptyLabel: 'No earlier changes recorded',
                        columns: [
                          UiTableColumn(
                            header: 'Action',
                            valueGetter: (row) =>
                                adminLabel(row.text('action')),
                          ),
                          UiTableColumn(
                            header: 'Actor',
                            valueGetter: (row) => row.text('actor_handle'),
                          ),
                          UiTableColumn(
                            header: 'Reason',
                            flex: 2,
                            valueGetter: (row) =>
                                adminMap(
                                  row.values['metadata'],
                                )['reason']?.toString() ??
                                'Recorded change',
                          ),
                          UiTableColumn(
                            header: 'Time',
                            valueGetter: (row) =>
                                adminDate(row.values['created_at']),
                          ),
                        ],
                      ),
                    ),
                    if (widget.resource == AdminResource.activity) ...[
                      const UiGap.v(20),
                      AdminSection(
                        title: 'Change information',
                        child: AdminFacts(
                          values: {
                            for (final item in adminMap(
                              record.values['metadata'],
                            ).entries)
                              if (item.value is! Map)
                                adminLabel(item.key): adminValue(item.value),
                            'Changed controls': adminMap(
                              adminMap(record.values['metadata'])['changes'],
                            ).keys.map(adminLabel).join(', '),
                          },
                        ),
                      ),
                    ],
                    if (_childResource != null &&
                        widget.showRelatedRecords) ...[
                      const UiGap.v(20),
                      AdminSection(
                        title: _childResource!.label,
                        child: AdminRecordsPanel(
                          key: ValueKey(_revision),
                          resource: _childResource!,
                          repository: widget.repository,
                          parentId: widget.resource == AdminResource.messages
                              ? record.text('thread_id')
                              : record.id,
                          onOpen: (row) => setState(() => _childId = row.id),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }

  String _content(Object value) {
    if (value is Map) {
      return value['markdown']?.toString() ??
          value['text']?.toString() ??
          value.toString();
    }
    return value.toString();
  }

  List<String> get _fields => [
    'status',
    'moderation_status',
    'moderation_note',
    'review_notes',
    'reviewed_by',
    'created_at',
    'updated_at',
    'reviewed_at',
    if (widget.resource == AdminResource.applications) ...[
      'full_name',
      'email',
      'phone',
      'city',
      'state',
      'platforms',
      'primary_platform',
      'channel_handle',
      'audience_reach',
      'niches',
      'sample_link',
      'account_holder',
      'bank_name',
      'account_last4',
      'ifsc',
      'upi_id',
    ],
    if (widget.resource == AdminResource.activity) ...[
      'action',
      'actor_handle',
      'actor_role',
      'subject_user_id',
      'target_type',
      'target_id',
      'category',
    ],
    if (widget.resource == AdminResource.deletions) ...[
      'user_handle',
      'reason',
      'data_purge_condition',
      'purge_journals_notes_strategies',
      'purge_community_messages',
      'purge_ai_workspace',
      'purge_affiliate_campaigns',
      'export_requested_before_delete',
      'scheduled_purge_at',
      'data_purged_at',
      'processing_started_at',
      'completed_at',
      'last_error',
    ],
    'ticker',
    'tickers',
    'tags',
    'visibility',
    'is_public',
    'is_pinned',
    'is_featured',
    'word_count',
    'view_count',
    'like_count',
    'kind',
    'role',
    'persona',
    if (widget.resource == AdminResource.aiRequests) ...[
      'provider',
      'model',
      'input_tokens',
      'output_tokens',
      'requested_at',
      'completed_at',
    ],
    'thread_id',
    'amount',
    'currency',
    'payout_method',
    'processed_at',
    'transaction_reference',
    'failure_reason',
    'notes',
    'commission_rate',
    'referral_code',
    'referred_user_id',
    'campaign_id',
    'channel',
    'bonus_awarded',
    'subscription_tier',
    'converted_at',
    'total_commission_earned',
    if (widget.resource == AdminResource.journal) ...[
      'entry_price',
      'exit_price',
      'stop_loss',
      'target',
      'size',
      'side',
      'pnl',
      'pnl_percent',
      'r_multiple',
      'opened_at',
      'closed_at',
      'outcome',
      'psychology',
      'psychology_score',
      'mistakes_made',
      'lessons_learned',
    ],
    'summary',
    'error',
    'sources',
  ];
}
