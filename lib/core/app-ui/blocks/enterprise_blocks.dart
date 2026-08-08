import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models_extra.dart';
import '../theme/app_tokens.dart';

String appTeamRoleLabel(AppTeamRole role) => switch (role) {
      AppTeamRole.owner => 'Owner',
      AppTeamRole.admin => 'Admin',
      AppTeamRole.analyst => 'Analyst',
      AppTeamRole.member => 'Member',
      AppTeamRole.viewer => 'Viewer',
    };

UiIntent appTeamRoleIntent(AppTeamRole role) => switch (role) {
      AppTeamRole.owner => UiIntent.primary,
      AppTeamRole.admin => UiIntent.info,
      AppTeamRole.analyst => UiIntent.bullish,
      AppTeamRole.member => UiIntent.neutral,
      AppTeamRole.viewer => UiIntent.neutral,
    };

/// Team roster with roles, status and per-member actions.
class AppTeamMembersBlock extends StatelessWidget {
  const AppTeamMembersBlock({
    super.key,
    required this.members,
    this.loading = false,
    this.onInvite,
    this.onMemberTap,
    this.onChangeRole,
    this.onRemove,
  });

  final List<AppTeamMember> members;
  final bool loading;
  final VoidCallback? onInvite;
  final ValueChanged<AppTeamMember>? onMemberTap;
  final ValueChanged<AppTeamMember>? onChangeRole;
  final ValueChanged<AppTeamMember>? onRemove;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: 'Team',
      subtitle: '${members.length} member(s)',
      trailing: UiButton(
        label: 'Invite',
        size: UiSize.sm,
        leadingIcon: Icons.person_add_alt,
        expandOnMobile: false,
        onPressed: onInvite,
      ),
      child: UiAsyncView(
        loading: loading,
        isEmpty: members.isEmpty,
        emptyTitle: 'No members yet',
        emptyMessage: 'Invite teammates to share journals and strategies.',
        emptyIcon: Icons.groups_outlined,
        builder: (BuildContext ctx) => UiTable<AppTeamMember>(
          rows: members,
          onRowTap: onMemberTap,
          stackOnMobile: true,
          columns: <UiTableColumn<AppTeamMember>>[
            UiTableColumn<AppTeamMember>(
              header: 'Member',
              flex: 2,
              cell: (BuildContext c, AppTeamMember m) => Row(
                children: <Widget>[
                  UiAvatar(imageUrl: m.avatarUrl, name: m.name, size: UiSize.sm),
                  SizedBox(width: ctx.sp(theme.spacing.sm)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(m.name, style: ctx.uiText.bodyStrong),
                        Text(
                          m.email,
                          overflow: TextOverflow.ellipsis,
                          style: ctx.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            UiTableColumn<AppTeamMember>(
              header: 'Role',
              cell: (BuildContext c, AppTeamMember m) => UiBadge(
                label: appTeamRoleLabel(m.role),
                intent: appTeamRoleIntent(m.role),
                onTap:
                    onChangeRole == null ? null : () => onChangeRole!(m),
              ),
            ),
            UiTableColumn<AppTeamMember>(
              header: 'Status',
              hideBelow: UiTableVisibility.tabletUp,
              cell: (BuildContext c, AppTeamMember m) => UiBadge(
                label: switch (m.status) {
                  AppMemberStatus.active => 'Active',
                  AppMemberStatus.invited => 'Invited',
                  AppMemberStatus.suspended => 'Suspended',
                },
                intent: switch (m.status) {
                  AppMemberStatus.active => UiIntent.bullish,
                  AppMemberStatus.invited => UiIntent.warning,
                  AppMemberStatus.suspended => UiIntent.bearish,
                },
              ),
            ),
            UiTableColumn<AppTeamMember>(
              header: 'Last active',
              hideBelow: UiTableVisibility.desktopUp,
              cell: (BuildContext c, AppTeamMember m) => Text(
                m.lastActiveAt == null
                    ? '—'
                    : AppTokens.relativeTime(m.lastActiveAt!),
                style: ctx.uiText.caption
                    .copyWith(color: theme.colors.foregroundMuted),
              ),
            ),
            UiTableColumn<AppTeamMember>(
              header: '',
              width: ctx.sz(48),
              cell: (BuildContext c, AppTeamMember m) => UiIconButton(
                icon: Icons.person_remove_outlined,
                size: UiSize.sm,
                tooltip: 'Remove',
                onPressed: onRemove == null ? null : () => onRemove!(m),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Immutable audit trail of workspace actions.
class AppAuditLogBlock extends StatelessWidget {
  const AppAuditLogBlock({
    super.key,
    required this.entries,
    this.loading = false,
    this.onExport,
  });

  final List<AppAuditEntry> entries;
  final bool loading;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    return UiCard(
      title: 'Audit log',
      subtitle: 'Every privileged action, retained for compliance',
      trailing: UiButton(
        label: 'Export',
        size: UiSize.sm,
        variant: UiVariant.outline,
        leadingIcon: Icons.download_outlined,
        expandOnMobile: false,
        onPressed: onExport,
      ),
      child: UiAsyncView(
        loading: loading,
        isEmpty: entries.isEmpty,
        emptyTitle: 'No activity recorded',
        emptyIcon: Icons.receipt_long_outlined,
        builder: (BuildContext ctx) => UiTimeline(
          entries: <UiTimelineEntry>[
            for (final AppAuditEntry e in entries)
              UiTimelineEntry(
                title: '${e.actor} · ${e.action}',
                subtitle: <String?>[e.target, e.ip]
                    .whereType<String>()
                    .join(' · '),
                timestamp: AppTokens.relativeTime(e.at),
                icon: Icons.shield_outlined,
                intent: UiIntent.info,
              ),
          ],
        ),
      ),
    );
  }
}

/// API key management for programmatic access.
class AppApiKeysBlock extends StatelessWidget {
  const AppApiKeysBlock({
    super.key,
    required this.keys,
    this.onCreate,
    this.onRevoke,
    this.onCopy,
    this.loading = false,
  });

  final List<AppApiKey> keys;
  final VoidCallback? onCreate;
  final ValueChanged<AppApiKey>? onRevoke;
  final ValueChanged<AppApiKey>? onCopy;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: 'API keys',
      subtitle: 'Keys are shown once at creation',
      trailing: UiButton(
        label: 'New key',
        size: UiSize.sm,
        leadingIcon: Icons.key_outlined,
        expandOnMobile: false,
        onPressed: onCreate,
      ),
      child: UiAsyncView(
        loading: loading,
        isEmpty: keys.isEmpty,
        emptyTitle: 'No API keys',
        emptyMessage: 'Create a key to sync trades from your broker.',
        emptyIcon: Icons.vpn_key_outlined,
        builder: (BuildContext ctx) => Column(
          children: <Widget>[
            for (final AppApiKey k in keys)
              Padding(
                padding: EdgeInsets.only(bottom: ctx.sp(theme.spacing.sm)),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(k.label,
                                    style: ctx.uiText.bodyStrong,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              SizedBox(width: ctx.sp(theme.spacing.xs)),
                              if (k.revoked)
                                const UiBadge(
                                  label: 'Revoked',
                                  intent: UiIntent.bearish,
                                ),
                            ],
                          ),
                          Text(
                            k.maskedKey,
                            style: ctx.uiText.numeric.copyWith(
                              color: theme.colors.foregroundMuted,
                            ),
                          ),
                          Text(
                            k.lastUsedAt == null
                                ? 'Never used'
                                : 'Last used ${AppTokens.relativeTime(k.lastUsedAt!)}',
                            style: ctx.uiText.caption.copyWith(
                              color: theme.colors.foregroundSubtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    UiIconButton(
                      icon: Icons.copy_all_outlined,
                      size: UiSize.sm,
                      tooltip: 'Copy',
                      onPressed: onCopy == null ? null : () => onCopy!(k),
                    ),
                    UiIconButton(
                      icon: Icons.block,
                      size: UiSize.sm,
                      tooltip: 'Revoke',
                      onPressed: k.revoked || onRevoke == null
                          ? null
                          : () => onRevoke!(k),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Plan usage meters (AI credits, seats, storage, API calls).
class AppUsageBlock extends StatelessWidget {
  const AppUsageBlock({
    super.key,
    required this.metrics,
    this.onUpgrade,
    this.title = 'Usage this cycle',
  });

  final List<AppUsageMetric> metrics;
  final VoidCallback? onUpgrade;
  final String title;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: title,
      footer: onUpgrade == null
          ? null
          : UiButton(
              label: 'Upgrade plan',
              variant: UiVariant.outline,
              leadingIcon: Icons.upgrade,
              onPressed: onUpgrade,
            ),
      child: Column(
        children: <Widget>[
          for (final AppUsageMetric m in metrics)
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.md)),
              child: UiProgressBar(
                value: m.ratio,
                label: m.label,
                intent: m.ratio >= 0.9
                    ? UiIntent.bearish
                    : (m.ratio >= 0.7 ? UiIntent.warning : UiIntent.primary),
                valueFormatter: (num _) =>
                    '${m.used.toStringAsFixed(0)} / ${m.limit.toStringAsFixed(0)}'
                    '${m.unit == null ? '' : ' ${m.unit}'}',
              ),
            ),
        ],
      ),
    );
  }
}
