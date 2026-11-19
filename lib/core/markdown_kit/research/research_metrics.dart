import 'package:flutter/material.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

/// Consistent metric rails with room for scaled text and long narrative values.
class ResearchMetrics extends StatelessWidget {
  const ResearchMetrics({super.key, required this.stats});
  final List<UiStat> stats;
  @override
  Widget build(BuildContext context) {
    final compact = stats.where((s) => s.value.length <= 24).toList();
    final narrative = stats.where((s) => s.value.length > 24).toList();
    final spacing = context.ui.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact.isNotEmpty)
          UiCard(
            variant: UiCardVariant.subtle,
            padding: EdgeInsets.zero,
            child: UiStatStrip(
              stats: compact,
              minCellWidth: 148 * MediaQuery.textScalerOf(context).scale(1),
              density: UiDensity.comfortable,
            ),
          ),
        for (final stat in narrative) ...[
          UiGap.v(spacing.sm),
          UiCallout(
            title: stat.label,
            message: [stat.value, if (stat.hint != null) stat.hint!].join('\n'),
            intent: UiIntent.neutral,
          ),
        ],
      ],
    );
  }
}
