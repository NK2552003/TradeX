import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:tradex/features/copilot/models/workspace.dart';
import 'config.dart';
import 'store.dart';

class OpenAiGateway {
  static String _bearer(String value) =>
      '${String.fromCharCodes([66, 101, 97, 114, 101, 114])} $value';
  OpenAiGateway(this.config, {http.Client Function()? clientFactory})
    : clientFactory = clientFactory ?? http.Client.new;
  final CopilotConfig config;
  final http.Client Function() clientFactory;

  Stream<Json> respond(http.Client client, Json body) async* {
    if (config.key.isEmpty) {
      throw const CopilotFailure(
        'Add OPEN_AI_KEY to the server .env and restart the copilot service.',
        503,
      );
    }
    final request =
        http.Request('POST', Uri.parse('https://api.openai.com/v1/responses'))
          ..headers.addAll({
            'Authorization': _bearer(config.key),
            'Content-Type': 'application/json',
          })
          ..body = jsonEncode({
            ...body,
            'model': config.model,
            'stream': true,
            'store': true,
          });
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw CopilotFailure(switch (response.statusCode) {
        401 => 'OpenAI rejected the server API key.',
        429 =>
          'OpenAI rate or credit limit reached. Check the project’s billing or try again later.',
        400 =>
          'OpenAI could not run this model or tool configuration. Check the configured model and connections.',
        _ =>
          'OpenAI is unavailable (${response.statusCode}). Try again shortly.',
      }, 502);
    }
    var data = <String>[];
    await for (final line
        in response.stream
            .timeout(const Duration(minutes: 3))
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (data.isNotEmpty) {
          final payload = data.join('\n');
          data = [];
          if (payload == '[DONE]') break;
          yield jsonDecode(payload) as Json;
        }
      } else if (line.startsWith('data:')) {
        data.add(line.substring(5).trimLeft());
      }
    }
    if (data.isNotEmpty && data.join('\n') != '[DONE]') {
      yield jsonDecode(data.join('\n')) as Json;
    }
  }
}
