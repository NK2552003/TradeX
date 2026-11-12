import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app-ui/app_ui.dart';
// ignore: unnecessary_import
import '../flutter-ui/flutter_ui.dart';
import 'ad_scope.dart';

/// Layout-only space for future house promotions on private product screens.
/// Intentionally independent of AdSlot: it can never mount a Google ad.
class PromotionPreview extends StatelessWidget {
  const PromotionPreview({super.key, required this.surface});
  final String surface;

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode || AdSenseScope.maybeOf(context)?.config.preview != true) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
      child: UiCard(
        variant: UiCardVariant.subtle,
        child: Row(
          children: [
            Icon(
              Icons.campaign_outlined,
              color: context.ui.colors.foregroundMuted,
            ),
            UiGap.h(context.ui.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$surface promotion space',
                    style: context.uiText.bodyStrong,
                  ),
                  Text(
                    'Preview only · non-Google placement',
                    style: context.uiText.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
