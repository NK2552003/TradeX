/// Local frontend handoff: flutter run -t lib/main_research_preview.dart
/// No sign-in or backend credentials are needed for this demo entry point.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/widgets/app_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(
    UiApp(
      theme: UiTheme.dark(),
      builder: (context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: UiTheme.dark().toThemeData(),
        title: 'AlphaJournal · Research workspace',
        builder: (context, child) =>
            UiToastScope(child: child ?? const SizedBox.shrink()),
        home: const AppScaffold(
          initialDestination: 'workspace',
          userDisplayName: 'Demo workspace',
        ),
      ),
    ),
  );
}
