import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../theme/app_tokens.dart';

/// Compact stat strip showing 2-6 metrics in a responsive grid.
///
/// 20% smaller than standard stat strips for denser layouts.
/// Mobile: 2 columns, Desktop: 4-6 columns based on available space.
class AppStatStripCompact extends StatelessWidget {
  const AppStatStripCompact({
    super.key,
    required this.stats,
    this.loading = false,
    this.columns,
  });

  /// List of stats to display (2-6 items recommended)
  final List<AppCompactStat> stats;

  /// Show skeleton loaders instead of values
  final bool loading;

  /// Force specific column count (auto-calculated if null)
  final int? columns;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;
    final int columnCount = columns ?? (isMobile ? 2 : (stats.length <= 4 ? stats.length : 4));

    if (loading) {
      return _buildSkeleton(context, columnCount);
    }

    return Container(
      decoration: BoxDecoration(
        color: context.uiColors.surfaceMuted,
        borderRadius: context.radius(theme.radii.lg),
        border: Border.all(color: context.uiColors.border),
      ),
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double availableWidth = constraints.maxWidth;
          final int effectiveColumns = availableWidth > 800 
              ? stats.length.clamp(1, 6) 
              : columnCount;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: effectiveColumns,
              mainAxisSpacing: context.sp(theme.spacing.md),
              crossAxisSpacing: context.sp(theme.spacing.md),
              childAspectRatio: 2.2,
            ),
            itemCount: stats.length,
            itemBuilder: (BuildContext context, int index) {
              return _StatCell(stat: stats[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context, int columnCount) {
    final UiTheme theme = context.ui;

    return Container(
      decoration: BoxDecoration(
        color: context.uiColors.surfaceMuted,
        borderRadius: context.radius(theme.radii.lg),
        border: Border.all(color: context.uiColors.border),
      ),
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnCount,
          mainAxisSpacing: context.sp(theme.spacing.md),
          crossAxisSpacing: context.sp(theme.spacing.md),
          childAspectRatio: 2.2,
        ),
        itemCount: columnCount,
        itemBuilder: (BuildContext context, int index) {
          return UiSkeleton(
            borderRadius: context.radius(theme.radii.md),
          );
        },
      ),
    );
  }
}

/// A single compact stat metric.
class AppCompactStat {
  const AppCompactStat({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
    this.intent = UiIntent.neutral,
  });

  /// Icon for the stat
  final IconData icon;

  /// Label below the value (e.g., "Total")
  final String label;

  /// The stat value (e.g., "24")
  final String value;

  /// Optional hint text (e.g., "2 live")
  final String? hint;

  /// Semantic intent for coloring
  final UiIntent intent;
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.stat});

  final AppCompactStat stat;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color intentColor = stat.intent.color(context);

    return Container(
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      decoration: BoxDecoration(
        color: context.uiColors.background,
        borderRadius: context.radius(theme.radii.md),
        border: Border.all(color: context.uiColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                stat.icon,
                size: context.sz(16),
                color: intentColor,
              ),
              SizedBox(width: context.sp(theme.spacing.xxs)),
              Expanded(
                child: Text(
                  stat.label,
                  style: context.uiText.caption.copyWith(
                    color: context.uiColors.foregroundMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            stat.value,
            style: context.uiText.titleStrong.copyWith(
              color: intentColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (stat.hint != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xxxs)),
            Text(
              stat.hint!,
              style: context.uiText.caption.copyWith(
                color: context.uiColors.foregroundSubtle,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
