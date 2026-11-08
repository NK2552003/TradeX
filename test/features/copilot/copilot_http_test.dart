import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../../../server/copilot/config.dart';
import '../../../server/copilot/server.dart';
import '../../../server/copilot/store.dart';

class _LoopbackHttp extends HttpOverrides {}

http.Client _client() => IOClient(
  HttpOverrides.runWithHttpOverrides(() => HttpClient(), _LoopbackHttp()),
);

void main() {
  test('HTTP rejects missing identity and unapproved origins', () async {
    final directory = await Directory.systemTemp.createTemp('copilot-http-');
    final server = CopilotServer(
      CopilotConfig({'COPILOT_PORT': '0'}),
      WorkspaceStore(directory),
    );
    await server.start();
    final client = _client();
    try {
      final base = 'http://127.0.0.1:${server.boundPort}';
      expect((await client.get(Uri.parse('$base/health'))).statusCode, 200);
      expect(
        (await client.get(Uri.parse('$base/v1/workspace'))).statusCode,
        401,
      );
      expect(
        (await client.get(
          Uri.parse('$base/health'),
          headers: {'Origin': 'https://unapproved.example'},
        )).statusCode,
        403,
      );
      final preflight = await client.send(
        http.Request('OPTIONS', Uri.parse('$base/v1/workspace'))
          ..headers['Origin'] = 'http://localhost:5173',
      );
      expect(preflight.statusCode, 204);
      expect(
        preflight.headers['access-control-allow-origin'],
        'http://localhost:5173',
      );
    } finally {
      client.close();
      await server.close();
      await directory.delete(recursive: true);
    }
  });

  test(
    'workspace responses redact credentials and provider continuations',
    () async {
      final directory = await Directory.systemTemp.createTemp('copilot-http-');
      final store = WorkspaceStore(directory);
      final server = CopilotServer(
        CopilotConfig({
          'COPILOT_PORT': '0',
          'COPILOT_LOCAL_OWNER': 'true',
          'OPEN_AI_KEY': 'provider-secret',
        }),
        store,
      );
      await server.start();
      final client = _client();
      try {
        await store.change('local-owner', (state) {
          state['connections'] = [
            {'id': 'connection', 'token': 'connector-secret'},
          ];
          state['threads'] = [
            {
              'id': 'thread',
              'responseId': 'response-secret',
              'continuation': [
                {'output': 'internal'},
              ],
            },
          ];
        });
        final response = await client.get(
          Uri.parse('http://127.0.0.1:${server.boundPort}/v1/workspace'),
        );
        expect(response.statusCode, 200);
        final data = jsonDecode(response.body) as Map;
        expect(data['connections'][0]['hasToken'], isTrue);
        expect(response.body, isNot(contains('connector-secret')));
        expect(response.body, isNot(contains('provider-secret')));
        expect(response.body, isNot(contains('response-secret')));
        expect(data['threads'][0].containsKey('continuation'), isFalse);
      } finally {
        client.close();
        await server.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
