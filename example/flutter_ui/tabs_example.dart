import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class TabsExampleView extends StatefulWidget {
  const TabsExampleView({super.key});

  @override
  State<TabsExampleView> createState() => _TabsExampleViewState();
}

class _TabsExampleViewState extends State<TabsExampleView> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiTabs & UiTabBar', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiTabs(
            items: const <UiTabItem>[
              UiTabItem(label: 'Overview', content: Text('Overview Tab Content')),
              UiTabItem(label: 'Analytics', content: Text('Analytics Tab Content')),
              UiTabItem(label: 'Settings', content: Text('Settings Tab Content')),
            ],
            initialIndex: _index,
            onChanged: (i) => setState(() => _index = i),
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),
          UiTabBar(
            items: const <UiTabItem>[
              UiTabItem(label: 'Journal Logs', content: SizedBox.shrink()),
              UiTabItem(label: 'Strategy Rules', content: SizedBox.shrink()),
            ],
            selectedIndex: _index,
            onChanged: (i) => setState(() => _index = i),
          ),
        ],
      ),
    );
  }
}
