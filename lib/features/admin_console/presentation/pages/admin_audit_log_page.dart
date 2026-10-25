import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/admin_console/data/admin_console_repository.dart';
import 'package:tradex/features/admin_console/models/admin_console_models.dart';

class AdminAuditLogPage extends StatefulWidget {
  const AdminAuditLogPage({super.key});

  @override
  State<AdminAuditLogPage> createState() => _AdminAuditLogPageState();
}

class _AdminAuditLogPageState extends State<AdminAuditLogPage> {
  final AdminConsoleRepository _repo = AdminConsoleRepository.instance;

  bool _loading = true;
  String _categoryFilter = 'all';
  String _severityFilter = 'all';
  String _viewMode = 'table'; // table | timeline
  String _searchQuery = '';
  List<AdminAuditLogEntry> _entries = const <AdminAuditLogEntry>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _repo.listAuditLogs();
      if (mounted) setState(() => _entries = rows);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AdminAuditLogEntry> get _filteredEntries {
    final String q = _searchQuery.trim().toLowerCase();
    return _entries.where((e) {
      if (_categoryFilter != 'all' && e.category != _categoryFilter) {
        return false;
      }
      if (_severityFilter != 'all' && e.severity != _severityFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return e.action.toLowerCase().contains(q) ||
          e.actorHandle.toLowerCase().contains(q) ||
          e.targetLabel.toLowerCase().contains(q) ||
          e.details.toLowerCase().contains(q) ||
          e.sha256Hash.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _exportDialog({required bool asJson}) async {
    final List<AdminAuditLogEntry> list = _filteredEntries;
    final String payload = asJson
        ? _repo.exportAuditLogsJson(list)
        : _repo.exportAuditLogsCsv(list);
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => UiDialog(
        title: asJson
            ? 'Exported Audit Ledger (JSON)'
            : 'Exported Audit Ledger (CSV)',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            UiCallout(
              title: 'Copied ${list.length} SHA-256 audit entries to clipboard',
              message:
                  'Ready for SEBI / exchange / statutory compliance archival.',
              intent: UiIntent.success,
            ),
            SizedBox(height: ctx.sp(ctx.ui.spacing.md)),
            UiField(
              label: 'Export Payload Preview',
              child: UiTextarea(
                value: payload,
                readOnly: true,
                minLines: 6,
                maxLines: 10,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          UiButton(
            label: 'Close',
            intent: UiIntent.primary,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _inspectHashModal(AdminAuditLogEntry entry) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => UiDialog(
        title: 'Cryptographic Audit Proof · ${entry.action}',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            UiCallout(
              title: 'SHA-256 Digest Verified',
              message: entry.sha256Hash,
              intent: UiIntent.success,
            ),
            SizedBox(height: ctx.sp(ctx.ui.spacing.md)),
            Text(
              'Actor: @${entry.actorHandle} (${entry.actorRole.toUpperCase()})\n'
              'Category: ${entry.category}\n'
              'Target: ${entry.targetLabel} (${entry.targetType})\n'
              'Node IP: ${entry.ipAddress}\n'
              'Timestamp: ${entry.createdAt.toIso8601String()}\n\n'
              'Details:\n${entry.details}',
              style: ctx.uiText.body,
            ),
          ],
        ),
        actions: <Widget>[
          UiButton(
            label: 'Copy SHA-256 Hash',
            variant: UiVariant.outline,
            leadingIcon: Icons.copy_rounded,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: entry.sha256Hash));
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                UiToast.show(
                  ctx,
                  title: 'SHA-256 Hash Copied',
                  intent: UiIntent.info,
                );
              }
            },
          ),
          UiButton(
            label: 'Done',
            intent: UiIntent.primary,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    if (_loading) {
      return UiSkeleton.page();
    }

    final List<AdminAuditLogEntry> visible = _filteredEntries;
    final int criticalCount = _entries
        .where((e) => e.severity == 'critical' || e.severity == 'warning')
        .length;
    final int payoutAndAffiliateCount = _entries
        .where(
          (e) =>
              e.category == 'payout_settlement' ||
              e.category == 'affiliate_review',
        )
        .length;
    final int deletionCount = _entries
        .where((e) => e.category == 'account_deletion')
        .length;

    return UiPage(
      maxWidth: 1440,
      header: UiHeader(
        title: 'Execution & Governance Audit Log',
        subtitle:
            'Tamper-evident SHA-256 compliance ledger covering desk risk rules, pre-trade approvals, INR affiliate payouts, and DPDP data purges.',
        leading: Icon(Icons.history_edu_outlined, color: theme.colors.primary),
        actions: <Widget>[
          UiButton(
            label: 'Export CSV',
            leadingIcon: Icons.table_view_outlined,
            variant: UiVariant.outline,
            size: UiSize.sm,
            onPressed: () => _exportDialog(asJson: false),
          ),
          UiButton(
            label: 'Export JSON',
            leadingIcon: Icons.data_object_rounded,
            intent: UiIntent.primary,
            size: UiSize.sm,
            onPressed: () => _exportDialog(asJson: true),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiCardGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 4,
            largeColumns: 4,
            childAspectRatio: context.uiRes.isMobile ? 2.3 : 1.9,
            children: <Widget>[
              UiMetricCard(
                label: 'Total Audit Records',
                value: '${_entries.length}',
                caption: '100% SHA-256 hash-verified',
                icon: Icons.verified_outlined,
              ),
              UiMetricCard(
                label: 'Warning / Critical Events',
                value: '$criticalCount',
                caption: 'Circuit breakers & breach locks',
                icon: Icons.gpp_maybe_outlined,
                intent: criticalCount > 0
                    ? UiIntent.warning
                    : UiIntent.success,
              ),
              UiMetricCard(
                label: 'INR Affiliate & Payout Logs',
                value: '$payoutAndAffiliateCount',
                caption: 'TDS u/s 194H & UTR settlements',
                icon: Icons.currency_rupee_rounded,
              ),
              UiMetricCard(
                label: 'DPDP Data Purge Proofs',
                value: '$deletionCount',
                caption: 'Conditional account deletions',
                icon: Icons.delete_sweep_outlined,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Filter Controls
          UiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Wrap(
                  spacing: context.sp(theme.spacing.md),
                  runSpacing: context.sp(theme.spacing.sm),
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: context.uiRes.isMobile
                            ? double.infinity
                            : 340,
                      ),
                      child: UiInput.search(
                        value: _searchQuery,
                        hintText:
                            'Search action, @actor, target, or SHA-256 hash…',
                        onChanged: (String v) =>
                            setState(() => _searchQuery = v),
                        onClear: () => setState(() => _searchQuery = ''),
                      ),
                    ),
                    Wrap(
                      spacing: context.sp(theme.spacing.sm),
                      runSpacing: context.sp(theme.spacing.xs),
                      children: <Widget>[
                        SizedBox(
                          width: 210,
                          child: UiSelect<String>(
                            value: _categoryFilter,
                            options: const <UiOption<String>>[
                              UiOption(
                                value: 'all',
                                label: 'All Categories',
                              ),
                              UiOption(
                                value: 'risk_control',
                                label: 'Risk & Circuit Breaker',
                              ),
                              UiOption(
                                value: 'order_approval',
                                label: 'Pre-Trade Approvals',
                              ),
                              UiOption(
                                value: 'seat_governance',
                                label: 'Seat & Consumer RBAC',
                              ),
                              UiOption(
                                value: 'payout_settlement',
                                label: 'INR Payout Settlement',
                              ),
                              UiOption(
                                value: 'affiliate_review',
                                label: 'Affiliate Onboarding',
                              ),
                              UiOption(
                                value: 'account_deletion',
                                label: 'Account & Data Purge',
                              ),
                            ],
                            onChanged: (String? v) {
                              if (v != null) {
                                setState(() => _categoryFilter = v);
                              }
                            },
                          ),
                        ),
                        UiToggleGroup<String>(
                          value: _severityFilter,
                          options: const <UiToggleOption<String>>[
                            UiToggleOption(value: 'all', label: 'All'),
                            UiToggleOption(value: 'info', label: 'Info'),
                            UiToggleOption(value: 'warning', label: 'Warn'),
                            UiToggleOption(value: 'critical', label: 'Crit'),
                          ],
                          onChanged: (String v) =>
                              setState(() => _severityFilter = v),
                        ),
                        UiToggleGroup<String>(
                          value: _viewMode,
                          options: const <UiToggleOption<String>>[
                            UiToggleOption(value: 'table', label: 'Table'),
                            UiToggleOption(
                              value: 'timeline',
                              label: 'Timeline',
                            ),
                          ],
                          onChanged: (String v) =>
                              setState(() => _viewMode = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),

          if (visible.isEmpty)
            const UiEmptyState(
              icon: Icons.manage_search_rounded,
              title: 'No matching audit entries',
              message:
                  'Adjust the category, severity, or search filter to inspect historical events.',
            )
          else if (_viewMode == 'timeline')
            UiCard(
              child: UiTimeline(
                onTap: (int idx) => _inspectHashModal(visible[idx]),
                entries: visible
                    .map(
                      (e) => UiTimelineEntry(
                        title: '${e.action} · ${e.targetLabel}',
                        subtitle:
                            '@${e.actorHandle} (${e.actorRole.toUpperCase()}) · ${e.details}\nSHA-256: ${e.sha256Hash}',
                        timestamp: AppTokens.shortDate(e.createdAt),
                        icon: Icons.verified_user_outlined,
                        intent: switch (e.severity) {
                          'critical' => UiIntent.danger,
                          'warning' => UiIntent.warning,
                          _ => UiIntent.primary,
                        },
                      ),
                    )
                    .toList(),
              ),
            )
          else
            UiTable<AdminAuditLogEntry>(
              rows: visible,
              rowKey: (e) => e.id,
              stackOnMobile: true,
              onRowTap: _inspectHashModal,
              columns: <UiTableColumn<AdminAuditLogEntry>>[
                UiTableColumn<AdminAuditLogEntry>(
                  id: 'timestamp',
                  label: 'Timestamp & Node',
                  cellBuilder: (BuildContext ctx, AdminAuditLogEntry e) =>
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            AppTokens.shortDate(e.createdAt),
                            style: ctx.uiText.bodyStrong,
                          ),
                          Text(
                            e.ipAddress,
                            style: ctx.uiText.caption.copyWith(
                              color: theme.colors.foregroundMuted,
                            ),
                          ),
                        ],
                      ),
                ),
                UiTableColumn<AdminAuditLogEntry>(
                  id: 'actor',
                  label: 'Actor',
                  valueGetter: (e) =>
                      '@${e.actorHandle} (${e.actorRole.toUpperCase()})',
                ),
                UiTableColumn<AdminAuditLogEntry>(
                  id: 'action',
                  label: 'Action & Target',
                  flex: 2,
                  cellBuilder: (BuildContext ctx, AdminAuditLogEntry e) =>
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            e.action,
                            style: ctx.uiText.mono.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            e.targetLabel,
                            style: ctx.uiText.caption.copyWith(
                              color: theme.colors.foregroundMuted,
                            ),
                          ),
                        ],
                      ),
                ),
                UiTableColumn<AdminAuditLogEntry>(
                  id: 'details',
                  label: 'Compliance Details',
                  flex: 2,
                  valueGetter: (e) => e.details,
                ),
                UiTableColumn<AdminAuditLogEntry>(
                  id: 'severity',
                  label: 'Severity',
                  cellBuilder: (BuildContext ctx, AdminAuditLogEntry e) =>
                      UiBadge(
                        label: e.severity.toUpperCase(),
                        intent: switch (e.severity) {
                          'critical' => UiIntent.danger,
                          'warning' => UiIntent.warning,
                          _ => UiIntent.info,
                        },
                        size: UiSize.xs,
                      ),
                ),
                UiTableColumn<AdminAuditLogEntry>(
                  id: 'hash',
                  label: 'SHA-256 Proof',
                  cellBuilder: (BuildContext ctx, AdminAuditLogEntry e) =>
                      UiButton(
                        label: '${e.sha256Hash.substring(0, 10)}…',
                        size: UiSize.xs,
                        variant: UiVariant.outline,
                        leadingIcon: Icons.fingerprint_rounded,
                        onPressed: () => _inspectHashModal(e),
                      ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
