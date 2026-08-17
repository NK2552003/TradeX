import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/app_constants.dart';
import 'package:tradex/features/auth/auth.dart';

class TradeXApp extends StatefulWidget {
  const TradeXApp({super.key});

  @override
  State<TradeXApp> createState() => _TradeXAppState();
}

class _TradeXAppState extends State<TradeXApp> {
  final AppThemeController _themeController =
      AppThemeController(ThemeMode.dark, 'Comfortable');

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppThemeScope(
      controller: _themeController,
      child: ListenableBuilder(
        listenable: _themeController,
        builder: (context, _) {
          final Brightness systemBrightness =
              MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.dark;
          final bool isDark = switch (_themeController.value) {
            ThemeMode.system => systemBrightness == Brightness.dark,
            ThemeMode.dark => true,
            ThemeMode.light => false,
          };

          final UiSpacing spacing = _themeController.density == 'Compact'
              ? const UiSpacing(
                  none: 0,
                  xxs: 1.5,
                  xs: 3,
                  sm: 6,
                  md: 9,
                  lg: 12,
                  xl: 18,
                  xxl: 24,
                  xxxl: 36,
                )
              : const UiSpacing();

          final UiTheme theme = isDark
              ? UiTheme.dark(spacing: spacing)
              : UiTheme.light(spacing: spacing);

          return UiApp(
            theme: theme,
            builder: (context) => MaterialApp(
              title: AppConstants.appName,
              debugShowCheckedModeBanner: false,
              theme: UiTheme.light(spacing: spacing).toThemeData(),
              darkTheme: UiTheme.dark(spacing: spacing).toThemeData(),
              themeMode: _themeController.value,
              builder: (context, child) => UiToastScope(
                child: child ?? const SizedBox.shrink(),
              ),
              home: const AuthWrapper(),
            ),
          );
        },
      ),
    );
  }
}
