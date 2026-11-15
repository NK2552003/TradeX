import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/security/message_cipher.dart';

void main() {
  final cipher = MessageCipher();
  test(
    'only intended recipients can read; sender, context and tampering are authenticated',
    () async {
      final alice = await cipher.newIdentity();
      final bob = await cipher.newIdentity();
      final eve = await cipher.newIdentity();
      final alicePublic = await alice.extractPublicKey();
      final signingKey = await cipher.signingPublicKey(alice);
      final ciphertext = await cipher.encrypt(
        'private attachment and text',
        context: 'chat/thread/message',
        sender: 'alice',
        identity: alice,
        recipients: {'alice': alicePublic, 'bob': await bob.extractPublicKey()},
      );
      expect(ciphertext, isNot(contains('private attachment')));
      Future<String> read(
        String text, {
        String context = 'chat/thread/message',
        String sender = 'alice',
        SimpleKeyPair? key,
      }) => cipher.decrypt(
        text,
        context: context,
        sender: sender,
        recipient: 'bob',
        identity: key ?? bob,
        senderKey: alicePublic,
        signingKey: signingKey,
      );
      expect(await read(ciphertext), 'private attachment and text');
      expect(
        await cipher.decrypt(
          ciphertext,
          context: 'chat/thread/message',
          sender: 'alice',
          recipient: 'alice',
          identity: alice,
          senderKey: alicePublic,
          signingKey: signingKey,
        ),
        'private attachment and text',
      );
      final restoredBob = await X25519().newKeyPairFromSeed(
        await bob.extractPrivateKeyBytes(),
      );
      expect(
        await read(ciphertext, key: restoredBob),
        'private attachment and text',
      );
      final forged = await cipher.encrypt(
        'forged by recipient',
        context: 'chat/thread/message',
        sender: 'alice',
        identity: bob,
        recipients: {'alice': alicePublic, 'bob': await bob.extractPublicKey()},
      );
      await expectLater(read(forged), throwsA(isA<FormatException>()));
      await expectLater(
        read(ciphertext, context: 'chat/other/message'),
        throwsA(anything),
      );
      await expectLater(read(ciphertext, sender: 'eve'), throwsA(anything));
      await expectLater(read(ciphertext, key: eve), throwsA(anything));
      final data = jsonDecode(
        utf8.decode(
          base64Decode(ciphertext.substring(MessageCipher.prefix.length)),
        ),
      );
      final inner = jsonDecode(
        utf8.decode(base64Decode(data['data'] as String)),
      );
      final bytes = base64Decode(inner['payload']['c'] as String);
      bytes[0] ^= 1;
      inner['payload']['c'] = base64Encode(bytes);
      data['data'] = base64Encode(utf8.encode(jsonEncode(inner)));
      await expectLater(
        read(
          MessageCipher.prefix + base64Encode(utf8.encode(jsonEncode(data))),
        ),
        throwsA(anything),
      );
    },
  );
  test(
    'fresh nonces produce different ciphertext for repeated messages',
    () async {
      final pair = await cipher.newIdentity();
      Future<String> encrypt() async => cipher.encrypt(
        'same',
        context: 'chat/t/m',
        sender: 'a',
        identity: pair,
        recipients: {'a': await pair.extractPublicKey()},
      );
      expect(await encrypt(), isNot(await encrypt()));
    },
  );
  test('recovery fails with a wrong key or different owner', () async {
    final key = await AesGcm.with256bits().newSecretKey();
    final backup = await cipher.seal([1, 2, 3], key, 'recovery/alice');
    expect(await cipher.open(backup, key, 'recovery/alice'), [1, 2, 3]);
    await expectLater(
      cipher.open(backup, key, 'recovery/bob'),
      throwsA(anything),
    );
    await expectLater(
      cipher.open(
        backup,
        await AesGcm.with256bits().newSecretKey(),
        'recovery/alice',
      ),
      throwsA(anything),
    );
  });
}
