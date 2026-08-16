import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/mock_data.dart';

class StrategiesPage extends StatefulWidget {
  const StrategiesPage({super.key});

  @override
  State<StrategiesPage> createState() => _StrategiesPageState();
}

class _StrategiesPageState extends State<StrategiesPage> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final strategies = [mockStrategy, mockStrategy2];

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
                    'Strategy Playbooks',
                    style: context.uiText.display.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Text(
                    'Document, analyze, and version control your trading strategies',
                    style: context.uiText.body.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
              UiButton(
                label: 'Create Strategy',
                leadingIcon: Icons.add,
                variant: UiVariant.primary,
                intent: UiIntent.primary,
                onPressed: () {
                  UiToast.show(
                    context,
                    title: 'New Strategy',
                    message: 'Strategy editor opened',
                    intent: UiIntent.info,
                  );
                },
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Navigation Switcher
          UiTabs(
            items: const [
              UiTabItem(label: 'Playbook Library'),
              UiTabItem(label: 'Strategy Analyzer'),
              UiTabItem(label: 'Knowledge Graph'),
            ],
            selectedIndex: _selectedTabIndex,
            onChanged: (idx) => setState(() => _selectedTabIndex = idx),
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          if (_selectedTabIndex == 0)
            AppStrategyLibraryBlock(
              strategies: strategies,
              onOpen: (s) {
                UiToast.show(
                  context,
                  title: s.name,
                  message: 'Opened strategy details and version history',
                  intent: UiIntent.primary,
                );
              },
            )
          else if (_selectedTabIndex == 1)
            UiCard(
              title: 'Strategy Analyzer Rollup',
              subtitle: 'Performance attribution by strategy setup',
              child: Column(
                children: [
                  for (final s in strategies)
                    Padding(
                      padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
                      child: AppStrategyCard(
                        strategy: s,
                      ),
                    ),
                ],
              ),
            )
          else
            UiCard(
              title: 'Strategy & Trade Knowledge Graph',
              subtitle: 'Interconnected visual map of strategies, trades and tickers',
              child: SizedBox(
                height: 320,
                child: Center(
                  child: UiGraphCanvas(
                    nodes: const [
                      UiGraphNode(id: 's1', label: 'ORB Breakout'),
                      UiGraphNode(id: 't1', label: '\$AAPL Win'),
                      UiGraphNode(id: 't2', label: '\$NVDA Win'),
                    ],
                    edges: const [
                      UiGraphEdge(from: 's1', to: 't1'),
                      UiGraphEdge(from: 's1', to: 't2'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
