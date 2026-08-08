import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class UiToggleExampleView extends StatelessWidget {
  const UiToggleExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiToggle Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiToggleGroup<String>(value: '1D', options: const <UiToggleOption<String>>[UiToggleOption(value: '1D', label: '1D')]),
        ],
      ),
    );
  }
}
