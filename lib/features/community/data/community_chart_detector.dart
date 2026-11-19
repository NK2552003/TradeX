import 'dart:convert';

import 'package:alphajournal/core/ai/unified_ai_service.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

class CommunityChartDetection {
  const CommunityChartDetection({
    required this.isChart,
    this.setup = const {},
    this.candles = const [],
  });

  final bool isChart;
  final Map<String, String> setup;
  final List<UiCandle> candles;

  String get candleJson => jsonEncode([
    for (final candle in candles)
      {
        'time': candle.time.toIso8601String(),
        'open': candle.open,
        'high': candle.high,
        'low': candle.low,
        'close': candle.close,
        'volume': candle.volume,
      },
  ]);

  factory CommunityChartDetection.parse(String response) {
    final cleaned = response
        .trim()
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '');
    final decoded = jsonDecode(cleaned);
    if (decoded is! Map || decoded['isChart'] is! bool) {
      throw const FormatException(
        'Chart detection returned an invalid response.',
      );
    }
    if (decoded['isChart'] != true) {
      return const CommunityChartDetection(isChart: false);
    }
    final setup = <String, String>{};
    final raw = decoded['setup'];
    if (raw is Map) {
      final ticker = raw['ticker']?.toString().trim().toUpperCase() ?? '';
      if (RegExp(r'^[A-Z0-9][A-Z0-9.:-]{0,19}$').hasMatch(ticker)) {
        setup['ticker'] = ticker;
      }
      final side = raw['side']?.toString().toUpperCase();
      if (side == 'LONG' || side == 'SHORT') setup['side'] = side!;
      for (final key in ['entry', 'stopLoss', 'target']) {
        final value = raw[key]?.toString().replaceAll(',', '').trim() ?? '';
        final number = double.tryParse(value);
        if (number != null && number.isFinite && number > 0) setup[key] = value;
      }
    }
    final candles = <UiCandle>[];
    // No calibrated axes means no reconstructable time series.
    if (decoded['axesReadable'] == true && decoded['candles'] is List) {
      final times = <DateTime>{};
      for (final row in (decoded['candles'] as List).take(120)) {
        if (row is! Map) continue;
        final stamp = row['time']?.toString() ?? '';
        if (!RegExp(
          r'^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:\d{2})$',
        ).hasMatch(stamp)) {
          continue;
        }
        final time = DateTime.tryParse(stamp);
        double? number(String key) => double.tryParse('${row[key]}');
        final open = number('open'),
            high = number('high'),
            low = number('low'),
            close = number('close');
        if (time == null ||
            [
              open,
              high,
              low,
              close,
            ].any((n) => n == null || !n.isFinite || n <= 0)) {
          continue;
        }
        if (low! > high! ||
            open! < low ||
            open > high ||
            close! < low ||
            close > high ||
            !times.add(time)) {
          continue;
        }
        final volume = number('volume');
        candles.add(
          UiCandle(
            time: time,
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume != null && volume.isFinite && volume >= 0
                ? volume
                : 0,
          ),
        );
      }
      candles.sort((a, b) => a.time.compareTo(b.time));
    }
    return CommunityChartDetection(
      isChart: true,
      setup: setup,
      candles: candles,
    );
  }
}

class CommunityChartDetector {
  CommunityChartDetector({UnifiedAiService? service})
    : _service = service ?? UnifiedAiService.instance;
  final UnifiedAiService _service;

  Future<CommunityChartDetection> detect(String imageDataUrl) async {
    final response = await _service.inspectImage(
      imageDataUrl: imageDataUrl,
      prompt:
          'Detect whether this image contains a financial price chart. '
          'Extract ONLY explicitly labeled ticker, LONG/SHORT position direction, '
          'entry, stop loss and target. A current-price marker is NOT an entry. '
          'Do not recommend a trade. Reconstruct at most 120 visible OHLC candles '
          'only when both the price scale and full dates, times and timezone '
          'can be read. Values reconstructed from pixels are approximate. '
          'If axes or dates/timezone are missing, set axesReadable=false and candles=[]. '
          'Do not infer a date from today. Omit missing setup values. '
          'Unknown volume must be omitted. Non-chart images return isChart=false. '
          'Return ONLY JSON, no research or visual blocks: '
          '{"isChart":true,"axesReadable":false,"setup":{"ticker":"",'
          '"side":"","entry":"","stopLoss":"","target":""},'
          '"candles":[{"time":"ISO8601 with timezone","open":0,"high":0,'
          '"low":0,"close":0}]}.',
    );
    return CommunityChartDetection.parse(response);
  }
}
