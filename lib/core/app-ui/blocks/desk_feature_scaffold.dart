import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';

/// Unified scaffold components for feature landing surfaces (Journal, Notes, Strategies).
///
/// Ensures exact consistency in:
/// - Notification / Pipeline action banner
/// - 4-Card Executive KPI strip
/// - Controls bar (Dropdown triggers, filter pills, view toggle)
/// - Main grid/table lazy-loaded pagination bar
/// - Live broker sync footer status bar

// ─────────────────────────────────────────────────────────────────────────────
// 1. Notification / Action Banner
// ─────────────────────────────────────────────────────────────────────────────

class DeskNotificationAction {
  const DeskNotificationAction({
    required this.label,
    required this.icon,
    this.intent = UiIntent.primary,
    this.badge,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final UiIntent intent;
  final String? badge;
  final VoidCallback onTap;
}

class DeskNotificationBanner extends StatelessWidget {
  const DeskNotificationBanner({
    super.key,
    required this.actions,
    this.onDismiss,
    this.dismissLabel = 'Dismiss suggestions',
  });

  final List<DeskNotificationAction> actions;
  final VoidCallback? onDismiss;
  final String dismissLabel;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.sm),
        vertical: context.sp(theme.spacing.xs),
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: context.radius(theme.radii.lg),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < actions.length; i++) ...<Widget>[
                    if (i > 0) SizedBox(width: context.sp(theme.spacing.xs)),
                    InkWell(
                      borderRadius: context.radius(theme.radii.pill),
                      onTap: actions[i].onTap,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.sp(theme.spacing.sm),
                          vertical: context.sp(theme.spacing.xs),
                        ),
                        decoration: BoxDecoration(
                          color: actions[i].intent
                              .color(context)
                              .withValues(alpha: 0.1),
                          borderRadius: context.radius(theme.radii.pill),
                          border: Border.all(
                            color: actions[i].intent
                                .color(context)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              actions[i].icon,
                              size: 14,
                              color: actions[i].intent.color(context),
                            ),
                            SizedBox(width: context.sp(theme.spacing.xs)),
                            Text(
                              actions[i].label,
                              style: context.uiText.caption.copyWith(
                                color: actions[i].intent.color(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (actions[i].badge != null) ...<Widget>[
                              SizedBox(width: context.sp(theme.spacing.xs)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: actions[i].intent
                                      .color(context)
                                      .withValues(alpha: 0.2),
                                  borderRadius: context.radius(theme.radii.sm),
                                ),
                                child: Text(
                                  actions[i].badge!,
                                  style: TextStyle(
                                    color: actions[i].intent.color(context),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (onDismiss != null) ...<Widget>[
            SizedBox(width: context.sp(theme.spacing.xs)),
            if (context.uiRes.isMobile)
              UiIconButton(
                icon: Icons.close_rounded,
                size: UiSize.xs,
                variant: UiVariant.ghost,
                tooltip: dismissLabel,
                onPressed: onDismiss,
              )
            else
              UiButton(
                label: dismissLabel,
                variant: UiVariant.ghost,
                size: UiSize.xs,
                onPressed: onDismiss,
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. 4-Card Executive KPI Overview
// ─────────────────────────────────────────────────────────────────────────────

class DeskStatCardData {
  const DeskStatCardData({
    required this.title,
    this.value = '',
    this.valueColor,
    this.secondary,
    this.secondaryColor,
    this.subtitle,
    this.customMetric,
    this.customBottom,
    this.key,
  });

  final String title;
  final String value;
  final Color? valueColor;
  final String? secondary;
  final Color? secondaryColor;
  final String? subtitle;
  final Widget? customMetric;
  final Widget? customBottom;
  final Key? key;
}

class DeskStatsOverview extends StatelessWidget {
  const DeskStatsOverview({super.key, required this.stats, this.maxWidth});

  final List<DeskStatCardData> stats;
  final double? maxWidth;

  Widget _buildCard(BuildContext context, DeskStatCardData data) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return UiCard(
      key: data.key,
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            data.title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.caption.copyWith(
              color: colors.foregroundSubtle,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          if (data.customMetric != null)
            data.customMetric!
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text(
                    data.value,
                    style: context.uiText.title.copyWith(
                      color: data.valueColor ?? colors.foreground,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  if (data.secondary != null) ...<Widget>[
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Text(
                      data.secondary!,
                      style: context.uiText.caption.copyWith(
                        color: data.secondaryColor ?? colors.foregroundMuted,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          if (data.customBottom != null)
            data.customBottom!
          else if (data.subtitle != null)
            Text(
              data.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.caption.copyWith(
                color: colors.foregroundMuted,
                fontSize: 11,
              ),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();

    final UiTheme theme = context.ui;
    final double gap = context.sp(theme.spacing.sm);
    final double width = maxWidth ?? MediaQuery.sizeOf(context).width;

    if (width >= 1024) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < stats.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: gap),
            Expanded(child: _buildCard(context, stats[i])),
          ],
        ],
      );
    }

    if (width >= 640 || stats.length <= 2) {
      final List<Widget> rows = <Widget>[];
      for (int i = 0; i < stats.length; i += 2) {
        if (i > 0) rows.add(SizedBox(height: gap));
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _buildCard(context, stats[i])),
              SizedBox(width: gap),
              Expanded(
                child: (i + 1 < stats.length)
                    ? _buildCard(context, stats[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      }
      return Column(children: rows);
    }

    // Narrow mobile layout: 2x2 grid
    return Column(
      children: <Widget>[
        for (int i = 0; i < stats.length; i += 2) ...<Widget>[
          if (i > 0) SizedBox(height: gap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _buildCard(context, stats[i])),
              SizedBox(width: gap),
              Expanded(
                child: (i + 1 < stats.length)
                    ? _buildCard(context, stats[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Standardized Filter Dropdown Button Trigger
// ─────────────────────────────────────────────────────────────────────────────

class DeskFilterDropdown extends StatelessWidget {
  const DeskFilterDropdown({
    super.key,
    required this.label,
    this.icon,
    this.isActive = false,
    required this.items,
    this.isExpanded = false,
  });

  final String label;
  final IconData? icon;
  final bool isActive;
  final List<UiMenuItem> items;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    final Widget content = Container(
      height: context.sz(32),
      padding: EdgeInsets.symmetric(horizontal: context.sp(theme.spacing.sm)),
      decoration: BoxDecoration(
        color: isActive
            ? colors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: context.radius(theme.radii.md),
        border: Border.all(
          color: isActive
              ? colors.primary.withValues(alpha: 0.4)
              : colors.border.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: isExpanded
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(
              icon,
              size: 13,
              color: isActive ? colors.primary : colors.foregroundMuted,
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.caption.copyWith(
                color: isActive ? colors.foreground : colors.foregroundMuted,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.xxs)),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 14,
            color: isActive ? colors.primary : colors.foregroundMuted,
          ),
        ],
      ),
    );

    return UiDropdownMenu(items: items, child: content);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Standardized View Mode Toggle (Grid vs List / Table)
// ─────────────────────────────────────────────────────────────────────────────

class DeskViewToggle extends StatelessWidget {
  const DeskViewToggle({
    super.key,
    required this.isGrid,
    required this.onChanged,
    this.gridIcon = Icons.grid_view_rounded,
    this.gridTooltip = 'Grid view',
    this.secondaryIcon = Icons.view_list_rounded,
    this.secondaryTooltip = 'List view',
  });

  final bool isGrid;
  final ValueChanged<bool> onChanged;
  final IconData gridIcon;
  final String gridTooltip;
  final IconData secondaryIcon;
  final String secondaryTooltip;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return Container(
      height: context.sz(32),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: context.radius(theme.radii.md),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Tooltip(
            message: gridTooltip,
            child: InkWell(
              onTap: () => onChanged(true),
              borderRadius: context.radius(theme.radii.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: isGrid ? colors.surfaceMuted : Colors.transparent,
                  borderRadius: context.radius(theme.radii.sm),
                ),
                child: Icon(
                  gridIcon,
                  size: 15,
                  color: isGrid ? colors.foreground : colors.foregroundMuted,
                ),
              ),
            ),
          ),
          Tooltip(
            message: secondaryTooltip,
            child: InkWell(
              onTap: () => onChanged(false),
              borderRadius: context.radius(theme.radii.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: !isGrid ? colors.surfaceMuted : Colors.transparent,
                  borderRadius: context.radius(theme.radii.sm),
                ),
                child: Icon(
                  secondaryIcon,
                  size: 15,
                  color: !isGrid ? colors.foreground : colors.foregroundMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Standardized Section Heading with Divider
// ─────────────────────────────────────────────────────────────────────────────

class DeskSectionHeader extends StatelessWidget {
  const DeskSectionHeader({
    super.key,
    required this.title,
    this.countLabel,
    this.trailing,
    this.accentColor,
    this.showDivider = true,
  });

  final String title;
  final String? countLabel;
  final Widget? trailing;
  final Color? accentColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: context.sp(theme.spacing.xs),
          runSpacing: context.sp(theme.spacing.xs),
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              title.toUpperCase(),
              style: context.uiText.caption.copyWith(
                color: accentColor ?? colors.foregroundMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (countLabel != null)
              UiBadge(label: countLabel!, size: UiSize.xs),
            ?trailing,
          ],
        ),
        if (showDivider) const UiDivider(spacing: 4),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Standardized Lazy Pagination Bar
// ─────────────────────────────────────────────────────────────────────────────

class DeskPaginationBar extends StatelessWidget {
  const DeskPaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
    this.itemLabel = 'entries',
  });

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final String itemLabel;

  @override
  Widget build(BuildContext context) {
    if (totalItems == 0) return const SizedBox.shrink();

    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    final int start = ((currentPage - 1) * pageSize + 1).clamp(1, totalItems);
    final int end = (currentPage * pageSize).clamp(1, totalItems);

    final String infoText = 'Showing $start to $end of $totalItems $itemLabel';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
      child: Column(
        children: [
          Text(
            infoText,
            style: context.uiText.caption.copyWith(
              color: colors.foregroundMuted,
            ),
            textAlign: TextAlign.center,
          ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: context.sp(theme.spacing.sm),
            runSpacing: context.sp(theme.spacing.xs),
            children: [
              UiButton(
                label: 'Previous',
                size: UiSize.xs,
                variant: UiVariant.outline,
                onPressed: currentPage > 1
                    ? () => onPageChanged(currentPage - 1)
                    : null,
              ),
              Text(
                'Page $currentPage of $totalPages',
                style: context.uiText.caption,
              ),
              UiButton(
                label: 'Next',
                size: UiSize.xs,
                variant: UiVariant.outline,
                onPressed: currentPage < totalPages
                    ? () => onPageChanged(currentPage + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. Standardized Status Bar Footer
// ─────────────────────────────────────────────────────────────────────────────

class DeskStatusBarFooter extends StatelessWidget {
  const DeskStatusBarFooter({
    super.key,
    this.syncLabel = 'Workspace records',
    this.latency,
    this.shortcutHints = const <String>[],
  });

  final String syncLabel;
  final String? latency;
  final List<String> shortcutHints;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return Container(
      margin: EdgeInsets.only(top: context.sp(theme.spacing.md)),
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: context.sp(theme.spacing.sm),
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(
            color: colors.border.withValues(alpha: 0.6),
            width: theme.borders.hairline,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Flexible(
                  child: Text(
                    syncLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.caption.copyWith(
                      color: colors.success,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (latency != null && !context.uiRes.isMobile) ...<Widget>[
                  Text(
                    '  •  $latency',
                    style: context.uiText.caption.copyWith(
                      color: colors.foregroundSubtle,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (shortcutHints.isNotEmpty && !context.uiRes.isMobile)
            Flexible(
              child: Text(
                shortcutHints.join('  •  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: context.uiText.caption.copyWith(
                  color: colors.foregroundSubtle,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
