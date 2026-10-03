import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import '../models/market_snapshot.dart';
import 'market_movers_panel.dart';
import 'market_layout.dart';

class MarketQuoteResults extends StatefulWidget {
  const MarketQuoteResults({
    super.key,
    required this.quotes,
    required this.onInstrument,
  });
  final List<MarketInstrument> quotes;
  final ValueChanged<MarketInstrument> onInstrument;
  @override
  State<MarketQuoteResults> createState() => _MarketQuoteResultsState();
}

class _MarketQuoteResultsState extends State<MarketQuoteResults> {
  int _page = 0;
  String _sort = 'default';
  @override
  void didUpdateWidget(covariant MarketQuoteResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quotes.length != widget.quotes.length ||
        oldWidget.quotes.firstOrNull?.symbol !=
            widget.quotes.firstOrNull?.symbol) {
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (widget.quotes.isEmpty) {
        return const UiEmptyState(
          title: 'No matching instruments',
          message: 'Try another company or symbol.',
        );
      }
      if (box.maxWidth < 600) {
        final quotes = [...widget.quotes];
        if (_sort == 'symbol') {
          quotes.sort((a, b) => a.symbol.compareTo(b.symbol));
        }
        if (_sort == 'change') {
          quotes.sort((a, b) => b.changePercent.compareTo(a.changePercent));
        }
        final count = (quotes.length / 20).ceil();
        final page = _page.clamp(0, count - 1);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UiSelect<String>(
              value: _sort,
              options: const [
                UiOption(label: 'Default order', value: 'default'),
                UiOption(label: 'Symbol A–Z', value: 'symbol'),
                UiOption(label: 'Highest change', value: 'change'),
              ],
              onChanged: (value) => setState(() {
                _sort = value;
                _page = 0;
              }),
            ),
            UiGap.v(context.ui.spacing.sm),
            for (final quote in quotes.skip(page * 20).take(20)) ...[
              MarketQuoteRow(
                quote: quote,
                onTap: () => widget.onInstrument(quote),
              ),
              const UiDivider(spacing: 0),
            ],
            if (count > 1)
              UiPagination(
                page: page,
                pageCount: count,
                onPageChanged: (value) => setState(() => _page = value),
              ),
          ],
        );
      }
      return UiTable<MarketInstrument>(
        rows: widget.quotes,
        pageSize: 30,
        density: UiDensity.compact,
        onRowTap: widget.onInstrument,
        columns: [
          UiTableColumn(
            header: 'Instrument',
            flex: 3,
            cell: (c, q) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.symbol, style: c.uiText.bodyStrong),
                Text(
                  q.name,
                  style: c.uiText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            compare: (a, b) => a.symbol.compareTo(b.symbol),
          ),
          UiTableColumn(
            header: 'Price',
            numeric: true,
            flex: 2,
            cell: (c, q) => Text('${q.currency} ${q.price.toStringAsFixed(2)}'),
            compare: (a, b) => a.price.compareTo(b.price),
          ),
          UiTableColumn(
            header: 'Change %',
            numeric: true,
            flex: 2,
            cell: (c, q) => Text(
              AppTokens.signedPercent(q.changePercent),
              style: c.uiText.bodyStrong.copyWith(
                color: AppTokens.plIntent(q.changePercent).color(c),
              ),
            ),
            compare: (a, b) => a.changePercent.compareTo(b.changePercent),
          ),
          if (box.maxWidth >= 760)
            UiTableColumn(
              header: 'Volume',
              numeric: true,
              cell: (c, q) => Text(AppTokens.count(q.volume)),
              compare: (a, b) => a.volume.compareTo(b.volume),
            ),
        ],
      );
    },
  );
}

class MarketCatalogueView extends StatelessWidget {
  const MarketCatalogueView({
    super.key,
    required this.quotes,
    required this.onInstrument,
  });
  final List<MarketInstrument> quotes;
  final ValueChanged<MarketInstrument> onInstrument;
  @override
  Widget build(BuildContext context) {
    final markets = <String, int>{};
    for (final q in quotes) {
      final label = q.market.isEmpty ? 'Unspecified' : q.market;
      markets.update(label, (n) => n + 1, ifAbsent: () => 1);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MarketPageHeading(
          title: 'Instrument directory',
          description:
              'Find an asset. Compare its quote. Open the complete research dossier.',
        ),
        MarketTwoPanel(
          primary: UiCard(
            title: 'Instruments',
            subtitle: '${quotes.length} matching quotes',
            padding: EdgeInsets.all(context.sp(context.ui.spacing.sm)),
            child: MarketQuoteResults(
              quotes: quotes,
              onInstrument: onInstrument,
            ),
          ),
          secondary: UiCard(
            title: 'Market composition',
            subtitle: 'Distribution of the current results',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (markets.isNotEmpty)
                  UiDonutChart(
                    size: 180,
                    centerLabel: '${quotes.length}',
                    slices: [
                      for (final market in markets.entries)
                        UiDonutSlice(
                          label: market.key,
                          value: market.value.toDouble(),
                        ),
                    ],
                  ),
                UiGap.v(context.ui.spacing.md),
                UiKeyValueTable(
                  rows: [
                    for (final market in markets.entries)
                      UiKeyValueRow(
                        label: market.key,
                        value: '${market.value}',
                      ),
                  ],
                ),
                const UiDivider(),
                const UiCallout(
                  title: 'From quote to research',
                  message:
                      'Open any instrument for price history, fundamentals, company news, options and ownership.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MarketMoversView extends StatelessWidget {
  const MarketMoversView({
    super.key,
    required this.snapshot,
    required this.onInstrument,
  });
  final MarketSnapshot snapshot;
  final ValueChanged<MarketInstrument> onInstrument;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const MarketPageHeading(
        title: 'Market movers',
        description:
            'Compare both sides of the session. Rankings use the reported snapshot changes.',
      ),
      MarketTwoPanel(
        equal: true,
        primary: UiCard(
          title: 'Top gainers',
          leading: Icon(Icons.trending_up, color: context.ui.colors.success),
          subtitle: '${snapshot.gainers.length} advancing instruments',
          child: MarketQuoteResults(
            quotes: snapshot.gainers,
            onInstrument: onInstrument,
          ),
        ),
        secondary: UiCard(
          title: 'Top losers',
          leading: Icon(Icons.trending_down, color: context.ui.colors.danger),
          subtitle: '${snapshot.losers.length} declining instruments',
          child: MarketQuoteResults(
            quotes: snapshot.losers,
            onInstrument: onInstrument,
          ),
        ),
      ),
    ],
  );
}
