import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:tradex/core/config/customer_limitations.dart';
import 'package:tradex/core/config/env_config.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/core/markdown_kit/perplexity_parser.dart';

import '../models/research_router.dart';
import '../models/trader_skill.dart';
import '../models/workspace.dart';
import '../models/workspace_errors.dart';
import '../models/workspace_mutations.dart';
import 'cloud_workspace_store.dart';
import 'copilot_api.dart';

CopilotApi createCopilotApi() {
  final endpoint = EnvConfig.copilotApiUrl.trim();
  return endpoint.isEmpty
      ? SupabaseCopilotApi()
      : CopilotApi(baseUri: Uri.parse(endpoint));
}

/// Hosted chat uses the existing authenticated, quota-enforcing Edge gateway.
/// Provider credentials are read only by the Edge Function from its secrets.
class SupabaseCopilotApi extends CopilotApi {
  SupabaseCopilotApi({
    http.Client? client,
    CloudWorkspaceStore Function()? store,
  }) : _http = client ?? http.Client(),
       _storeOverride = store;
  final http.Client _http;
  final Map<String, Completer<void>> _stops = {};
  final CloudWorkspaceStore Function()? _storeOverride;

  CloudWorkspaceStore session() {
    if (_storeOverride != null) return _storeOverride();
    final session = SupabaseConfig.client?.auth.currentSession;
    if (session == null) {
      throw const CopilotFailure(
        'Sign in to connect your copilot workspace.',
        401,
      );
    }
    return CloudWorkspaceStore(
      url: SupabaseConfig.supabaseUrl,
      key: SupabaseConfig.supabaseAnonKey,
      token: session.accessToken,
      owner: session.user.id,
      client: _http,
    );
  }

  static const capabilities = <String, dynamic>{
    'backend': 'supabase',
    'chat': true,
    'voice': true,
    'schedules': false,
    'computer': false,
    'slack': false,
    'apps': false,
    'research': true,
    'attachments': true,
  };

  @override
  Future<Json> getWorkspace() async {
    final store = session();
    final state = await store.read();
    // A tab closed during a call must not leave its thread locked forever.
    final cutoff = DateTime.now().toUtc().subtract(const Duration(minutes: 4));
    if (records(state['threads']).any(
      (thread) =>
          thread['status'] == 'running' &&
          (DateTime.tryParse(textOf(thread, 'updatedAt'))?.isBefore(cutoff) ??
              true),
    )) {
      await store.change((latest) {
        for (final thread in latest['threads'] as List) {
          if (thread['status'] == 'running' &&
              (DateTime.tryParse(
                    textOf(thread, 'updatedAt'),
                  )?.isBefore(cutoff) ??
                  true)) {
            thread['status'] = 'interrupted';
            for (final message in thread['messages'] as List) {
              if (message['status'] == 'streaming') {
                message['status'] = 'interrupted';
              }
            }
          }
        }
        return {};
      });
      return {...await store.read(), 'setup': capabilities};
    }
    return {...state, 'setup': capabilities};
  }

  @override
  Future<Json> action(Json body) async {
    final action = textOf(body, 'action');
    if (action.startsWith('schedule.') || action.startsWith('connection.')) {
      throw const CopilotFailure(
        'This integration requires a hosted copilot worker.',
        501,
      );
    }
    return session().change((state) => WorkspaceMutations.apply(state, body));
  }

  @override
  Stream<Json> run(String threadId, Json body, {bool approval = false}) async* {
    if (approval) {
      throw const CopilotFailure(
        'Approvals require a hosted copilot worker.',
        501,
      );
    }
    final store = session();
    final prompt = requiredText(body, 'prompt', max: 40000);
    final messageId = newId();
    final input = await store.change((state) {
      if ((state['settings'] as Json)['paused'] == true) {
        throw const CopilotFailure(
          'Resume your copilot in Settings before sending a message.',
        );
      }
      final thread = recordById(state, 'threads', threadId);
      if (thread['status'] == 'running') {
        throw const CopilotFailure(
          'This conversation is already responding.',
          409,
        );
      }
      final specialist = recordById(
        state,
        'specialists',
        thread['specialistId'] as String,
      );
      final mode = textOf(body, 'mode', 'auto');
      final allowWebSearch =
          (state['settings'] as Json)['research'] == true &&
          specialist['research'] == true;
      if (mode != 'auto' && !allowWebSearch) {
        throw const CopilotFailure(
          'Enable research for this workspace and specialist to use web search.',
          403,
        );
      }
      final settings = state['settings'] as Json;
      final autoAttachContext = settings['autoAttachContext'] != false;
      final responseStyle = textOf(settings, 'responseStyle', 'balanced');
      final citationsStyle = textOf(settings, 'citationsStyle', 'inline');
      final requireToolApproval = settings['requireToolApproval'] != false;
      final allowed = List<String>.from(specialist['spaceIds'] ?? []);
      final pages = records(
        state['pages'],
      ).where((p) => allowed.contains(p['spaceId'])).toList();
      final contextPage = !autoAttachContext || thread['pageId'] == null
          ? null
          : pages.where((p) => p['id'] == thread['pageId']).firstOrNull;
      if (autoAttachContext &&
          thread['pageId'] != null &&
          contextPage == null) {
        throw const CopilotFailure(
          'This specialist no longer has access to the selected page.',
          403,
        );
      }
      final messages = records(thread['messages'])
          .where((m) => m['status'] == 'complete')
          .map((m) => {'role': m['role'], 'content': m['body']})
          .toList();
      final instructions = StringBuffer(textOf(specialist, 'instructions'))
        ..write(
          '\nAnswer using supplied context. Use web search when available for current information and cite sources. Never claim to have searched without tool results. Report code execution only when the Python tool returns results. Do not claim to schedule work or save documents. Offer document drafts in your reply.\nPresent rich Perplexity-style structured research using cited [Source](url) links, real source URLs/websiteUrl/imageUrl fields so logos and images render, fenced visual cards (company, person, news, links, video, market_pulse, earnings_calendar, scenarios, backtest, portfolio, filing, wiki, risk_plan, workflow, compare, timeline, setup, verdict, factbox, faq, checklist, quote, earnings, financials, macro, ratings, screener, sentiment, product, media, formula, research_steps, chart, kpi), and a trailing followups JSON array.',
        );
      if (responseStyle == 'concise') {
        instructions.write(
          '\nResponse style: CONCISE. Lead immediately with key metrics/answer in 2-4 crisp bullet points and compact visual cards; avoid filler.',
        );
      } else if (responseStyle == 'detailed') {
        instructions.write(
          '\nResponse style: DETAILED. Provide institutional-grade multi-section analysis, thorough breakdown tables, bull/bear scenarios, risks, and rich visual cards.',
        );
      }
      if (citationsStyle == 'footnotes') {
        instructions.write(
          '\nCitations style: FOOTNOTES. Reference claims inline using numbered markers like [1], [2] and finish with a numbered Sources list linking markdown URLs.',
        );
      } else {
        instructions.write(
          '\nCitations style: INLINE. Embed descriptive markdown links [Source](url) directly next to the facts they support.',
        );
      }
      if (requireToolApproval) {
        instructions.write(
          '\nSafety preference: Require user approval before suggesting any permanent workspace, note, journal, or strategy save.',
        );
      }
      if (specialist['memory'] == true && settings['memory'] == true) {
        instructions.write(
          '\nUser preferences: ${jsonEncode(records(state['memories']).map((m) => m['text']).toList())}',
        );
      }
      if (contextPage != null) {
        instructions.write(
          '\nSelected page: ${contextPage['title']}\n${contextPage['body']}',
        );
      }
      instructions.write('\n${ResearchRouter.select(prompt).instructions}');
      final system = instructions.toString();
      if (system.length > 12000) {
        throw const CopilotFailure(
          'This page and memory context is too large. Shorten it before sending.',
        );
      }
      final stamp = now();
      final rawAttachments = records(body['attachments']);
      final savedAttachments = <Json>[
        for (final att in rawAttachments) _attachmentSummary(att),
      ];
      final gatewayAttachments = <Json>[
        for (final att in rawAttachments) _gatewayAttachment(att),
      ];
      (thread['messages'] as List).addAll([
        {
          'id': newId(),
          'role': 'user',
          'body': prompt,
          if (savedAttachments.isNotEmpty) 'attachments': savedAttachments,
          'status': 'complete',
          'createdAt': stamp,
        },
        {
          'id': messageId,
          'role': 'assistant',
          'body': '',
          'status': 'streaming',
          'createdAt': stamp,
        },
      ]);
      thread['status'] = 'running';
      thread['updatedAt'] = stamp;
      if (thread['title'] == 'New conversation') {
        thread['title'] = prompt.length > 80 ? prompt.substring(0, 80) : prompt;
      }
      return {
        'prompt': prompt,
        'kind': 'completion',
        'system_prompt': system,
        'trader_skill_context': TraderSkill.instructions(prompt),
        if (specialist['code'] == true)
          'trader_toolkit': TraderSkill.fromCommand(prompt) == null
              ? 'auto'
              : 'selected',
        'mode': mode,
        if (textOf(body, 'focus', 'all') != 'all' &&
            textOf(body, 'focus').isNotEmpty)
          'focus': textOf(body, 'focus'),
        'allow_web_search': allowWebSearch,
        'response_style': responseStyle,
        'citations_style': citationsStyle,
        'max_tokens': responseStyle == 'concise' ? 1800 : 4096,
        'attachments': gatewayAttachments,
        'messages': messages
            .skip(messages.length > 40 ? messages.length - 40 : 0)
            .toList(),
      };
    });
    final runKey = '${store.owner}:$threadId';
    final stopped = Completer<void>();
    _stops[runKey] = stopped;
    yield {'type': 'started', 'messageId': messageId};
    try {
      final pending = _http
          .post(
            Uri.parse('${store.url}/functions/v1/ai-gateway'),
            headers: {
              'Authorization': 'Bearer ${store.token}',
              'apikey': store.key,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(input),
          )
          .timeout(const Duration(seconds: 170));
      final response = await Future.any<http.Response?>([
        pending,
        stopped.future.then((_) => null),
      ]);
      if (response == null) {
        yield {'type': 'done'};
        return;
      }
      final result = jsonDecode(response.body) as Json;
      if (response.statusCode >= 400) {
        final errMsg = textOf(
          result,
          'error',
          textOf(result, 'message', 'AI request failed.'),
        );
        if (response.statusCode == 429 ||
            CustomerLimitations.isQuotaErrorMessage(errMsg)) {
          CustomerLimitations.markAiQuotaExhausted();
        }
        throw CopilotFailure(errMsg, response.statusCode);
      }
      final usage = result['usage'];
      if (usage is Map && usage['ai_queries_used'] is num) {
        AppSession.instance.aiQueriesUsed.value =
            (usage['ai_queries_used'] as num).toInt();
      }
      final answer = textOf(result, 'text');
      if (answer.trim().isEmpty) {
        throw const CopilotFailure(
          'The AI service returned an empty response.',
          502,
        );
      }
      final serverSources = records(result['sources']);
      final serverSteps =
          (result['steps'] as List?)
              ?.map((e) => '$e'.trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const <String>[];
      final rawFocus = textOf(result, 'focus', textOf(input, 'focus'));
      final normalizedFocus = rawFocus.isEmpty || rawFocus == 'all'
          ? ''
          : rawFocus;
      final parsedMeta = PerplexityAnswerParser.parse(
        answer,
        structuredSources:
            <({String url, String title, String domain, String snippet})>[
              for (final s in serverSources)
                (
                  url: textOf(s, 'url'),
                  title: textOf(s, 'title'),
                  domain: textOf(s, 'domain'),
                  snippet: textOf(s, 'snippet'),
                ),
            ],
        externalSteps: serverSteps,
        focus: normalizedFocus,
      );
      final normalizedSources = <Json>[
        for (final s in parsedMeta.sources)
          <String, dynamic>{
            'url': s.url,
            if (s.title.isNotEmpty) 'title': s.title,
            if (s.domain.isNotEmpty) 'domain': s.domain,
            if (s.snippet.isNotEmpty) 'snippet': s.snippet,
            if (s.publisher.isNotEmpty) 'publisher': s.publisher,
            if (s.publishedAt.isNotEmpty) 'publishedAt': s.publishedAt,
          },
      ];
      final rawMode = textOf(result, 'mode', textOf(input, 'mode'));
      final normalizedMode = rawMode == 'auto' ? '' : rawMode;
      final saved = await _finish(
        store,
        threadId,
        messageId,
        answer,
        'complete',
        sources: normalizedSources,
        research: result['research'] is Map
            ? Map<String, dynamic>.from(result['research'] as Map)
            : null,
        mode: normalizedMode,
        steps: serverSteps,
        focus: normalizedFocus,
      );
      if (saved) {
        for (final chunk in _streamChunks(answer)) {
          yield {'type': 'delta', 'text': chunk};
        }
      }
      yield {'type': 'done'};
    } catch (error) {
      final message = error is CopilotFailure
          ? error.message
          : 'The AI service could not finish. Reconnect to check the saved conversation.';
      await _finish(store, threadId, messageId, message, 'error');
      yield {'type': 'error', 'message': message};
    } finally {
      if (identical(_stops[runKey], stopped)) _stops.remove(runKey);
    }
  }

  static Json _gatewayAttachment(Json att) {
    final type = textOf(att, 'type');
    if (type == 'input_image') {
      return {'type': 'input_image', 'image_url': textOf(att, 'image_url')};
    }
    if (type == 'input_file') {
      return {
        'type': 'input_file',
        'filename': textOf(att, 'filename'),
        'file_data': textOf(att, 'file_data'),
      };
    }
    return {'type': 'input_text', 'text': textOf(att, 'text')};
  }

  static Json _attachmentSummary(Json att) {
    final ui = att['_ui'];
    if (ui is Map) {
      return Map<String, dynamic>.from(ui);
    }
    final type = textOf(att, 'type');
    if (type == 'input_image') {
      final url = textOf(att, 'image_url');
      return {
        'name': textOf(att, 'filename', 'Image'),
        'kind': 'image',
        if (url.isNotEmpty) 'previewUrl': url,
      };
    }
    if (type == 'input_file') {
      return {
        'name': textOf(att, 'filename', 'Document.pdf'),
        'kind': 'pdf',
        'mimeType': 'application/pdf',
      };
    }
    return {
      'name': textOf(att, 'filename', 'Attachment'),
      'kind': 'text',
    };
  }

  static Iterable<String> _streamChunks(String text) sync* {
    final matches = RegExp(r'\S+\s*').allMatches(text);
    if (matches.isEmpty) {
      if (text.isNotEmpty) yield text;
      return;
    }
    for (final match in matches) {
      yield match.group(0)!;
    }
  }

  Future<bool> _finish(
    CloudWorkspaceStore store,
    String id,
    String messageId,
    String text,
    String status, {
    List<Json> sources = const <Json>[],
    String mode = '',
    List<String> steps = const <String>[],
    String focus = '',
    Json? research,
  }) async {
    final result = await store.change((state) {
      final thread = records(
        state['threads'],
      ).where((t) => t['id'] == id).firstOrNull;
      if (thread == null || thread['status'] != 'running') {
        return {'saved': false};
      }
      final live = recordById(state, 'threads', id);
      final message = (live['messages'] as List)
          .where((m) => m['id'] == messageId)
          .firstOrNull;
      if (message == null || message['status'] != 'streaming') {
        return {'saved': false};
      }
      message['body'] = text;
      if (research != null) message['research'] = research;
      message['status'] = status;
      if (sources.isNotEmpty) {
        message['sources'] = sources;
      }
      if (mode.isNotEmpty) {
        message['mode'] = mode;
      }
      if (steps.isNotEmpty) {
        message['steps'] = steps;
      }
      if (focus.isNotEmpty) {
        message['focus'] = focus;
      }
      live['status'] = status == 'complete' ? 'idle' : 'error';
      live['updatedAt'] = now();
      return {'saved': true};
    });
    return result['saved'] == true;
  }

  @override
  Future<Json> stop(String id) async {
    final store = session();
    final result = await store.change((state) {
      final thread = recordById(state, 'threads', id);
      thread['status'] = 'stopped';
      for (final message in thread['messages'] as List) {
        if (message['status'] == 'streaming') message['status'] = 'stopped';
      }
      return {'stopped': true};
    });
    final pending = _stops['${store.owner}:$id'];
    if (pending != null && !pending.isCompleted) pending.complete();
    return result;
  }

  @override
  Future<Json> computer(
    String specialist, {
    String? action,
    Json input = const {},
  }) async => throw const CopilotFailure(
    'Computer access requires a hosted copilot worker.',
    501,
  );

  @override
  Future<Uint8List> artifact(String threadId, Json artifact) async =>
      throw const CopilotFailure(
        'Generated files require a hosted copilot worker.',
        501,
      );

  @override
  void dispose() {
    for (final pending in _stops.values) {
      if (!pending.isCompleted) pending.complete();
    }
    _http.close();
    super.dispose();
  }
}
