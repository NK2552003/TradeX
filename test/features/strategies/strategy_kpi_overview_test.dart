import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';

void main() {
  testWidgets('DeskStatsOverview cards have identical heights on desktop', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final card1 = DeskStatCardData(
      title: 'PLAYBOOK INVENTORY',
      customMetric: const Text('0 Active of 0 total'),
      customBottom: const Text('0 Live • 0 Testing • 0 Draft'),
    );
    final card2 = DeskStatCardData(
      title: 'BEST PERFORMING SETUP',
      customMetric: const Text('None yet'),
      customBottom: const Text('Win Rate: —'),
    );
    final card3 = DeskStatCardData(
      title: 'DISCIPLINE / RULE ADHERENCE',
      customMetric: const Text('100.0% Follow-through'),
      customBottom: const Text('Checklist logged 0 trades logged'),
    );
    final card4 = DeskStatCardData(
      title: 'ALLOCATED CAPITAL & TARGET R:R',
      customMetric: const Text('0 Trades in active play'),
      customBottom: const Text('Target Reward / Risk 1 : 2.4 Avg R:R'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: DeskStatsOverview(
              maxWidth: 1200,
              stats: [card1, card2, card3, card4],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cardFinders = find.byType(UiCard);
    expect(cardFinders, findsNWidgets(4));

    final h1 = tester.getSize(cardFinders.at(0)).height;
    final h2 = tester.getSize(cardFinders.at(1)).height;
    final h3 = tester.getSize(cardFinders.at(2)).height;
    final h4 = tester.getSize(cardFinders.at(3)).height;

    expect(h1, equals(h2));
    expect(h2, equals(h3));
    expect(h3, equals(h4));
    expect(h1, greaterThanOrEqualTo(84.0));
  });
}
