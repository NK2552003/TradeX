import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import '../../models/strategy_model.dart';

/// Compact, professional strategy card with reduced padding and clean typography.
class StrategyCard extends StatelessWidget {
  const StrategyCard({
    super.key,
    required this.strategy,
    this.onTap,
    this.onFavorite,
    this.compact = false,
  });

  final Strategy strategy;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final plColor = AppTokens.pl(context, strategy.netPnl);

    return AppHoverLift(
      child: UiCard(
        onTap: onTap,
        title: strategy.name,
        subtitle: strategy.category ?? 'Uncategorized',
        padding: EdgeInsets.all(context.sp(compact ? theme.spacing.sm : theme.spacing.md)),
        trailing: UiIconButton(
          icon: strategy.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
          onPressed: onFavorite,
          size: UiSize.sm,
          tooltip: strategy.isFavorite ? 'Remove from favorites' : 'Add to favorites',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Performance metrics row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _metricChip(context, '${strategy.winRate.toStringAsFixed(0)}%', 'Win Rate'),
                _metricChip(context, strategy.tradesCount.toString(), 'Trades'),
                _metricChip(context, AppTokens.rr(strategy.avgR), 'Avg R'),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            // P/L display
            Text(
              AppTokens.signedMoney(strategy.netPnl),
              style: context.uiText.title.copyWith(color: plColor),
            ),
            if (!compact && strategy.description != null) ...[
              SizedBox(height: context.sp(theme.spacing.xs)),
              Text(
                strategy.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.body.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
            SizedBox(height: context.sp(theme.spacing.sm)),
            // Badges
            Wrap(
              spacing: context.sp(theme.spacing.xs),
              runSpacing: context.sp(theme.spacing.xs),
              children: [
                UiBadge(
                  label: strategy.isPublic ? 'Public' : 'Private',
                  icon: strategy.isPublic ? Icons.public : Icons.lock_outline,
                  size: UiSize.xs,
                ),
                if (strategy.linkedTrades.isNotEmpty)
                  UiBadge(
                    label: '${strategy.linkedTrades.length} linked',
                    icon: Icons.link,
                    intent: UiIntent.primary,
                    size: UiSize.xs,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(BuildContext context, String value, String label) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: context.uiText.numeric.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundSubtle,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

/// Grid layout for strategy cards - responsive based on screen width.
class StrategyGrid extends StatelessWidget {
  const StrategyGrid({
    super.key,
    required this.strategies,
    this.onStrategyTap,
    this.onFavorite,
    this.compact = false,
  });

  final List<Strategy> strategies;
  final ValueChanged<Strategy>? onStrategyTap;
  final ValueChanged<Strategy>? onFavorite;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (strategies.isEmpty) {
      return UiEmptyState(
        title: 'No strategies yet',
        message: 'Create your first trading strategy to get started.',
        icon: Icons.auto_graph_outlined,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 500) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 1;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: context.sp(context.ui.spacing.md),
            mainAxisSpacing: context.sp(context.ui.spacing.md),
            childAspectRatio: compact ? 1.2 : 1.4,
          ),
          itemCount: strategies.length,
          itemBuilder: (context, index) {
            final strategy = strategies[index];
            return StrategyCard(
              strategy: strategy,
              compact: compact,
              onTap: onStrategyTap == null ? null : () => onStrategyTap!(strategy),
              onFavorite: onFavorite == null ? null : () => onFavorite!(strategy),
            );
          },
        );
      },
    );
  }
}
