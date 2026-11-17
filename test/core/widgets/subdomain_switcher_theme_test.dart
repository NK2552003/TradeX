import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/widgets/record_unavailable.dart';
import 'package:tradex/features/settings/presentation/pages/shared/appearance_settings_page.dart';

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
          final UiTheme uiTheme = isDark ? UiTheme.dark() : UiTheme.light();
          return UiApp(
            theme: uiTheme,
            builder: (context) => MaterialApp(
              theme: UiTheme.light().toThemeData(),
              darkTheme: UiTheme.dark().toThemeData(),
              themeMode: widget.controller.value,
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

      BuildContext bannerCtx() => tester.element(find.byType(RecordOpeningBanner));
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
      final extrasRaw = sp.getString('tradex_appearance_extras_v1');
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
