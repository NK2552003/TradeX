import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class UiTabNavigationExampleView extends StatelessWidget {
  const UiTabNavigationExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiTabNavigation Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiTabBar(items: const <UiTabItem>[UiTabItem(label: 'Nav Tab', content: SizedBox.shrink())], selectedIndex: 0, onChanged: (i) {}),
        ],
      ),
    );
  }
}
