import 'package:flutter/material.dart';
import 'package:alphajournal/features/affiliate_program/models/affiliate_application_model.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';

/// Page shown to active traders highlighting the benefits of the Affiliate Partner Program.
class TraderAffiliatePerksPage extends StatefulWidget {
  const TraderAffiliatePerksPage({
    super.key,
    this.onUpgradeToAffiliate,
    this.applicationStatus,
    this.onOpenPartnerHub,
    this.onRefreshStatus,
  });
  final AffiliateApplicationStatus? applicationStatus;
  final VoidCallback? onOpenPartnerHub, onRefreshStatus;

  final VoidCallback? onUpgradeToAffiliate;

  @override
  State<TraderAffiliatePerksPage> createState() =>
      _TraderAffiliatePerksPageState();
}

class _TraderAffiliatePerksPageState extends State<TraderAffiliatePerksPage> {
  double _referredTraders = 25;
  String get _actionLabel => switch (widget.applicationStatus) {
    AffiliateApplicationStatus.approved => 'Open Partner Hub',
    AffiliateApplicationStatus.pending => 'View application status',
    AffiliateApplicationStatus.rejected => 'Revise application',
    AffiliateApplicationStatus.suspended => 'View account status',
    _ => 'Apply for Affiliate',
  };
  VoidCallback? get _action =>
      widget.applicationStatus == AffiliateApplicationStatus.approved
      ? widget.onOpenPartnerHub
      : widget.onUpgradeToAffiliate;

  static const double _starterPayoutPerUser = 10.0;
  static const double _milestonePayoutPerUser = 30.0;
  static const int _milestoneThreshold = 50;

  double get _totalCommission {
    final int users = _referredTraders.round();
    final int firstBucket = users > _milestoneThreshold
        ? _milestoneThreshold
        : users;
    final int secondBucket = users > _milestoneThreshold
        ? users - _milestoneThreshold
        : 0;
    return firstBucket * _starterPayoutPerUser +
        secondBucket * _milestonePayoutPerUser;
  }

  bool get _unlocksFreePro => _referredTraders.round() >= _milestoneThreshold;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final responsive = context.uiRes;
    final double bottomInset = responsive.isMobile
        ? (keyboardInset > 0 ? keyboardInset + 24.0 : context.uiDockInset)
        : context.sp(theme.spacing.lg);

    final double pagePad = context.sp(
      responsive.isMobile ? theme.spacing.sm : theme.spacing.lg,
    );
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        pagePad,
        MediaQuery.paddingOf(context).top + pagePad,
        pagePad,
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
                      responsive.isMobile ? theme.spacing.md : theme.spacing.lg,
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
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  runSpacing: context.sp(theme.spacing.sm),
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(
                                        context.sp(theme.spacing.sm),
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.warning.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: context.radius(
                                          theme.radii.md,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.handshake_outlined,
                                        color: colors.warning,
                                        size: context.sz(24),
                                      ),
                                    ),
                                    const UiBadge(
                                      label: '₹10 → ₹30 / USER',
                                      intent: UiIntent.warning,
                                      size: UiSize.sm,
                                    ),
                                  ],
                                ),
                                SizedBox(height: context.sp(theme.spacing.sm)),
                                Text(
                                  'AlphaJournal Partner & Affiliate Program',
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
                                      'AlphaJournal Partner & Affiliate Program',
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
                                label: '₹10 → ₹30 / USER',
                                intent: UiIntent.warning,
                                size: UiSize.sm,
                              ),
                            ],
                          );
                        },
                      ),
                      SizedBox(height: context.sp(theme.spacing.md)),
                      Text(
                        'Apply to introduce your audience to AlphaJournal. After approval, your Partner Hub provides your own referral links, campaign reporting, and payouts. Qualifying commissions follow your partner account terms.',
                        style: context.uiText.body.copyWith(
                          color: colors.foregroundMuted,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: context.sp(theme.spacing.md)),
                      Wrap(
                        spacing: context.sp(theme.spacing.sm),
                        runSpacing: context.sp(theme.spacing.xs),
                        children: [
                          UiButton(
                            label: _actionLabel,
                            leadingIcon: Icons.assignment_outlined,
                            variant: UiVariant.primary,
                            intent: UiIntent.warning,
                            size: UiSize.sm,
                            onPressed: () {
                              if (_action != null) {
                                _action!();
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
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: context.sp(theme.spacing.xl)),

              UiCallout(
                title: switch (widget.applicationStatus) {
                  AffiliateApplicationStatus.approved =>
                    'Your partner access is approved',
                  AffiliateApplicationStatus.pending =>
                    'Your application is in review',
                  AffiliateApplicationStatus.rejected =>
                    'Your application needs changes',
                  AffiliateApplicationStatus.suspended =>
                    'Partner access is suspended',
                  _ => 'Referral links unlock after approval',
                },
                message:
                    widget.applicationStatus ==
                        AffiliateApplicationStatus.approved
                    ? 'Open Partner Hub to copy the link issued to your account and review your results.'
                    : 'Your trader account remains available. Review your application status here; referral links are issued only after approval.',
                action: widget.onRefreshStatus == null
                    ? null
                    : UiButton(
                        label: 'Refresh status',
                        variant: UiVariant.outline,
                        onPressed: widget.onRefreshStatus,
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
                      icon: Icons.currency_rupee_rounded,
                      title: '₹10 First 50 · ₹30 After 50',
                      description:
                          'Earn ₹10 INR per verified paid Basic or Pro user for your first 50 conversions, then ₹30 INR per paid user from #51 onward.',
                      badge: 'TIERED INR',
                    ),
                    _buildBenefitCard(
                      context,
                      theme,
                      colors,
                      icon: Icons.card_membership_rounded,
                      title: 'Free Pro at 50 Paid Users',
                      description:
                          'No complimentary Pro on signup. Complimentary AlphaJournal Pro unlocks automatically once 50 distinct referred users pay for Basic or Pro.',
                      badge: '50+ MILESTONE',
                    ),
                    _buildBenefitCard(
                      context,
                      theme,
                      colors,
                      icon: Icons.local_offer_outlined,
                      title: 'Month 1 Audience Offer',
                      description:
                          'Your audience gets Month 1 at ₹239 (Basic) or ₹399 (Pro) on monthly plans, then regular ₹299/₹499 renewal (1 per user; affiliates cannot use coupons).',
                      badge: 'MONTH 1 OFFER',
                    ),
                    _buildBenefitCard(
                      context,
                      theme,
                      colors,
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'NPCI UPI & Bank NEFT (₹)',
                      description:
                          'Receive INR settlements directly via NPCI UPI VPA, Bank NEFT, IMPS, or RTGS from ₹1,000 minimum threshold with 5% u/s 194H TDS compliance.',
                      badge: 'INR PAYOUTS',
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
                      responsive.isMobile ? theme.spacing.md : theme.spacing.lg,
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
                                  'Estimated Partner Payout (INR)',
                                  style: context.uiText.caption.copyWith(
                                    color: colors.foregroundMuted,
                                  ),
                                ),
                                SizedBox(height: context.sp(theme.spacing.xxs)),
                                Text(
                                  '₹${_totalCommission.toStringAsFixed(0)}',
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
                                  'Complimentary Pro Perk (50+ Paid)',
                                  style: context.uiText.caption.copyWith(
                                    color: colors.foregroundMuted,
                                  ),
                                ),
                                SizedBox(height: context.sp(theme.spacing.xxs)),
                                Text(
                                  _unlocksFreePro
                                      ? 'Unlocked (₹30/user)'
                                      : '${_milestoneThreshold - _referredTraders.round()} more to unlock',
                                  style: context.uiText.heading.copyWith(
                                    color: _unlocksFreePro
                                        ? colors.bullish
                                        : colors.foreground,
                                    fontSize: 18,
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
                title: 'Your AlphaJournal Partner Program',
                message:
                    'Complete the four-step identity, audience, payout, and review application. Your trader account stays active while an administrator reviews it.',
                action: UiButton(
                  label: _actionLabel,
                  leadingIcon: Icons.assignment_outlined,
                  variant: UiVariant.primary,
                  intent: UiIntent.warning,
                  size: UiSize.sm,
                  onPressed: () {
                    if (_action != null) {
                      _action!();
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
