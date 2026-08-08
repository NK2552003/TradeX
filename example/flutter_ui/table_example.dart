import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class TableExampleView extends StatelessWidget {
  const TableExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiTable - Data Grid View', style: context.uiText.heading),
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
