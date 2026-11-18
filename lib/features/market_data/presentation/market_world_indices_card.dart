import 'package:flutter/material.dart';

import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../data/yahoo_finance_service.dart';
import '../models/market_snapshot.dart';
import 'market_index_group_card.dart';
import 'market_index_item.dart';

export 'market_index_item.dart';
export 'market_index_group_card.dart';

/// Responsive Overview section for global indices, commodities, FX and rates.
class MarketWorldIndicesCard extends StatefulWidget {
  const MarketWorldIndicesCard({
    super.key,
    this.onInstrument,
    this.instruments = const <MarketInstrument>[],
  });

  final ValueChanged<MarketInstrument>? onInstrument;
  final List<MarketInstrument> instruments;

  @override
  State<MarketWorldIndicesCard> createState() => _MarketWorldIndicesCardState();
}

class _MarketWorldIndicesCardState extends State<MarketWorldIndicesCard> {
  static const List<(String, String)> _americasDefinitions = <(String, String)>[
    ('^IXIC', 'Nasdaq'),
    ('^GSPTSE', 'S&P/TSX Composite'),
    ('^GSPC', 'S&P 500'),
    ('^DJI', 'Dow 30'),
    ('^RUT', 'Russell 2000'),
    ('DX-Y.NYB', 'US Dollar Index'),
    ('^VIX', 'VIX'),
    ('^BVSP', 'IBOVESPA'),
  ];
  static const List<(String, String)> _europeDefinitions = <(String, String)>[
    ('^GDAXI', 'DAX'),
    ('^FCHI', 'CAC 40'),
    ('^STOXX50E', 'EURO STOXX 50'),
    ('^FTSE', 'FTSE 100'),
    ('^N100', 'Euronext 100'),
    ('EURUSD=X', 'EUR / USD'),
  ];
  static const List<(String, String)> _asiaDefinitions = <(String, String)>[
    ('^BSESN', 'S&P BSE SENSEX'),
    ('^HSI', 'Hang Seng'),
    ('000001.SS', 'SSE Composite'),
    ('^AXJO', 'S&P/ASX 200'),
    ('^N225', 'Nikkei 225'),
    ('^KS11', 'KOSPI Composite'),
  ];
  static const List<(String, String)> _commodityDefinitions =
      <(String, String)>[
        ('GC=F', 'Gold'),
        ('SI=F', 'Silver'),
        ('CL=F', 'Crude Oil'),
        ('NG=F', 'Natural Gas'),
        ('HG=F', 'Copper'),
      ];
  static const List<(String, String)> _currencyDefinitions = <(String, String)>[
    ('EURUSD=X', 'EUR / USD'),
    ('GBPUSD=X', 'GBP / USD'),
    ('USDJPY=X', 'USD / JPY'),
    ('USDINR=X', 'USD / INR'),
    ('BTC-USD', 'Bitcoin USD'),
    ('ETH-USD', 'Ethereum USD'),
  ];
  static const List<(String, String)> _bondDefinitions = <(String, String)>[
    ('^TNX', '10-Year Treasury'),
    ('^TYX', '30-Year Treasury'),
    ('^FVX', '5-Year Treasury'),
    ('^IRX', '13-Week Treasury Bill'),
  ];

  late List<MarketIndexItem> _americas;
  late List<MarketIndexItem> _europe;
  late List<MarketIndexItem> _asia;
  late List<MarketIndexItem> _commodities;
  late List<MarketIndexItem> _currencies;
  late List<MarketIndexItem> _bonds;
  bool _loadingQuotes = true;

  @override
  void initState() {
    super.initState();
    _americas = _initialItems(_americasDefinitions);
    _europe = _initialItems(_europeDefinitions);
    _asia = _initialItems(_asiaDefinitions);
    _commodities = _initialItems(_commodityDefinitions);
    _currencies = _initialItems(_currencyDefinitions);
    _bonds = _initialItems(_bondDefinitions);
    _syncFromInstruments();
    _fetchLatestQuotes();
  }

  @override
  void didUpdateWidget(covariant MarketWorldIndicesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.instruments, widget.instruments)) {
      setState(_syncFromInstruments);
    }
  }

  static List<MarketIndexItem> _initialItems(
    List<(String, String)> definitions,
  ) => definitions
      .map(
        ((String, String) definition) => MarketIndexItem(
          symbol: definition.$1,
          name: definition.$2,
          price: 0,
          changePercent: 0,
          spark: const <double>[],
        ),
      )
      .toList();

  List<List<MarketIndexItem>> get _groups => <List<MarketIndexItem>>[
    _americas,
    _europe,
    _asia,
    _commodities,
    _currencies,
    _bonds,
  ];

  void _syncFromInstruments() {
    if (widget.instruments.isEmpty) return;
    final Map<String, MarketInstrument> instrumentsBySymbol =
        <String, MarketInstrument>{
          for (final MarketInstrument instrument in widget.instruments)
            instrument.symbol.toUpperCase(): instrument,
        };

    for (final List<MarketIndexItem> group in _groups) {
      for (int index = 0; index < group.length; index++) {
        final MarketIndexItem current = group[index];
        final MarketInstrument? match =
            instrumentsBySymbol[current.symbol.toUpperCase()] ??
            widget.instruments
                .where(
                  (MarketInstrument instrument) =>
                      instrument.name.toLowerCase() ==
                      current.name.toLowerCase(),
                )
                .firstOrNull;
        if (match == null || !match.price.isFinite || match.price <= 0) {
          continue;
        }
        final currentTimestamp = current.timestamp;
        if (currentTimestamp != null &&
            match.updatedAt?.isAfter(currentTimestamp) != true) {
          continue;
        }
        group[index] = current.copyWith(
          price: match.price,
          changePercent: match.changePercent,
          spark: match.spark,
          isLive: false,
          timestamp: match.updatedAt,
          source: 'Market snapshot',
        );
      }
    }
  }

  Future<void> _fetchLatestQuotes() async {
    final List<({String symbol, String name})> requested =
        <({String symbol, String name})>[
          for (final List<MarketIndexItem> group in _groups)
            for (final MarketIndexItem item in group)
              (symbol: item.symbol, name: item.name),
        ];
    var latest = const <String, MarketIndexItem>{};
    try {
      latest = await YahooFinanceService
          .instance
          .fetchIndexItems(requested);
    } catch (_) {
      // Existing snapshot values remain visible when the live quote proxy fails.
    }
    if (!mounted) return;
    setState(() {
      _loadingQuotes = false;
      for (final List<MarketIndexItem> group in _groups) {
        for (int index = 0; index < group.length; index++) {
          final current = group[index];
          final quote = latest[current.symbol];
          if (quote == null || !quote.hasQuote) continue;
          final currentTimestamp = current.timestamp;
          if (currentTimestamp != null &&
              quote.timestamp?.isBefore(currentTimestamp) != false) {
            continue;
          }
          group[index] = quote;
        }
      }
    });
  }

  void _openInstrument(MarketIndexItem item) {
    final MarketInstrument? existing = widget.instruments
        .where(
          (MarketInstrument instrument) => instrument.symbol == item.symbol,
        )
        .firstOrNull;
    widget.onInstrument?.call(
      existing ??
          MarketInstrument.fromJson(
            <String, dynamic>{
              'ticker': item.symbol,
              'price': item.price,
              'change_pct': item.changePercent,
              'market': 'GLOBAL',
              'currency': '',
              'updated_at': item.timestamp?.toIso8601String(),
            },
            <String, dynamic>{'name': item.name},
            history: item.spark,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _MarketSectionHeader(
          title: 'World Indices',
          subtitle: 'Major benchmarks across the Americas, Europe and Asia',
        ),
        UiGap.v(theme.spacing.sm),
        UiCardGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 3,
          largeColumns: 3,
          minTileWidth: context.sz(340),
          intrinsicHeight: true,
          children: <Widget>[
            MarketIndexGroupCard(
              title: 'Americas',
              items: _americas,
              loading: _loadingQuotes,
              onItemTap: widget.onInstrument == null ? null : _openInstrument,
            ),
            MarketIndexGroupCard(
              title: 'Europe',
              items: _europe,
              loading: _loadingQuotes,
              onItemTap: widget.onInstrument == null ? null : _openInstrument,
            ),
            MarketIndexGroupCard(
              title: 'Asia',
              items: _asia,
              loading: _loadingQuotes,
              onItemTap: widget.onInstrument == null ? null : _openInstrument,
            ),
          ],
        ),
        UiGap.v(theme.spacing.xl),
        const _MarketSectionHeader(
          title: 'Assets',
          subtitle: 'Commodities, currencies, crypto and US Treasury yields',
        ),
        UiGap.v(theme.spacing.sm),
        UiCardGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 3,
          largeColumns: 3,
          minTileWidth: context.sz(340),
          intrinsicHeight: true,
          children: <Widget>[
            MarketIndexGroupCard(
              title: 'Commodities',
              items: _commodities,
              loading: _loadingQuotes,
              onItemTap: widget.onInstrument == null ? null : _openInstrument,
            ),
            MarketIndexGroupCard(
              title: 'Currencies & Crypto',
              items: _currencies,
              loading: _loadingQuotes,
              onItemTap: widget.onInstrument == null ? null : _openInstrument,
            ),
            MarketIndexGroupCard(
              title: 'US Treasury Yields',
              items: _bonds,
              loading: _loadingQuotes,
              onItemTap: widget.onInstrument == null ? null : _openInstrument,
            ),
          ],
        ),
      ],
    );
  }
}

class _MarketSectionHeader extends StatelessWidget {
  const _MarketSectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: context.uiText.title.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              UiGap.v(theme.spacing.xxs),
              Text(
                subtitle,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
        UiGap.h(theme.spacing.sm),
        const UiBadge(
          label: 'Latest quotes',
          icon: Icons.schedule_rounded,
          intent: UiIntent.info,
          variant: UiBadgeVariant.soft,
          size: UiSize.xs,
        ),
      ],
    );
  }
}
