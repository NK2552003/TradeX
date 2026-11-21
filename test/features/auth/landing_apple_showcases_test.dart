import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_dock/quiet_dock.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/markdown_kit/markdown_kit.dart';
import 'package:alphajournal/features/auth/presentation/pages/get_started_page.dart';
import 'package:alphajournal/features/auth/presentation/pages/login_page.dart';
import 'package:alphajournal/features/auth/presentation/pages/signup_page.dart';
import 'package:alphajournal/features/auth/presentation/widgets/apple_device_frames.dart';
import 'package:alphajournal/features/auth/presentation/widgets/landing_apple_showcases.dart';
import 'package:alphajournal/features/auth/widgets/auth_carousel_panel.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.dark}) {
  return UiThemeScope(
    theme: brightness == Brightness.dark ? UiTheme.dark() : UiTheme.light(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(24), child: child),
        ),
      ),
    ),
  );
}

void _setDesktop(WidgetTester tester, {double width = 1440}) {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'GetStartedPage removes Built for Traders & Affiliates and solutions nav link',
    (WidgetTester tester) async {
      _setDesktop(tester);
      await tester.pumpWidget(
        UiThemeScope(
          theme: UiTheme.dark(),
          child: MaterialApp(
            home: GetStartedPage(onGetStarted: (_) {}, onSignIn: () {}),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Built for Traders & Affiliates'), findsNothing);
      expect(find.text('Choose Your Role'), findsNothing);
      expect(find.text('Institutional Workspace at Your Fingertips'), findsNothing);
      expect(find.text('Core Features Built for Indian Markets'), findsNothing);
      expect(find.text('solutions'), findsNothing);
      expect(find.text('Trading Edge'), findsOneWidget);
      expect(find.text('engineered to compound.'), findsOneWidget);
      expect(find.text('Get started free'), findsOneWidget);
      expect(find.text('See how it works'), findsOneWidget);
      expect(find.byType(LandingHeroGridBackdrop), findsNWidgets(2));

      // Tapping the selection bounding box types the next phrase letter-by-letter
      await tester.tap(find.text('Trading Edge'));
      await tester.pump();
      expect(find.text('Trading Edge'), findsNothing);
      expect(find.text('Execution Desk'), findsNothing);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Ex'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('Execution Desk'), findsOneWidget);
      // Header starts compact at top of hero (Get started hidden) and expands on scroll
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Get started'), findsNothing);

      final ScrollableState scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(520);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Get started'), findsOneWidget);

      // Scrolling back to hero collapses the header CTA cleanly
      scrollable.position.jumpTo(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Get started'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('1. LandingAppleFeatureCarousel renders & scrolls cleanly', (
    WidgetTester tester,
  ) async {
    _setDesktop(tester);
    await tester.pumpWidget(
      _wrap(LandingAppleFeatureCarousel(onGetStarted: () {})),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Why AlphaJournal is the best'), findsOneWidget);
    expect(find.byType(AppAiMessageBubble), findsWidgets);
    expect(find.byType(AppPostCard), findsWidgets);
    final ListView listView = tester.widget<ListView>(find.byType(ListView).first);
    expect(listView.physics, isA<NeverScrollableScrollPhysics>());
    expect(tester.takeException(), isNull);
  });

  testWidgets('2. Removed Spotlight & Stacked Promo sections stay absent on landing page', (
    WidgetTester tester,
  ) async {
    _setDesktop(tester);
    await tester.pumpWidget(
      UiThemeScope(
        theme: UiTheme.dark(),
        child: MaterialApp(
          home: GetStartedPage(onGetStarted: (_) {}, onSignIn: () {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Weekly AI coaching'), findsNothing);
    expect(
      find.text('Connected Notes, Playbooks & Trade Backlinks'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('3. Hero mounts scrolling top AlphaThread above precision pulse grid & removes Spotlight section', (
    WidgetTester tester,
  ) async {
    _setDesktop(tester);
    await tester.pumpWidget(
      UiThemeScope(
        theme: UiTheme.dark(),
        child: MaterialApp(
          home: GetStartedPage(onGetStarted: (_) {}, onSignIn: () {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Connected Notes, Playbooks & Trade Backlinks'),
      findsNothing,
    );
    // Top AlphaThread lives inside the SingleChildScrollView (scrolls with content, not fixed backdrop)
    expect(find.byType(AlphaThreadBackdrop), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(AlphaThread),
      ),
      findsWidgets,
    );
    expect(find.byType(LandingHeroGridBackdrop), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '4. LandingAppleIphoneGallery renders 5 pre-rendered WebP iPhone frames for dark and light themes',
    (WidgetTester tester) async {
      _setDesktop(tester);
      await tester.pumpWidget(_wrap(const LandingAppleIphoneGallery()));
      await tester.pump();
      expect(find.byType(LandingDeviceFrameWebp), findsNWidgets(5));
      expect(find.byType(AppleIphoneSvgFrame), findsNothing);
      expect(find.byType(QuietDock), findsNothing);
      final List<LandingDeviceFrameWebp> frames = tester
          .widgetList<LandingDeviceFrameWebp>(
            find.byType(LandingDeviceFrameWebp),
          )
          .toList();
      expect(
        frames.map((f) => f.assetPathFor(Brightness.dark)).toList(),
        <String>[
          'assets/landing/iphone_community_dark.webp',
          'assets/landing/iphone_ai_copilot_dark.webp',
          'assets/landing/iphone_linked_notes_dark.webp',
          'assets/landing/iphone_markets_dark.webp',
          'assets/landing/iphone_journal_risk_dark.webp',
        ],
      );
      expect(
        frames.map((f) => f.assetPathFor(Brightness.light)).toList(),
        <String>[
          'assets/landing/iphone_community_light.webp',
          'assets/landing/iphone_ai_copilot_light.webp',
          'assets/landing/iphone_linked_notes_light.webp',
          'assets/landing/iphone_markets_light.webp',
          'assets/landing/iphone_journal_risk_light.webp',
        ],
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '5. LandingAppleIpadMosaicSection renders pre-rendered WebP iPad + mosaic cleanly',
    (WidgetTester tester) async {
      _setDesktop(tester);
      await tester.pumpWidget(_wrap(const LandingAppleIpadMosaicSection()));
      await tester.pump();
      expect(find.byType(LandingDeviceFrameWebp), findsOneWidget);
      expect(find.byType(AppleIpadSvgFrame), findsNothing);
      final LandingDeviceFrameWebp ipad = tester.widget<LandingDeviceFrameWebp>(
        find.byType(LandingDeviceFrameWebp),
      );
      expect(
        ipad.assetPathFor(Brightness.dark),
        'assets/landing/ipad_workspace_dark.webp',
      );
      expect(
        ipad.assetPathFor(Brightness.light),
        'assets/landing/ipad_workspace_light.webp',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '6. LandingAppleCenterPhoneStripSection renders pre-rendered WebP center iPhone + 6 flanking AI format cards cleanly',
    (WidgetTester tester) async {
      _setDesktop(tester);
      await tester.pumpWidget(
        _wrap(
          const LandingAppleCenterPhoneStripSection(),
          brightness: Brightness.light,
        ),
      );
      await tester.pump();
      expect(find.byType(LandingDeviceFrameWebp), findsOneWidget);
      expect(find.byType(AppleIphoneSvgFrame), findsNothing);
      expect(find.byType(QuietDock), findsNothing);
      final LandingDeviceFrameWebp phone = tester.widget<LandingDeviceFrameWebp>(
        find.byType(LandingDeviceFrameWebp),
      );
      expect(
        phone.assetPathFor(Brightness.light),
        'assets/landing/iphone_ai_quant_light.webp',
      );
      expect(find.byType(PerplexityCardBlock), findsNWidgets(4));
      expect(find.byType(ChartBlock), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('7. UiButton link variant (e.g. View all) renders without underline', (
    WidgetTester tester,
  ) async {
    _setDesktop(tester);
    await tester.pumpWidget(
      _wrap(
        UiButton(
          label: 'View all (3)',
          variant: UiVariant.link,
          onPressed: () {},
        ),
      ),
    );
    await tester.pump();
    final Text linkText = tester.widget<Text>(find.text('View all (3)'));
    expect(linkText.style?.decoration, isNot(TextDecoration.underline));
  });

  testWidgets('8. UiAccordion editorial variant animates open & close with circled numerals', (
    WidgetTester tester,
  ) async {
    _setDesktop(tester);
    await tester.pumpWidget(
      _wrap(
        const UiAccordion(
          variant: UiAccordionVariant.editorial,
          allowMultiple: true,
          items: <UiAccordionItem>[
            UiAccordionItem(
              title: 'Trading & Brokers',
              content: Text('NSE & BSE tradebook sync answer'),
            ),
            UiAccordionItem(
              title: 'Pricing & Plans',
              content: Text('INR GST transparent billing answer'),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Trading & Brokers'), findsOneWidget);
    expect(find.text('NSE & BSE tradebook sync answer'), findsNothing);

    // Open row 1 and row 2 (different text widths) — both must share exact left edge
    await tester.tap(find.text('Trading & Brokers'));
    await tester.pump();
    await tester.tap(find.text('Pricing & Plans'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('NSE & BSE tradebook sync answer'), findsOneWidget);
    expect(find.text('INR GST transparent billing answer'), findsOneWidget);
    final double titleLeft = tester.getTopLeft(find.text('Trading & Brokers')).dx;
    final double ans1Left =
        tester.getTopLeft(find.text('NSE & BSE tradebook sync answer')).dx;
    final double ans2Left =
        tester.getTopLeft(find.text('INR GST transparent billing answer')).dx;
    expect(ans1Left, closeTo(titleLeft, 0.5));
    expect(ans2Left, closeTo(titleLeft, 0.5));

    // Close row 1
    await tester.tap(find.text('Trading & Brokers'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('NSE & BSE tradebook sync answer'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('9. LoginPage renders thread backdrop and repaint-isolated split card without bg grid', (
    WidgetTester tester,
  ) async {
    _setDesktop(tester);
    await tester.pumpWidget(
      UiThemeScope(
        theme: UiTheme.dark(),
        child: MaterialApp(
          home: LoginPage(
            onLoginSuccess: (_, _) {},
            onNavigateToSignup: (_) {},
            onNavigateToForgotPassword: () {},
            onNavigateBack: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(LandingHeroGridBackdrop), findsNothing);
    expect(find.byType(AlphaThreadBackdrop), findsOneWidget);
    expect(find.byType(AuthCarouselPanel), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(RepaintBoundary), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('10. SignupPage renders thread backdrop and repaint-isolated split card without bg grid', (
    WidgetTester tester,
  ) async {
    _setDesktop(tester);
    await tester.pumpWidget(
      UiThemeScope(
        theme: UiTheme.dark(),
        child: MaterialApp(
          home: SignupPage(
            onSignupSuccess: (_, _, {requiresVerification = false}) {},
            onNavigateToLogin: (_) {},
            onNavigateBack: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(LandingHeroGridBackdrop), findsNothing);
    expect(find.byType(AlphaThreadBackdrop), findsOneWidget);
    expect(find.byType(AuthCarouselPanel), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.byType(RepaintBoundary), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '11. Header highlights active section on scroll/tap and toggles Dark/Light theme',
    (WidgetTester tester) async {
      _setDesktop(tester);
      final AppThemeController themeController = AppThemeController(
        ThemeMode.dark,
      );
      addTearDown(themeController.dispose);

      await tester.pumpWidget(
        AppThemeScope(
          controller: themeController,
          child: ListenableBuilder(
            listenable: themeController,
            builder: (BuildContext context, Widget? _) {
              final bool isDark = themeController.mode == ThemeMode.dark;
              return UiThemeScope(
                theme: isDark ? UiTheme.dark() : UiTheme.light(),
                child: MaterialApp(
                  home: GetStartedPage(
                    onGetStarted: (_) {},
                    onSignIn: () {},
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Helper to check whether a header nav link Semantics node is selected.
      bool isNavSelected(String label) {
        final Finder semFinder = find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (Widget w) => w is Semantics && w.properties.label == label,
          ),
        );
        final Semantics sem = tester.widget<Semantics>(semFinder.first);
        return sem.properties.selected == true;
      }

      // 1. At top of page, 'home' is active and gliding pill sits behind 'home'.
      expect(isNavSelected('home'), isTrue);
      expect(isNavSelected('platform'), isFalse);
      expect(isNavSelected('pricing'), isFalse);
      final Finder pillFinder = find.byKey(
        const ValueKey<String>('landing-header-sliding-pill'),
      );
      expect(pillFinder, findsOneWidget);
      final double homePillX = tester.getTopLeft(pillFinder).dx;
      final double homeToPricingGapBefore =
          tester.getTopLeft(find.text('pricing')).dx -
          tester.getTopLeft(find.text('home')).dx;

      // 2. Toggle Dark -> Light via header theme button.
      expect(
        find.byWidgetPredicate((Widget w) => w is AppThemeGlyph && w.isDark),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Switch to light theme'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(themeController.mode, ThemeMode.light);
      expect(
        find.byWidgetPredicate((Widget w) => w is AppThemeGlyph && !w.isDark),
        findsOneWidget,
      );

      // 3. Scroll down into the Platform section and verify gliding pill slides rightwards
      //    while inter-item spacing stays locked (zero horizontal bold-jitter).
      final Finder scrollFinder = find.byType(SingleChildScrollView).first;
      await tester.drag(scrollFinder, const Offset(0, -680));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(isNavSelected('platform'), isTrue);
      expect(isNavSelected('home'), isFalse);
      final double platformPillRelativeX =
          tester.getTopLeft(pillFinder).dx -
          tester.getTopLeft(find.text('home')).dx;
      expect(platformPillRelativeX, greaterThan(20));
      expect(
        tester.getTopLeft(find.text('pricing')).dx -
            tester.getTopLeft(find.text('home')).dx,
        closeTo(homeToPricingGapBefore, 0.5),
      );
      expect(homePillX, greaterThan(0));

      // 4. Tap 'faq' in the header and verify gliding pill slides to 'faq'.
      await tester.tap(find.text('faq'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(isNavSelected('faq'), isTrue);
      expect(isNavSelected('platform'), isFalse);
      final double faqPillRelativeX =
          tester.getTopLeft(pillFinder).dx -
          tester.getTopLeft(find.text('home')).dx;
      expect(faqPillRelativeX, greaterThan(platformPillRelativeX + 40));

      // 5. Toggle Light -> Dark back via header theme button.
      await tester.tap(find.byTooltip('Switch to dark theme'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(themeController.mode, ThemeMode.dark);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '12. Light mode has zero black-flash on hover interpolation and strong WCAG AA text contrast',
    (WidgetTester tester) async {
      double contrastRatio(Color a, Color b) {
        final double l1 = a.computeLuminance();
        final double l2 = b.computeLuminance();
        final double hi = l1 > l2 ? l1 : l2;
        final double lo = l1 > l2 ? l2 : l1;
        return (hi + 0.05) / (lo + 0.05);
      }

      final UiColors light = UiColors.light();
      expect(contrastRatio(light.foreground, light.surface), greaterThan(15.0));
      expect(
        contrastRatio(light.foregroundMuted, light.surface),
        greaterThan(7.0),
      );
      expect(
        contrastRatio(light.foregroundSubtle, light.surface),
        greaterThan(4.5),
      );
      expect(contrastRatio(light.bullish, light.surface), greaterThan(4.5));
      expect(contrastRatio(light.bearish, light.surface), greaterThan(4.5));
      expect(contrastRatio(light.warning, light.surface), greaterThan(4.5));
      expect(contrastRatio(light.info, light.surface), greaterThan(4.5));
      expect(
        contrastRatio(light.series.first, light.surface),
        greaterThan(4.5),
      );

      // Verify ghost UiButton's idle BoxDecoration color uses surfaceHover RGB at 0 alpha
      // (never 0x00000000 black, which would flash charcoal mid-transition on hover).
      await tester.pumpWidget(
        _wrap(
          UiButton(
            label: 'Sign in',
            variant: UiVariant.ghost,
            onPressed: () {},
          ),
          brightness: Brightness.light,
        ),
      );
      await tester.pump();

      final AnimatedContainer container = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(UiButton),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final BoxDecoration dec = container.decoration! as BoxDecoration;
      final Color idleBg = dec.color!;
      expect(idleBg.a, closeTo(0.0, 0.001));
      expect(idleBg.r, closeTo(light.surfaceHover.r, 0.01));
      expect(idleBg.g, closeTo(light.surfaceHover.g, 0.01));
      expect(idleBg.b, closeTo(light.surfaceHover.b, 0.01));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('13. Global AppTopBar displays theme toggle button and switches theme cleanly', (
    WidgetTester tester,
  ) async {
    _setDesktop(tester);
    final AppThemeController themeController = AppThemeController(
      ThemeMode.dark,
    );
    addTearDown(themeController.dispose);

    await tester.pumpWidget(
      AppThemeScope(
        controller: themeController,
        child: ListenableBuilder(
          listenable: themeController,
          builder: (BuildContext context, Widget? _) {
            final bool isDark = themeController.mode == ThemeMode.dark;
            return UiThemeScope(
              theme: isDark ? UiTheme.dark() : UiTheme.light(),
              child: MaterialApp(
                home: Scaffold(
                  body: AppTopBar(
                    selectedId: 'dashboard',
                    sections: const <AppNavSection>[
                      AppNavSection(
                        title: 'Workspace',
                        items: <AppNavItem>[
                          AppNavItem(
                            id: 'dashboard',
                            label: 'Dashboard',
                            icon: Icons.dashboard_outlined,
                          ),
                        ],
                      ),
                    ],
                    onNotifications: () {},
                    onHelp: () {},
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    final Finder toggleFinder = find.byKey(
      const ValueKey<String>('app-header-theme-toggle'),
    );
    expect(toggleFinder, findsOneWidget);
    expect(
      find.byWidgetPredicate((Widget w) => w is AppThemeGlyph && w.isDark),
      findsOneWidget,
    );

    await tester.tap(toggleFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(themeController.mode, ThemeMode.light);
    expect(
      find.byWidgetPredicate((Widget w) => w is AppThemeGlyph && !w.isDark),
      findsOneWidget,
    );

    await tester.tap(toggleFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(themeController.mode, ThemeMode.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '15. LandingAvailableDevicesSection renders 5 WebP device frames with Web Live now CTA in dark & light themes',
    (WidgetTester tester) async {
      _setDesktop(tester);
      bool launchedWeb = false;
      await tester.pumpWidget(
        _wrap(
          LandingAvailableDevicesSection(
            onLaunchWeb: () => launchedWeb = true,
          ),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump();

      expect(
        find.text('Journal on the go.\nReview on the big screen.'),
        findsOneWidget,
      );
      expect(find.text('AVAILABLE ON EVERY DEVICE'), findsNothing);
      expect(find.byType(LandingDeviceFrameWebp), findsNWidgets(5));
      expect(find.text('iPhone'), findsOneWidget);
      expect(find.text('Android'), findsOneWidget);
      expect(find.text('Tablet'), findsOneWidget);
      expect(find.text('Web'), findsOneWidget);
      expect(find.text('Mac'), findsOneWidget);
      expect(find.text('Live now'), findsOneWidget);
      expect(find.text('Coming soon'), findsNWidgets(4));

      final List<String> darkPaths = tester
          .widgetList<LandingDeviceFrameWebp>(
            find.byType(LandingDeviceFrameWebp),
          )
          .map((LandingDeviceFrameWebp w) => w.assetPathFor(Brightness.dark))
          .toList();
      expect(darkPaths, <String>[
        'assets/landing/device_iphone_dark.webp',
        'assets/landing/device_android_dark.webp',
        'assets/landing/device_tablet_dark.webp',
        'assets/landing/device_web_dark.webp',
        'assets/landing/device_mac_dark.webp',
      ]);

      await tester.tap(find.byKey(const ValueKey<String>('landing-device-web')));
      await tester.pump();
      expect(launchedWeb, isTrue);

      // Light mode + narrow mobile width renders cleanly without overflow.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        _wrap(
          const LandingAvailableDevicesSection(),
          brightness: Brightness.light,
        ),
      );
      await tester.pump();
      final List<String> lightPaths = tester
          .widgetList<LandingDeviceFrameWebp>(
            find.byType(LandingDeviceFrameWebp),
          )
          .map((LandingDeviceFrameWebp w) => w.assetPathFor(Brightness.light))
          .toList();
      expect(lightPaths, <String>[
        'assets/landing/device_iphone_light.webp',
        'assets/landing/device_android_light.webp',
        'assets/landing/device_tablet_light.webp',
        'assets/landing/device_web_light.webp',
        'assets/landing/device_mac_light.webp',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '16. Landing page UiDeferred sections never stay stuck on skeleton after theme toggle',
    (WidgetTester tester) async {
      _setDesktop(tester);
      final AppThemeController themeController = AppThemeController(
        ThemeMode.dark,
      );
      addTearDown(themeController.dispose);

      await tester.pumpWidget(
        AppThemeScope(
          controller: themeController,
          child: ListenableBuilder(
            listenable: themeController,
            builder: (BuildContext context, Widget? _) {
              final bool isDark = themeController.mode != ThemeMode.light;
              return UiApp(
                theme: isDark ? UiTheme.dark() : UiTheme.light(),
                builder: (_) => MaterialApp(
                  theme: UiTheme.light().toThemeData(),
                  darkTheme: UiTheme.dark().toThemeData(),
                  themeMode: themeController.mode,
                  home: GetStartedPage(
                    onGetStarted: (_) {},
                    onSignIn: () {},
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Toggle Dark -> Light while at top, then jump to Devices section.
      final Finder themeToggle = find.byType(AppThemeGlyph);
      expect(themeToggle, findsOneWidget);
      await tester.tap(themeToggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(themeController.mode, ThemeMode.light);

      // Tap 'devices' nav link to scroll to the deferred Devices section.
      await tester.tap(find.text('devices'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      expect(find.byType(LandingAvailableDevicesSection), findsOneWidget);

      // Toggle Light -> Dark while scrolled at Devices section: section stays mounted.
      await tester.tap(themeToggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(themeController.mode, ThemeMode.dark);
      expect(find.byType(LandingAvailableDevicesSection), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '17. AlphaThread does not replay entrance animation after modal dialog closes',
    (WidgetTester tester) async {
      _setDesktop(tester);
      late BuildContext hostContext;
      await tester.pumpWidget(
        UiApp(
          theme: UiTheme.dark(),
          builder: (_) => MaterialApp(
            home: Builder(
              builder: (BuildContext context) {
                hostContext = context;
                return const Scaffold(
                  body: AlphaThread(animate: true, height: 180),
                );
              },
            ),
          ),
        ),
      );
      // Let the 3600ms entrance animation complete.
      await tester.pump(const Duration(milliseconds: 3800));
      expect(tester.binding.hasScheduledFrame, isFalse);

      // Open a modal dialog (like CookiePreferencesDialog) over the page.
      showDialog<void>(
        context: hostContext,
        builder: (_) => const AlertDialog(content: Text('Cookies')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cookies'), findsOneWidget);

      // Close the modal dialog and verify AlphaThread stays completed (does not
      // restart a 3.6s animation).
      Navigator.of(hostContext).pop();
      await tester.pumpAndSettle();
      expect(find.text('Cookies'), findsNothing);
      // One frame later, no ongoing animation should be ticking.
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '18. UiScrollReveal reveals once on scroll into view and respects reduced motion',
    (WidgetTester tester) async {
      _setDesktop(tester);
      final ScrollController scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        UiApp(
          theme: UiTheme.dark(),
          builder: (_) => MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                controller: scrollController,
                child: const Column(
                  children: <Widget>[
                    SizedBox(height: 1400),
                    UiScrollReveal(
                      delay: Duration(milliseconds: 40),
                      child: Text('Below-fold reveal'),
                    ),
                    SizedBox(height: 400),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      FadeTransition fade() => tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(UiScrollReveal),
          matching: find.byType(FadeTransition),
        ),
      );
      // Starts hidden while below the fold.
      expect(fade().opacity.value, 0.0);

      // Scroll into view -> triggers smooth reveal once after 40ms stagger delay.
      scrollController.jumpTo(950);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 700));
      expect(fade().opacity.value, closeTo(1.0, 0.01));

      // Scrolling away and back never resets it back to 0.
      scrollController.jumpTo(0);
      await tester.pump();
      expect(fade().opacity.value, closeTo(1.0, 0.01));
      expect(tester.takeException(), isNull);
    },
  );
}
