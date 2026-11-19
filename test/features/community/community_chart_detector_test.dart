import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/features/community/data/community_chart_detector.dart';

void main() {
  test('non-chart image cannot supply setup or candles', () {
    final result = CommunityChartDetection.parse(
      jsonEncode({
        'isChart': false,
        'setup': {'ticker': 'BTC', 'entry': 100},
      }),
    );
    expect(result.isChart, isFalse);
    expect(result.setup, isEmpty);
    expect(result.candles, isEmpty);
  });
  test('unreadable axes preserve levels but never fabricate candles', () {
    final result = CommunityChartDetection.parse(
      jsonEncode({
        'isChart': true,
        'axesReadable': false,
        'setup': {
          'ticker': 'xauusd',
          'entry': '3,900',
          'target': '-10',
          'side': 'short',
        },
        'candles': [
          {
            'time': '2026-11-17T00:00:00Z',
            'open': 10,
            'high': 20,
            'low': 9,
            'close': 15,
          },
        ],
      }),
    );
    expect(result.setup, {
      'ticker': 'XAUUSD',
      'entry': '3900',
      'side': 'SHORT',
    });
    expect(result.candles, isEmpty);
  });
  test(
    'rejects malformed OHLC and ambiguous timestamps, deduplicates and sorts',
    () {
      Map<String, Object> candle(String time, {double high = 20}) => {
        'time': time,
        'open': 10,
        'high': high,
        'low': 9,
        'close': 15,
      };
      final result = CommunityChartDetection.parse(
        jsonEncode({
          'isChart': true,
          'axesReadable': true,
          'candles': [
            candle('2026-11-17T10:00:00Z'),
            candle('2026-11-17T09:00:00Z'),
            candle('2026-11-17T09:00:00Z'),
            candle('2026-11-17T08:00:00'),
            candle('2026-11-17T11:00:00Z', high: 5),
          ],
        }),
      );
      expect(result.candles.length, 2);
      expect(result.candles.first.time.hour, 9);
      expect(result.candles.first.volume, 0);
      expect(jsonDecode(result.candleJson), hasLength(2));
    },
  );
  test('malformed response fails instead of silently inventing a setup', () {
    expect(
      () => CommunityChartDetection.parse('A nice chart'),
      throwsFormatException,
    );
  });
}
