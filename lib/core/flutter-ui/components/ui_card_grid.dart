import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';

/// Responsive card grid: column count comes from the responsive helper.
class UiCardGrid extends StatelessWidget {
  const UiCardGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.largeColumns = 4,
    this.minTileWidth,
    this.childAspectRatio,
    this.mainAxisExtent,
    this.adaptiveSingleColumn = true,
    this.intrinsicHeight = false,
    this.equalHeight = false,
  });

  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final int largeColumns;
  final double? minTileWidth;
  final double? childAspectRatio;
  final double? mainAxisExtent;
  final bool adaptiveSingleColumn;

  /// Keep editorial cards at their natural height as content changes.
  final bool intrinsicHeight;

  /// Align variable-height card actions across each responsive row.
  final bool equalHeight;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final theme = context.ui;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        int cols;
        if (constraints.maxWidth < 360) {
          cols = 1;
        } else if (constraints.maxWidth < 640) {
          cols = mobileColumns;
        } else if (constraints.maxWidth < 960) {
          cols = tabletColumns;
        } else if (constraints.maxWidth < 1300) {
          cols = desktopColumns;
        } else {
          cols = largeColumns;
        }
        final double gap = context.sp(theme.spacing.md);
        if (minTileWidth != null && constraints.maxWidth.isFinite) {
          cols = ((constraints.maxWidth + gap) / (minTileWidth! + gap))
              .floor()
              .clamp(1, largeColumns);
        }

        cols = cols.clamp(1, children.length);
        if (equalHeight && minTileWidth != null) {
          // Balance automatic rows so four summaries form 2 x 2 instead of 3 + 1.
          final rows = (children.length / cols).ceil();
          cols = (children.length / rows).ceil();
        }
        if (cols == 1 && adaptiveSingleColumn) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0) SizedBox(height: gap),
                children[i],
              ],
            ],
          );
        }

        if (equalHeight) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int start = 0; start < children.length; start += cols) ...[
                if (start > 0) SizedBox(height: gap),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (
                        int column = 0;
                        column < cols && start + column < children.length;
                        column++
                      ) ...[
                        if (column > 0) SizedBox(width: gap),
                        Expanded(child: children[start + column]),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        }

        if (intrinsicHeight || mainAxisExtent == null) {
          // Round down to prevent fractional spacing from wrapping the final tile.
          final width = ((constraints.maxWidth - gap * (cols - 1)) / cols)
              .floorToDouble();
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final child in children)
                SizedBox(width: width > 0 ? width : constraints.maxWidth, child: child),
            ],
          );
        }

        final double ratio =
            childAspectRatio ?? (cols == 2 ? 1.45 : (cols == 3 ? 1.65 : 1.95));

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: children.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: mainAxisExtent == null ? ratio : 1.0,
            mainAxisExtent: mainAxisExtent,
          ),
          itemBuilder: (BuildContext _, int i) => children[i],
        );
      },
    );
  }
}
