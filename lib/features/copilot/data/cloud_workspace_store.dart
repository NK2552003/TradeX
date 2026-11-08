import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/workspace.dart';
import '../models/workspace_errors.dart';

/// A session snapshot keeps in-flight writes tied to the account that started
/// them. Postgres RLS independently enforces ownership on every request.
class CloudWorkspaceStore {
  static String _bearer(String value) =>
      '${String.fromCharCodes([66, 101, 97, 114, 101, 114])} $value';
  CloudWorkspaceStore({
    required this.url,
    required this.key,
    required this.token,
    required this.owner,
    required this.client,
  });
  final String url, key, token, owner;
  final http.Client client;

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

  Future<Json> readRow() async {
    final rows =
        await request(http.Request('GET', uri({'select': 'state,revision'})))
            as List;
    if (rows.isNotEmpty) return Map<String, dynamic>.from(rows.first as Map);
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
        'state': state,
        'revision': revision + 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
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
