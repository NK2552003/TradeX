import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/widgets/app_scaffold.dart';
import 'package:tradex/features/ai_assistant/presentation/ai_assistant_root_screen.dart';
import 'package:tradex/features/market_data/presentation/market_root_screen.dart';
import 'package:tradex/features/messages/presentation/messages_root_screen.dart';

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
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MarketRootScreen), findsOneWidget);
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

      expect(find.byType(AiAssistantRootScreen), findsOneWidget);
    });
  });
}
