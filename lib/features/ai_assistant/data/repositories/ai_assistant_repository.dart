import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';

/// The lens the copilot answers through. Each scope maps to a different
/// system prompt + retrieval set once a real model is wired in.
enum AiScope { general, journal, strategy, market, risk }

String aiScopeLabel(AiScope scope) => switch (scope) {
  AiScope.general => 'General',
  AiScope.journal => 'Journal review',
  AiScope.strategy => 'Strategy lab',
  AiScope.market => 'Market context',
  AiScope.risk => 'Risk coach',
};

IconData aiScopeIcon(AiScope scope) => switch (scope) {
  AiScope.general => Icons.auto_awesome_rounded,
  AiScope.journal => Icons.menu_book_rounded,
  AiScope.strategy => Icons.science_rounded,
  AiScope.market => Icons.public_rounded,
  AiScope.risk => Icons.shield_moon_rounded,
};

/// Datasets the copilot reads for a scope. The UI shows these so a trader can
/// see what the answer was grounded in, and the backend uses the same list as
/// the retrieval set for the scope's system prompt.
List<String> aiScopeSources(AiScope scope) => switch (scope) {
  AiScope.general => const <String>['Journal', 'Portfolio'],
  AiScope.journal => const <String>['Journal', 'Checklists'],
  AiScope.strategy => const <String>['Strategies', 'Backtests'],
  AiScope.market => const <String>['Watchlists', 'News'],
  AiScope.risk => const <String>['Risk limits', 'Open positions'],
};

/// One-line description of what a scope is for, shown under the selector.
String aiScopeBlurb(AiScope scope) => switch (scope) {
  AiScope.general => 'Anything about your account, in plain language.',
  AiScope.journal => 'Grades discipline and finds repeated mistakes.',
  AiScope.strategy => 'Ranks playbooks and suggests variants to test.',
  AiScope.market => 'Session context across the instruments you follow.',
  AiScope.risk => 'Exposure, sizing and drawdown guardrails.',
};

/// Monthly copilot allowance by subscription tier. Free users are capped so the
/// paywall/upsell states in the UI have something real to render.
@immutable
class AiCredits {
  const AiCredits({required this.used, required this.limit});

  final int used;
  final int limit;

  bool get exhausted => used >= limit;
  int get remaining => limit - used < 0 ? 0 : limit - used;
}

abstract class AiAssistantRepository {
  Future<List<AppAiMessage>> getHistory(AiScope scope);
  Future<List<AppAiPrompt>> getPrompts(AiScope scope);
  Future<AppAiMessage> send(
    AiScope scope,
    String prompt, {
    List<String> attachments,
  });
  Future<void> clearHistory(AiScope scope);

  /// Drops the trailing assistant reply. Called when the trader stops a
  /// generation so the stored thread matches what they were shown.
  Future<void> discardLastReply(AiScope scope);
  Future<List<AppAiInsight>> getInsights({String? symbol});
  Future<List<String>> getObservations(AppAiInsight insight);
  Future<String> reviewTrade(AppTrade trade);
  Future<AiCredits> getCredits(AppTier tier);
}

class AiAssistantRepositoryImpl implements AiAssistantRepository {
  AiAssistantRepositoryImpl({DemoDataSource? source})
    : _source = source ?? DemoDataSource.instance;

  final DemoDataSource _source;
  final Map<AiScope, List<AppAiMessage>> _history =
      <AiScope, List<AppAiMessage>>{};
  int _used = 0;

  static const Map<AppTier, int> _limits = <AppTier, int>{
    AppTier.free: 20,
    AppTier.premium: 500,
    AppTier.enterprise: 5000,
  };

  List<AppAiMessage> _bucket(AiScope scope) =>
      _history.putIfAbsent(scope, () => <AppAiMessage>[]);

  @override
  Future<List<AppAiMessage>> getHistory(AiScope scope) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    return List<AppAiMessage>.from(_bucket(scope));
  }

  @override
  Future<List<AppAiPrompt>> getPrompts(AiScope scope) async {
    switch (scope) {
      case AiScope.general:
        return const <AppAiPrompt>[
          AppAiPrompt(
            label: 'Summarise my week',
            prompt: 'Summarise how I traded over the last seven sessions.',
            icon: Icons.summarize_rounded,
          ),
          AppAiPrompt(
            label: 'What should I fix?',
            prompt: 'What is the single biggest leak in my trading right now?',
            icon: Icons.build_circle_outlined,
          ),
        ];
      case AiScope.journal:
        return const <AppAiPrompt>[
          AppAiPrompt(
            label: 'Review my journal',
            prompt: 'Review my journal entries and grade my discipline.',
            icon: Icons.menu_book_rounded,
          ),
          AppAiPrompt(
            label: 'Repeated mistakes',
            prompt: 'Which mistakes do I repeat most often, and when?',
            icon: Icons.repeat_rounded,
          ),
        ];
      case AiScope.strategy:
        return const <AppAiPrompt>[
          AppAiPrompt(
            label: 'Rank my playbooks',
            prompt: 'Rank my strategies by expectancy and explain the gaps.',
            icon: Icons.leaderboard_rounded,
          ),
          AppAiPrompt(
            label: 'Backtest ideas',
            prompt: 'Suggest three variations worth backtesting next.',
            icon: Icons.science_rounded,
          ),
        ];
      case AiScope.market:
        return const <AppAiPrompt>[
          AppAiPrompt(
            label: 'Session outlook',
            prompt: 'Give me the context for today across my watchlists.',
            icon: Icons.public_rounded,
          ),
          AppAiPrompt(
            label: 'Explain the move',
            prompt: 'Why is my biggest mover trading where it is?',
            icon: Icons.travel_explore_rounded,
          ),
        ];
      case AiScope.risk:
        return const <AppAiPrompt>[
          AppAiPrompt(
            label: 'Check my exposure',
            prompt: 'Am I over-exposed relative to my daily loss limit?',
            icon: Icons.shield_moon_rounded,
          ),
          AppAiPrompt(
            label: 'Size this trade',
            prompt: 'How should I size the next entry given my drawdown?',
            icon: Icons.balance_rounded,
          ),
        ];
    }
  }

  @override
  Future<AppAiMessage> send(
    AiScope scope,
    String prompt, {
    List<String> attachments = const <String>[],
  }) async {
    final List<AppAiMessage> bucket = _bucket(scope);
    bucket.add(
      AppAiMessage(
        id: 'aim_${DateTime.now().microsecondsSinceEpoch}_u',
        role: AppAiRole.user,
        body: prompt,
        sentAt: DateTime.now(),
        attachments: attachments,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 900));
    _used++;
    final AppAiMessage reply = AppAiMessage(
      id: 'aim_${DateTime.now().microsecondsSinceEpoch}_a',
      role: AppAiRole.assistant,
      body: _answerFor(scope),
      sentAt: DateTime.now(),
      sources: _sourcesFor(scope),
    );
    bucket.add(reply);
    return reply;
  }

  @override
  Future<void> clearHistory(AiScope scope) async {
    _history[scope] = <AppAiMessage>[];
  }

  @override
  Future<void> discardLastReply(AiScope scope) async {
    final List<AppAiMessage> bucket = _bucket(scope);
    if (bucket.isNotEmpty && bucket.last.role == AppAiRole.assistant) {
      bucket.removeLast();
    }
  }

  @override
  Future<List<AppAiInsight>> getInsights({String? symbol}) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    final List<AppAiInsight> all = _source.insights();
    if (symbol == null) return all;
    final List<AppAiInsight> filtered = all
        .where((AppAiInsight i) => i.tickers.contains(symbol))
        .toList(growable: false);
    return filtered.isEmpty ? all.take(2).toList(growable: false) : filtered;
  }

  @override
  Future<List<String>> getObservations(AppAiInsight insight) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final List<AppTrade> closed = _source
        .trades()
        .where((AppTrade t) => t.outcome != AppOutcome.open)
        .toList(growable: false);
    final int wins = closed
        .where((AppTrade t) => t.outcome == AppOutcome.win)
        .length;
    final double net = closed.fold<double>(
      0,
      (double sum, AppTrade t) => sum + t.pnl,
    );
    return <String>[
      'Sampled ${closed.length} closed executions for this observation.',
      'Hit rate across the sample is '
          '${AppTokens.percent(closed.isEmpty ? 0 : wins / closed.length * 100)}.',
      'Net contribution is ${AppTokens.signedMoney(net)} over the window.',
      if (insight.tickers.isNotEmpty)
        'Concentrated in ${insight.tickers.join(', ')}.',
    ];
  }

  @override
  Future<String> reviewTrade(AppTrade trade) async {
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final String outcome = AppTokens.outcomeLabel(trade.outcome);
    return 'This ${AppTokens.sideLabel(trade.side).toLowerCase()} in '
        '${trade.ticker} closed as a ${outcome.toLowerCase()} at '
        '${AppTokens.signedMoney(trade.pnl)}'
        '${trade.rMultiple == null ? '' : ' (${AppTokens.rr(trade.rMultiple!)})'}. '
        'Entry at ${AppTokens.money(trade.entry)} sat inside the prior range, so '
        'the initial risk was defensible; the exit is where the expectancy was '
        'decided. ${trade.outcome == AppOutcome.win ? 'You let the position work — repeat this hold pattern.' : 'The stop was widened after entry, which is the behaviour to remove.'} '
        'Tag this one under ${trade.strategy ?? 'an explicit playbook'} so the '
        'sample stays comparable.';
  }

  @override
  Future<AiCredits> getCredits(AppTier tier) async =>
      AiCredits(used: _used, limit: _limits[tier] ?? 20);

  List<String> _sourcesFor(AiScope scope) => aiScopeSources(scope);

  String _answerFor(AiScope scope) {
    final List<AppTrade> trades = _source.trades();
    final List<AppTrade> closed = trades
        .where((AppTrade t) => t.outcome != AppOutcome.open)
        .toList(growable: false);
    final int wins = closed
        .where((AppTrade t) => t.outcome == AppOutcome.win)
        .length;
    final double net = closed.fold<double>(
      0,
      (double sum, AppTrade t) => sum + t.pnl,
    );
    final double winRate = closed.isEmpty ? 0 : wins / closed.length * 100;
    final double avgR = closed.isEmpty
        ? 0
        : closed.fold<double>(
                0,
                (double s, AppTrade t) => s + (t.rMultiple ?? 0),
              ) /
              closed.length;
    final List<AppStrategy> strategies = _source.strategies();
    final AppStrategy bestStrategy = strategies.reduce(
      (AppStrategy a, AppStrategy b) => a.netPnl >= b.netPnl ? a : b,
    );
    final AppStrategy worstStrategy = strategies.reduce(
      (AppStrategy a, AppStrategy b) => a.netPnl <= b.netPnl ? a : b,
    );
    final List<AppTicker> movers = _source.tickers(limit: 3);
    final int open = trades
        .where((AppTrade t) => t.outcome == AppOutcome.open)
        .length;

    switch (scope) {
      case AiScope.general:
        return 'Across ${closed.length} closed trades you are '
            '${AppTokens.signedMoney(net)} with a '
            '${AppTokens.percent(winRate)} hit rate and '
            '${AppTokens.rr(avgR)} average outcome. The result is carried by '
            '${bestStrategy.name}; ${worstStrategy.name} is the drag. Cut the '
            'weakest playbook in half for two weeks and the equity curve '
            'smooths without touching your winners.';
      case AiScope.journal:
        return 'Your journal is complete on entry rationale but thin on exit '
            'notes — roughly a third of closed trades have no exit reason '
            'recorded. Discipline reads best in the morning session; entries '
            'logged after midday carry a materially lower R. Keep the pre-trade '
            'checklist mandatory and add one line on why you exited.';
      case AiScope.strategy:
        return '${bestStrategy.name} leads on expectancy at '
            '${AppTokens.signedMoney(bestStrategy.netPnl)} over '
            '${bestStrategy.trades} trades (${AppTokens.percent(bestStrategy.winRate)}, '
            '${AppTokens.rr(bestStrategy.avgR)}). ${worstStrategy.name} is '
            'negative and correlates with your highest-volume days. Backtest a '
            'variant that only takes the first two hours of the session.';
      case AiScope.market:
        return 'Your watchlists are led by '
            '${movers.map((AppTicker t) => '${t.symbol} ${AppTokens.signedPercent(t.changePercent)}').join(', ')}. '
            'Breadth is mixed, so treat continuation setups with tighter '
            'invalidation than usual and let the first thirty minutes define '
            'the range before committing size.';
      case AiScope.risk:
        return 'You are holding $open open positions against a '
            '${AppTokens.rr(avgR)} average outcome. Current drawdown is '
            '${AppTokens.percent(_source.drawdownSeries().reduce((double a, double b) => a < b ? a : b).abs())} '
            'from peak, which argues for holding size flat rather than pressing. '
            'Keep per-trade risk at 1% and stop for the day after two losses.';
    }
  }
}
