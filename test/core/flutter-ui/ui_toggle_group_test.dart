import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/blocks/desk_blocks.dart';
import 'package:alphajournal/core/app-ui/theme/app_tokens.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

void main() {
  group('AppWorkspaceCalendarBar layout', () {
    testWidgets('renders month and jumps toggle to the right side', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                child: AppWorkspaceCalendarBar(
                  selectedDay: DateTime(2026, 10, 27),
                  isMonthView: false,
                  onToggleView: (_) {},
                  onJumpToday: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('October 2026'), findsOneWidget);
      expect(find.byType(UiToggleGroup<bool>), findsOneWidget);

      final rowFinder = find.byType(Row);
      expect(rowFinder, findsWidgets);

      // Verify toggle button is positioned to the right of the month label
      final monthTopLeft = tester.getTopLeft(find.text('October 2026'));
      final toggleTopLeft = tester.getTopLeft(find.byType(UiToggleGroup<bool>));
      expect(toggleTopLeft.dx, greaterThan(monthTopLeft.dx + 100));
    });

    testWidgets('renders without overflow on narrow 320px screen', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: AppWorkspaceCalendarBar(
                selectedDay: DateTime(2026, 10, 1),
                isMonthView: false,
                onToggleView: (_) {},
                onJumpToday: () {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.byType(UiToggleGroup<bool>), findsOneWidget);
    });
  });
  group('UiToggleGroup expanded border radius', () {
    testWidgets('1 item expanded has all corners rounded', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: UiToggleGroup<int>(
                  value: 1,
                  expand: true,
                  options: const <UiToggleOption<int>>[
                    UiToggleOption<int>(value: 1, label: 'One'),
                  ],
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      final containers = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(containers.isNotEmpty, isTrue);
      final decoration = containers.first.decoration as BoxDecoration;
      final borderRadius = decoration.borderRadius as BorderRadius;
      expect(borderRadius.topLeft.x, greaterThan(0));
      expect(borderRadius.topRight.x, greaterThan(0));
      expect(borderRadius.bottomLeft.x, greaterThan(0));
      expect(borderRadius.bottomRight.x, greaterThan(0));
    });

    testWidgets('2 items expanded: item 1 rounded left, item 2 rounded right', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: UiToggleGroup<int>(
                  value: 1,
                  expand: true,
                  options: const <UiToggleOption<int>>[
                    UiToggleOption<int>(value: 1, label: 'One'),
                    UiToggleOption<int>(value: 2, label: 'Two'),
                  ],
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      final containers = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .toList();
      expect(containers.length, 2);

      // Item 1: Left rounded, right square
      final b1 =
          (containers[0].decoration as BoxDecoration).borderRadius
              as BorderRadius;
      expect(b1.topLeft.x, greaterThan(0));
      expect(b1.bottomLeft.x, greaterThan(0));
      expect(b1.topRight.x, equals(0));
      expect(b1.bottomRight.x, equals(0));

      // Item 2: Right rounded, left square
      final b2 =
          (containers[1].decoration as BoxDecoration).borderRadius
              as BorderRadius;
      expect(b2.topLeft.x, equals(0));
      expect(b2.bottomLeft.x, equals(0));
      expect(b2.topRight.x, greaterThan(0));
      expect(b2.bottomRight.x, greaterThan(0));
    });

    testWidgets(
      '3 items expanded: item 1 left, item 2 square (zero), item 3 right',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: UiToggleGroup<int>(
                    value: 1,
                    expand: true,
                    options: const <UiToggleOption<int>>[
                      UiToggleOption<int>(value: 1, label: 'One'),
                      UiToggleOption<int>(value: 2, label: 'Two'),
                      UiToggleOption<int>(value: 3, label: 'Three'),
                    ],
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );

        final containers = tester
            .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
            .toList();
        expect(containers.length, 3);

        // Item 1: Left rounded, right square
        final b1 =
            (containers[0].decoration as BoxDecoration).borderRadius
                as BorderRadius;
        expect(b1.topLeft.x, greaterThan(0));
        expect(b1.bottomLeft.x, greaterThan(0));
        expect(b1.topRight.x, equals(0));
        expect(b1.bottomRight.x, equals(0));

        // Item 2: All corners square (0)
        final b2 =
            (containers[1].decoration as BoxDecoration).borderRadius
                as BorderRadius;
        expect(b2.topLeft.x, equals(0));
        expect(b2.bottomLeft.x, equals(0));
        expect(b2.topRight.x, equals(0));
        expect(b2.bottomRight.x, equals(0));

        // Item 3: Right rounded, left square
        final b3 =
            (containers[2].decoration as BoxDecoration).borderRadius
                as BorderRadius;
        expect(b3.topLeft.x, equals(0));
        expect(b3.bottomLeft.x, equals(0));
        expect(b3.topRight.x, greaterThan(0));
        expect(b3.bottomRight.x, greaterThan(0));
      },
    );

    testWidgets(
      '4 items expanded: item 1 left, items 2 & 3 square, item 4 right',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  child: UiToggleGroup<int>(
                    value: 1,
                    expand: true,
                    options: const <UiToggleOption<int>>[
                      UiToggleOption<int>(value: 1, label: 'One'),
                      UiToggleOption<int>(value: 2, label: 'Two'),
                      UiToggleOption<int>(value: 3, label: 'Three'),
                      UiToggleOption<int>(value: 4, label: 'Four'),
                    ],
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );

        final containers = tester
            .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
            .toList();
        expect(containers.length, 4);

        // Item 1
        final b1 =
            (containers[0].decoration as BoxDecoration).borderRadius
                as BorderRadius;
        expect(b1.topLeft.x, greaterThan(0));
        expect(b1.bottomLeft.x, greaterThan(0));
        expect(b1.topRight.x, equals(0));
        expect(b1.bottomRight.x, equals(0));

        // Item 2
        final b2 =
            (containers[1].decoration as BoxDecoration).borderRadius
                as BorderRadius;
        expect(b2.topLeft.x, equals(0));
        expect(b2.bottomLeft.x, equals(0));
        expect(b2.topRight.x, equals(0));
        expect(b2.bottomRight.x, equals(0));

        // Item 3
        final b3 =
            (containers[2].decoration as BoxDecoration).borderRadius
                as BorderRadius;
        expect(b3.topLeft.x, equals(0));
        expect(b3.bottomLeft.x, equals(0));
        expect(b3.topRight.x, equals(0));
        expect(b3.bottomRight.x, equals(0));

        // Item 4
        final b4 =
            (containers[3].decoration as BoxDecoration).borderRadius
                as BorderRadius;
        expect(b4.topLeft.x, equals(0));
        expect(b4.bottomLeft.x, equals(0));
        expect(b4.topRight.x, greaterThan(0));
        expect(b4.bottomRight.x, greaterThan(0));
      },
    );
  });

  group('AppTokens timezone-safe date methods', () {
    test('dateOnly and isSameDay handle UTC and local datetimes correctly', () {
      final nowUtc = DateTime.utc(2026, 10, 27, 3, 30);
      final nowLocal = nowUtc.toLocal();

      expect(AppTokens.isSameDay(nowUtc, nowLocal), isTrue);
      expect(AppTokens.dateOnly(nowUtc), equals(AppTokens.dateOnly(nowLocal)));
    });
  });
}
