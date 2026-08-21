import 'package:flutter/material.dart';

/// Controller for managing the application theme mode (dark, light, system)
/// and layout spacing density ('Comfortable', 'Compact').
class AppThemeController extends ChangeNotifier {
  AppThemeController([
    ThemeMode initialMode = ThemeMode.dark,
    String initialDensity = 'Comfortable',
  ]) : _mode = initialMode,
       _density = initialDensity;

  ThemeMode _mode;
  String _density;

  ThemeMode get value => _mode;
  ThemeMode get mode => _mode;
  String get density => _density;

  static AppThemeController of(BuildContext context) {
    final AppThemeScope? scope = context
        .dependOnInheritedWidgetOfExactType<AppThemeScope>();
    if (scope == null) {
      throw FlutterError(
        'AppThemeController.of() called with a context that does not contain an AppThemeScope.',
      );
    }
    return scope.controller;
  }

  void setMode(ThemeMode mode) {
    if (_mode != mode) {
      _mode = mode;
      notifyListeners();
    }
  }

  void setDensity(String density) {
    if (_density != density) {
      _density = density;
      notifyListeners();
    }
  }

  bool isDark(BuildContext context) {
    if (_mode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _mode == ThemeMode.dark;
  }
}

/// Inherited widget scope that exposes [AppThemeController] down the widget tree.
class AppThemeScope extends InheritedNotifier<AppThemeController> {
  const AppThemeScope({
    super.key,
    required AppThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  AppThemeController get controller => notifier!;
}
