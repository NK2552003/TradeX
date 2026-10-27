import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/config/app_constants.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_workspace.dart';
import 'package:tradex/features/affiliate_program/presentation/widgets/affiliate_workspace_view.dart';
import 'package:tradex/features/settings/data/repositories/affiliate_settings_repository.dart';
import 'package:tradex/features/settings/models/affiliate_settings_model.dart';

class AffiliateSettingsPage extends StatefulWidget {
  const AffiliateSettingsPage({
    super.key,
    this.repository,
    this.onNavigate,
    this.onSwitchToTraderView,
    this.onOpenPayouts,
    this.onOpenMarketing,
    this.onSwitchToTrader,
  });

  final AffiliateSettingsRepository? repository;
  final ValueChanged<String>? onNavigate;
  final VoidCallback? onSwitchToTraderView;
  final VoidCallback? onOpenPayouts;
  final VoidCallback? onOpenMarketing;
  final VoidCallback? onSwitchToTrader;

  @override
  State<AffiliateSettingsPage> createState() => _AffiliateSettingsPageState();
}

class _AffiliateSettingsPageState extends State<AffiliateSettingsPage> {
  late final AffiliateSettingsRepository _repo;
  AffiliateSettingsModel? _settings;
  bool _loading = true, _savingSlug = false, _savingPayout = false;
  String? _error;

  String _slug = '';
  String _account = '';
  String _method = 'upi';
  String _threshold = '1000';
  bool _autoPayout = false;
  String _accountHolder = '';
  String _bankName = '';
  String _accountNumber = '';
  String _ifsc = '';
  String _upiId = '';
  String _pan = '';
  String _gstin = '';
  bool _gstRegistered = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? AffiliateSettingsRepositoryImpl();
    _load();
  }

  void _apply(AffiliateSettingsModel s) {
    _settings = s;
    _slug = s.customSlug;
    _account = s.payoutAccount;
    _method = s.payoutMethod.isEmpty ? 'upi' : s.payoutMethod;
    _threshold =
        (s.minimumPayoutThreshold < 1000 ? 1000.0 : s.minimumPayoutThreshold)
            .toStringAsFixed(0);
    _autoPayout = s.autoPayoutEnabled;
    _accountHolder = s.accountHolder;
    _bankName = s.bankName;
    _accountNumber = s.accountNumber;
    _ifsc = s.ifscCode;
    _upiId = s.upiId;
    _pan = s.panNumber;
    _gstin = s.gstin;
    _gstRegistered = s.gstRegistered;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _repo.getAffiliateSettings();
      if (!mounted) return;
      setState(() {
        _apply(s);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _save(
    Future<AffiliateSettingsModel> Function() operation,
    String title, {
    required bool slug,
  }) async {
    setState(() {
      if (slug) {
        _savingSlug = true;
      } else {
        _savingPayout = true;
      }
      _error = null;
    });
    try {
      final updated = await operation();
      if (!mounted) return;
      setState(() {
        _apply(updated);
        _savingSlug = false;
        _savingPayout = false;
      });
      UiToast.show(context, title: title, intent: UiIntent.success);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingSlug = false;
        _savingPayout = false;
        _error = e.toString().replaceFirst(RegExp(r'^.*?: '), '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    if (_loading) {
      return UiSkeleton.settingsDetail(sections: 2, rowsPerSection: 3);
    }
    if (_settings == null || _settings!.referralCode.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
        child: UiEmptyState(
          icon: Icons.handshake_outlined,
          title: _error == null
              ? 'Affiliate settings unavailable'
              : 'Could not load settings',
          message:
              _error ??
              'Sign in with an active affiliate account to manage referral and INR payout preferences.',
          action: UiButton(
            label: 'Try again',
            variant: UiVariant.outline,
            onPressed: _load,
          ),
        ),
      );
    }
    final s = _settings!;
    final referralUrl =
        '${AppConstants.appUrl}/r/${_slug.trim().isEmpty ? s.referralCode : _slug.trim()}';

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.onNavigate != null ||
                  widget.onSwitchToTraderView != null ||
                  widget.onOpenPayouts != null ||
                  widget.onOpenMarketing != null ||
                  widget.onSwitchToTrader != null) ...[
                Wrap(
                  spacing: context.sp(theme.spacing.sm),
                  runSpacing: context.sp(theme.spacing.xs),
                  children: [
                    if (widget.onNavigate != null) ...[
                      UiButton(
                        label: 'Partner Hub',
                        leadingIcon: Icons.dashboard_outlined,
                        size: UiSize.xs,
                        variant: UiVariant.outline,
                        onPressed: () => widget.onNavigate!('overview'),
                      ),
                      UiButton(
                        label: 'Back to payouts',
                        leadingIcon: Icons.payments_outlined,
                        size: UiSize.xs,
                        variant: UiVariant.ghost,
                        onPressed: () => widget.onNavigate!('payouts'),
                      ),
                    ] else ...[
                      if (widget.onOpenPayouts != null)
                        UiButton(
                          label: 'Back to payouts',
                          leadingIcon: Icons.payments_outlined,
                          size: UiSize.xs,
                          variant: UiVariant.ghost,
                          onPressed: widget.onOpenPayouts,
                        ),
                      if (widget.onOpenMarketing != null)
                        UiButton(
                          label: 'Campaign Studio',
                          leadingIcon: Icons.campaign_outlined,
                          size: UiSize.xs,
                          variant: UiVariant.outline,
                          onPressed: widget.onOpenMarketing,
                        ),
                    ],
                    if (widget.onSwitchToTraderView != null ||
                        widget.onSwitchToTrader != null)
                      UiButton(
                        label: 'Trader View',
                        leadingIcon: Icons.candlestick_chart_rounded,
                        size: UiSize.xs,
                        variant: UiVariant.secondary,
                        onPressed:
                            widget.onSwitchToTraderView ??
                            widget.onSwitchToTrader,
                      ),
                  ],
                ),
                UiGap.v(theme.spacing.md),
              ],
              if (_error != null) ...[
                UiCallout(
                  title: 'Could not save settings',
                  message: _error,
                  intent: UiIntent.warning,
                ),
                UiGap.v(theme.spacing.md),
              ],
              UiCardGrid(
                minTileWidth: 210,
                children: [
                  UiMetricCard(
                    label: 'Partner Tier',
                    value: s.tierName,
                    caption:
                        '${(s.commissionRate * 100).toStringAsFixed(0)}% recurring INR share',
                    icon: Icons.workspace_premium_outlined,
                  ),
                  UiMetricCard(
                    label: 'Total Referrals',
                    value: '${s.totalReferrals}',
                    caption: 'Code: ${s.referralCode}',
                    icon: Icons.group_outlined,
                  ),
                  UiMetricCard(
                    label: 'Total Earnings (INR)',
                    value: formatInrAmount(s.totalEarnings),
                    caption: 'Available: ${formatInrAmount(s.pendingPayout)}',
                    icon: Icons.currency_rupee_rounded,
                    intent: UiIntent.bullish,
                  ),
                ],
              ),
              UiGap.v(theme.spacing.lg),

              AppSettingsSectionBlock(
                title: 'Referral Link & Custom Slug',
                description:
                    'Use a memorable custom slug for your primary referral URL. Changing a slug requires updating published links.',
                children: [
                  UiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SelectableText(referralUrl, style: context.uiText.mono),
                        UiGap.v(theme.spacing.md),
                        Wrap(
                          spacing: context.sp(theme.spacing.sm),
                          runSpacing: context.sp(theme.spacing.sm),
                          crossAxisAlignment: WrapCrossAlignment.end,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 340),
                              child: UiField(
                                label: 'Custom Slug',
                                helper:
                                    '3–40 lowercase letters, numbers, hyphens or underscores.',
                                child: UiInput(
                                  value: _slug,
                                  onChanged: (v) => setState(() => _slug = v),
                                ),
                              ),
                            ),
                            UiButton(
                              label: 'Copy Link',
                              leadingIcon: Icons.copy_rounded,
                              variant: UiVariant.outline,
                              onPressed: () => copyAffiliateText(
                                context,
                                'Referral link',
                                referralUrl,
                              ),
                            ),
                            UiButton(
                              label: 'Save Slug',
                              intent: UiIntent.primary,
                              loading: _savingSlug,
                              onPressed: () => _save(
                                () => _repo.updateCustomSlug(_slug),
                                'Referral slug saved',
                                slug: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              UiGap.v(theme.spacing.lg),

              AppSettingsSectionBlock(
                title: 'Indian Payout Rails (INR ₹), Banking & Tax Compliance',
                description:
                    'Configure NPCI UPI VPA or Indian Bank NEFT/IMPS/RTGS details, minimum INR payout threshold (min ₹1,000), PAN for 5% TDS (u/s 194H), and optional GSTIN.',
                children: [
                  UiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                          builder: (ctx, c) {
                            final methodField = UiField(
                              label: 'Indian Payout Method',
                              child: UiSelect<String>(
                                value: _method,
                                onChanged: (v) => setState(() => _method = v),
                                options: const [
                                  UiOption(
                                    value: 'upi',
                                    label: 'NPCI UPI (Instant VPA)',
                                  ),
                                  UiOption(
                                    value: 'bank_neft',
                                    label: 'Bank NEFT (Indian Account + IFSC)',
                                  ),
                                  UiOption(
                                    value: 'bank_imps',
                                    label: 'Bank IMPS (24x7 Instant)',
                                  ),
                                  UiOption(
                                    value: 'bank_rtgs',
                                    label: 'Bank RTGS (High Value ≥ ₹2L)',
                                  ),
                                  UiOption(
                                    value: 'bank_transfer',
                                    label: 'Direct Bank Transfer (INR)',
                                  ),
                                  UiOption(
                                    value: 'razorpay',
                                    label: 'RazorpayX Partner Settlement',
                                  ),
                                ],
                              ),
                            );
                            final thresholdField = UiField(
                              label: 'Minimum Payout Threshold (INR ₹)',
                              helper: 'Minimum ₹1,000 INR.',
                              child: UiInput(
                                value: _threshold,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (v) =>
                                    setState(() => _threshold = v),
                              ),
                            );
                            return c.maxWidth >= 640
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: methodField),
                                      UiGap.h(theme.spacing.md),
                                      Expanded(child: thresholdField),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      methodField,
                                      UiGap.v(theme.spacing.sm),
                                      thresholdField,
                                    ],
                                  );
                          },
                        ),
                        UiGap.v(theme.spacing.sm),
                        UiField(
                          label: _method == 'upi'
                              ? 'Primary UPI ID (VPA) / Payout Account'
                              : 'Primary Payout Account / Reference',
                          helper:
                              'Used on new INR payout requests. Open payouts retain their submitted destination.',
                          child: UiInput(
                            value: _account,
                            hintText: _method == 'upi'
                                ? 'name@okhdfcbank'
                                : '50100482910421',
                            onChanged: (v) => setState(() {
                              _account = v;
                              if (_method == 'upi') _upiId = v;
                            }),
                          ),
                        ),
                        UiGap.v(theme.spacing.sm),
                        LayoutBuilder(
                          builder: (ctx, c) {
                            final holderField = UiField(
                              label: 'Beneficiary Name (As per Bank / PAN)',
                              child: UiInput(
                                value: _accountHolder,
                                hintText: 'Nitish Kumar',
                                onChanged: (v) =>
                                    setState(() => _accountHolder = v),
                              ),
                            );
                            final bankField = UiField(
                              label: 'Indian Bank Name',
                              child: UiInput(
                                value: _bankName,
                                hintText: 'HDFC Bank / ICICI Bank / SBI',
                                onChanged: (v) => setState(() => _bankName = v),
                              ),
                            );
                            return c.maxWidth >= 640
                                ? Row(
                                    children: [
                                      Expanded(child: holderField),
                                      UiGap.h(theme.spacing.md),
                                      Expanded(child: bankField),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      holderField,
                                      UiGap.v(theme.spacing.sm),
                                      bankField,
                                    ],
                                  );
                          },
                        ),
                        UiGap.v(theme.spacing.sm),
                        LayoutBuilder(
                          builder: (ctx, c) {
                            final acctNoField = UiField(
                              label: 'Bank Account Number',
                              child: UiInput(
                                value: _accountNumber,
                                hintText: '50100482910421',
                                onChanged: (v) =>
                                    setState(() => _accountNumber = v),
                              ),
                            );
                            final ifscField = UiField(
                              label: '11-Character Bank IFSC Code',
                              helper: 'Format: ABCD0123456',
                              child: UiInput(
                                value: _ifsc,
                                hintText: 'HDFC0000240',
                                onChanged: (v) =>
                                    setState(() => _ifsc = v.toUpperCase()),
                              ),
                            );
                            return c.maxWidth >= 640
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: acctNoField),
                                      UiGap.h(theme.spacing.md),
                                      Expanded(child: ifscField),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      acctNoField,
                                      UiGap.v(theme.spacing.sm),
                                      ifscField,
                                    ],
                                  );
                          },
                        ),
                        UiGap.v(theme.spacing.sm),
                        LayoutBuilder(
                          builder: (ctx, c) {
                            final panField = UiField(
                              label: 'Indian PAN (For 5% TDS Form 16A)',
                              helper: '10-character PAN (e.g. ABCDE1234F)',
                              child: UiInput(
                                value: _pan,
                                hintText: 'ABCDE1234F',
                                onChanged: (v) =>
                                    setState(() => _pan = v.toUpperCase()),
                              ),
                            );
                            final gstField = UiField(
                              label: 'GSTIN (Optional — 18% GST Invoicing)',
                              helper:
                                  '15-character GSTIN (e.g. 27ABCDE1234F1Z5)',
                              child: UiInput(
                                value: _gstin,
                                hintText: '27ABCDE1234F1Z5',
                                onChanged: (v) => setState(() {
                                  _gstin = v.toUpperCase();
                                  _gstRegistered = _gstin.trim().isNotEmpty;
                                }),
                              ),
                            );
                            return c.maxWidth >= 640
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: panField),
                                      UiGap.h(theme.spacing.md),
                                      Expanded(child: gstField),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      panField,
                                      UiGap.v(theme.spacing.sm),
                                      gstField,
                                    ],
                                  );
                          },
                        ),
                        UiGap.v(theme.spacing.md),
                        AppSettingCard(
                          title: 'Automatic INR Payout Preference',
                          description:
                              'Automatically queue INR settlements when your unpaid balance crosses your ₹ threshold.',
                          icon: Icons.autorenew_rounded,
                          control: UiSwitch(
                            value: _autoPayout,
                            onChanged: (v) => setState(() => _autoPayout = v),
                          ),
                        ),
                        UiGap.v(theme.spacing.md),
                        Align(
                          alignment: Alignment.centerRight,
                          child: UiButton(
                            label: 'Save payout settings',
                            intent: UiIntent.primary,
                            loading: _savingPayout,
                            onPressed: () {
                              final min = double.tryParse(_threshold.trim());
                              if (min == null) {
                                setState(
                                  () => _error =
                                      'Enter a valid minimum INR payout threshold.',
                                );
                                return;
                              }
                              _save(
                                () => _repo.updatePayoutSettings(
                                  payoutMethod: _method,
                                  payoutAccount: _account,
                                  minimumThreshold: min,
                                  autoPayout: _autoPayout,
                                  accountHolder: _accountHolder,
                                  bankName: _bankName,
                                  accountNumber: _accountNumber,
                                  ifscCode: _ifsc,
                                  upiId: _upiId,
                                  panNumber: _pan,
                                  gstin: _gstin,
                                  gstRegistered: _gstRegistered,
                                ),
                                'INR Payout & Tax settings saved',
                                slug: false,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (s.terms.isNotEmpty) ...[
                UiGap.v(theme.spacing.lg),
                AppSettingsSectionBlock(
                  title:
                      'Partner Agreement & Regulatory Terms (${s.termsVersionAccepted})',
                  description:
                      'Binding INR settlement, Section 194H TDS, and SEBI/ASCI disclosure rules for alphajournal affiliates.',
                  children: [
                    UiAccordion(
                      items: [
                        for (final term in s.terms)
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
              ],
            ],
          ),
        ),
      ),
    );
  }
}
