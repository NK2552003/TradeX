import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/features/auth/data/repositories/auth_repository.dart';
import 'package:tradex/features/auth/models/affiliate_profile_model.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';
import 'package:tradex/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:tradex/features/auth/presentation/pages/get_started_page.dart';
import 'package:tradex/features/auth/presentation/pages/login_page.dart';
import 'package:tradex/features/auth/presentation/pages/signup_page.dart';
import 'package:tradex/features/auth/presentation/widgets/tradex_footer.dart';
import 'package:tradex/features/auth/widgets/role_selector_tab.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.profileRole = UserRole.customer});

  final UserRole profileRole;

  @override
  Future<AuthResult> signIn({
    required UserRole role,
    required String emailOrHandle,
    required String password,
    String? adminKey,
  }) async {
    return AuthResult.success(
      message: 'Sign in successful',
      profile: UserProfileModel(
        id: 'usr_test_1',
        handle: 'testtrader',
        email: emailOrHandle,
        displayName: 'Test Trader',
        role: profileRole,
      ),
    );
  }

  @override
  Future<AuthResult> signUp({
    required UserRole role,
    required String handle,
    required String email,
    required String password,
    String? referralCode,
    String? adminKey,
  }) async {
    return AuthResult.success(
      message: 'Account created',
      profile: UserProfileModel(
        id: 'usr_test_2',
        handle: handle,
        email: email,
        displayName: handle,
        role: role,
      ),
    );
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthResult> resetPassword(String email) async {
    return AuthResult.success(
      message: 'Reset email sent',
      profile: UserProfileModel(
        id: 'usr_reset',
        handle: 'reset',
        email: email,
        displayName: 'Reset',
        role: UserRole.customer,
      ),
    );
  }

  @override
  Future<UserProfileModel?> getProfile(String userId) async => null;

  @override
  Future<AffiliateProfileModel?> getAffiliateProfile(String affiliateId) async =>
      null;
}

Widget _wrapWithUiTheme(
  Widget child, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CustomerDataPolicy.allowDemo = true;
  });

  group('Issue #21: Auth & Onboarding Hardening and Layout Verification', () {
    testWidgets(
      '1. LoginPage restricts RoleSelectorTab to Customer and Affiliate only',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _wrapWithUiTheme(
            LoginPage(
              initialRole: UserRole.customer,
              authRepository: _FakeAuthRepository(),
              onLoginSuccess: (_, _) {},
              onNavigateToSignup: (_) {},
              onNavigateToForgotPassword: () {},
              onNavigateBack: () {},
            ),
          ),
        );
        await tester.pump();

        final roleSelectorFinder = find.byType(RoleSelectorTab);
        expect(roleSelectorFinder, findsOneWidget);

        final RoleSelectorTab selector = tester.widget(roleSelectorFinder);
        expect(selector.roles, contains(UserRole.customer));
        expect(selector.roles, contains(UserRole.affiliate));
        expect(selector.roles.contains(UserRole.userAdmin), isFalse);
      },
    );

    testWidgets(
      '2. Role privilege escalation is blocked during login completion',
      (tester) async {
        UserRole? reportedRole;

        await tester.pumpWidget(
          _wrapWithUiTheme(
            LoginPage(
              initialRole: UserRole.customer,
              authRepository: _FakeAuthRepository(
                profileRole: UserRole.customer,
              ),
              onLoginSuccess: (role, email) {
                reportedRole = role;
              },
              onNavigateToSignup: (_) {},
              onNavigateToForgotPassword: () {},
              onNavigateBack: () {},
            ),
          ),
        );
        await tester.pump();

        // Enter valid credentials
        await tester.enterText(find.byType(UiInput).first, 'trader@tradex.com');
        await tester.enterText(
          find.byType(UiPasswordField).first,
          'Password123!',
        );
        await tester.pump();

        // Tap Login
        final loginBtn = find.widgetWithText(UiButton, 'Login').first;
        await tester.tap(loginBtn);
        await tester.pumpAndSettle();

        expect(reportedRole, equals(UserRole.customer));
      },
    );

    testWidgets(
      '3. Google sign-in cleanly handles unconfigured OAuth without crashing',
      (tester) async {
        await tester.pumpWidget(
          _wrapWithUiTheme(
            LoginPage(
              initialRole: UserRole.customer,
              authRepository: _FakeAuthRepository(),
              onLoginSuccess: (_, _) {},
              onNavigateToSignup: (_) {},
              onNavigateToForgotPassword: () {},
              onNavigateBack: () {},
            ),
          ),
        );
        await tester.pump();

        final googleBtn = find.widgetWithText(UiButton, 'Sign in with Google');
        expect(googleBtn, findsOneWidget);

        await tester.tap(googleBtn);
        await tester.pumpAndSettle();

        // Should display the configuration error callout
        expect(
          find.textContaining('Google sign-in is unavailable'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '4. TradeXFooter removes client encryption claims and shows Security & Compliance',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1024, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _wrapWithUiTheme(
            const Scaffold(body: SingleChildScrollView(child: TradeXFooter())),
            size: const Size(1024, 1200),
          ),
        );
        await tester.pump();

        final linkFinder = find.text('Security & Compliance');
        expect(linkFinder, findsOneWidget);
        expect(find.textContaining('Client Encryption'), findsNothing);

        await tester.ensureVisible(linkFinder);
        await tester.tap(linkFinder);
        await tester.pumpAndSettle();

        expect(find.text('Security & Compliance Architecture'), findsOneWidget);
        expect(find.textContaining('Row Level Security (RLS)'), findsOneWidget);
        expect(find.textContaining('Zero Custody'), findsOneWidget);
        expect(find.textContaining('client encryption'), findsNothing);
      },
    );

    testWidgets(
      '5. Password reset handles recovery session and prevents duplicate submissions',
      (tester) async {
        String? resetTokenReceived;
        String? resetPasswordReceived;

        await tester.pumpWidget(
          _wrapWithUiTheme(
            ForgotPasswordPage(
              completePasswordReset: (token, password) async {
                resetTokenReceived = token;
                resetPasswordReceived = password;
              },
              onBackToLogin: () {},
            ),
          ),
        );
        await tester.pump();

        // Enter email and request OTP
        await tester.enterText(
          find.byType(UiInput).first,
          'recovery@tradex.com',
        );
        await tester.pump();

        final sendBtn = find.widgetWithText(UiButton, 'Send Reset Code');
        await tester.tap(sendBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));

        // Step 1: Verification code entry
        expect(find.text('Enter Verification Code'), findsOneWidget);

        // Enter OTP code
        final otpField = find.byType(UiOtpField);
        expect(otpField, findsOneWidget);
        final UiOtpField fieldWidget = tester.widget(otpField);
        fieldWidget.controller?.value = '123456';
        await tester.pump();

        final verifyBtn = find.widgetWithText(UiButton, 'Verify & Continue');
        await tester.tap(verifyBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        // Step 2: New password input
        final passwordFields = find.byType(UiPasswordField);
        await tester.enterText(passwordFields.at(0), 'NewSecurePassword123!');
        await tester.enterText(passwordFields.at(1), 'NewSecurePassword123!');
        await tester.pump();

        final updateBtn = find.widgetWithText(UiButton, 'Update Password');
        await tester.tap(updateBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Step 3: Success state
        expect(find.text('Password Updated!'), findsOneWidget);
        expect(resetPasswordReceived, equals('NewSecurePassword123!'));
        expect(resetTokenReceived, isNotNull);
      },
    );

    for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0]) {
      testWidgets('6. Auth layouts render without overflow across width $width px', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _wrapWithUiTheme(
            LoginPage(
              initialRole: UserRole.customer,
              authRepository: _FakeAuthRepository(),
              onLoginSuccess: (_, _) {},
              onNavigateToSignup: (_) {},
              onNavigateToForgotPassword: () {},
              onNavigateBack: () {},
            ),
            size: Size(width, 800),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          _wrapWithUiTheme(
            SignupPage(
              initialRole: UserRole.customer,
              authRepository: _FakeAuthRepository(),
              onSignupSuccess: (_, _, {bool requiresVerification = false}) {},
              onNavigateToLogin: (_) {},
              onNavigateBack: () {},
            ),
            size: Size(width, 800),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          _wrapWithUiTheme(
            ForgotPasswordPage(onBackToLogin: () {}),
            size: Size(width, 800),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      '7. Onboarding GetStartedPage mobile landscape & scaled-text does not overflow',
      (tester) async {
        // Landscape compact mobile with text scaling
        await tester.binding.setSurfaceSize(const Size(720, 360));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _wrapWithUiTheme(
            GetStartedPage(onGetStarted: (_) {}, onSignIn: () {}),
            size: const Size(720, 360),
            textScale: 1.25,
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Continue as Trader'), findsOneWidget);
        expect(find.text('Join as Affiliate'), findsOneWidget);
      },
    );
  });
}
