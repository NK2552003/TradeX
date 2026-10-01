import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import '../data/asset_market_repository.dart';
import '../models/market_snapshot.dart';
import 'market_overview_view.dart';

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
          Text('Data coverage', style: context.uiText.heading),
          UiGap.v(context.ui.spacing.sm),
          Text(
            'Snapshot exported ${marketSnapshotDate(manifest)}. Directory coverage and successfully fetched records are shown separately.',
            style: context.uiText.body,
          ),
          UiGap.v(context.ui.spacing.md),
          UiCardGrid(
            intrinsicHeight: true,
            desktopColumns: 4,
            largeColumns: 4,
            children: [
              UiMetricCard(
                title: 'Directory symbols',
                value: '${directory.length}',
              ),
              UiMetricCard(
                title: 'Quotes available',
                value: '${quotes.length}',
              ),
              UiMetricCard(
                title: 'Price histories',
                value: '${manifest['history_count'] ?? 0}',
              ),
              UiMetricCard(
                title: 'Full detail records',
                value: '${manifest['detail_count'] ?? 0}',
              ),
            ],
          ),
          UiGap.v(context.ui.spacing.md),
          UiCallout(
            title: 'Snapshot coverage',
            message:
                'Quotes and daily history are broadly available. Fundamentals and full company profiles cover a smaller subset. Missing fields and unavailable provider sections are identified in each instrument.',
            intent: UiIntent.info,
          ),
          UiGap.v(context.ui.spacing.md),
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
                compare: (a, b) => '${a['ticker']}'.compareTo('${b['ticker']}'),
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
      );
    },
  );
}
