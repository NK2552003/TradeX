import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/privacy/consent_preferences.dart';
import 'package:tradex/features/affiliate_program/data/affiliate_attribution.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'absent, corrupt, old version, expired and future choices fail closed',
    () {
      final now = DateTime.utc(2026, 11, 9);
      for (final raw in [
        null,
        '',
        '[]',
        '{',
        jsonEncode({
          'version': 0,
          'advertising': true,
          'savedAt': now.toIso8601String(),
        }),
        jsonEncode({
          'version': 1,
          'advertising': true,
          'savedAt': now.subtract(const Duration(days: 180)).toIso8601String(),
        }),
        jsonEncode({
          'version': 1,
          'advertising': true,
          'savedAt': now.add(const Duration(seconds: 1)).toIso8601String(),
        }),
      ]) {
        final choice = ConsentPreferences.parse(raw, now);
        expect(choice.advertising, false);
        expect(choice.isCurrent(now), false);
      }
    },
  );

  test(
    'granular choices survive reload and advertising rejection disables personalisation',
    () async {
      final controller = ConsentController();
      await controller.initialize();
      expect(controller.needsChoice, true);
      expect(
        await controller.save(
          const ConsentPreferences(analytics: true, personalizedAds: true),
        ),
        true,
      );
      final reloaded = ConsentController();
      await reloaded.initialize();
      expect(reloaded.needsChoice, false);
      expect(reloaded.value.analytics, true);
      expect(reloaded.value.personalizedAds, false);
      expect(reloaded.value.advertising, false);
    },
  );

  test(
    'withdrawal removes optional referral records but preserves necessary data',
    () async {
      SharedPreferences.setMockInitialValues({
        'affiliate_attribution_v1': 'referral',
        'affiliate_visitor_v1': 'visitor',
        'auth_session_user_id': 'account',
      });
      final controller = ConsentController();
      expect(await controller.save(const ConsentPreferences()), true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('affiliate_attribution_v1'), isNull);
      expect(prefs.getString('affiliate_visitor_v1'), isNull);
      expect(prefs.getString('auth_session_user_id'), 'account');
    },
  );

  test(
    'unavailable storage leaves optional processing off and reports failure',
    () async {
      final controller = ConsentController(
        storage: () async => throw StateError('blocked'),
      );
      await controller.initialize();
      expect(controller.needsChoice, true);
      expect(
        await controller.save(const ConsentPreferences(advertising: true)),
        false,
      );
      expect(controller.value.advertising, false);
      expect(controller.error, isNotNull);
    },
  );

  test(
    'automatic attribution needs consent and expired referrals are removed',
    () async {
      final controller = ConsentController.instance;
      await controller.initialize();
      await controller.save(const ConsentPreferences());
      await AffiliateAttribution.capture('partner-one', 'valid-campaign');
      expect(await AffiliateAttribution.load(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('affiliate_visitor_v1'), false);
      await controller.save(const ConsentPreferences(affiliate: true));
      await AffiliateAttribution.capture('partner-one', 'valid-campaign');
      expect((await AffiliateAttribution.load())?['code'], 'partner-one');
      await prefs.setString(
        'affiliate_attribution_v1',
        jsonEncode({
          'code': 'partner-one',
          'captured_at': DateTime.now()
              .subtract(const Duration(days: 31))
              .toIso8601String(),
        }),
      );
      expect(await AffiliateAttribution.load(), isNull);
      expect(prefs.containsKey('affiliate_visitor_v1'), false);
    },
  );
  test(
    'refresh observes another tab withdrawing previously accepted choices',
    () async {
      final controller = ConsentController();
      await controller.initialize();
      await controller.save(
        const ConsentPreferences(advertising: true, affiliate: true),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        ConsentController.storageKey,
        jsonEncode(
          ConsentPreferences(savedAt: DateTime.now().toUtc()).toJson(),
        ),
      );
      await controller.refresh();
      expect(controller.value.advertising, false);
      expect(controller.value.affiliate, false);
      expect(controller.needsChoice, false);
    },
  );
}
