import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';

/// Cards for the calculators feature.
///
/// The hub is an index, not a storefront, so there is no promotional tile here —
/// only the compact row the tool list is built from, the placeholder for an id
/// with no screen behind it, and the loading state of the workbench.

// ── Tool index row ───────────────────────────────────────────────────────────

/// One line of the tool index.
///
/// Two dozen tools have to fit a rail without scrolling past the fold, so the
/// row carries a category-tinted glyph, the name, and nothing else. Selection
/// shows as a fill plus a hairline edge stripe rather than a filled pill, which
/// at this density would turn the rail into a stack of buttons.
class AppCalculatorNavItem extends StatelessWidget {
  const AppCalculatorNavItem({
    super.key,
    required this.meta,
    required this.selected,
    required this.onTap,
    this.showDescription = false,
  });

  final AppCalculatorMeta meta;
  final bool selected;
  final VoidCallback onTap;

  /// Adds the one-line summary under the name — used in the mobile sheet, where
  /// there is room and no hover to reveal it.
  final bool showDescription;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final Color tint = meta.category.intent.color(context);

    if (showDescription || context.uiRes.isMobile) {
      return UiCard(
        onTap: onTap,
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.md),
          vertical: context.sp(theme.spacing.sm + 2),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(context.sp(theme.spacing.xs + 2)),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: context.radius(theme.radii.md),
              ),
              child: Icon(
                meta.icon,
                size: context.sz(theme.sizes.iconSm),
                color: tint,
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.md)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    meta.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.bodyStrong.copyWith(
                      color: c.foreground,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Text(
                    meta.description,
                    style: context.uiText.caption.copyWith(
                      color: c.foregroundMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.sm)),
            Icon(
              Icons.chevron_right_rounded,
              size: context.sz(theme.sizes.iconSm),
              color: c.foregroundSubtle,
            ),
          ],
        ),
      );
    }

    return Material(
      color: selected ? c.surfaceHover : c.surface,
      child: InkWell(
        onTap: onTap,
        hoverColor: c.surfaceHover,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? tint : Colors.transparent,
                width: context.sz(2),
              ),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.sm),
            vertical: context.sp(theme.spacing.xs),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                meta.icon,
                size: context.sz(theme.sizes.iconXs),
                color: selected ? tint : c.foregroundSubtle,
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      meta.name,
                      style: context.uiText.caption.copyWith(
                        color: selected ? c.foreground : c.foregroundMuted,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showDescription)
                      Text(
                        meta.description,
                        style: uiOverline(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.chevron_right,
                  size: context.sz(theme.sizes.iconXs),
                  color: tint,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── States ───────────────────────────────────────────────────────────────────

/// Shown when a tool id has no screen behind it. Named so the hub never has to
/// invent an error surface inline.
class AppCalculatorMissingTool extends StatelessWidget {
  const AppCalculatorMissingTool({super.key, this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Padding(
      padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
      child: UiEmptyState(
        title: 'Tool unavailable',
        message: name == null
            ? 'This calculator is not wired up yet.'
            : '$name is not wired up yet.',
        icon: Icons.construction_outlined,
      ),
    );
  }
}

/// Loading state of the workbench: rail rows on the left, a readout band and two
/// panels on the right, so the layout does not jump when data lands.
class AppCalculatorWorkspaceSkeleton extends StatelessWidget {
  const AppCalculatorWorkspaceSkeleton({super.key, this.rows = 8});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final double gap = context.sp(theme.spacing.md);
    final bool mobile = context.uiRes.isMobile;

    final Widget rail = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        UiSkeleton(height: context.sz(theme.sizes.controlHeightSm)),
        SizedBox(height: gap),
        for (int i = 0; i < rows; i++) ...<Widget>[
          if (i > 0) SizedBox(height: context.sp(theme.spacing.sm)),
          UiSkeleton(height: context.sz(18), width: i.isEven ? null : 140),
        ],
      ],
    );

    final Widget analysis = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        UiSkeleton(height: context.sz(74)),
        SizedBox(height: gap),
        UiSkeleton(height: context.sz(168)),
        SizedBox(height: gap),
        UiSkeleton(height: context.sz(168)),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: context.radius(theme.radii.lg),
        border: Border.all(color: c.border, width: theme.borders.hairline),
      ),
      child: Padding(
        padding: EdgeInsets.all(gap),
        child: mobile
            ? analysis
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(width: context.sz(288), child: rail),
                  SizedBox(width: gap),
                  Expanded(child: analysis),
                ],
              ),
      ),
    );
  }
}

