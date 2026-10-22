import 'package:tradex/core/config/supabase_config.dart';
import 'package:uuid/uuid.dart';
import 'ai_chat_transport.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_seed_data.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/features/strategies/data/strategies_repository.dart';

/// Conversation state for authenticated streaming and explicit demo previews.
///
/// A plain [ChangeNotifier] shared by the main chat and feature overlays.
/// Configured accounts stream through [AiChatTransport]. Seed data and staged
/// demo replies are available only in the explicit preview/test mode.
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
    AiChatTransport? transport,
    String? Function()? actorId,
  }) : _identity =
           actorId ?? (() => SupabaseConfig.client?.auth.currentUser?.id),
       _transport = transport ?? HttpAiChatTransport(),
       _community = communityRepository,
       _threads =
           seedThreads ??
           (CustomerDataPolicy.allowDemo
               ? AiSeedData.threads()
               : <AiThread>[]) {
    _actorId = _identity();
    _authSubscription = SupabaseConfig.client?.auth.onAuthStateChange.listen(
      (_) => _ensureActor(),
    );
    _threads.sort(_threadOrder);
    if (_threads.isEmpty) _threads.add(_blankThread(AiPersona.swing));
    _activeThreadId = _threads.first.id;
    _insights = CustomerDataPolicy.allowDemo
        ? List<AppAiInsight>.from(AiSeedData.insights())
        : [];
  }

  /// Injected so AI-created community posts land in the real feed. When null,
  /// publishing a post fails explicitly.
  final CommunityRepository? _community;
  final AiChatTransport _transport;
  final String? Function() _identity;
  String? _actorId;
  StreamSubscription<dynamic>? _authSubscription;

  void _ensureActor() {
    final actor = _identity();
    if (actor == _actorId) return;
    _actorId = actor;
    _transport.cancel();
    _replyTimer?.cancel();
    _replySeq++;
    _generating = false;
    _generationError = null;
    _threads
      ..clear()
      ..add(_blankThread(AiPersona.swing));
    _activeThreadId = _threads.first.id;
    _actions.clear();
    _insights.clear();
    scheduleMicrotask(_notify);
  }

  String? _generationError;
  bool get serviceAvailable =>
      _transport.available || CustomerDataPolicy.allowDemo;
  String? get generationError => _generationError;
  bool get usesLiveService => _transport.available;

  final List<AiThread> _threads;
  late final List<AppAiInsight> _insights;
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
  List<AiThread> get threads {
    _ensureActor();
    return List<AiThread>.unmodifiable(_threads);
  }

  AiThread get activeThread {
    _ensureActor();
    return _threads.firstWhere(
      (AiThread t) => t.id == _activeThreadId,
      orElse: () => _threads.first,
    );
  }

  String get activeThreadId => _activeThreadId;

  List<AppAiMessage> get messages => activeThread.messages;

  AiPersona get persona => activeThread.persona;

  bool get generating => _generating;

  bool get isActiveEmpty => activeThread.messages.isEmpty;

  /// Seed content passthroughs — kept out of the widgets.
  List<AiCapability> get capabilities => AiSeedData.capabilities();
  List<AppAiPrompt> get quickPrompts => AiSeedData.quickPrompts();
  Map<String, List<AppAiPrompt>> get promptLibrary =>
      AiSeedData.promptLibrary();
  List<AiChartSetup> get chartSetups =>
      CustomerDataPolicy.allowDemo ? AiSeedData.chartSetups() : [];
  List<AppAiInsight> get insights => List<AppAiInsight>.unmodifiable(_insights);

  void dismissInsight(AppAiInsight insight) {
    _insights.remove(insight);
    notifyListeners();
  }

  void generateInsight() {
    if (!CustomerDataPolicy.allowDemo) return;
    final List<String> symbols = <String>[
      'NVDA',
      'TSLA',
      'AAPL',
      'BTC',
      'ETH',
      'SPY',
      'QQQ',
      'AMD',
    ];
    final Random rng = Random();
    final String symbol = symbols[rng.nextInt(symbols.length)];
    final bool bullish = rng.nextBool();
    final AppAiInsight fresh = AppAiInsight(
      id: 'insight_${DateTime.now().millisecondsSinceEpoch}',
      title:
          '$symbol ${bullish ? "Bullish Volume Breakout" : "Bearish Rejection at Resistance"}',
      body:
          'AI detected unusual ${bullish ? "accumulation" : "distribution"} patterns on the 1H timeframe with high institutional order flow.',
      confidence: 0.88,
      sentimentScore: bullish ? 0.75 : -0.65,
      tickers: <String>[symbol],
      createdAt: DateTime.now(),
    );
    _insights.insert(0, fresh);
    notifyListeners();
  }

  AiChartSetup? setupById(String id) {
    if (!CustomerDataPolicy.allowDemo) return null;
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
        if (!CustomerDataPolicy.allowDemo) return const <AiSuggestedAction>[];
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
    stop();
    _activeThreadId = id;
    _notify();
  }

  /// Starts a fresh conversation and makes it active.
  AiThread newThread({AiPersona persona = AiPersona.swing}) {
    stop();
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
    if (_activeThreadId == id) stop();
    _threads.removeAt(idx);
    if (_threads.isEmpty) _threads.add(_blankThread(AiPersona.swing));
    if (_activeThreadId == id) {
      _threads.sort(_threadOrder);
      _activeThreadId = _threads.first.id;
    }
    _notify();
  }

  /// Clears all messages in the active thread.
  void clearActiveThread() {
    stop();
    final AiThread t = activeThread;
    _replace(t.copyWith(messages: const <AppAiMessage>[]));
    _notify();
  }

  // -------------------------------------------------------------------------
  // Chat
  // -------------------------------------------------------------------------

  /// Appends the user's turn and schedules a simulated assistant reply.
  ///
  /// @backend POST /ai/threads/{id}/messages — stream the assistant response.
  void sendPrompt(String rawText, {AiPersona? persona}) {
    _ensureActor();
    if (!serviceAvailable || _generating) return;
    _generationError = null;
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
    _transport.cancel();
    _replyTimer?.cancel();
    _replySeq++;
    final AiThread thread = activeThread;
    if (thread.messages.any((AppAiMessage m) => m.pending)) {
      _replace(
        thread.copyWith(
          messages: thread.messages
              .where((AppAiMessage m) => !m.pending || m.body.isNotEmpty)
              .map(
                (m) => m.pending
                    ? AppAiMessage(
                        id: m.id,
                        role: m.role,
                        body: m.body,
                        sentAt: m.sentAt,
                        error: 'Response stopped. You can retry.',
                      )
                    : m,
              )
              .toList(growable: false),
        ),
      );
    }
    _generating = false;
    _notify();
  }

  /// Alias for [stop] to halt active generation.
  void stopGenerating() => stop();

  /// Regenerates the answer for [assistantMessage] using its preceding prompt.
  ///
  /// @backend POST /ai/messages/{id}/regenerate
  void regenerate(AppAiMessage assistantMessage) {
    _ensureActor();
    if (!serviceAvailable || _generating) return;
    _generationError = null;
    if (assistantMessage.role != AppAiRole.assistant) return;
    final AiThread thread = activeThread;
    final int idx = thread.messages.indexWhere(
      (AppAiMessage m) => m.id == assistantMessage.id,
    );
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

  Future<void> _streamReply(
    String threadId,
    String pendingId,
    AiPersona persona,
  ) async {
    final seq = ++_replySeq;
    var body = '';
    try {
      final thread = _threads.firstWhere((t) => t.id == threadId);
      await for (final delta in _transport.stream(
        threadId: threadId,
        persona: persona.name,
        messages: thread.messages,
      )) {
        _ensureActor();
        if (_disposed || seq != _replySeq) return;
        if (body.length + delta.length > 200000) {
          throw StateError(
            'The response is too long. Your partial answer has been kept.',
          );
        }
        body += delta;
        _updateStreamMessage(threadId, pendingId, body, pending: true);
      }
      if (_disposed || seq != _replySeq) return;
      if (body.trim().isEmpty) {
        throw StateError(
          'The assistant returned an empty response. Please retry.',
        );
      }
      _updateStreamMessage(threadId, pendingId, body);
    } catch (error) {
      if (_disposed || seq != _replySeq) return;
      _generationError = '$error'.replaceFirst('Bad state: ', '');
      _updateStreamMessage(threadId, pendingId, body, error: _generationError);
    } finally {
      if (!_disposed && seq == _replySeq) {
        _generating = false;
        _notify();
      }
    }
  }

  void _updateStreamMessage(
    String threadId,
    String pendingId,
    String body, {
    bool pending = false,
    String? error,
  }) {
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (index < 0) return;
    final thread = _threads[index];
    _threads[index] = thread.copyWith(
      messages: [
        for (final message in thread.messages)
          if (message.id == pendingId)
            AppAiMessage(
              id: message.id,
              role: message.role,
              body: body,
              pending: pending,
              error: error,
              sentAt: message.sentAt,
            )
          else
            message,
      ],
      updatedAt: DateTime.now(),
    );
    _actions[pendingId] = const [];
    _notify();
  }

  void _scheduleReply(
    String threadId,
    String pendingId,
    String userText,
    AiPersona persona,
  ) {
    if (usesLiveService) {
      unawaited(_streamReply(threadId, pendingId, persona));
      return;
    }
    _replyTimer?.cancel();
    final int seq = ++_replySeq;
    _replyTimer = Timer(const Duration(milliseconds: 1150), () {
      if (_disposed || seq != _replySeq) return;
      final ({
        String body,
        List<String> sources,
        List<AiSuggestedAction> actions,
      })
      reply = AiSeedData.replyFor(userText, persona);
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
        return _createPost(draft);
      case AiCreateTarget.chartAnalysis:
        // Chart analysis exports commit through the concrete targets above.
        return null;
    }
  }

  /// @backend POST /notes
  Future<AppLinkRef> _createNote(AiCreateDraft draft) async {
    final int wordCount = draft.body
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    final AppNote note = await NotesRepositoryScope.repository.create(
      AppNote(
        id: 'note_ai_${_uid()}',
        title: draft.title,
        content: draft.body,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        noteType: draft.noteType,
        tags: draft.tags,
        linkedTickers: draft.tickers,
        isFavorite: draft.isFavorite,
        isPublic: draft.isPublic,
        strategyName: draft.strategyName,
        wordCount: wordCount,
        hasCode: draft.body.contains('```'),
      ),
    );
    return _refFor(
      AppLinkKind.note,
      note.id,
      note.title,
      subtitle: '${draft.noteType.label} • ${draft.tickers.join(', ')}',
    );
  }

  /// @backend POST /journal/trades
  Future<AppLinkRef> _createTrade(AiCreateDraft draft) async {
    final AiChartSetup? s = draft.setup;
    final String ticker = draft.tickers.isNotEmpty
        ? draft.tickers.first
        : (s?.symbol ?? 'NIFTY50');
    final double entry = draft.entryPrice ?? (s?.entry ?? 100.0);
    final double? stop = draft.stopLoss ?? s?.stopLoss;
    final double? target = draft.target1 ?? s?.target1;
    final double rMult = draft.rMultiple ?? (s?.rrRatio ?? 2.0);
    final double exit = draft.isClosed ? (target ?? entry) : 0.0;
    final double pnl = draft.isClosed
        ? (draft.side == AppSide.long ? (exit - entry) : (entry - exit)) *
              draft.quantity
        : 0.0;
    final double pnlPercent = draft.isClosed && entry > 0
        ? ((draft.side == AppSide.long ? (exit - entry) : (entry - exit)) /
                  entry) *
              100
        : 0.0;
    final AppOutcome outcome = !draft.isClosed
        ? AppOutcome.open
        : (pnl > 0
              ? AppOutcome.win
              : (pnl < 0 ? AppOutcome.loss : AppOutcome.breakeven));
    final int wordCount = draft.body
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;

    final AppTrade trade = await JournalRepositoryScope.repository.create(
      AppTrade(
        id: 'trade_ai_${_uid()}',
        ticker: ticker,
        side: draft.side,
        openedAt: DateTime.now(),
        closedAt: draft.isClosed ? DateTime.now() : null,
        entry: entry,
        exit: draft.isClosed ? exit : null,
        stopLoss: stop,
        target: target,
        size: draft.quantity,
        pnl: pnl,
        pnlPercent: pnlPercent,
        rMultiple: rMult,
        outcome: outcome,
        title: draft.title,
        content: draft.body,
        notes: draft.title,
        strategy: draft.strategyName ?? s?.pattern ?? 'Breakout Momentum',
        tags: draft.tags,
        psychologyScore: draft.psychologyScore,
        isPublic: draft.isPublic,
        isFavorite: draft.isFavorite,
        wordCount: wordCount,
        hasCode: draft.body.contains('```'),
      ),
    );
    final String title = trade.title.isEmpty ? '$ticker trade' : trade.title;
    return _refFor(
      AppLinkKind.journal,
      trade.id,
      title,
      subtitle:
          '${draft.side.name.toUpperCase()} $ticker • ${rMult.toStringAsFixed(1)}R',
    );
  }

  /// @backend POST /strategies
  Future<AppLinkRef> _createStrategy(AiCreateDraft draft) async {
    final int wordCount = draft.body
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    final AppStrategy strat = await StrategiesRepositoryScope.repository.create(
      AppStrategy(
        id: 'strat_ai_${_uid()}',
        name: draft.title,
        summary: draft.summary?.trim().isNotEmpty == true
            ? draft.summary!
            : _firstLine(draft.body),
        category: draft.category ?? 'Breakout Momentum',
        content: draft.body,
        status: draft.strategyStatus,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tags: draft.tags,
        linkedTickers: draft.tickers,
        isPublic: draft.isPublic,
        isFavorite: draft.isFavorite,
        wordCount: wordCount,
        hasCode: draft.body.contains('```'),
      ),
    );
    try {
      await StrategiesRepositoryScope.repository.saveVersion(
        strat.id,
        note: 'Initial AI-generated draft playbook',
      );
    } catch (_) {}
    return _refFor(
      AppLinkKind.strategy,
      strat.id,
      strat.name,
      subtitle:
          '${draft.category ?? 'Playbook'} • ${draft.strategyStatus.name.toUpperCase()}',
    );
  }

  /// @backend POST /community/posts
  Future<AppLinkRef?> _createPost(AiCreateDraft draft) async {
    final CommunityRepository community = _community ?? CommunityRepository();
    final AiChartSetup? s = draft.setup;
    final tradeSetup = s != null
        ? CommunityTradeSetup(
            ticker: s.symbol,
            side: s.direction.label.toUpperCase(),
            entry: s.entry.toStringAsFixed(2),
            stopLoss: s.stopLoss.toStringAsFixed(2),
            target: s.target1.toStringAsFixed(2),
            rMultiple: '${s.rrRatio.toStringAsFixed(1)}R',
          )
        : (draft.entryPrice != null && draft.target1 != null
              ? CommunityTradeSetup(
                  ticker: draft.tickers.isNotEmpty
                      ? draft.tickers.first
                      : 'NIFTY50',
                  side: draft.side.name.toUpperCase(),
                  entry: draft.entryPrice!.toStringAsFixed(2),
                  stopLoss: (draft.stopLoss ?? 0).toStringAsFixed(2),
                  target: draft.target1!.toStringAsFixed(2),
                  rMultiple: '${(draft.rMultiple ?? 2.0).toStringAsFixed(1)}R',
                )
              : null);

    await community.createPost(
      body: draft.body,
      author: community.currentAuthor,
      tickers: draft.tickers,
      tags: draft.tags.isEmpty ? const <String>['AI Setup'] : draft.tags,
      tradeSetup: tradeSetup,
    );
    return _refFor(
      AppLinkKind.note,
      'community_feed',
      draft.title,
      subtitle: 'Published to Community',
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
          summary:
              'High-conviction ${setup.pattern} trading system on ${setup.symbol} with defined risk parameters.',
          category: 'Breakout Momentum',
          strategyStatus: AppStrategyStatus.live,
          body: AiSeedData.strategyBodyForSetup(setup),
          tickers: <String>[setup.symbol],
          tags: <String>['AI', 'Playbook', setup.pattern],
          setup: setup,
          entryPrice: setup.entry,
          stopLoss: setup.stopLoss,
          target1: setup.target1,
          target2: setup.target2,
          rMultiple: setup.rrRatio,
        );
      case AiCreateTarget.journal:
        return AiCreateDraft(
          target: target,
          title: '${setup.symbol} ${setup.pattern}',
          strategyName: setup.pattern,
          side: setup.direction.side,
          entryPrice: setup.entry,
          stopLoss: setup.stopLoss,
          target1: setup.target1,
          target2: setup.target2,
          quantity: 50.0,
          rMultiple: setup.rrRatio,
          body:
              '## Setup Thesis: ${setup.symbol}\n'
              '${setup.rationale}\n\n'
              '### Execution Strategy\n'
              '- **Key Invalidation Level:** ${setup.stopLoss.toStringAsFixed(2)}\n'
              '- **Primary Target:** ${setup.target1.toStringAsFixed(2)}\n'
              '- **Secondary Runner:** ${setup.target2.toStringAsFixed(2)}\n'
              '- **Calculated R:R:** ${setup.rrRatio.toStringAsFixed(1)}R\n\n'
              '### Trader Psychology\n'
              'Disciplined risk allocation followed. Pre-defined exit plan in place.',
          tickers: <String>[setup.symbol],
          tags: <String>['AI', setup.pattern, setup.direction.label],
          setup: setup,
        );
      case AiCreateTarget.post:
        return AiCreateDraft(
          target: target,
          title: '${setup.symbol} Setup Analysis',
          body: AiSeedData.postBodyForSetup(setup),
          tickers: <String>[setup.symbol],
          tags: <String>['AI Setup', setup.direction.label, setup.pattern],
          setup: setup,
          entryPrice: setup.entry,
          stopLoss: setup.stopLoss,
          target1: setup.target1,
          target2: setup.target2,
          rMultiple: setup.rrRatio,
          side: setup.direction.side,
        );
      case AiCreateTarget.note:
      case AiCreateTarget.chartAnalysis:
        return AiCreateDraft(
          target: AiCreateTarget.note,
          title: '${setup.symbol} ${setup.pattern} Technical Analysis',
          noteType: AppNoteType.analysis,
          body: AiSeedData.noteBodyForSetup(setup),
          tickers: <String>[setup.symbol],
          tags: <String>['AI', 'Analysis', setup.symbol, setup.pattern],
          setup: setup,
          entryPrice: setup.entry,
          stopLoss: setup.stopLoss,
          target1: setup.target1,
          target2: setup.target2,
          rMultiple: setup.rrRatio,
        );
    }
  }

  /// Builds a preview draft for [target] from the current chat context (or a
  /// generic scaffold when the thread is empty).
  AiCreateDraft draftFromChat(AiCreateTarget target) {
    final String source = _lastAssistantBody() ?? '';
    final String symbol = AiSeedData.symbolFrom(
      source.isEmpty ? activeThread.title : source,
    );
    final String title = switch (target) {
      AiCreateTarget.note => '$symbol In-Depth Research Note',
      AiCreateTarget.journal => '$symbol Trade Execution Idea',
      AiCreateTarget.strategy => '$symbol Precision Playbook',
      AiCreateTarget.post => '$symbol Community Market Update',
      AiCreateTarget.chartAnalysis => '$symbol Chart Breakdown',
    };
    final String body = source.isNotEmpty
        ? source
        : '# $symbol Analysis\n\n'
              'Comprehensive technical and macro breakdown for **$symbol** generated by the TradeX AI Copilot.\n\n'
              '## Key Observations\n'
              '- Momentum structure remains aligned with higher timeframe trends.\n'
              '- Invalidation and liquidity pools have been mapped.\n'
              '- Review risk parameters before committing capital.\n';
    return AiCreateDraft(
      target: target == AiCreateTarget.chartAnalysis
          ? AiCreateTarget.note
          : target,
      title: title,
      body: body,
      tickers: <String>[symbol],
      tags: const <String>['AI', 'Copilot'],
      noteType: AppNoteType.analysis,
      entryPrice: 150.0,
      stopLoss: 144.5,
      target1: 162.0,
      target2: 170.0,
      quantity: 50.0,
      rMultiple: 2.18,
      category: 'Price Action',
      strategyStatus: AppStrategyStatus.live,
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
    id: const Uuid().v4(),
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
  }) => AppLinkRef(
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
    _transport.cancel();
    _authSubscription?.cancel();
    _replySeq++;
    _replyTimer?.cancel();
    super.dispose();
  }
}

/// Static accessor so overlays and cross-feature callers can reach the shared
/// AI assistant repository without threading it through constructors.
class AiAssistantRepositoryScope {
  AiAssistantRepositoryScope._();

  static AiAssistantRepository? _instance;

  static AiAssistantRepository get repository =>
      _instance ??= AiAssistantRepository();

  static set repository(AiAssistantRepository repo) => _instance = repo;
}
