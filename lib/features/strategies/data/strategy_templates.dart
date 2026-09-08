import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/markdown_kit/markdown_kit.dart';

/// The shapes a new playbook can start from.
///
/// A playbook is not a note about a strategy — it is the strategy, written down
/// tightly enough that a future trade can be checked against it. That means every
/// template here asks the same four unavoidable questions: what makes this a
/// setup, where does the risk sit, when do I get out, and what would tell me the
/// edge has stopped working. The headings are fixed so a library of thirty
/// playbooks can be read side by side.
///
/// Performance is never templated. Win rate, average R and the equity curve are
/// aggregated from the journal entries filed under the playbook, so a template
/// that seeded them would be putting a claim in the trader's mouth.
@immutable
class AppStrategyTemplate {
  const AppStrategyTemplate({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.body,
    this.nameHint = '',
    this.summaryHint,
    this.category,
    this.tags = const <String>[],
    this.intent = UiIntent.primary,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;

  /// The markdown the editor opens with.
  final String body;

  /// Pre-fills the name field. Empty on the blank template so the editor's own
  /// "Name this playbook" prompt is what the trader sees first.
  final String nameHint;

  /// Pre-fills the one-paragraph pitch shown on library cards.
  final String? summaryHint;
  final String? category;
  final List<String> tags;

  /// Tints the tile in the gallery so eight options are distinguishable without
  /// reading eight labels.
  final UiIntent intent;

  /// The unsaved playbook this template represents.
  ///
  /// `id` is empty: the repository assigns one on `create`, which is the line
  /// between a draft the trader can still walk away from and a record that
  /// exists. Status starts at [AppStrategyStatus.draft] for the same reason — a
  /// playbook is not live until its author says so.
  AppStrategy toDraft() {
    final DateTime now = DateTime.now();
    return AppStrategy(
      id: '',
      name: nameHint,
      summary: summaryHint,
      category: category,
      content: body,
      status: AppStrategyStatus.draft,
      tags: tags,
      createdAt: now,
      updatedAt: now,
    ).withDerivedCounts();
  }
}

/// The library the "New playbook" gallery renders.
class StrategyTemplates {
  const StrategyTemplates._();

  static const AppStrategyTemplate blank = AppStrategyTemplate(
    id: 'blank',
    label: 'Blank playbook',
    description: 'An empty page and the version history switched on.',
    icon: Icons.article_outlined,
    body: '',
    intent: UiIntent.neutral,
  );

  static const AppStrategyTemplate rulesBased = AppStrategyTemplate(
    id: 'rules-based',
    label: 'Rule-based setup',
    description:
        'The default. Trigger, invalidation, risk and exits — everything a '
        'trade can be graded against.',
    icon: Icons.rule_folder_outlined,
    tags: <String>['setup'],
    category: 'Systematic',
    summaryHint: null,
    body:
        '## In one line\n\n'
        'What this playbook trades, and why the edge exists.\n\n'
        '## Market and instruments\n\n'
        '| Field | Value |\n'
        '| --- | --- |\n'
        '| Instruments | `\$TICKER` |\n'
        '| Timeframe |  |\n'
        '| Session | Regular hours |\n'
        '| Direction | Long and short |\n\n'
        '## Conditions that must be true\n\n'
        '- [ ] \n'
        '- [ ] \n\n'
        '## Entry trigger\n\n'
        'The specific event that puts the order in. If two traders read this, '
        'they should enter on the same candle.\n\n'
        '## Invalidation\n\n'
        'What makes the setup void *before* entry, and what voids the thesis '
        'after.\n\n'
        '## Risk\n\n'
        '| Field | Value |\n'
        '| --- | --- |\n'
        '| Risk per trade | 1% of equity |\n'
        '| Stop placement | Structural, not a fixed distance |\n'
        '| Max open positions | 2 |\n'
        '| Max losers per day | 2 |\n\n'
        '## Exits\n\n'
        '- First target: \n'
        '- Runner: \n'
        '- Time stop: \n\n'
        '## Pre-trade checklist'
        '${MarkdownSnippets.riskChecklistTemplate}'
        '## When to retire this\n\n'
        'The number that would tell me the edge is gone — not a feeling.\n',
  );

  static const AppStrategyTemplate breakout = AppStrategyTemplate(
    id: 'breakout',
    label: 'Breakout / momentum',
    description:
        'Level, confirmation and the failed-break rule that keeps a breakout '
        'playbook from becoming a chase.',
    icon: Icons.trending_up_rounded,
    tags: <String>['breakout', 'momentum'],
    category: 'Momentum',
    intent: UiIntent.bullish,
    body:
        '## The level\n\n'
        'How the level is drawn, and how far back it has to hold to count.\n\n'
        '## Confirmation\n\n'
        '| Field | Value |\n'
        '| --- | --- |\n'
        '| Close beyond level | Required |\n'
        '| Volume | Above the 20-period average |\n'
        '| Retest | Optional / required |\n'
        '| Max extension at entry | 1 ATR |\n\n'
        '## Entry\n\n'
        '## Failed break rule\n\n'
        'A break that closes back inside the range is the strongest signal in '
        'this playbook — and it is a signal to be flat, not to reverse. Say '
        'explicitly which it is here.\n\n'
        '## Stop and targets\n\n'
        '| Field | Value |\n'
        '| --- | --- |\n'
        '| Stop | Back inside the range |\n'
        '| Target 1 | Measured move |\n'
        '| Target 2 | Trail below structure |\n\n'
        '## What kills this setup\n\n'
        '- Chop: repeated breaks with no follow-through\n'
        '- Gap opens through the level\n'
        '- Event risk inside the hold period\n\n'
        '## Checklist\n\n'
        '- [ ] Level held at least twice before this attempt\n'
        '- [ ] Entry is within 1 ATR of the level\n'
        '- [ ] Stop is at the level, not at a round number\n',
  );

  static const AppStrategyTemplate meanReversion = AppStrategyTemplate(
    id: 'mean-reversion',
    label: 'Mean reversion',
    description:
        'Stretch, anchor and the trend filter that stops a fade from standing '
        'in front of a freight train.',
    icon: Icons.multiline_chart_rounded,
    tags: <String>['reversion', 'fade'],
    category: 'Mean reversion',
    intent: UiIntent.info,
    body:
        '## The anchor\n\n'
        'The mean being reverted to — VWAP, a moving average, a value area.\n\n'
        '## What counts as stretched\n\n'
        '| Field | Value |\n'
        '| --- | --- |\n'
        '| Distance from anchor | 2 standard deviations |\n'
        '| Consecutive closes away | 3 |\n'
        '| Volume profile | Declining into the extreme |\n\n'
        '## Trend filter\n\n'
        'The rule that keeps this out of trends. A fade taken inside a strong '
        'trend is a different trade with a different expectancy — name the '
        'filter and honour it.\n\n'
        '## Entry\n\n'
        '## Stop\n\n'
        'Beyond the extreme, sized so the anchor can be reached without the '
        'stop being hit first.\n\n'
        '## Exit\n\n'
        '- Primary: the anchor\n'
        '- Partial: halfway back\n'
        '- Time stop: reversion that has not started within N bars is not '
        'coming\n\n'
        '## Failure mode\n\n'
        'This playbook has a high win rate and a fat left tail. Write down the '
        'loss that would be unacceptable, then size for it.\n',
  );

  static const AppStrategyTemplate optionsIncome = AppStrategyTemplate(
    id: 'options-income',
    label: 'Options income',
    description:
        'Strike selection, defined risk and the adjustment ladder, written '
        'before the position needs one.',
    icon: Icons.calculate_outlined,
    tags: <String>['options', 'income'],
    category: 'Options',
    intent: UiIntent.warning,
    body:
        '## Structure\n\n'
        '| Field | Value |\n'
        '| --- | --- |\n'
        '| Strategy | Credit spread / iron condor / covered call |\n'
        '| Underlyings | `\$TICKER` |\n'
        '| DTE at entry | 30–45 |\n'
        '| Target credit |  |\n'
        '| Max loss per position |  |\n\n'
        '## Entry conditions\n\n'
        '- [ ] IV rank above \n'
        '- [ ] No earnings inside the holding period\n'
        '- [ ] Liquidity: spread under \n\n'
        '## Strike selection\n\n'
        'The rule, not the example. Delta, expected move, or a level.\n\n'
        '## Management\n\n'
        '| Trigger | Action |\n'
        '| --- | --- |\n'
        '| 50% of credit captured | Close |\n'
        '| Short strike tested | Roll or close |\n'
        '| 21 DTE | Close regardless |\n'
        '| Loss at 2x credit | Close |\n\n'
        '## Adjustments\n\n'
        'Every adjustment is a new trade with a new thesis. List the ones this '
        'playbook allows, and refuse the rest.\n\n'
        '## Assignment plan\n\n'
        'What happens if the short leg is assigned — before it is.\n',
  );

  static const AppStrategyTemplate systematic = AppStrategyTemplate(
    id: 'systematic',
    label: 'Systematic / backtested',
    description:
        'For a mechanical system: parameters, backtest results and the '
        'live-versus-test comparison.',
    icon: Icons.query_stats_rounded,
    tags: <String>['systematic', 'backtest'],
    category: 'Systematic',
    body:
        '## Logic\n\n'
        '```\n'
        'entry:  \n'
        'exit:   \n'
        'filter: \n'
        '```\n\n'
        '## Parameters\n\n'
        '| Parameter | Value | Sensitivity |\n'
        '| --- | --- | --- |\n'
        '|  |  |  |\n\n'
        '## Backtest\n\n'
        '| Metric | In sample | Out of sample |\n'
        '| --- | --- | --- |\n'
        '| Trades |  |  |\n'
        '| Win rate |  |  |\n'
        '| Average R |  |  |\n'
        '| Max drawdown |  |  |\n'
        '| Profit factor |  |  |\n\n'
        '## Assumptions that could be wrong\n\n'
        '- Slippage: \n'
        '- Fills at the tested price: \n'
        '- Survivorship in the sample: \n\n'
        '## Live versus test\n\n'
        'The journal fills this in. If live win rate drifts more than N points '
        'from the backtest over M trades, the system goes back to testing.\n\n'
        '## Kill switch\n\n'
        '- [ ] Drawdown beyond \n'
        '- [ ] N consecutive losers\n'
        '- [ ] Regime change: \n',
  );

  static const AppStrategyTemplate riskFramework = AppStrategyTemplate(
    id: 'risk-framework',
    label: 'Risk framework',
    description:
        'Not a setup — the sizing and loss limits every other playbook '
        'inherits.',
    icon: Icons.shield_outlined,
    tags: <String>['risk', 'process'],
    category: 'Risk',
    intent: UiIntent.danger,
    body:
        '## Account limits\n\n'
        '| Limit | Value |\n'
        '| --- | --- |\n'
        '| Risk per trade | 1% |\n'
        '| Risk per setup per day | 2% |\n'
        '| Daily stop | 3% |\n'
        '| Weekly stop | 6% |\n'
        '| Max portfolio heat | 6% |\n\n'
        '## Sizing rule\n\n'
        'Position size = risk budget ÷ (entry − stop). Never the other way '
        'round: the stop is decided by the chart, the size by arithmetic.\n\n'
        '## Correlation\n\n'
        'Two positions in the same sector are one position for the purposes of '
        'these limits.\n\n'
        '## After a loss\n\n'
        '- [ ] No re-entry on the same instrument for N minutes\n'
        '- [ ] Size down until the next win\n'
        '- [ ] Two losers ends the session\n\n'
        '## After a win\n\n'
        'The dangerous half of the day. Say what does *not* change.\n\n'
        '## Review cadence\n\n'
        'These numbers are revised monthly against the journal, never mid-'
        'session.\n',
  );

  static const AppStrategyTemplate journalDriven = AppStrategyTemplate(
    id: 'from-journal',
    label: 'Extracted from the journal',
    description:
        'For a pattern the journal already shows. Starts with the evidence, '
        'then writes the rules.',
    icon: Icons.auto_awesome_outlined,
    tags: <String>['discovered'],
    category: 'Discovered',
    intent: UiIntent.info,
    body:
        '## The pattern I noticed\n\n'
        'Describe what keeps happening, in the words the entries used.\n\n'
        '## Evidence\n\n'
        'Link the entries that show it — the winners and the losers. A playbook '
        'built only on the trades that worked is a story, not an edge.\n\n'
        '| Entry | Outcome | What it shows |\n'
        '| --- | --- | --- |\n'
        '|  |  |  |\n\n'
        '## Rules, as far as the evidence supports them\n\n'
        '- [ ] \n\n'
        '## What is still a guess\n\n'
        'The part with three trades behind it, not thirty.\n\n'
        '## Test plan\n\n'
        '| Field | Value |\n'
        '| --- | --- |\n'
        '| Sample needed | 20 trades |\n'
        '| Size while testing | Quarter risk |\n'
        '| Promote to live if |  |\n'
        '| Abandon if |  |\n',
  );

  /// Blank first, then the setups a trader is most likely to be writing, then
  /// the two that support the rest.
  static const List<AppStrategyTemplate> all = <AppStrategyTemplate>[
    blank,
    rulesBased,
    breakout,
    meanReversion,
    optionsIncome,
    systematic,
    riskFramework,
    journalDriven,
  ];

  static AppStrategyTemplate byId(String id) => all.firstWhere(
    (AppStrategyTemplate t) => t.id == id,
    orElse: () => blank,
  );
}
