import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:tradex/features/copilot/models/workspace.dart';
import 'agent_tools.dart';
import 'computer.dart';
import 'openai_gateway.dart';
import 'store.dart';

typedef Emit = void Function(Json event);

class AgentRunner {
  AgentRunner(this.store, this.gateway, {this.computer});
  final WorkspaceStore store;
  final OpenAiGateway gateway;
  final ComputerBridge? computer;
  final Map<String, http.Client> _active = {};
  final Set<http.Client> _cancelled = {};
  final Map<http.Client, Completer<void>> _finished = {};
  bool isRunning(String owner, String threadId) =>
      _active.containsKey('$owner/$threadId');

  void stop(String owner, String threadId) {
    final client = _active['$owner/$threadId'];
    if (client == null) return;
    _cancelled.add(client);
    client.close();
  }

  Future<void> stopAll() async {
    for (final client in _active.values) {
      _cancelled.add(client);
      client.close();
    }
    await Future.wait(_finished.values.map((c) => c.future));
  }

  Future<void> run(
    String owner,
    String threadId, {
    String? prompt,
    List<Json>? attachments,
    String mode = 'auto',
    bool resume = false,
    Emit? emit,
  }) async {
    final key = '$owner/$threadId';
    if (_active.containsKey(key)) {
      throw const CopilotFailure(
        'This specialist is already working in this conversation.',
        409,
      );
    }
    final client = gateway.clientFactory();
    _active[key] = client;
    _finished[client] = Completer<void>();
    final messageId = newId();
    var body = '';
    final activity = <Json>[];
    final sources = <Json>[];
    final artifacts = <Json>[];
    var started = false;
    void event(Json value) => emit?.call(value);
    try {
      var state = await store.read(owner);
      if (state['settings']['paused'] == true) {
        throw const CopilotFailure(
          'The workspace is paused. Resume it in settings.',
        );
      }
      if (!['auto', 'search', 'research'].contains(mode)) {
        throw const CopilotFailure('Choose Auto, Search, or Deep research.');
      }
      var thread = recordById(state, 'threads', threadId);
      final selected = recordById(state, 'specialists', thread['specialistId']);
      if (mode != 'auto' &&
          (state['settings']['research'] != true ||
              selected['research'] != true)) {
        throw const CopilotFailure(
          'Enable web research for this profile before using this mode.',
        );
      }
      if (!resume &&
          records(
            thread['approvals'],
          ).any((a) => ['pending', 'executing'].contains(a['status']))) {
        throw const CopilotFailure(
          'Review the pending actions before continuing.',
          409,
        );
      }
      var input = <Json>[];
      if (!resume && records(thread['continuation']).isNotEmpty) {
        await store.change(
          owner,
          (workspace) =>
              resetContinuation(recordById(workspace, 'threads', threadId)),
        );
        thread = recordById(await store.read(owner), 'threads', threadId);
      }
      if (resume) {
        input = records(thread['continuation']);
        if (input.isEmpty) {
          throw const CopilotFailure(
            'There is no pending turn to resume.',
            409,
          );
        }
      } else {
        final value = prompt?.trim() ?? '';
        if (value.isEmpty || value.length > 24000) {
          throw const CopilotFailure(
            'Enter a message of up to 24,000 characters.',
          );
        }
        input = [
          if (thread['responseId'] == null) ...[
            for (final message
                in records(thread['messages'])
                    .where((m) => textOf(m, 'body').isNotEmpty)
                    .toList()
                    .reversed
                    .take(40)
                    .toList()
                    .reversed)
              {'role': message['role'], 'content': message['body']},
            if (records(thread['approvals']).isNotEmpty)
              {
                'role': 'user',
                'content':
                    'Earlier action receipts from this conversation (context only; do not repeat these actions): ${jsonEncode(thread['approvals'])}',
              },
          ],
          {
            'role': 'user',
            'content': [
              {'type': 'input_text', 'text': value},
              ...?attachments,
            ],
          },
        ];
      }
      await store.change(owner, (workspace) {
        final current = recordById(workspace, 'threads', threadId);
        current['status'] = 'running';
        current['updatedAt'] = now();
        current.remove('error');
        if (!resume) {
          (current['messages'] as List).add({
            'id': newId(),
            'role': 'user',
            'body': prompt!.trim(),
            'createdAt': now(),
            'status': 'complete',
          });
          if (current['title'] == 'New conversation') {
            current['title'] = prompt.trim().substring(
              0,
              prompt.trim().length.clamp(0, 65),
            );
          }
        }
        current.remove('continuation');
        (current['messages'] as List).add({
          'id': messageId,
          'role': 'assistant',
          'body': '',
          'status': 'streaming',
          'createdAt': now(),
        });
      });
      started = true;
      event({'type': 'started', 'messageId': messageId});
      String? previous = thread['responseId'] as String?;
      for (var step = 0; step < 12; step++) {
        if (_cancelled.contains(client)) {
          throw const CopilotFailure('Stopped.', 499);
        }
        state = await store.read(owner);
        thread = recordById(state, 'threads', threadId);
        final specialist = recordById(
          state,
          'specialists',
          thread['specialistId'],
        );
        if (state['settings']['paused'] == true) {
          throw const CopilotFailure('Workspace paused.', 499);
        }
        Json? completed;
        final stepStart = body.length;
        await for (final response in gateway.respond(client, {
          'instructions':
              '${instructionsFor(state, specialist, thread)}${switch (mode) {
                'search' => '\nSearch the web for current information and answer concisely with source citations.',
                'research' => '\nResearch this question in depth using the web. Compare multiple relevant sources, verify dates and conflicting claims, and give a structured, cited synthesis with uncertainties. Do not claim exhaustive coverage.',
                _ => '',
              }}',
          'input': input,
          'tools': [
            for (final tool in toolsFor(state, specialist))
              if (tool['type'] == 'web_search' && mode == 'research')
                {...tool, 'search_context_size': 'high'}
              else
                tool,
          ],
          if (mode != 'auto' && !resume && step == 0)
            'tool_choice': {'type': 'web_search'},
          'previous_response_id': ?previous,
          'max_output_tokens': 8000,
        })) {
          if (_cancelled.contains(client)) {
            throw const CopilotFailure('Stopped.', 499);
          }
          switch (response['type']) {
            case 'response.output_text.delta':
              final delta = textOf(response, 'delta');
              body += delta;
              event({'type': 'delta', 'text': delta});
            case 'response.output_item.added':
              final item = response['item'] as Json;
              if (item['type'] != 'message' && item['type'] != 'reasoning') {
                final entry = {
                  'type': item['type'],
                  'name': item['name'] ?? item['type'],
                  'at': now(),
                };
                activity.add(entry);
                event({...entry, 'type': 'activity'});
              }
            case 'response.completed':
              completed = response['response'] as Json;
            case 'response.failed':
            case 'error':
              throw const CopilotFailure(
                'The model could not complete this turn. Your conversation has been kept.',
                502,
              );
            case 'response.incomplete':
              throw const CopilotFailure(
                'The response reached its output limit. Ask to continue from the saved partial answer.',
                502,
              );
          }
        }
        if (completed == null) {
          throw const CopilotFailure(
            'The connection ended before the answer completed.',
            502,
          );
        }
        previous = completed['id'] as String;
        final output = records(completed['output']);
        if (body.length == stepStart) {
          final fallback = output
              .where((item) => item['type'] == 'message')
              .expand((item) => records(item['content']))
              .where((content) => content['type'] == 'output_text')
              .map((content) => textOf(content, 'text'))
              .join();
          if (fallback.isNotEmpty) {
            body += fallback;
            event({'type': 'delta', 'text': fallback});
          }
        }
        final continuation = <Json>[];
        final approvals = <Json>[];
        for (final item in output) {
          if (item['type'] == 'message') {
            for (final content in records(item['content'])) {
              for (final annotation in records(content['annotations'])) {
                if (annotation['type'] == 'url_citation') {
                  if (!sources.any((s) => s['url'] == annotation['url'])) {
                    sources.add(annotation);
                  }
                } else if (annotation['type'] == 'container_file_citation') {
                  artifacts.add(annotation);
                }
              }
            }
          } else if (item['type'] == 'function_call') {
            Json? result;
            try {
              if (item['name'] == 'computer_read') {
                final args = parseArguments(item);
                if (![
                      'snapshot',
                      'screenshot',
                      'read',
                      'files_list',
                      'files_read',
                    ].contains(args['action']) ||
                    computer == null) {
                  result = {'error': 'Computer read action unavailable.'};
                } else {
                  result = await computer!.perform(
                    owner,
                    specialist['id'],
                    args['action'],
                    jsonDecode(textOf(args, 'input', '{}')) as Json,
                    agent: true,
                  );
                }
              } else {
                result = readTool(state, specialist, item);
              }
            } on CopilotFailure catch (error) {
              result = {'error': error.message};
            }
            if (result != null) {
              continuation.add(functionResult(item['call_id'], result));
            } else if ([
              'propose_page',
              'propose_memory',
              'propose_skill',
              'propose_computer_action',
            ].contains(item['name'])) {
              approvals.add({
                'id': newId(),
                'kind': item['name'],
                'messageId': messageId,
                'callId': item['call_id'],
                'arguments': parseArguments(item),
                'status': 'pending',
                'createdAt': now(),
                'specialistId': specialist['id'],
              });
            } else {
              continuation.add(
                functionResult(item['call_id'], {'error': 'Tool unavailable.'}),
              );
            }
          } else if (item['type'] == 'mcp_list_tools') {
            await store.change(owner, (workspace) {
              for (final connection in workspace['connections'] as List) {
                if ('connection_${textOf(connection as Json, 'id').replaceAll('-', '_')}' ==
                    item['server_label']) {
                  connection['tools'] = item['tools'];
                }
              }
            });
          } else if (item['type'] == 'mcp_approval_request') {
            final connection = records(state['connections'])
                .where(
                  (c) =>
                      'connection_${textOf(c, 'id').replaceAll('-', '_')}' ==
                      item['server_label'],
                )
                .firstOrNull;
            if (connection == null) {
              throw const CopilotFailure('Connection unavailable.');
            }
            approvals.add({
              'id': newId(),
              'kind': 'mcp',
              'messageId': messageId,
              'requestId': item['id'],
              'name': item['name'],
              'connectionId': connection['id'],
              'connectionName': connection['name'],
              'url': connection['url'],
              'arguments': parseArguments(item),
              'status': 'pending',
              'createdAt': now(),
            });
          }
        }
        await store.change(owner, (workspace) {
          final current = recordById(workspace, 'threads', threadId);
          current['responseId'] = previous;
          if (approvals.isNotEmpty) {
            (current['approvals'] as List).addAll(approvals);
            current['continuation'] = continuation;
            current['status'] = 'review';
          }
        });
        if (approvals.isNotEmpty) {
          if (body.isEmpty) body = 'I’ve prepared an action for your review.';
          break;
        }
        if (continuation.isEmpty) break;
        input = continuation;
        if (step == 11) {
          throw const CopilotFailure(
            'This turn reached its tool limit. Continue with a more focused request.',
          );
        }
      }
      await _finish(
        owner,
        threadId,
        messageId,
        body,
        'complete',
        sources,
        artifacts,
        activity,
      );
      event({'type': 'done'});
    } catch (error) {
      final stopped = _cancelled.contains(client);
      final message = stopped
          ? 'Stopped.'
          : error is CopilotFailure
          ? error.message
          : 'Connection lost. Your partial answer has been kept.';
      if (started) {
        await _finish(
          owner,
          threadId,
          messageId,
          body,
          stopped ? 'stopped' : 'failed',
          sources,
          artifacts,
          activity,
          error: message,
        );
      }
      event({'type': 'error', 'message': message});
      if (!started) rethrow;
    } finally {
      if (_active[key] == client) _active.remove(key);
      _cancelled.remove(client);
      _finished.remove(client)?.complete();
      client.close();
    }
  }

  Future<void> _finish(
    String owner,
    String threadId,
    String messageId,
    String body,
    String status,
    List<Json> sources,
    List<Json> artifacts,
    List<Json> activity, {
    String? error,
  }) => store.change(owner, (state) {
    final thread = recordById(state, 'threads', threadId);
    final message =
        (thread['messages'] as List).firstWhere((m) => m['id'] == messageId)
            as Json;
    message.addAll({
      'body': body,
      'status': status,
      'sources': sources,
      'artifacts': artifacts,
      'activity': activity,
    });
    if (error != null) {
      thread['error'] = error;
      resetContinuation(thread);
    }
    if (thread['status'] != 'review') {
      thread['status'] = status == 'complete' ? 'idle' : status;
    }
    thread['updatedAt'] = now();
  });
}
