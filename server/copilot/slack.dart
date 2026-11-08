import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:tradex/features/copilot/models/workspace.dart';

import 'agent_runner.dart';
import 'config.dart';
import 'store.dart';
import 'workspace_actions.dart';

class SlackBridge {
  static String _bearer(String value) =>
      '${String.fromCharCodes([66, 101, 97, 114, 101, 114])} $value';
  SlackBridge(this.config, this.store, this.runner);
  final CopilotConfig config;
  final WorkspaceStore store;
  final AgentRunner runner;
  bool get configured => [
    'SLACK_SIGNING_SECRET',
    'SLACK_BOT_TOKEN',
    'SLACK_OWNER_ID',
    'SLACK_TEAM_ID',
    'SLACK_ALLOWED_USER_IDS',
  ].every((k) => (config.values[k] ?? '').isNotEmpty);

  Future<void> handle(HttpRequest request) async {
    if (!configured) {
      throw const CopilotFailure('Slack is not configured.', 503);
    }
    final timestamp = request.headers.value('x-slack-request-timestamp') ?? '';
    final signature = request.headers.value('x-slack-signature') ?? '';
    final seconds = int.tryParse(timestamp) ?? 0;
    if ((DateTime.now().millisecondsSinceEpoch ~/ 1000 - seconds).abs() > 300) {
      throw const CopilotFailure('Expired Slack request.', 401);
    }
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
      if (bytes.length > 1000000) {
        throw const CopilotFailure('Slack request too large.', 413);
      }
    }
    final body = utf8.decode(bytes);
    final expected =
        'v0=${Hmac(sha256, utf8.encode(config.values['SLACK_SIGNING_SECRET']!)).convert(utf8.encode('v0:$timestamp:$body'))}';
    if (!_equal(expected, signature)) {
      throw const CopilotFailure('Invalid Slack signature.', 401);
    }
    final envelope = jsonDecode(body) as Json;
    request.response.headers.contentType = ContentType.json;
    if (envelope['type'] == 'url_verification') {
      request.response.write(jsonEncode({'challenge': envelope['challenge']}));
      return;
    }
    final event = Map<String, dynamic>.from(envelope['event'] ?? {});
    final allowedUsers = config.values['SLACK_ALLOWED_USER_IDS']!
        .split(',')
        .map((s) => s.trim())
        .toSet();
    if (envelope['team_id'] != config.values['SLACK_TEAM_ID'] ||
        !allowedUsers.contains(event['user']) ||
        event['bot_id'] != null ||
        event['subtype'] != null ||
        !['app_mention', 'message'].contains(event['type'])) {
      request.response.write('{}');
      return;
    }
    final owner = config.values['SLACK_OWNER_ID']!;
    final eventId = requiredText(envelope, 'event_id');
    final isNew = await store.change(owner, (state) {
      final seen = state.putIfAbsent('slackEvents', () => <String>[]) as List;
      if (seen.contains(eventId)) return false;
      seen.add(eventId);
      if (seen.length > 2000) seen.removeAt(0);
      return true;
    });
    request.response.write('{}');
    if (isNew) unawaited(_respond(owner, event));
  }

  Future<void> _respond(String owner, Json event) async {
    final channel = textOf(event, 'channel');
    final timestamp = textOf(event, 'thread_ts', textOf(event, 'ts'));
    final binding = '$channel/$timestamp';
    try {
      var workspace = await store.read(owner);
      String? threadId =
          (workspace['slackThreads'] as Map?)?[binding] as String?;
      if (threadId == null && event['type'] != 'app_mention') return;
      if (threadId == null) {
        final thread = await WorkspaceActions(store).apply(owner, {
          'action': 'thread.create',
          'specialistId': config.values['SLACK_SPECIALIST_ID'] ?? 'analyst',
          'title': 'Slack conversation',
        });
        threadId = thread['id'];
        await store.change(
          owner,
          (state) =>
              (state.putIfAbsent('slackThreads', () => <String, dynamic>{})
                      as Json)[binding] =
                  threadId,
        );
      }
      if (runner.isRunning(owner, threadId!)) return;
      final prompt = textOf(
        event,
        'text',
      ).replaceAll(RegExp(r'<@[A-Z0-9]+>'), '').trim();
      if (prompt.isEmpty) return;
      await runner.run(owner, threadId, prompt: prompt);
      workspace = await store.read(owner);
      final thread = recordById(workspace, 'threads', threadId);
      final message = records(
        thread['messages'],
      ).where((m) => m['role'] == 'assistant').lastOrNull;
      var reply = message == null
          ? 'Open the copilot conversation to review this run.'
          : textOf(message, 'body');
      if (thread['status'] == 'review') {
        reply += '\n\nAn action needs your approval in the TradeX copilot.';
      }
      if (reply.length > 3000) {
        reply = '${reply.substring(0, 3000)}\nContinue reading in TradeX.';
      }
      final client = http.Client();
      try {
        final response = await client
            .post(
              Uri.parse('https://slack.com/api/chat.postMessage'),
              headers: {
                'Authorization': _bearer(config.values['SLACK_BOT_TOKEN'] ?? ''),
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'channel': channel,
                'thread_ts': timestamp,
                'text': reply,
                'unfurl_links': false,
              }),
            )
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200 ||
            (jsonDecode(response.body) as Json)['ok'] != true) {
          throw const CopilotFailure(
            'Slack could not deliver the reply. Check bot membership and chat:write permission.',
          );
        }
        await store.change(
          owner,
          (state) => state['slackStatus'] = {
            'message': 'Last reply delivered.',
            'at': now(),
            'status': 'delivered',
          },
        );
      } finally {
        client.close();
      }
    } catch (error) {
      // Never replay a failed external write: the owner can inspect the saved
      // conversation and retry explicitly without duplicate Slack side effects.
      await store.change(
        owner,
        (state) => state['slackStatus'] = {
          'message': error is CopilotFailure
              ? error.message
              : 'The last Slack event could not finish. Check the saved conversation before retrying.',
          'at': now(),
          'status': 'failed',
        },
      );
    }
  }

  bool _equal(String left, String right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var i = 0; i < left.length; i++) {
      difference |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
    }
    return difference == 0;
  }
}
