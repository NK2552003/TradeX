import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/markdown_kit/markdown_kit.dart';

/// A starting point for a new note.
///
/// The gallery exists because a blank markdown page is the single biggest
/// reason a note app goes unused: someone who has never written markdown has
/// nothing to copy. Every template lands as ordinary GFM the editor and the
/// preview already understand, so a template is a head start, not a mode.
@immutable
class AppNoteTemplate {
  const AppNoteTemplate({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.noteType,
    required this.body,
    this.titleHint = '',
    this.tags = const <String>[],
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final AppNoteType noteType;

  /// Markdown pre-filled into the body.
  final String body;

  /// Pre-filled title. Empty means "let the writer name it".
  final String titleHint;
  final List<String> tags;

  /// An unsaved [AppNote] with this template applied. The repository assigns the
  /// real id on create, so the draft carries an empty one.
  AppNote toDraft() {
    final DateTime now = DateTime.now();
    return AppNote(
      id: '',
      title: titleHint,
      content: body,
      createdAt: now,
      updatedAt: now,
      noteType: noteType,
      tags: tags,
    ).withDerivedCounts();
  }
}

class NoteTemplates {
  const NoteTemplates._();

  static const AppNoteTemplate blank = AppNoteTemplate(
    id: 'blank',
    label: 'Blank note',
    description: 'Start from nothing',
    icon: Icons.article_outlined,
    noteType: AppNoteType.general,
    body: '',
  );

  static const List<AppNoteTemplate> all = <AppNoteTemplate>[
    blank,
    AppNoteTemplate(
      id: 'trade-plan',
      label: 'Trade plan',
      description: 'Entry, stop, target and the trigger — before you click buy',
      icon: Icons.flag_outlined,
      noteType: AppNoteType.plan,
      titleHint: 'Trade plan — ',
      tags: <String>['plan'],
      body:
          '## The setup\n\nWhat you see and why it matters.\n'
          '${MarkdownSnippets.tradeSetupTemplate}'
          '## Invalidation\n\nWhat would tell you this idea is wrong.\n\n'
          '## Checklist\n${MarkdownSnippets.riskChecklistTemplate}',
    ),
    AppNoteTemplate(
      id: 'pre-market',
      label: 'Pre-market plan',
      description: 'Bias, key levels, watchlist and rules for the session',
      icon: Icons.wb_twilight_rounded,
      noteType: AppNoteType.plan,
      titleHint: 'Pre-market — ',
      tags: <String>['premarket', 'routine'],
      body: MarkdownSnippets.preMarketTemplate,
    ),
    AppNoteTemplate(
      id: 'trade-review',
      label: 'Trade review',
      description: 'Post-mortem on one trade, execution scored separately',
      icon: Icons.rate_review_outlined,
      noteType: AppNoteType.review,
      titleHint: 'Review — ',
      tags: <String>['review'],
      body:
          '## What I saw\n\n\n\n'
          '## What I did\n\n\n\n'
          '## What the market did\n\n\n\n'
          '## Was the process right?\n\n'
          '> A loss on a good process is not a mistake. A win on a bad one is.\n\n'
          '| Dimension | Score /5 |\n'
          '| --- | --- |\n'
          '| Entry timing |  |\n'
          '| Sizing |  |\n'
          '| Stop discipline |  |\n'
          '| Exit |  |\n\n'
          '## One thing to change\n\n- [ ] \n\n',
    ),
    AppNoteTemplate(
      id: 'weekly-review',
      label: 'Weekly review',
      description: 'What worked, what did not, and next week',
      icon: Icons.event_note_outlined,
      noteType: AppNoteType.review,
      titleHint: 'Week of ',
      tags: <String>['review', 'weekly'],
      body: MarkdownSnippets.weeklyReviewTemplate,
    ),
    AppNoteTemplate(
      id: 'idea',
      label: 'Strategy idea',
      description: 'A hypothesis with the test that would falsify it',
      icon: Icons.lightbulb_outline_rounded,
      noteType: AppNoteType.idea,
      tags: <String>['idea'],
      body:
          '## Hypothesis\n\n\n\n'
          '## Why it might work\n\n- \n\n'
          '## How I would test it\n\n'
          '- [ ] Define the entry precisely\n'
          '- [ ] Define the exit precisely\n'
          '- [ ] Sample size and period\n'
          '- [ ] What result would kill it\n\n'
          '## Notes\n\n',
    ),
    AppNoteTemplate(
      id: 'analysis',
      label: 'Chart analysis',
      description: 'Levels table, a chart block and the conclusion',
      icon: Icons.query_stats_rounded,
      noteType: AppNoteType.analysis,
      tags: <String>['analysis'],
      body:
          '## Context\n\n\n\n'
          '## Levels\n\n'
          '| Level | Price | Note |\n'
          '| --- | --- | --- |\n'
          '| Supply | 0.00 |  |\n'
          '| Demand | 0.00 |  |\n\n'
          '## Read\n\n'
          '${MarkdownSnippets.chartTemplate}'
          '## Conclusion\n\n',
    ),
    AppNoteTemplate(
      id: 'cheat-sheet',
      label: 'Cheat sheet',
      description: 'Rules you keep forgetting, in one scannable page',
      icon: Icons.menu_book_outlined,
      noteType: AppNoteType.cheatSheet,
      tags: <String>['rules'],
      body:
          '## Non-negotiables\n\n'
          '- [ ] Risk per trade under 1%\n'
          '- [ ] Stop set before entry\n'
          '- [ ] No revenge trades\n\n'
          '## Position sizing\n\n'
          'Risk 1% of equity, so size = risk / (entry − stop).\n\n'
          '\$\$\nsize = \\frac{0.01 \\times equity}{|entry - stop|}\n\$\$\n\n'
          '## Session notes\n\n'
          '| Session | Behaviour |\n'
          '| --- | --- |\n'
          '| Open | Widest spreads, fastest moves |\n'
          '| Midday | Chop — stand down |\n'
          '| Close | Trend resolution |\n\n',
    ),
  ];

  static AppNoteTemplate byId(String id) => all.firstWhere(
    (AppNoteTemplate t) => t.id == id,
    orElse: () => blank,
  );
}
