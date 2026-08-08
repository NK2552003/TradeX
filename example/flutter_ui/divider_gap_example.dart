import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class DividerGapExampleView extends StatelessWidget {
  const DividerGapExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Foundational Layout Elements (UiLabel, UiGap, UiDivider)', style: context.uiText.heading),
          const UiGap.v(16),
          const UiLabel(text: 'Stock Symbol Ticker'),
          const UiGap.v(8),
          const UiDivider(),
        ],
      ),
    );
  }
}
