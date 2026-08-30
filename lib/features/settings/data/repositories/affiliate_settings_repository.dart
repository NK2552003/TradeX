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
  AffiliateSettingsModel _settings = AffiliateSettingsModel.mock();

  @override
  Future<AffiliateSettingsModel> getAffiliateSettings() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _settings;
  }

  @override
  Future<AffiliateSettingsModel> updateCustomSlug(String customSlug) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _settings = _settings.copyWith(customSlug: customSlug);
    return _settings;
  }

  @override
  Future<AffiliateSettingsModel> updatePayoutSettings({
    required String payoutMethod,
    required String payoutAccount,
    required double minimumThreshold,
    required bool autoPayout,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _settings = _settings.copyWith(
      payoutMethod: payoutMethod,
      payoutAccount: payoutAccount,
      minimumPayoutThreshold: minimumThreshold,
      autoPayoutEnabled: autoPayout,
    );
    return _settings;
  }

  @override
  Future<String> generateMarketingKitDownloadUrl() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return 'https://assets.tradex.ai/marketing/tradex_creator_kit_2026.zip';
  }
}
