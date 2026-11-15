import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'message_cipher.dart';

class PrivateMessageService {
  static final instance = PrivateMessageService();
  final cipher = MessageCipher();
  final storage = const FlutterSecureStorage();
  SupabaseClient get client => SupabaseConfig.client!;
  String get owner =>
      client.auth.currentUser?.id ?? (throw StateError('Sign in required.'));
  String _key(String user) => 'tradex.e2ee.${SupabaseConfig.supabaseUrl}.$user';

  Future<SimpleKeyPair> _identity(String user) async {
    final encoded = await storage.read(key: _key(user));
    if (encoded == null) {
      throw StateError(
        'Unlock encrypted messaging with your recovery passphrase.',
      );
    }
    return X25519().newKeyPairFromSeed(base64Decode(encoded));
  }

  /// Checks identity existence and local key unlock state in a single query.
  Future<({bool unlocked, bool hasIdentity})> checkStatus() async {
    final user = owner;
    final row = await client
        .from('message_identities')
        .select('public_key,signing_key')
        .eq('user_id', user)
        .maybeSingle();
    if (row == null) {
      return (unlocked: false, hasIdentity: false);
    }
    final stored = await storage.read(key: _key(user));
    if (stored == null) {
      return (unlocked: false, hasIdentity: true);
    }
    try {
      final public = await (await _identity(user)).extractPublicKey();
      if (base64Encode(public.bytes) != row['public_key']) {
        // Clear mismatched local cache so the user can re-unlock cleanly.
        await storage.delete(key: _key(user));
        return (unlocked: false, hasIdentity: true);
      }
      return (unlocked: true, hasIdentity: true);
    } on FormatException {
      await storage.delete(key: _key(user));
      return (unlocked: false, hasIdentity: true);
    }
  }

  Future<bool> hasIdentity() async => (await checkStatus()).hasIdentity;

  Future<bool> isUnlocked() async => (await checkStatus()).unlocked;

  Future<void> unlock(String passphrase) async {
    final user = owner;
    final row = await client
        .from('message_identities')
        .select()
        .eq('user_id', user)
        .maybeSingle();
    if (row == null && passphrase.trim().length < 16) {
      throw StateError(
        'Choose a recovery passphrase of at least 16 characters. Save it in your password manager.',
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
        throw StateError('Unable to unlock. Check your recovery passphrase.');
      }
    }
    if (owner != user) throw StateError('Account changed. Please try again.');
    await storage.write(key: _key(user), value: base64Encode(seed));
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
    final plain = await cipher.decrypt(
      value,
      context: context,
      recipient: user,
      sender: sender,
      identity: await _identity(user),
      senderKey: await publicKey(sender),
      signingKey: await signingPublicKey(sender),
    );
    if (owner != user) throw StateError('Account changed. Please try again.');
    return plain;
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
