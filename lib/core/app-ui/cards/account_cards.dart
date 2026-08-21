import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';
import '../motion/app_motion.dart';
import '../theme/app_tokens.dart';

/// Subscription plan card used on the pricing / upgrade screens.
class AppPlanCard extends StatelessWidget {
  const AppPlanCard({super.key, required this.plan, this.onSelect});

  final AppPlan plan;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color tint = AppTokens.tierColor(context, plan.tier);
    return AppHoverLift(
      child: UiCard(
        elevated: plan.highlighted,
        accentColor: plan.highlighted ? tint : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  AppTokens.tierIcon(plan.tier),
                  color: tint,
                  size: context.sz(theme.sizes.iconMd),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                Expanded(
                  child: Text(
                    AppTokens.tierLabel(plan.tier),
                    style: context.uiText.subheading,
                  ),
                ),
                if (plan.current)
                  const UiBadge(label: 'Current', intent: UiIntent.bullish)
                else if (plan.highlighted)
                  const UiBadge(label: 'Popular', intent: UiIntent.warning),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.md)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                // Display type at a large accessibility text scale is wide enough
                // to run a four-figure price off a narrow card, so the price gives
                // way before the billing period it belongs to.
                Flexible(
                  child: Text(
                    plan.priceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.display,
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xxs)),
                Flexible(
                  child: Text(
                    plan.period,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ),
              ],
            ),
            if (plan.description != null) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.xs)),
              Text(
                plan.description!,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
            SizedBox(height: context.sp(theme.spacing.lg)),
            for (final String f in plan.features)
              Padding(
                padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_outline,
                      size: context.sz(theme.sizes.iconSm),
                      color: tint,
                    ),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Expanded(child: Text(f, style: context.uiText.body)),
                  ],
                ),
              ),
            SizedBox(height: context.sp(theme.spacing.md)),
            UiButton(
              label: plan.current
                  ? 'Your plan'
                  : 'Choose ${AppTokens.tierLabel(plan.tier)}',
              expand: true,
              variant: plan.highlighted ? UiVariant.primary : UiVariant.outline,
              onPressed: plan.current ? null : onSelect,
            ),
          ],
        ),
      ),
    );
  }
}

/// Usage meter for quota-limited features (AI credits, screenshot imports).
class AppUsageCard extends StatelessWidget {
  const AppUsageCard({
    super.key,
    required this.label,
    required this.used,
    required this.limit,
    this.icon,
    this.onUpgrade,
  });

  final String label;
  final int used;
  final int limit;
  final IconData? icon;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double ratio = limit == 0 ? 0 : (used / limit).clamp(0, 1).toDouble();
    final UiIntent intent = ratio >= 0.9
        ? UiIntent.bearish
        : (ratio >= 0.7 ? UiIntent.warning : UiIntent.primary);
    return UiCard(
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: context.sz(theme.sizes.iconSm),
                  color: theme.colors.foregroundMuted,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.bodyStrong,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              // Quotas run to five and six figures, so the tally is abbreviated
              // and bounded rather than printed raw beside the label.
              Flexible(
                child: Text(
                  '${AppTokens.count(used)} / ${AppTokens.count(limit)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: context.uiText.numeric,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          UiProgressBar(value: ratio, intent: intent, showValue: false),
          if (ratio >= 0.9 && onUpgrade != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.sm)),
            UiButton(
              label: 'Upgrade for more',
              variant: UiVariant.ghost,
              size: UiSize.sm,
              expandOnMobile: false,
              onPressed: onUpgrade,
            ),
          ],
        ],
      ),
    );
  }
}

/// Locked-feature card shown when a tier gate blocks content.
class AppTierGateCard extends StatelessWidget {
  const AppTierGateCard({
    super.key,
    required this.requiredTier,
    required this.title,
    this.message,
    this.onUpgrade,
  });

  final AppTier requiredTier;
  final String title;
  final String? message;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color tint = AppTokens.tierColor(context, requiredTier);
    return UiCard(
      accentColor: tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.lock_outline,
                color: tint,
                size: context.sz(theme.sizes.iconMd),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(child: Text(title, style: context.uiText.subheading)),
              UiBadge(
                label: AppTokens.tierLabel(requiredTier),
                intent: AppTokens.tierIntent(requiredTier),
                filled: true,
              ),
            ],
          ),
          if (message != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.sm)),
            Text(
              message!,
              style: context.uiText.body.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
          ],
          SizedBox(height: context.sp(theme.spacing.lg)),
          UiButton(label: 'Unlock', onPressed: onUpgrade, expandOnMobile: true),
        ],
      ),
    );
  }
}

/// Gamified achievement / badge tile.
class AppAchievementCard extends StatelessWidget {
  const AppAchievementCard({super.key, required this.achievement, this.onTap});

  final AppAchievement achievement;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool on = achievement.unlocked;
    final Color tint = on
        ? theme.colors.warning
        : theme.colors.foregroundSubtle;
    return UiCard(
      onTap: onTap,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: on ? 0.16 : 0.08),
              borderRadius: context.radius(theme.radii.md),
            ),
            child: Icon(
              achievement.icon,
              color: tint,
              size: context.sz(theme.sizes.iconMd),
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Text(
            achievement.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.bodyStrong,
          ),
          if (achievement.description != null)
            Text(
              achievement.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
          if (!on && achievement.progress != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.sm)),
            UiProgressBar(
              value: achievement.progress!.clamp(0, 1),
              intent: UiIntent.warning,
              showValue: false,
            ),
          ],
        ],
      ),
    );
  }
}

/// Settings row: label, description and a trailing control.
class AppSettingCard extends StatelessWidget {
  const AppSettingCard({
    super.key,
    required this.title,
    required this.control,
    this.description,
    this.icon,
  });

  final String title;
  final Widget control;
  final String? description;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stack = constraints.maxWidth < context.sz(520);
        final bool mobile = context.uiRes.isMobile;
        final bool trailingSwitch = mobile && control is UiSwitch;
        final Widget copy = Row(
          crossAxisAlignment: mobile
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              if (mobile)
                Container(
                  padding: EdgeInsets.all(context.sp(theme.spacing.xs + 1)),
                  decoration: BoxDecoration(
                    color: theme.colors.primary.withValues(alpha: 0.08),
                    borderRadius: context.radius(theme.radii.md),
                  ),
                  child: Icon(
                    icon,
                    size: context.sz(theme.sizes.iconXs),
                    color: theme.colors.primary,
                  ),
                )
              else
                Icon(
                  icon,
                  size: context.sz(theme.sizes.iconSm),
                  color: theme.colors.foregroundMuted,
                ),
              SizedBox(
                width: context.sp(mobile ? theme.spacing.sm : theme.spacing.md),
              ),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: mobile ? 2 : null,
                    overflow: mobile ? TextOverflow.ellipsis : null,
                    style: mobile
                        ? context.uiText.label.copyWith(
                            color: theme.colors.foreground,
                          )
                        : context.uiText.bodyStrong,
                  ),
                  if (description != null) ...<Widget>[
                    SizedBox(height: context.sp(theme.spacing.xxs)),
                    Text(
                      description!,
                      maxLines: mobile ? 3 : null,
                      overflow: mobile ? TextOverflow.ellipsis : null,
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                        fontSize: mobile ? context.fs(11.5) : null,
                        height: mobile ? 1.35 : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );

        return UiCard(
          radius: theme.radii.lg,
          padding: mobile
              ? EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.md),
                  vertical: context.sp(theme.spacing.sm + 2),
                )
              : EdgeInsets.all(context.sp(theme.spacing.md)),
          child: trailingSwitch
              ? Row(
                  children: <Widget>[
                    Expanded(child: copy),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    control,
                  ],
                )
              : stack
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    copy,
                    SizedBox(
                      height: context.sp(
                        mobile ? theme.spacing.sm : theme.spacing.md,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: context.sz(280)),
                        child: control,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: <Widget>[
                    Expanded(child: copy),
                    SizedBox(width: context.sp(theme.spacing.md)),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: context.sz(280)),
                      child: control,
                    ),
                  ],
                ),
        );
      },
    );
  }
}
