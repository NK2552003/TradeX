import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import '../../models/strategy_model.dart';

/// Onboarding guide overlay for strategies feature.
/// Shows users what to do first and what to do last.
class StrategyGuideOverlay extends StatelessWidget {
  const StrategyGuideOverlay({
    super.key,
    this.onDismiss,
    this.onGetStarted,
  });

  final VoidCallback? onDismiss;
  final VoidCallback? onGetStarted;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    return UiCard(
      accentColor: theme.colors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: theme.colors.primary,
                size: context.sz(theme.sizes.iconLg),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: Text(
                  'Getting Started with Strategies',
                  style: context.uiText.subheading,
                ),
              ),
              UiIconButton(
                icon: Icons.close,
                size: UiSize.sm,
                onPressed: onDismiss,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),
          // Step-by-step guide
          _stepWidget(
            context,
            step: 1,
            title: 'Define Your Strategy',
            description: 'Give your strategy a name and category (e.g., "Opening Range Breakout", "Trend Following").',
            icon: Icons.edit_note,
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          _stepWidget(
            context,
            step: 2,
            title: 'Set Entry & Exit Rules',
            description: 'Document your entry conditions, exit criteria, stop-loss, and take-profit levels.',
            icon: Icons.rule,
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          _stepWidget(
            context,
            step: 3,
            title: 'Define Risk Parameters',
            description: 'Set position sizing rules and maximum risk per trade.',
            icon: Icons.shield_outlined,
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          _stepWidget(
            context,
            step: 4,
            title: 'Link Trades',
            description: 'As you execute trades in the Journal, link them to this strategy to track performance.',
            icon: Icons.link,
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          _stepWidget(
            context,
            step: 5,
            title: 'Review & Refine',
            description: 'Analyze win rate, P/L, and R-multiple. Update rules based on learnings.',
            icon: Icons.analytics_outlined,
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),
          // CTA Button
          UiButton(
            label: 'Create Your First Strategy',
            leadingIcon: Icons.add,
            expand: true,
            onPressed: onGetStarted,
          ),
        ],
      ),
    );
  }

  Widget _stepWidget(BuildContext context, {
    required int step,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final UiTheme theme = context.ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: context.sz(32),
          height: context.sz(32),
          decoration: BoxDecoration(
            color: theme.colors.primary.withValues(alpha: 0.12),
            borderRadius: context.radius(theme.radii.full),
          ),
          alignment: Alignment.center,
          child: Text(
            step.toString(),
            style: context.uiText.labelStrong.copyWith(
              color: theme.colors.primary,
            ),
          ),
        ),
        SizedBox(width: context.sp(theme.spacing.md)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: context.sz(theme.sizes.iconSm),
                    color: theme.colors.foregroundMuted,
                  ),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  Text(
                    title,
                    style: context.uiText.bodyStrong,
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.xs)),
              Text(
                description,
                style: context.uiText.body.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Empty state with guide for strategies page.
class StrategiesEmptyState extends StatelessWidget {
  const StrategiesEmptyState({
    super.key,
    this.onCreateStrategy,
    this.showGuide = true,
  });

  final VoidCallback? onCreateStrategy;
  final bool showGuide;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_graph_outlined,
              size: context.sz(80),
              color: theme.colors.foregroundSubtle,
            ),
            SizedBox(height: context.sp(theme.spacing.lg)),
            Text(
              'No Strategies Yet',
              style: context.uiText.heading,
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            Text(
              'Strategies are your trading playbooks. Define your rules first,\nthen link trades to measure performance.',
              textAlign: TextAlign.center,
              style: context.uiText.body.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.lg)),
            if (showGuide) ...[
              StrategyGuideOverlay(
                onGetStarted: onCreateStrategy,
              ),
              SizedBox(height: context.sp(theme.spacing.md)),
            ],
            UiButton(
              label: 'Create Strategy',
              leadingIcon: Icons.add,
              expandOnMobile: false,
              onPressed: onCreateStrategy,
            ),
          ],
        ),
      ),
    );
  }
}
