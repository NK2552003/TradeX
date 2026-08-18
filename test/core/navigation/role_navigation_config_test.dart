import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_dock/quiet_dock.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/navigation/role_navigation_config.dart';
import 'package:tradex/core/widgets/app_scaffold.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/settings/presentation/pages/shared/help_about_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/appearance_settings_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/profile_settings_page.dart';
import 'package:tradex/features/settings/presentation/pages/shared/settings_root_page.dart';
import 'package:tradex/features/settings/presentation/pages/trader/change_plan_page.dart';
import 'package:tradex/features/settings/data/repositories/billing_settings_repository.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_side_sheet.dart';

void main() {
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

    expect(find.text('Affiliate Settings'), findsOneWidget);
    expect(find.text('Payouts'), findsOneWidget);
    expect(find.text('Compliance'), findsNothing);
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

    expect(find.byType(AppLogo), findsOneWidget);
    final AppLogo mobileLogo = tester.widget<AppLogo>(find.byType(AppLogo));
    expect(mobileLogo.markRounded, isFalse);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.byTooltip('AI Assistant'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsNothing);
    expect(find.text('Settings'), findsNothing);
    expect(find.bySemanticsLabel('Settings'), findsOneWidget);

    final QuietDock dock = tester.widget<QuietDock>(find.byType(QuietDock));
    expect(dock.theme.radius, 28);
    expect(dock.theme.indicatorRadius, 24);
    final Finder headerSurface = find.byKey(
      const ValueKey<String>('app-header-surface'),
    );
    expect(tester.getTopLeft(headerSurface).dx, greaterThan(0));
    expect(tester.getTopRight(headerSurface).dx, lessThan(390));
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

    await tester.tap(find.bySemanticsLabel('Journal'));
    await tester.pumpAndSettle();
    expect(find.text('Trade Journal'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Account & Security'), findsOneWidget);
    expect(find.byType(QuietDockScaffold), findsOneWidget);
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
    expect(find.text('TradeX Basic'), findsOneWidget);
    expect(find.text('Basic Plan'), findsOneWidget);

    await pumpTier(AppTier.premium);
    await tester.pump();
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
}
