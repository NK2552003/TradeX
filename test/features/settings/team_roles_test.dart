import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/settings/presentation/pages/admin/team_roles_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/settings_root_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final double width in <double>[320, 360, 375, 390, 414]) {
    testWidgets('TeamRolesPage renders members list without overflow at ${width.toInt()}px', (WidgetTester tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UiApp(
          theme: UiTheme.dark(),
          builder: (BuildContext context) => const MaterialApp(
            home: Scaffold(
              body: TeamRolesPage(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('3 Active Desk Members'), findsOneWidget);
      expect(find.text('Nitish Kumar (Owner)'), findsOneWidget);
      expect(find.text('Sarah Jenkins'), findsOneWidget);
      expect(find.text('Marcus Vance'), findsOneWidget);
      expect(find.text('OWNER'), findsOneWidget);
      expect(find.text('ADMIN'), findsWidgets);
      expect(find.text('TRADER'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Admin Settings Organization & Team opens Team & Roles on desktop side sheet overlay', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => const MaterialApp(
          home: Scaffold(
            body: SettingsRootPage(
              userRole: UserRole.userAdmin,
              initialSectionId: 'organization',
              showNavigationPane: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Team & Roles'), findsOneWidget);
    await tester.tap(find.text('Team & Roles'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Team Directory & Roles'), findsOneWidget);
    expect(find.text('3 Active Desk Members'), findsOneWidget);
    expect(find.text('Nitish Kumar (Owner)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
