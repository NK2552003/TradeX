import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/settings/data/repositories/billing_settings_repository.dart';

class ChangePlanPage extends StatefulWidget {
  const ChangePlanPage({super.key, this.repository, this.onPlanChanged});

  final BillingSettingsRepository? repository;
  final ValueChanged<AppTier>? onPlanChanged;

  @override
  State<ChangePlanPage> createState() => _ChangePlanPageState();
}

class _ChangePlanPageState extends State<ChangePlanPage> {
  late final BillingSettingsRepository _repo;
  List<AppPlan> _plans = [];
  bool _loading = true;
  String _billingCycle = 'monthly'; // 'monthly' | 'annual'

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? BillingSettingsRepositoryImpl();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.getAvailablePlans();
      if (mounted) {
        setState(() {
          _plans = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCheckoutDialog(AppPlan plan) {
    bool isProcessing = false;
    final cardController = TextEditingController();
    final expController = TextEditingController();
    final cvcController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => UiDialog(
          title: 'Upgrade to ${AppTokens.tierLabel(plan.tier)}',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTokens.tierLabel(plan.tier),
                          style: context.uiText.bodyStrong,
                        ),
                        Text(
                          'Billed $_billingCycle',
                          style: context.uiText.caption.copyWith(
                            color: context.ui.colors.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _billingCycle == 'annual'
                          ? '₹1,999/mo (₹23,988/yr)'
                          : '${plan.priceLabel}/mo',
                      style: context.uiText.heading.copyWith(
                        color: context.ui.colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.sp(context.ui.spacing.md)),
              Text(
                'Payment Details (Stripe / RevenueCat Secure)',
                style: context.uiText.caption.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: context.sp(context.ui.spacing.xs)),
              UiField(
                label: 'Card Number',
                child: UiInput(
                  hintText: '4242 •••• •••• 4242',
                  keyboardType: TextInputType.number,
                  onChanged: (v) => cardController.text = v,
                ),
              ),
              SizedBox(height: context.sp(context.ui.spacing.xs)),
              Row(
                children: [
                  Expanded(
                    child: UiField(
                      label: 'MM / YY',
                      child: UiInput(
                        hintText: '12/28',
                        onChanged: (v) => expController.text = v,
                      ),
                    ),
                  ),
                  SizedBox(width: context.sp(context.ui.spacing.sm)),
                  Expanded(
                    child: UiField(
                      label: 'CVC / CVV',
                      child: UiInput(
                        hintText: '123',
                        keyboardType: TextInputType.number,
                        onChanged: (v) => cvcController.text = v,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(context.ui.spacing.md)),
              UiCallout(
                title: 'Instant Activation',
                message:
                    'Your features will be unlocked immediately upon confirmation. Cancel anytime.',
                intent: UiIntent.info,
              ),
            ],
          ),
          actions: [
            UiButton(
              label: 'Cancel',
              variant: UiVariant.outline,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            UiButton(
              label: 'Confirm & Pay ${plan.priceLabel}',
              intent: UiIntent.primary,
              loading: isProcessing,
              onPressed: () async {
                setDialogState(() => isProcessing = true);
                try {
                  await _repo.startCheckout(plan.tier.name, _billingCycle);
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                  if (mounted) {
                    widget.onPlanChanged?.call(plan.tier);
                    UiToast.show(
                      context,
                      title: 'Upgrade Successful!',
                      message:
                          'Welcome to TradeX ${AppTokens.tierLabel(plan.tier)}.',
                      intent: UiIntent.success,
                    );
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  setDialogState(() => isProcessing = false);
                  if (mounted) {
                    UiToast.show(
                      context,
                      title: 'Payment Failed',
                      message:
                          'Could not process card payment. Please try another card.',
                      intent: UiIntent.danger,
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    if (_loading) {
      return Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
        child: Column(
          children: const [
            UiSkeleton(height: 50),
            SizedBox(height: 24),
            UiSkeleton(height: 380),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Billing cycle switch
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.surfaceHover,
                borderRadius: context.radius(theme.radii.pill),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UiButton(
                    label: 'Monthly Billing',
                    variant: _billingCycle == 'monthly'
                        ? UiVariant.primary
                        : UiVariant.ghost,
                    intent: _billingCycle == 'monthly'
                        ? UiIntent.primary
                        : UiIntent.neutral,
                    size: UiSize.xs,
                    onPressed: () => setState(() => _billingCycle = 'monthly'),
                  ),
                  UiButton(
                    label: 'Annual (Save 20%)',
                    variant: _billingCycle == 'annual'
                        ? UiVariant.primary
                        : UiVariant.ghost,
                    intent: _billingCycle == 'annual'
                        ? UiIntent.primary
                        : UiIntent.neutral,
                    size: UiSize.xs,
                    onPressed: () => setState(() => _billingCycle = 'annual'),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),

          // Plans pricing table
          AppPricingBlock(
            plans: _plans,
            title: 'Unlock Next-Gen Institutional Tools',
            onSelect: _showCheckoutDialog,
          ),
        ],
      ),
    );
  }
}
