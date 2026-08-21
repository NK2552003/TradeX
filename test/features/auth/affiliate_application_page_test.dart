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

  testWidgets(
    'affiliate application logo and title match forgot password page styling',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        UiApp(
          theme: UiTheme.dark(),
          builder: (BuildContext context) => const MaterialApp(
            home: AffiliateApplicationPage(
              userId: 'test_user',
              email: 'test@tradex.test',
              displayName: 'Test User',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pump();

      final Finder logoFinder = find.byType(AppLogoMark);
      expect(logoFinder, findsOneWidget);
      final AppLogoMark logo = tester.widget<AppLogoMark>(logoFinder);
      expect(logo.size, 20.0);

      final Finder titleFinder = find.text('Complete Affiliate Application');
      expect(titleFinder, findsOneWidget);
      final Text titleText = tester.widget<Text>(titleFinder);
      expect(titleText.style?.fontSize, 28.0);
      expect(titleText.style?.fontWeight, FontWeight.w400);

      final Finder subtitleFinder = find.text(
        'Your trading account remains active while the TradeX team reviews this application.',
      );
      expect(subtitleFinder, findsOneWidget);
      final Text subtitleText = tester.widget<Text>(subtitleFinder);
      expect(subtitleText.style?.fontSize, 13.5);
    },
  );

  testWidgets(
    'renders single-row progress bar on mobile and UiStepper on desktop',
    (WidgetTester tester) async {
      // 1. Mobile (390px) test
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UiApp(
          theme: UiTheme.dark(),
          builder: (BuildContext context) => const MaterialApp(
            home: AffiliateApplicationPage(
              userId: 'test_user',
              email: 'test@tradex.test',
              displayName: 'Test User',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pump();

      // On mobile, UiStepper is hidden in favor of unified brand bar + modern segmented progress
      expect(find.byType(UiStepper), findsNothing);
      expect(find.text('STEP 1 OF 4'), findsOneWidget);

      // Only one main UiCard is rendered, no nested UiCard inside form
      expect(find.byType(UiCard), findsOneWidget);

      // 2. Desktop (1024px) test
      tester.view.physicalSize = const Size(1024, 768);
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pump();

      expect(find.byType(UiStepper), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('Presence'), findsOneWidget);
      expect(find.text('Payout'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
    },
  );
}
