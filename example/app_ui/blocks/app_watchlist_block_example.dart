import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AppWatchlistBlockExampleView extends StatelessWidget {
  const AppWatchlistBlockExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppWatchlistBlock Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const AppWatchlistBlock(tickers: <AppTicker>[AppTicker(symbol: 'AAPL', name: 'Apple', price: 224.5, changePercent: 1.8)]),
        ],
      ),
    );
  }
}
