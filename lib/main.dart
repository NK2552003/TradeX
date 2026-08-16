import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/app.dart';
import 'package:tradex/core/config/env_config.dart';
import 'package:tradex/core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (.env file)
  await EnvConfig.init();

  // Initialize Supabase configuration
  await SupabaseConfig.initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const TradeXApp());
}
