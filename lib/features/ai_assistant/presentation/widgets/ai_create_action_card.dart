import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';

/// A card in the "create anything" hub — one per [AiCreateTarget]. Shows the
/// target's intent-tinted icon, label, description and the verb it commits with.
/// All copy comes from [AiCreateTargetX]; the card holds no literal content.
class AiCreateActionCard extends StatelessWidget {
  const AiCreateActionCard({
    super.key,
    required this.target,
    required this.onTap,
  });

  final AiCreateTarget target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return UiCard(
      onTap: onTap,
      semanticLabel: target.actionLabel,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            target.icon,
            size: context.sz(22),
            color: target.intent.color(context),
          ),
          UiGap.h(theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(target.label, style: context.uiText.bodyStrong),
                UiGap.v(theme.spacing.xs),
                Text(
                  target.description,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                    height: 1.45,
                  ),
                ),
                UiGap.v(theme.spacing.sm),
                Text(
                  target.actionLabel,
                  style: context.uiText.caption.copyWith(
                    color: target.intent.color(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          UiGap.h(theme.spacing.xs),
          Icon(
            Icons.chevron_right_rounded,
            size: context.sz(18),
            color: theme.colors.foregroundSubtle,
          ),
        ],
      ),
    );
  }
}
