import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class AccordionExampleView extends StatelessWidget {
  const AccordionExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiAccordion - Expandable Panels', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiAccordion(
            items: <UiAccordionItem>[
              UiAccordionItem(
                title: 'Risk Management Guidelines',
                subtitle: 'Max 2% portfolio risk per trade setup',
                leadingIcon: Icons.shield_outlined,
                content: Text('Cut losses at predetermined stop-loss levels. Always verify risk-reward ratio exceeds 1:2.'),
              ),
              UiAccordionItem(
                title: 'Pre-Market Checklist',
                subtitle: 'Technical & Macro confirmation',
                leadingIcon: Icons.checklist_outlined,
                content: Text('Check economic news events, sector strength, market futures, and daily support/resistance.'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
