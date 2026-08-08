import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class SplitPaneExampleView extends StatelessWidget {
  const SplitPaneExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 300,
      child: UiSplitPane(
        primary: Center(child: Text('Left Pane: Watchlist & Tickers')),
        detail: Center(child: Text('Right Pane: Candlestick Chart & Details')),
      ),
    );
  }
}
