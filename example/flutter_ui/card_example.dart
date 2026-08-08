import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class CardExampleView extends StatelessWidget {
  const CardExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiCard & UiCardGrid - Modular Surface Layouts', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiCard(
            title: 'Primary Surface Card',
            subtitle: 'Standard panel container',
            child: Text('Card contents rendered inside standard surface container.'),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiCardGrid(
            children: const <Widget>[
              UiCard(title: 'Tile 1', child: Text('Grid Tile Content 1')),
              UiCard(title: 'Tile 2', child: Text('Grid Tile Content 2')),
            ],
          ),
        ],
      ),
    );
  }
}
