import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stores the native Supabase session in the OS credential store.
class CrossSubdomainLocalStorage extends LocalStorage {
  CrossSubdomainLocalStorage({required this.persistSessionKey});

  factory CrossSubdomainLocalStorage.forUrl(String supabaseUrl) {
    final host = Uri.tryParse(supabaseUrl)?.host ?? '';
    final ref = host.isNotEmpty ? host.split('.').first : 'local';
    return CrossSubdomainLocalStorage(persistSessionKey: 'sb-$ref-auth-token');
  }

  final String persistSessionKey;
  static const _storage = FlutterSecureStorage();
  Future<void>? _initialization;
  Future<void> _pendingWrite = Future.value();

  @override
  Future<void> initialize() => _initialization ??= _migrateLegacySession();

  Future<void> _migrateLegacySession() async {
    final preferences = await SharedPreferences.getInstance();
    final legacySession = preferences.getString(persistSessionKey);
    if (legacySession == null) return;
    try {
      final secureSession = await _storage.read(key: persistSessionKey);
      if (secureSession == null) {
        await _storage.write(key: persistSessionKey, value: legacySession);
      }
      await preferences.remove(persistSessionKey);
    } on PlatformException {
      // Retry migration at the next launch if the credential store was locked.
    } on MissingPluginException {
      // This runtime has no platform credential store.
    }
  }

  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;

  @override
  Future<String?> accessToken() async {
    await initialize();
    await _pendingWrite;
    try {
      return await _storage.read(key: persistSessionKey);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> removePersistedSession() => _writeSession(null);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _writeSession(persistSessionString);

  Future<void> _writeSession(String? session) {
    final operation = _pendingWrite.then((_) => _storeSession(session));
    _pendingWrite = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  Future<void> _storeSession(String? session) async {
    await initialize();
    final preferences = await SharedPreferences.getInstance();
    if (session == null) {
      try {
        await preferences.remove(persistSessionKey);
      } finally {
        await _storage.delete(key: persistSessionKey);
      }
      return;
    }
    await _storage.write(key: persistSessionKey, value: session);
    await preferences.remove(persistSessionKey);
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
