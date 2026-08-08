import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AppSearchBlockExampleView extends StatelessWidget {
  const AppSearchBlockExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppSearchBlock Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          AppSearchBlock(query: 'NVDA', results: const <AppSearchResult>[AppSearchResult(id: 'r1', title: 'NVDA Trade', kind: AppSearchKind.trade)], onQueryChanged: (q) {}),
        ],
      ),
    );
  }
}
