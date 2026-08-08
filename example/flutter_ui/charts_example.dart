import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Examples for Charts & Data Visualization components (Candlesticks, Sparkline, Donut, Line/Area, Graph Canvas).
class ChartsExampleView extends StatelessWidget {
  const ChartsExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final sampleCandles = <UiCandle>[
      UiCandle(time: DateTime.now().subtract(const Duration(days: 4)), open: 120, high: 125, low: 118, close: 124, volume: 1500),
      UiCandle(time: DateTime.now().subtract(const Duration(days: 3)), open: 124, high: 128, low: 123, close: 127, volume: 1800),
      UiCandle(time: DateTime.now().subtract(const Duration(days: 2)), open: 127, high: 130, low: 125, close: 126, volume: 1200),
      UiCandle(time: DateTime.now().subtract(const Duration(days: 1)), open: 126, high: 135, low: 126, close: 134, volume: 2400),
      UiCandle(time: DateTime.now(), open: 134, high: 138, low: 132, close: 137, volume: 2100),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Candlestick & OHLC Price Chart', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiCard(
            title: 'NVDA - 1D Candlestick Chart',
            child: UiCandleChart(
              candles: sampleCandles,
              height: 220,
              showVolume: true,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),
          Text('Donut Chart & Portfolio Allocation', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiCard(
            title: 'Asset Allocation',
            child: SizedBox(
              height: 180,
              child: UiDonutChart(
                slices: const <UiDonutSlice>[
                  UiDonutSlice(label: 'Equities', value: 55, color: Colors.blue),
                  UiDonutSlice(label: 'Crypto', value: 25, color: Colors.purple),
                  UiDonutSlice(label: 'Cash', value: 20, color: Colors.green),
                ],
              ),
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),
          Text('Sparkline Chart', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiCard(
            title: 'Equity Curve',
            child: UiSparkChart(
              values: <double>[1000, 1050, 1030, 1120, 1100, 1250, 1280],
              height: 80,
            ),
          ),
        ],
      ),
    );
  }
}
