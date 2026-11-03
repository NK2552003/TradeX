import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/ai_assistant/models/ai_coach_response.dart';

/// Warm editorial response surface for the fixed AI coach contract.
class AiCoachResponseCard extends StatelessWidget {
  const AiCoachResponseCard({
    super.key,
    required this.response,
    this.sources = const <String>[],
    this.onCopy,
    this.onRetry,
    this.onShare,
  });

  final AiCoachResponse response;
  final List<String> sources;
  final VoidCallback? onCopy;
  final VoidCallback? onRetry;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          response.label,
          style: context.uiText.caption.copyWith(
            color: colors.bullish,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        Text(
          response.title,
          style: context.uiText.heading.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.lg)),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < 360;
            final double width = compact
                ? constraints.maxWidth
                : (constraints.maxWidth - context.sp(theme.spacing.sm)) / 2;
            final List<Widget> cards = <Widget>[
              _RiskRewardTile(
                width: width,
                label: 'Risk/Reward · Initial',
                value: response.initialRiskReward,
                color: colors.surfaceMuted,
                valueColor: colors.foreground,
              ),
              _RiskRewardTile(
                width: width,
                label: 'Risk/Reward · Extended',
                value: response.extendedRiskReward,
                color: colors.bullish.withValues(alpha: 0.12),
                valueColor: colors.bullish,
              ),
            ];
            return Wrap(
              spacing: context.sp(theme.spacing.sm),
              runSpacing: context.sp(theme.spacing.sm),
              children: cards,
            );
          },
        ),
        SizedBox(height: context.sp(theme.spacing.lg)),
        Text(
          'The plan',
          style: context.uiText.caption.copyWith(
            color: colors.foregroundMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: colors.border,
                width: theme.borders.hairline,
              ),
              bottom: BorderSide(
                color: colors.border,
                width: theme.borders.hairline,
              ),
            ),
          ),
          child: Column(
            children: <Widget>[
              for (int index = 0; index < response.plan.length; index++)
                _PlanRow(number: index + 1, text: response.plan[index]),
            ],
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        Text(
          response.closing,
          style: context.uiText.body.copyWith(
            color: colors.foregroundMuted,
            height: 1.55,
          ),
        ),
        if (sources.isNotEmpty) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              for (final String source in sources)
                UiBadge(
                  label: source,
                  icon: Icons.link_rounded,
                  intent: UiIntent.info,
                  variant: UiBadgeVariant.outline,
                  size: UiSize.xs,
                ),
            ],
          ),
        ],
        Padding(
          padding: EdgeInsets.only(top: context.sp(theme.spacing.xs)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              UiButton(
                label: 'Copy',
                variant: UiVariant.link,
                onPressed: onCopy,
              ),
              UiButton(
                label: 'Regenerate',
                variant: UiVariant.link,
                onPressed: onRetry,
              ),
              if (onShare != null)
                UiButton(
                  label: 'Share',
                  variant: UiVariant.link,
                  onPressed: onShare,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RiskRewardTile extends StatelessWidget {
  const _RiskRewardTile({
    required this.width,
    required this.label,
    required this.value,
    required this.color,
    required this.valueColor,
  });

  final double width;
  final String label;
  final String value;
  final Color color;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return SizedBox(
      width: width,
      child: UiCard(
        variant: UiCardVariant.ghost,
        borderless: true,
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: context.radius(theme.radii.md),
          ),
          child: Padding(
            padding: EdgeInsets.all(context.sp(theme.spacing.md)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: context.uiText.caption),
                SizedBox(height: context.sp(theme.spacing.xs)),
                Text(
                  value,
                  style: context.uiText.display.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: context.sz(24),
            height: context.sz(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: context.uiText.caption.copyWith(
                    color: colors.onPrimary,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
          Expanded(
            child: Text(
              text,
              style: context.uiText.body.copyWith(height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}
