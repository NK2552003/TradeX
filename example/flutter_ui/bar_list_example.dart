import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class BarListExampleView extends StatelessWidget {
  const BarListExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiBarList - Horizontal Bar Distribution', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiBarList(
            items: <UiBarListItem>[
              UiBarListItem(label: 'Equities', value: 55000),
              UiBarListItem(label: 'Crypto', value: 25000),
              UiBarListItem(label: 'Commodities', value: 15000),
            ],
          ),
        ],
      ),
    );
  }
}
