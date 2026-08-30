import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/presentation/pages/login_page.dart';

void main() {
  testWidgets('login password field does not show password strength', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => MaterialApp(
          home: LoginPage(
            onLoginSuccess: (_, _) {},
            onNavigateToSignup: (_) {},
            onNavigateToForgotPassword: () {},
            onNavigateBack: () {},
          ),
        ),
      ),
    );

    final UiPasswordField passwordField = tester.widget<UiPasswordField>(
      find.byType(UiPasswordField),
    );
    expect(passwordField.showStrength, isFalse);

    await tester.enterText(find.byType(EditableText).at(1), 'weak');
    await tester.pump();
    expect(find.text('Weak'), findsNothing);
    expect(find.text('Fair'), findsNothing);
    expect(find.text('Good'), findsNothing);
    expect(find.text('Strong'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forgot password link is right-aligned with the password input', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool forgotPasswordTapped = false;

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => MaterialApp(
          home: LoginPage(
            onLoginSuccess: (_, _) {},
            onNavigateToSignup: (_) {},
            onNavigateToForgotPassword: () {
              forgotPasswordTapped = true;
            },
            onNavigateBack: () {},
          ),
        ),
      ),
    );

    final forgotFinder = find.text('Forgot your password?');
    expect(forgotFinder, findsOneWidget);

    final passwordFieldFinder = find.byType(UiPasswordField);
    expect(passwordFieldFinder, findsOneWidget);

    final Rect forgotRect = tester.getRect(forgotFinder);
    final Rect fieldRect = tester.getRect(passwordFieldFinder);

    // The right edge of the "Forgot your password?" text should align with the right edge of the input field
    // (within 1-2px tolerance for subpixel antialiasing/padding)
    expect((forgotRect.right - fieldRect.right).abs(), lessThanOrEqualTo(2.0));

    await tester.tap(forgotFinder);
    expect(forgotPasswordTapped, isTrue);
  });

  testWidgets('forgot password link is right-aligned on mobile viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => MaterialApp(
          home: LoginPage(
            onLoginSuccess: (_, _) {},
            onNavigateToSignup: (_) {},
            onNavigateToForgotPassword: () {},
            onNavigateBack: () {},
          ),
        ),
      ),
    );

    final forgotFinder = find.text('Forgot?');
    expect(forgotFinder, findsOneWidget);

    final passwordFieldFinder = find.byType(UiPasswordField);
    expect(passwordFieldFinder, findsOneWidget);

    final Rect forgotRect = tester.getRect(forgotFinder);
    final Rect fieldRect = tester.getRect(passwordFieldFinder);

    expect((forgotRect.right - fieldRect.right).abs(), lessThanOrEqualTo(2.0));
  });
}
