import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/presentation/pages/forgot_password_page.dart';

void main() {
  testWidgets('ForgotPasswordPage has matching logo size and title styling with LoginPage', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool backToLoginTapped = false;

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => MaterialApp(
          home: ForgotPasswordPage(
            onBackToLogin: () {
              backToLoginTapped = true;
            },
          ),
        ),
      ),
    );

    // Verify AppLogoMark has size 20 (matching LoginPage)
    final logoFinder = find.byType(AppLogoMark);
    expect(logoFinder, findsOneWidget);
    final AppLogoMark logo = tester.widget<AppLogoMark>(logoFinder);
    expect(logo.size, 20);

    // Verify title text size is 28.0
    final titleFinder = find.text('Reset your password');
    expect(titleFinder, findsOneWidget);
    final Text titleText = tester.widget<Text>(titleFinder);
    expect(titleText.style?.fontSize, 28.0);
    expect(titleText.style?.letterSpacing, -0.5);

    // Verify back button interaction
    final backBtnFinder = find.byIcon(Icons.arrow_back_rounded);
    expect(backBtnFinder, findsOneWidget);
    await tester.tap(backBtnFinder);
    expect(backToLoginTapped, isTrue);
  });

  testWidgets('ForgotPasswordPage renders single-row progress bar on mobile and UiStepper on desktop', (
    WidgetTester tester,
  ) async {
    // 1. Mobile (390px)
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => MaterialApp(
          home: ForgotPasswordPage(
            onBackToLogin: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UiStepper), findsNothing);
    expect(find.text('STEP 1 OF 3'), findsOneWidget);

    // 2. Desktop (1024px)
    tester.view.physicalSize = const Size(1024, 768);
    await tester.pumpAndSettle();

    expect(find.byType(UiStepper), findsOneWidget);
    expect(find.text('Request'), findsOneWidget);
    expect(find.text('Verify'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
  });
}
