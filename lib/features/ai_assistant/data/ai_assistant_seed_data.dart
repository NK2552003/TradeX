import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';

/// All mock content for the AI Assistant feature, kept strictly out of the
/// widgets. The repository builds its runtime state from these functions and
/// the shared [DemoDataSource]; nothing here is referenced from the UI directly.
///
/// Replies are synthesized from keyword-matched templates so the simulated
/// copilot feels responsive without any hardcoded copy leaking into views. The
/// [AiAssistantRepository] owns the staged delivery timing; this layer owns
/// only the words.
abstract final class AiSeedData {
  // -------------------------------------------------------------------------
  // Capability grid — "what can the copilot do"
  // -------------------------------------------------------------------------

  static List<AiCapability> capabilities() => <AiCapability>[
    const AiCapability(
      id: 'cap_analyze',
      title: 'Analyze a chart',
      description:
          'Detect the pattern, mark structure and extract entry, stop and targets.',
      icon: Icons.candlestick_chart_outlined,
      promptSeed: 'Analyze the current NIFTY50 chart and give me a trade plan.',
      target: AiCreateTarget.chartAnalysis,
      badge: 'Popular',
    ),
    const AiCapability(
      id: 'cap_note',
      title: 'Draft a research note',
      description:
          'Turn a thesis into a structured note with levels, catalysts and risks.',
      icon: Icons.sticky_note_2_outlined,
      promptSeed: 'Write a research note on the RELIANCE breakout setup.',
      target: AiCreateTarget.note,
    ),
    const AiCapability(
      id: 'cap_strategy',
      title: 'Build a strategy',
      description:
          'Codify a repeatable edge into an entry / exit / risk playbook.',
      icon: Icons.account_tree_outlined,
      promptSeed:
          'Help me build a swing strategy around opening-range breakouts.',
      target: AiCreateTarget.strategy,
    ),
    const AiCapability(
      id: 'cap_journal',
      title: 'Log a trade idea',
      description:
          'Capture entry, stop, targets and R:R straight into your journal.',
      icon: Icons.menu_book_outlined,
      promptSeed: 'Log a long trade idea on BANKNIFTY with a tight stop.',
      target: AiCreateTarget.journal,
    ),
    const AiCapability(
      id: 'cap_post',
      title: 'Share with community',
      description: 'Compose a clean setup post the feed will actually read.',
      icon: Icons.forum_outlined,
      promptSeed: 'Draft a community post about the TATAMOTORS momentum move.',
      target: AiCreateTarget.post,
    ),
    const AiCapability(
      id: 'cap_market',
      title: 'Summarize the market',
      description:
          'Get a fast read on breadth, movers and what matters right now.',
      icon: Icons.insights_outlined,
      promptSeed: 'Give me a summary of today\'s market and the key movers.',
    ),
    const AiCapability(
      id: 'cap_risk',
      title: 'Size a position',
      description: 'Work out position size and R multiples for a given risk.',
      icon: Icons.balance_outlined,
      promptSeed: 'How should I size a trade risking 1% on a 2-point stop?',
    ),
    const AiCapability(
      id: 'cap_review',
      title: 'Review my journal',
      description: 'Find patterns in recent trades and where edge is leaking.',
      icon: Icons.query_stats_outlined,
      promptSeed: 'Review my recent trades and tell me what to fix.',
    ),
  ];

  // -------------------------------------------------------------------------
  // Quick prompts — the chips shown on an empty chat
  // -------------------------------------------------------------------------

  static List<AppAiPrompt> quickPrompts() => const <AppAiPrompt>[
    AppAiPrompt(
      label: 'Analyze NIFTY50',
      prompt: 'Analyze the NIFTY50 chart and give me a trade plan.',
      icon: Icons.candlestick_chart_outlined,
    ),
    AppAiPrompt(
      label: 'Market summary',
      prompt: 'Summarize today\'s market and the biggest movers.',
      icon: Icons.insights_outlined,
    ),
    AppAiPrompt(
      label: 'Position size',
      prompt: 'Help me size a position risking 1% of my account.',
      icon: Icons.balance_outlined,
    ),
    AppAiPrompt(
      label: 'Build a playbook',
      prompt: 'Help me turn my breakout setup into a strategy playbook.',
      icon: Icons.account_tree_outlined,
    ),
  ];

  // -------------------------------------------------------------------------
  // Prompt library — categorized, browsable prompts (Create hub / library)
  // -------------------------------------------------------------------------

  /// Ordered category → prompts. Insertion order is preserved for display.
  static Map<String, List<AppAiPrompt>>
  promptLibrary() => <String, List<AppAiPrompt>>{
    'Analysis': const <AppAiPrompt>[
      AppAiPrompt(
        label: 'Break down a ticker',
        prompt:
            'Break down RELIANCE: trend, key levels, and the cleanest trade.',
        icon: Icons.query_stats_outlined,
      ),
      AppAiPrompt(
        label: 'Spot the pattern',
        prompt: 'What chart pattern is BANKNIFTY forming and how do I play it?',
        icon: Icons.show_chart_rounded,
      ),
      AppAiPrompt(
        label: 'Support & resistance',
        prompt: 'Map the key support and resistance levels on NIFTY50.',
        icon: Icons.horizontal_rule_rounded,
      ),
    ],
    'Strategy': const <AppAiPrompt>[
      AppAiPrompt(
        label: 'Design an edge',
        prompt: 'Help me design a mean-reversion strategy for index futures.',
        icon: Icons.account_tree_outlined,
      ),
      AppAiPrompt(
        label: 'Define exit rules',
        prompt: 'What exit rules keep me from giving back winners?',
        icon: Icons.logout_rounded,
      ),
      AppAiPrompt(
        label: 'Backtest checklist',
        prompt: 'Give me a checklist to validate a strategy before I trade it.',
        icon: Icons.fact_check_outlined,
      ),
    ],
    'Risk': const <AppAiPrompt>[
      AppAiPrompt(
        label: 'Position sizing',
        prompt: 'How do I size positions so one loss never hurts?',
        icon: Icons.balance_outlined,
      ),
      AppAiPrompt(
        label: 'Set a stop',
        prompt: 'Where should my stop go on a TATAMOTORS long from here?',
        icon: Icons.gpp_maybe_outlined,
      ),
    ],
    'Journaling': const <AppAiPrompt>[
      AppAiPrompt(
        label: 'Review the week',
        prompt: 'Review my trades this week and surface one thing to fix.',
        icon: Icons.event_note_outlined,
      ),
      AppAiPrompt(
        label: 'Trade post-mortem',
        prompt: 'Walk me through a post-mortem for my last losing trade.',
        icon: Icons.psychology_alt_outlined,
      ),
    ],
  };

  // -------------------------------------------------------------------------
  // Chart setups — detectable patterns with full trade plans
  // -------------------------------------------------------------------------

  static List<AiChartSetup> chartSetups() => const <AiChartSetup>[
    AiChartSetup(
      id: 'setup_nifty_flag',
      title: 'Bull flag continuation',
      symbol: 'NIFTY50',
      timeframe: '15m',
      pattern: 'Bull Flag',
      direction: AiTradeDirection.long,
      entry: 24280,
      stopLoss: 24120,
      target1: 24540,
      target2: 24720,
      confidence: 82,
      rationale:
          'Tight bull-flag consolidation after an impulsive leg up, riding the '
          'rising 20-EMA on the 15m. Volume is drying into the flag — classic '
          'continuation. A break and hold above the flag high confirms the move.',
    ),
    AiChartSetup(
      id: 'setup_reliance_bo',
      title: 'Range breakout',
      symbol: 'RELIANCE',
      timeframe: '1h',
      pattern: 'Ascending Triangle',
      direction: AiTradeDirection.long,
      entry: 2985,
      stopLoss: 2932,
      target1: 3060,
      target2: 3140,
      confidence: 76,
      rationale:
          'Higher lows pressing into flat horizontal resistance at 2,980 for '
          'three sessions. Each test of the highs is on rising volume — supply '
          'is being absorbed. The measured move projects to 3,140.',
    ),
    AiChartSetup(
      id: 'setup_banknifty_rev',
      title: 'Exhaustion reversal',
      symbol: 'BANKNIFTY',
      timeframe: '5m',
      pattern: 'Double Top',
      direction: AiTradeDirection.short,
      entry: 52180,
      stopLoss: 52380,
      target1: 51780,
      target2: 51480,
      confidence: 71,
      rationale:
          'Two failed pushes into 52,200 with a bearish RSI divergence on the '
          'second peak. Momentum is rolling over and the neckline at 51,900 is '
          'the trigger. Below it, sellers take control into the prior demand.',
    ),
  ];

  // -------------------------------------------------------------------------
  // Insights — reused from the shared demo source
  // -------------------------------------------------------------------------

  static List<AppAiInsight> insights({int? limit}) =>
      DemoDataSource.instance.insights(limit: limit);

  // -------------------------------------------------------------------------
  // Seed conversation history
  // -------------------------------------------------------------------------

  static List<AiThread> threads() {
    final DateTime now = DateTime.now();
    return <AiThread>[
      AiThread(
        id: 'thread_nifty',
        title: 'NIFTY50 breakout plan',
        persona: AiPersona.swing,
        pinned: true,
        updatedAt: now.subtract(const Duration(minutes: 12)),
        messages: <AppAiMessage>[
          AppAiMessage(
            id: 'm_nifty_1',
            role: AppAiRole.user,
            body: 'Is NIFTY50 setting up for a breakout here?',
            sentAt: now.subtract(const Duration(minutes: 18)),
          ),
          AppAiMessage(
            id: 'm_nifty_2',
            role: AppAiRole.assistant,
            body:
                '📈 Swing lens — multi-day structure & positioning:\n\n'
                'NIFTY50 is coiling in a tight bull flag on the 15m after a clean '
                'impulse leg. The rising 20-EMA is holding as dynamic support and '
                'volume is contracting into the flag — that is textbook '
                'continuation behaviour.\n\n'
                '• Trigger: break and hold above 24,280\n'
                '• Invalidation: 15m close back under 24,120\n'
                '• Targets: 24,540 then 24,720\n\n'
                'Swing note: scale in against the higher-timeframe demand and hold '
                'for the measured move.',
            sentAt: now.subtract(const Duration(minutes: 17)),
            sources: const <String>['NIFTY50 15m', 'Volume profile', 'Breadth'],
          ),
        ],
      ),
      AiThread(
        id: 'thread_reliance',
        title: 'RELIANCE earnings setup',
        persona: AiPersona.momentum,
        updatedAt: now.subtract(const Duration(hours: 3)),
        messages: <AppAiMessage>[
          AppAiMessage(
            id: 'm_rel_1',
            role: AppAiRole.user,
            body: 'How should I trade RELIANCE into earnings?',
            sentAt: now.subtract(const Duration(hours: 3, minutes: 4)),
          ),
          AppAiMessage(
            id: 'm_rel_2',
            role: AppAiRole.assistant,
            body:
                '⚡ Scalper lens — intraday momentum & order flow:\n\n'
                'RELIANCE is pressing an ascending triangle into 2,980. I would '
                'not pre-position into the print — let the reaction set the tone, '
                'then trade the retest of the breakout with defined risk under '
                '2,932.\n\n'
                'Scalper note: only trigger on a confirmed break-and-retest; kill '
                'the idea if 1m momentum stalls.',
            sentAt: now.subtract(const Duration(hours: 3, minutes: 3)),
            sources: const <String>['RELIANCE 1h', 'Options IV'],
          ),
        ],
      ),
      AiThread(
        id: 'thread_income',
        title: 'Weekly options income',
        persona: AiPersona.options,
        updatedAt: now.subtract(const Duration(days: 1, hours: 2)),
        messages: <AppAiMessage>[
          AppAiMessage(
            id: 'm_inc_1',
            role: AppAiRole.user,
            body: 'What is a safe weekly income strategy on the index?',
            sentAt: now.subtract(const Duration(days: 1, hours: 2, minutes: 6)),
          ),
          AppAiMessage(
            id: 'm_inc_2',
            role: AppAiRole.assistant,
            body:
                '🧮 Quant lens — volatility surface & Greeks:\n\n'
                'With IV rank elevated, an iron condor around the expected move '
                'collects premium while staying delta-neutral. Sell the wings at '
                '~16-delta and keep total risk to a fixed fraction of the book.\n\n'
                'Quant note: express this via defined-risk spreads while IV rank '
                'is elevated to stay theta-neutral.',
            sentAt: now.subtract(const Duration(days: 1, hours: 2, minutes: 5)),
            sources: const <String>['IV rank', 'Expected move'],
          ),
        ],
      ),
    ];
  }

  // -------------------------------------------------------------------------
  // Reply synthesis
  // -------------------------------------------------------------------------

  /// Known mock symbols the extractor recognises inside a prompt.
  static const List<String> _knownSymbols = <String>[
    'NIFTY50',
    'BANKNIFTY',
    'RELIANCE',
    'TATAMOTORS',
    'HDFCBANK',
    'ICICIBANK',
    'INFY',
    'TCS',
    'SBIN',
    'ADANIENT',
    'NIFTY',
  ];

  /// Pulls a probable ticker out of [text]; falls back to a sensible default.
  static String symbolFrom(String text) {
    final String upper = text.toUpperCase();
    for (final String symbol in _knownSymbols) {
      if (upper.contains(symbol)) {
        return symbol == 'NIFTY' ? 'NIFTY50' : symbol;
      }
    }
    final RegExpMatch? caps = RegExp(r'\b[A-Z]{3,}\b').firstMatch(text);
    return caps?.group(0) ?? 'NIFTY50';
  }

  /// Builds a persona-flavoured reply for [userText]. The repository prepends
  /// the persona opener / appends the emphasis; this returns the core body plus
  /// the sources and the "create from this" actions to surface underneath.
  static ({String body, List<String> sources, List<AiSuggestedAction> actions})
  replyFor(String userText, AiPersona persona) {
    final String lower = userText.toLowerCase();
    final String symbol = symbolFrom(userText);

    bool has(List<String> keys) => keys.any(lower.contains);

    if (has(<String>[
      'size',
      'sizing',
      'position size',
      'risk %',
      'how much',
    ])) {
      return (
        body:
            'Position sizing is the one lever that keeps a bad run survivable. '
            'Fix the risk per trade first, then let the stop define the size:\n\n'
            '• Risk per trade: 1% of equity\n'
            '• Size = (equity × 1%) ÷ (entry − stop) in points\n'
            '• Never average a loser below your invalidation\n\n'
            'On a 2-point stop with a ₹5,00,000 book, that is ₹5,000 of risk → '
            '2,500 units. Halve it in chop, and only press size when you are '
            'trading your A+ setup.',
        sources: const <String>['Risk model', 'Account equity'],
        actions: const <AiSuggestedAction>[
          AiSuggestedAction(target: AiCreateTarget.note, label: 'Save as note'),
          AiSuggestedAction(target: AiCreateTarget.strategy),
        ],
      );
    }

    if (has(<String>[
      'strategy',
      'playbook',
      'rules',
      'edge',
      'backtest',
      'system',
    ])) {
      return (
        body:
            'Here is a skeleton you can trade tomorrow — tighten each rule to '
            'your data:\n\n'
            'Core Rules\n'
            '• Context: only take longs above the rising 20-EMA on the anchor '
            'timeframe\n'
            '• Trigger: break-and-retest of the range high on rising volume\n'
            '• Stop: below the retest swing low\n'
            '• Target: 1R scale, trail the rest under structure\n\n'
            'Edge lives in the filters you say no to, not the entries you say yes '
            'to. Codify the no-trade conditions just as carefully.',
        sources: const <String>['Backtest notes', 'Playbook template'],
        actions: const <AiSuggestedAction>[
          AiSuggestedAction(target: AiCreateTarget.strategy),
          AiSuggestedAction(target: AiCreateTarget.note, label: 'Save as note'),
        ],
      );
    }

    if (has(<String>[
      'market',
      'today',
      'movers',
      'gainers',
      'losers',
      'breadth',
      'outlook',
      'summary',
    ])) {
      return (
        body:
            'Market read:\n\n'
            '• Breadth is constructive — advancers leading, and the index is '
            'holding above its rising daily 20-EMA.\n'
            '• Leaders: energy and autos are carrying the tape; TATAMOTORS and '
            'RELIANCE are relative-strength names.\n'
            '• Risk: financials are lagging — a rollover in BANKNIFTY would cap '
            'index upside.\n\n'
            'Net: buyable dips while $symbol holds structure; stand aside if '
            'breadth flips negative intraday.',
        sources: const <String>[
          'Index breadth',
          'Sector heatmap',
          'Advance/decline',
        ],
        actions: const <AiSuggestedAction>[
          AiSuggestedAction(
            target: AiCreateTarget.post,
            label: 'Share this read',
          ),
          AiSuggestedAction(target: AiCreateTarget.note, label: 'Save as note'),
        ],
      );
    }

    if (has(<String>[
      'journal',
      'review',
      'mistake',
      'post-mortem',
      'post mortem',
      'last trade',
      'my trades',
    ])) {
      return (
        body:
            'Looking across your recent trades, one pattern stands out: your '
            'winners are cut early and your losers are held to the stop. That is '
            'an exit problem, not an entry problem.\n\n'
            '• Wins: average hold well under target — you are booking at ~0.7R\n'
            '• Losses: full-stop hits, no partial de-risking\n\n'
            'Fix: take 1R partials and trail the remainder under structure. Log '
            'the reason for every early exit for two weeks and the leak usually '
            'closes itself.',
        sources: const <String>['Journal history', 'Trade stats'],
        actions: const <AiSuggestedAction>[
          AiSuggestedAction(target: AiCreateTarget.note, label: 'Save review'),
          AiSuggestedAction(
            target: AiCreateTarget.journal,
            label: 'Log a trade',
          ),
        ],
      );
    }

    if (has(<String>['post', 'share', 'community', 'tweet', 'feed'])) {
      return (
        body:
            'Here is a clean, no-hype way to share the $symbol idea:\n\n'
            '"$symbol pressing range highs on rising volume. Watching for a '
            'break-and-retest to trigger long; invalidation just under the '
            'range. Defined risk, let it come to you. #$symbol"\n\n'
            'Lead with the setup, name the invalidation, skip the price target '
            'hype — the feed rewards process over predictions.',
        sources: const <String>['Setup summary'],
        actions: const <AiSuggestedAction>[
          AiSuggestedAction(target: AiCreateTarget.post),
        ],
      );
    }

    if (has(<String>['note', 'write', 'draft', 'research'])) {
      return (
        body:
            'I have drafted a structured note on $symbol — thesis, the levels '
            'that matter, the catalyst window and what invalidates it. Review it '
            'and I will save it straight to your notes with the tickers linked.',
        sources: <String>['$symbol daily', 'Catalyst calendar'],
        actions: const <AiSuggestedAction>[
          AiSuggestedAction(target: AiCreateTarget.note),
          AiSuggestedAction(
            target: AiCreateTarget.chartAnalysis,
            label: 'Analyze chart',
          ),
        ],
      );
    }

    // Default: treat it as an analysis request on the detected symbol.
    return (
      body:
          'Here is my read on $symbol:\n\n'
          '• Trend: constructive — higher highs and higher lows on the anchor '
          'timeframe.\n'
          '• Key level: the range high is the line in the sand; reclaim and hold '
          'is bullish, rejection keeps it range-bound.\n'
          '• Plan: wait for the break-and-retest rather than chasing; risk sits '
          'cleanly under the retest low.\n\n'
          'Want me to turn this into a full trade plan, a note, or a journal '
          'entry?',
      sources: <String>['$symbol chart', 'Momentum', 'Volume'],
      actions: const <AiSuggestedAction>[
        AiSuggestedAction(
          target: AiCreateTarget.chartAnalysis,
          label: 'Analyze chart',
        ),
        AiSuggestedAction(target: AiCreateTarget.note, label: 'Save as note'),
        AiSuggestedAction(target: AiCreateTarget.journal, label: 'Log trade'),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Draft bodies for the "create anything" flow
  // -------------------------------------------------------------------------

  /// Markdown body for a note generated from [setup].
  static String noteBodyForSetup(AiChartSetup setup) {
    return '# ${setup.symbol} ${setup.pattern} Analysis\n\n'
        '**Timeframe:** ${setup.timeframe}  ·  **Bias:** ${setup.direction.label}  '
        '·  **Confidence:** ${setup.confidence}%\n\n'
        '## Trade plan\n'
        '- Entry: ${AppTokens.price(setup.entry)}\n'
        '- Stop loss: ${AppTokens.price(setup.stopLoss)}\n'
        '- Target 1: ${AppTokens.price(setup.target1)}\n'
        '- Target 2: ${AppTokens.price(setup.target2)}\n'
        '- Risk/Reward: ${setup.rrRatio.toStringAsFixed(2)}R\n\n'
        '## Rationale\n${setup.rationale}\n\n'
        '_Generated by the alphajournal AI copilot._';
  }

  /// Markdown body for a strategy playbook generated from [setup].
  static String strategyBodyForSetup(AiChartSetup setup) {
    return '## Core Rules — ${setup.pattern}\n\n'
        '**Setup:** ${setup.symbol} on the ${setup.timeframe} '
        '(${setup.direction.label.toLowerCase()} bias)\n\n'
        '### Entry\n'
        '- Wait for the ${setup.pattern.toLowerCase()} to confirm\n'
        '- Trigger near ${AppTokens.price(setup.entry)} on a break-and-retest\n\n'
        '### Risk\n'
        '- Hard stop at ${AppTokens.price(setup.stopLoss)}\n'
        '- Risk a fixed 1% of equity per trade\n\n'
        '### Exits\n'
        '- Scale 1R at ${AppTokens.price(setup.target1)}\n'
        '- Trail the runner toward ${AppTokens.price(setup.target2)}\n\n'
        '### Notes\n${setup.rationale}';
  }

  /// Community post body for [setup].
  static String postBodyForSetup(AiChartSetup setup) {
    return '🤖 AI Chart Scan · \$${setup.symbol}\n\n'
        '${setup.pattern} (${setup.timeframe}) — ${setup.direction.label} bias, '
        '${setup.confidence}% confidence.\n\n'
        'Entry ${AppTokens.price(setup.entry)} · Stop '
        '${AppTokens.price(setup.stopLoss)} · Target '
        '${AppTokens.price(setup.target1)} '
        '(${setup.rrRatio.toStringAsFixed(1)}R)\n\n'
        '${setup.rationale}';
  }
}
