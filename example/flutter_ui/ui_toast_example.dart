import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class UiToastExampleView extends StatelessWidget {
  const UiToastExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiToast Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiButton(label: 'Show Toast', variant: UiVariant.outline, onPressed: () {}),
        ],
      ),
    );
  }
}
