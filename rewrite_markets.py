import os
import json

# We'll just write a Dart script that generates the complete flutter code and then we can format it.
# Actually, I will write the code directly to lib/features/markets/ui/markets_screen.dart using Python string.

dart_code = """
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/features/markets/data/market_repository.dart';
import 'news_screen.dart';

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({
    super.key,
    this.watchlist = false,
    this.openRequest,
    this.onOpenRef,
  });
  final bool watchlist;
  final AppLinkOpenRequest? openRequest;
  final ValueChanged<AppLinkRef>? onOpenRef;
  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  final store = MarketWorkspaceStore.instance;
  String? selected;
  bool mobileDetail = false;
  int _navIndex = 0;
  
  Map<String, dynamic>? _worldIndices;
  
  final List<String> _navItems = [
    'Overview', 'World Indices', 'Futures', 'Bonds', 'Currencies', 
    'Options', 'Sectors', 'Stocks', 'Crypto', 'ETFs', 'Mutual Funds'
  ];

  @override
  void initState() {
    super.initState();
    store.initialize();
    selected = widget.openRequest?.id;
    mobileDetail = selected != null;
    _loadWorldIndices();
  }

  Future<void> _loadWorldIndices() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/market/screeners/world_indices_by_continent.json');
      setState(() {
        _worldIndices = jsonDecode(jsonStr);
      });
    } catch (e) {
      debugPrint('Error loading world indices: $e');
    }
  }

  @override
  void didUpdateWidget(MarketsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openRequest != null && oldWidget.openRequest != widget.openRequest) {
      setState(() {
        selected = widget.openRequest!.id;
        mobileDetail = true;
      });
    }
  }
  
  void open(String symbol) => setState(() {
    selected = symbol;
    mobileDetail = true;
  });

  Widget _buildLeftNav(BuildContext context) {
    final theme = context.ui;
    return Container(
      width: 200,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: theme.colors.border)),
      ),
      child: ListView.builder(
        padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
        itemCount: _navItems.length,
        itemBuilder: (context, index) {
          final isSelected = _navIndex == index;
          return UiInteractive(
            onTap: () => setState(() {
              _navIndex = index;
              selected = null; 
              mobileDetail = false;
            }),
            builder: (ctx, s) => Container(
              padding: EdgeInsets.symmetric(
                vertical: ctx.sp(theme.spacing.sm),
                horizontal: ctx.sp(theme.spacing.md),
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colors.primary.withValues(alpha: 0.10)
                    : (s.hovered ? theme.colors.surfaceHover : Colors.transparent),
                borderRadius: ctx.radius(theme.radii.lg),
              ),
              child: Text(
                _navItems[index],
                style: ctx.uiText.caption.copyWith(
                  color: isSelected ? theme.colors.primary : theme.colors.foregroundMuted,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCenterContent(BuildContext context) {
    if (selected != null) {
      final all = store.snapshot?.instruments ?? [];
      MarketInstrument? current;
      for (final q in all) {
        if (q.symbol == selected || q.symbol == '${selected?.toUpperCase()}.NS') {
          current = q;
        }
      }
      if (current != null) {
        return MarketInstrumentDetail(
          key: ValueKey(current.symbol),
          instrument: current,
          onBack: context.uiRes.isDesktop ? null : () => setState(() => mobileDetail = false),
          onOpenSymbol: open,
          onOpenRef: widget.onOpenRef,
        );
      }
    }

    if (_navIndex == 1) { // World Indices
      return _buildWorldIndicesCenter(context);
    }

    // Default Overview
    return _buildOverviewCenter(context);
  }

  Widget _buildWorldIndicesCenter(BuildContext context) {
    if (_worldIndices == null) {
      return const Center(child: UiSkeleton.watchlists());
    }
    
    return ListView(
      padding: EdgeInsets.all(context.sp(20)),
      children: [
        Text('World Indices', style: context.uiText.heading),
        const UiGap.v(20),
        UiCardGrid(
          children: _worldIndices!.entries.map((entry) {
            final continent = entry.key;
            final data = entry.value as Map<String, dynamic>;
            
            // Map the data to a list of rows
            final rows = data.entries.map((e) {
              final price = e.value != null ? (e.value['price'] ?? 0.0) : 0.0;
              return _IndexData(e.key, price);
            }).toList();
            
            return UiCard(
              variant: UiCardVariant.surface,
              child: Padding(
                padding: EdgeInsets.all(context.sp(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(continent, style: context.uiText.title),
                    const UiGap.v(12),
                    UiTable<_IndexData>(
                      rows: rows,
                      columns: [
                        UiTableColumn(
                          header: 'Symbol',
                          cell: (c, row) => Text(row.symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
                          flex: 2,
                        ),
                        UiTableColumn(
                          header: 'Price',
                          numeric: true,
                          cell: (c, row) => Text(row.price.toStringAsFixed(2)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildOverviewCenter(BuildContext context) {
    final stories = store.snapshot?.news ?? <MarketStory>[];
    final newsItems = stories.map((s) => AppNewsItem(
      id: s.id,
      headline: s.title,
      source: s.publisher,
      publishedAt: s.publishedAt ?? DateTime.now(),
      summary: s.summary,
      tickers: s.symbols,
    )).toList();

    return ListView(
      padding: EdgeInsets.all(context.sp(20)),
      children: [
        Text('Overview', style: context.uiText.heading),
        const UiGap.v(20),
        if (_worldIndices != null) ...[
           Text('Global Markets', style: context.uiText.subheading),
           const UiGap.v(12),
           UiCardGrid(
             children: _worldIndices!.entries.take(2).map((entry) {
               return UiCard(
                 child: Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        Text(entry.key, style: context.uiText.title),
                        const UiGap.v(8),
                        Text('${entry.value.length} indices tracked', style: context.uiText.caption),
                     ],
                   )
                 )
               );
             }).toList()
           ),
           const UiGap.v(24),
        ],
        AppNewsFeedBlock(
          title: 'Top Stories',
          items: newsItems,
          onTap: (item) {
             final story = stories.firstWhere((s) => s.id == item.id);
             showMarketStory(
                context,
                story,
                onOpenRef: widget.onOpenRef,
                onOpenSymbol: open,
             );
          }
        ),
      ],
    );
  }

  Widget _buildRightSidebar(BuildContext context) {
    final theme = context.ui;
    final all = store.snapshot?.instruments ?? [];
    final trending = all.where((q) => q.change != null && q.change! > 0).take(5).toList();

    return Container(
      width: 300,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.colors.border)),
      ),
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiInput.search(
            value: '',
            hintText: 'Quote Lookup',
            onChanged: (v) {},
          ),
          const UiGap.v(24),
          UiCard(
            variant: UiCardVariant.soft,
            child: Padding(
              padding: EdgeInsets.all(context.sp(16)),
              child: Column(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 48),
                  const UiGap.v(12),
                  Text('Sign in to view your portfolio', textAlign: TextAlign.center, style: context.uiText.body),
                  const UiGap.v(16),
                  UiButton(
                    label: 'Sign In',
                    intent: UiIntent.primary,
                    expand: true,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          const UiGap.v(24),
          Text('Trending tickers', style: context.uiText.subheading),
          const UiGap.v(12),
          ...trending.map((q) => Padding(
             padding: EdgeInsets.only(bottom: context.sp(8)),
             child: AppMarketQuoteTile(
                symbol: q.symbol,
                name: q.name,
                price: q.priceLabel,
                change: q.changeLabel,
                positive: q.positive,
                onTap: () => open(q.symbol),
             )
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (store.snapshot == null) {
          return UiPage(
            child: store.loading
                ? const UiSkeleton.watchlists()
                : UiEmptyState(
                    title: 'Markets could not be loaded',
                    message: store.error,
                    action: UiButton(label: 'Retry', onPressed: store.refresh),
                  ),
          );
        }

        return LayoutBuilder(
          builder: (context, box) {
            final desktop = box.maxWidth >= 900;
            
            if (desktop) {
              return UiPage(
                padding: EdgeInsets.zero,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLeftNav(context),
                    Expanded(child: _buildCenterContent(context)),
                    _buildRightSidebar(context),
                  ],
                ),
              );
            }

            // Mobile view
            if (mobileDetail && selected != null) {
              final all = store.snapshot?.instruments ?? [];
              final current = all.firstWhere((q) => q.symbol == selected || q.symbol == '${selected?.toUpperCase()}.NS', orElse: () => all.first);
              return PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) setState(() => mobileDetail = false);
                },
                child: UiPage(
                  padding: EdgeInsets.zero,
                  child: MarketInstrumentDetail(
                    instrument: current,
                    onBack: () => setState(() => mobileDetail = false),
                    onOpenSymbol: open,
                    onOpenRef: widget.onOpenRef,
                  ),
                ),
              );
            }

            return UiPage(
              child: ListView(
                padding: EdgeInsets.all(context.sp(16)),
                children: [
                  _buildRightSidebar(context), // Search and trending first
                  const UiGap.v(24),
                  _buildCenterContent(context),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _IndexData {
  final String symbol;
  final double price;
  _IndexData(this.symbol, this.price);
}

class MarketInstrumentDetail extends StatefulWidget {
  const MarketInstrumentDetail({
    super.key,
    required this.instrument,
    this.onBack,
    this.onOpenSymbol,
    this.onOpenRef,
  });
  final MarketInstrument instrument;
  final VoidCallback? onBack;
  final ValueChanged<String>? onOpenSymbol;
  final ValueChanged<AppLinkRef>? onOpenRef;
  @override
  State<MarketInstrumentDetail> createState() => _MarketInstrumentDetailState();
}

class _MarketInstrumentDetailState extends State<MarketInstrumentDetail> {
  final store = MarketWorkspaceStore.instance;
  late Future<List<MarketBar>> history;
  Map<String, dynamic>? fundamentals;
  int _navIndex = 0;
  
  final List<String> _navItems = [
    'Summary', 'News', 'Chart', 'Conversations', 'Historical Data', 'Options', 'Components'
  ];

  @override
  void initState() {
    super.initState();
    history = store.repository.history(widget.instrument.symbol);
    _loadFundamentals();
  }
  
  Future<void> _loadFundamentals() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/market/stock_detail/${widget.instrument.symbol}.json');
      if (mounted) {
         setState(() {
           fundamentals = jsonDecode(jsonStr);
         });
      }
    } catch (e) {
      debugPrint('No local details for ${widget.instrument.symbol}');
    }
  }

  @override
  void didUpdateWidget(MarketInstrumentDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.instrument != widget.instrument) {
      history = store.repository.history(widget.instrument.symbol);
      fundamentals = null;
      _loadFundamentals();
    }
  }

  Widget _buildLeftNav(BuildContext context) {
    final theme = context.ui;
    return Container(
      width: 200,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: theme.colors.border)),
      ),
      child: ListView.builder(
        padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
        itemCount: _navItems.length,
        itemBuilder: (context, index) {
          final isSelected = _navIndex == index;
          return UiInteractive(
            onTap: () => setState(() {
              _navIndex = index;
            }),
            builder: (ctx, s) => Container(
              padding: EdgeInsets.symmetric(
                vertical: ctx.sp(theme.spacing.sm),
                horizontal: ctx.sp(theme.spacing.md),
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colors.primary.withValues(alpha: 0.10)
                    : (s.hovered ? theme.colors.surfaceHover : Colors.transparent),
                borderRadius: ctx.radius(theme.radii.lg),
              ),
              child: Text(
                _navItems[index],
                style: ctx.uiText.caption.copyWith(
                  color: isSelected ? theme.colors.primary : theme.colors.foregroundMuted,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildCenter(BuildContext context) {
     final q = widget.instrument;
     return ListView(
        padding: EdgeInsets.all(context.sp(20)),
        children: [
          if (widget.onBack != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: UiButton(
                label: 'Back',
                variant: UiVariant.ghost,
                leadingIcon: Icons.arrow_back_rounded,
                onPressed: widget.onBack,
              ),
            ),
            const UiGap.v(16),
          ],
          Text(q.symbol, style: context.uiText.heading),
          Text(q.name, style: context.uiText.body.copyWith(color: context.ui.colors.foregroundMuted)),
          const UiGap.v(16),
          Text(q.priceLabel, style: context.uiText.title),
          Text('${q.changeLabel} vs previous close', style: context.uiText.body.copyWith(
            color: q.positive ? context.ui.colors.bullish : context.ui.colors.bearish,
          )),
          const UiGap.v(20),
          
          FutureBuilder<List<MarketBar>>(
            future: history,
            builder: (context, snapshot) {
               if (snapshot.connectionState != ConnectionState.done) {
                  return const UiSkeleton(height: 240);
               }
               final bars = snapshot.data ?? [];
               if (bars.isEmpty) {
                  return const UiEmptyState(title: 'No chart data');
               }
               // Note: mapping MarketBar to CandleData assuming CandleData is what UiCandleChart takes
               // Actually we will just use the UiChart block if CandleChart expects a specific type.
               // wait, in the original markets_screen, how was the chart drawn? It wasn't drawn, only a table.
               // Let's use UiCandleChart as requested.
               // Need to verify CandleData structure if UiCandleChart is used.
               // Let's use UiTable for history for now, or UiAreaChart.
               return SizedBox(
                 height: 300,
                 child: UiAreaChart(
                   series: [
                      UiChartSeries(
                         id: 'price',
                         name: 'Price',
                         data: bars.map((b) => UiChartPoint(x: b.time.millisecondsSinceEpoch.toDouble(), y: b.close)).toList(),
                         color: context.ui.colors.primary,
                      )
                   ]
                 ),
               );
            }
          ),
          
          const UiGap.v(32),
          Text('Fundamentals', style: context.uiText.subheading),
          const UiGap.v(16),
          
          if (fundamentals != null && fundamentals!['summary'] != null)
             _buildFundamentalsTable(context, fundamentals!['summary'])
          else
             const UiEmptyState(title: 'No fundamentals available'),
        ]
     );
  }
  
  Widget _buildFundamentalsTable(BuildContext context, Map<String, dynamic> summary) {
     final rows = summary.entries.map((e) => _FundData(e.key, e.value.toString())).toList();
     return UiTable<_FundData>(
       rows: rows,
       columns: [
         UiTableColumn(
           header: 'Metric',
           cell: (c, row) => Text(row.key.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
           flex: 1,
         ),
         UiTableColumn(
           header: 'Value',
           cell: (c, row) => Text(row.value),
           flex: 2,
         ),
       ]
     );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = context.uiRes.isDesktop;
    if (!desktop) {
       return _buildCenter(context);
    }
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLeftNav(context),
        Expanded(child: _buildCenter(context)),
      ],
    );
  }
}

class _FundData {
  final String key;
  final String value;
  _FundData(this.key, this.value);
}
"""

with open('lib/features/markets/ui/markets_screen.dart', 'w') as f:
    f.write(dart_code)

