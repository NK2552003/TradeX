import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';
import 'package:tradex/features/market_data/presentation/market_instrument_view.dart';

/// Reference-style quote row: identity, actual closing-price spark, quote/change.
class MarketQuoteRow extends StatelessWidget {
  const MarketQuoteRow({super.key, required this.quote, required this.onTap});
  final MarketInstrument quote;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final color = quote.changePercent >= 0
        ? theme.colors.success
        : theme.colors.danger;
    String signed(double value) =>
        '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}';
    return UiCard(
      variant: UiCardVariant.ghost,
      borderless: true,
      hoverLift: false,
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, box) => Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quote.symbol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.bodyStrong.copyWith(
                      color: theme.colors.info,
                    ),
                  ),
                  Text(
                    quote.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.caption,
                  ),
                ],
              ),
            ),
            if (box.maxWidth >= 220) ...[
              UiGap.h(theme.spacing.xs),
              Expanded(
                flex: 2,
                child: UiTooltip(
                  message: 'Daily closing prices',
                  child: quote.spark.length > 1
                      ? UiSparkChart(
                          data: quote.spark
                              .skip(
                                (quote.spark.length - 24).clamp(
                                  0,
                                  quote.spark.length,
                                ),
                              )
                              .toList(),
                          color: color,
                          filled: true,
                          height: context.sz(36),
                        )
                      : Text('No history', style: context.uiText.caption),
                ),
              ),
            ],
            UiGap.h(theme.spacing.xs),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    quote.price.toStringAsFixed(2),
                    maxLines: 1,
                    style: context.uiText.bodyStrong,
                  ),
                  Text(
                    '${quote.change == null ? '' : '${signed(quote.change!)} '}(${signed(quote.changePercent)}%)',
                    textAlign: TextAlign.right,
                    style: context.uiText.caption.copyWith(color: color),
                  ),
                  Text(
                    quote.currency,
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MarketMoversList extends StatelessWidget {
  const MarketMoversList({
    super.key,
    required this.title,
    required this.quotes,
    required this.onTap,
    this.limit = 5,
  });
  final String title;
  final List<MarketInstrument> quotes;
  final ValueChanged<MarketInstrument> onTap;
  final int limit;
  @override
  Widget build(BuildContext context) => UiCard(
    padding: EdgeInsets.all(context.sp(context.ui.spacing.sm)),
    titleWidget: Text(title, style: context.uiText.heading),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (quotes.isEmpty)
          UiEmptyState(title: 'No ${title.toLowerCase()} in this snapshot'),
        for (final quote in quotes.take(limit)) ...[
          MarketQuoteRow(quote: quote, onTap: () => onTap(quote)),
          const UiDivider(spacing: 0),
        ],
      ],
    ),
  );
}

class MarketMoversPanel extends StatefulWidget {
  const MarketMoversPanel({super.key, this.repository});
  final AssetMarketRepository? repository;
  @override
  State<MarketMoversPanel> createState() => _MarketMoversPanelState();
}

class _MarketMoversPanelState extends State<MarketMoversPanel> {
  late final AssetMarketRepository _repo =
      widget.repository ?? AssetMarketRepository();
  late Future<MarketSnapshot> _future = _repo.snapshot();
  void _open(MarketInstrument quote) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(quote.symbol)),
        body: MarketInstrumentView(instrument: quote, repository: _repo),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<MarketSnapshot>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return UiEmptyState(
          title: 'Market data unavailable',
          actionLabel: 'Try again',
          onActionPressed: () =>
              setState(() => _future = _repo.snapshot(refresh: true)),
        );
      }
      if (!snapshot.hasData) return const UiSkeleton(height: 200);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MarketMoversList(
            title: 'Top gainers',
            quotes: snapshot.data!.gainers,
            onTap: _open,
          ),
          UiGap.v(context.ui.spacing.md),
          MarketMoversList(
            title: 'Top losers',
            quotes: snapshot.data!.losers,
            onTap: _open,
          ),
        ],
      );
    },
  );
}
