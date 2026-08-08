import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class MarqueeExampleView extends StatelessWidget {
  const MarqueeExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiMarquee - Scrolling Ticker Bar', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiMarquee(
            children: <Widget>[
              Text('AAPL +1.8%'),
              Text('NVDA +4.2%'),
              Text('TSLA -2.1%'),
              Text('BTC/USD \$64,200'),
            ],
          ),
        ],
      ),
    );
  }
}
