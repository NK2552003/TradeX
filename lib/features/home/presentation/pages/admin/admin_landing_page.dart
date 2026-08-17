import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AdminLandingPage extends StatelessWidget {
  const AdminLandingPage({
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

          // 4 Key Desk Metrics
          _buildMetrics(context, theme),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Firm Governance & Compliance Live
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
                      color: colors.bearish.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.shield_rounded, size: context.sz(32), color: colors.bearish),
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
                            Text('Institutional Desk Console', style: context.uiText.heading),
                            UiBadge(
                              label: 'ADMIN',
                              intent: UiIntent.danger,
                              size: UiSize.xs,
                            ),
                          ],
                        ),
                        SizedBox(height: context.sp(theme.spacing.xxs)),
                        Text(
                          'Firm-wide risk circuit breakers, trader capital allocation, and compliance oversight.',
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
        label: 'Active Desk Seats',
        value: '18 / 25 Used',
        icon: Icons.groups_outlined,
      ),
      UiMetricCard(
        label: 'Firm Drawdown Intraday',
        value: '1.2% / 5.0%',
        delta: -0.4,
        icon: Icons.shield_outlined,
      ),
      UiMetricCard(
        label: 'Desk Daily Volume',
        value: '₹48.2 Cr',
        delta: 8.5,
        icon: Icons.bar_chart_rounded,
      ),
      UiMetricCard(
        label: 'Risk Flags',
        value: '0 Clean',
        icon: Icons.check_circle_outline_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w >= 800) {
          return Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) SizedBox(width: context.sp(theme.spacing.md)),
                Expanded(child: cards[i]),
              ],
            ],
          );
        } else if (w >= 480) {
          final itemW = (w - context.sp(theme.spacing.md)) / 2;
          return Wrap(
            spacing: context.sp(theme.spacing.md),
            runSpacing: context.sp(theme.spacing.md),
            children: [
              for (final c in cards) SizedBox(width: itemW, child: c),
            ],
          );
        } else {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) SizedBox(height: context.sp(theme.spacing.sm)),
                cards[i],
              ],
            ],
          );
        }
      },
    );
  }

  Widget _buildHighlights(BuildContext context, UiTheme theme, UiColors colors) {
    return Column(
      children: [
        UiCallout(
          title: 'Firm Governance & Compliance Live',
          message:
              'All 18 active prop traders are within designated risk limits. Immutable execution audit logs are synchronized.',
          intent: UiIntent.primary,
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Desk Workspace Branding', style: context.uiText.bodyStrong),
                    SizedBox(height: context.sp(theme.spacing.xxs)),
                    Text(
                      'Alpha Quantitative Prop Desk · Proprietary Trading Division',
                      style: context.uiText.caption.copyWith(color: colors.foregroundMuted),
                    ),
                  ],
                ),
              ),
              UiButton(
                label: 'Manage Team & Roles',
                variant: UiVariant.outline,
                size: UiSize.sm,
                onPressed: onNavigateToSettings,
              ),
            ],
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
                  Text('Admin Credentials', style: context.uiText.bodyStrong),
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
            Icon(Icons.shield_outlined, color: colors.primary),
            SizedBox(width: context.sp(theme.spacing.sm)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Desk Risk & Policies', style: context.uiText.bodyStrong),
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
