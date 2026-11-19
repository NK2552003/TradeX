import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

import '../../data/admin_repository.dart';
import '../../models/admin_records.dart';
import '../widgets/admin_facts.dart';
import '../widgets/admin_preview_cards.dart';

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
  String _chartStyle = 'area';
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
    subtitle: widget.analytics
        ? 'Cohort trends, subscription tiers, AI usage and moderation funnel'
        : 'Live platform health, moderation queues and operational activity',
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
      loadingMessage: widget.analytics
          ? 'Loading product analytics…'
          : 'Loading admin overview…',
      dataBuilder: (context, data) => widget.analytics
          ? _AnalyticsBody(
              data: data,
              days: _days,
              chartStyle: _chartStyle,
              onChartStyleChanged: (style) =>
                  setState(() => _chartStyle = style),
              onNavigate: widget.onNavigate,
              onDaysChanged: _updateDays,
            )
          : _OverviewBody(
              data: data,
              days: _days,
              chartStyle: _chartStyle,
              onChartStyleChanged: (style) =>
                  setState(() => _chartStyle = style),
              onNavigate: widget.onNavigate,
              onDaysChanged: _updateDays,
            ),
    ),
  );

  void _updateDays(int days) {
    setState(() => _days = days);
    _load();
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({
    required this.data,
    required this.days,
    required this.chartStyle,
    required this.onChartStyleChanged,
    required this.onDaysChanged,
    this.onNavigate,
  });

  final Map<String, dynamic> data;
  final int days;
  final String chartStyle;
  final ValueChanged<String> onChartStyleChanged;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<String>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final colors = context.ui.colors;
    final trend = _trendRows(data);
    final activeCount = _intOf(data['active_accounts']);
    final suspendedCount = _intOf(data['suspended_accounts']);
    final pendingTotal =
        _intOf(data['pending_applications']) +
        _intOf(data['pending_posts']) +
        _intOf(data['pending_comments']) +
        _intOf(data['pending_deletions']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CommandHeaderCard(
          title: pendingTotal > 0
              ? '$pendingTotal items awaiting admin review'
              : 'All review queues clear',
          subtitle:
              '${data['users'] ?? 0} accounts · ${data['subscriptions'] ?? 0} subscriptions · ${data['affiliates'] ?? 0} active partners',
          pendingTotal: pendingTotal,
          activeCount: activeCount,
          suspendedCount: suspendedCount,
          overrideCount: _intOf(data['access_grants']),
          fetchedAt: data['fetched_at'],
          onNavigate: onNavigate,
        ),
        const UiGap.v(20),
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
          description:
              'Tap a queue card to jump to moderation or open a live record preview below.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiCardGrid(
                minTileWidth: 220,
                children: [
                  for (final metric in [
                    (
                      'Affiliate applications',
                      'pending_applications',
                      'affiliate_reviews',
                      Icons.handshake_outlined,
                    ),
                    (
                      'Posts awaiting review',
                      'pending_posts',
                      'org_publishing',
                      Icons.article_outlined,
                    ),
                    (
                      'Comments awaiting review',
                      'pending_comments',
                      'admin_comments',
                      Icons.comment_outlined,
                    ),
                    (
                      'Deletion requests',
                      'pending_deletions',
                      'admin_deletions',
                      Icons.delete_outline,
                    ),
                  ])
                    UiMetricCard(
                      title: metric.$1,
                      value: '${data[metric.$2] ?? 0}',
                      icon: metric.$4,
                      intent: _intOf(data[metric.$2]) > 0
                          ? UiIntent.warning
                          : UiIntent.success,
                      onTap: onNavigate == null
                          ? null
                          : () => onNavigate!(metric.$3),
                    ),
                ],
              ),
              ..._buildQueuePreviews(context, data, onNavigate),
            ],
          ),
        ),
        const UiGap.v(20),
        _ResponsiveTwoColumn(
          left: UiCard(
            variant: UiCardVariant.surface,
            accentColor: colors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Account and tier distribution',
                  style: context.uiText.title,
                ),
                const UiGap.v(4),
                Text(
                  'Live breakdown across tiers and standing',
                  style: context.uiText.caption,
                ),
                const UiGap.v(16),
                UiDonutChart(
                  size: context.sz(168),
                  thickness: 22,
                  centerLabel: '${data['users'] ?? 0} total',
                  showLegend: true,
                  valueFormatter: (v) => v.toStringAsFixed(0),
                  slices: _accountTierSlices(context, data),
                ),
              ],
            ),
          ),
          right: UiCard(
            variant: UiCardVariant.surface,
            accentColor: colors.info,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Content footprint', style: context.uiText.title),
                const UiGap.v(4),
                Text(
                  'Published and workspace records by module',
                  style: context.uiText.caption,
                ),
                const UiGap.v(16),
                UiBarList(
                  valueFormatter: (v) => v.toStringAsFixed(0),
                  items: [
                    for (final entry in [
                      (
                        'Community posts',
                        _intOf(data['posts']),
                        'org_publishing',
                        Icons.article_outlined,
                        colors.primary,
                      ),
                      (
                        'Research notes',
                        _intOf(data['notes']),
                        'admin_notes',
                        Icons.note_outlined,
                        colors.info,
                      ),
                      (
                        'Journal entries',
                        _intOf(data['journal']),
                        'admin_journal',
                        Icons.book_outlined,
                        colors.success,
                      ),
                      (
                        'Strategies',
                        _intOf(data['strategies']),
                        'admin_strategies',
                        Icons.auto_graph_outlined,
                        colors.warning,
                      ),
                    ])
                      UiBarListItem(
                        label: entry.$1,
                        value: entry.$2,
                        icon: entry.$4,
                        color: entry.$5,
                        onTap: onNavigate == null
                            ? null
                            : () => onNavigate!(entry.$3),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const UiGap.v(20),
        _ActivityOverTimeSection(
          data: data,
          trend: trend,
          days: days,
          chartStyle: chartStyle,
          onChartStyleChanged: onChartStyleChanged,
          onDaysChanged: onDaysChanged,
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
        _RecentActivitySection(data: data),
        const UiGap.v(12),
        Text(
          'Updated ${adminDate(data['fetched_at'])}',
          style: context.uiText.caption,
        ),
      ],
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({
    required this.data,
    required this.days,
    required this.chartStyle,
    required this.onChartStyleChanged,
    required this.onDaysChanged,
    this.onNavigate,
  });

  final Map<String, dynamic> data;
  final int days;
  final String chartStyle;
  final ValueChanged<String> onChartStyleChanged;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<String>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final colors = context.ui.colors;
    final trend = _trendRows(data);
    final tierRows = _breakdownRows(data['tier_breakdown']);
    final roleRows = _breakdownRows(data['role_breakdown']);
    final aiProviders = _breakdownRows(data['ai_providers']);
    final modRows = _breakdownRows(data['moderation_breakdown']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCard(
          variant: UiCardVariant.surface,
          accentColor: colors.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Telemetry pulse · Last $days days',
                        style: context.uiText.title,
                      ),
                      const UiGap.v(2),
                      Text(
                        'Live metrics aggregated from database events',
                        style: context.uiText.caption,
                      ),
                    ],
                  ),
                  UiBadge(
                    label: 'Window: $days d',
                    intent: UiIntent.info,
                    variant: UiBadgeVariant.soft,
                  ),
                ],
              ),
              const UiGap.v(14),
              UiStatStrip(
                minCellWidth: 150,
                stats: [
                  UiStat(
                    label: 'Total accounts',
                    value: '${data['users'] ?? 0}',
                    hint: '${data['new_users'] ?? 0} new in ${days}d',
                    intent: UiIntent.primary,
                    icon: Icons.people_outline,
                    spark: _sparkSeries(trend, 'users'),
                  ),
                  UiStat(
                    label: 'Active actors',
                    value: '${data['active_users'] ?? 0}',
                    hint: 'Last $days days',
                    intent: UiIntent.success,
                    icon: Icons.bolt_outlined,
                    spark: _sparkSeries(trend, 'posts'),
                  ),
                  UiStat(
                    label: 'Messages sent',
                    value: '${data['messages'] ?? 0}',
                    hint: 'Last $days days',
                    intent: UiIntent.warning,
                    icon: Icons.forum_outlined,
                    spark: _sparkSeries(trend, 'messages'),
                  ),
                  UiStat(
                    label: 'AI requests',
                    value: '${data['ai_requests'] ?? 0}',
                    hint: 'Last $days days',
                    intent: UiIntent.info,
                    icon: Icons.auto_awesome_outlined,
                    spark: _sparkSeries(trend, 'ai_requests'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const UiGap.v(20),
        _ActivityOverTimeSection(
          data: data,
          trend: trend,
          days: days,
          chartStyle: chartStyle,
          onChartStyleChanged: onChartStyleChanged,
          onDaysChanged: onDaysChanged,
        ),
        const UiGap.v(20),
        _ResponsiveTwoColumn(
          left: UiCard(
            variant: UiCardVariant.surface,
            accentColor: colors.success,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Subscription tier & role mix',
                  style: context.uiText.title,
                ),
                const UiGap.v(4),
                Text(
                  'Share of registered accounts by billing tier',
                  style: context.uiText.caption,
                ),
                const UiGap.v(14),
                UiDonutChart(
                  size: context.sz(160),
                  thickness: 22,
                  centerLabel: '${data['subscriptions'] ?? 0} paid',
                  showLegend: true,
                  valueFormatter: (v) => v.toStringAsFixed(0),
                  slices: _accountTierSlices(context, data),
                ),
                if (tierRows.isNotEmpty) ...[
                  const UiGap.v(14),
                  UiKeyValueTable(
                    labelHeader: 'Tier',
                    valueHeader: 'Accounts',
                    rows: _kvRowsFromBreakdown(tierRows, _intOf(data['users'])),
                  ),
                ],
                if (roleRows.isNotEmpty) ...[
                  const UiGap.v(14),
                  Text('Access roles', style: context.uiText.subheading),
                  const UiGap.v(8),
                  UiCategoryBar(
                    categories: _categorySegments(context, roleRows),
                  ),
                ],
              ],
            ),
          ),
          right: UiCard(
            variant: UiCardVariant.surface,
            accentColor: colors.info,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'AI throughput & moderation funnel',
                  style: context.uiText.title,
                ),
                const UiGap.v(4),
                Text(
                  'Copilot traffic by provider and moderation posture',
                  style: context.uiText.caption,
                ),
                const UiGap.v(14),
                if (aiProviders.isNotEmpty)
                  UiBarList(
                    intent: UiIntent.info,
                    valueFormatter: (v) => v.toStringAsFixed(0),
                    items: [
                      for (final item in aiProviders)
                        UiBarListItem(
                          label: _prettyLabel(item.$1),
                          value: item.$2,
                          icon: Icons.smart_toy_outlined,
                          onTap: onNavigate == null
                              ? null
                              : () => onNavigate!('admin_ai'),
                        ),
                    ],
                  )
                else
                  UiMetricCard(
                    title: 'Recorded AI prompts ($days d)',
                    value: '${data['ai_requests'] ?? 0}',
                    caption: 'Copilot and prompt logs',
                    icon: Icons.auto_awesome_outlined,
                    onTap: onNavigate == null
                        ? null
                        : () => onNavigate!('admin_ai'),
                  ),
                const UiGap.v(16),
                Text('Moderation pipeline', style: context.uiText.subheading),
                const UiGap.v(8),
                UiCategoryBar(
                  categories: modRows.isNotEmpty
                      ? _categorySegments(context, modRows)
                      : [
                          UiCategorySegment(
                            label: 'Published posts',
                            value: _intOf(data['posts']).toDouble(),
                            color: colors.success,
                          ),
                          UiCategorySegment(
                            label: 'Pending queue',
                            value:
                                (_intOf(data['pending_posts']) +
                                        _intOf(data['pending_comments']))
                                    .toDouble(),
                            color: colors.warning,
                          ),
                          UiCategorySegment(
                            label: 'Deletions queued',
                            value: _intOf(data['pending_deletions']).toDouble(),
                            color: colors.danger,
                          ),
                        ],
                ),
              ],
            ),
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
        _RecentActivitySection(data: data),
        const UiGap.v(12),
        Text(
          'Updated ${adminDate(data['fetched_at'])}',
          style: context.uiText.caption,
        ),
      ],
    );
  }
}

class _CommandHeaderCard extends StatelessWidget {
  const _CommandHeaderCard({
    required this.title,
    required this.subtitle,
    required this.pendingTotal,
    required this.activeCount,
    required this.suspendedCount,
    required this.overrideCount,
    required this.fetchedAt,
    this.onNavigate,
  });

  final String title;
  final String subtitle;
  final int pendingTotal;
  final int activeCount;
  final int suspendedCount;
  final int overrideCount;
  final Object? fetchedAt;
  final ValueChanged<String>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final colors = context.ui.colors;
    return UiCard(
      variant: UiCardVariant.surface,
      accentColor: pendingTotal > 0 ? colors.warning : colors.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              UiBadge(
                label: pendingTotal > 0 ? 'Action needed' : 'Healthy',
                intent: pendingTotal > 0 ? UiIntent.warning : UiIntent.success,
              ),
              Text(adminDate(fetchedAt), style: context.uiText.caption),
            ],
          ),
          const UiGap.v(8),
          Text(title, style: context.uiText.title),
          const UiGap.v(2),
          Text(subtitle, style: context.uiText.caption),
          if (onNavigate != null) ...[
            const UiGap.v(12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                UiButton(
                  label: 'Users & access',
                  leadingIcon: Icons.people_outline,
                  size: UiSize.sm,
                  variant: UiVariant.soft,
                  onPressed: () => onNavigate!('org_team'),
                ),
                UiButton(
                  label: 'Moderation',
                  leadingIcon: Icons.article_outlined,
                  size: UiSize.sm,
                  variant: UiVariant.soft,
                  onPressed: () => onNavigate!('org_publishing'),
                ),
                UiButton(
                  label: 'Analytics',
                  leadingIcon: Icons.insights_outlined,
                  size: UiSize.sm,
                  variant: UiVariant.soft,
                  onPressed: () => onNavigate!('org_analytics'),
                ),
                UiButton(
                  label: 'App settings',
                  leadingIcon: Icons.tune_outlined,
                  size: UiSize.sm,
                  variant: UiVariant.outline,
                  onPressed: () => onNavigate!('org_risk'),
                ),
              ],
            ),
          ],
          const UiGap.v(16),
          UiCategoryBar(
            categories: [
              UiCategorySegment(
                label: 'Active',
                value: activeCount.toDouble(),
                color: colors.success,
              ),
              UiCategorySegment(
                label: 'Overrides',
                value: overrideCount.toDouble(),
                color: colors.info,
              ),
              UiCategorySegment(
                label: 'Suspended',
                value: suspendedCount.toDouble(),
                color: colors.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityOverTimeSection extends StatelessWidget {
  const _ActivityOverTimeSection({
    required this.data,
    required this.trend,
    required this.days,
    required this.chartStyle,
    required this.onChartStyleChanged,
    required this.onDaysChanged,
  });

  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> trend;
  final int days;
  final String chartStyle;
  final ValueChanged<String> onChartStyleChanged;
  final ValueChanged<int> onDaysChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.ui.colors;
    final chartData = [
      for (final point in trend)
        UiChartPoint(
          label: '${point['date']}'.split('T').first.split(' ').first,
          values: [
            for (final field in ['users', 'posts', 'messages', 'ai_requests'])
              (point[field] as num? ?? 0).toDouble(),
          ],
        ),
    ];
    final series = [
      UiChartSeries(name: 'New users', color: colors.primary),
      UiChartSeries(name: 'Posts', color: colors.success),
      UiChartSeries(name: 'Messages', color: colors.warning),
      UiChartSeries(name: 'AI requests', color: colors.info),
    ];

    return AdminSection(
      title: 'Activity over time',
      description:
          'Daily account registrations, posts, messages and AI requests recorded in the database. Dates use UTC.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
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
              UiToggleGroup<String>(
                value: chartStyle,
                options: const [
                  UiOption(value: 'area', label: 'Area'),
                  UiOption(value: 'bar', label: 'Bar'),
                ],
                onChanged: onChartStyleChanged,
              ),
            ],
          ),
          const UiGap.v(16),
          if (chartStyle == 'bar')
            UiBarChart(
              height: context.sz(260),
              data: chartData,
              series: series,
              valueFormatter: (value) => value.toStringAsFixed(0),
            )
          else
            UiAreaChart(
              height: context.sz(260),
              curved: false,
              data: chartData,
              series: series,
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
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final rows = (data['recent_activity'] as List? ?? [])
        .map((row) => AdminRecord(adminMap(row)))
        .toList();

    return AdminSection(
      title: 'Recent activity',
      description: data['history_started_at'] == null
          ? 'Activity history begins when changes are recorded. Earlier records retain their creation dates.'
          : 'Recorded history starts ${adminDate(data['history_started_at'])}. Earlier changes are not reconstructed.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rows.isNotEmpty) ...[
            UiTimeline(
              entries: [
                for (final row in rows.take(4))
                  UiTimelineEntry(
                    title: row.title,
                    subtitle: [
                      row.text('actor_handle'),
                      adminPreviewExcerpt(row, AdminResource.activity),
                    ].where((e) => e.isNotEmpty).join(' · '),
                    timestamp: adminDate(row.values['created_at']),
                    icon: Icons.history,
                    intent: UiIntent.primary,
                  ),
              ],
            ),
            const UiGap.v(14),
          ],
          UiTable<AdminRecord>(
            rows: rows,
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
        ],
      ),
    );
  }
}

class _ResponsiveTwoColumn extends StatelessWidget {
  const _ResponsiveTwoColumn({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (box.maxWidth < 860) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [left, const UiGap.v(16), right],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const UiGap.h(16),
          Expanded(child: right),
        ],
      );
    },
  );
}

List<Widget> _buildQueuePreviews(
  BuildContext context,
  Map<String, dynamic> data,
  ValueChanged<String>? onNavigate,
) {
  final previews = <(AdminResource, String, AdminRecord)>[
    for (final item in (data['preview_applications'] as List? ?? []))
      (
        AdminResource.applications,
        'affiliate_reviews',
        AdminRecord(adminMap(item)),
      ),
    for (final item in (data['preview_posts'] as List? ?? []))
      (AdminResource.posts, 'org_publishing', AdminRecord(adminMap(item))),
    for (final item in (data['preview_deletions'] as List? ?? []))
      (AdminResource.deletions, 'admin_deletions', AdminRecord(adminMap(item))),
  ];
  if (previews.isEmpty) return const [];

  return [
    const UiGap.v(16),
    Text('Live queue previews', style: context.uiText.subheading),
    const UiGap.v(10),
    UiCardGrid(
      minTileWidth: 280,
      children: [
        for (final item in previews.take(6))
          AdminVisualRecordCard(
            resource: item.$1,
            record: item.$3,
            onPreview: () => UiDrawer.show<void>(
              context,
              title: item.$3.title,
              child: AdminRecordPreviewContent(
                resource: item.$1,
                record: item.$3,
              ),
              footer: onNavigate == null
                  ? null
                  : UiButton(
                      label: 'Open queue',
                      leadingIcon: Icons.open_in_new,
                      onPressed: () {
                        Navigator.of(context).pop();
                        onNavigate(item.$2);
                      },
                    ),
            ),
            onOpenDetails: onNavigate == null
                ? () {}
                : () => onNavigate(item.$2),
          ),
      ],
    ),
  ];
}

List<Map<String, dynamic>> _trendRows(Map<String, dynamic> data) =>
    (data['trend'] as List? ?? []).map(adminMap).toList();

List<double> _sparkSeries(List<Map<String, dynamic>> trend, String field) => [
  for (final point in trend) (point[field] as num? ?? 0).toDouble(),
];

int _intOf(Object? value) => value is num ? value.toInt() : 0;

List<(String, int)> _breakdownRows(Object? raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        if (item is Map)
          (
            () {
              final provider = item['provider']?.toString().trim() ?? '';
              final model = item['model']?.toString().trim() ?? '';
              if (provider.isNotEmpty) {
                return model.isNotEmpty && model != provider
                    ? '$provider · $model'
                    : provider;
              }
              return '${item['label'] ?? item['name'] ?? 'other'}';
            }(),
            _intOf(item['count'] ?? item['value']),
          ),
    ];
  }
  if (raw is Map) {
    return [
      for (final entry in raw.entries) ('${entry.key}', _intOf(entry.value)),
    ];
  }
  return const [];
}

List<UiDonutSlice> _accountTierSlices(
  BuildContext context,
  Map<String, dynamic> data,
) {
  final colors = context.ui.colors;
  final tiers = _breakdownRows(data['tier_breakdown']);
  final palette = [
    colors.primary,
    colors.success,
    colors.info,
    colors.warning,
    colors.foregroundMuted,
  ];
  if (tiers.isNotEmpty) {
    return [
      for (var i = 0; i < tiers.length; i++)
        UiDonutSlice(
          label: _prettyLabel(tiers[i].$1),
          value: tiers[i].$2.toDouble(),
          color: palette[i % palette.length],
        ),
    ];
  }
  final paid = _intOf(data['subscriptions']);
  final users = _intOf(data['users']);
  final suspended = _intOf(data['suspended_accounts']);
  final standard = (users - paid - suspended).clamp(0, users);
  return [
    UiDonutSlice(
      label: 'Paid tier',
      value: paid.toDouble(),
      color: colors.success,
    ),
    UiDonutSlice(
      label: 'Standard',
      value: standard.toDouble(),
      color: colors.primary,
    ),
    if (suspended > 0)
      UiDonutSlice(
        label: 'Suspended',
        value: suspended.toDouble(),
        color: colors.danger,
      ),
  ];
}

List<UiCategorySegment> _categorySegments(
  BuildContext context,
  List<(String, int)> rows,
) {
  final colors = context.ui.colors;
  final palette = [
    colors.success,
    colors.primary,
    colors.warning,
    colors.info,
    colors.danger,
  ];
  return [
    for (var i = 0; i < rows.length; i++)
      UiCategorySegment(
        label: _prettyLabel(rows[i].$1),
        value: rows[i].$2.toDouble(),
        color: palette[i % palette.length],
      ),
  ];
}

List<UiKeyValueRow> _kvRowsFromBreakdown(
  List<(String, int)> rows,
  int totalUsers,
) {
  final denominator = totalUsers > 0
      ? totalUsers
      : rows.fold<int>(0, (sum, r) => sum + r.$2).clamp(1, 100000000);
  return [
    for (final row in rows)
      UiKeyValueRow(
        label: _prettyLabel(row.$1),
        value: '${row.$2}',
        trailing: '${((row.$2 * 100) / denominator).round()}%',
        share: (row.$2 / denominator).clamp(0.0, 1.0),
      ),
  ];
}

String _prettyLabel(String raw) {
  final text = raw.replaceAll('_', ' ').trim();
  if (text.isEmpty) return 'Other';
  return '${text[0].toUpperCase()}${text.substring(1)}';
}
