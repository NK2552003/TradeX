import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_dock/quiet_dock.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/core/navigation/role_navigation_config.dart';
import 'package:tradex/core/widgets/app_scaffold.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/settings/presentation/pages/shared/account_security_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/help_about_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/appearance_settings_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/profile_settings_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/settings_root_page.dart';
import 'package:tradex/features/settings/presentation/pages/trader/change_plan_page.dart';
import 'package:tradex/features/settings/presentation/pages/trader/trader_affiliate_perks_page.dart';
import 'package:tradex/features/settings/data/repositories/billing_settings_repository.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_side_sheet.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_nav_row.dart';

void main() {
  // Entitlement lives in a process-wide session, so a plan changed by one test
  // would otherwise decide what the next test's gates render.
  setUp(AppSession.instance.reset);

  group('RoleNavigationConfig', () {
    test('trader only exposes trader settings', () {
      final RoleNavigationConfig config = RoleNavigationConfig.forRole(
        UserRole.customer,
      );

      expect(config.allows('journal'), isTrue);
      expect(config.allows('settings_trading'), isTrue);
      expect(config.allows('settings_affiliate'), isFalse);
      expect(config.allows('settings_organization'), isFalse);
    });

    test('affiliate only exposes partner settings', () {
      final RoleNavigationConfig config = RoleNavigationConfig.forRole(
        UserRole.affiliate,
      );

      expect(config.allows('referrals'), isTrue);
      expect(config.allows('settings_affiliate'), isTrue);
      expect(config.allows('settings_trading'), isFalse);
      expect(config.allows('settings_desk_risk'), isFalse);
    });

    test('administrator only exposes institutional settings', () {
      final RoleNavigationConfig config = RoleNavigationConfig.forRole(
        UserRole.userAdmin,
      );

      expect(config.allows('org_team'), isTrue);
      expect(config.allows('settings_desk_risk'), isTrue);
      expect(config.allows('settings_trading'), isFalse);
      expect(config.allows('settings_affiliate'), isFalse);
    });

    test('every role has four persistent mobile items', () {
      for (final UserRole role in UserRole.values) {
        final RoleNavigationConfig config = RoleNavigationConfig.forRole(role);
        expect(config.mobilePrimaryItems, hasLength(4));
        expect(config.mobileMoreItems, isNotEmpty);
        expect(config.mobilePrimaryItems.last.id, 'settings');
        expect(
          config.mobilePrimaryItems.any(
            (AppNavItem item) => item.id == 'settings_profile',
          ),
          isFalse,
        );
        expect(config.allows('notifications'), isFalse);
      }
    });

    test('trader navigation uses the shortened Watchlist label', () {
      final RoleNavigationConfig config = RoleNavigationConfig.forRole(
        UserRole.customer,
      );
      final Iterable<AppNavItem> items = config.sections.expand(
        (AppNavSection section) => section.items,
      );

      expect(
        items.singleWhere((AppNavItem item) => item.id == 'watchlists').label,
        'Watchlist',
      );
    });
  });

  testWidgets('mobile dock opens the role-specific More hub', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final RoleNavigationConfig config = RoleNavigationConfig.forRole(
      UserRole.affiliate,
    );

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => MaterialApp(
          home: AppShell(
            sections: config.sections,
            selectedId: 'overview',
            mobilePrimaryItems: config.mobilePrimaryItems,
            mobileMoreItems: config.mobileMoreItems,
            onSelect: (_) {},
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    expect(find.text('Hub'), findsNothing);
    expect(find.text('Referrals'), findsNothing);
    expect(find.bySemanticsLabel('Hub'), findsOneWidget);
    expect(find.bySemanticsLabel('Referrals'), findsOneWidget);
    expect(find.text('Team'), findsNothing);

    await tester.tap(find.bySemanticsLabel('More tools'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    expect(find.text('Affiliate Settings'), findsOneWidget);
    expect(find.text('Payouts'), findsOneWidget);
    expect(find.text('Compliance'), findsNothing);
  });

  testWidgets('mobile More destination shows its icon with a change arrow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final RoleNavigationConfig config = RoleNavigationConfig.forRole(
      UserRole.customer,
    );

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => MaterialApp(
          home: AppShell(
            sections: config.sections,
            selectedId: config.mobileMoreItems.first.id,
            mobilePrimaryItems: config.mobilePrimaryItems,
            mobileMoreItems: config.mobileMoreItems,
            onSelect: (_) {},
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(config.mobileMoreItems.first.icon), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile shell uses the compact branded header and quiet dock', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final RoleNavigationConfig config = RoleNavigationConfig.forRole(
      UserRole.customer,
    );

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => MaterialApp(
          home: AppShell(
            sections: config.sections,
            selectedId: 'settings_profile',
            mobilePrimaryItems: config.mobilePrimaryItems,
            mobileMoreItems: config.mobileMoreItems,
            onSelect: (_) {},
            onSearch: () {},
            onNotifications: () {},
            onSettings: () {},
            onAi: () {},
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppLogo), findsNothing);
    expect(find.byType(AppWordmark), findsNothing);
    final AppLogoMark mobileLogo = tester.widget<AppLogoMark>(
      find.byType(AppLogoMark),
    );
    expect(mobileLogo.rounded, isFalse);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.byTooltip('AI Assistant'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsNothing);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
    expect(find.bySemanticsLabel('Settings'), findsOneWidget);

    final QuietDock dock = tester.widget<QuietDock>(find.byType(QuietDock));
    expect(dock.theme.radius, 28);
    expect(dock.theme.indicatorRadius, 24);
    final Finder headerSurface = find.byKey(
      const ValueKey<String>('app-header-surface'),
    );
    final Rect headerRect = tester.getRect(headerSurface);
    expect(headerRect.left, closeTo(headerRect.top, 0.01));
    expect(390 - headerRect.right, closeTo(headerRect.top, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile shell background follows the active theme', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final RoleNavigationConfig config = RoleNavigationConfig.forRole(
      UserRole.customer,
    );
    final UiTheme lightTheme = UiTheme.light();
    await tester.pumpWidget(
      UiApp(
        theme: lightTheme,
        builder: (BuildContext context) => MaterialApp(
          theme: lightTheme.toThemeData(),
          home: AppShell(
            sections: config.sections,
            selectedId: 'overview',
            mobilePrimaryItems: config.mobilePrimaryItems,
            mobileMoreItems: config.mobileMoreItems,
            onSelect: (_) {},
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    final ColoredBox background = tester.widget<ColoredBox>(
      find.byKey(const ValueKey<String>('app-mobile-shell-background')),
    );
    expect(background.color, lightTheme.colors.background);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile dock destinations keep their page content visible', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) =>
            const MaterialApp(home: AppScaffold()),
      ),
    );
    await tester.pumpAndSettle();

    final Finder header = find.byKey(
      const ValueKey<String>('app-header-surface'),
    );
    final Rect initialHeaderRect = tester.getRect(header);
    expect(
      find.descendant(of: header, matching: find.text('Dashboard')),
      findsOneWidget,
    );
    final Text dashboardTitle = tester.widget<Text>(
      find.descendant(of: header, matching: find.text('Dashboard')),
    );
    expect(dashboardTitle.style?.color, UiTheme.dark().colors.foreground);
    expect(dashboardTitle.style?.decoration, TextDecoration.none);
    expect(
      find.ancestor(of: header, matching: find.byType(PageView)),
      findsNothing,
    );

    await tester.tap(find.bySemanticsLabel('Journal'));
    await tester.pumpAndSettle();
    expect(find.text('Trade Journal'), findsWidgets);
    expect(
      find.descendant(of: header, matching: find.text('Trade Journal')),
      findsOneWidget,
    );
    expect(tester.getRect(header), initialHeaderRect);

    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Account & Security'), findsOneWidget);
    expect(
      find.descendant(of: header, matching: find.text('Settings')),
      findsOneWidget,
    );
    expect(tester.getRect(header), initialHeaderRect);
    expect(find.byType(QuietDockScaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile settings content finishes above the floating dock', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) =>
            const MaterialApp(home: AppScaffold()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();

    final Finder logout = find.text('Log Out of Account');
    final Finder settingsScrollView = find.ancestor(
      of: logout,
      matching: find.byType(SingleChildScrollView),
    );
    await tester.drag(settingsScrollView, const Offset(0, -2400));
    await tester.pumpAndSettle();

    final Finder logoutRow = find.ancestor(
      of: logout,
      matching: find.byType(SettingsNavRow),
    );
    final Rect logoutRect = tester.getRect(logoutRow);
    final Rect dockRect = tester.getRect(find.bySemanticsLabel('More tools'));
    expect(logoutRect.bottom, lessThanOrEqualTo(dockRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile dock yields to the keyboard inset', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    final RoleNavigationConfig config = RoleNavigationConfig.forRole(
      UserRole.customer,
    );
    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => MaterialApp(
          home: AppShell(
            sections: config.sections,
            selectedId: 'settings_profile',
            mobilePrimaryItems: config.mobilePrimaryItems,
            mobileMoreItems: config.mobileMoreItems,
            onSelect: (_) {},
            child: const UiPage(
              child: Column(
                children: <Widget>[
                  SizedBox(height: 420),
                  UiInput(hintText: 'Keyboard-safe input'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QuietDock), findsOneWidget);

    final Finder editable = find.byType(EditableText);
    await tester.ensureVisible(editable);
    await tester.showKeyboard(editable);
    await tester.pump();
    expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(find.byType(QuietDock), findsOneWidget);
    expect(tester.getSize(find.bySemanticsLabel('More tools')).height, 0);
    expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
    final MediaQueryData keyboardMediaQuery = MediaQuery.of(
      tester.element(editable),
    );
    final double keyboardTop =
        keyboardMediaQuery.size.height - keyboardMediaQuery.viewInsets.bottom;
    expect(
      tester.getRect(find.byType(SingleChildScrollView)).bottom,
      lessThanOrEqualTo(keyboardTop),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop settings side sheets float with shared corner radius', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: UiButton(
                label: 'Open panel',
                onPressed: () => showSettingsSideSheet<void>(
                  context,
                  title: 'Panel title',
                  child: const Text('Panel body'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open panel'));
    await tester.pumpAndSettle();

    final Finder surfaceFinder = find.byKey(
      const ValueKey<String>('settings-side-sheet-surface'),
    );
    final Container surface = tester.widget<Container>(surfaceFinder);
    final BoxDecoration decoration = surface.decoration! as BoxDecoration;
    final BorderRadius radius = decoration.borderRadius! as BorderRadius;
    expect(radius.topLeft.x, greaterThan(0));
    expect(radius.topRight.x, radius.topLeft.x);
    expect(tester.getTopLeft(surfaceFinder).dy, greaterThan(0));
    expect(tester.getTopRight(surfaceFinder).dx, lessThan(1440));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop settings navigation can be collapsed by its trigger', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final RoleNavigationConfig config = RoleNavigationConfig.forRole(
      UserRole.customer,
    );
    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => MaterialApp(
          home: Scaffold(
            body: AppSidebar(
              sections: config.sections,
              selectedId: 'settings_profile',
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Profile'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plan chooser renders all available plans on desktop', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) =>
            const MaterialApp(home: Scaffold(body: ChangePlanPage())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('₹0'), findsOneWidget);
    expect(find.text('₹2,499'), findsOneWidget);
    expect(find.text('₹7,999'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile exposes a rich public preview with icon verification', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) =>
            const MaterialApp(home: Scaffold(body: ProfileSettingsPage())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('VERIFIED TRADER'), findsNothing);
    expect(find.byIcon(Icons.verified_rounded), findsWidgets);
    await tester.tap(find.text('Preview Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Public profile preview'), findsOneWidget);
    expect(find.text('Posts'), findsOneWidget);
    expect(find.text('Journal'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.textContaining('NIFTY reclaimed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile toggle groups use the full available width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => MaterialApp(
          home: Scaffold(
            body: UiToggleGroup<String>(
              value: 'Dark',
              options: const <UiToggleOption<String>>[
                UiToggleOption<String>(label: 'Dark', value: 'Dark'),
                UiToggleOption<String>(label: 'Light', value: 'Light'),
                UiToggleOption<String>(label: 'System', value: 'System'),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(UiToggleGroup<String>)).width, 390);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile setting cards keep switches compact and trailing', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => MaterialApp(
          home: Scaffold(
            body: AppSettingCard(
              title: 'Trade Executions & Orders',
              description:
                  'Fills, partial fills, stop-loss triggers, and order cancellations.',
              icon: Icons.receipt_long_outlined,
              control: UiSwitch(value: true, onChanged: (_) {}),
            ),
          ),
        ),
      ),
    );

    final Rect cardRect = tester.getRect(find.byType(AppSettingCard));
    final Rect switchRect = tester.getRect(find.byType(UiSwitch));
    final Text title = tester.widget<Text>(
      find.text('Trade Executions & Orders'),
    );
    final Icon icon = tester.widget<Icon>(
      find.byIcon(Icons.receipt_long_outlined),
    );

    expect(cardRect.height, lessThan(140));
    expect(switchRect.width, lessThan(60));
    expect(switchRect.center.dx, greaterThan(cardRect.center.dx));
    expect(title.style?.fontSize, lessThanOrEqualTo(13));
    expect(icon.size, UiTheme.dark().sizes.iconSm);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appearance side sheet follows the global light theme', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final AppThemeController controller = AppThemeController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AppThemeScope(
        controller: controller,
        child: ListenableBuilder(
          listenable: controller,
          builder: (BuildContext context, Widget? child) {
            final UiTheme theme = controller.value == ThemeMode.light
                ? UiTheme.light()
                : UiTheme.dark();
            return UiApp(
              theme: theme,
              builder: (BuildContext context) => MaterialApp(
                theme: UiTheme.light().toThemeData(),
                darkTheme: UiTheme.dark().toThemeData(),
                themeMode: controller.value,
                home: Builder(
                  builder: (BuildContext context) => Scaffold(
                    body: UiButton(
                      label: 'Appearance',
                      onPressed: () => showSettingsSideSheet<void>(
                        context,
                        title: 'Appearance',
                        child: const AppearanceSettingsPage(),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    final Container surface = tester.widget<Container>(
      find.byKey(const ValueKey<String>('settings-side-sheet-surface')),
    );
    final BoxDecoration decoration = surface.decoration! as BoxDecoration;
    expect(controller.value, ThemeMode.light);
    expect(decoration.color, UiTheme.light().colors.surface);
    expect(tester.takeException(), isNull);
  });

  test('subscription repository updates its active plan dynamically', () async {
    final BillingSettingsRepository repository =
        BillingSettingsRepositoryImpl();
    await repository.startCheckout(AppTier.enterprise.name, 'annual');
    final subscription = await repository.getSubscription();
    final plans = await repository.getAvailablePlans();

    expect(subscription.tier, AppTier.enterprise);
    expect(subscription.billingCycle, 'annual');
    expect(
      plans
          .singleWhere((AppPlan plan) => plan.tier == AppTier.enterprise)
          .current,
      isTrue,
    );
  });

  testWidgets('all current settings pages pass mobile and desktop layout smoke', (
    WidgetTester tester,
  ) async {
    final AppThemeController controller = AppThemeController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    const List<({UserRole role, String section})> pages =
        <({UserRole role, String section})>[
          (role: UserRole.customer, section: 'profile'),
          (role: UserRole.customer, section: 'security'),
          (role: UserRole.customer, section: 'trading'),
          (role: UserRole.customer, section: 'billing'),
          (role: UserRole.customer, section: 'notifications'),
          (role: UserRole.customer, section: 'privacy'),
          (role: UserRole.customer, section: 'appearance'),
          (role: UserRole.customer, section: 'help'),
          (role: UserRole.affiliate, section: 'affiliate'),
          (role: UserRole.userAdmin, section: 'organization'),
          (role: UserRole.userAdmin, section: 'desk_risk'),
        ];

    for (final Size viewport in const <Size>[Size(390, 844), Size(1440, 900)]) {
      tester.view.physicalSize = viewport;
      for (final page in pages) {
        await tester.pumpWidget(
          AppThemeScope(
            controller: controller,
            child: UiApp(
              theme: UiTheme.dark(),
              builder: (BuildContext context) => MaterialApp(
                home: Scaffold(
                  body: SettingsRootPage(
                    userRole: page.role,
                    initialSectionId: page.section,
                    subscriptionTier: AppTier.premium,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason:
              '${page.role.id}/${page.section} failed at ${viewport.width.toInt()}px',
        );
      }
    }
  });

  testWidgets('help changelog opens as a constrained reusable dialog', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) =>
            const MaterialApp(home: Scaffold(body: HelpAboutPage())),
      ),
    );

    await tester.ensureVisible(find.text("View What's New"));
    await tester.tap(find.text("View What's New"));
    await tester.pumpAndSettle();

    expect(find.byType(UiDialog), findsOneWidget);
    expect(find.text("What's New in TradeX"), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('ui-dialog-surface')))
          .width,
      lessThanOrEqualTo(700),
    );
    expect(tester.takeException(), isNull);
  });

  for (final ({UserRole role, String visible, String hidden}) scenario
      in <({UserRole role, String visible, String hidden})>[
        (
          role: UserRole.customer,
          visible: 'Personal Trading & Risk Rules',
          hidden: 'Affiliate Portal & Payouts',
        ),
        (
          role: UserRole.affiliate,
          visible: 'Affiliate Portal & Payouts',
          hidden: 'Institutional Workspace & Governance',
        ),
        (
          role: UserRole.userAdmin,
          visible: 'Institutional Workspace & Governance',
          hidden: 'Personal Trading & Risk Rules',
        ),
      ]) {
    testWidgets('settings overview only shows ${scenario.role.id} options', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UiApp(
          theme: UiTheme.dark(),
          builder: (BuildContext context) => MaterialApp(
            home: Scaffold(
              body: SettingsRootPage(
                userRole: scenario.role,
                showNavigationPane: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text(scenario.visible), findsOneWidget);
      expect(find.text(scenario.hidden), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('desktop settings detail does not render a second sidebar', (
    WidgetTester tester,
  ) async {
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
              userRole: UserRole.customer,
              initialSectionId: 'privacy',
              showNavigationPane: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('Journal & Profile Visibility'), findsOneWidget);
    expect(find.text('Email & Security'), findsNothing);
    expect(find.text('Subscription & Billing'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('workspace name follows the customer subscription tier', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pumpTier(AppTier tier) => tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) =>
            MaterialApp(home: AppScaffold(subscriptionTier: tier)),
      ),
    );

    await pumpTier(AppTier.free);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('TradeX Basic'), findsOneWidget);
    expect(find.text('Basic Plan'), findsOneWidget);

    await pumpTier(AppTier.premium);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('TradeX Pro'), findsOneWidget);
    expect(find.text('Pro Plan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('header actions stay fixed when the active page changes', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final RoleNavigationConfig config = RoleNavigationConfig.forRole(
      UserRole.customer,
    );

    Future<void> pumpHeader(String selectedId) => tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => MaterialApp(
          home: Scaffold(
            body: AppTopBar(
              sections: config.sections,
              selectedId: selectedId,
              onSearch: () {},
              onNotifications: () {},
              onSettings: () {},
            ),
          ),
        ),
      ),
    );

    await pumpHeader('overview');
    final double searchX = tester
        .getTopLeft(find.text('Search symbols, orders...'))
        .dx;
    final double marketX = tester.getTopLeft(find.text('NSE/BSE LIVE')).dx;
    final double settingsX = tester.getTopLeft(find.byTooltip('Settings')).dx;

    await pumpHeader('settings_trading');
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Search symbols, orders...')).dx,
      closeTo(searchX, 0.01),
    );
    expect(
      tester.getTopLeft(find.text('NSE/BSE LIVE')).dx,
      closeTo(marketX, 0.01),
    );
    expect(
      tester.getTopLeft(find.byTooltip('Settings')).dx,
      closeTo(settingsX, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop header and content share the same right edge', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final RoleNavigationConfig config = RoleNavigationConfig.forRole(
      UserRole.customer,
    );

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => MaterialApp(
          home: AppShell(
            sections: config.sections,
            selectedId: 'overview',
            onSelect: (_) {},
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    final double headerRight = tester
        .getTopRight(find.byKey(const ValueKey<String>('app-header-surface')))
        .dx;
    final Finder contentFinder = find.byKey(
      const ValueKey<String>('app-content-surface'),
    );
    final Container content = tester.widget<Container>(contentFinder);
    final EdgeInsets contentMargin = content.margin! as EdgeInsets;
    final double contentRight =
        tester.getTopRight(contentFinder).dx - contentMargin.right;

    expect(headerRight, closeTo(contentRight, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'TraderAffiliatePerksPage renders without overflow on narrow 289px container and mobile viewport',
    (WidgetTester tester) async {
      // Test at tight 289px width
      tester.view.physicalSize = const Size(289, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UiApp(
          theme: UiTheme.dark(),
          builder: (BuildContext context) =>
              const MaterialApp(home: Scaffold(body: TraderAffiliatePerksPage())),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('TradeX Partner & Affiliate Program'), findsOneWidget);
      expect(find.text('30% REVSHARE'), findsOneWidget);
      expect(find.text('Estimated Earnings Calculator'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AppearanceSettingsPage mobile cards render full width controls and dock clearance',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final AppThemeController controller = AppThemeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        AppThemeScope(
          controller: controller,
          child: UiApp(
            theme: UiTheme.dark(),
            builder: (BuildContext context) => const MaterialApp(
              home: Scaffold(body: AppearanceSettingsPage()),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Interface Theme'), findsOneWidget);
      expect(find.text('Color Theme Mode'), findsOneWidget);
      expect(find.text('Default Financial Chart Settings'), findsOneWidget);
      expect(find.text('Primary Chart Type'), findsOneWidget);

      final SingleChildScrollView scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      final EdgeInsets padding = scrollView.padding! as EdgeInsets;
      expect(padding.bottom, greaterThanOrEqualTo(100.0));

      final selectFinder = find.byType(UiSelect<String>).first;
      final selectWidth = tester.getSize(selectFinder).width;
      expect(selectWidth, greaterThan(300.0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile settings subpage drill-in renders inside container with back navigation',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final AppThemeController controller = AppThemeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        AppThemeScope(
          controller: controller,
          child: UiApp(
            theme: UiTheme.dark(),
            builder: (BuildContext context) => const MaterialApp(
              home: AppScaffold(
                userRole: UserRole.customer,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Go to Settings tab
      await tester.tap(find.bySemanticsLabel('Settings'));
      await tester.pumpAndSettle();

      // In settings overview, tap Personal Profile
      expect(find.text('Personal Profile'), findsOneWidget);
      await tester.tap(find.text('Personal Profile'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verify that Profile subpage is rendered with top header back button and icon
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsWidgets);
      expect(find.text('Personal Profile'), findsWidgets);

      // Verify top header back button returns to settings overview
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Personal Profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile toast notifications float snugly above the quiet dock without close icon', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UiApp(
        theme: UiTheme.dark(),
        builder: (BuildContext context) => MaterialApp(
          home: UiToastScope(
            child: Builder(
              builder: (BuildContext ctx) => Scaffold(
                body: UiButton(
                  label: 'Show Toast',
                  onPressed: () => UiToast.success(
                    ctx,
                    title: 'Trade Executed',
                    message: 'Bought 10 AAPL @ \$220.00',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show Toast'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Trade Executed'), findsOneWidget);
    // Mobile toast should not render the cross / close button
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    final Rect toastRect = tester.getRect(find.byType(UiToast));
    // Toast bottom sits snugly right above dock (844 - 76 = 768)
    expect(toastRect.bottom, lessThanOrEqualTo(844 - 76.0));

    // Tap on mobile toast should dismiss it
    await tester.tap(find.byType(UiToast));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Trade Executed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'AccountSecurityPage renders on mobile without unconstrained button errors',
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
              body: AccountSecurityPage(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('Account Email'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);
      expect(find.text('Connected Accounts'), findsOneWidget);
      expect(find.text('Delete Account'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
