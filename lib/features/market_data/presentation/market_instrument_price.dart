import 'package:flutter/material.dart';

import 'package:tradex/core/app-ui/app_ui.dart';
// Both UI libraries are required for feature views.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import 'market_instrument_data.dart';

enum MarketHistoryRange { day, week, twoWeeks, month, twoMonths }

String marketHistoryRangeLabel(MarketHistoryRange range) => switch (range) {
  MarketHistoryRange.day => '1D',
  MarketHistoryRange.week => '1W',
  MarketHistoryRange.twoWeeks => '2W',
  MarketHistoryRange.month => '1M',
  MarketHistoryRange.twoMonths => '2M',
};

/// Slices chronologically sorted candles to match the 2-month CI/CD window
/// (`1D`, `1W`, `2W`, `1M`, `2M`).
List<UiCandle> filterMarketHistoryCandles(
  List<UiCandle> candles,
  MarketHistoryRange range,
) {
  if (candles.isEmpty) return const <UiCandle>[];
  final sorted = List<UiCandle>.from(candles)
    ..sort((a, b) => a.time.compareTo(b.time));
  final DateTime latest = sorted.last.time;
  final DateTime latestDay = DateTime.utc(
    latest.year,
    latest.month,
    latest.day,
  );
  final DateTime cutoff = switch (range) {
    MarketHistoryRange.day => latestDay,
    MarketHistoryRange.week => latestDay.subtract(const Duration(days: 6)),
    MarketHistoryRange.twoWeeks => latestDay.subtract(const Duration(days: 13)),
    MarketHistoryRange.month => latestDay.subtract(const Duration(days: 29)),
    MarketHistoryRange.twoMonths => latestDay.subtract(
      const Duration(days: 59),
    ),
  };
  final filtered = sorted.where((c) {
    final day = DateTime.utc(c.time.year, c.time.month, c.time.day);
    return !day.isBefore(cutoff);
  }).toList();
  return filtered.isNotEmpty ? filtered : <UiCandle>[sorted.last];
}

class InstrumentQuoteCard extends StatelessWidget {
  const InstrumentQuoteCard({super.key, required this.data});
  final InstrumentDetailData data;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final change = data.change;
    final date = data.quoteTime?.toUtc();
    final clock = date == null
        ? null
        : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} UTC';
    return UiCard(
      variant: UiCardVariant.surface,
      accentColor: theme.colors.primary,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: context.sp(theme.spacing.xl),
        runSpacing: context.sp(theme.spacing.md),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: context.sp(theme.spacing.sm),
                runSpacing: context.sp(theme.spacing.xs),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(data.instrument.symbol, style: context.uiText.heading),
                  if (data.exchange case final exchange?)
                    UiBadge(
                      label: exchange,
                      variant: UiBadgeVariant.outline,
                      size: UiSize.sm,
                    ),
                ],
              ),
              if (data.companyName != data.instrument.symbol)
                Text(data.companyName, style: context.uiText.body),
              if (data.sector case final sector?)
                Text(
                  sector,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: context.sp(theme.spacing.sm),
                runSpacing: context.sp(theme.spacing.xs),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    data.price == null
                        ? 'Quote unavailable'
                        : data.formatPrice(data.price),
                    style:
                        (data.price == null
                                ? context.uiText.subheading
                                : context.uiText.display)
                            .copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                  ),
                  if (change != null)
                    UiBadge(
                      label: AppTokens.signedPercent(change),
                      icon: AppTokens.plIcon(change),
                      intent: AppTokens.plIntent(change),
                      variant: UiBadgeVariant.soft,
                    ),
                ],
              ),
              if (data.price != null)
                Text(
                  [
                    data.useHistoricalClose
                        ? 'Last historical close'
                        : 'Snapshot quote',
                    if (date != null) instrumentDate(date),
                    ?clock,
                  ].join(' · '),
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class InstrumentPriceChart extends StatelessWidget {
  const InstrumentPriceChart({
    super.key,
    required this.data,
    required this.range,
    required this.chartType,
    required this.onRangeChanged,
    required this.onChartTypeChanged,
  });

  final InstrumentDetailData data;
  final MarketHistoryRange range;
  final UiPriceChartType chartType;
  final ValueChanged<MarketHistoryRange> onRangeChanged;
  final ValueChanged<UiPriceChartType> onChartTypeChanged;

  @override
  Widget build(BuildContext context) {
    final candles = filterMarketHistoryCandles(data.candles, range);
    final theme = context.ui;
    return UiCard(
      title: 'Price history',
      leading: const Icon(Icons.candlestick_chart_outlined),
      subtitle: candles.isEmpty
          ? null
          : [
              '${candles.length} ${candles.length == 1 ? 'session' : 'sessions'}',
              if (data.currency.isNotEmpty) data.currency,
            ].join(' · '),
      child: candles.isEmpty
          ? const UiEmptyState(
              icon: Icons.show_chart_outlined,
              title: 'No price history in this snapshot',
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final height = constraints.maxWidth < 480 ? 240.0 : 330.0;
                final isLine = chartType == UiPriceChartType.line;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: context.sp(theme.spacing.lg),
                      runSpacing: context.sp(theme.spacing.sm),
                      children: [
                        UiToggleGroup<MarketHistoryRange>(
                          key: const ValueKey('market-history-range-toggle'),
                          size: UiSize.sm,
                          value: range,
                          options: [
                            for (final item in MarketHistoryRange.values)
                              UiOption(
                                value: item,
                                label: marketHistoryRangeLabel(item),
                              ),
                          ],
                          onChanged: onRangeChanged,
                        ),
                        UiToggleGroup<UiPriceChartType>(
                          size: UiSize.sm,
                          value: chartType,
                          onChanged: onChartTypeChanged,
                          options: const [
                            UiOption(
                              value: UiPriceChartType.candles,
                              label: 'Candles',
                            ),
                            UiOption(
                              value: UiPriceChartType.hollow,
                              label: 'Bars',
                            ),
                            UiOption(
                              value: UiPriceChartType.line,
                              label: 'Line',
                            ),
                            UiOption(
                              value: UiPriceChartType.area,
                              label: 'Area',
                            ),
                          ],
                        ),
                      ],
                    ),
                    UiGap.v(theme.spacing.md),
                    if (chartType == UiPriceChartType.candles ||
                        chartType == UiPriceChartType.hollow)
                      UiCandleChart(
                        candles: candles,
                        type: chartType,
                        height: height,
                        priceFormatter: (value) =>
                            data.formatPrice(value, includeCurrency: false),
                        volumeFormatter: uiCompactNumber,
                      )
                    else
                      UiAreaChart(
                        height: height,
                        showLegend: false,
                        fillOpacity: isLine ? 0 : null,
                        series: [
                          UiChartSeries(
                            name: 'Close',
                            type: UiChartSeriesType.area,
                            color: theme.colors.primary,
                            fillOpacity: isLine ? 0 : null,
                          ),
                        ],
                        data: [
                          for (final candle in candles)
                            UiChartPoint(
                              label: instrumentDate(candle.time),
                              values: [candle.close],
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class InstrumentHistoryCards extends StatelessWidget {
  const InstrumentHistoryCards({
    super.key,
    required this.data,
    required this.range,
  });
  final InstrumentDetailData data;
  final MarketHistoryRange range;

  @override
  Widget build(BuildContext context) {
    if (data.candles.isEmpty) return const SizedBox.shrink();
    final candles = filterMarketHistoryCandles(data.candles, range);
    final sessionReturns = <({DateTime date, double change})>[
      for (var i = 1; i < data.candles.length; i++)
        if (data.candles[i - 1].close > 0 &&
            data.candles[i].close.isFinite &&
            data.candles[i - 1].close.isFinite)
          (
            date: data.candles[i].time,
            change:
                (data.candles[i].close / data.candles[i - 1].close - 1) * 100,
          ),
    ].reversed.take(10).toList().reversed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sessionReturns.isNotEmpty) ...[
          UiCard(
            title: 'Session return heatmap',
            subtitle:
                'Close-to-close change over the latest ${sessionReturns.length} sessions',
            child: UiCardGrid(
              minTileWidth: context.sz(122),
              largeColumns: 5,
              equalHeight: true,
              children: [
                for (final item in sessionReturns)
                  AppHeatTile(
                    label: MaterialLocalizations.of(
                      context,
                    ).formatShortMonthDay(item.date),
                    changePercent: item.change,
                  ),
              ],
            ),
          ),
          UiGap.v(context.ui.spacing.md),
        ],
        UiCard(
          title: 'Trading sessions',
          subtitle: 'Prices and volume for the selected range',
          child: UiTable<UiCandle>(
            key: ValueKey(range),
            rows: candles.reversed.toList(),
            stackOnMobile: true,
            pageSize: 10,
            columns: [
              UiTableColumn(
                header: 'Date',
                valueGetter: (row) => instrumentDate(row.time),
                sortValue: (row) => row.time,
              ),
              UiTableColumn(
                header: 'Open',
                valueGetter: (row) => data.formatPrice(row.open),
                numeric: true,
              ),
              UiTableColumn(
                header: 'High',
                valueGetter: (row) => data.formatPrice(row.high),
                numeric: true,
              ),
              UiTableColumn(
                header: 'Low',
                valueGetter: (row) => data.formatPrice(row.low),
                numeric: true,
              ),
              UiTableColumn(
                header: 'Close',
                valueGetter: (row) => data.formatPrice(row.close),
                numeric: true,
              ),
              UiTableColumn(
                header: 'Volume',
                valueGetter: (row) => instrumentCount(row.volume),
                numeric: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
