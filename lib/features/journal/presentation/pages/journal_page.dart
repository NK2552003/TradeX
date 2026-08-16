import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/mock_data.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  String _searchQuery = '';
  AppOutcome? _selectedOutcome;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final trades = [aaplTrade, tslaTrade, msftTrade];

    final filteredTrades = trades.where((t) {
      final matchesQuery = _searchQuery.isEmpty ||
          t.ticker.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.tags.any((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()));
      final matchesOutcome = _selectedOutcome == null || t.outcome == _selectedOutcome;
      return matchesQuery && matchesOutcome;
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header title & action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trading Journal',
                    style: context.uiText.display.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Text(
                    'Track executions, trade psychology & metrics',
                    style: context.uiText.body.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
              UiButton(
                label: 'Log Trade',
                leadingIcon: Icons.add,
                variant: UiVariant.primary,
                intent: UiIntent.primary,
                onPressed: () {
                  UiToast.show(
                    context,
                    title: 'New Trade Log',
                    message: 'Trade entry form opened',
                    intent: UiIntent.info,
                  );
                },
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Key Stats Summary Cards
          Row(
            children: [
              const Expanded(
                child: UiMetricCard(
                  label: 'Total Trades',
                  value: '3',
                  delta: 12,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              const Expanded(
                child: UiMetricCard(
                  label: 'Win Rate',
                  value: '66.7%',
                  delta: 4.2,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              const Expanded(
                child: UiMetricCard(
                  label: 'Net PnL',
                  value: '\$558.00',
                  delta: 558,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Journal Filter Block
          AppJournalFilterBlock(
            query: _searchQuery,
            outcome: _selectedOutcome,
            onQueryChanged: (q) => setState(() => _searchQuery = q),
            onOutcomeChanged: (o) => setState(() => _selectedOutcome = o),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),

          // Trade List Block
          AppTradeListBlock(
            trades: filteredTrades,
            onTradeTap: (trade) {
              UiToast.show(
                context,
                title: 'Trade Selected',
                message: '${trade.ticker} ${trade.side.name.toUpperCase()} entry selected',
                intent: UiIntent.primary,
              );
            },
          ),
        ],
      ),
    );
  }
}
