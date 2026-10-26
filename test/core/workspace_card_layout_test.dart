import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/ai_assistant/presentation/widgets/ai_create_action_card.dart';

void main() {
  testWidgets('card grid uses the pane width for two desktop action columns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 530,
              child: UiCardGrid(
                minTileWidth: 230,
                largeColumns: 2,
                children: const [
                  SizedBox(key: ValueKey('first'), height: 120),
                  SizedBox(key: ValueKey('second'), height: 120),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final first = tester.getRect(find.byKey(const ValueKey('first')));
    final second = tester.getRect(find.byKey(const ValueKey('second')));
    expect(first.top, second.top);
    expect(second.left, greaterThan(first.right));
    expect(second.right, lessThanOrEqualTo(530));
    expect(tester.takeException(), isNull);
  });

  for (final target in AiCreateTarget.values) {
    testWidgets('${target.label} remains actionable in a narrow desktop rail', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 280,
                child: AiCreateActionCard(
                  target: target,
                  onTap: () => tapped = true,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final title = tester.widget<Text>(find.text(target.label).first);
      expect(title.maxLines, isNull);
      await tester.tap(find.byType(AiCreateActionCard));
      expect(tapped, isTrue);
    });
  }
}
