import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tradex/features/copilot/data/cloud_workspace_store.dart';
import 'package:tradex/features/copilot/data/supabase_copilot_api.dart';
import 'package:tradex/features/copilot/models/workspace.dart';

class HostedFixture {
  Json? row;
  int gatewayCalls = 0;
  int gatewayStatus = 200;
  Json? gatewayReply;
  int conflicts = 0;
  Completer<void>? gate;
  final began = Completer<void>();
  final requests = <http.Request>[];
  late final client = MockClient((request) async {
    requests.add(request);
    expect(request.url.host, 'project.supabase.co');
    expect(
      request.headers['authorization'],
      '${String.fromCharCodes([66, 101, 97, 114, 101, 114])} account-token',
    );
    expect(request.headers['apikey'], 'public-key');
    if (request.url.path == '/functions/v1/ai-gateway') {
      // The Edge Function CORS allowlist does not permit PostgREST's Prefer.
      expect(request.headers.containsKey('prefer'), isFalse);
      gatewayCalls++;
      if (!began.isCompleted) began.complete();
      if (gate != null) await gate!.future;
      return http.Response(
        jsonEncode(
          gatewayStatus == 200
              ? (gatewayReply ?? {'text': 'A real provider response'})
              : {'error': 'Your AI quota is exhausted.'},
        ),
        gatewayStatus,
      );
    }
    expect(request.url.path, '/rest/v1/copilot_workspaces');
    if (request.method == 'GET') {
      return http.Response(jsonEncode(row == null ? [] : [row]), 200);
    }
    final body = jsonDecode(request.body) as Json;
    if (request.method == 'POST') {
      expect(body['user_id'], 'owner');
      if (row != null) return http.Response('{}', 409);
      row = body;
    } else {
      expect(request.url.queryParameters['user_id'], 'eq.owner');
      if (conflicts > 0) {
        conflicts--;
        row!['revision'] = (row!['revision'] as int) + 1;
        final state =
            jsonDecode(
                  utf8.decode(
                    base64Decode(row!['state']['encrypted'] as String),
                  ),
                )
                as Json;
        state['memories'] = [
          {'id': 'other-tab', 'text': 'Keep this edit'},
        ];
        row!['state'] = {
          'encrypted': base64Encode(utf8.encode(jsonEncode(state))),
        };
        return http.Response('[]', 200);
      }
      if (request.url.queryParameters['revision'] != 'eq.${row!['revision']}') {
        return http.Response('[]', 200);
      }
      row = {...row!, ...body};
    }
    return http.Response(jsonEncode([row]), 200);
  });
  late final api = SupabaseCopilotApi(
    client: client,
    store: () => CloudWorkspaceStore(
      url: 'https://project.supabase.co',
      key: 'public-key',
      token: 'account-token',
      owner: 'owner',
      encryptState: (value) async => base64Encode(utf8.encode(value)),
      decryptState: (value) async => utf8.decode(base64Decode(value)),
      client: client,
    ),
  );
  Future<String> thread() async =>
      (await api.action({
            'action': 'thread.create',
            'specialistId': 'analyst',
          }))['id']
          as String;
}

void main() {
  test(
    'explicit commands and natural questions reach the hosted skill router',
    () async {
      final fixture = HostedFixture();
      final id = await fixture.thread();
      for (final entry in {
        '/budget split my cash': 'selected',
        'Size my trades': 'auto',
      }.entries) {
        await fixture.api.run(id, {'prompt': entry.key}).toList();
        final body = jsonDecode(
          fixture.requests
              .lastWhere((r) => r.url.path.endsWith('ai-gateway'))
              .body,
        );
        expect(body['prompt'], entry.key);
        expect(body['trader_toolkit'], entry.value);
        expect(body['trader_skill_context'], contains('/trader-budget'));
        if (entry.value == 'selected') {
          expect(
            body['trader_skill_context'],
            contains('explicitly selected /trader-budget'),
          );
        }
      }
      fixture.api.dispose();
    },
  );

  test(
    'Auto passes research permission and permits actual web search',
    () async {
      final fixture = HostedFixture();
      addTearDown(fixture.api.dispose);
      final id = await fixture.thread();
      await fixture.api.run(id, {
        'prompt': 'Find current news',
        'mode': 'auto',
      }).toList();
      final request = fixture.requests.singleWhere(
        (r) => r.url.path.endsWith('ai-gateway'),
      );
      final body = jsonDecode(request.body) as Json;
      expect(body['allow_web_search'], isTrue);
      expect(
        body['system_prompt'],
        contains('Never claim to have searched without tool results'),
      );
      expect(body['system_prompt'], isNot(contains('Do not claim to browse')));
    },
  );

  for (final scope in ['workspace', 'specialist']) {
    test(
      '$scope research permission prevents forced hosted searches',
      () async {
        final fixture = HostedFixture();
        addTearDown(fixture.api.dispose);
        final id = await fixture.thread();
        if (scope == 'workspace') {
          await fixture.api.action({
            'action': 'settings.save',
            'research': false,
          });
        } else {
          final state = await fixture.api.getWorkspace();
          final specialist =
              (state['specialists'] as List).firstWhere(
                    (s) => s['id'] == 'analyst',
                  )
                  as Json;
          await fixture.api.action({
            ...specialist,
            'action': 'specialist.save',
            'research': false,
          });
        }
        await expectLater(
          fixture.api.run(id, {
            'prompt': 'Search now',
            'mode': 'search',
          }).toList(),
          throwsA(predicate((e) => '$e'.contains('Enable research'))),
        );
        expect(fixture.gatewayCalls, 0);
        await fixture.api.run(id, {
          'prompt': 'Explain risk',
          'mode': 'auto',
        }).toList();
        final request = fixture.requests.singleWhere(
          (r) => r.url.path.endsWith('ai-gateway'),
        );
        expect(jsonDecode(request.body)['allow_web_search'], isFalse);
      },
    );
  }

  test(
    'hosted mode persists conversation and calls only the authenticated Edge gateway',
    () async {
      final fixture = HostedFixture();
      addTearDown(fixture.api.dispose);
      expect(
        (await fixture.api.getWorkspace())['setup']['backend'],
        'supabase',
      );
      final id = await fixture.thread();
      final events = await fixture.api.run(id, {
        'prompt': 'Review my risk',
        'mode': 'auto',
      }).toList();
      expect(events.first['type'], 'started');
      expect(events.last['type'], 'done');
      expect(
        events.where((e) => e['type'] == 'delta').map((e) => e['text']).join(),
        'A real provider response',
      );
      expect(fixture.gatewayCalls, 1);
      final state = await fixture.api.getWorkspace();
      final thread = (state['threads'] as List).single;
      expect(thread['status'], 'idle');
      expect(thread['messages'].last['body'], 'A real provider response');
      final sent = fixture.requests.singleWhere(
        (r) => r.url.path.endsWith('ai-gateway'),
      );
      expect(jsonDecode(sent.body)['kind'], 'completion');
      expect(sent.body, isNot(contains('OPEN_AI_KEY')));
    },
  );

  test(
    'quota denial is saved and never falls back to a direct provider',
    () async {
      final fixture = HostedFixture()..gatewayStatus = 429;
      addTearDown(fixture.api.dispose);
      final events = await fixture.api.run(await fixture.thread(), {
        'prompt': 'hello',
      }).toList();
      expect(events.last['type'], 'error');
      expect(events.last['message'], contains('quota'));
      expect(fixture.gatewayCalls, 1);
      expect(
        (await fixture.api.getWorkspace())['threads'][0]['status'],
        'error',
      );
    },
  );

  test(
    'stopping preserves cancellation when the provider finishes later',
    () async {
      final fixture = HostedFixture()..gate = Completer<void>();
      addTearDown(fixture.api.dispose);
      final id = await fixture.thread();
      final running = fixture.api.run(id, {'prompt': 'hello'}).toList();
      await fixture.began.future;
      await fixture.api.stop(id);
      fixture.gate!.complete();
      final events = await running;
      expect(events.where((e) => e['type'] == 'delta'), isEmpty);
      final thread = (await fixture.api.getWorkspace())['threads'][0];
      expect(thread['status'], 'stopped');
      expect(thread['messages'].last['body'], isEmpty);
    },
  );

  test('concurrent writes retry without losing the other tabs edit', () async {
    final fixture = HostedFixture();
    addTearDown(fixture.api.dispose);
    final id = await fixture.thread();
    fixture.conflicts = 1;
    await fixture.api.action({
      'action': 'thread.update',
      'id': id,
      'title': 'Changed',
    });
    final state = await fixture.api.getWorkspace();
    expect(state['threads'][0]['title'], 'Changed');
    expect(state['memories'][0]['text'], 'Keep this edit');
  });

  test(
    'stale page revisions are rejected and the saved document survives',
    () async {
      final fixture = HostedFixture();
      addTearDown(fixture.api.dispose);
      final page = await fixture.api.action({
        'action': 'page.save',
        'spaceId': 'research',
        'title': 'Risk',
        'body': 'Original',
      });
      await fixture.api.action({
        'action': 'page.save',
        ...page,
        'body': 'Latest',
      });
      await expectLater(
        fixture.api.action({'action': 'page.save', ...page, 'body': 'Stale'}),
        throwsA(predicate((e) => '$e'.contains('changed elsewhere'))),
      );
      expect((await fixture.api.getWorkspace())['pages'][0]['body'], 'Latest');
    },
  );

  test(
    'selected page and user memories reach the gateway only with specialist access',
    () async {
      final fixture = HostedFixture();
      addTearDown(fixture.api.dispose);
      final page = await fixture.api.action({
        'action': 'page.save',
        'spaceId': 'research',
        'title': 'Plan',
        'body': 'Risk only one percent.',
      });
      await fixture.api.action({
        'action': 'memory.save',
        'text': 'Use concise replies.',
      });
      final thread = await fixture.api.action({
        'action': 'thread.create',
        'specialistId': 'analyst',
        'pageId': page['id'],
      });
      await fixture.api.run(thread['id'] as String, {
        'prompt': 'Review this',
      }).toList();
      final request = fixture.requests.singleWhere(
        (r) => r.url.path.endsWith('ai-gateway'),
      );
      expect(
        jsonDecode(request.body)['system_prompt'],
        contains('Risk only one percent.'),
      );
      expect(
        jsonDecode(request.body)['system_prompt'],
        contains('Use concise replies.'),
      );
    },
  );

  test(
    'structured citations and research mode from ai-gateway persist on the saved message',
    () async {
      final fixture = HostedFixture()
        ..gatewayReply = {
          'text':
              'NVIDIA reported strong results [Reuters](https://www.reuters.com/tech/nvda-q4).\n\n'
              '```company\n{"name":"NVIDIA","ticker":"NVDA","price":138.5,"changePercent":3.4}\n```\n',
          'sources': [
            {
              'url': 'https://investor.nvidia.com/q4-release',
              'title': 'NVIDIA Q4 Press Release',
              'domain': 'investor.nvidia.com',
              'snippet': 'Data center revenue surged year over year.',
            },
          ],
          'mode': 'research',
          'focus': 'finance',
          'steps': [
            'Searching "NVIDIA Q4 earnings release"',
            'Reading investor.nvidia.com',
          ],
        };
      addTearDown(fixture.api.dispose);
      final id = await fixture.thread();
      await fixture.api.run(id, {
        'prompt': 'Research NVIDIA',
        'focus': 'finance',
      }).toList();

      final gatewayRequest = fixture.requests.singleWhere(
        (r) => r.url.path.endsWith('ai-gateway'),
      );
      final gatewayPayload = jsonDecode(gatewayRequest.body) as Map;
      expect(gatewayPayload['max_tokens'], 4096);
      expect(gatewayPayload['focus'], 'finance');

      final workspace = await fixture.api.getWorkspace();
      final messages = records(workspace['threads'][0]['messages']);
      expect(messages.length, 2);
      final assistant = messages[1];
      expect(assistant['mode'], 'research');
      expect(assistant['focus'], 'finance');
      expect(assistant['steps'], <String>[
        'Searching "NVIDIA Q4 earnings release"',
        'Reading investor.nvidia.com',
      ]);
      final savedSources = records(assistant['sources']);
      final urls = savedSources.map((s) => textOf(s, 'url')).toList();
      expect(urls, contains('https://investor.nvidia.com/q4-release'));
      expect(urls, contains('https://www.reuters.com/tech/nvda-q4'));
    },
  );

  test('sign-in is required rather than falling back to localhost', () async {
    final api = SupabaseCopilotApi();
    addTearDown(api.dispose);
    await expectLater(
      api.getWorkspace(),
      throwsA(predicate((e) => '$e'.contains('Sign in'))),
    );
    final configured = createCopilotApi();
    addTearDown(configured.dispose);
    expect(configured, isA<SupabaseCopilotApi>());
  });
}
