import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:tradex/app.dart';
import 'package:tradex/core/config/env_config.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/billing/revenuecat_billing.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Keep development inspector paint overlays from leaking into product
      // previews after hot reloads (yellow baselines / layout boundary markers).
      debugPaintBaselinesEnabled = false;
      debugPaintSizeEnabled = false;

      // 1. Safely load environment variables (.env file)
      try {
        await EnvConfig.init();
      } catch (e) {
        debugPrint('[main] EnvConfig.init caught error: $e');
      }

      // 2. Safely initialize Supabase configuration
      try {
        await SupabaseConfig.initialize();
      } catch (e) {
        debugPrint('[main] SupabaseConfig.initialize caught error: $e');
      }

      try {
        await RevenueCatBilling.initialize();
      } catch (e) {
        debugPrint('[main] RevenueCat initialization unavailable: $e');
      }

      // 3. System UI styling (safe on all platforms)
      try {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            statusBarColor: Colors.transparent,
          ),
        );
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } catch (e) {
        debugPrint('[main] SystemChrome configuration skipped: $e');
      }

      // 4. Custom ErrorWidget to avoid blank white screens if a render error occurs
      ErrorWidget.builder = (FlutterErrorDetails details) {
        return Material(
          color: const Color(0xFF151312),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFD9695F),
                    size: 44,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Application Encountered an Error',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details.exceptionAsString(),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFA8A29E),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      };

      runApp(const TradeXApp());
    },
    (error, stackTrace) {
      debugPrint('[main] Unhandled Zone Error: $error\n$stackTrace');
    },
  );
}
