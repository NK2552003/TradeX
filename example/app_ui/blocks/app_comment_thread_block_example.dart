import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AppCommentThreadBlockExampleView extends StatelessWidget {
  const AppCommentThreadBlockExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppCommentThreadBlock Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiCard(title: 'AppCommentThreadBlock', child: Text('Comment Thread Block')),
        ],
      ),
    );
  }
}
