import 'package:flutter/material.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

/// Displays observed tool use, never model-claimed source freshness.
class ResearchFreshness extends StatelessWidget {
  const ResearchFreshness({super.key, required this.metadata});
  final Map<String, dynamic> metadata;
  @override
  Widget build(BuildContext context) {
    final searched = metadata['webSearchUsed'] == true;
    final sensitive = metadata['timeSensitive'] == true;
    final stamp = DateTime.tryParse(
      '${metadata['requestedAt'] ?? ''}',
    )?.toUtc();
    if (!searched && !sensitive) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: context.sp(context.ui.spacing.sm)),
      child: searched
          ? Wrap(
              spacing: context.sp(context.ui.spacing.sm),
              runSpacing: context.sp(context.ui.spacing.xs),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const UiBadge(
                  label: 'Web searched',
                  icon: Icons.travel_explore,
                  size: UiSize.xs,
                  variant: UiBadgeVariant.soft,
                ),
                if (stamp != null)
                  Text(
                    'Requested ${stamp.toIso8601String().replaceFirst('T', ' ').split('.').first} UTC',
                    style: context.uiText.caption,
                  ),
              ],
            )
          : const UiCallout(
              title: 'Current information is unverified',
              message:
                  'No web search was recorded for this answer. Treat time-sensitive facts as unverified and enable Search to check dated sources.',
              intent: UiIntent.warning,
            ),
    );
  }
}
