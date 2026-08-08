import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AppFeedBlockExampleView extends StatelessWidget {
  const AppFeedBlockExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppFeedBlock Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          AppFeedBlock(posts: <AppPost>[AppPost(id: 'p1', author: const AppTrader(id: 'u1', handle: '@nitish'), body: 'NVDA entry logged.', createdAt: DateTime.now())]),
        ],
      ),
    );
  }
}
