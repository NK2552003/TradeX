import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/auth/auth.dart';

void main() {
  group('AuthBackendService & Profile Roles Tests', () {
    late AuthBackendService authService;

    setUp(() {
      authService = AuthBackendService.instance;
    });

    test('Customer Signup & Authentication Flow', () async {
      final result = await authService.signUp(
        role: UserRole.customer,
        handle: '@trader_joe',
        email: 'joe@tradex.ai',
        password: 'password123',
      );

      expect(result.isSuccess, isTrue);
      expect(result.profile, isNotNull);
      expect(result.profile?.role, equals(UserRole.customer));
      expect(result.profile?.handle, equals('@trader_joe'));
      expect(result.profile?.email, equals('joe@tradex.ai'));
      expect(result.profile?.referralCode, startsWith('REF-TRADEX-'));

      // Test dual sign in by handle
      final signInResult = await authService.signIn(
        role: UserRole.customer,
        emailOrHandle: '@trader_joe',
        password: 'password123',
      );

      expect(signInResult.isSuccess, isTrue);
      expect(signInResult.profile?.email, equals('joe@tradex.ai'));
    });

    test('Affiliate Partner Signup & Referral Schema Test', () async {
      final result = await authService.signUp(
        role: UserRole.affiliate,
        handle: '@partner_pro',
        email: 'partner@tradex.ai',
        password: 'password123',
        referralCode: 'REF-TRADEX-2026',
      );

      expect(result.isSuccess, isTrue);
      expect(result.profile?.role, equals(UserRole.affiliate));
      expect(result.affiliateProfile, isNotNull);
      expect(result.affiliateProfile?.commissionRate, equals(0.15));
      expect(result.affiliateProfile?.totalReferrals, equals(1));
      expect(result.affiliateProfile?.unpaidBalance, equals(50.00));
    });

    test('User Admin Signup Requirement & Verification Test', () async {
      // 1. Without Master Admin Key (Expect Failure)
      final failResult = await authService.signUp(
        role: UserRole.userAdmin,
        handle: '@admin_sec',
        email: 'admin@tradex.ai',
        password: 'password123',
      );
      expect(failResult.isSuccess, isFalse);

      // 2. With Master Admin Key (Expect Success)
      final successResult = await authService.signUp(
        role: UserRole.userAdmin,
        handle: '@admin_sec',
        email: 'admin@tradex.ai',
        password: 'password123',
        adminKey: 'LIC-ADMIN-2026-KEY',
      );

      expect(successResult.isSuccess, isTrue);
      expect(successResult.profile?.role, equals(UserRole.userAdmin));
      expect(successResult.profile?.subscriptionTier, equals('enterprise'));
    });
  });
}
