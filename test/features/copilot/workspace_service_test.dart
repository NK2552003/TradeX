import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tradex/features/copilot/models/workspace.dart';

import '../../../server/copilot/agent_runner.dart';
import '../../../server/copilot/agent_tools.dart';
import '../../../server/copilot/approvals.dart';
import '../../../server/copilot/config.dart';
import '../../../server/copilot/openai_gateway.dart';
import '../../../server/copilot/store.dart';
import '../../../server/copilot/workspace_actions.dart';

void main() {
  late Directory directory;
  late WorkspaceStore store;
  late WorkspaceActions actions;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tradex-copilot-test-');
    store = WorkspaceStore(directory);
    await store.open();
    actions = WorkspaceActions(store);
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<Json> thread() => actions.apply('owner', {
    'action': 'thread.create',
    'specialistId': 'analyst',
  });
  Future<Json> page([String title = 'Research']) => actions.apply('owner', {
    'action': 'page.save',
    'title': title,
    'body': 'Original',
    'spaceId': 'research',
  });

  test(
    'workspaces persist across restart and remain isolated by owner',
    () async {
      await page();
      expect(records((await store.read('someone-else'))['pages']), isEmpty);
      await store.close();
      store = WorkspaceStore(directory);
      await store.open();
      expect(
        records((await store.read('owner'))['pages']).single['title'],
        'Research',
      );
    },
  );
  test(
    'revision conflict preserves the newer page and rejects the stale edit',
    () async {
      final original = await page();
      await actions.apply('owner', {
        ...original,
        'action': 'page.save',
        'body': 'Latest',
      });
      await expectLater(
        actions.apply('owner', {
          ...original,
          'action': 'page.save',
          'body': 'Stale',
        }),
        throwsA(isA<CopilotFailure>().having((e) => e.status, 'status', 409)),
      );
      expect(
        records((await store.read('owner'))['pages']).single['body'],
        'Latest',
      );
    },
  );
  test('nested pages reject cycles and cross-space parents', () async {
    final parent = await page();
    final child = await actions.apply('owner', {
      'action': 'page.save',
      'title': 'Child',
      'body': '',
      'spaceId': 'research',
      'parentId': parent['id'],
    });
    await expectLater(
      actions.apply('owner', {
        ...parent,
        'action': 'page.save',
        'parentId': child['id'],
      }),
      throwsA(isA<CopilotFailure>()),
    );
    await expectLater(
      actions.apply('owner', {
        'action': 'page.save',
        'title': 'Cross',
        'body': '',
        'spaceId': 'playbook',
        'parentId': parent['id'],
      }),
      throwsA(isA<CopilotFailure>()),
    );
  });
  test('parallel saves serialize without dropping data', () async {
    await Future.wait(List.generate(8, (index) => page('Page $index')));
    expect(records((await store.read('owner'))['pages']).length, 8);
  });
  test(
    'per-specialist space permission is enforced for page conversations and tools',
    () async {
      final document = await page();
      await expectLater(
        actions.apply('owner', {
          'action': 'thread.create',
          'specialistId': 'coach',
          'pageId': document['id'],
        }),
        throwsA(isA<CopilotFailure>().having((e) => e.status, 'status', 403)),
      );
      final state = await store.read('owner');
      final result = readTool(
        state,
        recordById(state, 'specialists', 'coach'),
        {
          'name': 'read_page',
          'arguments': jsonEncode({'id': document['id']}),
        },
      );
      expect(result!['error'], isNotNull);
    },
  );
  test(
    'global and specialist permissions jointly gate research, memory and apps',
    () async {
      final state = await store.read('owner');
      state['settings']['research'] = false;
      state['settings']['memory'] = false;
      final tools = toolsFor(
        state,
        recordById(state, 'specialists', 'analyst'),
      );
      expect(tools.any((t) => t['type'] == 'web_search'), isFalse);
      expect(tools.any((t) => t['name'] == 'propose_memory'), isFalse);
      expect(tools.any((t) => t['type'] == 'code_interpreter'), isTrue);
    },
  );
  test('streamed answer persists UTF-8 text, sources and files', () async {
    final created = await thread();
    final events = <Json>[];
    final gateway = OpenAiGateway(
      CopilotConfig({'OPEN_AI_KEY': 'test'}),
      clientFactory: () => MockClient((request) async {
        expect(request.url.host, 'api.openai.com');
        final input = jsonDecode(request.body) as Json;
        expect(input['input'].first['content'].first['text'], 'Explain risk');
        return http.Response(
          _sse([
            {
              'type': 'response.output_text.delta',
              'delta': 'Risk ≠ certainty.',
            },
            {
              'type': 'response.completed',
              'response': {
                'id': 'resp_1',
                'output': [
                  {
                    'type': 'message',
                    'content': [
                      {
                        'type': 'output_text',
                        'text': 'Risk ≠ certainty.',
                        'annotations': [
                          {
                            'type': 'url_citation',
                            'url': 'https://example.com/source',
                            'title': 'Source',
                          },
                          {
                            'type': 'container_file_citation',
                            'container_id': 'container_1',
                            'file_id': 'file_1',
                            'filename': 'risk.csv',
                          },
                        ],
                      },
                    ],
                  },
                ],
              },
            },
          ]),
          200,
          headers: {'content-type': 'text/event-stream; charset=utf-8'},
        );
      }),
    );
    await AgentRunner(
      store,
      gateway,
    ).run('owner', created['id'], prompt: 'Explain risk', emit: events.add);
    final saved = recordById(
      await store.read('owner'),
      'threads',
      created['id'],
    );
    final message = records(saved['messages']).last;
    expect(message['body'], 'Risk ≠ certainty.');
    expect(records(message['sources']).single['title'], 'Source');
    expect(records(message['artifacts']).single['filename'], 'risk.csv');
    expect(saved['status'], 'idle');
    expect(events.last['type'], 'done');
  });
  test(
    'draft proposal pauses, approves exactly once, and resumes with the saved page',
    () async {
      final created = await thread();
      var turns = 0;
      final gateway = OpenAiGateway(
        CopilotConfig({'OPEN_AI_KEY': 'test'}),
        clientFactory: () => MockClient((request) async {
          turns++;
          if (turns == 2) {
            final input = jsonDecode(request.body) as Json;
            expect(input['previous_response_id'], 'resp_proposal');
            expect(input['input'].first['type'], 'function_call_output');
          }
          return http.Response(
            _sse([
              {
                'type': 'response.completed',
                'response': {
                  'id': turns == 1 ? 'resp_proposal' : 'resp_saved',
                  'output': turns == 1
                      ? [
                          {
                            'type': 'function_call',
                            'name': 'propose_page',
                            'call_id': 'call_page',
                            'arguments': jsonEncode({
                              'spaceId': 'research',
                              'title': 'Plan',
                              'body': 'Reviewed draft',
                            }),
                          },
                        ]
                      : [],
                },
              },
            ]),
            200,
            headers: {'content-type': 'text/event-stream; charset=utf-8'},
          );
        }),
      );
      final runner = AgentRunner(store, gateway);
      await runner.run('owner', created['id'], prompt: 'Draft a plan');
      var state = await store.read('owner');
      expect(records(state['pages']), isEmpty);
      final pending = records(
        recordById(state, 'threads', created['id'])['approvals'],
      ).single;
      final approvals = ApprovalService(store);
      expect(
        await approvals.decide('owner', created['id'], pending['id'], true),
        isTrue,
      );
      expect(
        await approvals.decide('owner', created['id'], pending['id'], true),
        isFalse,
      );
      state = await store.read('owner');
      expect(records(state['pages']).length, 1);
      await runner.run('owner', created['id'], resume: true);
      expect(turns, 2);
    },
  );
  test('declining a draft has no side effects', () async {
    final created = await thread();
    await store.change(
      'owner',
      (state) => recordById(state, 'threads', created['id'])['approvals'] = [
        {
          'id': 'review',
          'kind': 'propose_memory',
          'status': 'pending',
          'createdAt': now(),
          'callId': 'call',
          'arguments': {'text': 'Preference'},
        },
      ],
    );
    await ApprovalService(
      store,
    ).decide('owner', created['id'], 'review', false);
    expect(records((await store.read('owner'))['memories']), isEmpty);
  });
  test('revoked permissions prevent previously proposed saves', () async {
    final created = await thread();
    await store.change('owner', (state) {
      recordById(state, 'specialists', 'analyst')['spaceIds'] = ['playbook'];
      recordById(state, 'threads', created['id'])['approvals'] = [
        {
          'id': 'review',
          'kind': 'propose_page',
          'status': 'pending',
          'createdAt': now(),
          'callId': 'call',
          'arguments': {
            'spaceId': 'research',
            'title': 'Plan',
            'body': 'Draft',
          },
        },
      ];
    });
    await expectLater(
      ApprovalService(store).decide('owner', created['id'], 'review', true),
      throwsA(isA<CopilotFailure>()),
    );
    expect(records((await store.read('owner'))['pages']), isEmpty);
  });
  test('truncated stream reports failure and preserves partial text', () async {
    final created = await thread();
    final gateway = OpenAiGateway(
      CopilotConfig({'OPEN_AI_KEY': 'test'}),
      clientFactory: () => MockClient(
        (_) async => http.Response(
          _sse([
            {'type': 'response.output_text.delta', 'delta': 'Partial answer'},
          ]),
          200,
          headers: {'content-type': 'text/event-stream; charset=utf-8'},
        ),
      ),
    );
    await AgentRunner(
      store,
      gateway,
    ).run('owner', created['id'], prompt: 'A question');
    final saved = recordById(
      await store.read('owner'),
      'threads',
      created['id'],
    );
    expect(saved['status'], 'failed');
    expect(records(saved['messages']).last['body'], 'Partial answer');
  });
  test(
    'restart marks active schedules interrupted instead of replaying work',
    () async {
      final created = await thread();
      await actions.apply('owner', {
        'action': 'schedule.save',
        'threadId': created['id'],
        'prompt': 'Review',
        'intervalMinutes': 60,
        'nextRunAt': now(),
      });
      await store.change(
        'owner',
        (state) => (state['schedules'] as List).first['status'] = 'running',
      );
      await store.close();
      store = WorkspaceStore(directory);
      await store.open();
      expect(
        records((await store.read('owner'))['schedules']).single['status'],
        'interrupted',
      );
    },
  );
  test(
    'stop keeps the conversation locked until its partial turn settles',
    () async {
      final created = await thread();
      final sent = Completer<void>();
      final response = Completer<http.Response>();
      final runner = AgentRunner(
        store,
        OpenAiGateway(
          CopilotConfig({'OPEN_AI_KEY': 'test'}),
          clientFactory: () => MockClient((_) {
            sent.complete();
            return response.future;
          }),
        ),
      );
      final working = runner.run('owner', created['id'], prompt: 'Start');
      await sent.future;
      runner.stop('owner', created['id']);
      expect(runner.isRunning('owner', created['id']), isTrue);
      await expectLater(
        runner.run('owner', created['id'], prompt: 'Second'),
        throwsA(isA<CopilotFailure>()),
      );
      response.complete(
        http.Response(
          _sse([
            {'type': 'response.output_text.delta', 'delta': 'Late'},
          ]),
          200,
        ),
      );
      await working;
      final saved = recordById(
        await store.read('owner'),
        'threads',
        created['id'],
      );
      expect(saved['status'], 'stopped');
      expect(saved['responseId'], isNull);
      expect(runner.isRunning('owner', created['id']), isFalse);
    },
  );

  test('restart never replays a claimed external approval', () async {
    final created = await thread();
    await store.change('owner', (state) {
      recordById(state, 'threads', created['id']).addAll({
        'status': 'review',
        'responseId': 'old-response',
        'approvals': [
          {
            'id': 'claimed',
            'kind': 'propose_computer_action',
            'status': 'executing',
          },
        ],
      });
    });
    await store.close();
    store = WorkspaceStore(directory);
    await store.open();
    final saved = recordById(
      await store.read('owner'),
      'threads',
      created['id'],
    );
    expect(saved['status'], 'interrupted');
    expect(saved['responseId'], isNull);
    expect(saved['approvals'][0]['status'], 'interrupted');
    expect(
      await ApprovalService(
        store,
      ).decide('owner', created['id'], 'claimed', true),
      isFalse,
    );
  });

  test(
    'disabled MCP tool cannot be approved and an empty selection exposes none',
    () async {
      final created = await thread();
      final connection = await actions.apply('owner', {
        'action': 'connection.save',
        'specialistId': 'analyst',
        'name': 'Test app',
        'url': 'https://mcp.example.com',
        'enabled': true,
        'allTools': false,
        'allowedTools': <String>[],
      });
      await store.change('owner', (state) {
        state['settings']['apps'] = true;
        recordById(state, 'specialists', 'analyst')['apps'] = true;
        recordById(state, 'threads', created['id'])['approvals'] = [
          {
            'id': 'mcp-review',
            'kind': 'mcp',
            'name': 'send_message',
            'status': 'pending',
            'createdAt': now(),
            'arguments': {},
            'connectionId': connection['id'],
            'url': 'https://mcp.example.com',
          },
        ];
      });
      final state = await store.read('owner');
      expect(
        toolsFor(
          state,
          recordById(state, 'specialists', 'analyst'),
        ).where((t) => t['type'] == 'mcp'),
        isEmpty,
      );
      await expectLater(
        ApprovalService(
          store,
        ).decide('owner', created['id'], 'mcp-review', true),
        throwsA(isA<CopilotFailure>()),
      );
    },
  );

  test('a completed response without deltas still saves the answer', () async {
    final created = await thread();
    final runner = AgentRunner(
      store,
      OpenAiGateway(
        CopilotConfig({'OPEN_AI_KEY': 'test'}),
        clientFactory: () => MockClient(
          (_) async => http.Response(
            _sse([
              {
                'type': 'response.completed',
                'response': {
                  'id': 'completed',
                  'output': [
                    {
                      'type': 'message',
                      'content': [
                        {'type': 'output_text', 'text': 'Recovered output'},
                      ],
                    },
                  ],
                },
              },
            ]),
            200,
          ),
        ),
      ),
    );
    await runner.run('owner', created['id'], prompt: 'Question');
    final saved = recordById(
      await store.read('owner'),
      'threads',
      created['id'],
    );
    expect(saved['messages'].last['body'], 'Recovered output');
  });
}

String _sse(List<Json> events) =>
    '${events.map((event) => 'data: ${jsonEncode(event)}\n\n').join()}data: [DONE]\n\n';
