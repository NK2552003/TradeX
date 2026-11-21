import 'package:flutter/material.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/affiliate_program/data/affiliate_attribution.dart';
import 'package:alphajournal/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/settings/data/repositories/billing_settings_repository.dart';
import 'package:alphajournal/features/settings/models/billing_models.dart';

/// Prompts a subscriber before launching Razorpay checkout:
/// asks "Do you have a referral code?", validates server-side, displays
/// Month-1 monthly savings (Basic ₹239 / Pro ₹399), and blocks affiliate
/// accounts from redeeming any referral or coupon code.
///
/// Returns `null` if the user cancelled, or a record with the validated
/// `referralCode` (which is `null` when proceeding without one).
Future<({String? referralCode})?> showReferralCodePromptDialog(
  BuildContext context, {
  required BillingSettingsRepository billingRepository,
  required String tierId,
  required String planName,
  required String billingCycle,
  required double listAmountInr,
  AppTier currentTier = AppTier.free,
}) async {
  final bool isAnnual = billingCycle == 'annual' || billingCycle == 'yearly';
  final milestone = await billingRepository.getAffiliateMilestoneStatus();
  final bool isAffiliate =
      milestone.isAffiliate ||
      SupabaseAuthBackendService.instance.currentUserProfile?.role ==
          UserRole.affiliate;
  final bool canAskReferral = !isAffiliate && currentTier == AppTier.free;

  String prefilled = '';
  if (canAskReferral) {
    final profileRef = SupabaseAuthBackendService
        .instance
        .currentUserProfile
        ?.referredByCode
        ?.trim();
    final attribution = await AffiliateAttribution.load();
    final attrCode = attribution?['code']?.toString().trim();
    prefilled = (profileRef != null && profileRef.isNotEmpty)
        ? profileRef.toUpperCase()
        : (attrCode != null && attrCode.isNotEmpty
              ? attrCode.toUpperCase()
              : '');
  }

  if (!context.mounted) return null;

  bool hasCode = canAskReferral && prefilled.isNotEmpty;
  final TextEditingController controller = TextEditingController(
    text: prefilled,
  );
  ReferralDiscountQuote? quote;
  String? errorText;
  bool validating = false;

  try {
    return await showDialog<({String? referralCode})>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext dialogCtx, StateSetter setDialogState) {
          final double discountInr =
              (quote != null && quote!.valid && quote!.appliesDiscount)
              ? quote!.discountInr
              : 0.0;
          final double dueInr = (listAmountInr - discountInr).clamp(
            0.0,
            listAmountInr,
          );
          final String? appliedCode = (quote != null && quote!.valid)
              ? (quote!.code ?? controller.text.trim().toUpperCase())
              : null;

          return UiDialog(
            title: 'Continue to $planName (${isAnnual ? 'Annual' : 'Monthly'})',
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                UiCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '$planName · ${isAnnual ? 'Annual' : 'Monthly'}',
                              style: context.uiText.bodyStrong,
                            ),
                          ),
                          Text(
                            '₹${listAmountInr.toStringAsFixed(0)}${isAnnual ? '/yr' : '/mo'}',
                            style: context.uiText.bodyStrong.copyWith(
                              color: context.ui.colors.primary,
                            ),
                          ),
                        ],
                      ),
                      if (appliedCode != null) ...<Widget>[
                        SizedBox(height: context.sp(context.ui.spacing.xs)),
                        const UiDivider(),
                        SizedBox(height: context.sp(context.ui.spacing.xs)),
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
                                  ? '-₹${discountInr.toStringAsFixed(0)}'
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
                                isAnnual
                                    ? 'Total due today'
                                    : 'Month 1 due today',
                                style: context.uiText.bodyStrong,
                              ),
                            ),
                            Text(
                              '₹${dueInr.toStringAsFixed(0)}',
                              style: context.uiText.bodyStrong,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: context.sp(context.ui.spacing.md)),
                if (isAffiliate)
                  const UiCallout(
                    title: 'Affiliate coupon restriction',
                    message:
                        'Affiliate accounts cannot redeem their own or other partners\' referral/coupon codes. Reach 50 verified paid Basic or Pro referrals to unlock complimentary Pro.',
                    intent: UiIntent.warning,
                  )
                else if (canAskReferral) ...<Widget>[
                  Text(
                    'Do you have a referral code?',
                    style: context.uiText.bodyStrong,
                  ),
                  SizedBox(height: context.sp(context.ui.spacing.xs)),
                  UiToggleGroup<bool>(
                    key: const ValueKey<String>('prompt-has-referral-toggle'),
                    size: UiSize.sm,
                    value: hasCode,
                    onChanged: (bool value) {
                      setDialogState(() {
                        hasCode = value;
                        if (!value) {
                          quote = null;
                          errorText = null;
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
                  if (hasCode) ...<Widget>[
                    SizedBox(height: context.sp(context.ui.spacing.sm)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Expanded(
                          child: UiField(
                            label: 'Referral code',
                            error: errorText,
                            helper: isAnnual
                                ? 'Annual plans already include 20% off; your partner still receives credit.'
                                : 'Month 1 becomes ₹${listAmountInr <= 300 ? '239' : '399'} (1 per account), then ₹${listAmountInr.toStringAsFixed(0)}/mo.',
                            child: UiInput(
                              key: const ValueKey<String>(
                                'prompt-referral-input',
                              ),
                              controller: controller,
                              hintText: 'PARTNER26',
                              onChanged: (_) {
                                if (errorText != null || quote != null) {
                                  setDialogState(() {
                                    errorText = null;
                                    quote = null;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        SizedBox(width: context.sp(context.ui.spacing.sm)),
                        UiButton(
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
                                  final raw = controller.text.trim();
                                  if (raw.isEmpty) {
                                    setDialogState(
                                      () => errorText =
                                          'Enter a referral code.',
                                    );
                                    return;
                                  }
                                  setDialogState(() {
                                    validating = true;
                                    errorText = null;
                                  });
                                  final res = await billingRepository
                                      .validateReferralCode(
                                        code: raw,
                                        tierId: tierId,
                                        billingCycle: isAnnual
                                            ? 'annual'
                                            : 'monthly',
                                      );
                                  if (!dialogCtx.mounted) return;
                                  setDialogState(() {
                                    validating = false;
                                    if (!res.valid) {
                                      quote = null;
                                      errorText = res.message;
                                    } else {
                                      quote = res;
                                      errorText = null;
                                    }
                                  });
                                },
                        ),
                      ],
                    ),
                    if (quote != null && quote!.valid) ...<Widget>[
                      SizedBox(height: context.sp(context.ui.spacing.sm)),
                      UiCallout(
                        title: 'Referral code verified',
                        message: quote!.message,
                        intent: UiIntent.bullish,
                      ),
                    ],
                  ],
                ] else
                  const UiCallout(
                    title: 'Seamless plan update',
                    message:
                        'Your previous Razorpay subscription (including UPI AutoPay) will be automatically cancelled once the new plan activates so you are never double-billed.',
                    intent: UiIntent.info,
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
                label: 'Proceed to Pay ₹${dueInr.toStringAsFixed(0)}',
                intent: UiIntent.primary,
                onPressed: validating
                    ? null
                    : () {
                        if (hasCode &&
                            controller.text.trim().isNotEmpty &&
                            appliedCode == null) {
                          setDialogState(() {
                            errorText =
                                'Tap Apply to verify your referral code, or select No to continue without one.';
                          });
                          return;
                        }
                        Navigator.of(
                          ctx,
                        ).pop((referralCode: hasCode ? appliedCode : null));
                      },
              ),
            ],
          );
        },
      ),
    );
  } finally {
    controller.dispose();
  }
}
