import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/billing/razorpay_web_checkout.dart';
import 'package:alphajournal/core/billing/revenuecat_billing.dart';
import 'package:alphajournal/core/config/app_constants.dart';
import 'package:alphajournal/core/config/customer_limitations.dart';
import 'package:alphajournal/core/config/env_config.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/core/data/app_session.dart';
import 'package:alphajournal/features/affiliate_program/data/affiliate_attribution.dart';
import 'package:alphajournal/features/auth/data/repositories/subscription_pricing_repository.dart';
import 'package:alphajournal/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/auth/models/pricing_models.dart';
import 'package:alphajournal/features/settings/data/repositories/billing_settings_repository.dart';
import 'package:alphajournal/features/settings/models/billing_models.dart';
import 'package:alphajournal/features/settings/presentation/widgets/settings_subpage_scope.dart';

/// Redesigned Claude-styled plan changer for Settings > Billing.
///
/// Features dynamic INR pricing, animated billing cycle toggle, 3 equal-height
/// tier cards, interactive checkout dialog with referral code verification
/// (Monthly Month-1 discount: Basic ₹239, Pro ₹399), affiliate coupon ban,
/// subscription upgrade/switch flow, and a horizontally scrollable feature
/// comparison matrix on mobile.
class ChangePlanPage extends StatefulWidget {
  const ChangePlanPage({
    super.key,
    this.repository,
    this.pricingRepository,
    this.onPlanChanged,
    this.isAffiliate = false,
  });

  final BillingSettingsRepository? repository;
  final SubscriptionPricingRepository? pricingRepository;
  final ValueChanged<AppTier>? onPlanChanged;
  final bool isAffiliate;

  @override
  State<ChangePlanPage> createState() => _ChangePlanPageState();
}

class _ChangePlanPageState extends State<ChangePlanPage> {
  bool get _supportsBusinessCheckout =>
      kIsWeb ||
      {
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      }.contains(defaultTargetPlatform);
  late final BillingSettingsRepository _billingRepo;
  late final SubscriptionPricingRepository _pricingRepo;

  SubscriptionSummary? _subscription;
  PricingCatalogueResponse? _catalogue;
  bool _loading = true;
  bool _loadFailed = false;
  bool _repricing = false;
  bool _isAnnual = true;
  String? _processingTierId;
  String? _prefilledReferralCode;

  bool get _isAffiliateAccount =>
      widget.isAffiliate ||
      (_subscription?.affiliateMilestone?.isAffiliate ?? false) ||
      SupabaseAuthBackendService.instance.currentUserProfile?.role ==
          UserRole.affiliate;

  @override
  void initState() {
    super.initState();
    _billingRepo = widget.repository ?? BillingSettingsRepositoryImpl();
    _pricingRepo =
        widget.pricingRepository ?? SubscriptionPricingRepositoryImpl();
    _isAnnual = AppSession.instance.billingCycle == 'annual';
    _loadData();
    _loadPrefilledReferral();
  }

  Future<void> _loadPrefilledReferral() async {
    try {
      final profileRef = SupabaseAuthBackendService
          .instance
          .currentUserProfile
          ?.referredByCode
          ?.trim();
      final attribution = await AffiliateAttribution.load();
      final attrCode = attribution?['code']?.toString().trim();
      final resolved = (profileRef != null && profileRef.isNotEmpty)
          ? profileRef
          : (attrCode != null && attrCode.isNotEmpty ? attrCode : null);
      if (!mounted || resolved == null) return;
      setState(() => _prefilledReferralCode = resolved.toUpperCase());
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final List<Object?> results = await Future.wait<Object?>([
        _billingRepo.getSubscription(),
        _pricingRepo.getPricingCatalogue(annual: _isAnnual),
      ]);
      if (!mounted) return;
      setState(() {
        _subscription = results[0] as SubscriptionSummary?;
        _catalogue = results[1] as PricingCatalogueResponse?;
        _loading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _toggleCycle(String cycle) async {
    final bool annual = cycle == 'annual';
    if (annual == _isAnnual || _repricing) return;

    setState(() {
      _isAnnual = annual;
      _repricing = true;
    });

    try {
      final PricingCatalogueResponse res = await _pricingRepo
          .getPricingCatalogue(annual: _isAnnual);
      if (!mounted) return;
      setState(() {
        _catalogue = res;
        _repricing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _repricing = false);
    }
  }

  Future<void> _openStoreOffer() async {
    try {
      await RevenueCatBilling.presentPaywall();
      if (!mounted) return;
      await _loadData();
      if (!mounted) return;
      UiToast.show(
        context,
        title: 'Purchase status refreshed',
        message:
            'Your account access updates after the store purchase is verified.',
        intent: UiIntent.info,
      );
    } catch (e) {
      if (!mounted) return;
      UiToast.show(
        context,
        title: 'Store offer unavailable',
        message: e.toString(),
        intent: UiIntent.warning,
      );
    }
  }

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

  Future<void> _openWebsiteBilling({PricingPlanModel? plan}) async {
    final String cycle = _isAnnual ? 'annual' : 'monthly';
    final Uri webBillingUri = Uri.parse(
      '${AppConstants.appSubdomainUrl}/settings_billing',
    ).replace(
      queryParameters: plan == null
          ? null
          : <String, String>{'plan': plan.id, 'cycle': cycle},
    );
    bool launched = false;
    try {
      launched = await launchUrl(
        webBillingUri,
        mode: LaunchMode.inAppBrowserView,
      );
    } catch (_) {
      launched = false;
    }
    if (!launched) {
      launched = await launchUrl(
        webBillingUri,
        mode: LaunchMode.externalApplication,
      );
    }
    if (!launched) {
      throw StateError('Could not open ${AppConstants.appSubdomainUrl}.');
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) => UiDialog(
        title: 'Continue on AlphaJournal Web',
        content: Text(
          'Subscription checkout opens on alphajournal.in for now. After completing your upgrade on the website, tap "Refresh Plan" to sync your account.',
          style: context.uiText.body,
        ),
        actions: <Widget>[
          UiButton(
            label: 'Close',
            variant: UiVariant.outline,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          UiButton(
            label: 'Refresh Plan',
            intent: UiIntent.primary,
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _loadData();
              if (!mounted) return;
              final AppTier nextTier =
                  _subscription?.tier ?? AppSession.instance.tier.value;
              widget.onPlanChanged?.call(nextTier);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openBusinessCheckout(
    PricingPlanModel plan, {
    String? referralCode,
  }) async {
    if (_processingTierId != null) return;
    setState(() => _processingTierId = plan.id);
    final String cycle = _isAnnual ? 'annual' : 'monthly';
    try {
      // On native Android/iOS builds without store billing configured,
      // direct the user to AlphaJournal web billing instead of failing to
      // open the inline web Razorpay modal inside the APK.
      if (_isNativeMobile && !RevenueCatBilling.isConfigured) {
        await _openWebsiteBilling(plan: plan);
        return;
      }

      final session = await _billingRepo.startCheckout(
        plan.id,
        cycle,
        referralCode: _isAffiliateAccount ? null : referralCode,
      );
      if (!mounted) return;
      final String keyId = (session.keyId != null && session.keyId!.isNotEmpty)
          ? session.keyId!
          : EnvConfig.razorpayKeyId;

      if (RazorpayWebCheckout.isSupported && keyId.isNotEmpty) {
        final UiTheme uiTheme = context.ui;
        final bool isDark = uiTheme.brightness == Brightness.dark;
        final user = SupabaseConfig.client?.auth.currentUser;
        final modalResult = await RazorpayWebCheckout.open(
          keyId: keyId,
          subscriptionId: session.sessionId,
          planName: plan.name,
          billingCycle: cycle,
          userEmail: user?.email,
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
          final verified = await _billingRepo.verifyCheckout(
            subscriptionId: modalResult.subscriptionId ?? session.sessionId,
            paymentId: modalResult.paymentId,
            signature: modalResult.signature,
          );
          if (!mounted) return;
          await _loadData();
          if (!mounted) return;
          widget.onPlanChanged?.call(plan.tier);
          UiToast.show(
            context,
            title: verified ? 'Subscription Active' : 'Payment Received',
            message: verified
                ? 'You are now on AlphaJournal ${plan.name}.'
                : 'Your payment is being confirmed by Razorpay.',
            intent: UiIntent.success,
          );
          closeSettingsSubpage(context);
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
          throw StateError('Could not open the secure checkout.');
        }
      }
      if (!mounted) return;
      await _showExternalCheckoutReturnDialog(plan, session.sessionId);
    } catch (error) {
      if (!mounted) return;
      UiToast.show(
        context,
        title: 'Checkout unavailable',
        message: error.toString().replaceFirst('Bad state: ', ''),
        intent: UiIntent.warning,
      );
    } finally {
      if (mounted) setState(() => _processingTierId = null);
    }
  }

  Future<void> _showExternalCheckoutReturnDialog(
    PricingPlanModel plan,
    String subscriptionId,
  ) async {
    bool verifying = false;
    String? statusNote;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext dialogCtx, StateSetter setDialogState) =>
            UiDialog(
              title: 'Complete ${plan.name} checkout',
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  UiCallout(
                    title: 'Finish payment in your browser',
                    message:
                        'After completing or cancelling payment in Razorpay, click "Verify & Return" or "Back to Plans" below.',
                    intent: UiIntent.info,
                  ),
                  if (statusNote != null) ...<Widget>[
                    SizedBox(height: context.sp(context.ui.spacing.sm)),
                    UiCallout(
                      title: 'Payment not completed yet',
                      message: statusNote!,
                      intent: UiIntent.warning,
                    ),
                  ],
                ],
              ),
              actions: <Widget>[
                UiButton(
                  label: 'Back to Plans',
                  variant: UiVariant.outline,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                UiButton(
                  label: 'Verify & Return',
                  intent: UiIntent.primary,
                  loading: verifying,
                  onPressed: verifying
                      ? null
                      : () async {
                          setDialogState(() {
                            verifying = true;
                            statusNote = null;
                          });
                          try {
                            final verified = await _billingRepo.verifyCheckout(
                              subscriptionId: subscriptionId,
                            );
                            if (verified) {
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              if (!mounted) return;
                              await _loadData();
                              if (!mounted) return;
                              widget.onPlanChanged?.call(plan.tier);
                              UiToast.show(
                                context,
                                title: 'Subscription Active',
                                message:
                                    'You are now on AlphaJournal ${plan.name}.',
                                intent: UiIntent.success,
                              );
                              closeSettingsSubpage(context);
                              return;
                            }
                            if (dialogCtx.mounted) {
                              setDialogState(() {
                                verifying = false;
                                statusNote =
                                    'Razorpay has not reported a completed payment yet. If your payment failed or was cancelled, click "Back to Plans".';
                              });
                            }
                          } catch (err) {
                            if (dialogCtx.mounted) {
                              setDialogState(() {
                                verifying = false;
                                statusNote = err.toString().replaceFirst(
                                  'Bad state: ',
                                  '',
                                );
                              });
                            }
                          }
                        },
                ),
              ],
            ),
      ),
    );
  }

  void _showCheckoutDialog(PricingPlanModel plan) {
    final bool isAffiliate = _isAffiliateAccount;
    final AppTier currentTier =
        _subscription?.tier ?? AppSession.instance.tier.value;
    final bool isCurrent = plan.tier == currentTier;
    final bool isUpgrade = plan.tier.index > currentTier.index;
    final bool isSwitchingPaidPlan =
        currentTier != AppTier.free && plan.tier != AppTier.free;
    final bool canAskReferral = !isAffiliate && currentTier == AppTier.free;
    final String cycle = _isAnnual ? 'annual' : 'monthly';

    final String initialRef = canAskReferral
        ? (_prefilledReferralCode ?? '')
        : '';
    bool hasReferralCode = canAskReferral && initialRef.isNotEmpty;
    final TextEditingController referralController = TextEditingController(
      text: initialRef,
    );
    ReferralDiscountQuote? quote;
    String? referralError;
    bool validating = false;
    bool processing = false;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext dialogCtx, StateSetter setDialogState) {
          final double baseAmount = _isAnnual
              ? plan.annualMonthlyAmount * 12
              : plan.monthlyAmount;
          final bool payable = baseAmount > 0;
          final double discountInr =
              (quote != null && quote!.valid && quote!.appliesDiscount)
              ? quote!.discountInr
              : 0.0;
          final double due = (baseAmount - discountInr).clamp(0.0, baseAmount);
          final String? appliedCode = (quote != null && quote!.valid)
              ? (quote!.code ?? referralController.text.trim().toUpperCase())
              : null;

          final String title = isCurrent
              ? 'Switch to ${_isAnnual ? 'annual' : 'monthly'} billing'
              : (isUpgrade
                    ? 'Upgrade to ${plan.name}'
                    : (plan.tier == AppTier.free
                          ? 'Switch to Free'
                          : 'Change to ${plan.name}'));

          return UiDialog(
            title: title,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                UiCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  plan.name,
                                  style: context.uiText.bodyStrong,
                                ),
                                Text(
                                  payable
                                      ? 'Billed ${_isAnnual ? 'annually' : 'monthly'}'
                                      : 'Free forever · No credit card required',
                                  style: context.uiText.caption.copyWith(
                                    color: context.ui.colors.foregroundMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            payable
                                ? '${plan.currencySymbol}${baseAmount.toStringAsFixed(0)}${_isAnnual ? '/yr' : '/mo'}'
                                : plan.priceLabel(isAnnual: _isAnnual),
                            style: context.uiText.heading.copyWith(
                              color: context.ui.colors.primary,
                            ),
                          ),
                        ],
                      ),
                      if (payable && appliedCode != null) ...<Widget>[
                        SizedBox(height: context.sp(context.ui.spacing.sm)),
                        const UiDivider(),
                        SizedBox(height: context.sp(context.ui.spacing.sm)),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                discountInr > 0
                                    ? 'Referral $appliedCode (Month 1 only)'
                                    : 'Referral $appliedCode (Partner credited)',
                                style: context.uiText.caption,
                              ),
                            ),
                            Text(
                              discountInr > 0
                                  ? '-${plan.currencySymbol}${discountInr.toStringAsFixed(0)}'
                                  : '20% annual rate',
                              style: context.uiText.caption.copyWith(
                                color: context.ui.colors.bullish,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: context.sp(context.ui.spacing.xs)),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                _isAnnual
                                    ? 'Total due today'
                                    : 'Month 1 due today',
                                style: context.uiText.bodyStrong,
                              ),
                            ),
                            Text(
                              '${plan.currencySymbol}${due.toStringAsFixed(0)}',
                              style: context.uiText.bodyStrong,
                            ),
                          ],
                        ),
                        if (!_isAnnual && discountInr > 0) ...<Widget>[
                          SizedBox(height: context.sp(context.ui.spacing.xxs)),
                          Text(
                            'Renews at ${plan.currencySymbol}${baseAmount.toStringAsFixed(0)}/mo from Month 2 onward.',
                            style: context.uiText.caption.copyWith(
                              color: context.ui.colors.foregroundMuted,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                if (payable) ...<Widget>[
                  SizedBox(height: context.sp(context.ui.spacing.md)),
                  if (isAffiliate)
                    const UiCallout(
                      title: 'Affiliate coupon restriction',
                      message:
                          'Affiliate accounts cannot redeem their own or other partners\' referral/coupon codes. Reach 50 verified paid Basic or Pro referrals to unlock complimentary Pro automatically.',
                      intent: UiIntent.warning,
                    )
                  else if (canAskReferral) ...<Widget>[
                    Text(
                      'Do you have a referral code?',
                      style: context.uiText.bodyStrong,
                    ),
                    SizedBox(height: context.sp(context.ui.spacing.xs)),
                    UiToggleGroup<bool>(
                      key: const ValueKey<String>('checkout-has-referral-toggle'),
                      size: UiSize.sm,
                      value: hasReferralCode,
                      onChanged: (bool value) {
                        setDialogState(() {
                          hasReferralCode = value;
                          if (!value) {
                            quote = null;
                            referralError = null;
                          }
                        });
                      },
                      options: const <UiToggleOption<bool>>[
                        UiToggleOption<bool>(value: false, label: 'No'),
                        UiToggleOption<bool>(
                          value: true,
                          label: 'Yes, I have a code',
                        ),
                      ],
                    ),
                    if (hasReferralCode) ...<Widget>[
                      SizedBox(height: context.sp(context.ui.spacing.sm)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Expanded(
                            child: UiField(
                              label: 'Referral code',
                              error: referralError,
                              helper: _isAnnual
                                  ? 'Annual plans already include 20% off; your partner will still be credited.'
                                  : 'Month 1 becomes ₹${plan.tier == AppTier.premium ? '239' : '399'} (1 use per account), then ₹${baseAmount.toStringAsFixed(0)}/mo.',
                              child: UiInput(
                                key: const ValueKey<String>(
                                  'checkout-referral-input',
                                ),
                                controller: referralController,
                                hintText: 'PARTNER26',
                                onChanged: (_) {
                                  if (referralError != null || quote != null) {
                                    setDialogState(() {
                                      referralError = null;
                                      quote = null;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          SizedBox(width: context.sp(context.ui.spacing.sm)),
                          UiButton(
                            key: const ValueKey<String>(
                              'checkout-referral-apply-btn',
                            ),
                            label: appliedCode != null ? 'Applied' : 'Apply',
                            variant: appliedCode != null
                                ? UiVariant.soft
                                : UiVariant.outline,
                            intent: appliedCode != null
                                ? UiIntent.bullish
                                : UiIntent.neutral,
                            loading: validating,
                            onPressed: validating
                                ? null
                                : () async {
                                    final String raw = referralController.text
                                        .trim();
                                    if (raw.isEmpty) {
                                      setDialogState(
                                        () => referralError =
                                            'Enter a referral code.',
                                      );
                                      return;
                                    }
                                    setDialogState(() {
                                      validating = true;
                                      referralError = null;
                                    });
                                    final res = await _billingRepo
                                        .validateReferralCode(
                                          code: raw,
                                          tierId: plan.id,
                                          billingCycle: cycle,
                                        );
                                    if (!dialogCtx.mounted) return;
                                    setDialogState(() {
                                      validating = false;
                                      if (!res.valid) {
                                        quote = null;
                                        referralError = res.message;
                                      } else {
                                        quote = res;
                                        referralError = null;
                                      }
                                    });
                                  },
                          ),
                        ],
                      ),
                      if (quote != null && quote!.valid) ...<Widget>[
                        SizedBox(height: context.sp(context.ui.spacing.sm)),
                        UiCallout(
                          title: quote!.offerConfigured
                              ? 'Referral code verified'
                              : 'Referral verified (offer pending Razorpay setup)',
                          message: quote!.message,
                          intent: quote!.offerConfigured
                              ? UiIntent.bullish
                              : UiIntent.warning,
                        ),
                      ],
                    ],
                  ] else ...<Widget>[
                    const UiCallout(
                      title: 'Subscription update',
                      message:
                          'Referral discounts apply only to a user\'s first paid subscription. Your previous Razorpay mandate (including UPI AutoPay) will be automatically cancelled as soon as your new plan activates so you are never double-billed.',
                      intent: UiIntent.info,
                    ),
                  ],
                  SizedBox(height: context.sp(context.ui.spacing.md)),
                  UiCallout(
                    title: isSwitchingPaidPlan
                        ? 'Seamless Razorpay Plan Update'
                        : 'Secure Razorpay Checkout',
                    message: isSwitchingPaidPlan
                        ? 'Authorize your new ${plan.name} (${_isAnnual ? 'annual' : 'monthly'}) mandate in Razorpay. Your previous subscription is cancelled immediately upon confirmation.'
                        : 'You will authorize your ${_isAnnual ? 'annual' : 'monthly'} subscription via UPI AutoPay, credit/debit card, or NetBanking.',
                    intent: UiIntent.info,
                  ),
                ],
                SizedBox(height: context.sp(context.ui.spacing.md)),
                UiCallout(
                  title: payable ? 'Instant activation' : 'Downgrade to Free',
                  message: payable
                      ? 'Features unlock as soon as payment is confirmed. Indian 18% GST itemized transparently. Cancel anytime.'
                      : 'Renewal will stop at the end of your current paid billing cycle. Paid features remain active until then.',
                  intent: payable ? UiIntent.info : UiIntent.warning,
                ),
              ],
            ),
            actions: <Widget>[
              UiButton(
                label: 'Cancel',
                variant: UiVariant.outline,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              UiButton(
                key: const ValueKey<String>('checkout-confirm-pay-btn'),
                label: payable
                    ? 'Confirm & Pay ${plan.currencySymbol}${due.toStringAsFixed(0)}'
                    : 'Stop Renewal at Period End',
                intent: UiIntent.primary,
                loading: processing,
                onPressed: processing || validating
                    ? null
                    : () async {
                        if (payable) {
                          if (hasReferralCode &&
                              referralController.text.trim().isNotEmpty &&
                              appliedCode == null) {
                            setDialogState(() {
                              referralError =
                                  'Tap Apply to verify your referral code, or select No to continue without one.';
                            });
                            return;
                          }
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          await _openBusinessCheckout(
                            plan,
                            referralCode: hasReferralCode ? appliedCode : null,
                          );
                          return;
                        }
                        setDialogState(() => processing = true);
                        try {
                          if (currentTier != AppTier.free) {
                            await _billingRepo.cancelSubscription(
                              reason: 'Switched to Free from Change Plan',
                            );
                          } else {
                            await _pricingRepo.selectPlan(
                              tierId: plan.id,
                              billingCycle: cycle,
                            );
                          }
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (!mounted) return;
                          await _loadData();
                          if (!mounted) return;
                          widget.onPlanChanged?.call(
                            _subscription?.tier ?? plan.tier,
                          );

                          UiToast.show(
                            context,
                            title: currentTier != AppTier.free
                                ? 'Renewal Stopped'
                                : 'Plan Changed',
                            message: currentTier != AppTier.free
                                ? 'Your paid plan stays active until the end of the current period, then moves to Free.'
                                : 'You are now on AlphaJournal ${plan.name}.',
                            intent: UiIntent.success,
                          );
                          closeSettingsSubpage(context);
                        } catch (err) {
                          if (!dialogCtx.mounted) return;
                          setDialogState(() => processing = false);
                          if (!mounted) return;
                          UiToast.show(
                            context,
                            title: 'Plan update failed',
                            message: err
                                .toString()
                                .replaceFirst('Bad state: ', ''),
                            intent: UiIntent.danger,
                          );
                        }
                      },
              ),
            ],
          );
        },
      ),
    ).whenComplete(referralController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final UiResponsive responsive = context.uiRes;

    if (_loadFailed) {
      return Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.sp(theme.spacing.lg),
            MediaQuery.paddingOf(context).top + context.sp(theme.spacing.lg),
            context.sp(theme.spacing.lg),
            responsive.isMobile
                ? context.uiPageBottomInset
                : context.sp(theme.spacing.lg),
          ),
          child: UiEmptyState(
            title: 'Pricing unavailable',
            message: _isNativeMobile
                ? 'Could not load plans inside the app right now. You can manage or upgrade your subscription on the AlphaJournal website.'
                : 'The published subscription catalogue could not be loaded.',
            action: Wrap(
              alignment: WrapAlignment.center,
              spacing: context.sp(theme.spacing.sm),
              runSpacing: context.sp(theme.spacing.xs),
              children: <Widget>[
                UiButton(
                  label: 'Try again',
                  variant: UiVariant.outline,
                  onPressed: _loadData,
                ),
                if (_isNativeMobile)
                  UiButton(
                    label: 'Open Website',
                    intent: UiIntent.primary,
                    leadingIcon: Icons.open_in_new_rounded,
                    onPressed: () => _openWebsiteBilling(),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    if (_loading || _catalogue == null) {
      return Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
        child: const Center(child: UiSkeleton(width: 240, height: 100)),
      );
    }

    final PricingCatalogueResponse catalogue = _catalogue!;
    final AppTier currentTier =
        _subscription?.tier ?? AppSession.instance.tier.value;

    final double hPad = context.sp(
      responsive.isMobile ? theme.spacing.md : theme.spacing.xl,
    );
    final double vPad = context.sp(theme.spacing.lg);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        hPad,
        MediaQuery.paddingOf(context).top + vPad,
        hPad,
        responsive.isMobile ? context.uiPageBottomInset : vPad,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sz(1100)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
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
                  const SizedBox(height: 10),
                  Text(
                    'One subscription. Access to everything.',
                    textAlign: TextAlign.center,
                    style: context.uiText.display.copyWith(
                      fontSize: responsive.isMobile ? 24 : 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xs)),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: context.sz(620)),
                    child: Text(
                      'Manage your AlphaJournal subscription tier and workspace quotas in Indian Rupees (₹) inclusive of 18% GST. Switch between monthly and annual billing anytime.',
                      textAlign: TextAlign.center,
                      style: context.uiText.body.copyWith(
                        color: colors.foregroundMuted,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Billing Cycle Switcher Toggle
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted.withValues(alpha: 0.5),
                    borderRadius: context.radius(theme.radii.pill),
                    border: Border.all(
                      color: colors.border,
                      width: theme.borders.hairline,
                    ),
                  ),
                  padding: EdgeInsets.all(context.sp(theme.spacing.xxs)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _buildCyclePill(
                        context,
                        label: 'Monthly',
                        isSelected: !_isAnnual,
                        onTap: () => _toggleCycle('monthly'),
                      ),
                      _buildCyclePill(
                        context,
                        label: 'Billed annually',
                        badge: 'Save 20%',
                        isSelected: _isAnnual,
                        onTap: () => _toggleCycle('annual'),
                      ),
                    ],
                  ),
                ),
              ),

              if (_repricing) ...<Widget>[
                SizedBox(height: context.sp(theme.spacing.sm)),
                Center(
                  child: Text(
                    'Re-pricing plans…',
                    style: context.uiText.caption.copyWith(
                      color: colors.foregroundMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              SizedBox(height: context.sp(theme.spacing.xl)),

              // 3 Pricing Cards Grid (Equal Heights)
              _buildPricingCardsGrid(
                context,
                theme,
                colors,
                responsive,
                catalogue.plans,
                currentTier,
              ),
              SizedBox(height: context.sp(theme.spacing.xxxl)),

              // Comparison Table Matrix
              _buildFeatureMatrixSection(
                context,
                theme,
                colors,
                responsive,
                catalogue.categories,
                catalogue.plans,
              ),
              SizedBox(height: context.sp(theme.spacing.xl)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCyclePill(
    BuildContext context, {
    required String label,
    String? badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.md),
          vertical: context.sp(theme.spacing.xs),
        ),
        decoration: BoxDecoration(
          color: isSelected ? colors.surface : Colors.transparent,
          borderRadius: context.radius(theme.radii.pill),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: context.uiText.bodyStrong.copyWith(
                fontSize: 13,
                color: isSelected ? colors.foreground : colors.foregroundMuted,
              ),
            ),
            if (badge != null) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.xs)),
              UiBadge(
                label: badge,
                intent: UiIntent.success,
                variant: UiBadgeVariant.soft,
                size: UiSize.xs,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCardsGrid(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
    List<PricingPlanModel> plans,
    AppTier currentTier,
  ) {
    if (responsive.isMobile) {
      return Column(
        children: <Widget>[
          for (int i = 0; i < plans.length; i++) ...<Widget>[
            if (i > 0) SizedBox(height: context.sp(theme.spacing.md)),
            _buildSingleCard(
              context,
              theme,
              colors,
              plans[i],
              currentTier,
              isMobile: true,
            ),
          ],
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < plans.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: context.sp(theme.spacing.md)),
            Expanded(
              child: _buildSingleCard(
                context,
                theme,
                colors,
                plans[i],
                currentTier,
                isMobile: false,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<({String heading, List<({IconData icon, String label})> items})>
  _overlaySectionsForTier(AppTier tier) {
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

  Widget _buildSingleCard(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    PricingPlanModel plan,
    AppTier currentTier, {
    required bool isMobile,
  }) {
    final bool isCurrent = plan.tier == currentTier;
    final bool isPaidTier = plan.tier != AppTier.free;
    final bool isCycleSwitch =
        isCurrent &&
        isPaidTier &&
        _subscription != null &&
        _subscription!.isAnnual != _isAnnual;
    final bool selected = isCurrent && !isCycleSwitch;
    final bool isFeatured = plan.highlighted || plan.tier == AppTier.premium;
    final bool isProcessing = _processingTierId == plan.id;
    final sections = _overlaySectionsForTier(plan.tier);
    final Color cardBg = colors.surfaceMuted.withValues(alpha: 0.38);

    final String introLine = switch (plan.tier) {
      AppTier.free => 'Our introductory plan:',
      AppTier.premium => 'Everything in Free, and:',
      AppTier.enterprise => 'Everything in Basic, and:',
    };

    final String? badgeText = isCurrent
        ? 'Current plan'
        : (isFeatured
              ? 'Most popular'
              : (plan.tier == AppTier.enterprise ? 'Full desk' : null));

    final UiIntent badgeIntent = isCurrent
        ? UiIntent.success
        : (isFeatured ? UiIntent.primary : UiIntent.neutral);

    final bool useStoreOffer =
        RevenueCatBilling.isConfigured && plan.tier == AppTier.premium;
    final bool useRazorpayCheckout =
        isPaidTier &&
        plan.isPurchasable &&
        (_supportsBusinessCheckout || !RevenueCatBilling.isConfigured);

    final String ctaLabel = useStoreOffer
        ? 'View store offer'
        : useRazorpayCheckout
        ? (isProcessing
              ? 'Starting checkout…'
              : selected
              ? 'Current plan'
              : isCycleSwitch
              ? 'Switch to ${_isAnnual ? 'Annual' : 'Monthly'}'
              : 'Get ${plan.name}')
        : !plan.isPurchasable
        ? plan.ctaLabel
        : isProcessing
        ? 'Processing…'
        : (selected
              ? 'Current plan'
              : (plan.tier == AppTier.free
                    ? 'Switch to Free'
                    : 'Get ${plan.name}'));

    final VoidCallback? onCtaTap = selected || isProcessing
        ? null
        : useStoreOffer
        ? _openStoreOffer
        : useRazorpayCheckout
        ? () => _showCheckoutDialog(plan)
        : !plan.isPurchasable
        ? null
        : () => _showCheckoutDialog(plan);

    final String billingCaption = plan.monthlyAmount <= 0
        ? 'Free forever · No credit card required'
        : (_isAnnual
              ? '${plan.currencySymbol}${(plan.annualMonthlyAmount * 12).toStringAsFixed(0)} billed annually · Save 20%'
              : 'Billed monthly · Cancel anytime');

    return Container(
      decoration: BoxDecoration(
        color: isCurrent || isFeatured
            ? colors.surfaceMuted.withValues(alpha: 0.55)
            : cardBg,
        borderRadius: context.radius(theme.radii.lg),
        border: Border.all(
          color: isCurrent
              ? colors.success.withValues(alpha: 0.5)
              : (isFeatured
                    ? colors.primary.withValues(alpha: 0.45)
                    : colors.border),
          width: isCurrent || isFeatured ? 1.25 : theme.borders.hairline,
        ),
      ),
      padding: const EdgeInsets.all(20),
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
              Text(
                plan.priceLabel(isAnnual: _isAnnual),
                style: context.uiText.display.copyWith(
                  fontSize: 32.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/month',
                style: context.uiText.caption.copyWith(
                  color: colors.foregroundSubtle,
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            billingCaption,
            style: context.uiText.caption.copyWith(
              color: _isAnnual && plan.monthlyAmount > 0
                  ? colors.bullish
                  : colors.foregroundSubtle,
              fontWeight: _isAnnual && plan.monthlyAmount > 0
                  ? FontWeight.w600
                  : FontWeight.normal,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 16),
          _ChangePlanCtaButton(
            label: ctaLabel,
            selected: selected,
            highlighted: isFeatured,
            onTap: onCtaTap,
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
    );
  }

  Widget _buildFeatureMatrixSection(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
    UiResponsive responsive,
    List<PlanFeatureCategory> categories,
    List<PricingPlanModel> plans,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          'Compare features across plans',
          textAlign: TextAlign.center,
          style: context.uiText.display.copyWith(
            fontSize: responsive.isMobile ? 22.0 : 28.0,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        if (responsive.isMobile) ...<Widget>[
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.md),
              vertical: context.sp(theme.spacing.xs),
            ),
            decoration: BoxDecoration(
              color: colors.surfaceMuted.withValues(alpha: 0.5),
              borderRadius: context.radius(theme.radii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.swap_horiz_rounded,
                  size: context.sz(14),
                  color: colors.primary,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Text(
                  'Scroll table horizontally to view all plans',
                  style: context.uiText.caption.copyWith(
                    color: colors.foreground,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
        ],
        SizedBox(height: context.sp(theme.spacing.md)),

        // Table
        UiCard(
          variant: UiCardVariant.surface,
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: responsive.isMobile ? context.sz(680) : context.sz(920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Features & Capabilities',
                            style: context.uiText.bodyStrong.copyWith(
                              color: colors.foregroundMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              'Free',
                              style: context.uiText.bodyStrong.copyWith(
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              'Basic',
                              style: context.uiText.bodyStrong.copyWith(
                                fontSize: 13,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              'Pro',
                              style: context.uiText.bodyStrong.copyWith(
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const UiDivider(),

                  for (final PlanFeatureCategory cat in categories) ...<Widget>[
                    Container(
                      color: colors.surfaceMuted.withValues(alpha: 0.3),
                      padding: EdgeInsets.symmetric(
                        horizontal: context.sp(theme.spacing.md),
                        vertical: context.sp(theme.spacing.xs),
                      ),
                      child: Text(
                        cat.name.toUpperCase(),
                        style: context.uiText.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: colors.foregroundSubtle,
                          fontSize: 11.0,
                        ),
                      ),
                    ),
                    const UiDivider(),

                    for (final PlanComparisonRow row in cat.rows) ...<Widget>[
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.sp(theme.spacing.md),
                          vertical: context.sp(theme.spacing.sm),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              flex: 3,
                              child: Text(
                                row.title,
                                style: context.uiText.body.copyWith(
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: _renderMatrixValue(
                                  context,
                                  colors,
                                  row.freeValue,
                                  row.isBoolean,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: _renderMatrixValue(
                                  context,
                                  colors,
                                  row.proValue,
                                  row.isBoolean,
                                  isPrimary: true,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: _renderMatrixValue(
                                  context,
                                  colors,
                                  row.enterpriseValue,
                                  row.isBoolean,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const UiDivider(),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _renderMatrixValue(
    BuildContext context,
    UiColors colors,
    dynamic value,
    bool isBoolean, {
    bool isPrimary = false,
  }) {
    if (isBoolean) {
      final bool checked = value == true;
      if (checked) {
        return Icon(
          Icons.check_circle_rounded,
          size: context.sz(16),
          color: isPrimary ? colors.primary : colors.bullish,
        );
      }
      return Text(
        '—',
        style: context.uiText.body.copyWith(color: colors.foregroundSubtle),
      );
    }

    final String text = value?.toString() ?? '—';
    return Text(
      text,
      textAlign: TextAlign.center,
      style: context.uiText.caption.copyWith(
        color: isPrimary ? colors.foreground : colors.foregroundMuted,
        fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
        fontSize: 11.5,
      ),
    );
  }
}

class _ChangePlanCtaButton extends StatefulWidget {
  const _ChangePlanCtaButton({
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
  State<_ChangePlanCtaButton> createState() => _ChangePlanCtaButtonState();
}

class _ChangePlanCtaButtonState extends State<_ChangePlanCtaButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool enabled = widget.onTap != null && !widget.selected;

    final Color bgColor = widget.selected
        ? theme.colors.surfaceMuted
        : widget.highlighted
        ? (_hovered && enabled
              ? Color.lerp(
                  theme.colors.primary,
                  const Color(0xFFD6DCE8),
                  0.22,
                )!
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
        onTap: enabled ? widget.onTap : null,
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
