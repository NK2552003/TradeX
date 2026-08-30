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

    test(
      'Affiliate signup creates a customer account pending application',
      () async {
        final result = await authService.signUp(
          role: UserRole.affiliate,
          handle: '@partner_pro',
          email: 'partner@tradex.ai',
          password: 'password123',
          referralCode: 'REF-TRADEX-2026',
        );

        expect(result.isSuccess, isTrue);
        expect(result.profile?.role, equals(UserRole.customer));
        expect(result.affiliateProfile, isNull);
        expect(result.message, contains('Complete the affiliate application'));
      },
    );

    test(
      'User Admin public signup is disabled with or without a key',
      () async {
        final failResult = await authService.signUp(
          role: UserRole.userAdmin,
          handle: '@admin_sec',
          email: 'admin@tradex.ai',
          password: 'password123',
        );
        expect(failResult.isSuccess, isFalse);

        // A leaked or manually submitted key must not reopen registration.
        final successResult = await authService.signUp(
          role: UserRole.userAdmin,
          handle: '@admin_sec',
          email: 'admin@tradex.ai',
          password: 'password123',
          adminKey: 'LIC-ADMIN-2026-KEY',
        );

        expect(successResult.isSuccess, isFalse);
        expect(successResult.errorCode, equals('admin_signup_disabled'));
        expect(successResult.message, contains('provisioned privately'));
      },
    );
  });
}
