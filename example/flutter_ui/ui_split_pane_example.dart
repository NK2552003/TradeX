import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class UiSplitPaneExampleView extends StatelessWidget {
  const UiSplitPaneExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiSplitPane Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const SizedBox(height: 100, child: UiSplitPane(primary: Center(child: Text('Left')), detail: Center(child: Text('Right')))),
        ],
      ),
    );
  }
}
