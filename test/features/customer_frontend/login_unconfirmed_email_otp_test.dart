import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/features/auth/data/repositories/auth_repository.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/auth/presentation/pages/login_page.dart';

class _MockUnconfirmedAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<bool> isSignupOpen() async => true;

  @override
  Future<AuthResult> signIn({
    required UserRole role,
    required String emailOrHandle,
    required String password,
    String? adminKey,
  }) async {
    return AuthResult.failure(
      'Email not confirmed. Please enter the verification code sent to your email.',
      errorCode: 'email_not_confirmed',
    );
  }
}

void main() {
  testWidgets('LoginPage routes unconfirmed email to verification callback', (
    WidgetTester tester,
  ) async {
    UserRole? verifiedRole;
    String? verifiedEmail;

    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          authRepository: _MockUnconfirmedAuthRepository(),
          onLoginSuccess: (_, _) {},
          onNavigateToSignup: (_) {},
          onNavigateToForgotPassword: () {},
          onNavigateBack: () {},
          onRequiresVerification: (role, email) {
            verifiedRole = role;
            verifiedEmail = email;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final inputs = find.byType(EditableText);
    expect(inputs, findsWidgets);

    // Enter email and password
    await tester.enterText(inputs.at(0), 'trader@example.com');
    await tester.enterText(inputs.at(1), 'password123');
    await tester.pumpAndSettle();

    // Tap submit button
    final submitButton = find.text('Login');
    expect(submitButton, findsOneWidget);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(verifiedRole, equals(UserRole.customer));
    expect(verifiedEmail, equals('trader@example.com'));
  });
}
