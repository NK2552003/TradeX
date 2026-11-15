import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tradex/core/config/customer_limitations.dart';
import 'package:tradex/core/config/customer_quota_usage.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/core/utils/app_visibility.dart';

import '../models/workspace.dart';
import 'copilot_api.dart';
import 'supabase_copilot_api.dart';

class CopilotController extends ChangeNotifier {
  static const Duration _basePollInterval = Duration(seconds: 60);
  static const int _maxPollFailures = 3;

  CopilotController({
    CopilotApi? api,
    CopilotWorkspace? initialState,
    bool autoLoad = true,
  }) : _autoLoad = autoLoad,
       api = api ?? createCopilotApi(),
       workspace =
           initialState ?? CopilotWorkspace.fromJson(initialWorkspace()) {
    _actor = SupabaseConfig.client?.auth.currentUser?.id;
    _auth = SupabaseConfig.client?.auth.onAuthStateChange.listen(
      (_) => _accountChanged(),
    );
    AppSession.instance.aiQueriesUsed.addListener(_onUsageChanged);
    if (autoLoad) {
      AppVisibility.instance.addListener(_onVisibilityChanged);
      unawaited(reload());
    }
  }
  final bool _autoLoad;
  final CopilotApi api;
  CopilotWorkspace workspace;
  bool loading = false;
  bool connected = false;
  bool generating = false;
  bool voiceBusy = false;
  bool quotaExceeded = false;
  int? quotaUsed;
  int? quotaLimit;
  String? error;
  String? activeThreadId;
  String specialistId = 'analyst';
  String? pageContextId;
  String streamingText = '';
  String? streamingMessageId;
  final List<Json> activity = [];
  Timer? _poll;
  StreamSubscription<dynamic>? _auth;
  String? _actor;
  int _epoch = 0;
  int _loadSequence = 0;
  int _pollFailures = 0;
  Future<String?>? _creatingThread;
  bool _disposed = false;

  int get accountEpoch => _epoch;
  int get effectiveAiQueriesUsed =>
      quotaUsed ?? AppSession.instance.aiQueriesUsed.value;
  int get effectiveAiQueriesLimit =>
      quotaLimit ?? CustomerLimitations.currentQuota.maxAiQueriesPerMonth;
  bool get isAiQuotaBlocked =>
      quotaExceeded ||
      CustomerLimitations.isAiQuotaExhausted(
        usedOverride: quotaUsed,
        limitOverride: quotaLimit,
      );
  bool get conversationLocked =>
      generating || voiceBusy || _creatingThread != null;

  void _onUsageChanged() {
    final used = AppSession.instance.aiQueriesUsed.value;
    if (quotaUsed != null && used > quotaUsed!) {
      quotaUsed = used;
    }
    quotaExceeded = CustomerLimitations.isAiQuotaExhausted(
      usedOverride: quotaUsed ?? used,
      limitOverride: quotaLimit,
    );
    _notify();
  }

  CopilotThread? get activeThread =>
      workspace.threads.where((t) => t.id == activeThreadId).firstOrNull;
  Specialist? get specialist =>
      workspace.specialists
          .where((s) => s.id == (activeThread?.specialistId ?? specialistId))
          .firstOrNull ??
      workspace.specialists.firstOrNull;
  bool get hasPendingReview =>
      activeThread?.approvals.any((a) => a['status'] == 'pending') ?? false;

  void _accountChanged() {
    final next = SupabaseConfig.client?.auth.currentUser?.id;
    if (next == _actor) return;
    _actor = next;
    _epoch++;
    workspace = CopilotWorkspace.fromJson(initialWorkspace());
    activeThreadId = null;
    pageContextId = null;
    generating = false;
    voiceBusy = false;
    _creatingThread = null;
    streamingText = '';
    streamingMessageId = null;
    activity.clear();
    connected = false;
    quotaExceeded = false;
    quotaUsed = null;
    quotaLimit = null;
    error = null;
    unawaited(reload());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _onVisibilityChanged(bool isVisible) {
    if (_disposed || !_autoLoad) return;
    if (!isVisible) {
      _poll?.cancel();
      _poll = null;
    } else {
      _pollFailures = 0;
      if (connected && !loading && !generating) {
        unawaited(reload(quiet: true));
      } else {
        _schedulePoll();
      }
    }
  }

  void _schedulePoll() {
    _poll?.cancel();
    _poll = null;
    if (_disposed || !_autoLoad || !AppVisibility.instance.isVisible) return;
    if (!connected || _pollFailures >= _maxPollFailures) return;
    final multiplier = _pollFailures == 0 ? 1 : (1 << _pollFailures);
    final delaySeconds = (_basePollInterval.inSeconds * multiplier).clamp(
      60,
      300,
    );
    _poll = Timer(Duration(seconds: delaySeconds), () {
      if (_disposed || !AppVisibility.instance.isVisible) return;
      if (!loading && !generating && connected) {
        unawaited(reload(quiet: true));
      } else {
        _schedulePoll();
      }
    });
  }

  Future<void> reload({bool quiet = false}) async {
    final epoch = _epoch;
    final sequence = ++_loadSequence;
    if (!quiet) {
      loading = true;
      _notify();
    }
    try {
      final state = await api.getWorkspace();
      if (_disposed || epoch != _epoch || sequence != _loadSequence) return;
      workspace = CopilotWorkspace.fromJson(state);
      connected = true;
      _pollFailures = 0;
      if (SupabaseConfig.isConfigured &&
          SupabaseConfig.client?.auth.currentUser != null) {
        try {
          await CustomerTierQuota.refreshPublishedCatalogue();
          final usage = await CustomerQuotaUsage.fetch();
          if (!_disposed && epoch == _epoch) {
            quotaUsed = usage.aiQueriesUsed;
            quotaLimit = usage.aiQueriesLimit;
            AppSession.instance.aiQueriesUsed.value = usage.aiQueriesUsed;
            quotaExceeded = CustomerLimitations.isAiQuotaExhausted(
              usedOverride: usage.aiQueriesUsed,
              limitOverride: usage.aiQueriesLimit,
            );
          }
        } catch (_) {}
      } else {
        quotaExceeded = CustomerLimitations.isAiQuotaExhausted();
      }
      if (!quiet) error = null;
      if (activeThreadId != null && activeThread == null) activeThreadId = null;
    } catch (failure) {
      if (_disposed || epoch != _epoch || sequence != _loadSequence) return;
      _pollFailures++;
      if (!quiet) {
        error = '$failure';
        connected = false;
      }
    } finally {
      if (epoch == _epoch && sequence == _loadSequence) {
        loading = false;
        _notify();
        _schedulePoll();
      }
    }
  }

  void selectThread(String id) {
    if (conversationLocked) return;
    activeThreadId = id;
    pageContextId = activeThread?.pageId;
    error = null;
    _notify();
  }

  void newConversation({String? specialist, String? pageId}) {
    if (conversationLocked) return;
    specialistId = specialist ?? this.specialist?.id ?? specialistId;
    activeThreadId = pageId == null
        ? null
        : workspace.threads
              .where(
                (t) => t.pageId == pageId && t.specialistId == specialistId,
              )
              .firstOrNull
              ?.id;
    pageContextId = pageId;
    error = null;
    _notify();
  }

  Future<String?> ensureThread() {
    if (activeThreadId != null) return Future.value(activeThreadId);
    return _creatingThread ??= _createThread();
  }

  Future<String?> _createThread() async {
    final epoch = _epoch;
    try {
      final chosen = specialist;
      if (chosen == null) return null;
      final created = await action({
        'action': 'thread.create',
        'specialistId': chosen.id,
        if (pageContextId != null) 'pageId': pageContextId,
      });
      if (created == null || epoch != _epoch || _disposed) return null;
      activeThreadId = textOf(created, 'id');
      _notify();
      return activeThreadId;
    } finally {
      if (epoch == _epoch) _creatingThread = null;
    }
  }

  Future<Json?> action(
    Json body, {
    bool refresh = true,
    bool reportError = true,
  }) async {
    final epoch = _epoch;
    try {
      final result = await api.action(body);
      if (_disposed || epoch != _epoch) return null;
      error = null;
      if (refresh) await reload(quiet: true);
      if (_disposed || epoch != _epoch) return null;
      return result;
    } catch (failure) {
      if (epoch == _epoch && reportError) {
        error = '$failure';
        _notify();
      }
      if (!reportError) rethrow;
      return null;
    }
  }

  Future<bool> sendPrompt(
    String prompt, {
    List<Json> attachments = const [],
    String mode = 'auto',
  }) async {
    if (generating || prompt.trim().isEmpty || hasPendingReview) return false;
    if (isAiQuotaBlocked) {
      quotaExceeded = true;
      error =
          'Monthly AI quota reached ($effectiveAiQueriesUsed/$effectiveAiQueriesLimit). Upgrade your plan to continue.';
      _notify();
      return false;
    }
    final epoch = _epoch;
    generating = true;
    _notify();
    final id = await ensureThread();
    if (_disposed || epoch != _epoch) return false;
    if (id == null) {
      generating = false;
      _notify();
      return false;
    }
    return _consume(id, {
      'prompt': prompt,
      'attachments': attachments,
      'mode': mode,
    });
  }

  Future<void> decide(Json approval, bool approve) async {
    if (generating || activeThreadId == null) return;
    await _consume(activeThreadId!, {
      'id': approval['id'],
      'approve': approve,
    }, approval: true);
  }

  Future<bool> _consume(String id, Json body, {bool approval = false}) async {
    final epoch = _epoch;
    generating = true;
    error = null;
    streamingText = '';
    streamingMessageId = null;
    activity.clear();
    var accepted = false;
    _notify();
    try {
      await for (final event in api.run(id, body, approval: approval)) {
        if (_disposed || epoch != _epoch) return false;
        switch (event['type']) {
          case 'started':
            accepted = true;
            streamingMessageId = textOf(event, 'messageId');
            await reload(quiet: true);
          case 'delta':
            streamingText += textOf(event, 'text');
          case 'activity':
            activity.add(event);
          case 'error':
            error = textOf(event, 'message');
        }
        _notify();
      }
    } catch (failure) {
      if (epoch == _epoch) error = '$failure';
    } finally {
      if (epoch == _epoch && !_disposed) {
        if (streamingMessageId != null && streamingText.isNotEmpty) {
          final thread = activeThread;
          final msg = thread?.messages
              .where((m) => m.id == streamingMessageId)
              .firstOrNull;
          if (msg != null) {
            msg.json['body'] = streamingText;
            if (msg.json['status'] == 'streaming') {
              msg.json['status'] = 'done';
            }
          }
        }
        generating = false;
        await reload(quiet: true);
        if (error != null && CustomerLimitations.isQuotaErrorMessage(error!)) {
          quotaExceeded = true;
          CustomerLimitations.markAiQuotaExhausted(limit: quotaLimit);
          quotaUsed = effectiveAiQueriesLimit;
          accepted = false;
        }
        streamingText = '';
        streamingMessageId = null;
        _notify();
      }
    }
    return accepted;
  }

  Future<void> stop() async {
    final id = activeThreadId;
    if (id == null) return;
    try {
      await api.stop(id);
    } catch (failure) {
      error = '$failure';
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _poll?.cancel();
    _auth?.cancel();
    AppSession.instance.aiQueriesUsed.removeListener(_onUsageChanged);
    if (_autoLoad) {
      AppVisibility.instance.removeListener(_onVisibilityChanged);
    }
    api.dispose();
    super.dispose();
  }
}

class CopilotScope {
  CopilotScope._();
  static CopilotController? _repository;
  static CopilotController get repository =>
      _repository ??= CopilotController();
  static set repository(CopilotController repository) =>
      _repository = repository;
}
