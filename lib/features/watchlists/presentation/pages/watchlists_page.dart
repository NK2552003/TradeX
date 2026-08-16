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
        symbol: 'AAPL',
        name: 'Apple Inc.',
        price: 224.30,
        changePercent: 1.8,
        currencySymbol: '\$',
        spark: [220, 221, 223, 222, 224.3],
      ),
      const AppTicker(
        symbol: 'NVDA',
        name: 'NVIDIA Corp.',
        price: 118.50,
        changePercent: 4.2,
        currencySymbol: '\$',
        spark: [112, 114, 115, 117, 118.5],
      ),
      const AppTicker(
        symbol: 'TSLA',
        name: 'Tesla Inc.',
        price: 197.80,
        changePercent: -2.4,
        currencySymbol: '\$',
        spark: [202, 201, 199, 198, 197.8],
      ),
      const AppTicker(
        symbol: 'MSFT',
        name: 'Microsoft Corp.',
        price: 414.20,
        changePercent: 0.6,
        currencySymbol: '\$',
        spark: [410, 411, 412, 413, 414.2],
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
                'LIVE MARKET: NVDA +4.2% | AAPL +1.8% | BTC/USD \$64,200 (+3.1%) | SPY +0.5% | QQQ +1.1%',
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
