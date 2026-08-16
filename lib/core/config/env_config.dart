import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  EnvConfig._();

  static bool _isLoaded = false;
  static bool get isLoaded => _isLoaded;

  /// Safely initialize environment variables from `.env` asset file.
  static Future<void> init() async {
    try {
      await dotenv.load(fileName: '.env');
      _isLoaded = true;
      debugPrint('[EnvConfig] Environment file (.env) successfully loaded.');
    } catch (e) {
      _isLoaded = false;
      debugPrint('[EnvConfig] Could not load .env file: $e. Falling back to compile-time env variables.');
    }
  }

  /// Helper getter to retrieve key with priority:
  /// 1. flutter_dotenv (.env asset)
  /// 2. --dart-define (String.fromEnvironment)
  /// 3. Fallback default value
  static String _get(String key, {String defaultValue = ''}) {
    if (_isLoaded && dotenv.env.containsKey(key)) {
      final value = dotenv.env[key]?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return String.fromEnvironment(key, defaultValue: defaultValue);
  }

  // --- Supabase Config ---
  static String get supabaseUrl => _get(
        'SUPABASE_URL',
        defaultValue: 'https://placeholder.supabase.co',
      );

  static String get supabaseAnonKey => _get(
        'SUPABASE_ANON_KEY',
        defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.placeholder',
      );

  // --- AI API Keys ---
  static String get geminiApiKey => _get('GEMINI_API_KEY');
  static String get openaiApiKey => _get('OPENAI_API_KEY');

  // --- App Environment ---
  static String get environment => _get('ENVIRONMENT', defaultValue: 'development');
  static bool get isProduction => environment.toLowerCase() == 'production';
  static bool get isDevelopment => !isProduction;
}
