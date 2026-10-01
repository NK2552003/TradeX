import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/auth/models/pricing_models.dart';

/// Shared renderer: landing and pricing use the identical catalogue contract.
class PublicPricingContent extends StatelessWidget {
  const PublicPricingContent({
    super.key,
    required this.catalogue,
    required this.annual,
    required this.onAnnualChanged,
    required this.onSelect,
    this.busyPlan,
    this.showDetails = true,
  });
  final PricingCatalogueResponse catalogue;
  final bool annual;
  final ValueChanged<bool> onAnnualChanged;
  final ValueChanged<PricingPlanModel> onSelect;
  final String? busyPlan;
  final bool showDetails;
  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(catalogue.text('title'), style: context.uiText.heading),
        UiGap.v(theme.spacing.sm),
        Text(catalogue.text('description'), style: context.uiText.body),
        UiGap.v(theme.spacing.md),
        UiToggleGroup<bool>(
          options: [
            UiToggleOption(label: catalogue.text('monthly'), value: false),
            UiToggleOption(label: catalogue.text('annual'), value: true),
          ],
          value: annual,
          onChanged: onAnnualChanged,
        ),
        UiGap.v(theme.spacing.lg),
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= 1000
                ? 3
                : box.maxWidth >= 680
                ? 2
                : 1;
            final gap = context.sp(theme.spacing.md);
            final width = (box.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final plan in catalogue.plans)
                  SizedBox(
                    width: width,
                    child: UiCard(
                      accentColor: plan.highlighted
                          ? theme.colors.primary
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (plan.badgeLabel != null)
                            UiBadge(label: plan.badgeLabel!),
                          Text(plan.name, style: context.uiText.heading),
                          UiGap.v(theme.spacing.xs),
                          Text(plan.subtitle, style: context.uiText.body),
                          UiGap.v(theme.spacing.md),
                          Text(
                            plan.priceLabel(isAnnual: annual),
                            style: context.uiText.numeric,
                          ),
                          Text(
                            plan.periodLabel(isAnnual: annual),
                            style: context.uiText.caption,
                          ),
                          UiGap.v(theme.spacing.md),
                          for (final feature in plan.featuresSummary) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: context.sz(16),
                                  color: theme.colors.success,
                                ),
                                UiGap.h(theme.spacing.xs),
                                Expanded(
                                  child: Text(
                                    feature,
                                    style: context.uiText.body,
                                  ),
                                ),
                              ],
                            ),
                            UiGap.v(theme.spacing.xs),
                          ],
                          UiGap.v(theme.spacing.sm),
                          UiButton(
                            label: busyPlan == plan.id
                                ? catalogue.text('processing')
                                : plan.isCurrent
                                ? catalogue.text('current')
                                : plan.ctaLabel,
                            loading: busyPlan == plan.id,
                            expand: true,
                            onPressed: busyPlan == null
                                ? () => onSelect(plan)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        UiGap.v(theme.spacing.md),
        Text(catalogue.footerDisclaimer, style: context.uiText.caption),
        if (showDetails) ...[
          UiGap.v(theme.spacing.xl),
          Text(catalogue.text('matrix'), style: context.uiText.heading),
          for (final category in catalogue.categories) ...[
            UiGap.v(theme.spacing.md),
            UiCard(
              title: category.name,
              child: Column(
                children: [
                  for (final row in category.rows) ...[
                    UiGap.v(theme.spacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(row.title, style: context.uiText.bodyStrong),
                    ),
                    if (row.tooltip != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          row.tooltip!,
                          style: context.uiText.caption,
                        ),
                      ),
                    UiGap.v(theme.spacing.xs),
                    Wrap(
                      spacing: context.sp(theme.spacing.md),
                      runSpacing: context.sp(theme.spacing.xs),
                      children: [
                        for (final plan in catalogue.plans)
                          SizedBox(
                            width: context.sz(200),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${plan.name}: ',
                                    style: context.uiText.caption,
                                  ),
                                ),
                                if (row.valueForTier(plan.tier) is bool)
                                  Icon(
                                    row.valueForTier(plan.tier) == true
                                        ? Icons.check_rounded
                                        : Icons.remove_rounded,
                                    size: context.sz(16),
                                  )
                                else
                                  Expanded(
                                    child: Text(
                                      '${row.valueForTier(plan.tier) ?? "—"}',
                                      style: context.uiText.body,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    UiDivider(),
                  ],
                ],
              ),
            ),
          ],
          UiGap.v(theme.spacing.xl),
          Text(catalogue.text('faq'), style: context.uiText.heading),
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
    );
  }
}
