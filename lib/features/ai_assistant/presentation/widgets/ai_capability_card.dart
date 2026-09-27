import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';

/// A capability tile in the "what can the copilot do" grid. Tapping it seeds the
/// composer with the capability's prompt (and, when the capability carries a
/// [AiCreateTarget], routes into the create flow). All copy comes from the
/// [AiCapability] model — nothing is hardcoded here.
class AiCapabilityCard extends StatelessWidget {
  const AiCapabilityCard({
    super.key,
    required this.capability,
    required this.onTap,
  });

  final AiCapability capability;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return UiCard(
      onTap: onTap,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: context.sz(40),
                height: context.sz(40),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: context.radius(theme.radii.md),
                ),
                child: Icon(
                  capability.icon,
                  size: context.sz(theme.sizes.iconLg),
                  color: colors.primary,
                ),
              ),
              const Spacer(),
              if (capability.badge != null)
                UiBadge(
                  label: capability.badge!,
                  intent: UiIntent.primary,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.sm,
                ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Text(
            capability.title,
            style: context.uiText.bodyStrong,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            capability.description,
            style: context.uiText.caption.copyWith(
              color: colors.foregroundMuted,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
