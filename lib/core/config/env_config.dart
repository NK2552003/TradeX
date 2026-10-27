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
      debugPrint(
        '[EnvConfig] Could not load .env file: $e. Falling back to compile-time env variables.',
      );
    }
  }

  /// Helper getter to retrieve key with priority:
  /// 1. Direct match in dotenv (.env)
  /// 2. NEXT_PUBLIC_ / VITE_ / REACT_APP_ prefixed key in dotenv
  /// 3. --dart-define (String.fromEnvironment)
  /// 4. Fallback default value
  static String _get(String key, {String defaultValue = ''}) {
    if (_isLoaded) {
      // 1. Exact key match
      if (dotenv.env.containsKey(key)) {
        final val = dotenv.env[key]?.trim() ?? '';
        if (val.isNotEmpty) return val;
      }
      // 2. NEXT_PUBLIC_ prefix match
      final nextPublicKey = 'NEXT_PUBLIC_$key';
      if (dotenv.env.containsKey(nextPublicKey)) {
        final val = dotenv.env[nextPublicKey]?.trim() ?? '';
        if (val.isNotEmpty) return val;
      }
      // 3. VITE_ prefix match
      final viteKey = 'VITE_$key';
      if (dotenv.env.containsKey(viteKey)) {
        final val = dotenv.env[viteKey]?.trim() ?? '';
        if (val.isNotEmpty) return val;
      }
      // 4. REACT_APP_ prefix match
      final reactKey = 'REACT_APP_$key';
      if (dotenv.env.containsKey(reactKey)) {
        final val = dotenv.env[reactKey]?.trim() ?? '';
        if (val.isNotEmpty) return val;
      }
    }

    // 5. Dart environment compile-time variables
    final envVal = String.fromEnvironment(key);
    if (envVal.isNotEmpty) return envVal;

    final nextPublicEnv = String.fromEnvironment('NEXT_PUBLIC_$key');
    if (nextPublicEnv.isNotEmpty) return nextPublicEnv;

    return defaultValue;
  }

  // --- Supabase Config ---
  static String get supabaseUrl =>
      _get('SUPABASE_URL', defaultValue: 'https://placeholder.supabase.co');

  static String get supabaseAnonKey => _get(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.placeholder',
  );

  // --- AI API Keys ---
  static String get openrouterApiKey => _get('OPENROUTER_API_KEY');
  static String get geminiApiKey => _get('GEMINI_API_KEY');
  static String get openaiApiKey => _get('OPENAI_API_KEY');
  static String get claudeApiKey {
    final claude = _get('CLAUDE_API_KEY');
    if (claude.isNotEmpty) return claude;
    return _get('ANTHROPIC_API_KEY');
  }

  static bool get hasAiKey =>
      openrouterApiKey.isNotEmpty ||
      geminiApiKey.isNotEmpty ||
      openaiApiKey.isNotEmpty ||
      claudeApiKey.isNotEmpty;

  // Publishable client identifiers only. Never put a Razorpay secret or a
  // RevenueCat secret API key in an application asset or dart-define.
  static String get revenueCatTestApiKey => _get('REVENUECAT_TEST_API_KEY');
  static String get revenueCatAndroidApiKey =>
      _get('REVENUECAT_ANDROID_API_KEY');
  static String get revenueCatIosApiKey => _get('REVENUECAT_IOS_API_KEY');
  static String get razorpayTestKeyId => _get('RAZORPAY_TEST_KEY_ID');

  // --- App Environment ---
  static String get environment =>
      _get('ENVIRONMENT', defaultValue: 'development');
  static bool get isProduction => environment.toLowerCase() == 'production';
  static bool get isDevelopment => !isProduction;
}
