import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_seed_data.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/features/strategies/data/strategies_repository.dart';

/// In-memory state for the AI Assistant feature.
///
/// A plain [ChangeNotifier] (no external state package): views `addListener` /
/// `removeListener` → `setState`, exactly like the community and messages
/// repositories. All content comes from [AiSeedData]; nothing is hardcoded in
/// the widgets.
///
/// The copilot's replies are simulated with a staged [Timer] delay so the UX
/// matches a streaming assistant while staying backend-ready — every mutation
/// that would hit a server is marked with `/// @backend`.
///
/// **Create-from-AI** routes through the real feature repositories so a
/// generated record actually lands in Notes / Journal / Strategies (via their
/// global `*RepositoryScope` singletons) or the Community feed (via the injected
/// [CommunityRepository], since community has no global scope). Note / journal /
/// strategy creations return an [AppLinkRef] the shell can open; posts have no
/// Writing-Desk destination and return `null`.
class AiAssistantRepository extends ChangeNotifier {
  AiAssistantRepository({
    CommunityRepository? communityRepository,
    List<AiThread>? seedThreads,
  })  : _community = communityRepository,
        _threads = seedThreads ?? AiSeedData.threads() {
    _threads.sort(_threadOrder);
    if (_threads.isEmpty) _threads.add(_blankThread(AiPersona.swing));
    _activeThreadId = _threads.first.id;
  }

  /// Injected so AI-created community posts land in the real feed. When null,
  /// the post target is unavailable (silently skipped).
  final CommunityRepository? _community;

  final List<AiThread> _threads;
  late String _activeThreadId;

  bool _generating = false;
  Timer? _replyTimer;

  /// Monotonic token that invalidates a scheduled reply after stop / retry.
  int _replySeq = 0;
  bool _disposed = false;

  /// Suggested "create from this" actions keyed by the assistant message id
  /// they hang off. Memoized lazily for seeded threads.
  final Map<String, List<AiSuggestedAction>> _actions =
      <String, List<AiSuggestedAction>>{};

  // -------------------------------------------------------------------------
  // Read API
  // -------------------------------------------------------------------------

  /// Threads ordered pinned-first, then most-recently updated.
  List<AiThread> get threads => List<AiThread>.unmodifiable(_threads);

  AiThread get activeThread => _threads.firstWhere(
        (AiThread t) => t.id == _activeThreadId,
        orElse: () => _threads.first,
      );

  String get activeThreadId => _activeThreadId;

  List<AppAiMessage> get messages => activeThread.messages;

  AiPersona get persona => activeThread.persona;

  bool get generating => _generating;

  bool get isActiveEmpty => activeThread.messages.isEmpty;

  /// Seed content passthroughs — kept out of the widgets.
  List<AiCapability> get capabilities => AiSeedData.capabilities();
  List<AppAiPrompt> get quickPrompts => AiSeedData.quickPrompts();
  Map<String, List<AppAiPrompt>> get promptLibrary => AiSeedData.promptLibrary();
  List<AiChartSetup> get chartSetups => AiSeedData.chartSetups();
  List<AppAiInsight> get insights => AiSeedData.insights();

  AiChartSetup? setupById(String id) {
    for (final AiChartSetup s in AiSeedData.chartSetups()) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The create actions to surface under the latest assistant answer in the
  /// active thread. Empty while generating or before the first answer.
  List<AiSuggestedAction> get latestActions {
    final List<AppAiMessage> msgs = activeThread.messages;
    for (int i = msgs.length - 1; i >= 0; i--) {
      final AppAiMessage m = msgs[i];
      if (m.pending) return const <AiSuggestedAction>[];
      if (m.role == AppAiRole.assistant) {
        final List<AiSuggestedAction>? recorded = _actions[m.id];
        if (recorded != null) return recorded;
        // Derive lazily for seeded threads from the preceding user turn.
        final String? userText = _precedingUserText(msgs, i);
        final List<AiSuggestedAction> derived = userText == null
            ? const <AiSuggestedAction>[]
            : AiSeedData.replyFor(userText, activeThread.persona).actions;
        _actions[m.id] = derived;
        return derived;
      }
    }
    return const <AiSuggestedAction>[];
  }

  // -------------------------------------------------------------------------
  // Conversation mutations
  // -------------------------------------------------------------------------

  void selectThread(String id) {
    if (_activeThreadId == id) return;
    if (!_threads.any((AiThread t) => t.id == id)) return;
    _replyTimer?.cancel();
    _replySeq++;
    _generating = false;
    _activeThreadId = id;
    _notify();
  }

  /// Starts a fresh conversation and makes it active.
  AiThread newThread({AiPersona persona = AiPersona.swing}) {
    _replyTimer?.cancel();
    _replySeq++;
    _generating = false;
    final AiThread t = _blankThread(persona);
    _threads.insert(0, t);
    _activeThreadId = t.id;
    _notify();
    return t;
  }

  /// Changes the persona of the active thread (affects future replies).
  void setPersona(AiPersona persona) {
    final AiThread t = activeThread;
    if (t.persona == persona) return;
    _replace(t.copyWith(persona: persona));
    _notify();
  }

  void togglePin(String id) {
    final int idx = _threads.indexWhere((AiThread t) => t.id == id);
    if (idx < 0) return;
    _threads[idx] = _threads[idx].copyWith(pinned: !_threads[idx].pinned);
    _threads.sort(_threadOrder);
    _notify();
  }

  void renameThread(String id, String title) {
    final String clean = title.trim();
    if (clean.isEmpty) return;
    final int idx = _threads.indexWhere((AiThread t) => t.id == id);
    if (idx < 0) return;
    _threads[idx] = _threads[idx].copyWith(title: clean);
    _notify();
  }

  void deleteThread(String id) {
    final int idx = _threads.indexWhere((AiThread t) => t.id == id);
    if (idx < 0) return;
    _threads.removeAt(idx);
    if (_threads.isEmpty) _threads.add(_blankThread(AiPersona.swing));
    if (_activeThreadId == id) {
      _threads.sort(_threadOrder);
      _activeThreadId = _threads.first.id;
    }
    _notify();
  }

  // -------------------------------------------------------------------------
  // Chat
  // -------------------------------------------------------------------------

  /// Appends the user's turn and schedules a simulated assistant reply.
  ///
  /// @backend POST /ai/threads/{id}/messages — stream the assistant response.
  void sendPrompt(String rawText, {AiPersona? persona}) {
    final String text = rawText.trim();
    if (text.isEmpty) return;

    final AiThread thread = activeThread;
    final DateTime now = DateTime.now();
    final AiPersona effective = persona ?? thread.persona;
    final int stamp = now.microsecondsSinceEpoch;

    final AppAiMessage userMsg = AppAiMessage(
      id: 'm_${stamp}_u',
      role: AppAiRole.user,
      body: text,
      sentAt: now,
    );
    final String pendingId = 'm_${stamp}_a';
    final AppAiMessage pending = AppAiMessage(
      id: pendingId,
      role: AppAiRole.assistant,
      body: '',
      pending: true,
      sentAt: now,
    );

    _replace(
      thread.copyWith(
        persona: effective,
        messages: <AppAiMessage>[...thread.messages, userMsg, pending],
        updatedAt: now,
        // Title the thread from the first user message.
        title: thread.messages.isEmpty ? _titleFrom(text) : null,
      ),
    );
    _generating = true;
    _notify();

    _scheduleReply(thread.id, pendingId, text, effective);
  }

  /// Stops the in-flight generation and drops the pending bubble.
  void stop() {
    _replyTimer?.cancel();
    _replySeq++;
    final AiThread thread = activeThread;
    if (thread.messages.any((AppAiMessage m) => m.pending)) {
      _replace(
        thread.copyWith(
          messages: thread.messages
              .where((AppAiMessage m) => !m.pending)
              .toList(growable: false),
        ),
      );
    }
    _generating = false;
    _notify();
  }

  /// Regenerates the answer for [assistantMessage] using its preceding prompt.
  ///
  /// @backend POST /ai/messages/{id}/regenerate
  void regenerate(AppAiMessage assistantMessage) {
    if (assistantMessage.role != AppAiRole.assistant) return;
    final AiThread thread = activeThread;
    final int idx =
        thread.messages.indexWhere((AppAiMessage m) => m.id == assistantMessage.id);
    if (idx <= 0) return;

    int u = idx - 1;
    while (u >= 0 && thread.messages[u].role != AppAiRole.user) {
      u--;
    }
    if (u < 0) return;

    final String userText = thread.messages[u].body;
    final List<AppAiMessage> kept = thread.messages.sublist(0, u + 1);
    final String pendingId = 'm_${DateTime.now().microsecondsSinceEpoch}_a';
    final AppAiMessage pending = AppAiMessage(
      id: pendingId,
      role: AppAiRole.assistant,
      body: '',
      pending: true,
      sentAt: DateTime.now(),
    );
    _replace(
      thread.copyWith(
        messages: <AppAiMessage>[...kept, pending],
        updatedAt: DateTime.now(),
      ),
    );
    _generating = true;
    _notify();
    _scheduleReply(thread.id, pendingId, userText, thread.persona);
  }

  void _scheduleReply(
    String threadId,
    String pendingId,
    String userText,
    AiPersona persona,
  ) {
    _replyTimer?.cancel();
    final int seq = ++_replySeq;
    _replyTimer = Timer(const Duration(milliseconds: 1150), () {
      if (_disposed || seq != _replySeq) return;
      final ({
        String body,
        List<String> sources,
        List<AiSuggestedAction> actions,
      }) reply = AiSeedData.replyFor(userText, persona);
      final String body =
          '${persona.opener}\n\n${reply.body}\n\n${persona.emphasis}';
      _finalizePending(threadId, pendingId, body, reply.sources, reply.actions);
    });
  }

  void _finalizePending(
    String threadId,
    String pendingId,
    String body,
    List<String> sources,
    List<AiSuggestedAction> actions,
  ) {
    final int idx = _threads.indexWhere((AiThread t) => t.id == threadId);
    if (idx < 0) return;
    final AiThread thread = _threads[idx];
    final List<AppAiMessage> msgs = thread.messages
        .map(
          (AppAiMessage m) => m.id == pendingId
              ? AppAiMessage(
                  id: m.id,
                  role: AppAiRole.assistant,
                  body: body,
                  sentAt: DateTime.now(),
                  sources: sources,
                )
              : m,
        )
        .toList(growable: false);
    _threads[idx] = thread.copyWith(messages: msgs, updatedAt: DateTime.now());
    _actions[pendingId] = actions;
    _generating = false;
    _notify();
  }

  // -------------------------------------------------------------------------
  // Create anything from AI
  // -------------------------------------------------------------------------

  /// Turns a previewed [draft] into a real record and returns a link to it
  /// (null for community posts, which have no Writing-Desk destination).
  Future<AppLinkRef?> create(AiCreateDraft draft) async {
    switch (draft.target) {
      case AiCreateTarget.note:
        return _createNote(draft);
      case AiCreateTarget.journal:
        return _createTrade(draft);
      case AiCreateTarget.strategy:
        return _createStrategy(draft);
      case AiCreateTarget.post:
        _createPost(draft);
        return null;
      case AiCreateTarget.chartAnalysis:
        // Chart analysis exports commit through the concrete targets above.
        return null;
    }
  }

  /// @backend POST /notes
  Future<AppLinkRef> _createNote(AiCreateDraft draft) async {
    final AppNote note = await NotesRepositoryScope.repository.create(
      AppNote(
        id: 'note_ai_${_uid()}',
        title: draft.title,
        content: draft.body,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        noteType: AppNoteType.analysis,
        tags: draft.tags,
        linkedTickers: draft.tickers,
        isFavorite: true,
      ),
    );
    return _refFor(
      AppLinkKind.note,
      note.id,
      note.title,
      subtitle: 'AI-generated note',
    );
  }

  /// @backend POST /journal/trades
  Future<AppLinkRef> _createTrade(AiCreateDraft draft) async {
    final AiChartSetup? s = draft.setup;
    final String ticker = s?.symbol ??
        (draft.tickers.isNotEmpty ? draft.tickers.first : 'NIFTY50');
    final AppTrade trade = await JournalRepositoryScope.repository.create(
      AppTrade(
        id: 'trade_ai_${_uid()}',
        ticker: ticker,
        side: (s?.direction ?? AiTradeDirection.long).side,
        openedAt: DateTime.now(),
        entry: s?.entry ?? 0,
        exit: null,
        stopLoss: s?.stopLoss,
        target: s?.target1,
        size: 50,
        rMultiple: s?.rrRatio,
        title: draft.title,
        content: draft.body,
        strategy: s?.pattern,
        tags: draft.tags,
      ),
    );
    final String title = trade.title.isEmpty ? '$ticker trade' : trade.title;
    return _refFor(
      AppLinkKind.journal,
      trade.id,
      title,
      subtitle: 'AI trade idea',
    );
  }

  /// @backend POST /strategies
  Future<AppLinkRef> _createStrategy(AiCreateDraft draft) async {
    final AppStrategy strat = await StrategiesRepositoryScope.repository.create(
      AppStrategy(
        id: 'strat_ai_${_uid()}',
        name: draft.title,
        summary: _firstLine(draft.body),
        content: draft.body,
        status: AppStrategyStatus.draft,
        createdAt: DateTime.now(),
        tags: draft.tags,
        linkedTickers: draft.tickers,
      ),
    );
    return _refFor(
      AppLinkKind.strategy,
      strat.id,
      strat.name,
      subtitle: 'AI playbook',
    );
  }

  /// @backend POST /community/posts
  void _createPost(AiCreateDraft draft) {
    final CommunityRepository? community = _community;
    if (community == null) return;
    final AiChartSetup? s = draft.setup;
    community.createPost(
      body: draft.body,
      author: community.currentAuthor,
      tickers: draft.tickers,
      tags: draft.tags.isEmpty ? const <String>['AI Setup'] : draft.tags,
      tradeSetup: s == null
          ? null
          : CommunityTradeSetup(
              ticker: s.symbol,
              side: s.direction.label.toUpperCase(),
              entry: s.entry.toStringAsFixed(2),
              stopLoss: s.stopLoss.toStringAsFixed(2),
              target: s.target1.toStringAsFixed(2),
              rMultiple: '${s.rrRatio.toStringAsFixed(1)}R',
            ),
    );
  }

  // -------------------------------------------------------------------------
  // Draft builders (used by the create hub + chart analyzer)
  // -------------------------------------------------------------------------

  /// Builds a preview draft for [target] from an analyzed [setup].
  AiCreateDraft draftFromSetup(AiChartSetup setup, AiCreateTarget target) {
    switch (target) {
      case AiCreateTarget.strategy:
        return AiCreateDraft(
          target: target,
          title: '${setup.symbol} ${setup.pattern} Playbook',
          body: AiSeedData.strategyBodyForSetup(setup),
          tickers: <String>[setup.symbol],
          tags: const <String>['AI', 'Playbook'],
          setup: setup,
        );
      case AiCreateTarget.journal:
        return AiCreateDraft(
          target: target,
          title: '${setup.symbol} ${setup.pattern}',
          body: setup.rationale,
          tickers: <String>[setup.symbol],
          tags: const <String>['AI'],
          setup: setup,
        );
      case AiCreateTarget.post:
        return AiCreateDraft(
          target: target,
          title: '${setup.symbol} setup',
          body: AiSeedData.postBodyForSetup(setup),
          tickers: <String>[setup.symbol],
          tags: <String>['AI Setup', setup.direction.label],
          setup: setup,
        );
      case AiCreateTarget.note:
      case AiCreateTarget.chartAnalysis:
        return AiCreateDraft(
          target: AiCreateTarget.note,
          title: '${setup.symbol} ${setup.pattern} Analysis',
          body: AiSeedData.noteBodyForSetup(setup),
          tickers: <String>[setup.symbol],
          tags: const <String>['AI', 'Analysis'],
          setup: setup,
        );
    }
  }

  /// Builds a preview draft for [target] from the current chat context (or a
  /// generic scaffold when the thread is empty).
  AiCreateDraft draftFromChat(AiCreateTarget target) {
    final String source = _lastAssistantBody() ?? '';
    final String symbol =
        AiSeedData.symbolFrom(source.isEmpty ? activeThread.title : source);
    final String title = switch (target) {
      AiCreateTarget.note => '$symbol research note',
      AiCreateTarget.journal => '$symbol trade idea',
      AiCreateTarget.strategy => '$symbol playbook',
      AiCreateTarget.post => '$symbol update',
      AiCreateTarget.chartAnalysis => '$symbol analysis',
    };
    final String body = source.isNotEmpty
        ? source
        : 'A ${target.label.toLowerCase()} on $symbol generated by the TradeX '
            'AI copilot. Edit the details before saving.';
    return AiCreateDraft(
      target: target == AiCreateTarget.chartAnalysis ? AiCreateTarget.note : target,
      title: title,
      body: body,
      tickers: <String>[symbol],
      tags: const <String>['AI'],
    );
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  static int _threadOrder(AiThread a, AiThread b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    return b.updatedAt.compareTo(a.updatedAt);
  }

  AiThread _blankThread(AiPersona persona) => AiThread(
        id: 'thread_${DateTime.now().microsecondsSinceEpoch}',
        title: 'New chat',
        persona: persona,
        messages: const <AppAiMessage>[],
        updatedAt: DateTime.now(),
      );

  void _replace(AiThread updated) {
    final int idx = _threads.indexWhere((AiThread t) => t.id == updated.id);
    if (idx < 0) return;
    _threads[idx] = updated;
  }

  String? _lastAssistantBody() {
    final List<AppAiMessage> msgs = activeThread.messages;
    for (int i = msgs.length - 1; i >= 0; i--) {
      if (msgs[i].role == AppAiRole.assistant && !msgs[i].pending) {
        return msgs[i].body;
      }
    }
    return null;
  }

  static String? _precedingUserText(List<AppAiMessage> msgs, int assistantIdx) {
    for (int i = assistantIdx - 1; i >= 0; i--) {
      if (msgs[i].role == AppAiRole.user) return msgs[i].body;
    }
    return null;
  }

  static String _titleFrom(String text) {
    final String clean = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length <= 42) return clean;
    return '${clean.substring(0, 42).trimRight()}…';
  }

  static String _firstLine(String body) {
    final String stripped = body.replaceAll(RegExp(r'^#+\s*'), '').trim();
    final int nl = stripped.indexOf('\n');
    final String line = nl < 0 ? stripped : stripped.substring(0, nl);
    return line.length <= 120 ? line : '${line.substring(0, 120)}…';
  }

  AppLinkRef _refFor(
    AppLinkKind kind,
    String id,
    String title, {
    String? subtitle,
  }) =>
      AppLinkRef(
        kind: kind,
        id: id,
        title: title,
        subtitle: subtitle,
        intent: kind.intent,
        icon: kind.icon,
      );

  String _uid() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _replyTimer?.cancel();
    super.dispose();
  }
}
