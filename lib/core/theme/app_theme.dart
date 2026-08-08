import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Central theme provider delegating directly to the flutter-ui design system tokens.
class AppTheme {
  static UiTheme get uiLight => UiTheme.light();
  static UiTheme get uiDark => UiTheme.dark();

  static ThemeData get light => uiLight.toThemeData();
  static ThemeData get dark => uiDark.toThemeData();
}
