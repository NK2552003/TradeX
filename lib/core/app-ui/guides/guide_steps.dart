import 'feature_guide.dart';

/// Guide steps — the copy and shape of the three feature walkthroughs.
///
/// The walkthroughs mirror the one flow the three features share:
/// **Define → Execute → Review**. Strategies steps define the playbooks,
/// journal steps execute them, and notes steps review the execution — so a
/// trader finishing any one guide has met the other two features by the last
/// step.
///
/// All guide strings live here, never in screens. Steps are plain data: the
/// owning screen receives them through [FeatureGuideBanner] /
/// [FeatureGuideSheet] and resolves each step's [FeatureGuideStep.actionLabel]
/// into real navigation via `onStepAction`. Nothing in this file opens a
/// screen, resolves a record, or knows a route.

/// One step of a feature walkthrough.
///
/// [title] and [why] are presentation copy; [actionLabel] names the real
/// in-app action the step describes. A step without an action is still worth
/// reading — it just has no button.
class FeatureGuideStep {
  const FeatureGuideStep({
    required this.id,
    required this.title,
    required this.why,
    this.actionLabel,
  });

  /// Stable identifier, used for analytics and step lookups — never rendered.
  final String id;

  /// The step heading, short enough to read in one glance.
  final String title;

  /// The one "why it matters" line under the heading.
  final String why;

  /// Label for the step's primary action button, or null for a read-only
  /// step. The owning screen decides what the button does.
  final String? actionLabel;

  bool get hasAction => actionLabel != null && actionLabel!.trim().isNotEmpty;
}

/// The ready-made walkthroughs, one per guided feature.
abstract final class FeatureGuideSteps {
  /// Strategies — *define* the playbooks: template → rules → testing →
  /// journaling → the record.
  static const List<FeatureGuideStep> strategies = <FeatureGuideStep>[
    FeatureGuideStep(
      id: 'template',
      title: 'Start from a template in the playbook gallery',
      why:
          'A proven structure beats a blank page — adapt the setup you keep '
          'repeating instead of inventing rules you will not follow.',
      actionLabel: 'Open the gallery',
    ),
    FeatureGuideStep(
      id: 'rules',
      title:
          'Write your rules (entry, invalidation, stop, sizing, exit) '
          'and save as Draft',
      why:
          'A playbook only proves itself if the rules were written before the '
          'trade, so the journal can score exactly what you promised to do.',
      actionLabel: 'Write the rules',
    ),
    FeatureGuideStep(
      id: 'testing',
      title: 'Promote to Testing when you start trading it',
      why:
          'Testing is where the journal starts building the playbook\'s '
          'record — real trades, sized small, scored honestly.',
      actionLabel: 'Promote to Testing',
    ),
    FeatureGuideStep(
      id: 'file-entries',
      title: 'File journal entries under the playbook while testing',
      why:
          'Every entry filed under the playbook is one more data point in its '
          'win rate; unfiled trades teach nobody.',
      actionLabel: 'Open the journal',
    ),
    FeatureGuideStep(
      id: 'live',
      title: 'Review the record and promote to Live',
      why:
          'The record decides, not the feeling — promote to Live only when '
          'the numbers have earned it over enough trades.',
      actionLabel: 'Review the record',
    ),
  ];

  /// Journal — *execute* the playbooks: log → file → checklist → attach →
  /// outcome.
  static const List<FeatureGuideStep> journal = <FeatureGuideStep>[
    FeatureGuideStep(
      id: 'log',
      title: 'Log the trade as you take it or right after the close',
      why:
          'Memory edits trades to flatter you; a log written at the desk is '
          'the only version worth reviewing later.',
      actionLabel: 'Log a trade',
    ),
    FeatureGuideStep(
      id: 'file',
      title: 'File it under the playbook you followed',
      why:
          'Filing is what turns a pile of trades into one playbook\'s track '
          'record — the playbook page updates as you go.',
      actionLabel: 'File under a playbook',
    ),
    FeatureGuideStep(
      id: 'checklist',
      title: 'Fill the checklist and psychology sections honestly',
      why:
          'The checklist catches process errors while they are cheap; the '
          'psychology score is how you notice the ones you keep repeating.',
      actionLabel: 'Fill the checklist',
    ),
    FeatureGuideStep(
      id: 'attach',
      title: 'Attach screenshots and tag it',
      why:
          'The chart you saw and the tags you will search for later are what '
          'keep an entry retrievable a month on.',
      actionLabel: 'Attach and tag',
    ),
    FeatureGuideStep(
      id: 'outcome',
      title: 'Mark the outcome — the playbook\'s record updates itself',
      why:
          'Win rate, average R and the equity curve are computed from '
          'outcomes, never typed in by hand.',
      actionLabel: 'Mark the outcome',
    ),
  ];

  /// Notes — *review* the execution: write → link → tag → tighten → revisit.
  static const List<FeatureGuideStep> notes = <FeatureGuideStep>[
    FeatureGuideStep(
      id: 'review',
      title: 'Write the review note after your session',
      why:
          'The same day you still know why you entered; by next week you only '
          'remember the result.',
      actionLabel: 'Write the review',
    ),
    FeatureGuideStep(
      id: 'link',
      title: 'Link it to the trade and the playbook it discusses',
      why:
          'Links are what make a note useful elsewhere — the trade page and '
          'the playbook page pick it up automatically.',
      actionLabel: 'Link the note',
    ),
    FeatureGuideStep(
      id: 'tags',
      title: 'Tag it (ticker, mistake, lesson) so it is findable',
      why:
          'A note you cannot find on the next setup is a note you never '
          'wrote.',
      actionLabel: 'Add tags',
    ),
    FeatureGuideStep(
      id: 'refactor',
      title: 'Use the AI refactor to tighten your writing',
      why:
          'A sharp sentence gets reread; a wall of text gets skipped exactly '
          'when you need it.',
      actionLabel: 'Refactor with AI',
    ),
    FeatureGuideStep(
      id: 'weekly',
      title: 'Revisit weekly using tag filters',
      why:
          'Lessons compound when they are re-read before the session, not '
          'after it.',
      actionLabel: 'Review weekly',
    ),
  ];

  /// The ready-made walkthrough for [feature].
  static List<FeatureGuideStep> forFeature(FeatureId feature) =>
      switch (feature) {
        FeatureId.strategies => strategies,
        FeatureId.journal => journal,
        FeatureId.notes => notes,
      };

  /// The sheet/banner heading for [feature]. Screens pass this to
  /// [FeatureGuideSheet.show] as its `title`.
  static String title(FeatureId feature) => switch (feature) {
    FeatureId.strategies => 'Playbook guide',
    FeatureId.journal => 'Journal guide',
    FeatureId.notes => 'Notes guide',
  };
}
