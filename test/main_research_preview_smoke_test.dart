import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/widgets/app_scaffold.dart';
import 'package:alphajournal/features/copilot/copilot.dart';
import 'package:alphajournal/features/market_data/presentation/market_root_screen.dart';
import 'package:alphajournal/features/messages/presentation/messages_root_screen.dart';

void main() {
  group('Research Preview & AppScaffold Smoke Tests', () {
    testWidgets('mounts AppScaffold with Market destination successfully', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        UiApp(
          theme: UiTheme.dark(),
          builder: (context) => MaterialApp(
            theme: UiTheme.dark().toThemeData(),
            home: const AppScaffold(
              initialDestination: 'market',
              userDisplayName: 'Demo User',
              subscriptionTier: AppTier.premium,
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();

      expect(find.byType(MarketRootScreen), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is UiInput &&
              widget.hintText == 'Search market news, companies, symbols...',
        ),
        findsOneWidget,
      );
    });

    testWidgets('mounts AppScaffold with Messages destination successfully', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        UiApp(
          theme: UiTheme.dark(),
          builder: (context) => MaterialApp(
            theme: UiTheme.dark().toThemeData(),
            home: const AppScaffold(
              initialDestination: 'messages',
              userDisplayName: 'Demo User',
              subscriptionTier: AppTier.premium,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MessagesRootScreen), findsOneWidget);
    });

    testWidgets('mounts AppScaffold with AI destination successfully', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        UiApp(
          theme: UiTheme.dark(),
          builder: (context) => MaterialApp(
            theme: UiTheme.dark().toThemeData(),
            home: const AppScaffold(
              initialDestination: 'ai_copilot',
              userDisplayName: 'Demo User',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CopilotScreen), findsOneWidget);
    });
  });
}
