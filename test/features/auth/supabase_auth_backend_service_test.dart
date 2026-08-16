import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupabaseAuthBackendService Integration & Fallback Tests', () {
    late SupabaseAuthBackendService authService;

    setUp(() {
      authService = SupabaseAuthBackendService.instance;
    });

    test('1. Supabase unconfigured fallback mode handles Customer registration', () async {
      expect(SupabaseConfig.isConfigured, isFalse);

      final result = await authService.signUp(
        role: UserRole.customer,
        handle: 'supatrader',
        email: 'supatrader@tradex.ai',
        password: 'Password123!',
      );

      expect(result.isSuccess, isTrue);
      expect(result.profile, isNotNull);
      expect(result.profile!.email, equals('supatrader@tradex.ai'));
      expect(result.profile!.role, equals(UserRole.customer));
      expect(result.profile!.referralCode, startsWith('REF-TRADEX-'));
    });

    test('2. Dual Sign-In via Handle or Email with fallback', () async {
      final loginByHandle = await authService.signIn(
        role: UserRole.customer,
        emailOrHandle: '@supatrader',
        password: 'Password123!',
      );
      expect(loginByHandle.isSuccess, isTrue);
      expect(loginByHandle.profile!.handle, equals('@supatrader'));

      final loginByEmail = await authService.signIn(
        role: UserRole.customer,
        emailOrHandle: 'supatrader@tradex.ai',
        password: 'Password123!',
      );
      expect(loginByEmail.isSuccess, isTrue);
      expect(loginByEmail.profile!.email, equals('supatrader@tradex.ai'));
    });

    test('3. User Admin registration requires Master Admin Key', () async {
      final failedResult = await authService.signUp(
        role: UserRole.userAdmin,
        handle: 'admin_test',
        email: 'admin_test@tradex.ai',
        password: 'Password123!',
      );
      expect(failedResult.isSuccess, isFalse);
      expect(failedResult.message, contains('Master Admin Key is required'));

      final validResult = await authService.signUp(
        role: UserRole.userAdmin,
        handle: 'admin_test',
        email: 'admin_test@tradex.ai',
        password: 'Password123!',
        adminKey: 'LIC-ADMIN-2026-KEY',
      );
      expect(validResult.isSuccess, isTrue);
      expect(validResult.profile!.role, equals(UserRole.userAdmin));
    });
  });
}
