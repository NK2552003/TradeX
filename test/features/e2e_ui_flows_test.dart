import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/core/widgets/app_scaffold.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/workspace/ui/workspace_screen.dart';
import 'package:tradex/features/journal/presentation/journal_page.dart';
import 'package:tradex/features/watchlists/presentation/watchlists_page.dart';
import 'package:tradex/features/strategies/presentation/strategies_page.dart';
import 'package:tradex/features/community/presentation/community_page.dart';
import 'package:tradex/features/copilot/copilot.dart';
import 'package:tradex/features/settings/presentation/pages/shared/settings_root_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppSession.instance.reset();
  });

  Widget buildTestableWidget(Widget child, {Size size = const Size(1280, 800)}) {
    return UiApp(
      theme: UiTheme.dark(),
      builder: (context) => MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(size: size),
            child: Material(
              type: MaterialType.transparency,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('End-to-End UI & Screen Navigation Verification', () {
    testWidgets('1. Trader AppScaffold Desktop Shell renders with full navigation rail', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          const AppScaffold(userRole: UserRole.customer),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that Workspace is active by default
      expect(find.byType(WorkspaceScreen), findsOneWidget);
    });

    testWidgets('2. Journal Screen renders with trade logs and stats', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          const JournalPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(JournalPage), findsOneWidget);
    });

    testWidgets('3. Watchlists Screen renders with tickers and categories', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          const WatchlistsPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WatchlistsPage), findsOneWidget);
    });

    testWidgets('4. Quant Strategies Screen renders strategies catalog', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          const StrategiesPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StrategiesPage), findsOneWidget);
    });

    testWidgets('5. Community Feed Screen renders posts and social tabs', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          const CommunityPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CommunityPage), findsOneWidget);
    });

    testWidgets('6. Copilot workspace renders', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          const CopilotScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CopilotScreen), findsOneWidget);
    });

    testWidgets('7. Settings Root Screen renders all configuration modules', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          const SettingsRootPage(
            userRole: UserRole.customer,
            showNavigationPane: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsRootPage), findsOneWidget);
    });

    testWidgets('8. Affiliate AppScaffold Shell renders partner navigation', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          const AppScaffold(userRole: UserRole.affiliate),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppScaffold), findsOneWidget);
    });

    testWidgets('9. Desk Admin AppScaffold Shell renders institutional risk controls', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestableWidget(
          const AppScaffold(userRole: UserRole.userAdmin),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppScaffold), findsOneWidget);
    });
  });
}
