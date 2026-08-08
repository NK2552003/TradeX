import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class UiRadioCardGroupExampleView extends StatelessWidget {
  const UiRadioCardGroupExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiRadioCardGroup Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiRadioCardGroup<String>(value: 'usd', options: const <UiOption<String>>[UiOption(value: 'usd', label: 'USD Order')]),
        ],
      ),
    );
  }
}
