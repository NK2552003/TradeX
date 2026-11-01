import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../../data/admin_repository.dart';
import '../../models/admin_records.dart';
import '../widgets/admin_facts.dart';

class AdminOverviewPage extends StatefulWidget {
  const AdminOverviewPage({
    super.key,
    this.onNavigate,
    this.repository,
    this.analytics = false,
  });
  final ValueChanged<String>? onNavigate;
  final AdminRepository? repository;
  final bool analytics;
  @override
  State<AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends State<AdminOverviewPage> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  int _days = 30;
  int _request = 0;
  AdminRepository get _repo => widget.repository ?? AdminRepository.instance;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.overview(days: _days);
      if (mounted && request == _request) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _error = adminError(error);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => UiPage(
    title: widget.analytics ? 'Product analytics' : 'Admin overview',
    subtitle: 'Accounts, content and recorded product activity',
    actions: [
      UiButton(
        label: 'Refresh',
        leadingIcon: Icons.refresh,
        variant: UiVariant.outline,
        onPressed: _loading ? null : _load,
      ),
    ],
    child: UiAsyncView<Map<String, dynamic>>(
      loading: _loading,
      error: _error,
      data: _data,
      onRetry: _load,
      loadingMessage: 'Loading platform analytics…',
      dataBuilder: (context, data) => _OverviewContent(
        data: data,
        days: _days,
        onNavigate: widget.onNavigate,
        onDaysChanged: (days) {
          setState(() => _days = days);
          _load();
        },
      ),
    ),
  );
}

class _OverviewContent extends StatelessWidget {
  const _OverviewContent({
    required this.data,
    required this.days,
    required this.onDaysChanged,
    this.onNavigate,
  });
  final Map<String, dynamic> data;
  final int days;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<String>? onNavigate;
  @override
  Widget build(BuildContext context) {
    final trend = (data['trend'] as List? ?? []).map(adminMap).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCardGrid(
          minTileWidth: 230,
          children: [
            for (final metric in [
              (
                'Users',
                'users',
                'All registered accounts',
                'org_team',
                Icons.people_outline,
              ),
              (
                'Active accounts',
                'active_accounts',
                'Accounts currently allowed access',
                'org_team',
                Icons.verified_user_outlined,
              ),
              (
                'Active subscriptions',
                'subscriptions',
                'Current billing subscription records',
                'admin_subscriptions',
                Icons.subscriptions_outlined,
              ),
              (
                'Active affiliates',
                'affiliates',
                'Approved partners with active status',
                'affiliate_reviews',
                Icons.handshake_outlined,
              ),
            ])
              UiMetricCard(
                title: metric.$1,
                value: '${data[metric.$2] ?? 0}',
                caption: metric.$3,
                icon: metric.$5,
                onTap: onNavigate == null ? null : () => onNavigate!(metric.$4),
              ),
          ],
        ),
        const UiGap.v(20),
        AdminSection(
          title: 'Review queues',
          child: UiCardGrid(
            minTileWidth: 230,
            children: [
              for (final metric in [
                (
                  'Affiliate applications',
                  'pending_applications',
                  'affiliate_reviews',
                ),
                ('Posts awaiting review', 'pending_posts', 'org_publishing'),
                (
                  'Comments awaiting review',
                  'pending_comments',
                  'admin_comments',
                ),
                ('Deletion requests', 'pending_deletions', 'admin_deletions'),
              ])
                UiMetricCard(
                  title: metric.$1,
                  value: '${data[metric.$2] ?? 0}',
                  intent: UiIntent.warning,
                  onTap: onNavigate == null
                      ? null
                      : () => onNavigate!(metric.$3),
                ),
            ],
          ),
        ),
        const UiGap.v(20),
        AdminSection(
          title: 'Activity over time',
          description:
              'Daily account registrations, posts, messages and AI requests recorded in the database. Dates use UTC.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiToggleGroup<int>(
                value: days,
                options: const [
                  UiOption(value: 7, label: '7 days'),
                  UiOption(value: 30, label: '30 days'),
                  UiOption(value: 90, label: '90 days'),
                ],
                onChanged: onDaysChanged,
              ),
              const UiGap.v(16),
              UiChart(
                height: context.sz(280),
                curved: false,
                data: [
                  for (final point in trend)
                    UiChartPoint(
                      label: '${point['date']}'
                          .split('T')
                          .first
                          .split(' ')
                          .first,
                      values: [
                        for (final field in [
                          'users',
                          'posts',
                          'messages',
                          'ai_requests',
                        ])
                          (point[field] as num? ?? 0).toDouble(),
                      ],
                    ),
                ],
                series: [
                  UiChartSeries(
                    name: 'New users',
                    color: context.ui.colors.primary,
                  ),
                  UiChartSeries(
                    name: 'Posts',
                    color: context.ui.colors.success,
                  ),
                  UiChartSeries(
                    name: 'Messages',
                    color: context.ui.colors.warning,
                  ),
                  UiChartSeries(
                    name: 'AI requests',
                    color: context.ui.colors.foregroundMuted,
                  ),
                ],
                valueFormatter: (value) => value.toStringAsFixed(0),
              ),
              const UiGap.v(16),
              UiCardGrid(
                minTileWidth: 210,
                children: [
                  UiMetricCard(
                    title: 'New users',
                    value: '${data['new_users'] ?? 0}',
                    caption: 'Last $days days',
                  ),
                  UiMetricCard(
                    title: 'Users with recorded activity',
                    value: '${data['active_users'] ?? 0}',
                    caption: 'Distinct actors in the last $days days',
                  ),
                  UiMetricCard(
                    title: 'Messages sent',
                    value: '${data['messages'] ?? 0}',
                    caption: 'Last $days days',
                  ),
                  UiMetricCard(
                    title: 'AI requests',
                    value: '${data['ai_requests'] ?? 0}',
                    caption: 'Last $days days',
                  ),
                ],
              ),
            ],
          ),
        ),
        const UiGap.v(20),
        AdminSection(
          title: 'Content and account totals',
          child: UiCardGrid(
            minTileWidth: 190,
            children: [
              for (final metric in [
                ('Posts', 'posts', 'org_publishing'),
                ('Notes', 'notes', 'admin_notes'),
                ('Journal entries', 'journal', 'admin_journal'),
                ('Strategies', 'strategies', 'admin_strategies'),
                ('Suspended accounts', 'suspended_accounts', 'org_team'),
                ('Access overrides', 'access_grants', 'admin_subscriptions'),
              ])
                UiMetricCard(
                  title: metric.$1,
                  value: '${data[metric.$2] ?? 0}',
                  onTap: onNavigate == null
                      ? null
                      : () => onNavigate!(metric.$3),
                ),
            ],
          ),
        ),
        const UiGap.v(20),
        AdminSection(
          title: 'Recent activity',
          description: data['history_started_at'] == null
              ? 'Activity history begins when changes are recorded. Earlier records retain their creation dates.'
              : 'Recorded history starts ${adminDate(data['history_started_at'])}. Earlier changes are not reconstructed.',
          child: UiTable<AdminRecord>(
            rows: (data['recent_activity'] as List? ?? [])
                .map((row) => AdminRecord(adminMap(row)))
                .toList(),
            stackOnMobile: true,
            emptyLabel: 'No activity recorded yet',
            columns: [
              UiTableColumn(
                header: 'Action',
                flex: 3,
                valueGetter: (row) => row.title,
              ),
              UiTableColumn(
                header: 'Actor',
                valueGetter: (row) => row.text('actor_handle'),
              ),
              UiTableColumn(
                header: 'Time',
                valueGetter: (row) => adminDate(row.values['created_at']),
              ),
            ],
          ),
        ),
        const UiGap.v(12),
        Text(
          'Updated ${adminDate(data['fetched_at'])}',
          style: context.uiText.caption,
        ),
      ],
    );
  }
}
