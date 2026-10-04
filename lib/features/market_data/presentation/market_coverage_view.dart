import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import '../data/asset_market_repository.dart';
import '../models/market_snapshot.dart';
import 'market_overview_view.dart';
import 'market_layout.dart';
import 'market_visuals.dart';

class MarketCoverageView extends StatefulWidget {
  const MarketCoverageView({
    super.key,
    required this.snapshot,
    required this.repository,
    required this.onInstrument,
    this.searchQuery = '',
  });
  final MarketSnapshot snapshot;
  final AssetMarketRepository repository;
  final ValueChanged<MarketInstrument> onInstrument;
  final String searchQuery;
  @override
  State<MarketCoverageView> createState() => _MarketCoverageViewState();
}

class _MarketCoverageViewState extends State<MarketCoverageView> {
  late final _future = widget.repository.read('tickers/universe');
  String _status = 'all';
  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: _future,
    builder: (context, result) {
      if (result.hasError) {
        return const UiEmptyState(title: 'Directory unavailable');
      }
      if (!result.hasData) return const UiSkeleton(height: 180);
      final directory = (result.data as List).whereType<Map>().toList();
      final quotes = {for (final q in widget.snapshot.instruments) q.symbol: q};
      final query = widget.searchQuery.trim().toLowerCase();
      final rows = directory.where((r) {
        final q = quotes[r['ticker']];
        return (_status == 'all' ||
                (_status == 'priced' ? q != null : q == null)) &&
            '$r ${q?.name ?? ''}'.toLowerCase().contains(query);
      }).toList();
      final manifest = widget.snapshot.manifest;
      final directoryMarkets = <String, num>{};
      for (final row in directory) {
        final market = '${row['market'] ?? 'Other'}';
        directoryMarkets.update(market, (n) => n + 1, ifAbsent: () => 1);
      }
      return MarketTwoPanel(
        secondary: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UiCard(
              title: 'Coverage health',
              subtitle: 'Availability across the exported directory',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UiStatStrip(
                    stats: [
                      UiStat(
                        label: 'Directory symbols',
                        value: '${directory.length}',
                      ),
                      UiStat(
                        label: 'Quotes available',
                        value: '${quotes.length}',
                      ),
                      UiStat(
                        label: 'Price histories',
                        value: '${manifest['history_count'] ?? 0}',
                      ),
                      UiStat(
                        label: 'Full detail records',
                        value: '${manifest['detail_count'] ?? 0}',
                      ),
                    ],
                  ),
                  UiGap.v(context.ui.spacing.md),
                  UiProgressBar(
                    value: directory.isEmpty
                        ? 0
                        : directory
                                  .where((r) => quotes.containsKey(r['ticker']))
                                  .length /
                              directory.length,
                    label: 'Directory symbols with a quote',
                  ),
                  UiGap.v(context.ui.spacing.md),
                  UiProgressBar(
                    value: quotes.isEmpty
                        ? 0
                        : ((manifest['detail_count'] as num? ?? 0) /
                                  quotes.length)
                              .clamp(0.0, 1.0),
                    label: 'Quoted symbols with a full dossier',
                  ),
                  UiGap.v(context.ui.spacing.lg),
                  UiCallout(
                    title: 'Snapshot coverage',
                    message:
                        'This package contains ${manifest['history_count'] ?? 0} price histories and ${manifest['detail_count'] ?? 0} full profiles for ${quotes.length} quotes. The source export referenced ${manifest['source_history_count'] ?? manifest['history_count'] ?? 0} histories; unavailable files are not plotted.',
                  ),
                  UiGap.v(context.ui.spacing.md),
                  Text(
                    'Snapshot exported ${marketSnapshotDate(manifest)}',
                    style: context.uiText.caption,
                  ),
                ],
              ),
            ),
            UiGap.v(context.ui.spacing.md),
            MarketDistributionCard(
              title: 'Directory by market',
              subtitle: 'All exported ticker symbols',
              values: directoryMarkets,
            ),
          ],
        ),
        primary: UiCard(
          title: 'Ticker directory',
          subtitle: '${rows.length} matching symbols',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiSelect<String>(
                value: _status,
                options: const [
                  UiOption(label: 'All directory symbols', value: 'all'),
                  UiOption(label: 'Quote available', value: 'priced'),
                  UiOption(label: 'No quote in snapshot', value: 'missing'),
                ],
                onChanged: (v) => setState(() => _status = v),
              ),
              UiGap.v(context.ui.spacing.md),
              UiTable<Map>(
                key: ValueKey('${widget.searchQuery}/$_status'),
                rows: rows,
                pageSize: 30,
                stackOnMobile: true,
                columns: [
                  UiTableColumn(
                    header: 'Symbol',
                    cell: (c, r) =>
                        Text('${r['ticker']}', style: c.uiText.bodyStrong),
                    compare: (a, b) =>
                        '${a['ticker']}'.compareTo('${b['ticker']}'),
                  ),
                  UiTableColumn(
                    header: 'Market',
                    cell: (c, r) => Text('${r['market']}'),
                  ),
                  UiTableColumn(
                    header: 'Company',
                    flex: 2,
                    cell: (c, r) => Text(quotes[r['ticker']]?.name ?? '—'),
                  ),
                  UiTableColumn(
                    header: 'Availability',
                    cell: (c, r) => UiBadge(
                      label: quotes.containsKey(r['ticker'])
                          ? 'Quote available'
                          : 'No quote',
                      intent: quotes.containsKey(r['ticker'])
                          ? UiIntent.success
                          : UiIntent.neutral,
                    ),
                  ),
                ],
                onRowTap: (r) {
                  final quote = quotes[r['ticker']];
                  if (quote != null) {
                    widget.onInstrument(quote);
                  } else {
                    UiToast.show(
                      context,
                      title: 'No price quote was exported for ${r['ticker']}',
                      intent: UiIntent.info,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
