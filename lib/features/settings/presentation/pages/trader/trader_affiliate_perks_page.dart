import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Page shown to active traders highlighting the benefits of the Affiliate Partner Program.
class TraderAffiliatePerksPage extends StatefulWidget {
  const TraderAffiliatePerksPage({super.key, this.onUpgradeToAffiliate});

  final VoidCallback? onUpgradeToAffiliate;

  @override
  State<TraderAffiliatePerksPage> createState() =>
      _TraderAffiliatePerksPageState();
}

class _TraderAffiliatePerksPageState extends State<TraderAffiliatePerksPage> {
  double _referredTraders = 25;
  final String _referralLink = 'https://tradex.ai/r/nitish_alpha';

  static const double _proPlanPrice = 2499.0;
  static const double _revSharePercent = 0.30;

  double get _monthlyEarnings =>
      _referredTraders * _proPlanPrice * _revSharePercent;
  double get _annualEarnings => _monthlyEarnings * 12;

  void _copyReferralLink() {
    Clipboard.setData(ClipboardData(text: _referralLink));
    UiToast.show(
      context,
      title: 'Referral Link Copied',
      message: 'Share $_referralLink with your fellow traders!',
      intent: UiIntent.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final responsive = context.uiRes;
    final double bottomInset = responsive.isMobile
        ? (keyboardInset > 0 ? keyboardInset + 24.0 : 108.0)
        : context.sp(theme.spacing.lg);

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        context.sp(responsive.isMobile ? theme.spacing.sm : theme.spacing.lg),
        context.sp(responsive.isMobile ? theme.spacing.sm : theme.spacing.lg),
        context.sp(responsive.isMobile ? theme.spacing.sm : theme.spacing.lg),
        bottomInset,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              UiCard(
                accentColor: colors.warning,
                child: Padding(
                  padding: EdgeInsets.all(
                    context.sp(
                      responsive.isMobile
                          ? theme.spacing.md
                          : theme.spacing.lg,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, headerConstraints) {
                          final isNarrow = headerConstraints.maxWidth < 480;
                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(
                                        context.sp(theme.spacing.sm),
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.warning
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            context.radius(theme.radii.md),
                                      ),
                                      child: Icon(
                                        Icons.handshake_outlined,
                                        color: colors.warning,
                                        size: context.sz(24),
                                      ),
                                    ),
                                    const UiBadge(
                                      label: '30% REVSHARE',
                                      intent: UiIntent.warning,
                                      size: UiSize.sm,
                                    ),
                                  ],
                                ),
                                SizedBox(height: context.sp(theme.spacing.sm)),
                                Text(
                                  'TradeX Partner & Affiliate Program',
                                  style: context.uiText.heading,
                                ),
                                SizedBox(height: context.sp(theme.spacing.xxs)),
                                Text(
                                  'Monetize your trading edge & community',
                                  style: context.uiText.caption.copyWith(
                                    color: colors.foregroundMuted,
                                  ),
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.all(
                                  context.sp(theme.spacing.sm),
                                ),
                                decoration: BoxDecoration(
                                  color: colors.warning.withValues(alpha: 0.15),
                                  borderRadius: context.radius(theme.radii.md),
                                ),
                                child: Icon(
                                  Icons.handshake_outlined,
                                  color: colors.warning,
                                  size: context.sz(24),
                                ),
                              ),
                              SizedBox(width: context.sp(theme.spacing.md)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TradeX Partner & Affiliate Program',
                                      style: context.uiText.heading,
                                    ),
                                    Text(
                                      'Monetize your trading edge & community',
                                      style: context.uiText.caption.copyWith(
                                        color: colors.foregroundMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: context.sp(theme.spacing.sm)),
                              const UiBadge(
                                label: '30% REVSHARE',
                                intent: UiIntent.warning,
                                size: UiSize.sm,
                              ),
                            ],
                          );
                        },
                      ),
                      SizedBox(height: context.sp(theme.spacing.md)),
                      Text(
                        'As a TradeX trader, you are eligible to earn a recurring 30% lifetime commission on every trader who subscribes through your referral link. Refer fellow traders, students, or your community members and build a passive income stream alongside your trading.',
                        style: context.uiText.body.copyWith(
                          color: colors.foregroundMuted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: context.sp(theme.spacing.xl)),

              // Your Personal Referral Link Box
              UiCard(
                child: Padding(
                  padding: EdgeInsets.all(
                    context.sp(
                      responsive.isMobile
                          ? theme.spacing.md
                          : theme.spacing.lg,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Personal Referral Link',
                        style: context.uiText.bodyStrong,
                      ),
                      SizedBox(height: context.sp(theme.spacing.xxs)),
                      Text(
                        'Share this link in your discord, trading groups, or social channels:',
                        style: context.uiText.caption.copyWith(
                          color: colors.foregroundMuted,
                        ),
                      ),
                      SizedBox(height: context.sp(theme.spacing.md)),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth >= 480) {
                            return Row(
                              children: [
                                Expanded(
                                  child: UiInput(
                                    value: _referralLink,
                                    enabled: false,
                                    leadingIcon: Icons.link_rounded,
                                    onChanged: (_) {},
                                  ),
                                ),
                                SizedBox(width: context.sp(theme.spacing.md)),
                                UiButton(
                                  label: 'Copy Link',
                                  leadingIcon: Icons.copy_rounded,
                                  variant: UiVariant.primary,
                                  intent: UiIntent.warning,
                                  onPressed: _copyReferralLink,
                                ),
                              ],
                            );
                          } else {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                UiInput(
                                  value: _referralLink,
                                  enabled: false,
                                  leadingIcon: Icons.link_rounded,
                                  onChanged: (_) {},
                                ),
                                SizedBox(height: context.sp(theme.spacing.sm)),
                                UiButton(
                                  label: 'Copy Link',
                                  leadingIcon: Icons.copy_rounded,
                                  variant: UiVariant.primary,
                                  intent: UiIntent.warning,
                                  onPressed: _copyReferralLink,
                                ),
                              ],
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: context.sp(theme.spacing.xl)),

              // 4 Key Benefits Grid
              Text('Affiliate Partner Benefits', style: context.uiText.heading),
              SizedBox(height: context.sp(theme.spacing.md)),

              LayoutBuilder(
                builder: (context, constraints) {
                  final cards = [
                    _buildBenefitCard(
                      context,
                      theme,
                      colors,
                      icon: Icons.all_inclusive_rounded,
                      title: '30% Lifetime RevShare',
                      description:
                          'Earn 30% of every subscription payment every month as long as the referred trader stays active.',
                      badge: 'RECURRING',
                    ),
                    _buildBenefitCard(
                      context,
                      theme,
                      colors,
                      icon: Icons.card_membership_rounded,
                      title: 'Free TradeX Pro Tier',
                      description:
                          'Refer just 3 active traders to automatically waive your own TradeX Pro monthly subscription fees.',
                      badge: 'FREE PRO',
                    ),
                    _buildBenefitCard(
                      context,
                      theme,
                      colors,
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Automated Payouts',
                      description:
                          'Receive monthly earnings directly via PayPal, Stripe Connect, or direct ACH bank wire transfer.',
                      badge: 'MONTHLY',
                    ),
                    _buildBenefitCard(
                      context,
                      theme,
                      colors,
                      icon: Icons.palette_outlined,
                      title: 'Creator Media Kit',
                      description:
                          'Get high-res TradeX badges, banners, OBS stream overlays, and custom discount promo codes.',
                      badge: 'ASSETS',
                    ),
                  ];

                  if (constraints.maxWidth >= 650) {
                    final itemW =
                        (constraints.maxWidth - context.sp(theme.spacing.md)) /
                        2;
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
                          if (i > 0)
                            SizedBox(height: context.sp(theme.spacing.md)),
                          cards[i],
                        ],
                      ],
                    );
                  }
                },
              ),

              SizedBox(height: context.sp(theme.spacing.xl)),

              // Interactive Commission Calculator Card
              UiCard(
                child: Padding(
                  padding: EdgeInsets.all(
                    context.sp(
                      responsive.isMobile
                          ? theme.spacing.md
                          : theme.spacing.lg,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: context.sp(theme.spacing.sm),
                        runSpacing: context.sp(theme.spacing.xs),
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Text(
                            'Estimated Earnings Calculator',
                            style: context.uiText.bodyStrong,
                          ),
                          UiBadge(
                            label:
                                '${_referredTraders.toInt()} Referred Traders',
                            intent: UiIntent.primary,
                          ),
                        ],
                      ),
                      SizedBox(height: context.sp(theme.spacing.md)),

                      // Slider for referred traders
                      UiSlider(
                        value: _referredTraders,
                        min: 1,
                        max: 200,
                        divisions: 199,
                        label: '${_referredTraders.toInt()} Traders',
                        onChanged: (val) =>
                            setState(() => _referredTraders = val),
                      ),

                      SizedBox(height: context.sp(theme.spacing.lg)),

                      // Earnings Display Cards
                      LayoutBuilder(
                        builder: (context, earningsConstraints) {
                          final isNarrow = earningsConstraints.maxWidth < 460;
                          final monthlyCard = Container(
                            padding: EdgeInsets.all(
                              context.sp(theme.spacing.md),
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceHover,
                              borderRadius: context.radius(theme.radii.md),
                              border: Border.all(color: colors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Monthly Recurring Revenue',
                                  style: context.uiText.caption.copyWith(
                                    color: colors.foregroundMuted,
                                  ),
                                ),
                                SizedBox(
                                  height: context.sp(theme.spacing.xxs),
                                ),
                                Text(
                                  '₹${_monthlyEarnings.toStringAsFixed(0)} / mo',
                                  style: context.uiText.heading.copyWith(
                                    color: colors.warning,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );

                          final annualCard = Container(
                            padding: EdgeInsets.all(
                              context.sp(theme.spacing.md),
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceHover,
                              borderRadius: context.radius(theme.radii.md),
                              border: Border.all(color: colors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Annual Passive Income',
                                  style: context.uiText.caption.copyWith(
                                    color: colors.foregroundMuted,
                                  ),
                                ),
                                SizedBox(
                                  height: context.sp(theme.spacing.xxs),
                                ),
                                Text(
                                  '₹${_annualEarnings.toStringAsFixed(0)} / yr',
                                  style: context.uiText.heading.copyWith(
                                    color: colors.bullish,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                monthlyCard,
                                SizedBox(height: context.sp(theme.spacing.sm)),
                                annualCard,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: monthlyCard),
                              SizedBox(width: context.sp(theme.spacing.md)),
                              Expanded(child: annualCard),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: context.sp(theme.spacing.xl)),

              // Action Callout Banner
              UiCallout(
                intent: UiIntent.warning,
                title: 'Ready to apply for the TradeX Partner Program?',
                message:
                    'Complete the four-step identity, audience, payout, and review application. Your trader account stays active while an administrator reviews it.',
                action: UiButton(
                  label: 'Start Application',
                  leadingIcon: Icons.assignment_outlined,
                  variant: UiVariant.primary,
                  intent: UiIntent.warning,
                  size: UiSize.sm,
                  onPressed: () {
                    if (widget.onUpgradeToAffiliate != null) {
                      widget.onUpgradeToAffiliate!();
                    } else {
                      UiToast.show(
                        context,
                        title: 'Application required',
                        message:
                            'Affiliate tools unlock only after administrator approval.',
                        intent: UiIntent.warning,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitCard(
    BuildContext context,
    UiTheme theme,
    UiColors colors, {
    required IconData icon,
    required String title,
    required String description,
    required String badge,
  }) {
    final responsive = context.uiRes;
    return Container(
      padding: EdgeInsets.all(
        context.sp(responsive.isMobile ? theme.spacing.sm : theme.spacing.md),
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: context.radius(theme.radii.md),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: colors.warning,
                size: context.sz(responsive.isMobile ? 18 : 22),
              ),
              UiBadge(label: badge, intent: UiIntent.warning, size: UiSize.xs),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Text(
            title,
            style: context.uiText.bodyStrong,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            description,
            style: context.uiText.caption.copyWith(
              color: colors.foregroundMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
