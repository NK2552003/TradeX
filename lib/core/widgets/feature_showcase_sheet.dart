import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/navigation/share_links.dart';
import 'package:tradex/core/utils/share_actions.dart';
import 'package:tradex/core/widgets/feature_showcase_catalog.dart';
import 'package:tradex/core/widgets/feature_showcase_preview.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_side_sheet.dart';

/// Opens the responsive right-side Feature Showcase & Walkthrough overlay.
Future<void> showFeatureShowcaseOverlay(
  BuildContext context, {
  String? currentDestination,
  UserRole activeRole = UserRole.customer,
  bool hasAffiliateAccess = false,
  bool hasAdminAccess = false,
  required void Function(FeatureShowcaseItem item) onOpenFeature,
  void Function(FeatureShowcaseItem item)? onStartPageTour,
}) {
  return showSettingsSideSheet<void>(
    context,
    title: 'Feature Explorer & Live Previews',
    subtitle: 'Interactive guide to every workspace, market, community & AI tool',
    desktopWidthRatio: 0.74,
    maxWidth: 1180,
    minDesktopWidth: 680,
    scrollable: false,
    child: FeatureShowcaseSheet(
      currentDestination: currentDestination,
      activeRole: activeRole,
      hasAffiliateAccess: hasAffiliateAccess,
      hasAdminAccess: hasAdminAccess,
      onOpenFeature: onOpenFeature,
      onStartPageTour: onStartPageTour,
    ),
  );
}

class FeatureShowcaseSheet extends StatefulWidget {
  const FeatureShowcaseSheet({
    super.key,
    this.currentDestination,
    this.activeRole = UserRole.customer,
    this.hasAffiliateAccess = false,
    this.hasAdminAccess = false,
    required this.onOpenFeature,
    this.onStartPageTour,
  });

  final String? currentDestination;
  final UserRole activeRole;
  final bool hasAffiliateAccess;
  final bool hasAdminAccess;
  final void Function(FeatureShowcaseItem item) onOpenFeature;
  final void Function(FeatureShowcaseItem item)? onStartPageTour;

  @override
  State<FeatureShowcaseSheet> createState() => _FeatureShowcaseSheetState();
}

class _FeatureShowcaseSheetState extends State<FeatureShowcaseSheet> {
  late final List<FeatureShowcaseItem> _allItems = buildFeatureShowcaseCatalog(
    hasAffiliateAccess: widget.hasAffiliateAccess,
    hasAdminAccess: widget.hasAdminAccess,
  );
  FeatureShowcaseCategory _category = FeatureShowcaseCategory.all;
  String _query = '';
  late String _selectedId = _resolveInitialSelection();
  final Map<String, Set<int>> _completedSteps = <String, Set<int>>{};

  String _resolveInitialSelection() {
    final dest = widget.currentDestination;
    if (dest != null && dest.trim().isNotEmpty) {
      for (final item in _allItems) {
        if (item.matchesDestination(dest)) return item.id;
      }
    }
    return _allItems.first.id;
  }

  List<FeatureShowcaseItem> get _filteredItems {
    return _allItems.where((item) {
      if (_category != FeatureShowcaseCategory.all &&
          item.category != _category) {
        return false;
      }
      return item.matchesQuery(_query);
    }).toList();
  }

  FeatureShowcaseItem? get _selectedItem {
    final filtered = _filteredItems;
    if (filtered.isEmpty) return null;
    for (final item in filtered) {
      if (item.id == _selectedId) return item;
    }
    return filtered.first;
  }

  void _toggleStep(String itemId, int stepIndex, bool value) {
    setState(() {
      final set = _completedSteps.putIfAbsent(itemId, () => <int>{});
      if (value) {
        set.add(stepIndex);
      } else {
        set.remove(stepIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final colors = theme.colors;
    final filtered = _filteredItems;
    final selected = _selectedItem;

    return Padding(
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Search & category filters
          UiInput.search(
            key: const ValueKey<String>('feature-showcase-search'),
            value: _query,
            hintText: 'Search features, subdomains, calculators, skills...',
            size: UiSize.sm,
            onChanged: (v) => setState(() => _query = v),
            onClear: () => setState(() => _query = ''),
          ),
          UiGap.v(theme.spacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final cat in FeatureShowcaseCategory.values) ...[
                  UiButton(
                    key: ValueKey<String>('feature-cat-${cat.name}'),
                    label: cat.label,
                    icon: cat.icon,
                    size: UiSize.xs,
                    variant:
                        _category == cat ? UiVariant.solid : UiVariant.outline,
                    intent:
                        _category == cat ? UiIntent.primary : UiIntent.neutral,
                    onPressed: () => setState(() => _category = cat),
                  ),
                  UiGap.h(theme.spacing.xs),
                ],
              ],
            ),
          ),
          UiGap.v(theme.spacing.sm),
          const UiDivider(),
          UiGap.v(theme.spacing.sm),

          Expanded(
            child: filtered.isEmpty || selected == null
                ? UiEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matching features',
                    message:
                        'Try clearing your search filter or switching to the All tab.',
                    actionLabel: 'Show All Features',
                    onActionPressed: () => setState(() {
                      _query = '';
                      _category = FeatureShowcaseCategory.all;
                    }),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final bool splitView = constraints.maxWidth >= 640;
                      if (splitView) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            SizedBox(
                              width: context.sz(214),
                              child: _buildFeatureSidebarList(
                                context,
                                filtered,
                                selected,
                                colors,
                              ),
                            ),
                            UiGap.h(theme.spacing.md),
                            Expanded(
                              child: _buildFeatureDetailPane(context, selected),
                            ),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildCompactFeatureSelector(
                            context,
                            filtered,
                            selected,
                          ),
                          UiGap.v(theme.spacing.sm),
                          Expanded(
                            child: _buildFeatureDetailPane(context, selected),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureSidebarList(
    BuildContext context,
    List<FeatureShowcaseItem> items,
    FeatureShowcaseItem selected,
    dynamic colors,
  ) {
    final theme = context.ui;
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => UiGap.v(theme.spacing.xs),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = item.id == selected.id;
        return UiCard(
          key: ValueKey<String>('feature-nav-${item.id}'),
          variant: isSelected ? UiCardVariant.surface : UiCardVariant.outlined,
          accentColor: isSelected ? theme.colors.primary : null,
          density: UiDensity.compact,
          onTap: () => setState(() => _selectedId = item.id),
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.sm),
            vertical: context.sp(theme.spacing.xs),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                item.icon,
                size: context.sz(17),
                color: isSelected
                    ? theme.colors.primary
                    : theme.colors.foregroundMuted,
              ),
              UiGap.h(theme.spacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.bodyStrong.copyWith(
                        fontSize: context.fs(12.5),
                        color: isSelected
                            ? theme.colors.foreground
                            : theme.colors.foregroundMuted,
                      ),
                    ),
                    Text(
                      item.subdomain.host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption.copyWith(
                        fontSize: context.fs(10.5),
                        color: theme.colors.foregroundSubtle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactFeatureSelector(
    BuildContext context,
    List<FeatureShowcaseItem> items,
    FeatureShowcaseItem selected,
  ) {
    final theme = context.ui;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final item in items) ...[
            UiButton(
              key: ValueKey<String>('feature-pill-${item.id}'),
              label: item.title,
              icon: item.icon,
              size: UiSize.xs,
              variant: item.id == selected.id
                  ? UiVariant.solid
                  : UiVariant.outline,
              intent: item.id == selected.id
                  ? UiIntent.primary
                  : UiIntent.neutral,
              onPressed: () => setState(() => _selectedId = item.id),
            ),
            UiGap.h(theme.spacing.xs),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureDetailPane(
    BuildContext context,
    FeatureShowcaseItem item,
  ) {
    final theme = context.ui;
    final colors = theme.colors;
    final bool canOpen = !item.requiresAdminAccess || widget.hasAdminAccess;
    final String shareUrl = item.canonicalUrl(activeRole: widget.activeRole);
    final String compactPath = AppShareLinks.displayHostAndPath(shareUrl);
    final Set<int> checked = _completedSteps[item.id] ?? const <int>{};
    final double progress = item.demoSteps.isEmpty
        ? 1.0
        : checked.length / item.demoSteps.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Top feature identity & canonical subdomain strip
                UiCard(
                  variant: UiCardVariant.outlined,
                  padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: context.sz(38),
                            height: context.sz(38),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.12),
                              borderRadius: context.radius(theme.radii.md),
                            ),
                            child: Icon(
                              item.icon,
                              size: context.sz(20),
                              color: colors.primary,
                            ),
                          ),
                          UiGap.h(theme.spacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  item.title,
                                  style: context.uiText.heading.copyWith(
                                    fontSize: context.fs(17),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  item.tagline,
                                  style: context.uiText.caption.copyWith(
                                    color: colors.foregroundMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          UiIconButton(
                            key: ValueKey<String>('feature-share-${item.id}'),
                            icon: Icons.ios_share_rounded,
                            size: UiSize.xs,
                            tooltip: 'Share ${item.title} link',
                            onPressed: () {
                              ShareActions.showLinkShareSheet(
                                context,
                                title: item.title,
                                subtitle: item.tagline,
                                url: shareUrl,
                                copyToastTitle: 'Feature link copied',
                              );
                            },
                          ),
                        ],
                      ),
                      UiGap.v(theme.spacing.sm),
                      Wrap(
                        spacing: context.sp(theme.spacing.xs),
                        runSpacing: context.sp(theme.spacing.xs),
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          UiBadge(
                            label: item.subdomain.host,
                            icon: Icons.language_rounded,
                            intent: UiIntent.primary,
                            variant: UiBadgeVariant.soft,
                            size: UiSize.xs,
                          ),
                          UiBadge(
                            label: item.tierBadge,
                            intent: item.requiresAdminAccess &&
                                    !widget.hasAdminAccess
                                ? UiIntent.warning
                                : UiIntent.neutral,
                            variant: UiBadgeVariant.outline,
                            size: UiSize.xs,
                          ),
                          UiBadge(
                            label: compactPath,
                            icon: Icons.link_rounded,
                            intent: UiIntent.neutral,
                            variant: UiBadgeVariant.soft,
                            size: UiSize.xs,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                UiGap.v(theme.spacing.md),

                // Two-column editorial explanation + usage/telemetry preview
                LayoutBuilder(
                  builder: (context, detailConstraints) {
                    final bool wideTwoColumn =
                        detailConstraints.maxWidth >= 540;
                    final leftColumn = _buildEditorialHelpersColumn(
                      context,
                      item: item,
                      shareUrl: shareUrl,
                      canOpen: canOpen,
                    );
                    final rightColumn = _buildSpecsAndPreviewColumn(
                      context,
                      item: item,
                    );
                    if (wideTwoColumn) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(flex: 5, child: leftColumn),
                          UiGap.h(theme.spacing.lg),
                          Expanded(flex: 6, child: rightColumn),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        leftColumn,
                        UiGap.v(theme.spacing.md),
                        rightColumn,
                      ],
                    );
                  },
                ),
                UiGap.v(theme.spacing.md),

                // Highlights
                UiCard(
                  variant: UiCardVariant.outlined,
                  padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'KEY CAPABILITIES',
                        style: context.uiText.label.copyWith(
                          color: colors.foregroundMuted,
                          fontSize: context.fs(10.5),
                          letterSpacing: 0.7,
                        ),
                      ),
                      UiGap.v(theme.spacing.xs),
                      for (final h in item.highlights) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: context.sp(theme.spacing.xxs),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: context.sz(16),
                                color: colors.success,
                              ),
                              UiGap.h(theme.spacing.xs),
                              Expanded(
                                child: Text(
                                  h,
                                  style: context.uiText.body.copyWith(
                                    fontSize: context.fs(13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                UiGap.v(theme.spacing.md),

                // Product Review & Notes
                UiCallout(
                  title: 'Review & Setup Notes',
                  message: item.reviewNote,
                  intent: item.requiresAdminAccess && !widget.hasAdminAccess
                      ? UiIntent.warning
                      : UiIntent.info,
                ),
                UiGap.v(theme.spacing.md),

                // Step-by-step interactive demo checklist
                UiCard(
                  variant: UiCardVariant.outlined,
                  padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      UiProgressBar(
                        value: progress,
                        label: 'How to create & use · Quick Walkthrough',
                        intent: progress >= 1.0
                            ? UiIntent.success
                            : UiIntent.primary,
                      ),
                      UiGap.v(theme.spacing.sm),
                      for (int i = 0; i < item.demoSteps.length; i++) ...[
                        UiCheckbox(
                          asCard: true,
                          size: UiSize.sm,
                          value: checked.contains(i),
                          label: '${i + 1}. ${item.demoSteps[i].title}',
                          description: item.demoSteps[i].detail,
                          onChanged: (v) => _toggleStep(item.id, i, v),
                        ),
                        if (i < item.demoSteps.length - 1)
                          UiGap.v(theme.spacing.xs),
                      ],
                    ],
                  ),
                ),
                UiGap.v(theme.spacing.md),
              ],
            ),
          ),
        ),
        const UiDivider(),
        UiGap.v(theme.spacing.sm),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: context.sp(theme.spacing.sm),
          runSpacing: context.sp(theme.spacing.xs),
          children: <Widget>[
            if (item.supportsPageTour && widget.onStartPageTour != null)
              UiButton(
                key: ValueKey<String>('feature-tour-${item.id}'),
                label: 'Interactive Page Tour',
                icon: Icons.assistant_direction_outlined,
                variant: UiVariant.outline,
                size: UiSize.sm,
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onStartPageTour!(item);
                },
              ),
            UiButton(
              key: ValueKey<String>('feature-open-${item.id}'),
              label: canOpen ? 'Open ${item.title}' : 'Admin Role Required',
              icon: canOpen
                  ? Icons.open_in_new_rounded
                  : Icons.lock_outline_rounded,
              variant: UiVariant.solid,
              intent: canOpen ? UiIntent.primary : UiIntent.neutral,
              size: UiSize.sm,
              disabled: !canOpen,
              onPressed: canOpen
                  ? () {
                      Navigator.of(context).pop();
                      widget.onOpenFeature(item);
                    }
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditorialHelpersColumn(
    BuildContext context, {
    required FeatureShowcaseItem item,
    required String shareUrl,
    required bool canOpen,
  }) {
    final theme = context.ui;
    final colors = theme.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.summary,
          style: context.uiText.bodyStrong.copyWith(
            color: colors.foreground,
            fontSize: context.fs(13.5),
            height: 1.45,
          ),
        ),
        UiGap.v(theme.spacing.sm),
        for (int i = 0; i < item.detailedParagraphs.length; i++) ...[
          Text(
            item.detailedParagraphs[i],
            style: context.uiText.body.copyWith(
              color: colors.foregroundMuted,
              fontSize: context.fs(12.5),
              height: 1.55,
            ),
          ),
          if (i < item.detailedParagraphs.length - 1)
            UiGap.v(theme.spacing.sm),
        ],
        if (item.helperTips.isNotEmpty) ...[
          UiGap.v(theme.spacing.md),
          UiCard(
            variant: UiCardVariant.surface,
            density: UiDensity.compact,
            padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: context.sz(14),
                      color: colors.warning,
                    ),
                    UiGap.h(theme.spacing.xxs),
                    Text(
                      'QUICK TIPS & HELPERS',
                      style: context.uiText.label.copyWith(
                        fontSize: context.fs(10),
                        letterSpacing: 0.7,
                        color: colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
                UiGap.v(theme.spacing.xs),
                for (int i = 0; i < item.helperTips.length; i++) ...[
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i < item.helperTips.length - 1
                          ? context.sp(theme.spacing.xxs)
                          : 0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '•',
                          style: context.uiText.caption.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        UiGap.h(theme.spacing.xs),
                        Expanded(
                          child: Text(
                            item.helperTips[i],
                            style: context.uiText.caption.copyWith(
                              color: colors.foreground,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        UiGap.v(theme.spacing.md),
        Text(
          'MORE INFORMATION & HELPERS',
          style: context.uiText.label.copyWith(
            fontSize: context.fs(10),
            letterSpacing: 0.8,
            color: colors.foregroundSubtle,
          ),
        ),
        UiGap.v(theme.spacing.xxs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (canOpen)
              UiButton(
                label: 'Open ${item.title}',
                trailingIcon: Icons.open_in_new_rounded,
                variant: UiVariant.link,
                size: UiSize.xs,
                alignment: Alignment.centerLeft,
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onOpenFeature(item);
                },
              ),
            if (item.supportsPageTour && widget.onStartPageTour != null)
              UiButton(
                label: 'Launch Interactive Page Tour',
                trailingIcon: Icons.assistant_direction_outlined,
                variant: UiVariant.link,
                size: UiSize.xs,
                alignment: Alignment.centerLeft,
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onStartPageTour!(item);
                },
              ),
            UiButton(
              key: ValueKey<String>('feature-copy-${item.id}'),
              label: 'Copy Subdomain URL',
              trailingIcon: Icons.content_copy_rounded,
              variant: UiVariant.link,
              size: UiSize.xs,
              alignment: Alignment.centerLeft,
              onPressed: () {
                ShareActions.copy(
                  context,
                  shareUrl,
                  title: 'Feature link copied',
                );
              },
            ),
            UiButton(
              label: 'Share via WhatsApp, Telegram & More',
              trailingIcon: Icons.ios_share_rounded,
              variant: UiVariant.link,
              size: UiSize.xs,
              alignment: Alignment.centerLeft,
              onPressed: () {
                ShareActions.showLinkShareSheet(
                  context,
                  title: item.title,
                  subtitle: item.tagline,
                  url: shareUrl,
                  copyToastTitle: 'Feature link copied',
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpecsAndPreviewColumn(
    BuildContext context, {
    required FeatureShowcaseItem item,
  }) {
    final theme = context.ui;
    final colors = theme.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiCard(
          variant: UiCardVariant.surface,
          density: UiDensity.compact,
          padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'QUOTAS & SPECIFICATIONS',
                style: context.uiText.label.copyWith(
                  fontSize: context.fs(10),
                  letterSpacing: 0.75,
                  color: colors.foregroundMuted,
                ),
              ),
              UiGap.v(theme.spacing.xs),
              const UiDivider(),
              for (int i = 0; i < item.specs.length; i++) ...[
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: context.sp(theme.spacing.xs),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        flex: 3,
                        child: Text(
                          item.specs[i].label,
                          style: context.uiText.caption.copyWith(
                            color: colors.foregroundMuted,
                          ),
                        ),
                      ),
                      UiGap.h(theme.spacing.sm),
                      Flexible(
                        flex: 4,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            item.specs[i].value,
                            textAlign: TextAlign.right,
                            style: context.uiText.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.foreground,
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < item.specs.length - 1) const UiDivider(),
              ],
            ],
          ),
        ),
        UiGap.v(theme.spacing.md),
        FeatureShowcasePreviewPanel(item: item),
      ],
    );
  }
}
