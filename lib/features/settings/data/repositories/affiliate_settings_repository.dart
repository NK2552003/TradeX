import 'package:tradex/features/affiliate_program/data/affiliate_workspace_repository.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_workspace.dart';
import 'package:tradex/features/settings/models/affiliate_settings_model.dart';

abstract class AffiliateSettingsRepository {
  Future<AffiliateSettingsModel> getAffiliateSettings();
  Future<AffiliateSettingsModel> updateCustomSlug(String customSlug);
  Future<AffiliateSettingsModel> updatePayoutSettings({
    required String payoutMethod,
    required String payoutAccount,
    required double minimumThreshold,
    required bool autoPayout,
    String? accountHolder,
    String? accountHolderName,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? upiId,
    String? upiVpa,
    String? panNumber,
    String? gstin,
    bool? gstRegistered,
  });
}

class AffiliateSettingsRepositoryImpl implements AffiliateSettingsRepository {
  AffiliateSettingsRepositoryImpl({AffiliateWorkspaceRepository? workspace})
    : _workspace = workspace ?? AffiliateWorkspaceRepository();

  final AffiliateWorkspaceRepository _workspace;

  @override
  Future<AffiliateSettingsModel> getAffiliateSettings() async {
    final w = await _workspace.load();
    final p = w.profile;
    final tier = p.text('tier', 'standard');
    final AffiliateRecord? tierRec = w.currentTierRecord;
    final String tierDisplayName = tierRec != null
        ? tierRec.text('display_name')
        : '${tier[0].toUpperCase()}${tier.substring(1)} Partner';

    return AffiliateSettingsModel(
      currency: w.currency,
      referralCode: p.text('affiliate_code'),
      customSlug: p.text('custom_slug', p.text('affiliate_code')),
      commissionRate: p.number('commission_rate') == 0
          ? 0.25
          : p.number('commission_rate'),
      tierName: tierDisplayName,
      payoutMethod: p.text('payout_method', 'upi'),
      payoutAccount: w.rawPayoutDestination.isNotEmpty
          ? w.rawPayoutDestination
          : w.payoutAccount,
      minimumPayoutThreshold: p.number('minimum_payout_threshold') < 1000
          ? 1000
          : p.number('minimum_payout_threshold'),
      autoPayoutEnabled: p.flag('auto_payout_enabled'),
      totalReferrals: p.count('total_referrals'),
      totalEarnings: p.number('total_earnings'),
      pendingPayout: p.number('unpaid_balance'),
      accountHolder: w.accountHolder,
      bankName: w.bankName,
      accountNumber: w.accountNumber,
      ifscCode: w.ifscCode,
      upiId: w.upiId,
      panNumber: w.panNumber,
      gstin: w.gstin,
      gstRegistered: w.gstRegistered,
      tdsRate: w.tdsRate,
      termsVersionAccepted: p.text('terms_version_accepted', '2026.1-INR'),
      tiers: w.tiers,
      terms: w.terms,
    );
  }

  @override
  Future<AffiliateSettingsModel> updateCustomSlug(String customSlug) async {
    final clean = customSlug.trim().toLowerCase();
    if (!affiliateSlugPattern.hasMatch(clean)) {
      throw ArgumentError(
        'Use 3–40 lowercase letters, numbers, hyphens or underscores.',
      );
    }
    await _workspace.updateProfile({'custom_slug': clean});
    return getAffiliateSettings();
  }

  @override
  Future<AffiliateSettingsModel> updatePayoutSettings({
    required String payoutMethod,
    required String payoutAccount,
    required double minimumThreshold,
    required bool autoPayout,
    String? accountHolder,
    String? accountHolderName,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? upiId,
    String? upiVpa,
    String? panNumber,
    String? gstin,
    bool? gstRegistered,
  }) async {
    final String? effectiveHolder = accountHolder ?? accountHolderName;
    final String? effectiveUpi = upiId ?? upiVpa;
    const methods = {
      'upi',
      'bank_neft',
      'bank_imps',
      'bank_rtgs',
      'bank_transfer',
      'bank_wire',
      'razorpay',
    };
    final account = payoutAccount.trim();
    if (!methods.contains(payoutMethod) ||
        account.isEmpty ||
        !minimumThreshold.isFinite ||
        minimumThreshold < 1000) {
      throw ArgumentError(
        'Enter a valid Indian payout destination (UPI VPA or Bank Account) and a minimum threshold of at least ₹1,000 INR.',
      );
    }

    final String cleanPan = (panNumber ?? '').trim().toUpperCase();
    if (cleanPan.isNotEmpty && !affiliatePanPattern.hasMatch(cleanPan)) {
      throw ArgumentError(
        'Enter a valid 10-character Indian PAN (e.g. ABCDE1234F).',
      );
    }

    final String cleanIfsc = (ifscCode ?? '').trim().toUpperCase();
    if (cleanIfsc.isNotEmpty && !affiliateIfscPattern.hasMatch(cleanIfsc)) {
      throw ArgumentError(
        'Enter a valid 11-character Indian Bank IFSC code (e.g. HDFC0000240).',
      );
    }

    final String cleanGstin = (gstin ?? '').trim().toUpperCase();
    if (cleanGstin.isNotEmpty && !affiliateGstinPattern.hasMatch(cleanGstin)) {
      throw ArgumentError(
        'Enter a valid 15-character Indian GSTIN (e.g. 27ABCDE1234F1Z5).',
      );
    }

    final Map<String, Object?> detailsPatch = <String, Object?>{
      'payout_account': account,
      if (effectiveUpi != null) 'upi_id': effectiveUpi.trim(),
      if (payoutMethod == 'upi' &&
          (effectiveUpi == null || effectiveUpi.trim().isEmpty))
        'upi_id': account,
      if (effectiveHolder != null) 'account_holder': effectiveHolder.trim(),
      if (bankName != null) 'bank_name': bankName.trim(),
      if (accountNumber != null) 'account_number': accountNumber.trim(),
      if (cleanIfsc.isNotEmpty) 'ifsc': cleanIfsc,
      if (cleanPan.isNotEmpty) 'pan': cleanPan,
      if (cleanGstin.isNotEmpty) 'gstin': cleanGstin,
    };

    await _workspace.updateProfile({
      'currency': 'INR',
      'payout_method': payoutMethod,
      'payout_details': detailsPatch,
      'minimum_payout_threshold': minimumThreshold,
      'auto_payout_enabled': autoPayout,
      if (cleanPan.isNotEmpty) 'pan_number': cleanPan,
      if (cleanGstin.isNotEmpty) 'gstin': cleanGstin,
      'gst_registered': ?gstRegistered,
    });
    return getAffiliateSettings();
  }
}
