import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';
import '../models/app_models_extra.dart';
import '../theme/app_tokens.dart';

/// Timeframe options offered above a price chart.
enum AppTimeframe { m5, m15, h1, h4, d1, w1 }

String appTimeframeLabel(AppTimeframe tf) => switch (tf) {
      AppTimeframe.m5 => '5m',
      AppTimeframe.m15 => '15m',
      AppTimeframe.h1 => '1H',
      AppTimeframe.h4 => '4H',
      AppTimeframe.d1 => '1D',
      AppTimeframe.w1 => '1W',
    };

/// Ticker price chart: header quote, timeframe switcher, chart-type toggle
/// and the candle chart itself with entry/stop/target lines.
class AppPriceChartBlock extends StatelessWidget {
  const AppPriceChartBlock({
    super.key,
    required this.candles,
    this.ticker,
    this.timeframe = AppTimeframe.d1,
    this.timeframes = AppTimeframe.values,
    this.onTimeframeChanged,
    this.chartType = UiPriceChartType.candles,
    this.onChartTypeChanged,
    this.entry,
    this.stopLoss,
    this.target,
    this.markers = const <UiCandleMarker>[],
    this.overlays = const <UiCandleOverlay>[],
    this.loading = false,
    this.height,
    this.showVolume = true,
  });

  final List<AppCandle> candles;
  final AppTicker? ticker;
  final AppTimeframe timeframe;
  final List<AppTimeframe> timeframes;
  final ValueChanged<AppTimeframe>? onTimeframeChanged;
  final UiPriceChartType chartType;
  final ValueChanged<UiPriceChartType>? onChartTypeChanged;
  final double? entry;
  final double? stopLoss;
  final double? target;
  final List<UiCandleMarker> markers;
  final List<UiCandleOverlay> overlays;
  final bool loading;
  final double? height;
  final bool showVolume;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<UiPriceLine> lines = <UiPriceLine>[
      if (entry != null)
        UiPriceLine(
          price: entry!,
          label: 'Entry ${AppTokens.money(entry!)}',
          intent: UiIntent.info,
        ),
      if (stopLoss != null)
        UiPriceLine(
          price: stopLoss!,
          label: 'Stop ${AppTokens.money(stopLoss!)}',
          intent: UiIntent.bearish,
        ),
      if (target != null)
        UiPriceLine(
          price: target!,
          label: 'Target ${AppTokens.money(target!)}',
          intent: UiIntent.bullish,
        ),
    ];

    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (ticker != null) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(ticker!.symbol, style: context.uiText.heading),
                      Text(
                        ticker!.name,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.caption
                            .copyWith(color: theme.colors.foregroundMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      AppTokens.money(ticker!.price,
                          symbol: ticker!.currencySymbol),
                      style: context.uiText.title,
                    ),
                    Text(
                      AppTokens.signedPercent(ticker!.changePercent),
                      style: context.uiText.bodyStrong.copyWith(
                        color: AppTokens.pl(context, ticker!.changePercent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.md)),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: UiToggleGroup<AppTimeframe>(
                    value: timeframe,
                    onChanged: onTimeframeChanged,
                    options: <UiToggleOption<AppTimeframe>>[
                      for (final AppTimeframe tf in timeframes)
                        UiToggleOption<AppTimeframe>(
                          value: tf,
                          label: appTimeframeLabel(tf),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              UiIconButton(
                icon: chartType == UiPriceChartType.candles
                    ? Icons.candlestick_chart_outlined
                    : Icons.show_chart,
                tooltip: 'Chart type',
                size: UiSize.sm,
                onPressed: onChartTypeChanged == null
                    ? null
                    : () => onChartTypeChanged!(
                          chartType == UiPriceChartType.candles
                              ? UiPriceChartType.line
                              : UiPriceChartType.candles,
                        ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiAsyncView(
            loading: loading,
            isEmpty: candles.isEmpty,
            emptyTitle: 'No price data',
            emptyMessage: 'Price history is unavailable for this symbol.',
            emptyIcon: Icons.show_chart,
            loadingBuilder: (BuildContext ctx) =>
                UiSkeleton(height: height ?? ctx.sz(280)),
            builder: (BuildContext ctx) => UiCandleChart(
              height: height,
              type: chartType,
              showVolume: showVolume,
              priceLines: lines,
              markers: markers,
              overlays: overlays,
              candles: <UiCandle>[
                for (final AppCandle c in candles)
                  UiCandle(
                    time: c.time,
                    open: c.open,
                    high: c.high,
                    low: c.low,
                    close: c.close,
                    volume: c.volume,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Backtest / simulation summary: headline metrics plus equity curve.
class AppBacktestResultBlock extends StatelessWidget {
  const AppBacktestResultBlock({
    super.key,
    required this.result,
    this.onRerun,
    this.onSave,
  });

  final AppBacktestResult result;
  final VoidCallback? onRerun;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: result.name,
      subtitle: result.runAt == null
          ? 'Backtest result'
          : 'Run ${AppTokens.relativeTime(result.runAt!)}',
      trailing: UiIconButton(
        icon: Icons.replay,
        size: UiSize.sm,
        tooltip: 'Re-run',
        onPressed: onRerun,
      ),
      footer: onSave == null
          ? null
          : UiButton(
              label: 'Save result',
              variant: UiVariant.outline,
              leadingIcon: Icons.bookmark_border,
              onPressed: onSave,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: context.sp(theme.spacing.lg),
            runSpacing: context.sp(theme.spacing.md),
            children: <Widget>[
              _metric(context, 'Net P/L',
                  AppTokens.signedMoney(result.netPnl),
                  color: AppTokens.pl(context, result.netPnl)),
              _metric(context, 'Win rate',
                  AppTokens.percent(result.winRate * 100)),
              _metric(context, 'Trades', '${result.trades}'),
              _metric(context, 'Max DD',
                  AppTokens.percent(result.maxDrawdown * 100),
                  color: theme.colors.destructive),
              if (result.profitFactor != null)
                _metric(context, 'Profit factor',
                    result.profitFactor!.toStringAsFixed(2)),
              if (result.sharpe != null)
                _metric(context, 'Sharpe', result.sharpe!.toStringAsFixed(2)),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),
          UiSparkChart(
            values: result.equityCurve,
            height: context.sz(72),
            color: AppTokens.pl(context, result.netPnl),
          ),
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value,
      {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: context.uiText.caption
              .copyWith(color: context.uiColors.foregroundMuted),
        ),
        Text(
          value,
          style: context.uiText.numeric.copyWith(color: color),
        ),
      ],
    );
  }
}
