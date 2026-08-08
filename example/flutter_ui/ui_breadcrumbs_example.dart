import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class UiBreadcrumbsExampleView extends StatelessWidget {
  const UiBreadcrumbsExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiBreadcrumbs Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiBreadcrumbs(crumbs: const <UiCrumb>[UiCrumb(label: 'Home'), UiCrumb(label: 'Journal')]),
        ],
      ),
    );
  }
}
