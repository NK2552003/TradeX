import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class TraderLandingPage extends StatelessWidget {
  const TraderLandingPage({
    super.key,
    required this.userEmail,
    required this.onNavigateToSettings,
  });

  final String userEmail;
  final VoidCallback onNavigateToSettings;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildHeader(context, theme, colors),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // 4 Key Trader Metrics
          _buildMetrics(context, theme),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // AI Pulse & Pre-Trade Checklist Highlights
          _buildHighlights(context, theme, colors),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Quick Action Shortcuts
          _buildActionShortcuts(context, theme, colors),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UiTheme theme, UiColors colors) {
    return UiCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 480;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.candlestick_chart_outlined, size: context.sz(32), color: colors.primary),
                  ),
                  SizedBox(width: context.sp(theme.spacing.md)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: context.sp(theme.spacing.xs),
                          runSpacing: 4,
                          children: [
                            Text('Active Trader Dashboard', style: context.uiText.heading),
                            UiBadge(
                              label: 'TRADER',
                              intent: UiIntent.primary,
                              size: UiSize.xs,
                            ),
                          ],
                        ),
                        SizedBox(height: context.sp(theme.spacing.xxs)),
                        Text(
                          'Your quantitative trading journal, execution gates, and performance analytics.',
                          style: context.uiText.caption.copyWith(color: colors.foregroundMuted),
                        ),
                      ],
                    ),
                  ),
                  if (!isNarrow) ...[
                    SizedBox(width: context.sp(theme.spacing.md)),
                    UiButton(
                      label: 'Open Settings',
                      leadingIcon: Icons.tune_rounded,
                      variant: UiVariant.outline,
                      size: UiSize.sm,
                      onPressed: onNavigateToSettings,
                    ),
                  ],
                ],
              ),
              if (isNarrow) ...[
                SizedBox(height: context.sp(theme.spacing.md)),
                UiButton(
                  label: 'Open Settings',
                  leadingIcon: Icons.tune_rounded,
                  variant: UiVariant.outline,
                  size: UiSize.sm,
                  onPressed: onNavigateToSettings,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetrics(BuildContext context, UiTheme theme) {
    final cards = [
      UiMetricCard(
        label: 'Today\'s Net P&L',
        value: '+₹14,250.50',
        delta: 14.2,
        icon: Icons.trending_up_rounded,
      ),
      UiMetricCard(
        label: 'Win Rate (30D)',
        value: '68.4%',
        delta: 5.1,
        icon: Icons.pie_chart_outline_rounded,
      ),
      UiMetricCard(
        label: 'Open Positions',
        value: '3 Active',
        icon: Icons.candlestick_chart_outlined,
      ),
      UiMetricCard(
        label: 'Discipline Score',
        value: '96 / 100',
        delta: 2.0,
        icon: Icons.shield_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w >= 800) {
          return Row(
            children: [
              Expanded(child: cards[0]),
              SizedBox(width: context.sp(theme.spacing.md)),
              Expanded(child: cards[1]),
              SizedBox(width: context.sp(theme.spacing.md)),
              Expanded(child: cards[2]),
              SizedBox(width: context.sp(theme.spacing.md)),
              Expanded(child: cards[3]),
            ],
          );
        } else if (w >= 480) {
          final itemW = (w - context.sp(theme.spacing.md)) / 2;
          return Wrap(
            spacing: context.sp(theme.spacing.md),
            runSpacing: context.sp(theme.spacing.md),
            children: cards.map((c) => SizedBox(width: itemW, child: c)).toList(),
          );
        } else {
          return Column(
            children: cards
                .map((c) => Padding(
                      padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
                      child: c,
                    ))
                .toList(),
          );
        }
      },
    );
  }

  Widget _buildHighlights(BuildContext context, UiTheme theme, UiColors colors) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCallout(
          title: 'AI Market Intelligence Daily Pulse',
          message:
              'NIFTY 50 and RELIANCE are showing high-conviction breakout setups on above-average relative volume. Your risk-reward target is set to 2.5R in Trading Preferences.',
          intent: UiIntent.bullish,
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pre-Trade Checklist Gates: Active', style: context.uiText.bodyStrong),
                    SizedBox(height: context.sp(theme.spacing.xxs)),
                    Text(
                      '3 of 4 required discipline gates passed for current session setups.',
                      style: context.uiText.caption.copyWith(color: colors.foregroundMuted),
                    ),
                  ],
                ),
              ),
              UiButton(
                label: 'Configure Gates',
                variant: UiVariant.outline,
                size: UiSize.sm,
                onPressed: onNavigateToSettings,
              ),
            ],
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        // Partner RevShare Spotlight Card
        UiCard(
          accentColor: colors.warning,
          child: Padding(
            padding: EdgeInsets.all(context.sp(theme.spacing.md)),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.handshake_rounded, color: colors.warning, size: context.sz(24)),
                ),
                SizedBox(width: context.sp(theme.spacing.md)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: context.sp(theme.spacing.xs),
                        runSpacing: 4,
                        children: [
                          Text('Refer a Trader & Earn 30% Lifetime RevShare', style: context.uiText.bodyStrong),
                          UiBadge(
                            label: 'PARTNER PERKS',
                            intent: UiIntent.warning,
                            size: UiSize.xs,
                          ),
                        ],
                      ),
                      SizedBox(height: context.sp(theme.spacing.xxs)),
                      Text(
                        'Share your invite link with fellow traders. Earn recurring monthly payouts or waive your TradeX Pro fees completely.',
                        style: context.uiText.caption.copyWith(color: colors.foregroundMuted),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.md)),
                UiButton(
                  label: 'View Perks & Link',
                  leadingIcon: Icons.arrow_forward_rounded,
                  intent: UiIntent.warning,
                  variant: UiVariant.soft,
                  size: UiSize.sm,
                  onPressed: onNavigateToSettings,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionShortcuts(BuildContext context, UiTheme theme, UiColors colors) {
    final item1 = UiInteractive(
      onTap: onNavigateToSettings,
      builder: (context, state) => Container(
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        decoration: BoxDecoration(
          color: state.hovered ? colors.surfaceHover : colors.surface,
          borderRadius: context.radius(theme.radii.md),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.person_outline_rounded, color: colors.primary),
            SizedBox(width: context.sp(theme.spacing.sm)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profile & Trading Style', style: context.uiText.bodyStrong),
                  Text('Customize avatar and public credentials', style: context.uiText.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final item2 = UiInteractive(
      onTap: onNavigateToSettings,
      builder: (context, state) => Container(
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        decoration: BoxDecoration(
          color: state.hovered ? colors.surfaceHover : colors.surface,
          borderRadius: context.radius(theme.radii.md),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.tune_rounded, color: colors.primary),
            SizedBox(width: context.sp(theme.spacing.sm)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trading & Risk Preferences', style: context.uiText.bodyStrong),
                  Text('Configure parameters and notification gates', style: context.uiText.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions & Preferences', style: context.uiText.heading),
        SizedBox(height: context.sp(theme.spacing.sm)),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 600) {
              return Row(
                children: [
                  Expanded(child: item1),
                  SizedBox(width: context.sp(theme.spacing.md)),
                  Expanded(child: item2),
                ],
              );
            } else {
              return Column(
                children: [
                  item1,
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  item2,
                ],
              );
            }
          },
        ),
      ],
    );
  }
}
