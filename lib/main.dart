import 'package:alphajournal/core/notifications/push_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alphajournal/app.dart';
import 'package:alphajournal/core/app-ui/theme/app_theme_controller.dart';
import 'package:alphajournal/core/config/env_config.dart';
import 'package:alphajournal/core/config/legacy_brand_storage_migration.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/core/billing/revenuecat_billing.dart';

void _debugLog(String message, [Object? error, StackTrace? stackTrace]) {
  if (!kDebugMode) return;
  final details = error == null ? '' : ': $error';
  final trace = stackTrace == null ? '' : '\n$stackTrace';
  debugPrint('$message$details$trace');
}

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Keep development inspector paint overlays from leaking into product
      // previews after hot reloads (yellow baselines / layout boundary markers).
      debugPaintBaselinesEnabled = false;
      debugPaintSizeEnabled = false;

      try {
        await LegacyBrandStorageMigration.run();
      } catch (e) {
        _debugLog('[main] Legacy AlphaJournal storage migration skipped', e);
      }

      // 1. Safely load environment variables (.env file)
      try {
        await EnvConfig.init();
      } catch (e) {
        _debugLog('[main] EnvConfig.init caught error', e);
      }

      // 2. Safely initialize Supabase configuration
      try {
        await SupabaseConfig.initialize();
      } catch (e) {
        _debugLog('[main] SupabaseConfig.initialize caught error', e);
      }

      try {
        await RevenueCatBilling.initialize();
      } catch (e) {
        _debugLog('[main] RevenueCat initialization unavailable', e);
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
        _debugLog('[main] SystemChrome configuration skipped', e);
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
                    kDebugMode
                        ? details.exceptionAsString()
                        : 'Something went wrong while rendering this screen. Please reopen it or try again.',
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

      PushService.instance.initialize();
      AppZoom initialZoom = AppZoom.system;
      AppTextSize initialTextSize = AppTextSize.system;
      try {
        final preferences = await SharedPreferences.getInstance();
        initialZoom =
            AppZoom.fromPreference(
              preferences.getString(AppZoom.preferenceKey),
            ) ??
            AppZoom.system;
        initialTextSize =
            AppTextSize.fromPreference(
              preferences.getString(AppTextSize.preferenceKey),
            ) ??
            AppTextSize.system;
      } catch (_) {
        // Keep the default sizing when local preferences are unavailable.
      }
      runApp(
        AlphaJournalApp(
          initialZoom: initialZoom,
          initialTextSize: initialTextSize,
        ),
      );
    },
    (error, stackTrace) {
      _debugLog('[main] Unhandled Zone Error', error, stackTrace);
    },
  );
}
