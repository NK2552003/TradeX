import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/markdown_kit/markdown_kit.dart';

/// The shapes a journal entry can start from.
///
/// A blank editor is the reason journals die. The trader who just closed a loser
/// does not want to design a document; they want to answer three questions and
/// leave. Every template here is those questions already typed, with the headings
/// a future review will search for, so the entry is consistent without anyone
/// having to remember a house style.
///
/// A template only supplies the *words*. Numbers stay empty on purpose: entry,
/// stop, size and outcome are collected by the editor's fields, and a template
/// that pre-filled them with zeros would put fabricated prices into the journal.
@immutable
class AppJournalTemplate {
  const AppJournalTemplate({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.body,
    this.titleHint = '',
    this.tags = const <String>[],
    this.side = AppSide.long,
    this.intent = UiIntent.primary,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;

  /// The markdown the editor opens with.
  final String body;

  /// Pre-fills the headline. Left empty on the blank template so the entry falls
  /// back to `AppTrade.displayTitle` (`RELIANCE long`) until the trader names it.
  final String titleHint;
  final List<String> tags;

  /// Which way the template assumes the trade went on. Only a default — the
  /// editor's side control overrides it.
  final AppSide side;

  /// Tints the tile in the gallery so the options are distinguishable at a
  /// glance rather than by reading eight labels.
  final UiIntent intent;

  /// The unsaved entry this template represents.
  ///
  /// `id` is empty: the repository assigns one on `create`, which is what marks
  /// the difference between a draft the trader can still abandon and a record
  /// that exists.
  AppTrade toDraft() {
    final DateTime now = DateTime.now();
    return AppTrade(
      id: '',
      ticker: '',
      side: side,
      entry: 0,
      exit: null,
      openedAt: now,
      outcome: AppOutcome.open,
      title: titleHint,
      content: body,
      tags: tags,
      updatedAt: now,
    ).withDerivedCounts();
  }
}

/// The library the "New entry" gallery renders.
class JournalTemplates {
  const JournalTemplates._();

  static const AppJournalTemplate blank = AppJournalTemplate(
    id: 'blank',
    label: 'Blank entry',
    description: 'Just the numbers and an empty page.',
    icon: Icons.article_outlined,
    body: '',
    intent: UiIntent.neutral,
  );

  static const AppJournalTemplate review = AppJournalTemplate(
    id: 'trade-review',
    label: 'Trade review',
    description:
        'The full post-mortem: thesis, execution, and the one thing to do '
        'differently.',
    icon: Icons.fact_check_outlined,
    titleHint: '',
    tags: <String>['review'],
    body:
        '## Thesis\n\n'
        'What made this a trade? Name the setup and what would have '
        'invalidated it.\n\n'
        '## The trade'
        '${MarkdownSnippets.tradeSetupTemplate}'
        '## How it actually went\n\n'
        '- Entry: did I take the trigger, or chase it?\n'
        '- Management: what did I do while it was on?\n'
        '- Exit: plan, stop, target, or nerves?\n\n'
        '## Verdict\n\n'
        '- [ ] Followed the plan\n'
        '- [ ] Sized correctly\n'
        '- [ ] Would take this again\n\n'
        '## One thing to change\n\n',
  );

  static const AppJournalTemplate livePosition = AppJournalTemplate(
    id: 'open-position',
    label: 'Live position',
    description:
        'Log the plan before the outcome exists, so the review cannot be '
        'rewritten by hindsight.',
    icon: Icons.play_circle_outline_rounded,
    tags: <String>['open'],
    body:
        '## Why I am in\n\n'
        '## The plan'
        '${MarkdownSnippets.tradeSetupTemplate}'
        '## Management rules\n\n'
        '- [ ] Move the stop only when structure moves\n'
        '- [ ] Take partials at the first target\n'
        '- [ ] Exit if the thesis breaks, not if the price wobbles\n\n'
        '## What would make me wrong\n\n',
  );

  static const AppJournalTemplate mistake = AppJournalTemplate(
    id: 'mistake-log',
    label: 'Mistake log',
    description:
        'For the trade you should not have taken. Names the rule, the trigger '
        'and the cost.',
    icon: Icons.report_problem_outlined,
    tags: <String>['mistake', 'discipline'],
    intent: UiIntent.warning,
    body:
        '## What I did\n\n'
        '## The rule I broke\n\n'
        '## What set it off\n\n'
        'Boredom, revenge, FOMO, a tip, a news headline — be specific and be '
        'honest.\n\n'
        '## What it cost\n\n'
        '| Cost | Amount |\n'
        '| --- | --- |\n'
        '| Money |  |\n'
        '| R |  |\n'
        '| Rest of the session |  |\n\n'
        '## The guard rail\n\n'
        '- [ ] \n',
  );

  static const AppJournalTemplate planVsActual = AppJournalTemplate(
    id: 'plan-vs-actual',
    label: 'Plan vs actual',
    description:
        'A two-column comparison for when the trade worked but the process '
        'did not.',
    icon: Icons.compare_arrows_rounded,
    tags: <String>['process'],
    intent: UiIntent.info,
    body:
        '## Side by side\n\n'
        '| | Planned | Actual |\n'
        '| --- | --- | --- |\n'
        '| Entry |  |  |\n'
        '| Stop |  |  |\n'
        '| Target |  |  |\n'
        '| Size |  |  |\n'
        '| Hold time |  |  |\n\n'
        '## Where they diverged\n\n'
        '## Was the deviation right?\n\n'
        'A profitable deviation is still a broken process. Say which this was.\n\n'
        '## Checklist'
        '${MarkdownSnippets.riskChecklistTemplate}',
  );

  static const AppJournalTemplate chartReview = AppJournalTemplate(
    id: 'chart-review',
    label: 'Chart review',
    description: 'Screenshot first: mark the levels, then write what you saw.',
    icon: Icons.candlestick_chart_outlined,
    tags: <String>['chart'],
    body:
        '## The chart\n\n'
        'Paste or attach the screenshot here, marked up with entry, stop and '
        'target.\n\n'
        '## Levels that mattered\n\n'
        '| Level | Price | Why |\n'
        '| --- | --- | --- |\n'
        '|  |  |  |\n\n'
        '## What the tape said\n\n'
        '## What I would look for next time\n\n',
  );

  static const AppJournalTemplate scaleOut = AppJournalTemplate(
    id: 'scale-out',
    label: 'Scaled exit',
    description:
        'For positions closed in pieces — one row per fill, so the average is '
        'auditable.',
    icon: Icons.stacked_line_chart_rounded,
    tags: <String>['execution'],
    body:
        '## Fills\n\n'
        '| # | Date | Price | Qty | Reason |\n'
        '| --- | --- | --- | --- | --- |\n'
        '| 1 |  |  |  | Entry |\n'
        '| 2 |  |  |  | Partial |\n'
        '| 3 |  |  |  | Runner |\n\n'
        '## Was the ladder planned?\n\n'
        '## Did scaling help or cost?\n\n',
  );

  /// Blank first, then the two everyday entries, then the diagnostics.
  static const List<AppJournalTemplate> all = <AppJournalTemplate>[
    blank,
    review,
    livePosition,
    mistake,
    planVsActual,
    chartReview,
    scaleOut,
  ];

  static AppJournalTemplate byId(String id) =>
      all.firstWhere((AppJournalTemplate t) => t.id == id, orElse: () => blank);
}
