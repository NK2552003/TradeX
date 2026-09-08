import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';
import 'ui_data_panel.dart';
import 'ui_spark_chart.dart';

/// One cell of a [UiStatStrip].
@immutable
class UiStat {
  const UiStat({
    required this.label,
    required this.value,
    this.hint,
    this.intent = UiIntent.neutral,
    this.spark,
    this.icon,
    this.colSpan,
  });

  final String label;
  final String value;

  /// Small qualifier under the value ("per day", "of capital", "vs 1.5R").
  final String? hint;

  /// Colours the value only. Labels and hints stay muted so a strip of eight
  /// stats does not turn into a traffic light.
  final UiIntent intent;

  /// Optional micro-trend drawn under the value. Needs 3+ points to render.
  final List<double>? spark;
  final IconData? icon;

  /// Optional column span when rendered inside a multi-column [UiStatStrip].
  ///
  /// When not specified, [UiStatStrip] automatically calculates the column span
  /// and flex ratio so that any trailing cells auto-fill the row gap cleanly.
  final int? colSpan;
}

/// A grid of readouts separated by hairlines — the metric rail of a data page.
///
/// Reflows by measuring itself: cells never fall below [minCellWidth], so the
/// same strip is an eight-across desktop rail and a two-across phone grid
/// without the caller branching on breakpoints. Values use the theme's tabular
/// numeric style so digits line up column-to-column while they animate.
class UiStatStrip extends StatelessWidget {
  const UiStatStrip({
    super.key,
    required this.stats,
    this.columns,
    this.minCellWidth = 120,
    this.density = UiDensity.compact,
    this.showSpark = true,
  });

  final List<UiStat> stats;

  /// Force a column count. Leave null to derive it from [minCellWidth].
  final int? columns;
  final double minCellWidth;
  final UiDensity density;
  final bool showSpark;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    final theme = context.ui;
    final c = theme.colors;

    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final double available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : ctx.sz(minCellWidth) * stats.length;
        final int totalSpan =
            stats.fold(0, (int acc, UiStat s) => acc + (s.colSpan ?? 1));
        final int maxSpan = totalSpan > stats.length ? totalSpan : stats.length;
        final int cols = (columns ??
                (available / ctx.sz(minCellWidth)).floor())
            .clamp(1, maxSpan);
        final List<List<_UiStatItem>> rowGroups = _computeRows(stats, cols);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int row = 0; row < rowGroups.length; row++)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (int col = 0; col < rowGroups[row].length; col++)
                      Expanded(
                        flex: rowGroups[row][col].span,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(
                              left: col == 0
                                  ? BorderSide.none
                                  : BorderSide(
                                      color: c.border,
                                      width: theme.borders.hairline,
                                    ),
                              top: row == 0
                                  ? BorderSide.none
                                  : BorderSide(
                                      color: c.border,
                                      width: theme.borders.hairline,
                                    ),
                            ),
                          ),
                          child: _cell(ctx, rowGroups[row][col].stat),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  static List<List<_UiStatItem>> _computeRows(List<UiStat> stats, int cols) {
    final bool hasExplicitSpan = stats.any((s) => s.colSpan != null);

    if (hasExplicitSpan) {
      final List<List<_UiStatItem>> rows = <List<_UiStatItem>>[];
      List<_UiStatItem> currentRow = <_UiStatItem>[];
      int currentSpan = 0;

      for (final UiStat stat in stats) {
        final int span = (stat.colSpan ?? 1).clamp(1, cols);
        if (currentSpan + span > cols && currentRow.isNotEmpty) {
          rows.add(_autoFillRowGap(currentRow, cols));
          currentRow = <_UiStatItem>[];
          currentSpan = 0;
        }
        currentRow.add(_UiStatItem(stat: stat, span: span));
        currentSpan += span;
      }
      if (currentRow.isNotEmpty) {
        rows.add(_autoFillRowGap(currentRow, cols));
      }
      return rows;
    }

    // Standard reflow: chunk into rows of at most [cols]
    final List<List<_UiStatItem>> rows = <List<_UiStatItem>>[];
    for (int i = 0; i < stats.length; i += cols) {
      final int count = (i + cols <= stats.length) ? cols : (stats.length - i);
      final List<UiStat> slice = stats.sublist(i, i + count);

      // Auto-fill the gap in proper ratio if trailing row has fewer items than cols
      final int autoSpan = (cols % count == 0) ? (cols ~/ count) : 1;

      rows.add(<_UiStatItem>[
        for (final UiStat s in slice)
          _UiStatItem(stat: s, span: autoSpan),
      ]);
    }
    return rows;
  }

  static List<_UiStatItem> _autoFillRowGap(List<_UiStatItem> row, int cols) {
    if (row.isEmpty) return row;
    final int usedSpan = row.fold(0, (int acc, _UiStatItem it) => acc + it.span);
    if (usedSpan >= cols) return row;

    if (cols % row.length == 0) {
      final int newSpan = cols ~/ row.length;
      return <_UiStatItem>[
        for (final _UiStatItem it in row)
          _UiStatItem(stat: it.stat, span: newSpan),
      ];
    }
    return row;
  }

  Widget _cell(BuildContext context, UiStat stat) {
    final theme = context.ui;
    final c = theme.colors;
    final double f = density.factor;
    final Color valueColor = stat.intent == UiIntent.neutral
        ? c.foreground
        : stat.intent.color(context);
    final bool hasSpark =
        showSpark && stat.spark != null && stat.spark!.length >= 3;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md) * f,
        vertical: context.sp(theme.spacing.md) * f,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (stat.icon != null) ...<Widget>[
                Icon(
                  stat.icon,
                  size: context.sz(theme.sizes.iconXs),
                  color: c.foregroundSubtle,
                ),
                SizedBox(width: context.sp(theme.spacing.xxs)),
              ],
              Expanded(
                child: Text(
                  stat.label.toUpperCase(),
                  style: uiOverline(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            stat.value,
            style: context.uiText.numeric.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (stat.hint != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xxs)),
            Text(
              stat.hint!,
              style: context.uiText.caption.copyWith(
                color: c.foregroundSubtle,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (hasSpark) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xs)),
            UiSparkChart(
              values: stat.spark!,
              height: context.sz(18),
              color: valueColor,
            ),
          ],
        ],
      ),
    );
  }
}

class _UiStatItem {
  const _UiStatItem({required this.stat, required this.span});
  final UiStat stat;
  final int span;
}
