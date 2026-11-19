import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/messages/presentation/widgets/message_composer.dart';

void main() {
  testWidgets(
    'composer returns above the dock when the keyboard is dismissed',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            sections: const [],
            selectedId: 'messages',
            hideMobileTopBar: true,
            mobilePrimaryItems: const [
              AppNavItem(id: 'messages', label: 'Messages', icon: Icons.forum),
              AppNavItem(id: 'overview', label: 'Home', icon: Icons.home),
            ],
            onSelect: (_) {},
            child: Column(
              children: [
                const Spacer(),
                MessageComposer(threadId: 'keyboard-test', onSendText: (_) {}),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final composer = find.byType(MessageComposer);
      final field = find.descendant(
        of: composer,
        matching: find.byType(TextField),
      );
      final initialBottom = tester.getBottomLeft(composer).dy;
      expect(initialBottom, 844);
      await tester.enterText(field, 'Unsent draft');
      await tester.pumpAndSettle();
      final initialField = tester.getRect(field);
      expect(initialField.bottom, lessThanOrEqualTo(844 - 56 - 16 - 24));

      // Opening, partially swiping back, cancelling, then completing the swipe.
      for (final inset in [300.0, 150.0, 300.0, 120.0, 0.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        tester.view.padding = FakeViewPadding(bottom: inset == 0 ? 24 : 0);
        await tester.pump();
        expect(
          tester.getBottomLeft(composer).dy,
          inset > 0 ? 844 - inset : initialBottom,
        );
        final fieldContext = tester.element(field);
        expect(MediaQuery.viewInsetsOf(fieldContext).bottom, 0);
        if (inset > 0) {
          expect(MediaQuery.viewPaddingOf(fieldContext).bottom, 0);
        }
      }
      expect(tester.getRect(field), initialField);
      expect(tester.widget<TextField>(field).controller!.text, 'Unsent draft');
      expect(tester.takeException(), isNull);
    },
  );
}
