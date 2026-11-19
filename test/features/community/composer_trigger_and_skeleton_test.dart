import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/flutter-ui/components/ui_skeleton.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_composer_card.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_composer_trigger_card.dart';

void main() {
  group('CommunityComposerTriggerCard Tests', () {
    testWidgets(
      'renders input pill without profile avatar and displays all action options',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        ComposerMode? selectedMode;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CommunityComposerTriggerCard(
                onTap: (ComposerMode mode) => selectedMode = mode,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check placeholder text
        expect(
          find.text('Start a post, share a setup, or ask the community...'),
          findsOneWidget,
        );

        // Verify action options exist
        expect(find.text('Trade Setup'), findsOneWidget);
        expect(find.text('Market Thesis'), findsOneWidget);
        expect(find.text('Chart / Media'), findsOneWidget);
        expect(find.text('Write Article'), findsOneWidget);
        expect(find.text('Post'), findsOneWidget);

        // Verify tapping input pill triggers onTap with ComposerMode.post
        await tester.tap(
          find.text('Start a post, share a setup, or ask the community...'),
        );
        expect(selectedMode, equals(ComposerMode.post));

        // Verify tapping Trade Setup triggers onTap with ComposerMode.tradeSetup
        await tester.tap(find.text('Trade Setup'));
        expect(selectedMode, equals(ComposerMode.tradeSetup));

        // Verify tapping Chart / Media triggers onTap with ComposerMode.chart
        await tester.tap(find.text('Chart / Media'));
        expect(selectedMode, equals(ComposerMode.chart));

        // Verify tapping Write Article triggers onTap with ComposerMode.attachment
        await tester.tap(find.text('Write Article'));
        expect(selectedMode, equals(ComposerMode.attachment));
      },
    );
  });

  group('UiSkeleton.community Tests', () {
    testWidgets(
      'renders community skeleton on desktop layout without overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: UiSkeleton.community())),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'renders community skeleton on mobile layout without overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: UiSkeleton.community())),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
