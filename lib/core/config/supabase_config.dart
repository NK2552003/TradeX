import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/config/env_config.dart';

class SupabaseConfig {
  SupabaseConfig._();

  // Default credentials (resolved from EnvConfig or runtime settings)
  static String supabaseUrl = EnvConfig.supabaseUrl;
  static String supabaseAnonKey = EnvConfig.supabaseAnonKey;

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /// Returns true if valid Supabase credentials (not default placeholders) are present
  static bool get isConfigured {
    return _isInitialized &&
        supabaseUrl.isNotEmpty &&
        !supabaseUrl.contains('placeholder.supabase.co') &&
        supabaseAnonKey.isNotEmpty &&
        !supabaseAnonKey.contains('placeholder');
  }

  /// Initialize Supabase Flutter SDK
  static Future<void> initialize({String? customUrl, String? customKey}) async {
    if (customUrl != null && customUrl.isNotEmpty) {
      supabaseUrl = customUrl;
    }
    if (customKey != null && customKey.isNotEmpty) {
      supabaseAnonKey = customKey;
    }

    if (supabaseUrl.contains('placeholder.supabase.co') || supabaseAnonKey.contains('placeholder')) {
      debugPrint('[SupabaseConfig] Supabase running in local mock mode (URL/Key unconfigured).');
      _isInitialized = false;
      return;
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
        debug: kDebugMode,
      );
      _isInitialized = true;
      debugPrint('[SupabaseConfig] Supabase SDK successfully initialized.');
    } catch (e) {
      _isInitialized = false;
      debugPrint('[SupabaseConfig] Failed to initialize Supabase SDK: $e');
    }
  }

  /// Helper getter to safely access SupabaseClient instance
  static SupabaseClient? get client {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}
