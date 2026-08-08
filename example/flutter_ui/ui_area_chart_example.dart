import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Professional Level Area Chart Showcase featuring interactive controls,
/// metric headers, multi-series comparison, and reusable component integration.
class UiAreaChartExampleView extends StatefulWidget {
  const UiAreaChartExampleView({super.key});

  @override
  State<UiAreaChartExampleView> createState() => _UiAreaChartExampleViewState();
}

class _UiAreaChartExampleViewState extends State<UiAreaChartExampleView> {
  // Sample timeframe datasets for the interactive card
  final Map<String, List<UiChartPoint>> _timeframeData = {
    '1D': const <UiChartPoint>[
      UiChartPoint(label: '09:30', values: <double>[138200]),
      UiChartPoint(label: '11:00', values: <double>[139100]),
      UiChartPoint(label: '12:30', values: <double>[138800]),
      UiChartPoint(label: '14:00', values: <double>[141200]),
      UiChartPoint(label: '16:00', values: <double>[142850]),
    ],
    '1W': const <UiChartPoint>[
      UiChartPoint(label: 'Mon', values: <double>[132000]),
      UiChartPoint(label: 'Tue', values: <double>[134500]),
      UiChartPoint(label: 'Wed', values: <double>[133800]),
      UiChartPoint(label: 'Thu', values: <double>[138900]),
      UiChartPoint(label: 'Fri', values: <double>[142850]),
    ],
    '1M': const <UiChartPoint>[
      UiChartPoint(label: 'Week 1', values: <double>[125000]),
      UiChartPoint(label: 'Week 2', values: <double>[128400]),
      UiChartPoint(label: 'Week 3', values: <double>[135100]),
      UiChartPoint(label: 'Week 4', values: <double>[142850]),
    ],
    '1Y': const <UiChartPoint>[
      UiChartPoint(label: 'Q1', values: <double>[100000]),
      UiChartPoint(label: 'Q2', values: <double>[112000]),
      UiChartPoint(label: 'Q3', values: <double>[128000]),
      UiChartPoint(label: 'Q4', values: <double>[142850]),
    ],
    'ALL': const <UiChartPoint>[
      UiChartPoint(label: '2023', values: <double>[80000]),
      UiChartPoint(label: '2024', values: <double>[110000]),
      UiChartPoint(label: '2025', values: <double>[130000]),
      UiChartPoint(label: '2026', values: <double>[142850]),
    ],
  };

  String _activeTf = '1M';

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final List<UiChartPoint> activePoints =
        _timeframeData[_activeTf] ?? _timeframeData['1M']!;

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiAreaChart Showcase & Options', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            'Professional level financial area charts with interactive option controls, rich gradient fills, metric headers, and multi-series support.',
            style: context.uiText.caption
                .copyWith(color: theme.colors.foregroundMuted),
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // 1. Interactive Area Chart Card with Timeframe Controls & Options
          UiAreaChartCard(
            title: 'Portfolio Performance',
            subtitle: 'Real-time equity growth and active drawdown tracking',
            metricValue: '\$142,850.50',
            metricChange: '+14.28% (\$17,850)',
            isBullish: true,
            initialTimeframe: _activeTf,
            timeframes: const <String>['1D', '1W', '1M', '1Y', 'ALL'],
            onTimeframeChanged: (tf) => setState(() => _activeTf = tf),
            data: activePoints,
            series: const <UiChartSeries>[
              UiChartSeries(
                name: 'Equity',
                color: Color(0xFF6366F1),
                lineGlow: true,
              ),
            ],
            height: 220,
            valueFormatter: (v) => '\$${(v / 1000).toStringAsFixed(1)}k',
          ),

          SizedBox(height: context.sp(theme.spacing.xl)),

          // 2. Multi-Series Layered Comparison Area Chart
          UiCard(
            title: 'Strategy Benchmark Comparison',
            subtitle: 'Multi-series layered area chart (Alpha Fund vs S&P 500)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                UiAreaChart(
                  height: 220,
                  data: const <UiChartPoint>[
                    UiChartPoint(label: 'Jan', values: <double>[100000, 100000]),
                    UiChartPoint(label: 'Feb', values: <double>[108000, 103000]),
                    UiChartPoint(label: 'Mar', values: <double>[105000, 101000]),
                    UiChartPoint(label: 'Apr', values: <double>[116000, 106000]),
                    UiChartPoint(label: 'May', values: <double>[124000, 109000]),
                    UiChartPoint(label: 'Jun', values: <double>[121000, 108000]),
                    UiChartPoint(label: 'Jul', values: <double>[135000, 114000]),
                  ],
                  series: const <UiChartSeries>[
                    UiChartSeries(
                      name: 'Alpha Strategy Fund',
                      color: Color(0xFF6366F1),
                      fillOpacity: 0.30,
                      lineGlow: true,
                    ),
                    UiChartSeries(
                      name: 'S&P 500 Benchmark',
                      color: Color(0xFF10B981),
                      fillOpacity: 0.15,
                    ),
                  ],
                  showLegend: true,
                  toggleableLegend: true,
                  valueFormatter: (v) => '\$${(v / 1000).toStringAsFixed(0)}k',
                ),
              ],
            ),
          ),

          SizedBox(height: context.sp(theme.spacing.xl)),

          // 3. Custom Dual Gradient & Data Dots Area Chart
          UiCard(
            title: 'Crypto Basket Volatility',
            subtitle: 'Custom gradient colors, marker dots & precision crosshair',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                UiAreaChart(
                  height: 200,
                  data: const <UiChartPoint>[
                    UiChartPoint(label: 'Mon', values: <double>[42000]),
                    UiChartPoint(label: 'Tue', values: <double>[44800]),
                    UiChartPoint(label: 'Wed', values: <double>[43500]),
                    UiChartPoint(label: 'Thu', values: <double>[47900]),
                    UiChartPoint(label: 'Fri', values: <double>[46200]),
                    UiChartPoint(label: 'Sat', values: <double>[51200]),
                    UiChartPoint(label: 'Sun', values: <double>[53500]),
                  ],
                  series: const <UiChartSeries>[
                    UiChartSeries(
                      name: 'BTC/USD',
                      color: Color(0xFFF59E0B),
                      gradientColors: <Color>[
                        Color(0x66F59E0B),
                        Color(0x00F59E0B),
                      ],
                      showDots: true,
                      lineGlow: true,
                    ),
                  ],
                  showDots: true,
                  showGrid: true,
                  valueFormatter: (v) => '\$${v.toStringAsFixed(0)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
