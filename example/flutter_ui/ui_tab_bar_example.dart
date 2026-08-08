import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class UiTabBarExampleView extends StatelessWidget {
  const UiTabBarExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiTabBar Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiTabBar(items: const <UiTabItem>[UiTabItem(label: 'Tab 1', content: SizedBox.shrink())], selectedIndex: 0, onChanged: (i) {}),
        ],
      ),
    );
  }
}
