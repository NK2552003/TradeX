import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AppChatThreadBlockExampleView extends StatelessWidget {
  const AppChatThreadBlockExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppChatThreadBlock Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiCard(title: 'AppChatThreadBlock', child: Text('Chat Thread Block')),
        ],
      ),
    );
  }
}
