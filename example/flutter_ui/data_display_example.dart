import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Examples for Data Display components (Avatar, MetricCard, Table, Callout, Tracker, BarList).
class DataDisplayExampleView extends StatelessWidget {
  const DataDisplayExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Avatars & Badges', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          Row(
            children: const <Widget>[
              UiAvatar(name: 'Nitish Kumar', size: UiSize.sm),
              SizedBox(width: 12),
              UiAvatar(name: 'Nitish Kumar', size: UiSize.md),
              SizedBox(width: 12),
              UiAvatar(name: 'Nitish Kumar', size: UiSize.lg),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),
          Text('Callout Banner', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiCallout(
            title: 'Market Hours Alert',
            message: 'US Equities market opens in 45 minutes. Ensure open orders are reviewed.',
            intent: UiIntent.info,
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),
          Text('Metric Cards & KPIs', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          Row(
            children: <Widget>[
              const Expanded(
                child: UiMetricCard(
                  label: 'Net Profit',
                  value: '\$14,250.00',
                  delta: 18.4,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              const Expanded(
                child: UiMetricCard(
                  label: 'Max Drawdown',
                  value: '-\$1,200.00',
                  delta: -2.1,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),
          Text('Data Table', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiTable<Map<String, dynamic>>(
            rows: const <Map<String, dynamic>>[
              {'symbol': 'AAPL', 'qty': 150, 'avg': 210.40, 'pnl': 2400.0},
              {'symbol': 'NVDA', 'qty': 200, 'avg': 118.20, 'pnl': 3360.0},
              {'symbol': 'MSFT', 'qty': 80, 'avg': 440.10, 'pnl': -620.0},
            ],
            columns: <UiTableColumn<Map<String, dynamic>>>[
              UiTableColumn<Map<String, dynamic>>(
                header: 'Symbol',
                cell: (ctx, row) => Text(row['symbol'] as String, style: ctx.uiText.bodyStrong),
              ),
              UiTableColumn<Map<String, dynamic>>(
                header: 'Quantity',
                cell: (ctx, row) => Text('${row['qty']}'),
              ),
              UiTableColumn<Map<String, dynamic>>(
                header: 'Avg Price',
                cell: (ctx, row) => Text('\$${(row['avg'] as double).toStringAsFixed(2)}'),
              ),
              UiTableColumn<Map<String, dynamic>>(
                header: 'P/L',
                cell: (ctx, row) {
                  final double pnl = row['pnl'] as double;
                  return Text(
                    '${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
                    style: TextStyle(color: pnl >= 0 ? ctx.uiColors.bullish : ctx.uiColors.bearish),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
