import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class UiSelectNativeExampleView extends StatelessWidget {
  const UiSelectNativeExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiSelectNative Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiSelectNative<String>(value: 'usd', options: const <UiOption<String>>[UiOption(value: 'usd', label: 'USD Native')], onChanged: (v) {}),
        ],
      ),
    );
  }
}
