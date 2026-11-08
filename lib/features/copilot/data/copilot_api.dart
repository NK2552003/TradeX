import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:tradex/core/config/supabase_config.dart';

import '../models/workspace.dart';

class CopilotApiException implements Exception {
  const CopilotApiException(this.message, [this.status = 0]);
  final String message;
  final int status;
  @override
  String toString() => message;
}

class CopilotApi {
  CopilotApi({Uri? baseUri, http.Client? client, String? Function()? token})
    : baseUri =
          baseUri ??
          Uri.parse(
            const String.fromEnvironment(
              'COPILOT_API_URL',
              defaultValue: 'http://127.0.0.1:8787',
            ),
          ),
      _client = client ?? http.Client(),
      _token =
          token ??
          (() => SupabaseConfig.client?.auth.currentSession?.accessToken);
  final Uri baseUri;
  final http.Client _client;
  final String? Function() _token;
  String? get authorization {
    final token = _token()?.trim();
    return token == null || token.isEmpty ? null : _bearer(token);
  }
  static String _bearer(String value) =>
      '${String.fromCharCodes([66, 101, 97, 114, 101, 114])} $value';
  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Authorization': ?authorization,
  };

  Future<Json> getWorkspace() => _request('GET', '/v1/workspace');
  Future<Json> action(Json body) => _request('POST', '/v1/actions', body);
  Future<Json> stop(String id) => _request('POST', '/v1/threads/$id/stop', {});
  Future<Json> computer(
    String specialist, {
    String? action,
    Json input = const {},
  }) => _request(
    action == null ? 'GET' : 'POST',
    '/v1/computers/$specialist',
    action == null ? null : {'action': action, 'input': input},
  );

  Future<Json> _request(String method, String path, [Json? body]) async {
    try {
      final request = http.Request(method, baseUri.resolve(path))
        ..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await _client.send(request),
      ).timeout(const Duration(seconds: 30));
      final value = jsonDecode(response.body) as Json;
      if (response.statusCode >= 400) {
        throw CopilotApiException(
          textOf(value, 'message', 'Request failed.'),
          response.statusCode,
        );
      }
      return value;
    } on CopilotApiException {
      rethrow;
    } catch (_) {
      throw const CopilotApiException(
        'The configured copilot service could not be reached. Please reconnect or contact support.',
      );
    }
  }

  Stream<Json> run(String threadId, Json body, {bool approval = false}) async* {
    try {
      final request =
          http.Request(
              'POST',
              baseUri.resolve(
                '/v1/threads/$threadId/${approval ? 'approve' : 'run'}',
              ),
            )
            ..headers.addAll(headers)
            ..body = jsonEncode(body);
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      await for (final line
          in response.stream
              .timeout(const Duration(minutes: 4))
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        final event = jsonDecode(line) as Json;
        if (response.statusCode >= 400) {
          throw CopilotApiException(
            textOf(event, 'message'),
            response.statusCode,
          );
        }
        yield event;
      }
    } on CopilotApiException {
      rethrow;
    } catch (_) {
      throw const CopilotApiException(
        'The connection was interrupted. Reconnect to check the saved result before retrying.',
      );
    }
  }

  Future<Uint8List> artifact(String threadId, Json artifact) async {
    final response = await _client.get(
      baseUri.resolve(
        '/v1/artifacts/$threadId/${artifact['container_id']}/${artifact['file_id']}',
      ),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw const CopilotApiException(
        'This generated file is no longer available. Ask the specialist to recreate it.',
      );
    }
    return response.bodyBytes;
  }

  Uri get voiceUri => baseUri
      .resolve('/v1/voice')
      .replace(scheme: baseUri.scheme == 'https' ? 'wss' : 'ws');
  void dispose() => _client.close();
}
