import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class JournalBlocksExampleView extends StatelessWidget {
  const JournalBlocksExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppJournalFilterBlock Example', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const AppJournalFilterBlock(
            query: 'NVDA',
            outcome: AppOutcome.win,
          ),
        ],
      ),
    );
  }
}
