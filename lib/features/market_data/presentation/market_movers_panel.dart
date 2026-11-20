import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/market_data/data/asset_market_repository.dart';
import 'package:alphajournal/features/market_data/models/market_snapshot.dart';
import 'package:alphajournal/features/market_data/presentation/market_instrument_view.dart';
import 'package:alphajournal/features/settings/presentation/widgets/settings_side_sheet.dart';

/// Reference-style quote row: identity, actual closing-price spark, quote/change.
class MarketQuoteRow extends StatelessWidget {
  const MarketQuoteRow({
    super.key,
    required this.quote,
    required this.onTap,
    this.allowHistoryFetch = true,
  });
  final MarketInstrument quote;
  final VoidCallback onTap;
  final bool allowHistoryFetch;
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
                  child: _QuoteHistory(
                    quote: quote,
                    color: color,
                    allowFetch: allowHistoryFetch,
                  ),
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
    this.allowHistoryFetch = true,
  });
  final String title;
  final List<MarketInstrument> quotes;
  final ValueChanged<MarketInstrument> onTap;
  final int limit;
  final bool allowHistoryFetch;
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
          if (limit <= 10)
            MarketQuoteRow(
              quote: quote,
              onTap: () => onTap(quote),
              allowHistoryFetch: allowHistoryFetch,
            )
          else
            UiDeferred(
              key: ValueKey(quote.symbol),
              estimatedHeight: 80,
              builder: (_) => MarketQuoteRow(
                quote: quote,
                onTap: () => onTap(quote),
                allowHistoryFetch: allowHistoryFetch,
              ),
            ),
          const UiDivider(spacing: 0),
        ],
      ],
    ),
  );
}

class MarketMoversPanel extends StatefulWidget {
  const MarketMoversPanel({
    super.key,
    this.repository,
    this.limitedCommunityAccess = false,
  });
  final AssetMarketRepository? repository;
  final bool limitedCommunityAccess;
  @override
  State<MarketMoversPanel> createState() => _MarketMoversPanelState();
}

class _MarketMoversPanelState extends State<MarketMoversPanel> {
  late final AssetMarketRepository _repo =
      widget.repository ?? AssetMarketRepository.shared;
  late Future<MarketSnapshot> _future = widget.limitedCommunityAccess
      ? _repo.communityPreview()
      : _repo.snapshot();
  bool _detailOpen = false;

  Future<void> _open(MarketInstrument quote) async {
    if (_detailOpen) return;
    _detailOpen = true;
    try {
      await showSettingsSideSheet<void>(
        context,
        title: quote.symbol,
        subtitle: quote.name,
        desktopWidthRatio: .48,
        minDesktopWidth: 540,
        maxWidth: 760,
        child: widget.limitedCommunityAccess
            ? _CommunityInstrumentPreview(instrument: quote)
            : SingleChildScrollView(
                padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
                child: MarketInstrumentView(
                  instrument: quote,
                  repository: _repo,
                ),
              ),
      );
    } finally {
      _detailOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<MarketSnapshot>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return UiEmptyState(
          title: 'Market data unavailable',
          actionLabel: 'Try again',
          onActionPressed: () => setState(
            () => _future = widget.limitedCommunityAccess
                ? _repo.communityPreview(refresh: true)
                : _repo.snapshot(refresh: true),
          ),
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
            allowHistoryFetch: !widget.limitedCommunityAccess,
          ),
          UiGap.v(context.ui.spacing.md),
          MarketMoversList(
            title: 'Top losers',
            quotes: snapshot.data!.losers,
            onTap: _open,
            allowHistoryFetch: !widget.limitedCommunityAccess,
          ),
        ],
      );
    },
  );
}

class _CommunityInstrumentPreview extends StatelessWidget {
  const _CommunityInstrumentPreview({required this.instrument});

  final MarketInstrument instrument;

  String _compactNumber(num value) {
    final abs = value.abs();
    if (abs >= 1e12) return '${(value / 1e12).toStringAsFixed(2)}T';
    if (abs >= 1e9) return '${(value / 1e9).toStringAsFixed(2)}B';
    if (abs >= 1e6) return '${(value / 1e6).toStringAsFixed(2)}M';
    if (abs >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  double? _numField(String key) {
    final raw = instrument.raw[key];
    return raw is num && raw.isFinite ? raw.toDouble() : null;
  }

  String _textField(String key) => '${instrument.raw[key] ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final bool positive = instrument.changePercent >= 0;
    final Color trendColor = positive
        ? theme.colors.success
        : theme.colors.danger;
    final double? dayLow = _numField('day_low');
    final double? dayHigh = _numField('day_high');
    final double? week52Low = _numField('fifty_two_week_low');
    final double? week52High = _numField('fifty_two_week_high');
    final double? marketCap = _numField('market_cap');
    final double? peRatio = _numField('pe_ratio');
    final double? beta = _numField('beta');
    final double? dividendYield = _numField('dividend_yield');
    final String sector = _textField('sector');
    final String industry = _textField('industry');
    final String exchange = _textField('exchange');

    final List<({String label, String value})> detailRows =
        <({String label, String value})>[
          if (instrument.previousClose != null)
            (
              label: 'Previous close',
              value:
                  '${instrument.previousClose!.toStringAsFixed(2)} ${instrument.currency}',
            ),
          if (dayLow != null && dayHigh != null)
            (
              label: 'Day range',
              value:
                  '${dayLow.toStringAsFixed(2)} – ${dayHigh.toStringAsFixed(2)}',
            ),
          if (week52Low != null && week52High != null)
            (
              label: '52-week range',
              value:
                  '${week52Low.toStringAsFixed(2)} – ${week52High.toStringAsFixed(2)}',
            ),
          if (instrument.volume > 0)
            (label: 'Volume', value: _compactNumber(instrument.volume)),
          if (marketCap != null && marketCap > 0)
            (label: 'Market cap', value: _compactNumber(marketCap)),
          if (peRatio != null && peRatio > 0)
            (label: 'P/E ratio', value: peRatio.toStringAsFixed(2)),
          if (beta != null) (label: 'Beta', value: beta.toStringAsFixed(2)),
          if (dividendYield != null && dividendYield > 0)
            (
              label: 'Dividend yield',
              value: '${(dividendYield * 100).toStringAsFixed(2)}%',
            ),
          if (exchange.isNotEmpty) (label: 'Exchange', value: exchange),
          if (sector.isNotEmpty) (label: 'Sector', value: sector),
          if (industry.isNotEmpty) (label: 'Industry', value: industry),
        ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiCardGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 2,
            largeColumns: 2,
            children: <Widget>[
              UiMetricCard(
                label: 'Last price',
                value: instrument.price.toStringAsFixed(2),
                change:
                    '${positive ? '+' : ''}${instrument.changePercent.toStringAsFixed(2)}%',
                isPositive: positive,
                subtitle: instrument.currency.isEmpty
                    ? 'USD'
                    : instrument.currency,
                icon: Icons.price_change_outlined,
              ),
              UiMetricCard(
                label: 'Market',
                value: instrument.market.isEmpty ? 'Global' : instrument.market,
                subtitle: exchange.isNotEmpty ? exchange : instrument.name,
                icon: Icons.public_rounded,
              ),
            ],
          ),
          if (instrument.spark.length > 1) ...<Widget>[
            UiGap.v(theme.spacing.md),
            UiCard(
              title: 'Recent closing trend',
              child: UiSparkChart(
                data: instrument.spark,
                height: context.sz(140),
                color: trendColor,
                filled: true,
              ),
            ),
          ],
          if (detailRows.isNotEmpty) ...<Widget>[
            UiGap.v(theme.spacing.md),
            UiCard(
              title: 'Ticker details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (int i = 0; i < detailRows.length; i++) ...<Widget>[
                    if (i > 0) const UiDivider(spacing: 0),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: context.sp(theme.spacing.xs),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              detailRows[i].label,
                              style: context.uiText.caption.copyWith(
                                color: theme.colors.foregroundMuted,
                              ),
                            ),
                          ),
                          SizedBox(width: context.sp(theme.spacing.sm)),
                          Text(
                            detailRows[i].value,
                            style: context.uiText.bodyStrong,
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          UiGap.v(theme.spacing.md),
          const UiCallout(
            title: 'Community market preview',
            message:
                'Free includes live pricing, trend charts, and details for Community preview tickers. Full Market Intelligence, screeners, options, and global coverage unlock with AlphaJournal Basic or Pro.',
            intent: UiIntent.info,
          ),
        ],
      ),
    );
  }
}

class _QuoteHistory extends StatefulWidget {
  const _QuoteHistory({
    required this.quote,
    required this.color,
    required this.allowFetch,
  });
  final MarketInstrument quote;
  final Color color;
  final bool allowFetch;

  @override
  State<_QuoteHistory> createState() => _QuoteHistoryState();
}

class _QuoteHistoryState extends State<_QuoteHistory> {
  late Future<List<double>> _history = _load();

  Future<List<double>> _load() => widget.quote.spark.length > 1
      ? Future.value(widget.quote.spark)
      : widget.allowFetch
      ? AssetMarketRepository.shared.getSpark(widget.quote.symbol)
      : Future.value(const <double>[]);

  @override
  void didUpdateWidget(covariant _QuoteHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quote != widget.quote) _history = _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<double>>(
    future: _history,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return UiSkeleton(height: context.sz(36));
      }
      final points = snapshot.data ?? const <double>[];
      if (points.length < 2) {
        return Text('No history', style: context.uiText.caption);
      }
      return UiSparkChart(
        data: points
            .skip((points.length - 24).clamp(0, points.length))
            .toList(),
        color: widget.color,
        filled: true,
        height: context.sz(36),
      );
    },
  );
}
