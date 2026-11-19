import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import '../../data/community_chart_detector.dart';

class CommunityChartReview extends StatelessWidget {
  const CommunityChartReview({
    super.key,
    required this.detection,
    required this.onApply,
    required this.onDismiss,
  });
  final CommunityChartDetection detection;
  final VoidCallback onApply;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final gap = context.sp(theme.spacing.sm);
    return UiCard(
      variant: UiCardVariant.subtle,
      title: 'Chart detected',
      subtitle: 'Review the image-derived values before adding them.',
      trailing: UiIconButton(
        icon: Icons.close,
        tooltip: 'Dismiss chart suggestion',
        onPressed: onDismiss,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final field in detection.setup.entries)
                UiBadge(
                  label:
                      '${switch (field.key) {
                        'stopLoss' => 'Stop loss',
                        'entry' => 'Entry',
                        'target' => 'Target',
                        'ticker' => 'Symbol',
                        _ => 'Side',
                      }}: ${field.value}',
                  variant: UiBadgeVariant.outline,
                ),
            ],
          ),
          UiGap.v(gap),
          if (detection.candles.isNotEmpty) ...[
            UiCandleChart(
              candles: detection.candles,
              height: 140,
              showVolume: false,
              interactive: false,
            ),
            UiGap.v(gap),
          ],
          Text(
            detection.candles.isEmpty
                ? 'The time or price axes could not be fully read. No candles were generated.'
                : '${detection.candles.length} approximate candles reconstructed from the image. Verify against the source chart.',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
          UiGap.v(gap),
          UiButton(
            label: 'Use detected setup',
            leadingIcon: Icons.playlist_add_check_rounded,
            onPressed: detection.setup.isEmpty && detection.candles.isEmpty
                ? null
                : onApply,
          ),
          UiGap.v(context.sp(theme.spacing.xs)),
          Text(
            'Only empty fields will be filled. Your existing setup stays intact.',
            style: context.uiText.caption,
          ),
        ],
      ),
    );
  }
}
