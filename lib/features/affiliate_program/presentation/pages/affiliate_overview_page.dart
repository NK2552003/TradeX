import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/affiliate_program/data/affiliate_workspace_repository.dart';
import 'package:alphajournal/features/affiliate_program/models/affiliate_workspace.dart';
import 'package:alphajournal/features/affiliate_program/presentation/widgets/affiliate_workspace_view.dart';

class AffiliateOverviewPage extends StatelessWidget {
  const AffiliateOverviewPage({
    super.key,
    this.onNavigate,
    this.onSwitchToTraderView,
    this.onOpenReferrals,
    this.onOpenPayouts,
    this.onOpenMarketing,
    this.repository,
  });

  final ValueChanged<String>? onNavigate;
  final VoidCallback? onSwitchToTraderView;
  final VoidCallback? onOpenReferrals;
  final VoidCallback? onOpenPayouts;
  final VoidCallback? onOpenMarketing;
  final AffiliateWorkspaceRepository? repository;

  @override
  Widget build(BuildContext context) {
    return AffiliateWorkspaceView(
      title: 'Partner Hub (INR ₹)',
      subtitle:
          'Earn ₹10/paid user for your first 50 Basic/Pro referrals, ₹30/paid user from #51+, and unlock complimentary Pro at 50 verified paid referrals.',
      repository: repository,
      onNavigate: onNavigate,
      actions: (ctx, w, _) => [
        if (onSwitchToTraderView != null)
          UiButton(
            label: 'Trader View',
            leadingIcon: Icons.candlestick_chart_rounded,
            size: UiSize.sm,
            variant: UiVariant.secondary,
            onPressed: onSwitchToTraderView,
          ),
        if (w.referralUrl.isNotEmpty)
          UiButton(
            label: 'Copy Referral Link',
            leadingIcon: Icons.copy_rounded,
            size: UiSize.sm,
            variant: UiVariant.outline,
            onPressed: () =>
                copyAffiliateText(ctx, 'Referral link', w.referralUrl),
          ),
        UiButton(
          label: 'Request INR Payout',
          leadingIcon: Icons.account_balance_wallet_outlined,
          size: UiSize.sm,
          intent: UiIntent.primary,
          onPressed:
              onOpenPayouts ??
              (onNavigate == null ? null : () => onNavigate!('payouts')),
        ),
      ],
      builder: (context, w, reload) {
        final p = w.profile;
        final int payoutPerUser = w.currentCommissionInr.round();
        final AffiliateRecord? currentTier = w.currentTierRecord;
        final String tierTitle =
            currentTier?.text('display_name') ??
            (w.complimentaryProUnlocked
                ? 'Tier 2 · 50+ Milestone Partner'
                : 'Tier 1 · Starter Partner');

        final linkCard = UiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: context.sp(context.ui.spacing.sm),
                runSpacing: context.sp(context.ui.spacing.xs),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  UiBadge(
                    label: '$tierTitle · ₹$payoutPerUser / PAID USER',
                    intent: UiIntent.warning,
                  ),
                  UiBadge(
                    label: w.complimentaryProUnlocked
                        ? 'FREE PRO UNLOCKED (50+)'
                        : 'FREE PRO: ${w.paidReferralsCount}/${w.freeProThreshold} PAID',
                    intent: w.complimentaryProUnlocked
                        ? UiIntent.bullish
                        : UiIntent.info,
                  ),
                  UiBadge(
                    label: p.text('status', 'active').toUpperCase(),
                    intent: p.text('status') == 'active'
                        ? UiIntent.bullish
                        : UiIntent.warning,
                  ),
                  UiBadge(
                    label:
                        'TDS ${(w.tdsRate * 100).toStringAsFixed(0)}% u/s 194H',
                    intent: UiIntent.info,
                  ),
                  if (w.gstRegistered)
                    const UiBadge(
                      label: 'GSTIN VERIFIED',
                      intent: UiIntent.primary,
                    ),
                ],
              ),
              UiGap.v(context.ui.spacing.sm),
              Text('Your Primary Referral Link', style: context.uiText.heading),
              UiGap.v(context.ui.spacing.xs),
              SelectableText(
                w.referralUrl,
                style: context.uiText.mono.copyWith(
                  color: context.ui.colors.primary,
                ),
              ),
              UiGap.v(context.ui.spacing.md),
              Wrap(
                spacing: context.sp(context.ui.spacing.sm),
                runSpacing: context.sp(context.ui.spacing.xs),
                children: [
                  UiButton(
                    label: 'Copy Link',
                    leadingIcon: Icons.copy_rounded,
                    size: UiSize.sm,
                    intent: UiIntent.primary,
                    onPressed: () => copyAffiliateText(
                      context,
                      'Referral link',
                      w.referralUrl,
                    ),
                  ),
                  UiButton(
                    label: 'Campaign Studio',
                    leadingIcon: Icons.campaign_outlined,
                    size: UiSize.sm,
                    variant: UiVariant.outline,
                    onPressed:
                        onOpenMarketing ??
                        (onNavigate == null
                            ? null
                            : () => onNavigate!('marketing')),
                  ),
                  UiButton(
                    label: 'Payout & Tax Settings',
                    leadingIcon: Icons.tune_rounded,
                    size: UiSize.sm,
                    variant: UiVariant.ghost,
                    onPressed: () => onNavigate?.call('settings_affiliate'),
                  ),
                ],
              ),
            ],
          ),
        );

        final funnelCard = UiCard(
          title: 'Conversion Funnel & Tier Milestone',
          trailing: UiBadge(
            label: '${w.conversionRate.toStringAsFixed(1)}% CONV',
            intent: UiIntent.bullish,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              UiProgressBar(
                value: w.totalClicks == 0
                    ? 0
                    : (w.referrals.length / w.totalClicks).clamp(0, 1),
                label:
                    'Signups from campaign clicks (${w.referrals.length} of ${w.totalClicks})',
              ),
              UiGap.v(context.ui.spacing.sm),
              UiProgressBar(
                value: w.referrals.isEmpty
                    ? 0
                    : (w.convertedCount / w.referrals.length).clamp(0, 1),
                label:
                    'Paid INR conversions (${w.convertedCount} of ${w.referrals.length})',
              ),
              UiGap.v(context.ui.spacing.sm),
              UiProgressBar(
                value: w.progressToFreePro,
                label: w.complimentaryProUnlocked
                    ? '50+ Paid Milestone Reached (${w.paidReferralsCount}/${w.freeProThreshold}) · Earning ₹30/user & Free Pro unlocked'
                    : 'Progress to ₹30/user & Complimentary Pro (${w.paidReferralsCount} / ${w.freeProThreshold} verified paid Basic/Pro users)',
              ),
            ],
          ),
        );

        final series = [
          for (final item in w.payouts.reversed)
            UiChartPoint(
              label: item.text('created_at').split('T').first,
              values: <double>[item.number('amount')],
            ),
          if (p.number('unpaid_balance') > 0)
            UiChartPoint(
              label: 'Unpaid (₹)',
              values: <double>[p.number('unpaid_balance')],
            ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UiCardGrid(
              equalHeight: true,
              minTileWidth: 210,
              children: [
                UiMetricCard(
                  label: 'Available Balance (INR)',
                  value: w.money(p.number('unpaid_balance')),
                  caption: w.payoutAccount.isEmpty
                      ? 'Add UPI / Bank destination in settings'
                      : 'Net after 5% TDS: ${w.money(w.netPayoutFor(p.number('unpaid_balance')))}',
                  icon: Icons.account_balance_wallet_outlined,
                  intent: UiIntent.bullish,
                ),
                UiMetricCard(
                  label: 'Lifetime Earnings (INR)',
                  value: w.money(p.number('total_earnings')),
                  caption:
                      '₹$payoutPerUser / paid user · ${w.payouts.length} settlements',
                  icon: Icons.currency_rupee_rounded,
                  intent: UiIntent.primary,
                ),
                UiMetricCard(
                  label: 'Settled to Bank / UPI',
                  value: w.money(p.number('paid_earnings')),
                  caption: 'Destination: ${w.payoutMethod.toUpperCase()}',
                  icon: Icons.fact_check_outlined,
                ),
                UiMetricCard(
                  label: 'Active Referrals',
                  value:
                      '${p.count('active_referrals')} / ${p.count('total_referrals')}',
                  caption: '${w.totalClicks} tracked campaign clicks',
                  icon: Icons.people_outline_rounded,
                ),
              ],
            ),
            UiGap.v(context.ui.spacing.lg),
            LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth >= 860
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: linkCard),
                        UiGap.h(context.ui.spacing.md),
                        Expanded(flex: 5, child: funnelCard),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        linkCard,
                        UiGap.v(context.ui.spacing.md),
                        funnelCard,
                      ],
                    ),
            ),
            UiGap.v(context.ui.spacing.lg),

            // Dynamic Commission Tiers Breakdown (Loaded from repository / DB)
            if (w.tiers.isNotEmpty) ...[
              UiCard(
                title: 'Partner Commission Tiers & INR Settlement Rules',
                subtitle:
                    'Dynamic tier structure synced with Institutional Desk governance.',
                trailing: UiBadge(
                  label:
                      'MIN PAYOUT ${w.money(p.number('minimum_payout_threshold') < 1000 ? 1000 : p.number('minimum_payout_threshold'))}',
                  intent: UiIntent.primary,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    UiCardGrid(
                      equalHeight: true,
                      minTileWidth: 230,
                      children: [
                        for (final tier in w.tiers)
                          UiCard(
                            variant:
                                tier.text('tier_code') ==
                                    p.text('tier', 'starter')
                                ? UiCardVariant.accent
                                : UiCardVariant.subtle,
                            accentColor:
                                tier.text('tier_code') ==
                                    p.text('tier', 'starter')
                                ? context.ui.colors.primary
                                : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        tier.text('display_name'),
                                        style: context.uiText.bodyStrong,
                                      ),
                                    ),
                                    if (tier.text('tier_code') ==
                                        p.text('tier', 'starter'))
                                      const UiBadge(
                                        label: 'CURRENT',
                                        intent: UiIntent.bullish,
                                        size: UiSize.xs,
                                      ),
                                  ],
                                ),
                                UiGap.v(context.ui.spacing.xs),
                                Text(
                                  tier.number('payout_per_user_inr') > 0
                                      ? '₹${tier.number('payout_per_user_inr').round()} / paid user'
                                      : '${(tier.number('commission_rate') * 100).round()}% INR Share',
                                  style: context.uiText.title.copyWith(
                                    color: context.ui.colors.primary,
                                  ),
                                ),
                                Text(
                                  tier.count('min_active_referrals') >= 50
                                      ? 'Unlocks at 50+ paid Basic/Pro users · Free Pro included'
                                      : 'First 50 paid Basic/Pro users · ${tier.text('settlement_cycle')}',
                                  style: context.uiText.caption,
                                ),
                                UiGap.v(context.ui.spacing.xs),
                                for (final perk
                                    in tier.stringList('perks').take(2))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: context.sz(14),
                                          color: context.ui.colors.bullish,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            perk,
                                            style: context.uiText.caption,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              UiGap.v(context.ui.spacing.lg),
            ],

            if (series.isNotEmpty) ...[
              UiCard(
                title: 'INR Earnings & Settlement Ledger (₹)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    UiBarChart(
                      height: 210,
                      data: series,
                      series: [
                        UiChartSeries(
                          name: 'INR (₹)',
                          color: context.ui.colors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              UiGap.v(context.ui.spacing.lg),
            ],

            UiCard(
              title: 'Active Campaigns',
              trailing: UiButton(
                label: 'Manage Campaigns',
                size: UiSize.xs,
                variant: UiVariant.ghost,
                onPressed:
                    onOpenMarketing ??
                    (onNavigate == null
                        ? null
                        : () => onNavigate!('marketing')),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (w.campaigns.isEmpty)
                    const Text(
                      'No campaigns yet. Create one in Campaign Studio.',
                    )
                  else
                    UiBarList(
                      items: [
                        for (final c in w.campaigns)
                          UiBarListItem(
                            label:
                                '${c.text('name')} (${c.text('channel')} · ${c.text('status')})',
                            value: c.number('clicks'),
                            displayValue:
                                '${c.count('clicks')} clicks · ${w.money(c.number('revenue_generated_inr'))}',
                          ),
                      ],
                    ),
                ],
              ),
            ),
            UiGap.v(context.ui.spacing.lg),

            UiCard(
              padding: EdgeInsets.zero,
              headerPadding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
              title: 'Latest Referrals (INR)',
              trailing: UiButton(
                label: 'All Referrals',
                size: UiSize.xs,
                variant: UiVariant.ghost,
                onPressed:
                    onOpenReferrals ??
                    (onNavigate == null
                        ? null
                        : () => onNavigate!('referrals')),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  UiTable<AffiliateRecord>(
                    rows: w.referrals.take(5).toList(),
                    rowKey: (r) => r.id,
                    stackOnMobile: true,
                    emptyLabel: 'No referrals recorded yet.',
                    columns: [
                      UiTableColumn<AffiliateRecord>(
                        id: 'id',
                        label: 'Referral',
                        cellBuilder: (ctx, r) =>
                            Text(r.id, style: ctx.uiText.mono),
                      ),
                      UiTableColumn<AffiliateRecord>(
                        id: 'channel',
                        label: 'Channel & Plan',
                        cellBuilder: (ctx, r) => Text(
                          '${r.text('channel', 'direct').toUpperCase()} · ${r.text('plan_tier', 'pro').toUpperCase()}',
                        ),
                      ),
                      UiTableColumn<AffiliateRecord>(
                        id: 'status',
                        label: 'Status',
                        cellBuilder: (_, r) => UiBadge(
                          label: r.text('status').toUpperCase(),
                          intent: r.text('status') == 'converted'
                              ? UiIntent.bullish
                              : r.text('status') == 'pending'
                              ? UiIntent.warning
                              : UiIntent.neutral,
                        ),
                      ),
                      UiTableColumn<AffiliateRecord>(
                        id: 'bonus',
                        label: 'Gross Commission (₹)',
                        numeric: true,
                        cellBuilder: (ctx, r) => Text(
                          w.money(r.number('bonus_awarded')),
                          style: ctx.uiText.mono,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (w.terms.isNotEmpty) ...[
              UiGap.v(context.ui.spacing.lg),
              UiCard(
                title: 'Partner Terms, Indian Tax (TDS/GST) & SEBI/ASCI Rules',
                trailing: UiBadge(
                  label: p.text('terms_version_accepted', '2026.1-INR'),
                  intent: UiIntent.info,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    UiAccordion(
                      items: [
                        for (final term in w.terms)
                          UiAccordionItem(
                            title:
                                '${term.text('clause_code')} · ${term.text('title')}',
                            subtitle: term.text('summary'),
                            badge: term.flag('mandatory') ? 'MANDATORY' : null,
                            content: Text(
                              term.text('body'),
                              style: context.uiText.body,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
