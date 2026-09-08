/// Comprehensive user guides for Linked Strategies, Journal, and Notes.
///
/// Provides step-by-step onboarding flows with contextual guidance
/// for each of the three core features.

import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../components/components.dart';

/// Guide steps for Linked Strategies feature.
class AppStrategiesGuide {
  const AppStrategiesGuide._();

  static List<AppGuideStep> get steps => <AppGuideStep>[
    AppGuideStep(
      title: 'Define Your Trading Playbook',
      description: 'Start by creating a strategy that captures your trading approach. A well-defined playbook includes clear entry rules, risk management, and exit criteria.',
      tips: <String>[
        'Use templates to get started quickly',
        'Be specific about entry conditions',
        'Define your risk before entering trades',
      ],
    ),
    AppGuideStep(
      title: 'Set Clear Rules & Criteria',
      description: 'Document your entry signals, position sizing, stop-loss levels, and profit targets. The more precise your rules, the easier it is to follow them consistently.',
      tips: <String>[
        'Include specific price patterns or indicators',
        'Define exact position sizing rules',
        'Set clear invalidation criteria',
      ],
    ),
    AppGuideStep(
      title: 'Connect to Journal Entries',
      description: 'Link your executed trades to this strategy to track performance. This creates a feedback loop between your plan and actual execution.',
      tips: <String>[
        'File every trade under the relevant strategy',
        'Review linked trades regularly',
        'Update strategy based on real results',
      ],
    ),
    AppGuideStep(
      title: 'Monitor & Adjust',
      description: 'Track your strategy\'s win rate, P/L, and other metrics. Use this data to refine your approach or retire underperforming playbooks.',
      tips: <String>[
        'Review performance weekly',
        'Look for patterns in losing trades',
        "Don't be afraid to retire strategies that don't work",
      ],
    ),
  ];

  static String get title => 'Linked Strategies';
  static String get description => 'Where you define your playbooks and rules first.';
  static String get emptyTitle => 'No playbooks yet';
  static String get emptyDescription => 'Create your first trading strategy to start tracking your approach systematically.';
  static String get emptyAction => '+ New Playbook';
}

/// Guide steps for Linked Journal feature.
class AppJournalGuide {
  const AppJournalGuide._();

  static List<AppGuideStep> get steps => <AppGuideStep>[
    AppGuideStep(
      title: 'Execute Based on Strategies',
      description: 'When you take a trade, log it in your journal. Select the strategy you\'re following to maintain the connection between plan and execution.',
      tips: <String>[
        'Log trades immediately after execution',
        'Always link to the relevant strategy',
        'Include entry price and position size',
      ],
    ),
    AppGuideStep(
      title: 'Log Entry & Exit Points',
      description: 'Record all the details: entry price, exit price, position size, fees, and outcome. Complete data enables accurate performance analysis.',
      tips: <String>[
        'Include all costs and fees',
        'Note the R-multiple for each trade',
        'Add screenshots if helpful',
      ],
    ),
    AppGuideStep(
      title: 'Record Performance Metrics',
      description: 'Your journal automatically calculates P/L, win rate, and R-multiples. Review these metrics to understand your edge.',
      tips: <String>[
        'Focus on R-multiples, not just money',
        'Track both winning and losing trades',
        'Look for patterns across multiple trades',
      ],
    ),
    AppGuideStep(
      title: 'Link to Notes & Reflections',
      description: 'Connect journal entries to notes for deeper analysis. Document what worked, what didn\'t, and lessons learned for continuous improvement.',
      tips: <String>[
        'Write notes while the trade is fresh',
        'Tag notes for easy retrieval',
        'Review notes before similar setups',
      ],
    ),
  ];

  static String get title => 'Linked Journal';
  static String get description => 'Where you execute and log the trades based on those strategies.';
  static String get emptyTitle => 'No trades logged yet';
  static String get emptyDescription => 'Start logging your trades to build a comprehensive performance history.';
  static String get emptyAction => '+ Log Trade';
}

/// Guide steps for Linked Notes feature.
class AppNotesGuide {
  const AppNotesGuide._();

  static List<AppGuideStep> get steps => <AppGuideStep>[
    AppGuideStep(
      title: 'Review Trade Executions',
      description: 'Notes let you reflect on your trades beyond the numbers. Analyze what went well, what didn\'t, and how you can improve.',
      tips: <String>[
        'Review trades within 24 hours',
        'Focus on process, not outcome',
        'Identify recurring mistakes',
      ],
    ),
    AppGuideStep(
      title: 'Tag Important Insights',
      description: 'Use tags to categorize your notes by setup type, mistake pattern, market condition, or any system that helps you find insights quickly.',
      tips: <String>[
        'Use consistent tagging conventions',
        'Tag by emotional state when relevant',
        'Create tags for common patterns',
      ],
    ),
    AppGuideStep(
      title: 'Reflect on Strategy Effectiveness',
      description: 'Connect notes to strategies to document what\'s working and what needs adjustment. This creates a knowledge base for continuous improvement.',
      tips: <String>[
        'Link notes to specific strategies',
        'Document rule violations and why they happened',
        'Track improvements over time',
      ],
    ),
    AppGuideStep(
      title: 'Create Actionable Improvements',
      description: 'Turn insights into action items. Update your strategies, adjust your process, or create new rules based on what you\'ve learned.',
      tips: <String>[
        'End each note with an action item',
        'Review old notes before trading sessions',
        'Share insights with your trading community',
      ],
    ),
  ];

  static String get title => 'Linked Notes';
  static String get description => 'Where you review, tag, and reflect on the execution.';
  static String get emptyTitle => 'No notes yet';
  static String get emptyDescription => 'Create your first note to start building your trading knowledge base.';
  static String get emptyAction => '+ New Note';
}

/// Combined guide manager for all three features.
class AppFeatureGuides {
  const AppFeatureGuides._();

  /// Shows the appropriate guide based on feature type
  static Future<void> showGuide(
    BuildContext context, {
    required AppFeatureType featureType,
    VoidCallback? onComplete,
  }) async {
    final List<AppGuideStep> steps;
    final String title;
    final String description;

    switch (featureType) {
      case AppFeatureType.strategies:
        steps = AppStrategiesGuide.steps;
        title = AppStrategiesGuide.title;
        description = AppStrategiesGuide.description;
      case AppFeatureType.journal:
        steps = AppJournalGuide.steps;
        title = AppJournalGuide.title;
        description = AppJournalGuide.description;
      case AppFeatureType.notes:
        steps = AppNotesGuide.steps;
        title = AppNotesGuide.title;
        description = AppNotesGuide.description;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AppFeatureGuide(
        title: title,
        description: description,
        steps: steps,
        onComplete: onComplete ?? () {},
        featureKey: featureType.name,
      ),
    );
  }

  /// Returns empty state widget for the given feature
  static Widget buildEmptyState(
    BuildContext context, {
    required AppFeatureType featureType,
    VoidCallback? onAction,
  }) {
    String title;
    String description;
    IconData icon;
    String actionText;

    switch (featureType) {
      case AppFeatureType.strategies:
        title = AppStrategiesGuide.emptyTitle;
        description = AppStrategiesGuide.emptyDescription;
        icon = Icons.auto_graph;
        actionText = AppStrategiesGuide.emptyAction;
      case AppFeatureType.journal:
        title = AppJournalGuide.emptyTitle;
        description = AppJournalGuide.emptyDescription;
        icon = Icons.journal;
        actionText = AppJournalGuide.emptyAction;
      case AppFeatureType.notes:
        title = AppNotesGuide.emptyTitle;
        description = AppNotesGuide.emptyDescription;
        icon = Icons.note;
        actionText = AppNotesGuide.emptyAction;
    }

    return AppEmptyStateGuide(
      title: title,
      description: description,
      icon: icon,
      primaryAction: UiButton(
        label: actionText,
        variant: UiVariant.filled,
        onPressed: onAction,
      ),
      secondaryAction: UiButton(
        label: 'View Guide',
        variant: UiVariant.outline,
        onPressed: () => showGuide(
          context,
          featureType: featureType,
        ),
      ),
    );
  }
}

/// Feature type enum for guide selection
enum AppFeatureType {
  strategies,
  journal,
  notes,
}

extension on AppFeatureType {
  String get name {
    switch (this) {
      case AppFeatureType.strategies:
        return 'strategies';
      case AppFeatureType.journal:
        return 'journal';
      case AppFeatureType.notes:
        return 'notes';
    }
  }
}
