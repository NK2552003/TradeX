import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'package:alphajournal/features/copilot/models/workspace.dart';
import 'package:alphajournal/features/copilot/models/workspace_errors.dart';

export 'package:alphajournal/features/copilot/models/workspace_errors.dart';

class WorkspaceEncryptionException extends CopilotFailure {
  const WorkspaceEncryptionException(String message) : super(message, 500);
}

void resetContinuation(Json thread) {
  thread.remove('responseId');
  thread.remove('continuation');
  for (final approval in thread['approvals'] as List? ?? []) {
    if (approval['status'] == 'pending' || approval['status'] == 'executing') {
      approval['status'] = 'interrupted';
      approval['result'] = {
        'error':
            'Interrupted. Check the destination before requesting another action; execution may already have occurred.',
      };
    }
  }
}

class WorkspaceStore {
  static const int currentEnvelopeVersion = 1;
  static const String currentAlgorithm = 'AES-256-GCM';

  WorkspaceStore(
    this.directory, {
    String? encryptionKey,
    String? previousEncryptionKey,
    bool requireExplicitKey = false,
  }) : _activeKey = _resolveKey(
         encryptionKey,
         requireExplicitKey: requireExplicitKey,
       ),
       _previousKey =
           previousEncryptionKey != null &&
               previousEncryptionKey.trim().isNotEmpty
           ? parseKeyMaterial(previousEncryptionKey)
           : _resolveOptionalEnvKey();

  final Directory directory;
  Uint8List _activeKey;
  Uint8List? _previousKey;
  final Map<String, Json> _cache = {};
  Future<void> _queue = Future.value();
  RandomAccessFile? _lock;
  final Random _random = _createSecureRandom();

  static Random _createSecureRandom() {
    try {
      return Random.secure();
    } catch (_) {
      return Random();
    }
  }

  static Uint8List _resolveKey(
    String? explicitKey, {
    required bool requireExplicitKey,
  }) {
    if (explicitKey != null) {
      return parseKeyMaterial(explicitKey);
    }
    final envKey =
        Platform.environment['COPILOT_WORKSPACE_KEY'] ??
        Platform.environment['COPILOT_ENCRYPTION_KEY'];
    if (envKey != null && envKey.trim().isNotEmpty) {
      return parseKeyMaterial(envKey);
    }
    throw const WorkspaceEncryptionException(
      'COPILOT_WORKSPACE_KEY is required and must be a valid 256-bit (32-byte) key encoded as hex or base64.',
    );
  }

  static Uint8List? _resolveOptionalEnvKey() {
    final prev =
        Platform.environment['COPILOT_PREVIOUS_WORKSPACE_KEY'] ??
        Platform.environment['COPILOT_PREVIOUS_ENCRYPTION_KEY'];
    if (prev == null || prev.trim().isEmpty) return null;
    return parseKeyMaterial(prev);
  }

  /// Validates and decodes a 256-bit (32-byte) key from hex (64 chars) or base64/base64url.
  /// Never includes the raw key material in exception messages.
  static Uint8List parseKeyMaterial(String rawKey) {
    final trimmed = rawKey.trim();
    if (trimmed.isEmpty) {
      throw const WorkspaceEncryptionException(
        'Workspace encryption key is missing. Configure a 256-bit key in COPILOT_WORKSPACE_KEY.',
      );
    }
    Uint8List? decoded;
    if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(trimmed)) {
      decoded = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        decoded[i] = int.parse(trimmed.substring(i * 2, i * 2 + 2), radix: 16);
      }
    } else {
      try {
        final normalized = base64Url.normalize(
          trimmed.replaceAll('+', '-').replaceAll('/', '_'),
        );
        final bytes = base64Url.decode(normalized);
        if (bytes.length == 32) {
          decoded = Uint8List.fromList(bytes);
        }
      } catch (_) {
        decoded = null;
      }
    }
    if (decoded == null || decoded.length != 32) {
      throw const WorkspaceEncryptionException(
        'Workspace encryption key is invalid. Expected 32 bytes (64 hex characters or 44 base64 characters).',
      );
    }
    var allZero = true;
    for (final b in decoded) {
      if (b != 0) {
        allZero = false;
        break;
      }
    }
    if (allZero) {
      throw const WorkspaceEncryptionException(
        'Workspace encryption key is invalid: all-zero key is not permitted.',
      );
    }
    return decoded;
  }

  Future<void> open() async {
    await directory.create(recursive: true);
    _lock = await File(
      p.join(directory.path, '.lock'),
    ).open(mode: FileMode.append);
    await _lock!.lock(FileLock.exclusive);

    try {
      final entities = await directory.list().toList();
      // Clean up any incomplete .tmp files from interrupted writes
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.json.tmp')) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }

      final pendingWrites = <String, Json>{};
      final decodedCache = <String, Json>{};

      for (final entity in entities) {
        if (entity is! File || p.extension(entity.path) != '.json') continue;
        final baseName = p.basename(entity.path);
        if (baseName.startsWith('.')) continue;
        final ownerKey = p.basenameWithoutExtension(entity.path);
        final rawContent = await entity.readAsString();
        final decoded = _decodeOrMigrateWorkspaceFile(ownerKey, rawContent);
        final state = decoded.state;
        var modifiedOnStartup = decoded.needsReencrypt;

        for (final thread in records(state['threads'])) {
          if (thread['status'] == 'running' || thread['status'] == 'ready') {
            final live = recordById(state, 'threads', thread['id']);
            live['status'] = 'interrupted';
            resetContinuation(live);
            for (final message in live['messages'] as List) {
              if (message['status'] == 'streaming') {
                message['status'] = 'interrupted';
              }
            }
            modifiedOnStartup = true;
          }
          final live = recordById(state, 'threads', thread['id']);
          if ((live['approvals'] as List).any(
            (a) => a['status'] == 'executing',
          )) {
            live['status'] = 'interrupted';
            resetContinuation(live);
            modifiedOnStartup = true;
          }
        }
        for (final task in state['schedules'] as List) {
          if (task['status'] == 'running') {
            task['status'] = 'interrupted';
            modifiedOnStartup = true;
          }
        }
        for (final call in state['calls'] as List) {
          if (call['status'] == 'active') {
            call['status'] = 'interrupted';
            call['endedAt'] = now();
            modifiedOnStartup = true;
          }
        }
        decodedCache[ownerKey] = state;
        if (modifiedOnStartup) {
          pendingWrites[ownerKey] = state;
        }
      }

      _cache
        ..clear()
        ..addAll(decodedCache);
      for (final entry in pendingWrites.entries) {
        await _write(entry.key, entry.value);
      }
    } catch (_) {
      await close();
      rethrow;
    }
  }

  /// Rotates the active encryption key and atomically re-encrypts all persisted workspaces.
  Future<void> rotateKey(String newKeyRaw) {
    final newKey = parseKeyMaterial(newKeyRaw);
    final completer = Completer<void>();
    _queue = _queue.then((_) async {
      try {
        final previous = _activeKey;
        _activeKey = newKey;
        _previousKey = previous;
        for (final entry in _cache.entries) {
          await _write(entry.key, entry.value);
        }
        completer.complete();
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  ({Json state, bool needsReencrypt}) _decodeOrMigrateWorkspaceFile(
    String ownerKey,
    String rawContent,
  ) {
    final dynamic parsed;
    try {
      parsed = jsonDecode(rawContent);
    } catch (_) {
      throw WorkspaceEncryptionException(
        'Corrupted workspace file for $ownerKey.',
      );
    }
    if (parsed is! Map<String, dynamic>) {
      throw WorkspaceEncryptionException(
        'Invalid workspace format for $ownerKey.',
      );
    }

    final isEncryptedEnvelope =
        parsed.containsKey('ciphertext') ||
        parsed.containsKey('alg') ||
        parsed.containsKey('nonce') ||
        parsed.containsKey('tag') ||
        parsed.containsKey('v');

    if (isEncryptedEnvelope) {
      final version = parsed['v'];
      final alg = parsed['alg'];
      if (version != currentEnvelopeVersion || alg != currentAlgorithm) {
        throw WorkspaceEncryptionException(
          'Unsupported workspace encryption envelope (v=$version, alg=$alg).',
        );
      }
      final nonceB64 = parsed['nonce'];
      final ciphertextB64 = parsed['ciphertext'];
      final tagB64 = parsed['tag'];
      if (nonceB64 is! String ||
          ciphertextB64 is! String ||
          tagB64 is! String) {
        throw WorkspaceEncryptionException(
          'Malformed encrypted workspace envelope for $ownerKey.',
        );
      }
      final Uint8List nonce;
      final Uint8List ciphertext;
      final Uint8List tag;
      try {
        nonce = Uint8List.fromList(base64.decode(nonceB64));
        ciphertext = Uint8List.fromList(base64.decode(ciphertextB64));
        tag = Uint8List.fromList(base64.decode(tagB64));
      } catch (_) {
        throw WorkspaceEncryptionException(
          'Malformed base64 in encrypted workspace envelope for $ownerKey.',
        );
      }
      if (nonce.length != 12 || tag.length != 16) {
        throw WorkspaceEncryptionException(
          'Invalid nonce or authentication tag length for $ownerKey.',
        );
      }
      final aad = Uint8List.fromList(
        utf8.encode('tradex-copilot:v1:$ownerKey'),
      );
      Uint8List? plaintextBytes = _Aes256Gcm.decrypt(
        key: _activeKey,
        nonce: nonce,
        ciphertext: ciphertext,
        tag: tag,
        aad: aad,
      );
      var usedPreviousKey = false;
      if (plaintextBytes == null && _previousKey != null) {
        plaintextBytes = _Aes256Gcm.decrypt(
          key: _previousKey!,
          nonce: nonce,
          ciphertext: ciphertext,
          tag: tag,
          aad: aad,
        );
        usedPreviousKey = plaintextBytes != null;
      }
      if (plaintextBytes == null) {
        throw WorkspaceEncryptionException(
          'Failed to authenticate or decrypt workspace $ownerKey. Verify COPILOT_WORKSPACE_KEY and file integrity.',
        );
      }
      final dynamic stateObj;
      try {
        stateObj = jsonDecode(utf8.decode(plaintextBytes));
      } catch (_) {
        throw WorkspaceEncryptionException(
          'Decrypted workspace payload is not valid JSON for $ownerKey.',
        );
      }
      if (stateObj is! Map<String, dynamic> ||
          stateObj['threads'] is! List ||
          stateObj['connections'] is! List) {
        throw WorkspaceEncryptionException(
          'Decrypted workspace payload has invalid schema for $ownerKey.',
        );
      }
      return (state: stateObj, needsReencrypt: usedPreviousKey);
    }

    // Legacy plaintext workspace file: validate structure before migrating
    if (parsed['threads'] is! List || parsed['connections'] is! List) {
      throw WorkspaceEncryptionException(
        'Unrecognized plaintext workspace structure for $ownerKey.',
      );
    }
    return (state: parsed, needsReencrypt: true);
  }

  String _encryptWorkspaceEnvelope(String ownerKey, Json state) {
    final plaintext = Uint8List.fromList(utf8.encode(jsonEncode(state)));
    final nonce = Uint8List(12);
    for (var i = 0; i < nonce.length; i++) {
      nonce[i] = _random.nextInt(256);
    }
    final aad = Uint8List.fromList(utf8.encode('tradex-copilot:v1:$ownerKey'));
    final sealed = _Aes256Gcm.encrypt(
      key: _activeKey,
      nonce: nonce,
      plaintext: plaintext,
      aad: aad,
    );
    return jsonEncode({
      'v': currentEnvelopeVersion,
      'alg': currentAlgorithm,
      'nonce': base64.encode(nonce),
      'ciphertext': base64.encode(sealed.ciphertext),
      'tag': base64.encode(sealed.tag),
    });
  }

  String _ownerKey(String owner) =>
      base64Url.encode(utf8.encode(owner)).replaceAll('=', '');
  Iterable<String> get owners => _cache.keys.map(
    (key) => utf8.decode(base64Url.decode(base64Url.normalize(key))),
  );

  Future<Json> read(String owner) async {
    await _queue;
    final key = _ownerKey(owner);
    final state = _cache.putIfAbsent(key, initialWorkspace);
    return jsonDecode(jsonEncode(state)) as Json;
  }

  Future<T> change<T>(String owner, T Function(Json state) apply) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        final key = _ownerKey(owner);
        final state =
            jsonDecode(jsonEncode(_cache[key] ?? initialWorkspace())) as Json;
        final result = apply(state);
        await _write(key, state);
        _cache[key] = state;
        completer.complete(result);
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  Future<void> _write(String key, Json state) async {
    final target = p.join(directory.path, '$key.json');
    final pending = File('$target.tmp');
    final encryptedEnvelope = _encryptWorkspaceEnvelope(key, state);
    await pending.writeAsString(encryptedEnvelope, flush: true);
    await pending.rename(target);
  }

  Future<void> close() async {
    await _queue;
    try {
      await _lock?.unlock();
    } catch (_) {}
    try {
      await _lock?.close();
    } catch (_) {}
    _lock = null;
  }
}

/// NIST FIPS 197 (AES-256) + NIST SP 800-38D (GCM) authenticated encryption.
class _Aes256Gcm {
  static const List<int> _sBox = <int>[
    0x63,
    0x7c,
    0x77,
    0x7b,
    0xf2,
    0x6b,
    0x6f,
    0xc5,
    0x30,
    0x01,
    0x67,
    0x2b,
    0xfe,
    0xd7,
    0xab,
    0x76,
    0xca,
    0x82,
    0xc9,
    0x7d,
    0xfa,
    0x59,
    0x47,
    0xf0,
    0xad,
    0xd4,
    0xa2,
    0xaf,
    0x9c,
    0xa4,
    0x72,
    0xc0,
    0xb7,
    0xfd,
    0x93,
    0x26,
    0x36,
    0x3f,
    0xf7,
    0xcc,
    0x34,
    0xa5,
    0xe5,
    0xf1,
    0x71,
    0xd8,
    0x31,
    0x15,
    0x04,
    0xc7,
    0x23,
    0xc3,
    0x18,
    0x96,
    0x05,
    0x9a,
    0x07,
    0x12,
    0x80,
    0xe2,
    0xeb,
    0x27,
    0xb2,
    0x75,
    0x09,
    0x83,
    0x2c,
    0x1a,
    0x1b,
    0x6e,
    0x5a,
    0xa0,
    0x52,
    0x3b,
    0xd6,
    0xb3,
    0x29,
    0xe3,
    0x2f,
    0x84,
    0x53,
    0xd1,
    0x00,
    0xed,
    0x20,
    0xfc,
    0xb1,
    0x5b,
    0x6a,
    0xcb,
    0xbe,
    0x39,
    0x4a,
    0x4c,
    0x58,
    0xcf,
    0xd0,
    0xef,
    0xaa,
    0xfb,
    0x43,
    0x4d,
    0x33,
    0x85,
    0x45,
    0xf9,
    0x02,
    0x7f,
    0x50,
    0x3c,
    0x9f,
    0xa8,
    0x51,
    0xa3,
    0x40,
    0x8f,
    0x92,
    0x9d,
    0x38,
    0xf5,
    0xbc,
    0xb6,
    0xda,
    0x21,
    0x10,
    0xff,
    0xf3,
    0xd2,
    0xcd,
    0x0c,
    0x13,
    0xec,
    0x5f,
    0x97,
    0x44,
    0x17,
    0xc4,
    0xa7,
    0x7e,
    0x3d,
    0x64,
    0x5d,
    0x19,
    0x73,
    0x60,
    0x81,
    0x4f,
    0xdc,
    0x22,
    0x2a,
    0x90,
    0x88,
    0x46,
    0xee,
    0xb8,
    0x14,
    0xde,
    0x5e,
    0x0b,
    0xdb,
    0xe0,
    0x32,
    0x3a,
    0x0a,
    0x49,
    0x06,
    0x24,
    0x5c,
    0xc2,
    0xd3,
    0xac,
    0x62,
    0x91,
    0x95,
    0xe4,
    0x79,
    0xe7,
    0xc8,
    0x37,
    0x6d,
    0x8d,
    0xd5,
    0x4e,
    0xa9,
    0x6c,
    0x56,
    0xf4,
    0xea,
    0x65,
    0x7a,
    0xae,
    0x08,
    0xba,
    0x78,
    0x25,
    0x2e,
    0x1c,
    0xa6,
    0xb4,
    0xc6,
    0xe8,
    0xdd,
    0x74,
    0x1f,
    0x4b,
    0xbd,
    0x8b,
    0x8a,
    0x70,
    0x3e,
    0xb5,
    0x66,
    0x48,
    0x03,
    0xf6,
    0x0e,
    0x61,
    0x35,
    0x57,
    0xb9,
    0x86,
    0xc1,
    0x1d,
    0x9e,
    0xe1,
    0xf8,
    0x98,
    0x11,
    0x69,
    0xd9,
    0x8e,
    0x94,
    0x9b,
    0x1e,
    0x87,
    0xe9,
    0xce,
    0x55,
    0x28,
    0xdf,
    0x8c,
    0xa1,
    0x89,
    0x0d,
    0xbf,
    0xe6,
    0x42,
    0x68,
    0x41,
    0x99,
    0x2d,
    0x0f,
    0xb0,
    0x54,
    0xbb,
    0x16,
  ];

  static const List<int> _rCon = <int>[
    0x00,
    0x01,
    0x02,
    0x04,
    0x08,
    0x10,
    0x20,
    0x40,
    0x80,
    0x1b,
    0x36,
  ];

  static ({Uint8List ciphertext, Uint8List tag}) encrypt({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List plaintext,
    required Uint8List aad,
  }) {
    final roundKeys = _expandKey(key);
    final h = _encryptBlock(Uint8List(16), roundKeys);

    final j0 = Uint8List(16);
    j0.setRange(0, 12, nonce);
    j0[15] = 1;

    final ciphertext = _ctrXor(plaintext, j0, roundKeys);
    final s = _ghash(h, aad, ciphertext);
    final ej0 = _encryptBlock(j0, roundKeys);
    final tag = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      tag[i] = s[i] ^ ej0[i];
    }
    return (ciphertext: ciphertext, tag: tag);
  }

  static Uint8List? decrypt({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List ciphertext,
    required Uint8List tag,
    required Uint8List aad,
  }) {
    if (nonce.length != 12 || tag.length != 16) return null;
    final roundKeys = _expandKey(key);
    final h = _encryptBlock(Uint8List(16), roundKeys);

    final j0 = Uint8List(16);
    j0.setRange(0, 12, nonce);
    j0[15] = 1;

    final s = _ghash(h, aad, ciphertext);
    final ej0 = _encryptBlock(j0, roundKeys);
    var diff = 0;
    for (var i = 0; i < 16; i++) {
      diff |= (s[i] ^ ej0[i]) ^ tag[i];
    }
    if (diff != 0) {
      return null;
    }
    return _ctrXor(ciphertext, j0, roundKeys);
  }

  static Uint8List _ctrXor(Uint8List input, Uint8List j0, Uint8List roundKeys) {
    final output = Uint8List(input.length);
    final cb = Uint8List.fromList(j0);
    for (var offset = 0; offset < input.length; offset += 16) {
      _increment32(cb);
      final keystream = _encryptBlock(cb, roundKeys);
      final chunkLen = (input.length - offset) < 16
          ? (input.length - offset)
          : 16;
      for (var i = 0; i < chunkLen; i++) {
        output[offset + i] = input[offset + i] ^ keystream[i];
      }
    }
    return output;
  }

  static void _increment32(Uint8List block) {
    for (var i = 15; i >= 12; i--) {
      block[i] = (block[i] + 1) & 0xff;
      if (block[i] != 0) break;
    }
  }

  static Uint8List _ghash(Uint8List h, Uint8List aad, Uint8List ciphertext) {
    var y = Uint8List(16);

    void processBytes(Uint8List data) {
      for (var offset = 0; offset < data.length; offset += 16) {
        final chunkLen = (data.length - offset) < 16
            ? (data.length - offset)
            : 16;
        for (var i = 0; i < chunkLen; i++) {
          y[i] ^= data[offset + i];
        }
        y = _gfMul(y, h);
      }
    }

    processBytes(aad);
    processBytes(ciphertext);

    final lenBlock = Uint8List(16);
    final bd = ByteData.sublistView(lenBlock);
    final aadBits = aad.length * 8;
    final cipherBits = ciphertext.length * 8;
    bd.setUint32(0, (aadBits ~/ 0x100000000) & 0xffffffff, Endian.big);
    bd.setUint32(4, aadBits & 0xffffffff, Endian.big);
    bd.setUint32(8, (cipherBits ~/ 0x100000000) & 0xffffffff, Endian.big);
    bd.setUint32(12, cipherBits & 0xffffffff, Endian.big);

    for (var i = 0; i < 16; i++) {
      y[i] ^= lenBlock[i];
    }
    return _gfMul(y, h);
  }

  static Uint8List _gfMul(Uint8List x, Uint8List y) {
    final z = Uint8List(16);
    final v = Uint8List.fromList(y);
    for (var i = 0; i < 128; i++) {
      final byteIdx = i >> 3;
      final bitIdx = 7 - (i & 7);
      if (((x[byteIdx] >> bitIdx) & 1) != 0) {
        for (var j = 0; j < 16; j++) {
          z[j] ^= v[j];
        }
      }
      final lsb = v[15] & 1;
      for (var j = 15; j > 0; j--) {
        v[j] = ((v[j] >> 1) | ((v[j - 1] & 1) << 7)) & 0xff;
      }
      v[0] = (v[0] >> 1) & 0xff;
      if (lsb != 0) {
        v[0] ^= 0xe1;
      }
    }
    return z;
  }

  static Uint8List _expandKey(Uint8List key) {
    final w = Uint8List(240);
    w.setRange(0, 32, key);
    final temp = Uint8List(4);
    var bytesGenerated = 32;
    var rconIdx = 1;

    while (bytesGenerated < 240) {
      for (var i = 0; i < 4; i++) {
        temp[i] = w[bytesGenerated - 4 + i];
      }
      if (bytesGenerated % 32 == 0) {
        final t = temp[0];
        temp[0] = _sBox[temp[1]] ^ _rCon[rconIdx++];
        temp[1] = _sBox[temp[2]];
        temp[2] = _sBox[temp[3]];
        temp[3] = _sBox[t];
      } else if (bytesGenerated % 32 == 16) {
        for (var i = 0; i < 4; i++) {
          temp[i] = _sBox[temp[i]];
        }
      }
      for (var i = 0; i < 4; i++) {
        w[bytesGenerated] = w[bytesGenerated - 32] ^ temp[i];
        bytesGenerated++;
      }
    }
    return w;
  }

  static int _xtime(int x) => ((x << 1) ^ (((x >> 7) & 1) * 0x1b)) & 0xff;

  static Uint8List _encryptBlock(Uint8List input, Uint8List roundKeys) {
    final s = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      s[i] = input[i] ^ roundKeys[i];
    }

    for (var round = 1; round < 14; round++) {
      for (var i = 0; i < 16; i++) {
        s[i] = _sBox[s[i]];
      }
      // ShiftRows
      var t = s[1];
      s[1] = s[5];
      s[5] = s[9];
      s[9] = s[13];
      s[13] = t;

      t = s[2];
      s[2] = s[10];
      s[10] = t;
      t = s[6];
      s[6] = s[14];
      s[14] = t;

      t = s[15];
      s[15] = s[11];
      s[11] = s[7];
      s[7] = s[3];
      s[3] = t;

      // MixColumns
      for (var c = 0; c < 16; c += 4) {
        final a0 = s[c];
        final a1 = s[c + 1];
        final a2 = s[c + 2];
        final a3 = s[c + 3];
        final tm = a0 ^ a1 ^ a2 ^ a3;
        s[c] ^= tm ^ _xtime(a0 ^ a1);
        s[c + 1] ^= tm ^ _xtime(a1 ^ a2);
        s[c + 2] ^= tm ^ _xtime(a2 ^ a3);
        s[c + 3] ^= tm ^ _xtime(a3 ^ a0);
      }

      // AddRoundKey
      final rkOffset = round * 16;
      for (var i = 0; i < 16; i++) {
        s[i] ^= roundKeys[rkOffset + i];
      }
    }

    // Final round (no MixColumns)
    for (var i = 0; i < 16; i++) {
      s[i] = _sBox[s[i]];
    }
    var t = s[1];
    s[1] = s[5];
    s[5] = s[9];
    s[9] = s[13];
    s[13] = t;

    t = s[2];
    s[2] = s[10];
    s[10] = t;
    t = s[6];
    s[6] = s[14];
    s[14] = t;

    t = s[15];
    s[15] = s[11];
    s[11] = s[7];
    s[7] = s[3];
    s[3] = t;

    for (var i = 0; i < 16; i++) {
      s[i] ^= roundKeys[224 + i];
    }
    return s;
  }
}
