import 'package:flutter/material.dart';
import 'package:tradex/core/config/app_constants.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/auth/auth.dart';

class TradeXApp extends StatefulWidget {
  const TradeXApp({super.key});

  @override
  State<TradeXApp> createState() => _TradeXAppState();
}

class _TradeXAppState extends State<TradeXApp> {
  final bool _isDark = true;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = _isDark ? UiTheme.dark() : UiTheme.light();
    return UiApp(
      theme: theme,
      builder: (context) => MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: UiTheme.light().toThemeData(),
        darkTheme: UiTheme.dark().toThemeData(),
        themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
        home: const AuthWrapper(),
      ),
    );
  }
}
