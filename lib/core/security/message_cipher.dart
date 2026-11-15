import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Versioned authenticated envelopes. Routing context is authenticated as AAD.
/// Static X25519 recipient keys do not provide forward secrecy.
class MessageCipher {
  static const prefix = 'e2ee:v1:';
  final _aes = AesGcm.with256bits();
  final _dh = X25519();

  Future<SimpleKeyPair> newIdentity() => _dh.newKeyPair();

  Future<SimpleKeyPair> _signingIdentity(SimpleKeyPair identity) async {
    final seed = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(await identity.extractPrivateKeyBytes()),
      nonce: utf8.encode('tradex/signing/v1'),
      info: const [],
    );
    return Ed25519().newKeyPairFromSeed(await seed.extractBytes());
  }

  Future<SimplePublicKey> signingPublicKey(SimpleKeyPair identity) async =>
      (await _signingIdentity(identity)).extractPublicKey();

  Future<SecretKey> _wrappingKey(
    SimpleKeyPair local,
    SimplePublicKey remote,
    String context,
  ) async {
    final shared = await _dh.sharedSecretKey(
      keyPair: local,
      remotePublicKey: remote,
    );
    return Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: shared,
      nonce: utf8.encode('tradex/e2ee/v1'),
      info: utf8.encode(context),
    );
  }

  Future<Map<String, dynamic>> seal(
    List<int> bytes,
    SecretKey key,
    String context,
  ) async {
    final box = await _aes.encrypt(
      bytes,
      secretKey: key,
      aad: utf8.encode(context),
    );
    return {
      'n': base64Encode(box.nonce),
      'c': base64Encode(box.cipherText),
      't': base64Encode(box.mac.bytes),
    };
  }

  Future<List<int>> open(
    Map<String, dynamic> data,
    SecretKey key,
    String context,
  ) => _aes.decrypt(
    SecretBox(
      base64Decode(data['c'] as String),
      nonce: base64Decode(data['n'] as String),
      mac: Mac(base64Decode(data['t'] as String)),
    ),
    secretKey: key,
    aad: utf8.encode(context),
  );

  Future<String> encrypt(
    String plaintext, {
    required String context,
    required String sender,
    required SimpleKeyPair identity,
    required Map<String, SimplePublicKey> recipients,
  }) async {
    if (recipients.isEmpty || !recipients.containsKey(sender)) {
      throw StateError('Encryption requires the sender and every recipient.');
    }
    final key = await _aes.newSecretKey();
    final keyBytes = await key.extractBytes();
    final wrapped = <String, dynamic>{};
    for (final entry in recipients.entries) {
      final aad = '$context/$sender/${entry.key}';
      wrapped[entry.key] = await seal(
        keyBytes,
        await _wrappingKey(identity, entry.value, aad),
        aad,
      );
    }
    final aad = '$context/$sender';
    final data = base64Encode(
      utf8.encode(
        jsonEncode({
          'sender': sender,
          'keys': wrapped,
          'payload': await seal(utf8.encode(plaintext), key, aad),
        }),
      ),
    );
    final signature = await Ed25519().sign(
      utf8.encode('$context\n$data'),
      keyPair: await _signingIdentity(identity),
    );
    return prefix +
        base64Encode(
          utf8.encode(
            jsonEncode({
              'data': data,
              'signature': base64Encode(signature.bytes),
            }),
          ),
        );
  }

  Future<String> decrypt(
    String ciphertext, {
    required String context,
    required String recipient,
    required String sender,
    required SimpleKeyPair identity,
    required SimplePublicKey senderKey,
    required SimplePublicKey signingKey,
  }) async {
    if (!ciphertext.startsWith(prefix)) {
      throw const FormatException('Not an encrypted message');
    }
    final envelope =
        jsonDecode(
              utf8.decode(base64Decode(ciphertext.substring(prefix.length))),
            )
            as Map<String, dynamic>;
    final encoded = envelope['data'] as String;
    final valid = await Ed25519().verify(
      utf8.encode('$context\n$encoded'),
      signature: Signature(
        base64Decode(envelope['signature'] as String),
        publicKey: signingKey,
      ),
    );
    if (!valid) throw const FormatException('Message signature is invalid');
    final data =
        jsonDecode(utf8.decode(base64Decode(encoded))) as Map<String, dynamic>;
    if (data['sender'] != sender) {
      throw const FormatException('Sender mismatch');
    }
    final wrapped = (data['keys'] as Map)[recipient];
    if (wrapped == null) {
      throw StateError('This account cannot decrypt this message.');
    }
    final aad = '$context/$sender/$recipient';
    final key = await open(
      Map<String, dynamic>.from(wrapped as Map),
      await _wrappingKey(identity, senderKey, aad),
      aad,
    );
    return utf8.decode(
      await open(
        Map<String, dynamic>.from(data['payload'] as Map),
        SecretKey(key),
        '$context/$sender',
      ),
    );
  }
}
