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
    this.childAspectRatio = 1.95,
  });

  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final int largeColumns;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
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
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: children.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (BuildContext _, int i) => children[i],
        );
      },
    );
  }
}
