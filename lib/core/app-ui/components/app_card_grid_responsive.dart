import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../theme/app_tokens.dart';

/// A responsive card grid that adapts columns based on screen size.
///
/// Mobile: 1 column
/// Tablet: 2 columns  
/// Desktop: 3-4 columns based on available width
///
/// Supports pagination, empty states, and custom layouts.
class AppCardGridResponsive extends StatelessWidget {
  const AppCardGridResponsive({
    super.key,
    required this.children,
    this.emptyState,
    this.loading = false,
    this.columns,
    this.minColumnWidth = 280,
    this.padding,
  });

  /// Cards to display in the grid
  final List<Widget> children;

  /// Widget to show when list is empty (optional)
  final Widget? emptyState;

  /// Show skeleton loaders instead of cards
  final bool loading;

  /// Force specific column count (auto-calculated if null)
  final int? columns;

  /// Minimum width per column before wrapping
  final double minColumnWidth;

  /// Padding around the grid
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;
    final bool isTablet = context.uiRes.isTablet;

    // Empty state
    if (!loading && children.isEmpty && emptyState != null) {
      return Padding(
        padding: padding ?? EdgeInsets.all(context.sp(theme.spacing.lg)),
        child: emptyState!,
      );
    }

    // Loading state
    if (loading) {
      return _buildSkeletonGrid(context, isMobile, isTablet);
    }

    // Calculate columns
    final int columnCount = columns ?? _calculateColumns(context, isMobile, isTablet);

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double availableWidth = constraints.maxWidth;
          final int effectiveColumns = availableWidth > 1200
              ? (availableWidth / minColumnWidth).floor().clamp(3, 6)
              : columnCount;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: effectiveColumns,
              mainAxisSpacing: context.sp(theme.spacing.md),
              crossAxisSpacing: context.sp(theme.spacing.md),
              childAspectRatio: _calculateAspectRatio(isMobile),
            ),
            itemCount: children.length,
            itemBuilder: (BuildContext context, int index) {
              return children[index];
            },
          );
        },
      ),
    );
  }

  int _calculateColumns(BuildContext context, bool isMobile, bool isTablet) {
    if (isMobile) return 1;
    if (isTablet) return 2;
    return 3;
  }

  double _calculateAspectRatio(bool isMobile) {
    // Card aspect ratio: wider on desktop, taller on mobile
    return isMobile ? 1.4 : 1.6;
  }

  Widget _buildSkeletonGrid(BuildContext context, bool isMobile, bool isTablet) {
    final UiTheme theme = context.ui;
    final int columnCount = _calculateColumns(context, isMobile, isTablet);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnCount,
        mainAxisSpacing: context.sp(theme.spacing.md),
        crossAxisSpacing: context.sp(theme.spacing.md),
        childAspectRatio: _calculateAspectRatio(isMobile),
      ),
      itemCount: 6, // Show 6 skeleton cards
      itemBuilder: (BuildContext context, int index) {
        return UiCard(
          loading: true,
          loadingHeight: context.sz(120),
          child: const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Empty state with guidance for when there are no items.
class AppEmptyStateGuide extends StatelessWidget {
  const AppEmptyStateGuide({
    super.key,
    required this.title,
    required this.description,
    this.icon,
    this.primaryAction,
    this.secondaryAction,
    this.showIllustration = true,
  });

  /// Main title (e.g., "No playbooks yet")
  final String title;

  /// Description explaining what to do (e.g., "Create your first playbook to get started")
  final String description;

  /// Optional icon (defaults to inbox)
  final IconData? icon;

  /// Primary action button (e.g., "+ New Playbook")
  final Widget? primaryAction;

  /// Secondary action (e.g., "View templates")
  final Widget? secondaryAction;

  /// Show illustration graphic
  final bool showIllustration;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(isMobile ? theme.spacing.lg : theme.spacing.xl),
            vertical: context.sp(theme.spacing.xl),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (showIllustration) ...<Widget>[
                Container(
                  width: context.sz(isMobile ? 120 : 160),
                  height: context.sz(isMobile ? 120 : 160),
                  decoration: BoxDecoration(
                    color: context.uiColors.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon ?? Icons.inbox_outlined,
                    size: context.sz(isMobile ? 56 : 72),
                    color: context.uiColors.foregroundMuted,
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.lg)),
              ],
              Text(
                title,
                style: isMobile ? context.uiText.title : context.uiText.display,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.sp(theme.spacing.sm)),
              Text(
                description,
                style: context.uiText.body.copyWith(
                  color: context.uiColors.foregroundMuted,
                ),
                textAlign: TextAlign.center,
              ),
              if (primaryAction != null || secondaryAction != null) ...<Widget>[
                SizedBox(height: context.sp(theme.spacing.lg)),
                Wrap(
                  spacing: context.sp(theme.spacing.sm),
                  runSpacing: context.sp(theme.spacing.sm),
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    if (primaryAction != null) primaryAction!,
                    if (secondaryAction != null) secondaryAction!,
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
