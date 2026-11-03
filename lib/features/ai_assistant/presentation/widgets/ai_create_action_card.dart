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
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final Color intentColor = target.intent.color(context);

    return UiCard(
      onTap: onTap,
      semanticLabel: target.actionLabel,
      variant: UiCardVariant.surface,
      borderless: true,
      accentColor: intentColor,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(target.icon, size: context.sz(20), color: intentColor),
          SizedBox(width: context.sp(theme.spacing.sm)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        target.label,
                        style: context.uiText.bodyStrong.copyWith(
                          fontSize: context.fs(14),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    UiBadge(
                      label: target.actionLabel,
                      intent: target.intent,
                      variant: UiBadgeVariant.soft,
                      size: UiSize.xs,
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.xxs)),
                Text(
                  target.description,
                  style: context.uiText.caption.copyWith(
                    color: colors.foregroundMuted,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: context.sz(13),
            color: colors.foregroundSubtle,
          ),
        ],
      ),
    );
  }
}
