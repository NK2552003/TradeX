import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
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
    final Color tint = target.intent.color(context);
    return UiCard(
      onTap: onTap,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Row(
        children: <Widget>[
          Container(
            width: context.sz(44),
            height: context.sz(44),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.13),
              borderRadius: context.radius(theme.radii.md),
            ),
            child: Icon(
              target.icon,
              size: context.sz(theme.sizes.iconLg),
              color: tint,
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.md)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        target.label,
                        style: context.uiText.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    UiBadge(
                      label: target.actionLabel,
                      intent: target.intent,
                      variant: UiBadgeVariant.soft,
                      size: UiSize.sm,
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.xxs)),
                Text(
                  target.description,
                  style: context.uiText.caption.copyWith(
                    color: colors.foregroundMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          Icon(
            Icons.arrow_forward_rounded,
            size: context.sz(theme.sizes.iconMd),
            color: colors.foregroundSubtle,
          ),
        ],
      ),
    );
  }
}
