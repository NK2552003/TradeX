import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../../data/admin_repository.dart';
import '../../models/admin_records.dart';
import 'admin_facts.dart';

class AdminRecordsPanel extends StatefulWidget {
  const AdminRecordsPanel({
    super.key,
    required this.resource,
    required this.repository,
    required this.onOpen,
    this.userId,
    this.parentId,
    this.initialStatus = 'all',
    this.revision = 0,
  });
  final AdminResource resource;
  final AdminRepository repository;
  final ValueChanged<AdminRecord> onOpen;
  final String? userId;
  final String? parentId;
  final String initialStatus;
  final int revision;

  @override
  State<AdminRecordsPanel> createState() => _AdminRecordsPanelState();
}

class _AdminRecordsPanelState extends State<AdminRecordsPanel> {
  AdminPageData? _data;
  String? _error;
  String _search = '';
  late String _status = widget.initialStatus;
  int _page = 0;
  int _days = 0;
  int _request = 0;
  bool _loading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminRecordsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resource != widget.resource ||
        oldWidget.userId != widget.userId ||
        oldWidget.parentId != widget.parentId ||
        oldWidget.revision != widget.revision) {
      _page = 0;
      _status = widget.initialStatus;
      _load();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repository.list(
        widget.resource,
        userId: widget.userId,
        parentId: widget.parentId,
        search: _search,
        status: _status,
        page: _page,
        from: _days == 0
            ? null
            : DateTime.now().subtract(Duration(days: _days)),
      );
      if (!mounted || request != _request) return;
      if (_page >= result.totalPages) {
        _page = result.totalPages - 1;
        await _load();
        return;
      }
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _error = adminError(error);
        });
      }
    }
  }

  void _searchChanged(String value) {
    setState(() {
      _search = value;
      _page = 0;
    });
    // Invalidate in-flight results before the debounce fires.
    _request++;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      UiInput.search(
        value: _search,
        hintText: widget.resource.searchHint,
        onChanged: _searchChanged,
        onClear: () => _searchChanged(''),
      ),
      const UiGap.v(12),
      Wrap(
        spacing: context.sp(context.ui.spacing.sm),
        runSpacing: context.sp(context.ui.spacing.sm),
        children: [
          if (widget.resource.statuses.isNotEmpty)
            UiSelect<String>(
              label: widget.resource == AdminResource.activity
                  ? 'Category'
                  : 'Status',
              value: _status,
              options: [
                const UiOption(value: 'all', label: 'All'),
                for (final status in widget.resource.statuses)
                  UiOption(value: status, label: adminLabel(status)),
              ],
              onChanged: (value) {
                setState(() {
                  _status = value;
                  _page = 0;
                });
                _load();
              },
            ),
          UiSelect<int>(
            label: 'Created',
            value: _days,
            options: const [
              UiOption(value: 0, label: 'All time'),
              UiOption(value: 7, label: 'Last 7 days'),
              UiOption(value: 30, label: 'Last 30 days'),
              UiOption(value: 90, label: 'Last 90 days'),
            ],
            onChanged: (value) {
              setState(() {
                _days = value;
                _page = 0;
              });
              _load();
            },
          ),
          UiButton(
            label: 'Refresh',
            leadingIcon: Icons.refresh,
            variant: UiVariant.outline,
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      const UiGap.v(16),
      UiAsyncView<AdminPageData>(
        loading: _loading,
        error: _error,
        data: _data,
        loadingMessage: 'Loading ${widget.resource.label.toLowerCase()}…',
        onRetry: _load,
        isEmpty: !_loading && _error == null && _data?.rows.isEmpty == true,
        emptyTitle: 'No ${widget.resource.label.toLowerCase()} found',
        emptyMessage: 'Try changing the search or filters.',
        dataBuilder: (BuildContext context, AdminPageData result) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${result.total} records · newest first',
              style: context.uiText.caption,
            ),
            const UiGap.v(8),
            UiTable<AdminRecord>(
              rows: result.rows,
              rowKey: (row) => row.id,
              onRowTap: widget.onOpen,
              stackOnMobile: true,
              columns: [
                UiTableColumn(
                  header: widget.resource == AdminResource.users
                      ? 'User'
                      : 'Record',
                  flex: 3,
                  cell: (context, row) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.label,
                      ),
                      if (row.text('email').isNotEmpty)
                        Text(row.text('email'), style: context.uiText.caption),
                      if (row.text('author').isNotEmpty)
                        Text(row.text('author'), style: context.uiText.caption),
                    ],
                  ),
                ),
                UiTableColumn(
                  header: 'Status',
                  cell: (context, row) => UiBadge(
                    label: adminLabel(row.status),
                    intent: switch (row.status) {
                      'active' ||
                      'approved' ||
                      'paid' ||
                      'complete' => UiIntent.success,
                      'suspended' ||
                      'rejected' ||
                      'restricted' ||
                      'failed' => UiIntent.danger,
                      'pending' ||
                      'pending_approval' ||
                      'processing' => UiIntent.warning,
                      _ => UiIntent.neutral,
                    },
                  ),
                ),
                UiTableColumn(
                  header: _detailHeading,
                  flex: 2,
                  valueGetter: _detail,
                ),
                UiTableColumn(
                  header: 'Created',
                  valueGetter: (row) => adminDate(row.values['created_at']),
                ),
                UiTableColumn(
                  header: 'Open',
                  width: 112,
                  cell: (context, row) => UiButton(
                    label: 'Details',
                    variant: UiVariant.ghost,
                    size: UiSize.sm,
                    onPressed: () => widget.onOpen(row),
                  ),
                ),
              ],
            ),
            const UiGap.v(12),
            UiPagination(
              currentPage: _page + 1,
              totalPages: result.totalPages,
              onPageChanged: (page) {
                setState(() => _page = page - 1);
                _load();
              },
            ),
          ],
        ),
      ),
    ],
  );

  String get _detailHeading => switch (widget.resource) {
    AdminResource.users || AdminResource.subscriptions => 'Plan / role',
    AdminResource.posts => 'Engagement',
    AdminResource.affiliates => 'Commission',
    AdminResource.activity => 'Target',
    _ => 'Details',
  };

  String _detail(AdminRecord row) => switch (widget.resource) {
    AdminResource.users =>
      '${adminLabel(row.text('tier'))} · ${adminLabel(row.text('role'))}',
    AdminResource.subscriptions =>
      '${adminLabel(row.text('tier'))} · ${row.text('billing_provider', 'No provider')}',
    AdminResource.posts =>
      '${row.count('views_count')} views · ${row.count('likes_count')} likes · ${row.count('comments_count')} comments',
    AdminResource.comments => '${row.count('likes_count')} likes',
    AdminResource.notes ||
    AdminResource.journal ||
    AdminResource.strategies => '${row.count('word_count')} words',
    AdminResource.applications =>
      '${row.text('primary_platform')} · ${row.text('audience_reach')}',
    AdminResource.affiliates =>
      '${((row.values['commission_rate'] as num? ?? 0) * 100).toStringAsFixed(1)}% · ${adminLabel(row.text('tier'))}',
    AdminResource.payouts => '${row.text('amount')} ${row.text('currency')}',
    AdminResource.activity => adminLabel(row.text('target_type')),
    AdminResource.ai =>
      '${row.count('messages_count')} messages · ${adminLabel(row.text('persona'))}',
    AdminResource.aiRequests => row.text('ticker', 'No ticker'),
    AdminResource.deletions => adminDate(row.values['scheduled_purge_at']),
    _ => row.text('thread_id', row.text('referral_code', '—')),
  };
}
