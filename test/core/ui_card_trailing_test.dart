import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

void main() {
  group('UiCard trailing alignment tests', () {
    testWidgets(
      'places trailing action on the right side of card header on wide viewports',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 800,
                  child: UiCard(
                    title: 'Magnificent seven',
                    trailing: UiButton(
                      label: 'View all',
                      variant: UiVariant.ghost,
                      onPressed: () {},
                    ),
                    child: const SizedBox(
                      height: 100,
                      child: Text('Card Content'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final cardRect = tester.getRect(find.byType(UiCard));
        final titleRect = tester.getRect(find.text('Magnificent seven'));
        final buttonRect = tester.getRect(
          find.widgetWithText(UiButton, 'View all'),
        );

        // Title is on the left
        expect(titleRect.left, greaterThanOrEqualTo(cardRect.left));
        // Trailing button is pushed to the right side of the card (near cardRect.right)
        expect(
          buttonRect.right,
          greaterThan(cardRect.left + cardRect.width * 0.85),
        );
        expect(buttonRect.right, lessThanOrEqualTo(cardRect.right));
        // Title and trailing button are vertically aligned in the header row
        expect(
          (titleRect.center.dy - buttonRect.center.dy).abs(),
          lessThan(10.0),
        );
      },
    );

    testWidgets(
      'places trailing action on the right side of card header on narrow viewports',
      (tester) async {
        tester.view.physicalSize = const Size(360, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: UiCard(
                    title: 'Magnificent seven',
                    trailing: UiButton(
                      label: 'View all',
                      variant: UiVariant.ghost,
                      onPressed: () {},
                    ),
                    child: const SizedBox(
                      height: 100,
                      child: Text('Card Content'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final cardRect = tester.getRect(find.byType(UiCard));
        final buttonRect = tester.getRect(
          find.widgetWithText(UiButton, 'View all'),
        );

        // In narrow viewport, trailing is aligned to the right (near cardRect.right)
        expect(
          buttonRect.right,
          greaterThan(cardRect.left + cardRect.width * 0.6),
        );
        expect(buttonRect.right, lessThanOrEqualTo(cardRect.right));
      },
    );
  });
}
