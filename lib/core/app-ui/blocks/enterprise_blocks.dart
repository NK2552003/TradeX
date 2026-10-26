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
                  UiAvatar(
                    imageUrl: m.avatarUrl,
                    name: m.name,
                    size: UiSize.sm,
                  ),
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
                onTap: onChangeRole == null ? null : () => onChangeRole!(m),
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
                style: ctx.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
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
                subtitle: <String?>[
                  e.target,
                  e.ip,
                ].whereType<String>().join(' · '),
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
                                child: Text(
                                  k.label,
                                  style: ctx.uiText.bodyStrong,
                                  overflow: TextOverflow.ellipsis,
                                ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Institutional Desk Console Reusable Blocks & Overlays
// ─────────────────────────────────────────────────────────────────────────────

/// Live status strip with pulsing heartbeat and top-level institutional metrics.
class DeskStatusBar extends StatelessWidget {
  const DeskStatusBar({
    super.key,
    required this.isHalted,
    required this.supervisedCapitalInr,
    required this.allocatedCapitalInr,
    required this.seatCount,
    required this.maxDrawdownPct,
    this.statusText,
  });

  final bool isHalted;
  final double supervisedCapitalInr;
  final double allocatedCapitalInr;
  final int seatCount;
  final double maxDrawdownPct;
  final String? statusText;

  static String _formatCompact(double val) {
    final double abs = val.abs();
    if (abs >= 10000000) {
      return '₹${(abs / 10000000).toStringAsFixed(2)} Cr';
    }
    if (abs >= 100000) {
      return '₹${(abs / 100000).toStringAsFixed(2)} L';
    }
    return '₹${val.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;

    final Color statusColor = isHalted ? c.destructive : c.bullish;
    final String label =
        statusText ??
        (isHalted ? 'Desk execution halted' : 'Desk execution active');

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: context.sp(theme.spacing.sm),
        horizontal: context.sp(theme.spacing.xs),
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: c.border, width: theme.borders.hairline),
          bottom: BorderSide(color: c.border, width: theme.borders.hairline),
        ),
      ),
      child: Wrap(
        spacing: context.sp(theme.spacing.lg),
        runSpacing: context.sp(theme.spacing.xs),
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _PulsingDot(color: statusColor),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Text(
                label,
                style: context.uiText.bodyStrong.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          RichText(
            text: TextSpan(
              style: context.uiText.caption.copyWith(color: c.foregroundMuted),
              children: <TextSpan>[
                const TextSpan(text: 'Firm capital '),
                TextSpan(
                  text: _formatCompact(supervisedCapitalInr),
                  style: context.uiText.caption.copyWith(
                    color: c.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          RichText(
            text: TextSpan(
              style: context.uiText.caption.copyWith(color: c.foregroundMuted),
              children: <TextSpan>[
                TextSpan(text: 'Deployed across $seatCount seats '),
                TextSpan(
                  text: _formatCompact(allocatedCapitalInr),
                  style: context.uiText.caption.copyWith(
                    color: c.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          RichText(
            text: TextSpan(
              style: context.uiText.caption.copyWith(color: c.foregroundMuted),
              children: <TextSpan>[
                const TextSpan(text: 'Max firm drawdown '),
                TextSpan(
                  text: '${maxDrawdownPct.toStringAsFixed(2)}%',
                  style: context.uiText.caption.copyWith(
                    color: c.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// One metric KPI entry in a [DeskLedgerBlock].
class DeskLedgerItem {
  const DeskLedgerItem({
    required this.label,
    required this.value,
    this.subtext,
    this.actionLabel,
    this.valueColor,
    this.onTap,
    this.badgeText,
    this.badgeIntent,
  });

  final String label;
  final String value;
  final String? subtext;
  final String? actionLabel;
  final Color? valueColor;
  final VoidCallback? onTap;
  final String? badgeText;
  final UiIntent? badgeIntent;
}

/// 4-column responsive ledger with thin border dividers.
class DeskLedgerBlock extends StatelessWidget {
  const DeskLedgerBlock({super.key, required this.items});

  final List<DeskLedgerItem> items;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;

    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final int columns = width >= 900 ? 4 : (width >= 560 ? 2 : 1);

        final List<List<DeskLedgerItem>> rows = <List<DeskLedgerItem>>[];
        for (int i = 0; i < items.length; i += columns) {
          final int end = (i + columns <= items.length)
              ? i + columns
              : items.length;
          rows.add(items.sublist(i, end));
        }

        return Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: c.border,
                width: theme.borders.hairline,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int r = 0; r < rows.length; r++) ...<Widget>[
                if (r > 0)
                  Divider(
                    height: 1,
                    thickness: theme.borders.hairline,
                    color: c.border,
                  ),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (
                        int col = 0;
                        col < rows[r].length;
                        col++
                      ) ...<Widget>[
                        if (col > 0)
                          VerticalDivider(
                            width: 1,
                            thickness: theme.borders.hairline,
                            color: c.border,
                          ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: ctx.sp(theme.spacing.md),
                              horizontal: ctx.sp(theme.spacing.sm),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        rows[r][col].label,
                                        style: ctx.uiText.caption.copyWith(
                                          color: c.foregroundMuted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    if (rows[r][col].badgeText != null)
                                      UiBadge(
                                        label: rows[r][col].badgeText!,
                                        intent:
                                            rows[r][col].badgeIntent ??
                                            UiIntent.neutral,
                                        size: UiSize.xs,
                                      ),
                                  ],
                                ),
                                SizedBox(height: ctx.sp(theme.spacing.xxs)),
                                Text(
                                  rows[r][col].value,
                                  style: ctx.uiText.heading.copyWith(
                                    color:
                                        rows[r][col].valueColor ?? c.foreground,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 28,
                                    fontFeatures: const <FontFeature>[
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                SizedBox(height: ctx.sp(theme.spacing.xxs)),
                                if (rows[r][col].actionLabel != null &&
                                    rows[r][col].onTap != null)
                                  InkWell(
                                    onTap: rows[r][col].onTap,
                                    borderRadius: ctx.radius(theme.radii.sm),
                                    child: Text(
                                      rows[r][col].actionLabel!,
                                      style: ctx.uiText.caption.copyWith(
                                        color: c.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  )
                                else if (rows[r][col].subtext != null)
                                  Text(
                                    rows[r][col].subtext!,
                                    style: ctx.uiText.caption.copyWith(
                                      color: c.foregroundMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A responsive right-side slide-over drawer overlay container for subpages.
class DeskOverlaySheet extends StatelessWidget {
  const DeskOverlaySheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.actions = const <Widget>[],
    this.onClose,
    this.width = 460,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final VoidCallback? onClose;
  final double width;

  /// Presents the overlay subpage sliding in smoothly from the right side.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required Widget child,
    List<Widget> actions = const <Widget>[],
    double width = 460,
  }) {
    final theme = context.ui;
    final bool mobile = context.uiRes.isMobile;
    return UiDialog.present<T>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) => AnimatedPadding(
        duration: theme.motion.fast,
        padding: MediaQuery.viewInsetsOf(ctx),
        child: Align(
          alignment: mobile ? Alignment.bottomCenter : Alignment.centerRight,
          child: SizedBox(
            width: mobile ? double.infinity : ctx.sz(width),
            height: mobile
                ? MediaQuery.sizeOf(ctx).height * 0.94
                : double.infinity,
            child: Material(
              type: MaterialType.transparency,
              child: UiCard(
                variant: UiCardVariant.elevated,
                padding: EdgeInsets.zero,
                borderRadius: mobile
                    ? BorderRadius.vertical(
                        top: Radius.circular(ctx.sz(theme.radii.xl)),
                      )
                    : BorderRadius.horizontal(
                        left: Radius.circular(ctx.sz(theme.radii.lg)),
                      ),
                child: UiDialog(
                  title: title,
                  description: subtitle,
                  actions: actions,
                  child: SingleChildScrollView(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return UiDialog(
      title: title,
      description: subtitle,
      actions: actions,
      child: child,
    );
  }
}
