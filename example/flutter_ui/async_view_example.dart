import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class AsyncViewExampleView extends StatelessWidget {
  const AsyncViewExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiAsyncView - Async State Loader', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiAsyncViewStateCard(
            title: 'Market Depth & Orderbook',
            subtitle: 'Unified controller for loading, error, empty, and data states',
            contentBuilder: (ctx) => const UiCard(
              title: 'Live Orderbook Data Loaded',
              subtitle: 'Depth: 250 levels • Refresh rate: 100ms',
              child: Text('Market data stream is active.'),
            ),
          ),
        ],
      ),
    );
  }
}
