import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tradex/core/config/supabase_config.dart';

import '../models/workspace.dart';
import 'copilot_api.dart';

class CopilotController extends ChangeNotifier {
  CopilotController({
    CopilotApi? api,
    CopilotWorkspace? initialState,
    bool autoLoad = true,
  }) : api = api ?? CopilotApi(),
       workspace =
           initialState ?? CopilotWorkspace.fromJson(initialWorkspace()) {
    _actor = SupabaseConfig.client?.auth.currentUser?.id;
    _auth = SupabaseConfig.client?.auth.onAuthStateChange.listen(
      (_) => _accountChanged(),
    );
    if (autoLoad) unawaited(reload());
    if (autoLoad) {
      _poll = Timer.periodic(const Duration(seconds: 15), (_) {
        if (!loading && !generating && connected) {
          unawaited(reload(quiet: true));
        }
      });
    }
  }
  final CopilotApi api;
  CopilotWorkspace workspace;
  bool loading = false;
  bool connected = false;
  bool generating = false;
  bool voiceBusy = false;
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
  Future<String?>? _creatingThread;
  bool _disposed = false;

  int get accountEpoch => _epoch;
  bool get conversationLocked =>
      generating || voiceBusy || _creatingThread != null;

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
    error = null;
    unawaited(reload());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
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
      if (!quiet) error = null;
      if (activeThreadId != null && activeThread == null) activeThreadId = null;
    } catch (failure) {
      if (_disposed || epoch != _epoch || sequence != _loadSequence) return;
      if (!quiet) {
        error = '$failure';
        connected = false;
      }
    } finally {
      if (epoch == _epoch && sequence == _loadSequence) {
        loading = false;
        _notify();
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
        generating = false;
        await reload(quiet: true);
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
