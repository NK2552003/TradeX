import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/models/pricing_models.dart';
import 'package:tradex/features/public_site/data/public_site_repository.dart';
import 'package:tradex/features/public_site/models/public_site_content.dart';
import 'package:tradex/features/public_site/presentation/public_pricing_content.dart';

class GetStartedPage extends StatefulWidget {
  const GetStartedPage({
    super.key,
    required this.onGetStarted,
    required this.onSignIn,
    this.onViewFullPricing,
    this.repository,
  });
  final void Function(UserRole role) onGetStarted;
  final VoidCallback onSignIn;
  final VoidCallback? onViewFullPricing;
  final PublicSiteRepository? repository;
  @override
  State<GetStartedPage> createState() => _GetStartedPageState();
}

class _GetStartedPageState extends State<GetStartedPage> {
  late final PublicSiteRepository _repo =
      widget.repository ?? publicSiteRepository();
  late Future<(PublicSiteContent, PricingCatalogueResponse)> _future = _load();
  bool _annual = true;
  Future<(PublicSiteContent, PricingCatalogueResponse)> _load() async {
    final results = await Future.wait<Object>([
      _repo.landing(),
      _repo.pricing().then(PricingCatalogueResponse.fromJson),
    ]);
    return (
      results[0] as PublicSiteContent,
      results[1] as PricingCatalogueResponse,
    );
  }

  IconData _icon(String? name) => switch (name) {
    'forum' => Icons.forum_outlined,
    'book' => Icons.book_outlined,
    'news' => Icons.newspaper_outlined,
    _ => Icons.auto_awesome_outlined,
  };
  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<(PublicSiteContent, PricingCatalogueResponse)>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return UiEmptyState(
                title: 'Unable to load page content',
                actionLabel: 'Try again',
                onActionPressed: () => setState(() => _future = _load()),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: UiSkeleton(width: 240, height: 100));
            }
            final (page, catalogue) = snapshot.data!;
            return SingleChildScrollView(
              padding: EdgeInsets.all(context.sp(theme.spacing.md)),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: context.sp(theme.spacing.md),
                        children: [
                          Text(
                            page.text('brand'),
                            style: context.uiText.heading,
                          ),
                          UiButton(
                            label: page.text('signin_label'),
                            variant: UiVariant.ghost,
                            onPressed: widget.onSignIn,
                          ),
                        ],
                      ),
                      UiGap.v(theme.spacing.xl),
                      Text(page.text('title'), style: context.uiText.display),
                      UiGap.v(theme.spacing.md),
                      Text(
                        page.text('description'),
                        style: context.uiText.body,
                      ),
                      UiGap.v(theme.spacing.md),
                      Wrap(
                        spacing: context.sp(theme.spacing.sm),
                        runSpacing: context.sp(theme.spacing.sm),
                        children: [
                          UiButton(
                            label: page.text('start_label'),
                            onPressed: () =>
                                widget.onGetStarted(UserRole.customer),
                          ),
                          UiButton(
                            label: page.text('pricing_label'),
                            variant: UiVariant.outline,
                            onPressed: widget.onViewFullPricing,
                          ),
                        ],
                      ),
                      UiGap.v(theme.spacing.xl),
                      Text(
                        page.text('features_title'),
                        style: context.uiText.heading,
                      ),
                      UiGap.v(theme.spacing.md),
                      UiCardGrid(
                        intrinsicHeight: true,
                        desktopColumns: 2,
                        largeColumns: 2,
                        children: [
                          for (final feature in page.rows('features'))
                            UiCard(
                              title: feature['title'] as String,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _icon(feature['icon'] as String?),
                                    color: theme.colors.primary,
                                  ),
                                  UiGap.v(theme.spacing.sm),
                                  Text(
                                    feature['description'] as String,
                                    style: context.uiText.body,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      UiGap.v(theme.spacing.xl),
                      Text(
                        page.text('roles_title'),
                        style: context.uiText.heading,
                      ),
                      UiGap.v(theme.spacing.md),
                      UiCardGrid(
                        intrinsicHeight: true,
                        desktopColumns: 2,
                        largeColumns: 2,
                        children: [
                          for (final role in page.rows('roles'))
                            UiCard(
                              title: role['title'] as String,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    role['description'] as String,
                                    style: context.uiText.body,
                                  ),
                                  UiGap.v(theme.spacing.md),
                                  UiButton(
                                    label: role['cta'] as String,
                                    onPressed: () => widget.onGetStarted(
                                      UserRole.values.byName(
                                        role['id'] as String,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      UiGap.v(theme.spacing.xl),
                      PublicPricingContent(
                        catalogue: catalogue,
                        annual: _annual,
                        showDetails: false,
                        onAnnualChanged: (value) =>
                            setState(() => _annual = value),
                        onSelect: (_) {
                          if (widget.onViewFullPricing != null) {
                            widget.onViewFullPricing!();
                          } else {
                            widget.onGetStarted(UserRole.customer);
                          }
                        },
                      ),
                      UiGap.v(theme.spacing.xl),
                      Text(
                        page.text('faq_title'),
                        style: context.uiText.heading,
                      ),
                      UiGap.v(theme.spacing.md),
                      UiAccordion(
                        items: [
                          for (final faq in [...page.faqs, ...catalogue.faqs])
                            UiAccordionItem(
                              title: faq.question,
                              content: Text(
                                faq.answer,
                                style: context.uiText.body,
                              ),
                            ),
                        ],
                      ),
                      UiGap.v(theme.spacing.xl),
                      Text(page.text('footer'), style: context.uiText.caption),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
