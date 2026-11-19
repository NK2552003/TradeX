import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';

void main() {
  testWidgets(
    'a form card has a normal cursor and its input remains editable',
    (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: UiCard(
                  child: UiInput(controller: controller, hintText: 'Email'),
                ),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: 1,
      );
      await mouse.addPointer(location: Offset.zero);
      final card = tester.getRect(find.byType(UiCard));
      await mouse.moveTo(card.topLeft + const Offset(4, 4));
      await tester.pump();
      expect(
        tester.binding.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.basic,
      );
      await mouse.moveTo(tester.getCenter(find.byType(TextField)));
      await tester.pump();
      expect(
        tester.binding.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.text,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      await tester.enterText(find.byType(TextField), 'trader@example.com');
      expect(controller.text, 'trader@example.com');
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('action cards keep their enabled and disabled cursors', (
    tester,
  ) async {
    var taps = 0;
    for (final enabled in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: UiCard(
                enabled: enabled,
                onTap: () => taps++,
                child: const Text('Open item'),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: 1,
      );
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Open item')));
      await tester.pump();
      expect(
        tester.binding.mouseTracker.debugDeviceActiveCursor(1),
        enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      );
      await tester.tap(find.text('Open item'));
      await tester.pump();
      await mouse.removePointer();
    }
    expect(taps, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
