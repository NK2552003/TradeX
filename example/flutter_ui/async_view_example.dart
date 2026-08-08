import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class AsyncViewExampleView extends StatelessWidget {
  const AsyncViewExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiAsyncView - Async State Loader', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiAsyncView(
            builder: (ctx) => const Text('Content loaded successfully!'),
          ),
        ],
      ),
    );
  }
}
