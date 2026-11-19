import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

Widget host(Widget child, {bool reduced = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(800, 600),
      disableAnimations: reduced,
    ),
    child: Scaffold(body: child),
  ),
);

void main() {
  for (final reduced in [false, true]) {
    testWidgets('reveal opens and closes with reduced motion $reduced', (
      tester,
    ) async {
      var open = false;
      late StateSetter update;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Column(
                children: [
                  UiReveal(
                    key: const ValueKey('reveal'),
                    child: open
                        ? const SizedBox(height: 200, child: Text('Discussion'))
                        : null,
                  ),
                ],
              );
            },
          ),
          reduced: reduced,
        ),
      );
      final region = find.byKey(const ValueKey('reveal'));
      update(() => open = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(
        tester.getSize(region).height,
        reduced ? equals(200) : inExclusiveRange(0, 200),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(region).height, 200);
      update(() => open = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester.getSize(region).height,
        reduced ? equals(0) : inExclusiveRange(0, 200),
      );
      // Reversing midway must not leave a stale removal callback behind.
      update(() => open = true);
      await tester.pumpAndSettle();
      expect(tester.getSize(region).height, 200);
      update(() => open = false);
      await tester.pumpAndSettle();
      expect(find.text('Discussion'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'menu selection fires once and finishes its exit before removal',
    (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        host(
          UiDropdownMenu(
            items: [
              UiMenuItem(label: 'Choose reaction', onTap: () => selected++),
            ],
            child: const Text('Open menu'),
          ),
        ),
      );
      await tester.tap(find.byType(UiDropdownMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose reaction'));
      await tester.pump();
      expect(selected, 1);
      expect(find.text('Choose reaction'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('Choose reaction'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Choose reaction'), findsNothing);
      await tester.tap(find.byType(UiDropdownMenu));
      await tester.pump(const Duration(milliseconds: 30));
      // Unmounting during entrance must safely remove the overlay and ticker.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dialog result waits for the closing transition', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => UiButton(
            label: 'Open dialog',
            onPressed: () async {
              await UiDialog.show<void>(
                context,
                child: const UiDialog(title: 'Reactions'),
              );
              completed = true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(completed, isFalse);
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(find.text('Reactions'), findsNothing);
  });
}
