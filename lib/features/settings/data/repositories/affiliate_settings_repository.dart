import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/settings/models/affiliate_settings_model.dart';

abstract class AffiliateSettingsRepository {
  Future<AffiliateSettingsModel> getAffiliateSettings();
  Future<AffiliateSettingsModel> updateCustomSlug(String customSlug);
  Future<AffiliateSettingsModel> updatePayoutSettings({
    required String payoutMethod,
    required String payoutAccount,
    required double minimumThreshold,
    required bool autoPayout,
  });
  Future<String> generateMarketingKitDownloadUrl();
}

class AffiliateSettingsRepositoryImpl implements AffiliateSettingsRepository {
  static const String _demoUserId = '00000000-0000-0000-0000-000000000001';

  AffiliateSettingsModel _settings = CustomerDataPolicy.allowDemo
      ? AffiliateSettingsModel.mock()
      : const AffiliateSettingsModel(
          referralCode: '',
          customSlug: '',
          commissionRate: 0,
          tierName: 'Not enrolled',
          payoutMethod: 'upi',
          payoutAccount: '',
          minimumPayoutThreshold: 0,
          autoPayoutEnabled: false,
          totalReferrals: 0,
          totalEarnings: 0,
          pendingPayout: 0,
        );

  @override
  Future<AffiliateSettingsModel> getAffiliateSettings() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? _demoUserId;

        final res = await client
            .from('affiliate_profiles')
            .select()
            .eq('id', targetUserId)
            .maybeSingle();

        if (res != null) {
          final payoutDetails =
              res['payout_details'] as Map<String, dynamic>? ?? {};
          _settings = AffiliateSettingsModel(
            referralCode:
                res['affiliate_code'] as String? ?? 'TRADEX-ALPHA-2026',
            customSlug: res['custom_slug'] as String? ?? 'nitish_alpha',
            commissionRate:
                (res['commission_rate'] as num?)?.toDouble() ?? 0.30,
            tierName:
                'Tier 2 · ${(res['tier'] as String? ?? 'gold').toUpperCase()} Partner',
            payoutMethod: res['payout_method'] as String? ?? 'upi',
            payoutAccount:
                payoutDetails['payout_vpa'] as String? ??
                payoutDetails['payout_account'] as String? ??
                'nitish@okhdfcbank',
            minimumPayoutThreshold:
                (res['minimum_payout_threshold'] as num?)?.toDouble() ?? 2500.0,
            autoPayoutEnabled: res['auto_payout_enabled'] as bool? ?? true,
            totalReferrals: (res['total_referrals'] as num?)?.toInt() ?? 48,
            totalEarnings:
                (res['total_earnings'] as num?)?.toDouble() ?? 84500.0,
            pendingPayout:
                (res['unpaid_balance'] as num?)?.toDouble() ?? 14200.0,
          );
          return _settings;
        }
      } catch (e) {
        debugPrint(
          '[AffiliateSettingsRepository] getAffiliateSettings error: $e',
        );
      }
    }
    return _settings;
  }

  @override
  Future<AffiliateSettingsModel> updateCustomSlug(String customSlug) async {
    _settings = _settings.copyWith(customSlug: customSlug);

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? _demoUserId;

        await client
            .from('affiliate_profiles')
            .update({
              'custom_slug': customSlug,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', targetUserId);
      } catch (e) {
        debugPrint('[AffiliateSettingsRepository] updateCustomSlug error: $e');
      }
    }
    return _settings;
  }

  @override
  Future<AffiliateSettingsModel> updatePayoutSettings({
    required String payoutMethod,
    required String payoutAccount,
    required double minimumThreshold,
    required bool autoPayout,
  }) async {
    _settings = _settings.copyWith(
      payoutMethod: payoutMethod,
      payoutAccount: payoutAccount,
      minimumPayoutThreshold: minimumThreshold,
      autoPayoutEnabled: autoPayout,
    );

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final user = client.auth.currentUser;
        final targetUserId = user?.id ?? _demoUserId;

        await client
            .from('affiliate_profiles')
            .update({
              'payout_method': payoutMethod,
              'minimum_payout_threshold': minimumThreshold,
              'auto_payout_enabled': autoPayout,
              'payout_details': {
                'payout_vpa': payoutAccount,
                'payout_account': payoutAccount,
              },
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', targetUserId);
      } catch (e) {
        debugPrint(
          '[AffiliateSettingsRepository] updatePayoutSettings error: $e',
        );
      }
    }
    return _settings;
  }

  @override
  Future<String> generateMarketingKitDownloadUrl() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return 'https://assets.tradex.ai/marketing/tradex_creator_kit_2026.zip';
  }
}
