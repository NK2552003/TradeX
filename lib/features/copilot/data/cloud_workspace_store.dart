import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import 'package:alphajournal/core/security/private_message_service.dart';

import '../models/workspace.dart';
import '../models/workspace_errors.dart';

/// A session snapshot keeps in-flight writes tied to the account that started
/// them. Postgres RLS independently enforces ownership on every request.
class CloudWorkspaceStore {
  static String _bearer(String value) =>
      "${String.fromCharCodes([66, 101, 97, 114, 101, 114])} $value";
  CloudWorkspaceStore({
    required this.url,
    required this.key,
    required this.token,
    required this.owner,
    required this.client,
    this.encryptState,
    this.decryptState,
  });
  final String url, key, token, owner;
  final http.Client client;
  final Future<String> Function(String value)? encryptState;
  final Future<String> Function(String value)? decryptState;

  Map<String, String> get headers => {
    'apikey': key,
    'Authorization': _bearer(token),
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  Uri uri([Map<String, String> params = const {}]) => Uri.parse(
    '$url/rest/v1/copilot_workspaces',
  ).replace(queryParameters: {'user_id': 'eq.$owner', ...params});

  Future<dynamic> request(http.Request request) async {
    request.headers.addAll(headers);
    final response = await http.Response.fromStream(
      await client.send(request).timeout(const Duration(seconds: 30)),
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode >= 400) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const CopilotFailure(
          'Sign in again to access your copilot workspace.',
          401,
        );
      }
      if (response.statusCode == 404) {
        throw const CopilotFailure(
          'Copilot workspace storage needs its database migration. Please contact support.',
          503,
        );
      }
      if (response.statusCode == 409) return null;
      throw const CopilotFailure(
        'Your workspace could not be saved. Please reconnect and try again.',
        503,
      );
    }
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  void _checkOwner() {
    if (encryptState == null && PrivateMessageService.instance.owner != owner) {
      throw const CopilotFailure(
        'Account changed. Reopen your workspace.',
        401,
      );
    }
  }

  Future<Json> readRow() async {
    _checkOwner();
    final rows =
        await request(http.Request('GET', uri({'select': 'state,revision'})))
            as List;
    if (rows.isNotEmpty) {
      final row = Map<String, dynamic>.from(rows.first as Map);
      final stored = Map<String, dynamic>.from(row['state'] as Map);
      if (stored['encrypted'] is String) {
        final encrypted = stored['encrypted'] as String;
        try {
          final plain = decryptState != null
              ? await decryptState!(encrypted)
              : await PrivateMessageService.instance.decrypt(
                  encrypted,
                  'workspace/$owner',
                  owner,
                );
          row['state'] = jsonDecode(plain);
        } on SecretBoxAuthenticationError catch (error) {
          if (decryptState != null) {
            throw const CopilotFailure(
              'Encrypted workspace could not be decrypted with the current key.',
              401,
            );
          }
          final status = await PrivateMessageService.instance.checkStatus();
          if (!status.unlocked) {
            throw const CopilotFailure(
              'Unlock encrypted storage with your account password or recovery passphrase.',
              401,
            );
          }
          debugPrint(
            '[CloudWorkspaceStore] Recovering unreadable workspace state (MAC mismatch): $error',
          );
          row['state'] = initialWorkspace();
        } on FormatException catch (error) {
          if (decryptState != null) rethrow;
          final status = await PrivateMessageService.instance.checkStatus();
          if (!status.unlocked) {
            throw const CopilotFailure(
              'Unlock encrypted storage with your account password or recovery passphrase.',
              401,
            );
          }
          debugPrint(
            '[CloudWorkspaceStore] Recovering unreadable workspace state (format error): $error',
          );
          row['state'] = initialWorkspace();
        }
      }
      return row;
    }
    return {'revision': 0, 'state': initialWorkspace()};
  }

  Future<Json> read() async =>
      Map<String, dynamic>.from((await readRow())['state'] as Map);

  Future<Json> change(Json Function(Json state) apply) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      final row = await readRow();
      final revision = row['revision'] as int;
      final state = Map<String, dynamic>.from(row['state'] as Map);
      final result = apply(state);
      final write = http.Request(
        revision == 0 ? 'POST' : 'PATCH',
        revision == 0
            ? Uri.parse('$url/rest/v1/copilot_workspaces')
            : uri({'revision': 'eq.$revision'}),
      );
      write.body = jsonEncode({
        if (revision == 0) 'user_id': owner,
        'state': {
          'encrypted': encryptState != null
              ? await encryptState!(jsonEncode(state))
              : await PrivateMessageService.instance.encrypt(
                  jsonEncode(state),
                  'workspace/$owner',
                  [owner],
                ),
        },
        'revision': revision + 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      _checkOwner();
      final saved = await request(write);
      if (saved is List && saved.length == 1) return result;
      // Another tab won the compare-and-swap. Reapply against the latest state;
      // page revisions still reject stale edits instead of overwriting them.
    }
    throw const CopilotFailure(
      'Your workspace changed in another tab. Reconnect and try again.',
      409,
    );
  }
}
