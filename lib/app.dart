import 'package:flutter/material.dart';
import 'package:tradex/core/config/app_constants.dart';
import 'package:tradex/core/theme/app_theme.dart';
import 'package:tradex/core/widgets/app_scaffold.dart';

class TradeXApp extends StatelessWidget {
  const TradeXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.light,
      home: const AppScaffold(),
    );
  }
}
