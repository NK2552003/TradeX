import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:tradex/features/copilot/models/workspace.dart';
import 'agent_runner.dart';
import 'approvals.dart';
import 'auth.dart';
import 'config.dart';
import 'computer.dart';
import 'openai_gateway.dart';
import 'scheduler.dart';
import 'slack.dart';
import 'store.dart';
import 'voice.dart';
import 'workspace_actions.dart';

class CopilotServer {
  CopilotServer(this.config, this.store) : auth = CopilotAuth(config);
  final CopilotConfig config;
  final WorkspaceStore store;
  final CopilotAuth auth;
  late final computers = ComputerBridge(config, store);
  late final AgentRunner runner = AgentRunner(
    store,
    OpenAiGateway(config),
    computer: computers,
  );
  late final scheduler = CopilotScheduler(store, runner);
  late final slack = SlackBridge(config, store, runner);
  late final voice = CopilotVoice(config, auth, store, runner);
  HttpServer? _server;
  int? get boundPort => _server?.port;

  Future<void> start() async {
    if (config.localOwner &&
        !['127.0.0.1', '::1', 'localhost'].contains(config.host)) {
      throw const CopilotFailure(
        'Local-owner mode requires a loopback bind address.',
      );
    }
    await store.open();
    _server = await HttpServer.bind(config.host, config.port);
    scheduler.start();
    _server!.listen((request) => unawaited(_handle(request)));
  }

  Future<void> close() async {
    scheduler.stop();
    await _server?.close(force: true);
    await voice.close();
    await runner.stopAll();
    await scheduler.settle();
    await store.close();
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    var streaming = false;
    try {
      final origin = request.headers.value('origin');
      if (!config.allowsOrigin(origin)) {
        throw const CopilotFailure('Origin not allowed.', 403);
      }
      if (origin != null) {
        response.headers.set('Access-Control-Allow-Origin', origin);
      }
      response.headers.set('Vary', 'Origin');
      response.headers.set(
        'Access-Control-Allow-Headers',
        'Authorization, Content-Type',
      );
      response.headers.set(
        'Access-Control-Allow-Methods',
        'GET, POST, OPTIONS',
      );
      response.headers.set('Cache-Control', 'no-store');
      if (request.method == 'OPTIONS') {
        response.statusCode = 204;
        return;
      }
      final path = request.uri.pathSegments;
      if (request.uri.path == '/health') {
        _json(response, {'status': 'ok'});
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/v1/slack/events') {
        await slack.handle(request);
        return;
      }
      if (request.uri.path == '/v1/voice' &&
          WebSocketTransformer.isUpgradeRequest(request)) {
        await voice.connect(request);
        return;
      }
      final owner = await auth.identify(
        request.headers.value('Authorization'),
        request.connectionInfo?.remoteAddress,
      );
      if (request.method == 'GET' && request.uri.path == '/v1/workspace') {
        final state = await store.read(owner);
        for (final connection in state['connections'] as List) {
          connection['hasToken'] = textOf(
            connection as Json,
            'token',
          ).isNotEmpty;
          connection.remove('token');
        }
        for (final thread in state['threads'] as List) {
          thread.remove('continuation');
          thread.remove('responseId');
        }
        state['setup'] = {
          'openai': config.key.isNotEmpty,
          'model': config.model,
          'voice': config.key.isNotEmpty,
          'schedules': true,
          'computer': computers.configured,
          'slack': slack.configured && config.values['SLACK_OWNER_ID'] == owner,
        };
        _json(response, state);
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/v1/actions') {
        final input = await _body(request);
        final result = await WorkspaceActions(store).apply(owner, input);
        if (input['action'] == 'settings.save' && input['paused'] == true) {
          final state = await store.read(owner);
          for (final thread in records(state['threads'])) {
            runner.stop(owner, thread['id']);
          }
        }
        _json(response, result);
        return;
      }
      if (path.length == 3 && path[0] == 'v1' && path[1] == 'computers') {
        if (request.method == 'GET') {
          _json(response, await computers.status(owner, path[2]));
        } else if (request.method == 'POST') {
          final input = await _body(request);
          _json(
            response,
            await computers.perform(
              owner,
              path[2],
              requiredText(input, 'action'),
              Map<String, dynamic>.from(input['input'] ?? {}),
            ),
          );
        } else {
          throw const CopilotFailure('Method not allowed.', 405);
        }
        return;
      }
      if (path.length == 4 &&
          path[0] == 'v1' &&
          path[1] == 'threads' &&
          request.method == 'POST') {
        final threadId = path[2];
        final input = await _body(request);
        if (path[3] == 'stop') {
          recordById(await store.read(owner), 'threads', threadId);
          runner.stop(owner, threadId);
          _json(response, {'stopped': true});
          return;
        }
        if (path[3] == 'approve') {
          final ready = await ApprovalService(store, computer: computers)
              .decide(
                owner,
                threadId,
                requiredText(input, 'id'),
                input['approve'] == true,
              );
          if (!ready) {
            _json(response, {'pending': true});
            return;
          }
          input['resume'] = true;
        } else if (path[3] != 'run') {
          throw const CopilotFailure('Endpoint not found.', 404);
        }
        if (path[3] == 'run' && input['resume'] == true) {
          throw const CopilotFailure(
            'Resume reviewed actions through their approval request.',
          );
        }
        final attachments = _attachments(input['attachments']);
        response.headers.contentType = ContentType(
          'application',
          'x-ndjson',
          charset: 'utf-8',
        );
        response.bufferOutput = false;
        streaming = true;
        var connected = true;
        response.done.catchError((_) {
          connected = false;
        });
        await runner.run(
          owner,
          threadId,
          prompt: input['prompt'] as String?,
          mode: textOf(input, 'mode', 'auto'),
          resume: input['resume'] == true,
          attachments: attachments,
          emit: (event) {
            if (connected) {
              try {
                response.writeln(jsonEncode(event));
              } catch (_) {
                connected = false;
              }
            }
          },
        );
        return;
      }
      if (request.method == 'GET' &&
          path.length == 5 &&
          path[0] == 'v1' &&
          path[1] == 'artifacts') {
        final state = await store.read(owner);
        final thread = recordById(state, 'threads', path[2]);
        final allowed = records(thread['messages'])
            .expand((m) => records(m['artifacts']))
            .any(
              (a) => a['container_id'] == path[3] && a['file_id'] == path[4],
            );
        if (!allowed) throw const CopilotFailure('File not found.', 404);
        final client = http.Client();
        try {
          final upstream = await client.send(
            http.Request(
              'GET',
              Uri.parse(
                'https://api.openai.com/v1/containers/${Uri.encodeComponent(path[3])}/files/${Uri.encodeComponent(path[4])}/content',
              ),
            )..headers['Authorization'] = _bearer(config.key),
          );
          response.statusCode = upstream.statusCode;
          response.headers.contentType = ContentType.binary;
          await response.addStream(upstream.stream);
        } finally {
          client.close();
        }
        return;
      }
      throw const CopilotFailure('Endpoint not found.', 404);
    } catch (error) {
      final failure = error is CopilotFailure
          ? error
          : error is FormatException || error is TypeError
          ? const CopilotFailure('Invalid request data.')
          : const CopilotFailure(
              'The copilot service could not complete this request.',
              500,
            );
      try {
        if (!streaming) response.statusCode = failure.status;
        _json(response, {
          'type': 'error',
          'message': failure.message,
        }, setType: !streaming);
      } catch (_) {
        /* The client disconnected; persisted work remains available. */
      }
    } finally {
      try {
        await response.close();
      } catch (_) {
        /* Already upgraded or disconnected. */
      }
    }
  }

  static String _bearer(String value) =>
      '${String.fromCharCodes([66, 101, 97, 114, 101, 114])} $value';
  static void _json(HttpResponse response, Json value, {bool setType = true}) {
    if (setType) response.headers.contentType = ContentType.json;
    response.writeln(jsonEncode(value));
  }

  static Future<Json> _body(HttpRequest request) async {
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
      if (bytes.length > 12000000) {
        throw const CopilotFailure('Request exceeds the 12 MB limit.', 413);
      }
    }
    return jsonDecode(utf8.decode(bytes)) as Json;
  }

  static List<Json> _attachments(dynamic raw) {
    final attachments = records(raw);
    if (attachments.length > 4) {
      throw const CopilotFailure('Attach up to four files.');
    }
    for (final item in attachments) {
      if (item['type'] == 'input_image') {
        if (!RegExp(
          r'^data:image/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$',
        ).hasMatch(textOf(item, 'image_url'))) {
          throw const CopilotFailure('Attach PNG, JPEG, or WebP images.');
        }
      } else if (item['type'] == 'input_file') {
        if (!textOf(item, 'filename').toLowerCase().endsWith('.pdf') ||
            !textOf(
              item,
              'file_data',
            ).startsWith('data:application/pdf;base64,')) {
          throw const CopilotFailure(
            'Only PDF file attachments are supported.',
          );
        }
      } else if (item['type'] != 'input_text') {
        throw const CopilotFailure('Unsupported attachment.');
      }
    }
    return attachments;
  }
}
