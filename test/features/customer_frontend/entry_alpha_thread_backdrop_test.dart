import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tradex/core/app-ui/brand/alpha_thread.dart';
import 'package:tradex/features/auth/presentation/pages/get_started_page.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('GetStartedPage AlphaThreadBackdrop', () {
    testWidgets('mobile viewport (< 700) renders top and bottom ribbons (allSides: true)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: GetStartedPage(
            onGetStarted: (_) {},
            onSignIn: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final backdropFinder = find.byType(AlphaThreadBackdrop);
      expect(backdropFinder, findsOneWidget);

      final AlphaThreadBackdrop backdrop = tester.widget(backdropFinder);
      expect(backdrop.allSides, isTrue);

      // On mobile (< 700), AlphaThreadBackdrop renders 2 ribbons (top and bottom)
      final threads = find.byType(AlphaThread);
      expect(threads, findsNWidgets(2));
    });

    testWidgets('desktop viewport (>= 700) renders ribbons on all four sides', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: GetStartedPage(
            onGetStarted: (_) {},
            onSignIn: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final backdropFinder = find.byType(AlphaThreadBackdrop);
      expect(backdropFinder, findsOneWidget);

      final AlphaThreadBackdrop backdrop = tester.widget(backdropFinder);
      expect(backdrop.allSides, isTrue);

      // On desktop (>= 700), AlphaThreadBackdrop renders 4 ribbons (top, bottom, left, right)
      final threads = find.byType(AlphaThread);
      expect(threads, findsNWidgets(4));
    });
  });
}

