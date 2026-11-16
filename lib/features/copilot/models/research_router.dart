import 'research_format.dart';

class ResearchRoute {
  const ResearchRoute(
    this.label,
    this.reason, {
    this.format,
    this.nativeCard,
    this.explicit = false,
  });
  final String label;
  final String reason;
  final ResearchFormat? format;
  final String? nativeCard;
  final bool explicit;

  String get instructions =>
      '''
OUTPUT ROUTING: $label. $reason
Respect the user's explicit output instructions and requested length above this recommendation. For simple factual questions, greetings, or narrow follow-ups, answer directly without unnecessary cards. Ask for missing critical inputs rather than inventing them.
${format == null
          ? nativeCard == null
                ? 'Choose the smallest useful answer structure from the actual question and conversation context.'
                : 'Use the $nativeCard visual card when supported data is available, with a concise direct answer and linked evidence.'
          : 'Use a research_panel with format "${format!.id}". ${format!.directive} Columns: ${format!.columns.join(' | ')}. Include a direct summary, rows matching those columns, evidence links with actual dates if available, limitations, and next steps.'}
For mixed questions, use one main format and at most one complementary card. Do not force unrelated metrics, web searches, or tables into the answer.
''';
}

/// Fast local routing previews the format; the model can adapt to conversation context.
class ResearchRouter {
  const ResearchRouter._();

  static ResearchRoute select(String prompt) {
    final text = prompt.trim().toLowerCase();
    // A studio selection is an explicit contract, not a keyword suggestion.
    for (final f in ResearchFormat.values) {
      if (text.contains('format "${f.id}"')) {
        return ResearchRoute(
          f.title,
          'Selected explicitly by you.',
          format: f,
          explicit: true,
        );
      }
    }
    if (RegExp(
      r'\b(plain text|no (?:cards|tables)|one sentence|code only|just the (?:answer|code))\b',
    ).hasMatch(text)) {
      return const ResearchRoute(
        'Direct answer',
        'Your explicit formatting preference takes priority.',
        explicit: true,
      );
    }
    if (text.startsWith('/')) {
      return const ResearchRoute(
        'Trader skill',
        'Use the selected skill and its output requirements.',
        explicit: true,
      );
    }
    if (RegExp(
      r'\b(write|debug|fix|generate)\b.*\b(code|script|function|sql|python|dart)\b',
    ).hasMatch(text)) {
      return const ResearchRoute(
        'Code & explanation',
        'Use language-tagged code blocks and a concise explanation.',
      );
    }
    ResearchFormat? best;
    var score = 0;
    for (final entry in _patterns.entries) {
      final match = RegExp(entry.value, caseSensitive: false).firstMatch(text);
      if (match != null && match.group(0)!.length > score) {
        score = match.group(0)!.length;
        best = ResearchFormat.values.firstWhere((f) => f.id == entry.key);
      }
    }
    if (best != null) {
      return ResearchRoute(
        best.title,
        'Matched the analytical task in your question.',
        format: best,
      );
    }
    for (final entry in _native) {
      if (RegExp(entry.$1, caseSensitive: false).hasMatch(text)) {
        return ResearchRoute(
          entry.$2,
          'Matched the topic and useful result structure.',
          nativeCard: entry.$3,
        );
      }
    }
    return const ResearchRoute(
      'Auto format',
      'Adapt the answer to the question and conversation context.',
    );
  }

  static const _native = <(String, String, String)>[
    (r'\b(earnings|eps|quarterly results)\b', 'Earnings report', 'earnings'),
    (
      r'\b(latest news|headlines|breaking news|news today)\b',
      'News digest',
      'news',
    ),
    (r'\b(compare|comparison|versus|vs\.?)\b', 'Comparison', 'compare'),
    (
      r'\b(financial statements|income statement|financials)\b',
      'Financial statements',
      'financials',
    ),
    (
      r'\b(analyst ratings|price targets|consensus ratings)\b',
      'Analyst consensus',
      'ratings',
    ),
    (
      r'\b(cpi|inflation|fomc|central bank|rbi|macro)\b',
      'Macro briefing',
      'macro',
    ),
    (r'\b(who is|biography|career)\b', 'Person profile', 'person'),
    (
      r'\b(company overview|company profile|research .*company)\b',
      'Company dossier',
      'company',
    ),
    (
      r'\b(screen stocks|stock screener|top gainers|top losers)\b',
      'Market screener',
      'screener',
    ),
    (
      r'\b(sentiment|options flow|put.call ratio)\b',
      'Sentiment & flow',
      'sentiment',
    ),
  ];

  static const _patterns = <String, String>{
    'evidence_map': r'\b(evidence map|map .*claims? to|trace .*evidence)\b',
    'claim_check': r'\b(fact.check|verify .*claims?|is .*claim true)\b',
    'source_conflicts':
        r'\b(conflicting sources|sources disagree|contradictory reports)\b',
    'source_quality':
        r'\b(source quality|source credibility|reliable sources)\b',
    'freshness_audit':
        r'\b(freshness audit|outdated|stale data|check latest|update this answer)\b',
    'primary_sources':
        r'\b(primary.source brief|original sources|primary sources only)\b',
    'assumptions': r'\b(assumptions|assumption ledger)\b',
    'unknowns': r'\b(unknowns|missing facts|data gaps)\b',
    'counterevidence':
        r'\b(counterevidence|counterarguments|evidence against)\b',
    'research_plan': r'\b(research plan|plan .*research|investigation plan)\b',
    'session_brief':
        r'\b(market briefing|session brief|market today|today.s market|market open|market close)\b',
    'overnight_changes': r'\b(overnight|since yesterday|since .*close)\b',
    'catalyst_radar':
        r'\b(upcoming catalysts|catalyst radar|upcoming events)\b',
    'sector_rotation': r'\b(sector rotation|sector performance)\b',
    'cross_asset': r'\b(cross.asset|across asset classes)\b',
    'liquidity': r'\b(liquidity|market depth|bid.ask spread)\b',
    'volatility':
        r'\b(volatility regime|implied volatility|realized volatility)\b',
    'breadth': r'\b(market breadth|advance.decline|market participation)\b',
    'event_reaction': r'\b(event reaction|reaction to|post.event)\b',
    'weekly_outlook': r'\b(week.ahead|weekly outlook|next week)\b',
    'business_model':
        r'\b(business model|revenue streams|how .*makes? money)\b',
    'revenue_bridge':
        r'\b(revenue bridge|revenue drivers|decompose .*growth)\b',
    'margin_bridge': r'\b(margin bridge|margin drivers|margin changes)\b',
    'cash_quality': r'\b(cash.flow quality|cash conversion|earnings quality)\b',
    'balance_sheet': r'\b(balance.sheet|debt maturities|cash runway)\b',
    'valuation_sensitivity':
        r'\b(valuation sensitivity|dcf|discounted cash flow)\b',
    'peer_benchmark': r'\b(peer benchmark|compare .*peers|peer comparison)\b',
    'capital_allocation': r'\b(capital allocation|buybacks|dividend policy)\b',
    'management_execution':
        r'\b(management execution|management track record|management commitments)\b',
    'filing_changes':
        r'\b(filing changes|compare .*filings|changes in .*10.k)\b',
    'risk_register':
        r'\b(risk register|risk review|risk assessment|biggest risks|key risks)\b',
    'scenario_tree':
        r'\b(scenarios|scenario tree|bull.base.bear|upside and downside)\b',
    'stress_test': r'\b(stress.test|stress testing|shock .*portfolio)\b',
    'invalidation': r'\b(invalidation|invalidate .*thesis|thesis breaks)\b',
    'position_sizing':
        r'\b(position siz(?:e|ing)|size .*position|risk budget)\b',
    'concentration': r'\b(concentration|concentrated portfolio)\b',
    'drawdown': r'\b(drawdown|recovery period)\b',
    'correlation': r'\b(correlation|diversification)\b',
    'hedge_tradeoffs': r'\b(hedg(?:e|ing)|hedge tradeoffs)\b',
    'pre_mortem': r'\b(pre.mortem|how .*could fail)\b',
    'trade_debrief':
        r'\b(trade debrief|review my trade|analyze my trade|post.trade review)\b',
    'execution_audit': r'\b(execution audit|slippage|planned vs actual)\b',
    'mistake_patterns':
        r'\b(mistake patterns|repeated mistakes|recurring mistakes)\b',
    'discipline': r'\b(discipline|rule adherence|follow .*rules)\b',
    'setup_playbook': r'\b(setup playbook|trading playbook|setup rules)\b',
    'entry_checklist': r'\b(pre.entry|entry checklist|before entering)\b',
    'exit_plan': r'\b(exit plan|exit rules|plan .*exit)\b',
    'weekly_review':
        r'\b(weekly review|review .*week.*trades|weekly journal)\b',
    'behavior_bias': r'\b(behavioral bias|revenge trading|overtrading|fomo)\b',
    'experiment_design': r'\b(experiment|backtest design|test .*hypothesis)\b',
    'executive_brief': r'\b(executive brief|summari[sz]e|summary|tl;?dr)\b',
    'beginner_guide': r'\b(beginner|eli5|explain simply|first principles)\b',
    'expert_brief': r'\b(expert brief|technical deep dive|advanced analysis)\b',
    'decision_matrix': r'\b(decision matrix|which should i|help me choose)\b',
    'concept_glossary': r'\b(glossary|define .*terms|terminology)\b',
    'worked_example':
        r'\b(worked example|step.by.step calculation|show .*calculation)\b',
    'myth_fact': r'\b(myth|misconceptions)\b',
    'cause_effect': r'\b(cause.and.effect|causal mechanism|causation)\b',
    'action_brief': r'\b(action plan|next steps|what should i do next)\b',
    'questions_to_ask':
        r'\b(questions to ask|what should i ask|unresolved questions)\b',
  };
}
