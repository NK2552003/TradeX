import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AffiliateLandingPage extends StatelessWidget {
  const AffiliateLandingPage({
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

          // 4 Key Affiliate Metrics
          _buildMetrics(context, theme),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Referral Link Box & Media Kit Download
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
                      color: colors.warning.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.handshake_rounded, size: context.sz(32), color: colors.warning),
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
                            Text('Affiliate Partner Portal', style: context.uiText.heading),
                            UiBadge(
                              label: 'AFFILIATE',
                              intent: UiIntent.warning,
                              size: UiSize.xs,
                            ),
                          ],
                        ),
                        SizedBox(height: context.sp(theme.spacing.xxs)),
                        Text(
                          'Track referrals, monitor monthly payouts, and access promotional media kits.',
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
        label: 'Active Referrals',
        value: '48 Traders',
        delta: 12.0,
        icon: Icons.people_outline_rounded,
      ),
      UiMetricCard(
        label: 'Lifetime Earnings',
        value: '₹84,500.00',
        delta: 28.4,
        icon: Icons.currency_rupee_rounded,
      ),
      UiMetricCard(
        label: 'Pending Payout',
        value: '₹14,200.00',
        icon: Icons.schedule_rounded,
      ),
      UiMetricCard(
        label: 'Conversion Rate',
        value: '14.2%',
        delta: 3.1,
        icon: Icons.ads_click_rounded,
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
        UiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Your Referral Link', style: context.uiText.bodyStrong),
                  UiBadge(label: '30% RECURRING', intent: UiIntent.warning),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.xs)),
              Text(
                'https://tradex.ai/r/nitish_alpha',
                style: context.uiText.caption.copyWith(
                  fontFamily: 'monospace',
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.md)),
              Row(
                children: [
                  UiButton(
                    label: 'Copy Link',
                    leadingIcon: Icons.copy_rounded,
                    intent: UiIntent.primary,
                    size: UiSize.sm,
                    onPressed: () {
                      UiToast.show(
                        context,
                        title: 'Copied!',
                        message: 'Referral link copied to clipboard.',
                        intent: UiIntent.success,
                      );
                    },
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  UiButton(
                    label: 'Edit Custom Slug',
                    variant: UiVariant.outline,
                    size: UiSize.sm,
                    onPressed: onNavigateToSettings,
                  ),
                ],
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
                  Text('Partner Identity', style: context.uiText.bodyStrong),
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
            Icon(Icons.account_balance_wallet_outlined, color: colors.primary),
            SizedBox(width: context.sp(theme.spacing.sm)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payout & RevShare Settings', style: context.uiText.bodyStrong),
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
