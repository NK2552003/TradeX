import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Native/VM fallback Supabase [LocalStorage] using [SharedPreferences].
class CrossSubdomainLocalStorage extends LocalStorage {
  CrossSubdomainLocalStorage({required this.persistSessionKey});

  factory CrossSubdomainLocalStorage.forUrl(String supabaseUrl) {
    final host = Uri.tryParse(supabaseUrl)?.host ?? '';
    final ref = host.isNotEmpty ? host.split('.').first : 'local';
    return CrossSubdomainLocalStorage(persistSessionKey: 'sb-$ref-auth-token');
  }

  final String persistSessionKey;
  late final SharedPreferences _preferences;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _preferences = await SharedPreferences.getInstance();
    _initialized = true;
  }

  @override
  Future<bool> hasAccessToken() async {
    if (!_initialized) await initialize();
    return _preferences.containsKey(persistSessionKey);
  }

  @override
  Future<String?> accessToken() async {
    if (!_initialized) await initialize();
    return _preferences.getString(persistSessionKey);
  }

  @override
  Future<void> removePersistedSession() async {
    if (!_initialized) await initialize();
    await _preferences.remove(persistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    if (!_initialized) await initialize();
    await _preferences.setString(persistSessionKey, persistSessionString);
  }
}

String? getSharedFlag(String key) => null;

String? getLocalPreferenceFallback(String key) => null;

void setSharedFlag(String key, String value, {int maxAgeDays = 30}) {}

void removeSharedFlag(String key) {}

void syncWebTheme({
  required String mode,
  required String density,
  required bool isLight,
}) {}

void navigateBrowserUrl(String url) {}
