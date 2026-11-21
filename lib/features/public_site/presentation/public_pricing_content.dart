import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/customer_limitations.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/auth/models/pricing_models.dart';

/// Shared renderer: landing, post-signup, and full pricing view use the
/// identical overlay-styled subscription cards, feature matrix, and FAQs.
class PublicPricingContent extends StatelessWidget {
  const PublicPricingContent({
    super.key,
    required this.catalogue,
    required this.annual,
    required this.onAnnualChanged,
    required this.onSelect,
    this.busyPlan,
    this.showDetails = true,
    this.isAuthenticated = true,
  });

  final PricingCatalogueResponse catalogue;
  final bool annual;
  final ValueChanged<bool> onAnnualChanged;
  final ValueChanged<PricingPlanModel> onSelect;
  final String? busyPlan;
  final bool showDetails;
  final bool isAuthenticated;

  List<({String heading, List<({IconData icon, String label})> items})>
  _sectionsForTier(AppTier tier) {
    final CustomerTierQuota q = CustomerTierQuota.forTier(tier);
    String formatQuota(int value, String singular, String plural) {
      if (value >= 100000) return 'Unlimited $plural';
      return '$value ${value == 1 ? singular : plural}';
    }

    return switch (tier) {
      AppTier.free => [
        (
          heading: 'Workspace & Journaling',
          items: [
            (
              icon: Icons.edit_note_rounded,
              label: formatQuota(q.maxNotes, 'note', 'notes'),
            ),
            (
              icon: Icons.candlestick_chart_rounded,
              label: formatQuota(q.maxTrades, 'trade log', 'trade logs'),
            ),
            (
              icon: Icons.track_changes_rounded,
              label: formatQuota(
                q.maxLiveStrategies,
                'live strategy',
                'live strategies',
              ),
            ),
            (
              icon: Icons.bookmark_border_rounded,
              label: formatQuota(q.maxWatchlists, 'watchlist', 'watchlists'),
            ),
            (
              icon: Icons.notifications_none_rounded,
              label: formatQuota(q.maxAlerts, 'price alert', 'price alerts'),
            ),
          ],
        ),
        (
          heading: 'Community & Markets',
          items: [
            (
              icon: Icons.forum_outlined,
              label:
                  '${q.maxCommunityPostsPerDay} posts & ${q.maxCommunityCommentsPerDay} replies / day',
            ),
            (
              icon: Icons.show_chart_rounded,
              label: 'Market previews & basic calculators',
            ),
          ],
        ),
      ],
      AppTier.premium => [
        (
          heading: 'Markets & Desk',
          items: [
            (
              icon: Icons.candlestick_chart_rounded,
              label:
                  '${formatQuota(q.maxNotes, 'note', 'notes')} & ${formatQuota(q.maxTrades, 'trade', 'trades')}',
            ),
            (
              icon: Icons.track_changes_rounded,
              label:
                  '${formatQuota(q.maxLiveStrategies, 'strategy', 'strategies')} & ${formatQuota(q.maxWatchlists, 'watchlist', 'watchlists')}',
            ),
            (
              icon: Icons.insights_rounded,
              label: 'Full Market Intelligence & screeners',
            ),
            (
              icon: Icons.calculate_outlined,
              label: 'Advanced risk & position calculators',
            ),
            (
              icon: Icons.mail_outline_rounded,
              label: 'Direct messages & trader network',
            ),
          ],
        ),
        (
          heading: 'AI & Alerts',
          items: [
            (
              icon: Icons.auto_awesome_rounded,
              label: '${q.maxAiQueriesPerMonth} AI Copilot queries / mo',
            ),
            (
              icon: Icons.notifications_active_outlined,
              label: formatQuota(q.maxAlerts, 'active alert', 'active alerts'),
            ),
            (
              icon: Icons.forum_outlined,
              label:
                  '${q.maxCommunityPostsPerDay} posts & ${q.maxCommunityCommentsPerDay} replies / day',
            ),
          ],
        ),
      ],
      AppTier.enterprise => [
        (
          heading: 'Institutional Desk',
          items: [
            (
              icon: Icons.layers_outlined,
              label:
                  '${formatQuota(q.maxNotes, 'note', 'notes')} & ${formatQuota(q.maxTrades, 'trade', 'trades')}',
            ),
            (
              icon: Icons.picture_as_pdf_outlined,
              label: 'CSV & PDF performance exports',
            ),
            (
              icon: Icons.science_outlined,
              label: 'Advanced strategy backtesting',
            ),
            (
              icon: Icons.query_stats_rounded,
              label: 'Deep expectancy & drawdown analytics',
            ),
          ],
        ),
        (
          heading: 'AI & Priority',
          items: [
            (
              icon: Icons.bolt_rounded,
              label: '${q.maxAiQueriesPerMonth} AI Copilot queries / mo',
            ),
            (
              icon: Icons.notifications_active_rounded,
              label: formatQuota(q.maxAlerts, 'active alert', 'active alerts'),
            ),
            (
              icon: Icons.verified_outlined,
              label:
                  '${q.maxCommunityPostsPerDay} posts & ${q.maxCommunityCommentsPerDay} replies / day',
            ),
          ],
        ),
      ],
    };
  }

  Widget _buildPlanCard(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    PricingPlanModel plan,
  ) {
    final bool selected = isAuthenticated && plan.isCurrent;
    final bool highlighted = plan.highlighted || plan.tier == AppTier.premium;
    final bool isBusy = busyPlan == plan.id;
    final bool isDark = theme.brightness == Brightness.dark;
    final sections = _sectionsForTier(plan.tier);
    final Color cardBg = isDark
        ? colors.surfaceMuted.withValues(alpha: 0.38)
        : colors.surface;

    final String introLine = switch (plan.tier) {
      AppTier.free => 'Our introductory plan:',
      AppTier.premium => 'Everything in Free, and:',
      AppTier.enterprise => 'Everything in Basic, and:',
    };

    final String currentText = catalogue.text('current').isNotEmpty
        ? catalogue.text('current')
        : 'Current Plan';
    final String processingText = catalogue.text('processing').isNotEmpty
        ? catalogue.text('processing')
        : 'Processing…';

    final String ctaLabel = isBusy
        ? processingText
        : selected
        ? currentText
        : !isAuthenticated
        ? (plan.tier == AppTier.free ? 'Start Free' : 'Get ${plan.name}')
        : !plan.isPurchasable
        ? plan.ctaLabel
        : (plan.tier == AppTier.free ? 'Switch to Free' : 'Get ${plan.name}');

    final String? badgeText = selected
        ? currentText
        : (highlighted
              ? 'Most popular'
              : (plan.tier == AppTier.enterprise ? 'Full desk' : null));

    final UiIntent badgeIntent = selected
        ? UiIntent.success
        : (highlighted ? UiIntent.primary : UiIntent.neutral);

    final double annualTotal = plan.annualMonthlyAmount * 12;
    final String billingCaption = plan.monthlyAmount <= 0
        ? 'Free forever · No credit card required'
        : (annual
              ? '${plan.currencySymbol}${annualTotal.toStringAsFixed(0)} billed annually · Save 20%'
              : 'Billed monthly · Cancel anytime');

    final bool canPress =
        busyPlan == null &&
        (!isAuthenticated || plan.isPurchasable || selected);

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected || highlighted
              ? (isDark
                    ? colors.surfaceMuted.withValues(alpha: 0.55)
                    : colors.surface)
              : cardBg,
          borderRadius: context.radius(theme.radii.lg),
          border: Border.all(
            color: selected
                ? colors.success.withValues(alpha: isDark ? 0.5 : 0.72)
                : (highlighted
                      ? colors.primary.withValues(alpha: isDark ? 0.45 : 0.72)
                      : colors.border),
            width: selected || highlighted ? 1.5 : theme.borders.hairline,
          ),
          boxShadow: isDark
              ? null
              : (selected || highlighted ? theme.shadows.md : theme.shadows.sm),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  plan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.heading.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
              ),
              if (badgeText != null) ...<Widget>[
                const SizedBox(width: 8),
                UiBadge(
                  label: badgeText,
                  intent: badgeIntent,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    plan.priceLabel(isAnnual: annual),
                    maxLines: 1,
                    style: context.uiText.display.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: colors.foreground,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/month',
                style: context.uiText.caption.copyWith(
                  fontSize: 12,
                  color: colors.foregroundSubtle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            billingCaption,
            style: context.uiText.caption.copyWith(
              fontSize: 11.5,
              color: annual && plan.monthlyAmount > 0
                  ? colors.bullish
                  : colors.foregroundSubtle,
              fontWeight: annual && plan.monthlyAmount > 0
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 16),
          _PublicPricingCtaButton(
            label: ctaLabel,
            selected: selected,
            highlighted: highlighted,
            onTap: canPress ? () => onSelect(plan) : null,
          ),
          const SizedBox(height: 18),
          Text(
            introLine,
            style: context.uiText.caption.copyWith(
              fontSize: 12,
              color: colors.foregroundMuted,
            ),
          ),
          const SizedBox(height: 14),
          for (int s = 0; s < sections.length; s++) ...<Widget>[
            if (s > 0) const SizedBox(height: 14),
            Text(
              sections[s].heading,
              style: context.uiText.caption.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: colors.foregroundSubtle,
              ),
            ),
            const SizedBox(height: 6),
            Divider(height: 1, thickness: 1, color: colors.border),
            const SizedBox(height: 10),
            for (final item in sections[s].items)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        item.icon,
                        size: 15,
                        color: colors.foregroundMuted,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        item.label,
                        style: context.uiText.caption.copyWith(
                          fontSize: 12.5,
                          color: colors.foreground,
                          height: 1.32,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final compact = context.uiRes.isMobile;
    final String titleText = catalogue.text('title').isNotEmpty
        ? catalogue.text('title')
        : 'One subscription. Access to everything.';
    final String descText =
        catalogue.text('description').isNotEmpty
        ? catalogue.text('description')
        : (catalogue.text('subtitle').isNotEmpty
              ? catalogue.text('subtitle')
              : 'Manage your AlphaJournal subscription tier and workspace quotas in Indian Rupees (₹) inclusive of 18% GST.');
    final String monthlyLabel = catalogue.text('monthly').isNotEmpty
        ? catalogue.text('monthly')
        : 'Monthly';
    final String annualLabel = catalogue.text('annual').isNotEmpty
        ? catalogue.text('annual')
        : (catalogue.text('billed_annually').isNotEmpty
              ? catalogue.text('billed_annually')
              : 'Billed annually');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: context.radius(theme.radii.pill),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: colors.foreground,
                ),
                const SizedBox(width: 6),
                Text(
                  'AlphaJournal',
                  style: context.uiText.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          titleText,
          textAlign: TextAlign.center,
          style: context.uiText.display.copyWith(
            fontSize: compact ? 24 : 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: colors.foreground,
          ),
        ),
        UiGap.v(theme.spacing.xs),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Text(
              descText,
              textAlign: TextAlign.center,
              style: context.uiText.body.copyWith(
                color: colors.foregroundMuted,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ),
        ),
        UiGap.v(theme.spacing.md),
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: context.radius(theme.radii.pill),
              border: Border.all(
                color: colors.borderStrong,
                width: theme.borders.hairline,
              ),
            ),
            padding: const EdgeInsets.all(3),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Semantics(
                  button: true,
                  selected: !annual,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onAnnualChanged(false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: !annual ? colors.primary : Colors.transparent,
                        borderRadius: context.radius(theme.radii.pill),
                        border: !annual
                            ? Border.all(
                                color: colors.primary,
                                width: theme.borders.hairline,
                              )
                            : null,
                        boxShadow: !annual
                            ? <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: theme.brightness == Brightness.dark
                                        ? 0.32
                                        : 0.16,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        monthlyLabel,
                        style: context.uiText.bodyStrong.copyWith(
                          fontSize: 12.5,
                          color: !annual
                              ? colors.onPrimary
                              : colors.foregroundMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  selected: annual,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onAnnualChanged(true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: annual ? colors.primary : Colors.transparent,
                        borderRadius: context.radius(theme.radii.pill),
                        border: annual
                            ? Border.all(
                                color: colors.primary,
                                width: theme.borders.hairline,
                              )
                            : null,
                        boxShadow: annual
                            ? <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: theme.brightness == Brightness.dark
                                        ? 0.32
                                        : 0.16,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            annualLabel,
                            style: context.uiText.bodyStrong.copyWith(
                              fontSize: 12.5,
                              color: annual
                                  ? colors.onPrimary
                                  : colors.foregroundMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          UiBadge(
                            label: 'Save 20%',
                            intent: UiIntent.success,
                            variant: annual
                                ? UiBadgeVariant.solid
                                : UiBadgeVariant.soft,
                            size: UiSize.xs,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        UiGap.v(theme.spacing.lg),
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= 960
                ? 3
                : box.maxWidth >= 680
                ? 2
                : 1;
            return UiCardGrid(
              equalHeight: true,
              intrinsicHeight: true,
              mobileColumns: columns,
              tabletColumns: columns,
              desktopColumns: columns,
              largeColumns: columns,
              children: [
                for (final plan in catalogue.plans)
                  _buildPlanCard(context, theme, colors, plan),
              ],
            );
          },
        ),
        UiGap.v(theme.spacing.md),
        Text(
          catalogue.footerDisclaimer.isNotEmpty
              ? catalogue.footerDisclaimer
              : 'Prices shown in INR inclusive of 18% GST. Cancel or change your plan anytime from Settings → Billing.',
          textAlign: TextAlign.center,
          style: context.uiText.caption.copyWith(
            color: colors.foregroundSubtle,
          ),
        ),
        if (showDetails) ...[
          UiGap.v(theme.spacing.xl),
          Text(
            catalogue.text('matrix').isNotEmpty
                ? catalogue.text('matrix')
                : 'Compare features across plans',
            textAlign: TextAlign.center,
            style: context.uiText.heading.copyWith(fontSize: compact ? 20 : 24),
          ),
          for (final category in catalogue.categories) ...[
            UiGap.v(theme.spacing.md),
            UiDeferred(
              estimatedHeight: 400,
              builder: (_) => UiCard(
                title: category.name,
                child: UiTable<PlanComparisonRow>(
                  stackOnMobile: true,
                  columns: [
                    UiTableColumn(
                      header: catalogue.text('feature').isNotEmpty
                          ? catalogue.text('feature')
                          : 'Feature',
                      flex: 2,
                      cell: (context, row) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(row.title, style: context.uiText.bodyStrong),
                          if (row.tooltip != null)
                            Text(row.tooltip!, style: context.uiText.caption),
                        ],
                      ),
                    ),
                    for (final plan in catalogue.plans)
                      UiTableColumn(
                        header: plan.name,
                        cell: (context, row) {
                          final value = row.valueForTier(plan.tier);
                          return value is bool
                              ? Icon(
                                  value
                                      ? Icons.check_rounded
                                      : Icons.remove_rounded,
                                  size: context.sz(18),
                                  color: value
                                      ? theme.colors.success
                                      : theme.colors.foregroundMuted,
                                )
                              : Text(
                                  '${value ?? "—"}',
                                  style: context.uiText.body,
                                );
                        },
                      ),
                  ],
                  rows: category.rows,
                ),
              ),
            ),
          ],
          if (catalogue.faqs.isNotEmpty) ...[
            UiGap.v(theme.spacing.xl),
            Text(
              catalogue.text('faq').isNotEmpty
                  ? catalogue.text('faq')
                  : 'Frequently Asked Questions',
              textAlign: TextAlign.center,
              style: context.uiText.heading.copyWith(
                fontSize: compact ? 20 : 24,
              ),
            ),
            UiGap.v(theme.spacing.md),
            UiAccordion(
              items: [
                for (final faq in catalogue.faqs)
                  UiAccordionItem(
                    title: faq.question,
                    content: Text(faq.answer, style: context.uiText.body),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _PublicPricingCtaButton extends StatefulWidget {
  const _PublicPricingCtaButton({
    required this.label,
    required this.selected,
    required this.highlighted,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  State<_PublicPricingCtaButton> createState() =>
      _PublicPricingCtaButtonState();
}

class _PublicPricingCtaButtonState extends State<_PublicPricingCtaButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool enabled = widget.onTap != null;

    final Color bgColor = widget.selected
        ? theme.colors.surfaceMuted
        : widget.highlighted
        ? (_hovered && enabled
              ? theme.colors.primaryHover
              : theme.colors.primary)
        : (_hovered && enabled
              ? theme.colors.surfaceHover
              : theme.colors.surface);

    final Color textColor = widget.selected
        ? theme.colors.foregroundSubtle
        : (widget.highlighted
              ? theme.colors.onPrimary
              : theme.colors.foreground);

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: context.radius(theme.radii.pill),
            border: widget.selected || widget.highlighted
                ? null
                : Border.all(
                    color: _hovered && enabled
                        ? theme.colors.foregroundMuted
                        : theme.colors.borderStrong,
                  ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.label,
              maxLines: 1,
              style: context.uiText.body.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
