import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AppWatchlistCardExampleView extends StatelessWidget {
  const AppWatchlistCardExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AppWatchlistCard Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const AppTickerCard(ticker: AppTicker(symbol: 'AAPL', name: 'Apple Inc.', price: 224.5, changePercent: 1.8)),
        ],
      ),
    );
  }
}
