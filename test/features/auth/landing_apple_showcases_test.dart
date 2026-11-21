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
      expect(find.text('Trading Journal'), findsOneWidget);
      expect(find.text('for your system'), findsOneWidget);
      expect(find.text('Get started free'), findsOneWidget);
      expect(find.text('See how it works'), findsOneWidget);
      expect(find.byType(LandingHeroGridBackdrop), findsNWidgets(2));

      // Tapping the selection bounding box types the next phrase letter-by-letter
      await tester.tap(find.text('Trading Journal'));
      await tester.pump();
      expect(find.text('Trading Journal'), findsNothing);
      expect(find.text('AI Copilot'), findsNothing);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('AI'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('AI Copilot'), findsOneWidget);
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

  testWidgets('4. LandingAppleIphoneGallery renders 5 iPhone SVG frames + QuietDock + Knowledge Graph', (
    WidgetTester tester,
  ) async {
    _setDesktop(tester);
    await tester.pumpWidget(_wrap(const LandingAppleIphoneGallery()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AppleIphoneSvgFrame), findsNWidgets(5));
    expect(find.byType(QuietDock), findsNWidgets(5));
    expect(find.byType(UiGraphCanvas), findsOneWidget);
    expect(find.byType(AppLinkedRecordsPanel), findsOneWidget);
    expect(find.byType(AppNoteCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('5. LandingAppleIpadMosaicSection renders iPad SVG + mosaic cleanly', (
    WidgetTester tester,
  ) async {
    _setDesktop(tester);
    await tester.pumpWidget(_wrap(const LandingAppleIpadMosaicSection()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AppleIpadSvgFrame), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('6. LandingAppleCenterPhoneStripSection renders center iPhone AI Quant Lab + 6 flanking AI format cards cleanly', (
    WidgetTester tester,
  ) async {
    _setDesktop(tester);
    await tester.pumpWidget(
      _wrap(const LandingAppleCenterPhoneStripSection(), brightness: Brightness.light),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AppleIphoneSvgFrame), findsOneWidget);
    expect(find.byType(QuietDock), findsOneWidget);
    expect(find.byType(AppAiMessageBubble), findsOneWidget);
    expect(find.byType(PerplexityCardBlock), findsNWidgets(4));
    expect(find.byType(ChartBlock), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

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
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
      await tester.tap(find.byTooltip('Switch to light theme'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(themeController.mode, ThemeMode.light);
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);

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
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);

    await tester.tap(toggleFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(themeController.mode, ThemeMode.light);
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);

    await tester.tap(toggleFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(themeController.mode, ThemeMode.dark);
    expect(tester.takeException(), isNull);
  });
}
