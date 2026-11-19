import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alphajournal/core/config/customer_data_policy.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/features/auth/data/repositories/supabase_auth_otp_repository.dart';
import 'package:alphajournal/features/auth/data/services/auth_session_storage.dart';
import 'package:alphajournal/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/auth/models/otp_purpose.dart';
import 'package:alphajournal/features/auth/models/user_profile_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CustomerDataPolicy.allowDemo = false;
  });

  tearDown(() {
    CustomerDataPolicy.allowDemo = false;
  });

  group('Issue #36: Authentication Hardening & Negative Regressions', () {
    test(
      '1. Self-signup privilege escalation is blocked for admin role',
      () async {
        final authService = SupabaseAuthBackendService.instance;

        final result = await authService.signUp(
          role: UserRole.userAdmin,
          handle: 'superadmin',
          email: 'admin.attack@alphajournal.com',
          password: 'securePassword123!',
          adminKey: 'unauthorized_master_key',
        );

        expect(result.isSuccess, isFalse);
        expect(result.errorCode, equals('admin_signup_disabled'));
        expect(
          result.message,
          contains('Administrator accounts are provisioned privately'),
        );
      },
    );

    test(
      '2. OTP verification fails closed in production and rejects arbitrary codes',
      () async {
        CustomerDataPolicy.allowDemo = false;
        final otpRepo = SupabaseAuthOtpRepository();

        // In production (allowDemo = false), unconfigured Supabase must fail closed
        final result = await otpRepo.verifyOtp(
          identifier: 'trader@alphajournal.com',
          purpose: OtpPurpose.signupVerification,
          code: '123456', // Arbitrary code
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, isNotNull);
        expect(result.token, isNull);
      },
    );

    test('3. OTP send fails closed when unconfigured in production', () async {
      CustomerDataPolicy.allowDemo = false;
      final otpRepo = SupabaseAuthOtpRepository();

      expect(
        () => otpRepo.sendOtp(
          identifier: 'trader@alphajournal.com',
          purpose: OtpPurpose.signupVerification,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      '4. OTP fallback is strictly isolated to explicit allowDemo mode',
      () async {
        CustomerDataPolicy.allowDemo = true;
        final otpRepo = SupabaseAuthOtpRepository();

        // With allowDemo=true, mock test verification is permitted
        final successResult = await otpRepo.verifyOtp(
          identifier: 'demo@alphajournal.com',
          purpose: OtpPurpose.signupVerification,
          code: '123456',
        );
        expect(successResult.success, isTrue);

        // Testing error code 000000 still fails in mock
        final failResult = await otpRepo.verifyOtp(
          identifier: 'demo@alphajournal.com',
          purpose: OtpPurpose.signupVerification,
          code: '000000',
        );
        expect(failResult.success, isFalse);
      },
    );

    test(
      '5. AuthSessionStorage strips adminKey and sanitizes sensitive data on save',
      () async {
        SharedPreferences.setMockInitialValues({});

        final adminProfile = UserProfileModel(
          id: 'usr_admin_999',
          handle: '@admin',
          email: 'admin@alphajournal.com',
          displayName: 'Administrator',
          role: UserRole.userAdmin,
          status: ProfileStatus.active,
          adminKey: 'top_secret_admin_key_should_not_leak',
          subscriptionTier: 'enterprise',
          createdAt: DateTime(2026, 1, 1),
        );

        await AuthSessionStorage.saveSession(profile: adminProfile);

        final stored = await AuthSessionStorage.getStoredProfile();
        expect(stored, isNotNull);
        expect(stored?.id, equals('usr_admin_999'));
        // adminKey must be stripped / sanitized to empty string
        expect(stored?.adminKey, isEmpty);
        expect(stored?.adminKey, isNot(contains('top_secret')));

        // Customer preference cannot elevate to admin role
        await AuthSessionStorage.saveWorkspaceRole(
          adminProfile.id,
          UserRole.userAdmin,
        );
        final elevatedRole = await AuthSessionStorage.workspaceRoleFor(
          adminProfile,
        );
        expect(elevatedRole, equals(UserRole.userAdmin));

        final customerProfile = adminProfile.copyWith(role: UserRole.customer);
        final customerRole = await AuthSessionStorage.workspaceRoleFor(
          customerProfile,
        );
        expect(customerRole, equals(UserRole.customer));
      },
    );
  });

  test(
    'a rejected workspace sign-in discards the provisional SDK session',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      const userId = '876c5649-5698-443d-8908-dc9a73b62d06';
      const email = 'trader@example.test';
      String jwtPart(Map<String, Object> value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final header = jwtPart({'alg': 'HS256'});
      final payload = jwtPart({
        'sub': userId,
        'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
      });
      final auth = SupabaseAuthBackendService.instance;
      await http.runWithClient(
        () async {
          await SupabaseConfig.initialize(
            customUrl: 'https://mock.example.test',
            customKey: 'synthetic-frontend-test-key',
          );
          expect(SupabaseConfig.isConfigured, isTrue);
          addTearDown(() => Supabase.instance.dispose());

          final result = await auth.signIn(
            role: UserRole.affiliate,
            emailOrHandle: email,
            password: 'test-password',
          );

          expect(
            result.errorCode,
            'affiliate_not_approved',
            reason: result.message,
          );
          expect(SupabaseConfig.client!.auth.currentSession, isNull);
          expect(await AuthSessionStorage.getStoredProfile(), isNull);
          expect(auth.passwordSignInPending, isFalse);
        },
        () => MockClient((request) async {
          expect(request.url.host, 'mock.example.test');
          final Object? response = switch (request.url.path) {
            '/auth/v1/token' => {
              'access_token': '$header.$payload.synthetic',
              'refresh_token': 'synthetic-refresh-token',
              'token_type': 'bearer',
              'user': {'id': userId, 'email': email},
            },
            '/rest/v1/profiles' => [
              {
                'id': userId,
                'email': email,
                'role': 'customer',
                'handle': '@trader',
              },
            ],
            '/rest/v1/affiliate_applications' => [
              {'status': 'pending'},
            ],
            '/auth/v1/logout' => null,
            _ => fail('Unexpected auth test path ${request.url.path}'),
          };
          expect(auth.passwordSignInPending, isTrue);
          return http.Response(
            response == null ? '' : jsonEncode(response),
            response == null ? 204 : 200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
    },
  );
}
