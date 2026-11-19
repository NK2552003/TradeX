import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/widgets/record_unavailable.dart';
import 'package:alphajournal/features/settings/presentation/pages/shared/appearance_settings_page.dart';

class _TestThemeHost extends StatefulWidget {
  const _TestThemeHost({required this.controller, required this.child});

  final AppThemeController controller;
  final Widget child;

  @override
  State<_TestThemeHost> createState() => _TestThemeHostState();
}

class _TestThemeHostState extends State<_TestThemeHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangePlatformBrightness() {
    if (widget.controller.value == ThemeMode.system && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppThemeScope(
      controller: widget.controller,
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final Brightness systemBrightness =
              MediaQuery.maybePlatformBrightnessOf(context) ??
              WidgetsBinding.instance.platformDispatcher.platformBrightness;
          final bool isDark = switch (widget.controller.value) {
            ThemeMode.system => systemBrightness == Brightness.dark,
            ThemeMode.dark => true,
            ThemeMode.light => false,
          };
          final uiTheme = (isDark ? UiTheme.dark() : UiTheme.light()).copyWith(
            zoom: widget.controller.zoom.factor,
          );
          return UiApp(
            theme: uiTheme,
            builder: (context) => MaterialApp(
              theme: UiTheme.light().toThemeData(),
              darkTheme: UiTheme.dark().toThemeData(),
              themeMode: widget.controller.value,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: widget.controller.textSize.resolve(
                    MediaQuery.textScalerOf(context),
                  ),
                ),
                child: child!,
              ),
              home: UiToastScope(child: widget.child),
            ),
          );
        },
      ),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'Appearance persists independent app zoom and text size choices',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.15;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final controller = AppThemeController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _TestThemeHost(
          controller: controller,
          child: const Scaffold(body: AppearanceSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      final zoom = find.byKey(const ValueKey('appearance-app-zoom'));
      final textSize = find.byKey(const ValueKey('appearance-text-size'));
      final baseSize = tester.element(zoom).sz(20);
      final baseFont = tester.element(zoom).uiText.body.fontSize!;

      Future<void> select(Finder picker, String label) async {
        await tester.ensureVisible(picker);
        await tester.tap(picker);
        await tester.pumpAndSettle();
        final option = find.descendant(
          of: find.byType(UiDialog),
          matching: find.text(label),
        );
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pumpAndSettle();
      }

      expect(MediaQuery.textScalerOf(tester.element(zoom)).scale(20), 23);
      await select(zoom, 'Extra large');
      expect(controller.zoom, AppZoom.extraLarge);
      final zoomedSize = tester.element(zoom).sz(20);
      expect(zoomedSize, greaterThan(baseSize));
      final zoomedFont = tester.element(zoom).uiText.body.fontSize!;
      expect(zoomedFont, closeTo(baseFont * 1.25, 0.001));

      await select(textSize, 'Extra large');
      expect(controller.textSize, AppTextSize.extraLarge);
      expect(tester.element(zoom).sz(20), zoomedSize);
      expect(tester.element(zoom).uiText.body.fontSize, zoomedFont);
      expect(MediaQuery.textScalerOf(tester.element(zoom)).scale(20), 26);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppZoom.preferenceKey), 'extraLarge');
      expect(prefs.getString(AppTextSize.preferenceKey), 'extraLarge');

      await select(textSize, 'System default');
      tester.platformDispatcher.textScaleFactorTestValue = 1.25;
      await tester.pumpAndSettle();
      expect(MediaQuery.textScalerOf(tester.element(zoom)).scale(20), 25);
      expect(tester.element(zoom).sz(20), zoomedSize);
      expect(prefs.getString(AppTextSize.preferenceKey), 'system');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'RecordOpeningBanner and AppearanceSettingsPage follow Dark, Light, and System platform brightness',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final controller = AppThemeController(ThemeMode.dark, 'Comfortable');
      addTearDown(controller.dispose);

      // Simulate System brightness = light while controller starts dark.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;

      await tester.pumpWidget(
        _TestThemeHost(
          controller: controller,
          child: const Scaffold(
            body: Column(
              children: [
                Expanded(child: AppearanceSettingsPage()),
                RecordOpeningBanner(
                  title: 'Switching workspace...',
                  subtitle: 'Connecting to community.alphajournal.in',
                  badgeLabel: 'Subdomain',
                  icon: Icons.swap_horiz_rounded,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      BuildContext bannerCtx() =>
          tester.element(find.byType(RecordOpeningBanner));
      expect(bannerCtx().ui.brightness, Brightness.dark);
      expect(bannerCtx().ui.colors.background, UiColors.dark().background);

      // Select Light inside AppearanceSettingsPage.
      await tester.tap(find.text('Light'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.value, ThemeMode.light);
      expect(bannerCtx().ui.brightness, Brightness.light);
      expect(bannerCtx().ui.colors.background, UiColors.light().background);
      expect(bannerCtx().ui.colors.surface, UiColors.light().surface);

      final sp = await SharedPreferences.getInstance();
      final extrasRaw = sp.getString('alphajournal_appearance_extras_v1');
      expect(extrasRaw, isNotNull);
      final extras = jsonDecode(extrasRaw!) as Map<String, dynamic>;
      expect(extras['theme_mode'], 'light');

      // Switch to System while platform brightness is Light -> banner stays Light.
      await tester.tap(find.text('System'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.value, ThemeMode.system);
      expect(bannerCtx().ui.brightness, Brightness.light);

      // Flip OS brightness to Dark while System mode is active -> banner switches Dark.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(bannerCtx().ui.brightness, Brightness.dark);
      expect(bannerCtx().ui.colors.background, UiColors.dark().background);

      // Flush pending toast auto-dismiss timers before teardown.
      await tester.pump(const Duration(seconds: 5));
    },
  );
}
