import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/settings/data/repositories/affiliate_settings_repository.dart';
import 'package:tradex/features/settings/models/affiliate_settings_model.dart';

class AffiliateSettingsPage extends StatefulWidget {
  const AffiliateSettingsPage({super.key, this.repository});

  final AffiliateSettingsRepository? repository;

  @override
  State<AffiliateSettingsPage> createState() => _AffiliateSettingsPageState();
}

class _AffiliateSettingsPageState extends State<AffiliateSettingsPage> {
  late final AffiliateSettingsRepository _repo;
  AffiliateSettingsModel? _settings;
  bool _loading = true;
  bool _saving = false;

  late final TextEditingController _slugController;
  late final TextEditingController _payoutAccountController;
  String _selectedPayoutMethod = 'upi';
  double _minThreshold = 2500.0;
  bool _autoPayout = true;

  final List<String> _payoutMethods = const <String>[
    'upi',
    'bank_neft',
    'razorpay',
  ];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? AffiliateSettingsRepositoryImpl();
    _slugController = TextEditingController();
    _payoutAccountController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _slugController.dispose();
    _payoutAccountController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final s = await _repo.getAffiliateSettings();
      if (mounted) {
        setState(() {
          _settings = s;
          _slugController.text = s.customSlug;
          _payoutAccountController.text = s.payoutAccount;
          _selectedPayoutMethod = s.payoutMethod;
          _minThreshold = s.minimumPayoutThreshold;
          _autoPayout = s.autoPayoutEnabled;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSlug() async {
    final slug = _slugController.text.trim();
    if (slug.isEmpty) return;
    setState(() => _saving = true);
    try {
      final updated = await _repo.updateCustomSlug(slug);
      if (mounted) {
        setState(() {
          _settings = updated;
          _saving = false;
        });
        UiToast.show(
          context,
          title: 'Referral Slug Updated',
          message: 'Your link is now tradex.ai/r/$slug',
          intent: UiIntent.success,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _savePayoutSettings() async {
    setState(() => _saving = true);
    try {
      final updated = await _repo.updatePayoutSettings(
        payoutMethod: _selectedPayoutMethod,
        payoutAccount: _payoutAccountController.text.trim(),
        minimumThreshold: _minThreshold,
        autoPayout: _autoPayout,
      );
      if (mounted) {
        setState(() {
          _settings = updated;
          _saving = false;
        });
        UiToast.show(
          context,
          title: 'Payout Preferences Saved',
          message:
              'Your partner payouts will be sent to ${_payoutAccountController.text.trim()}.',
          intent: UiIntent.success,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final isMobile = context.uiRes.isMobile;

    if (_loading) {
      return UiSkeleton.settingsDetail(sections: 3, rowsPerSection: 3);
    }

    final s = _settings!;
    final fullReferralUrl = 'https://tradex.ai/r/${s.customSlug}';
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double bottomInset = isMobile
        ? (keyboardInset > 0 ? keyboardInset + 24.0 : context.uiDockInset)
        : context.sp(theme.spacing.lg);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg),
        bottomInset,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Affiliate Partner Overview Card
              UiCard(
                child: Flex(
                  direction: isMobile ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.handshake_rounded,
                        size: context.sz(28),
                        color: colors.warning,
                      ),
                    ),
                    SizedBox(
                      width: isMobile ? 0 : context.sp(theme.spacing.md),
                      height: isMobile ? context.sp(theme.spacing.sm) : 0,
                    ),
                    if (isMobile)
                      _AffiliateTierSummary(settings: s)
                    else
                      Expanded(child: _AffiliateTierSummary(settings: s)),
                    SizedBox(
                      width: isMobile ? 0 : context.sp(theme.spacing.md),
                      height: isMobile ? context.sp(theme.spacing.md) : 0,
                    ),
                    SizedBox(
                      width: isMobile ? double.infinity : null,
                      child: UiButton(
                        label: 'Download Media Kit',
                        leadingIcon: Icons.download_rounded,
                        variant: UiVariant.outline,
                        size: UiSize.sm,
                        onPressed: () async {
                          await _repo.generateMarketingKitDownloadUrl();
                          if (context.mounted) {
                            UiToast.show(
                              context,
                              title: 'Media Kit Ready',
                              message:
                                  'Downloading banners, logo vector files, and promo graphics.',
                              intent: UiIntent.info,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Earnings and Referrals Stats
              LayoutBuilder(
                builder: (context, constraints) {
                  final cards = [
                    UiMetricCard(
                      label: 'Total Referrals',
                      value: '${s.totalReferrals}',
                      delta: 12.0,
                      icon: Icons.people_outline_rounded,
                    ),
                    UiMetricCard(
                      label: 'Total Earnings',
                      value: '₹${s.totalEarnings.toStringAsFixed(2)}',
                      delta: 34.5,
                      icon: Icons.currency_rupee_rounded,
                    ),
                    UiMetricCard(
                      label: 'Pending Payout',
                      value: '₹${s.pendingPayout.toStringAsFixed(2)}',
                      icon: Icons.schedule_rounded,
                    ),
                  ];

                  if (constraints.maxWidth >= 720) {
                    return Row(
                      children: [
                        Expanded(child: cards[0]),
                        SizedBox(width: context.sp(theme.spacing.md)),
                        Expanded(child: cards[1]),
                        SizedBox(width: context.sp(theme.spacing.md)),
                        Expanded(child: cards[2]),
                      ],
                    );
                  } else if (constraints.maxWidth >= 480) {
                    final itemW =
                        (constraints.maxWidth - context.sp(theme.spacing.md)) /
                        2;
                    return Wrap(
                      spacing: context.sp(theme.spacing.md),
                      runSpacing: context.sp(theme.spacing.md),
                      children: [
                        SizedBox(width: itemW, child: cards[0]),
                        SizedBox(width: itemW, child: cards[1]),
                        SizedBox(width: constraints.maxWidth, child: cards[2]),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        cards[0],
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        cards[1],
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        cards[2],
                      ],
                    );
                  }
                },
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Referral Link & Custom Slug Editor
              AppSettingsSectionBlock(
                title: 'Custom Referral Link',
                description:
                    'Share this link on your YouTube channel, Twitter/X, Discord, or newsletter.',
                children: [
                  UiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 480) {
                              return Row(
                                children: [
                                  Expanded(
                                    child: UiField(
                                      label: 'Your Referral Link',
                                      child: UiInput(
                                        value: fullReferralUrl,
                                        readOnly: true,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: context.sp(theme.spacing.sm)),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 22.0),
                                    child: UiButton(
                                      label: 'Copy Link',
                                      leadingIcon: Icons.copy_rounded,
                                      intent: UiIntent.primary,
                                      onPressed: () {
                                        UiToast.show(
                                          context,
                                          title: 'Copied!',
                                          message:
                                              'Referral link copied to clipboard.',
                                          intent: UiIntent.success,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  UiField(
                                    label: 'Your Referral Link',
                                    child: UiInput(
                                      value: fullReferralUrl,
                                      readOnly: true,
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.sm),
                                  ),
                                  UiButton(
                                    label: 'Copy Link',
                                    leadingIcon: Icons.copy_rounded,
                                    intent: UiIntent.primary,
                                    onPressed: () {
                                      UiToast.show(
                                        context,
                                        title: 'Copied!',
                                        message:
                                            'Referral link copied to clipboard.',
                                        intent: UiIntent.success,
                                      );
                                    },
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                        SizedBox(height: context.sp(theme.spacing.md)),
                        Flex(
                          direction: isMobile ? Axis.vertical : Axis.horizontal,
                          crossAxisAlignment: isMobile
                              ? CrossAxisAlignment.stretch
                              : CrossAxisAlignment.center,
                          children: [
                            if (isMobile)
                              UiField(
                                label: 'Custom Tracking Slug',
                                helper:
                                    'Custom branding slug appears after tradex.ai/r/...',
                                child: UiInput(
                                  value: _slugController.text,
                                  hintText: 'e.g. your_brand_name',
                                  onChanged: (v) => _slugController.text = v,
                                ),
                              )
                            else
                              Expanded(
                                child: UiField(
                                  label: 'Custom Tracking Slug',
                                  helper:
                                      'Custom branding slug appears after tradex.ai/r/...',
                                  child: UiInput(
                                    value: _slugController.text,
                                    hintText: 'e.g. your_brand_name',
                                    onChanged: (v) => _slugController.text = v,
                                  ),
                                ),
                              ),
                            SizedBox(
                              width: isMobile
                                  ? 0
                                  : context.sp(theme.spacing.sm),
                              height: isMobile
                                  ? context.sp(theme.spacing.sm)
                                  : 0,
                            ),
                            Padding(
                              padding: EdgeInsets.only(top: isMobile ? 0 : 10),
                              child: SizedBox(
                                width: isMobile ? double.infinity : null,
                                child: UiButton(
                                  label: 'Update Slug',
                                  variant: UiVariant.outline,
                                  loading: _saving,
                                  onPressed: _saveSlug,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Payout Preferences
              AppSettingsSectionBlock(
                title: 'Payout Method & Minimum Threshold',
                description:
                    'Configure where and when monthly affiliate commissions are transferred.',
                children: [
                  UiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        UiField(
                          label: 'Payout Method',
                          child: UiSelect<String>(
                            value: _selectedPayoutMethod,
                            options: _payoutMethods
                                .map(
                                  (m) => UiOption<String>(
                                    label: m == 'upi'
                                        ? 'UPI (Google Pay / PhonePe / Paytm)'
                                        : (m == 'bank_neft'
                                              ? 'Direct Bank Transfer (NEFT / IMPS)'
                                              : 'Razorpay / Stripe India'),
                                    value: m,
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() => _selectedPayoutMethod = val);
                            },
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        UiField(
                          label: _selectedPayoutMethod == 'upi'
                              ? 'UPI ID / VPA'
                              : (_selectedPayoutMethod == 'bank_neft'
                                    ? 'Account Number & IFSC Code'
                                    : 'Razorpay Account ID'),
                          child: UiInput(
                            value: _payoutAccountController.text,
                            hintText: _selectedPayoutMethod == 'upi'
                                ? 'yourname@okhdfcbank'
                                : 'HDFC0001234 · 50100293849281',
                            onChanged: (v) => _payoutAccountController.text = v,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.md)),
                        AppSettingCard(
                          title: 'Automatic Monthly Payouts',
                          description:
                              'Automatically disburse earnings on the 1st of every month if minimum threshold is met.',
                          icon: Icons.autorenew_rounded,
                          control: UiSwitch(
                            value: _autoPayout,
                            onChanged: (v) => setState(() => _autoPayout = v),
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: context.sp(theme.spacing.sm),
                          runSpacing: context.sp(theme.spacing.sm),
                          children: [
                            Text(
                              'Minimum Payout Threshold',
                              style: context.uiText.bodyStrong,
                            ),
                            UiBadge(
                              label: '₹${_minThreshold.toInt()} Minimum',
                              intent: UiIntent.primary,
                            ),
                          ],
                        ),
                        SizedBox(height: context.sp(theme.spacing.xs)),
                        UiSlider(
                          value: _minThreshold,
                          min: 1000.0,
                          max: 25000.0,
                          divisions: 24,
                          onChanged: (v) => setState(() => _minThreshold = v),
                        ),
                        SizedBox(height: context.sp(theme.spacing.md)),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: isMobile ? double.infinity : null,
                            child: UiButton(
                              label: 'Save Payout Settings',
                              intent: UiIntent.primary,
                              loading: _saving,
                              onPressed: _savePayoutSettings,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AffiliateTierSummary extends StatelessWidget {
  const _AffiliateTierSummary({required this.settings});

  final AffiliateSettingsModel settings;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: context.sp(theme.spacing.xs),
          runSpacing: context.sp(theme.spacing.xxs),
          children: [
            Text('Affiliate Partner Tier', style: context.uiText.bodyStrong),
            UiBadge(
              label: settings.tierName,
              intent: UiIntent.warning,
              size: UiSize.xs,
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.xxs)),
        Text(
          '${(settings.commissionRate * 100).toInt()}% Recurring Lifetime Revenue Share across all active trader subscriptions.',
          style: context.uiText.caption.copyWith(color: colors.foregroundMuted),
        ),
      ],
    );
  }
}
