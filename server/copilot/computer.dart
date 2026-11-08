import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:tradex/features/copilot/models/workspace.dart';

import 'config.dart';
import 'store.dart';

class ComputerBridge {
  static String _bearer(String value) => "${String.fromCharCodes([66, 101, 97, 114, 101, 114])} $value";
  ComputerBridge(this.config, this.store);
  final CopilotConfig config;
  final WorkspaceStore store;
  bool get configured => [
    'COMPUTER_SUPERVISOR_URL',
    'COMPUTER_SUPERVISOR_TOKEN',
    'COMPUTER_TOKEN',
  ].every((name) => (config.values[name] ?? '').isNotEmpty);
  String _identity(String owner, String specialist) => sha256
      .convert(utf8.encode('$owner/$specialist'))
      .toString()
      .substring(0, 32);
  String _token(String id) => Hmac(
    sha256,
    utf8.encode(config.values['COMPUTER_TOKEN']!),
  ).convert(utf8.encode('opendots-computer:$id')).toString();

  Future<Json> _request(Uri uri, String token, {Json? body, String? id}) async {
    final client = http.Client();
    try {
      final request = http.Request(body == null ? 'GET' : 'POST', uri)
        ..followRedirects = false
        ..headers.addAll({
          'Authorization': _bearer(token),
          'Content-Type': 'application/json',
          'x-openbot-bot-id': ?id,
        });
      if (body != null) request.body = jsonEncode(body);
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 70));
      if (response.statusCode == 409) {
        throw const CopilotFailure(
          'Refresh the computer snapshot, or release human control before the specialist continues.',
          409,
        );
      }
      if (response.statusCode != 200) {
        throw CopilotFailure(
          'Computer service returned ${response.statusCode}.',
          502,
        );
      }
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        if (bytes.length > 6000000) {
          throw const CopilotFailure(
            'Computer output exceeded the display limit.',
          );
        }
      }
      var text = utf8.decode(bytes);
      for (final secret in [
        token,
        config.values['COMPUTER_TOKEN'],
        config.values['COMPUTER_SUPERVISOR_TOKEN'],
      ]) {
        if (secret != null && secret.isNotEmpty) {
          text = text.replaceAll(secret, '[redacted]');
        }
      }
      return jsonDecode(text) as Json;
    } finally {
      client.close();
    }
  }

  Future<Json?> _state(String id) async {
    final response = await _request(
      Uri.parse('${config.values['COMPUTER_SUPERVISOR_URL']}/computers'),
      config.values['COMPUTER_SUPERVISOR_TOKEN']!,
    );
    return records(
      response['computers'],
    ).where((c) => c['botId'] == id).firstOrNull;
  }

  Uri _endpoint(String id, Json state) {
    final container =
        '${config.values['COMPUTER_NAMESPACE'] ?? 'opendots'}-computer-$id';
    final uri = Uri.tryParse(
      textOf(
        state,
        'url',
        state['port'] == null
            ? 'http://$container:4100'
            : 'http://127.0.0.1:${state['port']}',
      ),
    );
    if (state['botId'] != id ||
        state['container'] != container ||
        uri == null ||
        uri.scheme != 'http' ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        !['127.0.0.1', 'localhost', container].contains(uri.host) ||
        (uri.host == container
            ? uri.port != 4100
            : uri.port != state['port']) ||
        uri.path != '') {
      throw const CopilotFailure(
        'Computer identity could not be verified.',
        502,
      );
    }
    return uri;
  }

  Future<Json> status(String owner, String specialistId) async {
    final workspace = await store.read(owner);
    final specialist = recordById(workspace, 'specialists', specialistId);
    final base = <String, dynamic>{
      'configured': configured,
      'permissions':
          specialist['computer'] ??
          {'enabled': false, 'browser': false, 'files': false, 'shell': false},
      'activity': (specialist['computerActivity'] as List? ?? []).reversed
          .take(30)
          .toList(),
    };
    if (!configured) return {...base, 'state': 'not_configured'};
    try {
      final id = _identity(owner, specialistId);
      final state = await _state(id);
      if (state == null || state['status'] != 'running') {
        return {...base, 'state': 'stopped'};
      }
      final control = await _request(
        _endpoint(id, state).resolve('/control'),
        _token(id),
        id: id,
      );
      return {...base, 'state': 'running', 'control': control};
    } catch (_) {
      return {...base, 'state': 'unavailable'};
    }
  }

  Future<Json> perform(
    String owner,
    String specialistId,
    String action,
    Json input, {
    bool agent = false,
  }) async {
    final workspace = await store.read(owner);
    final specialist = recordById(workspace, 'specialists', specialistId);
    if (action == 'permissions' && !agent) {
      await store.change(
        owner,
        (state) =>
            recordById(state, 'specialists', specialistId)['computer'] = {
              for (final flag in ['enabled', 'browser', 'files', 'shell'])
                flag: input[flag] == true,
            },
      );
      return status(owner, specialistId);
    }
    if (!configured) {
      throw const CopilotFailure(
        'Connect an isolated OpenBot computer service in the server configuration first.',
        503,
      );
    }
    final permissions = specialist['computer'] as Json? ?? {};
    final kind = action == 'exec'
        ? 'shell'
        : action.startsWith('files_')
        ? 'files'
        : 'browser';
    if (permissions['enabled'] != true ||
        (!['start', 'stop', 'take', 'release'].contains(action) &&
            permissions[kind] != true) ||
        (agent &&
            (workspace['settings']['paused'] == true ||
                action.startsWith('human_') ||
                ['start', 'stop', 'take', 'release'].contains(action)))) {
      throw const CopilotFailure('This computer action is not permitted.', 403);
    }
    _validate(action, input);
    final id = _identity(owner, specialistId);
    Json result;
    try {
      if (action == 'start' || action == 'stop') {
        result = await _request(
          Uri.parse(
            '${config.values['COMPUTER_SUPERVISOR_URL']}/computers/$id/${action == 'start' ? 'ensure' : 'stop'}',
          ),
          config.values['COMPUTER_SUPERVISOR_TOKEN']!,
          body: {},
        );
      } else {
        final state = await _state(id);
        if (state == null || state['status'] != 'running') {
          throw const CopilotFailure('Start this specialist’s computer first.');
        }
        final endpoint = _endpoint(id, state);
        if (action == 'take' || action == 'release') {
          var control = await _request(
            endpoint.resolve('/control'),
            _token(id),
            id: id,
          );
          if (action == 'take' && control['request'] == null) {
            control = await _request(
              endpoint.resolve('/control/request'),
              _token(id),
              id: id,
              body: {'reason': 'Owner requested control.'},
            );
          }
          if (control['request'] == null) {
            throw const CopilotFailure('There is no active takeover request.');
          }
          result = await _request(
            endpoint.resolve('/control/$action'),
            _token(id),
            id: id,
            body: {'requestId': control['request']['id']},
          );
        } else {
          final route = action
              .replaceFirst('files_', 'files/')
              .replaceFirst('human_', 'human/');
          result = await _request(
            endpoint.resolve('/$route'),
            _token(id),
            id: id,
            body: ['read', 'screenshot'].contains(action) ? null : input,
          );
        }
      }
      await _audit(owner, specialistId, action, agent, 'completed');
      return result;
    } catch (_) {
      await _audit(owner, specialistId, action, agent, 'failed');
      rethrow;
    }
  }

  Future<void> _audit(
    String owner,
    String specialist,
    String action,
    bool agent,
    String outcome,
  ) => store.change(owner, (state) {
    final item = recordById(state, 'specialists', specialist);
    final log = item.putIfAbsent('computerActivity', () => <Json>[]) as List;
    log.add({
      'action': action,
      'actor': agent ? 'specialist' : 'you',
      'outcome': outcome,
      'at': now(),
    });
    if (log.length > 200) log.removeAt(0);
  });

  void _validate(String action, Json input) {
    const allowed = [
      'start',
      'stop',
      'take',
      'release',
      'navigate',
      'read',
      'snapshot',
      'screenshot',
      'click',
      'type',
      'key',
      'scroll',
      'files_list',
      'files_read',
      'files_write',
      'exec',
      'human_click',
      'human_type',
      'human_key',
      'human_scroll',
    ];
    if (!allowed.contains(action)) {
      throw const CopilotFailure('Unknown computer action.');
    }
    if (action.startsWith('files_')) {
      final path = textOf(input, 'path');
      if (path.startsWith('/') ||
          path.contains('\\') ||
          path.contains('\u0000') ||
          path.split('/').contains('..')) {
        throw const CopilotFailure(
          'Use a relative computer workspace path without traversal.',
        );
      }
    }
    if (action == 'navigate') {
      final uri = Uri.tryParse(textOf(input, 'url'));
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.userInfo.isNotEmpty) {
        throw const CopilotFailure('Enter a valid public web address.');
      }
    }
    if (jsonEncode(input).length > 120000) {
      throw const CopilotFailure('Computer input is too large.');
    }
  }
}
