import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/mock_data.dart';

class PortfolioPage extends StatelessWidget {
  const PortfolioPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Portfolio Dashboard',
                    style: context.uiText.display.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Text(
                    'Aggregate performance, equity curve & risk analytics',
                    style: context.uiText.body.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
              const UiBadge(
                label: '1M Performance',
                intent: UiIntent.primary,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // KPI Stats Row
          Row(
            children: [
              const Expanded(
                child: UiMetricCard(
                  label: 'Net Worth',
                  value: '\$124,500.00',
                  delta: 14250,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              const Expanded(
                child: UiMetricCard(
                  label: 'Win Rate',
                  value: '68.4%',
                  delta: 4.2,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              const Expanded(
                child: UiMetricCard(
                  label: 'Max Drawdown',
                  value: '-4.2%',
                  delta: -4.2,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Area Chart Card: Portfolio Equity Curve
          UiAreaChartCard(
            title: 'Equity Growth Curve',
            subtitle: 'Net portfolio account equity over time',
            metricValue: '\$124,500.00',
            metricChange: '+12.4%',
            isBullish: true,
            data: const [
              UiChartPoint(label: 'Jan', values: [100000]),
              UiChartPoint(label: 'Feb', values: [104500]),
              UiChartPoint(label: 'Mar', values: [102000]),
              UiChartPoint(label: 'Apr', values: [111000]),
              UiChartPoint(label: 'May', values: [118400]),
              UiChartPoint(label: 'Jun', values: [115000]),
              UiChartPoint(label: 'Jul', values: [124500]),
            ],
            series: [
              UiChartSeries(
                name: 'Net Equity',
                color: theme.colors.bullish,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Win Rate & Best Trade highlights
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: AppWinRateCard(
                  winRate: 68.4,
                  wins: 28,
                  losses: 12,
                  breakeven: 3,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              Expanded(
                child: AppExtremeTradeCard(
                  trade: aaplTrade,
                  best: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
