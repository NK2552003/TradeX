import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/affiliate_program/presentation/pages/affiliate_application_page.dart';

void main() {
  for (final Size viewport in const <Size>[
    Size(390, 844),
    Size(1024, 768),
    Size(1440, 900),
  ]) {
    testWidgets(
      'affiliate application renders without field or overflow errors at ${viewport.width.toInt()}px',
      (WidgetTester tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          UiApp(
            theme: UiTheme.dark(),
            builder: (BuildContext context) => const MaterialApp(
              home: AffiliateApplicationPage(
                userId: 'layout_test_applicant',
                email: 'applicant@tradex.test',
                displayName: 'Layout Test',
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 180));
        await tester.pump();

        expect(find.text('Personal information'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
        expect(find.text('Application Encountered an Error'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
