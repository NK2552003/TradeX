import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/settings/presentation/pages/shared/profile_settings_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/settings_root_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/trader_profile_preview_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Profile Settings & Preview Overflow Fixes', () {
    testWidgets(
      'Affiliate Profile Step 4 renders without overflow on narrow mobile screen',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          UiApp(
            theme: UiTheme.dark(),
            builder: (BuildContext context) => const MaterialApp(
              home: Scaffold(
                body: ProfileSettingsPage(
                  userRole: UserRole.affiliate,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Verify Step 4 elements are present
        expect(
          find.text('Step 4: Referral Portal, Terms & Visibility', skipOffstage: false),
          findsOneWidget,
        );
        expect(find.text('Custom Referral Code', skipOffstage: false), findsOneWidget);
        expect(find.text('Commission Tier Status', skipOffstage: false), findsOneWidget);
        expect(
          find.text('Tier 2 · Gold Partner (30%)', skipOffstage: false),
          findsOneWidget,
        );

        // Verify zero overflow exceptions
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Customer Profile renders all responsive rows without overflow on narrow mobile screen',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          UiApp(
            theme: UiTheme.dark(),
            builder: (BuildContext context) => const MaterialApp(
              home: Scaffold(
                body: ProfileSettingsPage(
                  userRole: UserRole.customer,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('Location / City', skipOffstage: false), findsOneWidget);
        expect(find.text('Website / Profile Link', skipOffstage: false), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    for (final double width in <double>[320, 360, 375, 390, 414, 768, 1024, 1280, 1440]) {
      testWidgets(
        'Admin Command Center & Analytics Preview cards render without overflow at ${width.toInt()}px',
        (WidgetTester tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            UiApp(
              theme: UiTheme.dark(),
              builder: (BuildContext context) => const MaterialApp(
                home: Scaffold(
                  body: TraderProfilePreviewPage(
                    displayName: 'System Administrator',
                    handle: 'root_admin',
                    userRole: UserRole.userAdmin,
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();

          // Verify Admin Command Center metric cards
          expect(find.text('Firm killswitch', skipOffstage: false), findsOneWidget);
          expect(find.text('Matching latency', skipOffstage: false), findsOneWidget);
          expect(find.text('Active terminals', skipOffstage: false), findsOneWidget);
          expect(find.text('Order throughput', skipOffstage: false), findsOneWidget);

          // Tap on Analytics tab to test Analytics preview cards
          final Finder analyticsTab = find.text('Analytics');
          if (analyticsTab.evaluate().isNotEmpty) {
            await tester.tap(analyticsTab);
            await tester.pumpAndSettle();
            expect(find.text('Firm-wide daily volume', skipOffstage: false), findsOneWidget);
            expect(find.text('Matching gateway latency', skipOffstage: false), findsOneWidget);
            expect(find.text('Order match execution rate', skipOffstage: false), findsOneWidget);
            expect(find.text('Server infrastructure load', skipOffstage: false), findsOneWidget);
          }

          // Verify zero bottom or right overflow exceptions
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'Profile preview action buttons are positioned to the right of avatar without overlapping across all roles',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        for (final UserRole role in UserRole.values) {
          await tester.pumpWidget(
            UiApp(
              theme: UiTheme.dark(),
              builder: (BuildContext context) => MaterialApp(
                home: Scaffold(
                  body: TraderProfilePreviewPage(
                    displayName: 'Nitish Kumar',
                    handle: 'nitish_trader',
                    userRole: role,
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pumpAndSettle();

          final Finder avatarFinder = find.byType(UiAvatar).first;
          final Rect avatarRect = tester.getRect(avatarFinder);

          // Find the action button (Root Terminal for admin, Follow for customer, Subscribe for affiliate)
          final String buttonLabel = switch (role) {
            UserRole.userAdmin => 'Root Terminal',
            UserRole.affiliate => 'Subscribe',
            UserRole.customer => 'Follow',
          };
          final Finder buttonFinder = find.text(buttonLabel);
          expect(buttonFinder, findsOneWidget);
          final Rect buttonRect = tester.getRect(buttonFinder);

          // Assert that the button is positioned strictly to the right of the avatar
          expect(buttonRect.left, greaterThan(avatarRect.right));
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'Desktop view opens blocked users in a right side sheet overlay without replacing content',
      (WidgetTester tester) async {
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
                  initialSectionId: 'privacy',
                  showNavigationPane: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('Blocked Users'), findsOneWidget);
        await tester.tap(find.text('Blocked Users'));
        await tester.pumpAndSettle();

        // On desktop, the side sheet overlay is rendered
        expect(find.byKey(const ValueKey<String>('settings-side-sheet-surface')), findsOneWidget);
        // And the underlying privacy settings page is still present underneath the overlay
        expect(find.text('Journal & Profile Visibility'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Mobile view opens blocked users inline inside the content container',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          UiApp(
            theme: UiTheme.dark(),
            builder: (BuildContext context) => const MaterialApp(
              home: Scaffold(
                body: SettingsRootPage(
                  initialSectionId: 'privacy',
                  showNavigationPane: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('Blocked Users'), findsOneWidget);
        await tester.tap(find.text('Blocked Users'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // On mobile, renders inline in the stack without the side sheet overlay
        expect(find.byKey(const ValueKey<String>('settings-side-sheet-surface')), findsNothing);
        expect(find.text('@spammer_bot99'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
