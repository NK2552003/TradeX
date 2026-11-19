import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/auth/data/repositories/subscription_pricing_repository.dart';
import 'package:alphajournal/features/auth/models/pricing_models.dart';
import 'package:alphajournal/features/public_site/presentation/public_pricing_content.dart';

class SubscriptionPricingPage extends StatefulWidget {
  const SubscriptionPricingPage({
    super.key,
    required this.onContinue,
    this.onBack,
    this.onSelectPlan,
    this.repository,
    this.isPostSignup = true,
  });
  final VoidCallback onContinue;
  final VoidCallback? onBack;
  final void Function(PricingPlanModel plan, bool isAnnual)? onSelectPlan;
  final SubscriptionPricingRepository? repository;
  final bool isPostSignup;
  @override
  State<SubscriptionPricingPage> createState() =>
      _SubscriptionPricingPageState();
}

class _SubscriptionPricingPageState extends State<SubscriptionPricingPage> {
  late final SubscriptionPricingRepository _repository =
      widget.repository ?? SubscriptionPricingRepositoryImpl();
  late Future<PricingCatalogueResponse> _future = _repository
      .getPricingCatalogue();
  bool _annual = true;
  String? _busy;
  Future<void> _select(PricingPlanModel plan) async {
    setState(() => _busy = plan.id);
    try {
      await _repository.selectPlan(
        tierId: plan.id,
        billingCycle: _annual ? 'annual' : 'monthly',
      );
      if (!mounted) return;
      widget.onSelectPlan?.call(plan, _annual);
      widget.onContinue();
    } catch (_) {
      if (mounted) {
        UiToast.show(
          context,
          title: 'Unable to select plan',
          intent: UiIntent.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<PricingCatalogueResponse>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return UiEmptyState(
                title: 'Unable to load pricing',
                actionLabel: 'Try again',
                onActionPressed: () =>
                    setState(() => _future = _repository.getPricingCatalogue()),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: UiSkeleton(width: 240, height: 100));
            }
            final catalogue = snapshot.data!;
            return SingleChildScrollView(
              padding: EdgeInsets.all(context.sp(theme.spacing.md)),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.onBack != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: UiButton(
                            label: catalogue.text('back'),
                            leadingIcon: Icons.arrow_back,
                            variant: UiVariant.ghost,
                            onPressed: widget.onBack,
                          ),
                        ),
                      UiGap.v(theme.spacing.md),
                      PublicPricingContent(
                        catalogue: catalogue,
                        annual: _annual,
                        busyPlan: _busy,
                        onAnnualChanged: (value) =>
                            setState(() => _annual = value),
                        onSelect: _select,
                      ),
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
