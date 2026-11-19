import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';

void main() {
  for (final width in [240.0, 400.0, 700.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('divider centers its label at $width and $scale', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: SizedBox(
                    width: width,
                    child: const IntrinsicHeight(
                      child: UiDivider(label: 'Or continue with'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(
          tester.getCenter(find.text('Or continue with')).dx,
          closeTo(tester.getCenter(find.byType(UiDivider)).dx, .01),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
