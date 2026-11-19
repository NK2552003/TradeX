import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint, kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alphajournal/core/config/cross_subdomain_storage.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'message_cipher.dart';

class PrivateMessageService {
  static final instance = PrivateMessageService();
  static const String _handoffDataCookie = 'ax_e2ee_v1';
  static const String _handoffKeyCookie = 'ax_e2ee_k';

  final cipher = MessageCipher();
  final storage = const FlutterSecureStorage();
  final ValueNotifier<int> unlockRevision = ValueNotifier<int>(0);

  String? _cachedUserId;
  List<int>? _cachedSeed;

  SupabaseClient get client => SupabaseConfig.client!;
  String get owner =>
      client.auth.currentUser?.id ?? (throw StateError('Sign in required.'));
  String _key(String user) =>
      'alphajournal.e2ee.${SupabaseConfig.supabaseUrl}.$user';
  String _legacyKey(String user) =>
      'tradex.e2ee.${SupabaseConfig.supabaseUrl}.$user';

  Future<String?> _readStoredSeed(String user) async {
    final current = await storage.read(key: _key(user));
    if (current != null && current.isNotEmpty) return current;
    final legacy = await storage.read(key: _legacyKey(user));
    if (legacy == null || legacy.isEmpty) return null;
    await storage.write(key: _key(user), value: legacy);
    await storage.delete(key: _legacyKey(user));
    return legacy;
  }

  /// Returns `true` immediately when the active user's 32-byte E2EE seed is
  /// already loaded in memory, avoiding intermediate loading flashes on screen
  /// transitions.
  bool get isLocallyUnlockedFast {
    if (!SupabaseConfig.isConfigured) return false;
    final userId = SupabaseConfig.client?.auth.currentUser?.id;
    return userId != null &&
        userId == _cachedUserId &&
        _cachedSeed != null &&
        _cachedSeed!.length == 32;
  }

  /// Seals a 32-byte seed into a compact base64 AES-256-GCM envelope bound to
  /// [userId] via AAD for cross-subdomain session handoff on `.alphajournal.in`.
  static Future<String> sealHandoffSeed({
    required List<int> seed,
    required List<int> wrappingKey,
    required String userId,
  }) async {
    final algorithm = AesGcm.with256bits();
    final box = await algorithm.encrypt(
      seed,
      secretKey: SecretKey(wrappingKey),
      aad: utf8.encode('handoff/$userId'),
    );
    return base64Encode(<int>[
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  /// Unseals a cross-subdomain handoff envelope created by [sealHandoffSeed].
  static Future<List<int>?> openHandoffSeed({
    required String encodedEnvelope,
    required List<int> wrappingKey,
    required String userId,
  }) async {
    try {
      final raw = base64Decode(encodedEnvelope);
      // 12-byte nonce + 32-byte seed + 16-byte GCM tag = 60 bytes.
      if (raw.length != 60 || wrappingKey.length != 32) return null;
      final algorithm = AesGcm.with256bits();
      final clear = await algorithm.decrypt(
        SecretBox(
          raw.sublist(12, 44),
          nonce: raw.sublist(0, 12),
          mac: Mac(raw.sublist(44, 60)),
        ),
        secretKey: SecretKey(wrappingKey),
        aad: utf8.encode('handoff/$userId'),
      );
      return clear.length == 32 ? clear : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistUnlockedSeed(String user, List<int> seed) async {
    _cachedUserId = user;
    _cachedSeed = List<int>.unmodifiable(seed);
    await storage.write(key: _key(user), value: base64Encode(seed));
    if (kIsWeb) {
      try {
        final rawKey = await (await AesGcm.with256bits().newSecretKey())
            .extractBytes();
        final envelope = await sealHandoffSeed(
          seed: seed,
          wrappingKey: rawKey,
          userId: user,
        );
        CrossSubdomainState.setFlag(
          _handoffKeyCookie,
          base64Encode(rawKey),
          maxAgeDays: 30,
        );
        CrossSubdomainState.setFlag(
          _handoffDataCookie,
          envelope,
          maxAgeDays: 30,
        );
      } catch (e) {
        debugPrint(
          '[PrivateMessageService] Cross-subdomain handoff write skipped: $e',
        );
      }
    }
    unlockRevision.value++;
  }

  /// Attempts to populate memory and local origin storage from either local
  /// [FlutterSecureStorage] or the shared `.alphajournal.in` handoff cookies.
  Future<bool> warmFromCache() async {
    if (!SupabaseConfig.isConfigured) return false;
    final user = SupabaseConfig.client?.auth.currentUser?.id;
    if (user == null) {
      _cachedUserId = null;
      _cachedSeed = null;
      return false;
    }
    if (_cachedUserId == user &&
        _cachedSeed != null &&
        _cachedSeed!.length == 32) {
      return true;
    }
    try {
      final stored = await _readStoredSeed(user);
      if (stored != null && stored.isNotEmpty) {
        final decoded = base64Decode(stored);
        if (decoded.length == 32) {
          _cachedUserId = user;
          _cachedSeed = List<int>.unmodifiable(decoded);
          unlockRevision.value++;
          return true;
        }
      }
    } catch (_) {
      await storage.delete(key: _key(user));
    }

    if (kIsWeb) {
      final keyRaw = CrossSubdomainState.getFlag(_handoffKeyCookie);
      final dataRaw = CrossSubdomainState.getFlag(_handoffDataCookie);
      if (keyRaw != null &&
          keyRaw.isNotEmpty &&
          dataRaw != null &&
          dataRaw.isNotEmpty) {
        try {
          final seed = await openHandoffSeed(
            encodedEnvelope: dataRaw,
            wrappingKey: base64Decode(keyRaw),
            userId: user,
          );
          if (seed != null && seed.length == 32) {
            _cachedUserId = user;
            _cachedSeed = List<int>.unmodifiable(seed);
            await storage.write(key: _key(user), value: base64Encode(seed));
            unlockRevision.value++;
            return true;
          }
        } catch (_) {}
      }
    }
    return false;
  }

  /// Clears in-memory and shared cross-subdomain E2EE unlock state on logout.
  static Future<void> clearLocalUnlockCache({String? userId}) async {
    instance._cachedUserId = null;
    instance._cachedSeed = null;
    CrossSubdomainState.removeFlag(_handoffDataCookie);
    CrossSubdomainState.removeFlag(_handoffKeyCookie);
    final targetUser =
        userId ??
        (SupabaseConfig.isConfigured
            ? SupabaseConfig.client?.auth.currentUser?.id
            : null);
    if (targetUser != null && targetUser.isNotEmpty) {
      try {
        await instance.storage.delete(key: instance._key(targetUser));
        await instance.storage.delete(key: instance._legacyKey(targetUser));
      } catch (_) {}
    }
    instance.unlockRevision.value++;
  }

  Future<SimpleKeyPair> _identity(String user) async {
    if (_cachedUserId == user &&
        _cachedSeed != null &&
        _cachedSeed!.length == 32) {
      return cipher.identityFromSeedBytes(_cachedSeed!);
    }
    await warmFromCache();
    if (_cachedUserId == user &&
        _cachedSeed != null &&
        _cachedSeed!.length == 32) {
      return cipher.identityFromSeedBytes(_cachedSeed!);
    }
    final encoded = await _readStoredSeed(user);
    if (encoded == null) {
      throw StateError(
        'Unlock encrypted messaging with your account password or recovery passphrase.',
      );
    }
    final decoded = base64Decode(encoded);
    _cachedUserId = user;
    _cachedSeed = List<int>.unmodifiable(decoded);
    return cipher.identityFromSeedBytes(decoded);
  }

  /// Checks identity existence and local key unlock state in a single query.
  Future<({bool unlocked, bool hasIdentity})> checkStatus() async {
    final user = owner;
    final warmed = await warmFromCache();
    final row = await client
        .from('message_identities')
        .select('public_key,signing_key')
        .eq('user_id', user)
        .maybeSingle();
    if (row == null) {
      _cachedUserId = null;
      _cachedSeed = null;
      return (unlocked: false, hasIdentity: false);
    }
    if (!warmed) {
      final stored = await _readStoredSeed(user);
      if (stored == null) {
        return (unlocked: false, hasIdentity: true);
      }
    }
    try {
      final public = await (await _identity(user)).extractPublicKey();
      if (base64Encode(public.bytes) != row['public_key']) {
        // Clear mismatched local cache so the user can re-unlock cleanly.
        _cachedUserId = null;
        _cachedSeed = null;
        await storage.delete(key: _key(user));
        CrossSubdomainState.removeFlag(_handoffDataCookie);
        CrossSubdomainState.removeFlag(_handoffKeyCookie);
        return (unlocked: false, hasIdentity: true);
      }
      if (kIsWeb &&
          CrossSubdomainState.getFlag(_handoffDataCookie) == null &&
          _cachedSeed != null) {
        await _persistUnlockedSeed(user, _cachedSeed!);
      }
      return (unlocked: true, hasIdentity: true);
    } on FormatException {
      _cachedUserId = null;
      _cachedSeed = null;
      await storage.delete(key: _key(user));
      return (unlocked: false, hasIdentity: true);
    }
  }

  Future<bool> hasIdentity() async => (await checkStatus()).hasIdentity;

  Future<bool> isUnlocked() async => (await checkStatus()).unlocked;

  Future<void> unlock(
    String passphrase, {
    bool allowAccountPassword = false,
  }) async {
    final user = owner;
    final row = await client
        .from('message_identities')
        .select()
        .eq('user_id', user)
        .maybeSingle();
    if (row == null && !allowAccountPassword && passphrase.trim().length < 16) {
      throw StateError(
        'Choose a recovery passphrase of at least 16 characters. Save it in your password manager.',
      );
    }
    if (row == null && allowAccountPassword && passphrase.isEmpty) {
      throw StateError(
        'Enter your account password to secure encrypted messaging.',
      );
    }
    final salt = row == null
        ? (await AesGcm.with256bits().newSecretKey()).extractBytes()
        : Future.value(base64Decode(row['salt'] as String));
    final saltBytes = await salt;
    final recoveryKey =
        await Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: 600000,
          bits: 256,
        ).deriveKey(
          secretKey: SecretKey(utf8.encode(passphrase)),
          nonce: saltBytes,
        );
    List<int> seed;
    if (row == null) {
      final pair = await cipher.newIdentity();
      seed = await pair.extractPrivateKeyBytes();
      final public = await pair.extractPublicKey();
      final backup = await cipher.seal(seed, recoveryKey, 'recovery/$user');
      await client.from('message_identities').insert({
        'user_id': user,
        'public_key': base64Encode(public.bytes),
        'signing_key': base64Encode(
          (await cipher.signingPublicKey(pair)).bytes,
        ),
        'salt': base64Encode(saltBytes),
        'backup': backup,
      });
    } else {
      try {
        seed = await cipher.open(
          Map<String, dynamic>.from(row['backup'] as Map),
          recoveryKey,
          'recovery/$user',
        );
        final pair = await X25519().newKeyPairFromSeed(seed);
        if (base64Encode((await pair.extractPublicKey()).bytes) !=
            row['public_key']) {
          throw const FormatException('Identity mismatch');
        }
      } catch (_) {
        throw StateError(
          'Unable to unlock. Check your password or recovery passphrase.',
        );
      }
    }
    if (owner != user) throw StateError('Account changed. Please try again.');
    await _persistUnlockedSeed(user, seed);
  }

  /// Automatically initializes or unlocks E2EE keys using the password just
  /// entered during login/signup. Returns `false` silently when a legacy
  /// account uses a separate recovery passphrase so auth itself is never
  /// interrupted.
  Future<bool> trySilentUnlockWithPassword(String password) async {
    if (!SupabaseConfig.isConfigured || password.isEmpty) return false;
    final user = SupabaseConfig.client?.auth.currentUser?.id;
    if (user == null) return false;
    try {
      final status = await checkStatus();
      if (status.unlocked) return true;
      await unlock(password, allowAccountPassword: true);
      return true;
    } catch (e) {
      debugPrint('[PrivateMessageService] Silent password unlock skipped: $e');
      return false;
    }
  }

  /// Re-wraps the already-unlocked E2EE seed with [newSecret] without changing
  /// immutable `public_key` or `signing_key`. Call after changing account
  /// password so future logins continue unlocking automatically.
  Future<void> rekeyBackup(String newSecret) async {
    if (newSecret.isEmpty) {
      throw StateError(
        'A valid password is required to re-wrap encryption keys.',
      );
    }
    final user = owner;
    final identity = await _identity(user);
    final seed = await identity.extractPrivateKeyBytes();
    final saltBytes = await (await AesGcm.with256bits().newSecretKey())
        .extractBytes();
    final newKey = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 600000,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode(newSecret)), nonce: saltBytes);
    final backup = await cipher.seal(seed, newKey, 'recovery/$user');
    await client
        .from('message_identities')
        .update({'salt': base64Encode(saltBytes), 'backup': backup})
        .eq('user_id', user);
    await _persistUnlockedSeed(user, seed);
  }

  Future<SimplePublicKey> publicKey(String user) async {
    final row = await client
        .from('message_public_keys')
        .select('public_key,signing_key')
        .eq('user_id', user)
        .maybeSingle();
    if (row == null) {
      throw StateError(
        'A recipient must set up encrypted messaging before you can send.',
      );
    }
    final key = '${row['public_key']}:${row['signing_key']}';
    final pinName = '${_key(owner)}.peer.$user';
    final pinned = await storage.read(key: pinName);
    if (pinned != null && pinned != key) {
      throw StateError('Recipient encryption key changed. Sending is blocked.');
    }
    if (pinned == null) await storage.write(key: pinName, value: key);
    return SimplePublicKey(
      base64Decode(row['public_key'] as String),
      type: KeyPairType.x25519,
    );
  }

  Future<SimplePublicKey> signingPublicKey(String user) async {
    // publicKey pins both the DH and signing identity before this lookup.
    await publicKey(user);
    final pinned = await storage.read(key: '${_key(owner)}.peer.$user');
    return SimplePublicKey(
      base64Decode(pinned!.split(':')[1]),
      type: KeyPairType.ed25519,
    );
  }

  Future<String> encrypt(
    String value,
    String context,
    Iterable<String> users,
  ) async {
    final user = owner;
    final recipients = <String, SimplePublicKey>{};
    for (final id in {...users, user}) {
      recipients[id] = await publicKey(id);
    }
    final identity = await _identity(user);
    if (owner != user) throw StateError('Account changed. Please try again.');
    return cipher.encrypt(
      value,
      context: context,
      sender: user,
      identity: identity,
      recipients: recipients,
    );
  }

  Future<String> decrypt(String value, String context, String sender) async {
    // Historic plaintext remains readable; only new writes are encrypted.
    if (!value.startsWith(MessageCipher.prefix)) return value;
    final user = owner;
    final identity = await _identity(user);
    final senderPublicKey = await publicKey(sender);
    final senderSigningKey = await signingPublicKey(sender);
    final plain = await decryptWithKeys(
      value,
      context: context,
      user: user,
      sender: sender,
      identity: identity,
      senderPublicKey: senderPublicKey,
      senderSigningKey: senderSigningKey,
    );
    if (owner != user) throw StateError('Account changed. Please try again.');
    return plain;
  }

  /// Opens an encrypted payload using already-resolved keys, with single-user
  /// recovery for self-encrypted rows signed during WebCrypto clamping skew.
  Future<String> decryptWithKeys(
    String value, {
    required String context,
    required String user,
    required String sender,
    required SimpleKeyPair identity,
    required SimplePublicKey senderPublicKey,
    required SimplePublicKey senderSigningKey,
  }) async {
    try {
      return await cipher.decrypt(
        value,
        context: context,
        recipient: user,
        sender: sender,
        identity: identity,
        senderKey: senderPublicKey,
        signingKey: senderSigningKey,
      );
    } on FormatException catch (error) {
      if (sender != user ||
          !error.message.contains('Message signature is invalid')) {
        rethrow;
      }
      // Recover self-encrypted rows written while _identity clamped WebCrypto
      // seeds during signing against an unclamped published signing key.
      final clamped = await X25519().newKeyPairFromSeed(
        await identity.extractPrivateKeyBytes(),
      );
      final clampedSigningKey = await cipher.signingPublicKey(clamped);
      if (_bytesEqual(clampedSigningKey.bytes, senderSigningKey.bytes)) {
        rethrow;
      }
      return cipher.decrypt(
        value,
        context: context,
        recipient: user,
        sender: sender,
        identity: identity,
        senderKey: senderPublicKey,
        signingKey: clampedSigningKey,
      );
    }
  }

  bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<List<String>> participants(String thread) async {
    final rows = await client
        .from('chat_participants')
        .select('user_id')
        .eq('thread_id', thread);
    final users = rows.map((r) => r['user_id'] as String).toList();
    if (!users.contains(owner) || users.length < 2) {
      throw StateError('Conversation membership is incomplete.');
    }
    return users;
  }

  Future<String> encryptChat(String value, String thread, String id) async =>
      encrypt(value, 'chat/$thread/$id', await participants(thread));
}
