import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import '../data/asset_market_repository.dart';
import '../models/market_snapshot.dart';
import 'market_overview_view.dart';
import 'market_layout.dart';

class MarketCoverageView extends StatefulWidget {
  const MarketCoverageView({
    super.key,
    required this.snapshot,
    required this.repository,
    required this.onInstrument,
  });
  final MarketSnapshot snapshot;
  final AssetMarketRepository repository;
  final ValueChanged<MarketInstrument> onInstrument;
  @override
  State<MarketCoverageView> createState() => _MarketCoverageViewState();
}

class _MarketCoverageViewState extends State<MarketCoverageView> {
  late final _future = widget.repository.read('tickers/universe');
  String _query = '', _status = 'all';
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
      final query = _query.trim().toLowerCase();
      final rows = directory.where((r) {
        final q = quotes[r['ticker']];
        return (_status == 'all' ||
                (_status == 'priced' ? q != null : q == null)) &&
            '$r ${q?.name ?? ''}'.toLowerCase().contains(query);
      }).toList();
      final manifest = widget.snapshot.manifest;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MarketPageHeading(
            title: 'Data coverage',
            description:
                'Understand what is available before you start your research.',
          ),
          MarketTwoPanel(
            secondary: UiCard(
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
                  UiGap.v(context.ui.spacing.lg),
                  const UiCallout(
                    title: 'Snapshot coverage',
                    message:
                        'Fundamentals and full company profiles cover a subset of instruments. Missing fields are identified in each dossier.',
                  ),
                  UiGap.v(context.ui.spacing.md),
                  Text(
                    'Snapshot exported ${marketSnapshotDate(manifest)}',
                    style: context.uiText.caption,
                  ),
                ],
              ),
            ),
            primary: UiCard(
              title: 'Ticker directory',
              subtitle: '${rows.length} matching symbols',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UiInput.search(
                    value: _query,
                    hintText: 'Search the full ticker directory',
                    onChanged: (v) => setState(() => _query = v),
                    onClear: () => setState(() => _query = ''),
                  ),
                  UiGap.v(context.ui.spacing.sm),
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
                    key: ValueKey('$_query/$_status'),
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
                          title:
                              'No price quote was exported for ${r['ticker']}',
                          intent: UiIntent.info,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}
