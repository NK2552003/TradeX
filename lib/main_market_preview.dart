/// Preview any Market Intelligence destination without backend credentials.
/// Example: /?page=market_news
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/widgets/app_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  GoogleFonts.config.allowRuntimeFetching = false;
  final destination = Uri.base.queryParameters['page'] ?? 'market_overview';
  runApp(
    UiApp(
      theme: UiTheme.dark(),
      builder: (context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: UiTheme.dark().toThemeData(),
        title: 'TraderHub · Market Intelligence',
        builder: (context, child) =>
            UiToastScope(child: child ?? const SizedBox.shrink()),
        home: AppScaffold(
          initialDestination: destination,
          userDisplayName: 'Market preview',
        ),
      ),
    ),
  );
}
