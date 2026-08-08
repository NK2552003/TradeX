import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class UiTabsExampleView extends StatelessWidget {
  const UiTabsExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiTabs Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiTabs(items: const <UiTabItem>[UiTabItem(label: 'Overview', content: Text('Tab Panel'))], initialIndex: 0, onChanged: (i) {}),
        ],
      ),
    );
  }
}
