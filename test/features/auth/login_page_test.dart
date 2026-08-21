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
}
