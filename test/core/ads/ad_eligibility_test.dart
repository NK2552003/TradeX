import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alphajournal/core/ads/ad_config.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/data/account_access_repository.dart';
import 'package:alphajournal/core/privacy/consent_preferences.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';

void main() {
  AccountAccess account({
    AppTier tier = AppTier.free,
    UserRole role = UserRole.customer,
    String status = 'active',
  }) => AccountAccess(
    userId: 'viewer',
    status: status,
    role: role,
    tier: tier,
    features: const {},
  );
  test('only verified active free customer accounts are eligible', () {
    expect(
      AdEligibility.freeAccount(account(), AppTier.free, 'viewer'),
      isTrue,
    );
    for (final access in [
      null,
      account(tier: AppTier.premium),
      account(tier: AppTier.enterprise),
      account(role: UserRole.userAdmin),
      account(role: UserRole.affiliate),
      account(status: 'suspended'),
    ]) {
      expect(
        AdEligibility.freeAccount(access, AppTier.free, 'viewer'),
        isFalse,
      );
    }
    expect(
      AdEligibility.freeAccount(account(), AppTier.premium, 'viewer'),
      isFalse,
    );
    expect(
      AdEligibility.freeAccount(account(), AppTier.free, 'different-user'),
      isFalse,
    );
  });
  test('private, transactional and administrative routes have no ads', () {
    for (final route in [
      'workspace',
      'journal',
      'notes',
      'strategies',
      'messages',
      'settings',
      'billing_subscription',
      'admin_console',
      'affiliate_overview',
      'ai_copilot',
      'auth/login',
      'community_profile',
      'community_bookmarks',
      'search',
    ]) {
      expect(AdEligibility.publicDestination(route), isFalse, reason: route);
    }
    expect(
      AdEligibility.publicDestination('notes', publicRecord: true),
      isTrue,
    );
    expect(AdEligibility.publicDestination('community_feed'), isTrue);
  });
  test('unconfigured and malformed publisher/slot IDs cannot serve ads', () {
    expect(const AdConfig().configured(AdPlacement.feedInline), isFalse);
    expect(
      const AdConfig(
        enabled: true,
        publisherId: 'placeholder',
        slots: {AdPlacement.feedInline: '1234567890'},
      ).configured(AdPlacement.feedInline),
      isFalse,
    );
    expect(
      const AdConfig(
        enabled: true,
        publisherId: 'ca-pub-1234567890123456',
        slots: {AdPlacement.feedInline: 'invalid'},
      ).configured(AdPlacement.feedInline),
      isFalse,
    );
    expect(
      const AdConfig(
        enabled: true,
        publisherId: 'ca-pub-1234567890123456',
        slots: {AdPlacement.feedInline: '1234567890'},
      ).configured(AdPlacement.feedInline),
      isTrue,
    );
  });
  test('advertising requires a saved choice and stops on withdrawal', () async {
    SharedPreferences.setMockInitialValues({});
    final consent = ConsentController();
    addTearDown(consent.dispose);
    expect(AdEligibility.consentAllows(consent), isFalse);
    await consent.initialize();
    expect(AdEligibility.consentAllows(consent), isFalse);
    await consent.save(const ConsentPreferences(advertising: true));
    expect(AdEligibility.consentAllows(consent), isTrue);
    final pending = consent.save(const ConsentPreferences());
    await pending;
    expect(AdEligibility.consentAllows(consent), isFalse);
  });
}
