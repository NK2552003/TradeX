import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

void main() {
  testWidgets('UiOtpField scales boxes to fit tight 300px constraints without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: UiOtpField(
                  length: 6,
                  size: UiSize.lg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UiOtpField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UiOtpField handles text entry and completed callback', (
    WidgetTester tester,
  ) async {
    String completedCode = '';

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: UiOtpField(
                length: 6,
                onCompleted: (code) => completedCode = code,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);
    await tester.enterText(textFieldFinder, '123456');
    await tester.pumpAndSettle();

    expect(completedCode, '123456');
    expect(tester.takeException(), isNull);
  });
}
