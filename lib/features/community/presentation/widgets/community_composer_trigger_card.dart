import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/presentation/widgets/community_composer_card.dart';

/// A compact, LinkedIn-style trigger card for creating community posts.
///
/// Replaces the bulky inline composer with a sleek input pill and bottom action
/// buttons. Tapping any option opens the rich composer in an overlay right-side
/// sheet (on desktop/tablet) or a bottom drawer (on mobile).
class CommunityComposerTriggerCard extends StatelessWidget {
  const CommunityComposerTriggerCard({
    super.key,
    required this.onTap,
    this.placeholder =
        'Start a post, share a setup, or ask the community...',
  });

  /// Called when the user clicks the input field or any action button,
  /// passing the selected [ComposerMode].
  final void Function(ComposerMode mode) onTap;

  /// Placeholder hint text for the input trigger pill.
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 1. Top Input Field Trigger Pill (No Profile Icon, per design spec)
          Semantics(
            button: true,
            label: 'Start a post',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(context.radius(theme.radii.pill).topLeft.x),
                onTap: () => onTap(ComposerMode.post),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(theme.spacing.md),
                    vertical: context.sp(theme.spacing.sm) + 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted.withValues(alpha: 0.5),
                    borderRadius: context.radius(theme.radii.pill),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.7),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.edit_outlined,
                        size: context.sz(18),
                        color: colors.foregroundMuted,
                      ),
                      UiGap.h(theme.spacing.sm),
                      Expanded(
                        child: Text(
                          placeholder,
                          style: context.uiText.body.copyWith(
                            color: colors.foregroundMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      UiGap.h(theme.spacing.xs),
                      UiIconButton(
                        icon: Icons.add_rounded,
                        size: UiSize.xs,
                        variant: UiVariant.ghost,
                        intent: UiIntent.primary,
                        tooltip: 'New Post',
                        onPressed: () => onTap(ComposerMode.post),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          UiGap.v(theme.spacing.sm),

          // 2. Bottom Row Action Options (Trade Setup, Thesis, Photo/Chart, Article)
          Row(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: <Widget>[
                      _TriggerOption(
                        icon: Icons.candlestick_chart_rounded,
                        label: 'Trade Setup',
                        iconColor: const Color(0xFF10B981), // Emerald
                        onTap: () => onTap(ComposerMode.tradeSetup),
                      ),
                      UiGap.h(theme.spacing.xs),
                      _TriggerOption(
                        icon: Icons.trending_up_rounded,
                        label: 'Market Thesis',
                        iconColor: const Color(0xFF3B82F6), // Blue
                        onTap: () => onTap(ComposerMode.post),
                      ),
                      UiGap.h(theme.spacing.xs),
                      _TriggerOption(
                        icon: Icons.photo_outlined,
                        label: 'Chart / Media',
                        iconColor: const Color(0xFFF59E0B), // Amber
                        onTap: () => onTap(ComposerMode.chart),
                      ),
                      UiGap.h(theme.spacing.xs),
                      _TriggerOption(
                        icon: Icons.article_outlined,
                        label: 'Write Article',
                        iconColor: const Color(0xFF8B5CF6), // Purple
                        onTap: () => onTap(ComposerMode.attachment),
                      ),
                    ],
                  ),
                ),
              ),
              UiGap.h(theme.spacing.sm),
              UiButton(
                label: 'Post',
                size: UiSize.xs,
                intent: UiIntent.primary,
                onPressed: () => onTap(ComposerMode.post),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TriggerOption extends StatelessWidget {
  const _TriggerOption({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: context.radius(theme.radii.md),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.sm),
            vertical: context.sp(theme.spacing.xs),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: context.sz(18),
                color: iconColor,
              ),
              UiGap.h(theme.spacing.xs),
              Text(
                label,
                style: context.uiText.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.foreground.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
