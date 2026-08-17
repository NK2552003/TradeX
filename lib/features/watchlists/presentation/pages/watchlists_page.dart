import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class WatchlistsPage extends StatefulWidget {
  const WatchlistsPage({super.key});

  @override
  State<WatchlistsPage> createState() => _WatchlistsPageState();
}

class _WatchlistsPageState extends State<WatchlistsPage> {
  String _searchQuery = '';
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final tickers = [
      const AppTicker(
        symbol: 'RELIANCE',
        name: 'Reliance Industries Ltd.',
        price: 2950.40,
        changePercent: 1.8,
        currencySymbol: '₹',
        spark: [2910, 2925, 2930, 2942, 2950.4],
      ),
      const AppTicker(
        symbol: 'TCS',
        name: 'Tata Consultancy Services',
        price: 4180.50,
        changePercent: 2.4,
        currencySymbol: '₹',
        spark: [4112, 4134, 4150, 4170, 4180.5],
      ),
      const AppTicker(
        symbol: 'HDFCBANK',
        name: 'HDFC Bank Ltd.',
        price: 1640.80,
        changePercent: -0.6,
        currencySymbol: '₹',
        spark: [1655, 1650, 1648, 1642, 1640.8],
      ),
      const AppTicker(
        symbol: 'INFY',
        name: 'Infosys Ltd.',
        price: 1814.20,
        changePercent: 1.1,
        currencySymbol: '₹',
        spark: [1800, 1805, 1810, 1812, 1814.2],
      ),
      const AppTicker(
        symbol: 'NIFTY50',
        name: 'NIFTY 50 Index',
        price: 24850.00,
        changePercent: 0.8,
        currencySymbol: '₹',
        spark: [24650, 24700, 24750, 24800, 24850],
      ),
    ];

    final filteredTickers = tickers.where((t) {
      return _searchQuery.isEmpty ||
          t.symbol.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ticker Marquee Banner
          UiMarquee(
            children: [
              Text(
                'LIVE MARKET: NIFTY 50 24,850 (+0.8%) | BANKNIFTY 51,200 (+1.2%) | RELIANCE ₹2,950 (+1.8%) | TCS ₹4,180 (+2.4%) | INFY ₹1,814 (+1.1%)',
                style: context.uiText.bodyStrong.copyWith(color: theme.colors.bullish),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Header title & action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Watchlists & Scanner',
                    style: context.uiText.display.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Text(
                    'Real-time price alerts, technical scanner & custom shortlists',
                    style: context.uiText.body.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
              UiButton(
                label: 'Add Ticker',
                leadingIcon: Icons.add,
                variant: UiVariant.primary,
                intent: UiIntent.primary,
                onPressed: () {
                  UiToast.show(
                    context,
                    title: 'Add Asset',
                    message: 'Asset search dialog opened',
                    intent: UiIntent.info,
                  );
                },
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Tabs & Search
          Row(
            children: [
              Expanded(
                child: UiTabs(
                  items: const [
                    UiTabItem(label: 'Tech Leaders'),
                    UiTabItem(label: 'Crypto Movers'),
                    UiTabItem(label: 'Earnings Week'),
                    UiTabItem(label: 'Custom Shortlist'),
                  ],
                  selectedIndex: _selectedTabIndex,
                  onChanged: (idx) => setState(() => _selectedTabIndex = idx),
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              SizedBox(
                width: 260,
                child: UiInput.search(
                  value: _searchQuery,
                  hintText: 'Search watchlist...',
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Watchlist Cards Grid
          UiCardGrid(
            children: filteredTickers.map((ticker) {
              return AppTickerCard(
                ticker: ticker,
                onTap: () {
                  UiToast.show(
                    context,
                    title: ticker.symbol,
                    message: 'Chart view loaded for ${ticker.name}',
                    intent: UiIntent.primary,
                  );
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
