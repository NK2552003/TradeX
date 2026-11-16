import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/components/ui_candle_chart.dart';

/// Controller for managing the application theme mode (dark, light, system),
/// layout spacing density, and global financial chart defaults.
class AppThemeController extends ChangeNotifier {
  AppThemeController([
    ThemeMode initialMode = ThemeMode.dark,
    String initialDensity = 'Comfortable',
    String initialChartRange = '1D',
    String initialChartStyle = 'Candlestick',
    String initialColorConvention = 'Standard (Green/Red)',
  ]) : _mode = initialMode,
       _density = initialDensity,
       _chartRange = initialChartRange,
       _chartStyle = initialChartStyle,
       _colorConvention = initialColorConvention;

  ThemeMode _mode;
  String _density;
  String _chartRange;
  String _chartStyle;
  String _colorConvention;

  ThemeMode get value => _mode;
  ThemeMode get mode => _mode;
  String get density => _density;
  String get chartRange => _chartRange;
  String get chartStyle => _chartStyle;
  String get colorConvention => _colorConvention;

  UiPriceChartType get preferredPriceChartType => switch (_chartStyle) {
    'Line' => UiPriceChartType.line,
    'Area' => UiPriceChartType.area,
    'Bars' => UiPriceChartType.hollow,
    _ => UiPriceChartType.candles,
  };

  static AppThemeController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppThemeScope>()
        ?.controller;
  }

  static AppThemeController of(BuildContext context) {
    final AppThemeController? controller = maybeOf(context);
    if (controller == null) {
      throw FlutterError(
        'AppThemeController.of() called with a context that does not contain an AppThemeScope.',
      );
    }
    return controller;
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

  void setChartRange(String range) {
    if (_chartRange != range) {
      _chartRange = range;
      notifyListeners();
    }
  }

  void setChartStyle(String style) {
    if (_chartStyle != style) {
      _chartStyle = style;
      notifyListeners();
    }
  }

  void setColorConvention(String convention) {
    if (_colorConvention != convention) {
      _colorConvention = convention;
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
