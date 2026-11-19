import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/auth/models/pricing_models.dart';

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
        Text(
          catalogue.text('title'),
          textAlign: TextAlign.center,
          style: context.uiText.heading.copyWith(
            fontSize: context.fs(context.uiRes.isMobile ? 28 : 40),
          ),
        ),
        UiGap.v(theme.spacing.sm),
        Text(
          catalogue.text('description'),
          textAlign: TextAlign.center,
          style: context.uiText.body.copyWith(
            color: theme.colors.foregroundMuted,
          ),
        ),
        UiGap.v(theme.spacing.md),
        Center(
          child: SizedBox(
            width: context.sz(320),
            child: UiToggleGroup<bool>(
              options: [
                UiToggleOption(label: catalogue.text('monthly'), value: false),
                UiToggleOption(label: catalogue.text('annual'), value: true),
              ],
              value: annual,
              onChanged: onAnnualChanged,
            ),
          ),
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
            return UiCardGrid(
              equalHeight: true,
              intrinsicHeight: true,
              mobileColumns: columns,
              tabletColumns: columns,
              desktopColumns: columns,
              largeColumns: columns,
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
                          SizedBox(
                            height: context.sz(24),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: plan.badgeLabel != null
                                  ? UiBadge(
                                      label: plan.badgeLabel!,
                                      intent: plan.highlighted
                                          ? UiIntent.primary
                                          : UiIntent.neutral,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                          Text(plan.name, style: context.uiText.heading),
                          UiGap.v(theme.spacing.xs),
                          Text(plan.subtitle, style: context.uiText.body),
                          UiGap.v(theme.spacing.md),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              plan.priceLabel(isAnnual: annual),
                              maxLines: 1,
                              style: context.uiText.numeric.copyWith(
                                fontSize: context.fs(36),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
                          if (columns > 1) const Spacer(),
                          UiGap.v(theme.spacing.sm),
                          UiButton(
                            label: plan.isCurrent
                                ? catalogue.text('current')
                                : !plan.isPurchasable
                                ? plan.ctaLabel
                                : busyPlan == plan.id
                                ? catalogue.text('processing')
                                : plan.ctaLabel,
                            loading: busyPlan == plan.id,
                            expand: true,
                            variant: plan.highlighted
                                ? UiVariant.solid
                                : UiVariant.outline,
                            onPressed:
                                busyPlan == null &&
                                    (plan.isPurchasable || plan.isCurrent)
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
            UiDeferred(
              estimatedHeight: 400,
              builder: (_) => UiCard(
                title: category.name,
                child: UiTable<PlanComparisonRow>(
                  stackOnMobile: true,
                  columns: [
                    UiTableColumn(
                      header: catalogue.text('feature'),
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
