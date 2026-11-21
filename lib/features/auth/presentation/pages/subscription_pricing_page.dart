import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/billing/razorpay_web_checkout.dart';
import 'package:alphajournal/core/billing/revenuecat_billing.dart';
import 'package:alphajournal/core/config/app_constants.dart';
import 'package:alphajournal/core/config/env_config.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/core/data/app_session.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/auth/data/repositories/subscription_pricing_repository.dart';
import 'package:alphajournal/features/auth/models/pricing_models.dart';
import 'package:alphajournal/features/public_site/presentation/public_pricing_content.dart';
import 'package:alphajournal/features/settings/data/repositories/billing_settings_repository.dart';
import 'package:alphajournal/features/settings/presentation/widgets/referral_code_prompt_dialog.dart';

class SubscriptionPricingPage extends StatefulWidget {
  const SubscriptionPricingPage({
    super.key,
    required this.onContinue,
    this.onBack,
    this.onSelectPlan,
    this.onRequireAuth,
    this.repository,
    this.isPostSignup = true,
  });
  final VoidCallback onContinue;
  final VoidCallback? onBack;
  final void Function(PricingPlanModel plan, bool isAnnual)? onSelectPlan;
  final void Function(PricingPlanModel plan, bool isAnnual)? onRequireAuth;
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

  bool get _isSignedIn => SupabaseConfig.isConfigured
      ? SupabaseConfig.client?.auth.currentUser != null
      : widget.isPostSignup;

  bool get _isNativeMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String _toHexColor(Color c) {
    final int r = (c.r * 255).round().clamp(0, 255);
    final int g = (c.g * 255).round().clamp(0, 255);
    final int b = (c.b * 255).round().clamp(0, 255);
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

  Future<void> _select(PricingPlanModel plan) async {
    if (!_isSignedIn) {
      if (widget.onRequireAuth != null) {
        widget.onRequireAuth!(plan, _annual);
      } else {
        widget.onBack?.call();
      }
      return;
    }

    setState(() => _busy = plan.id);
    try {
      final cycle = _annual ? 'annual' : 'monthly';
      if (plan.tier != AppTier.free &&
          !plan.isCurrent &&
          SupabaseConfig.isConfigured &&
          SupabaseConfig.client?.auth.currentUser != null) {
        if (_isNativeMobile && !RevenueCatBilling.isConfigured) {
          final Uri webBillingUri = Uri.parse(
            '${AppConstants.appSubdomainUrl}/settings_billing',
          ).replace(
            queryParameters: <String, String>{'plan': plan.id, 'cycle': cycle},
          );
          bool opened = false;
          try {
            opened = await launchUrl(
              webBillingUri,
              mode: LaunchMode.inAppBrowserView,
            );
          } catch (_) {
            opened = false;
          }
          if (!opened) {
            opened = await launchUrl(
              webBillingUri,
              mode: LaunchMode.externalApplication,
            );
          }
          if (!opened) {
            throw StateError('Could not open ${AppConstants.appSubdomainUrl}.');
          }
          if (!mounted) return;
          UiToast.show(
            context,
            title: 'Opened AlphaJournal Web',
            message:
                'Complete your upgrade on the website; your account updates automatically.',
            intent: UiIntent.info,
          );
          return;
        }

        final billingRepo = BillingSettingsRepositoryImpl();
        final double listInr = _annual
            ? plan.annualMonthlyAmount * 12
            : plan.monthlyAmount;
        final refChoice = await showReferralCodePromptDialog(
          context,
          billingRepository: billingRepo,
          tierId: plan.id,
          planName: plan.name,
          billingCycle: cycle,
          listAmountInr: listInr,
          currentTier: AppSession.instance.tier.value,
        );
        if (refChoice == null || !mounted) return;
        final session = await billingRepo.startCheckout(
          plan.id,
          cycle,
          referralCode: refChoice.referralCode,
        );
        if (!mounted) return;
        final keyId = (session.keyId != null && session.keyId!.isNotEmpty)
            ? session.keyId!
            : EnvConfig.razorpayKeyId;

        if (RazorpayWebCheckout.isSupported && keyId.isNotEmpty) {
          final UiTheme uiTheme = context.ui;
          final bool isDark = uiTheme.brightness == Brightness.dark;
          final modalResult = await RazorpayWebCheckout.open(
            keyId: keyId,
            subscriptionId: session.sessionId,
            planName: plan.name,
            billingCycle: cycle,
            userEmail: SupabaseConfig.client?.auth.currentUser?.email,
            isDark: isDark,
            themeColor: _toHexColor(
              isDark ? uiTheme.colors.surface : uiTheme.colors.primary,
            ),
            backdropColor: _toHexColor(uiTheme.colors.background),
            surfaceColor: _toHexColor(uiTheme.colors.surface),
            foregroundColor: _toHexColor(uiTheme.colors.foreground),
            borderColor: _toHexColor(uiTheme.colors.borderStrong),
            imageUrl: '${AppConstants.appSubdomainUrl}/icons/Icon-192.png',
          );
          if (!mounted) return;
          if (modalResult.isSuccess) {
            await billingRepo.verifyCheckout(
              subscriptionId: modalResult.subscriptionId ?? session.sessionId,
              paymentId: modalResult.paymentId,
              signature: modalResult.signature,
            );
            if (!mounted) return;
            widget.onSelectPlan?.call(plan, _annual);
            widget.onContinue();
            return;
          }
          if (modalResult.isFailed) {
            UiToast.show(
              context,
              title: 'Payment failed',
              message:
                  modalResult.errorMessage ??
                  'Payment could not be completed. Returned to AlphaJournal.',
              intent: UiIntent.danger,
            );
            return;
          }
          if (modalResult.isCancelled) {
            UiToast.show(
              context,
              title: 'Checkout cancelled',
              message: 'Returned to AlphaJournal without charging your account.',
              intent: UiIntent.info,
            );
            return;
          }
        }

        if (!await launchUrl(
          Uri.parse(session.url),
          mode: LaunchMode.inAppBrowserView,
        )) {
          if (!await launchUrl(
            Uri.parse(session.url),
            mode: LaunchMode.externalApplication,
          )) {
            throw StateError('Could not open Razorpay checkout.');
          }
        }
        if (!mounted) return;
        UiToast.show(
          context,
          title: 'Checkout opened',
          message: 'Your plan updates as soon as Razorpay confirms payment.',
          intent: UiIntent.info,
        );
        return;
      }
      await _repository.selectPlan(
        tierId: plan.id,
        billingCycle: cycle,
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
                      RepaintBoundary(
                        child: PublicPricingContent(
                          catalogue: catalogue,
                          annual: _annual,
                          busyPlan: _busy,
                          isAuthenticated: _isSignedIn,
                          onAnnualChanged: (value) =>
                              setState(() => _annual = value),
                          onSelect: _select,
                        ),
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
