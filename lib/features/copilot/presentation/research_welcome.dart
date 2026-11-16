import 'package:flutter/material.dart';

import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../models/research_format.dart';

class ResearchWelcome extends StatelessWidget {
  const ResearchWelcome({
    super.key,
    required this.onPrompt,
    required this.onFormats,
    required this.onSkills,
  });
  final ValueChanged<String> onPrompt;
  final VoidCallback onFormats;
  final VoidCallback onSkills;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final featured = [
      'session_brief',
      'evidence_map',
      'scenario_tree',
      'trade_debrief',
    ];
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xl)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            child: UiBadge(
              label: 'ALPHAJOURNAL / RESEARCH',
              icon: Icons.travel_explore,
              variant: UiBadgeVariant.soft,
              intent: UiIntent.primary,
            ),
          ),
          UiGap.v(theme.spacing.lg),
          Text(
            'A sharper question.\nA clearer edge.',
            textAlign: TextAlign.center,
            style: context.uiText.display.copyWith(
              height: 1.12,
              letterSpacing: -1,
            ),
          ),
          UiGap.v(theme.spacing.md),
          Text(
            'Explore the markets. Follow the evidence.\nTurn your research into a plan you can explain.',
            textAlign: TextAlign.center,
            style: context.uiText.body.copyWith(
              color: theme.colors.foregroundMuted,
              height: 1.6,
            ),
          ),
          UiGap.v(theme.spacing.lg),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: context.sp(theme.spacing.sm),
            runSpacing: context.sp(theme.spacing.sm),
            children: [
              UiButton(
                label: 'Explore 60 research formats',
                icon: Icons.auto_awesome_outlined,
                variant: UiVariant.soft,
                onPressed: onFormats,
              ),
              UiButton(
                label: 'Trader skills',
                icon: Icons.bolt_outlined,
                variant: UiVariant.ghost,
                onPressed: onSkills,
              ),
            ],
          ),
          UiGap.v(theme.spacing.xl),
          Text(
            'START WITH A QUESTION',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
              letterSpacing: 1.4,
            ),
          ),
          UiGap.v(theme.spacing.sm),
          for (final id in featured)
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
              child: UiCard(
                variant: UiCardVariant.outlined,
                density: UiDensity.compact,
                onTap: () => onPrompt(
                  ResearchFormat.values
                      .firstWhere((f) => f.id == id)
                      .prompt('the topic I describe below'),
                ),
                child: Row(
                  children: [
                    Icon(
                      switch (id) {
                        'session_brief' => Icons.public,
                        'evidence_map' => Icons.fact_check_outlined,
                        'scenario_tree' => Icons.account_tree_outlined,
                        _ => Icons.menu_book_outlined,
                      },
                      size: context.sz(22),
                      color: theme.colors.primary,
                    ),
                    UiGap.h(theme.spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ResearchFormat.values
                                .firstWhere((f) => f.id == id)
                                .title,
                            style: context.uiText.label,
                          ),
                          UiGap.v(theme.spacing.xxs),
                          Text(
                            switch (id) {
                              'session_brief' =>
                                'What changed, why it matters, and what comes next.',
                              'evidence_map' =>
                                'Trace the claims. Examine the evidence.',
                              'scenario_tree' =>
                                'Explore the upside, downside, and what would change your mind.',
                              _ => 'Find the lesson behind the outcome.',
                            },
                            style: context.uiText.caption.copyWith(
                              color: theme.colors.foregroundMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    UiGap.h(theme.spacing.sm),
                    Icon(
                      Icons.north_east,
                      size: context.sz(16),
                      color: theme.colors.foregroundSubtle,
                    ),
                  ],
                ),
              ),
            ),
          UiGap.v(theme.spacing.md),
          Text(
            'Current questions use date-aware research when web search is enabled.',
            textAlign: TextAlign.center,
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
        ],
      ),
    );
  }
}
