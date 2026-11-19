/// Customer frontend preview with no backend initialization.
/// Open /workspace?preview=customer to exercise the real router and shell.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app.dart';
import 'core/config/customer_data_policy.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  CustomerDataPolicy.allowDemo = true;
  SemanticsBinding.instance.ensureSemantics();
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const AlphaJournalApp());
}
