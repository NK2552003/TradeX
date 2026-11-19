import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/market_data/models/market_snapshot.dart';

typedef InstrumentRow = Map<String, dynamic>;

InstrumentRow instrumentMap(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

List<InstrumentRow> instrumentRows(Object? value) =>
    value is List ? value.whereType<InstrumentRow>().toList() : const [];

String? instrumentText(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

double? instrumentNumber(Object? value) {
  final number = value is num
      ? value.toDouble()
      : double.tryParse(instrumentText(value) ?? '');
  return number?.isFinite == true ? number : null;
}

String instrumentDate(Object? value) {
  final date = value is DateTime
      ? value
      : DateTime.tryParse(instrumentText(value) ?? '');
  return date == null
      ? instrumentText(value) ?? '—'
      : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String instrumentCount(Object? value) {
  final number = instrumentNumber(value);
  return number == null ? '—' : uiCompactNumber(number);
}

String instrumentPercent(Object? value, {double scale = 1}) {
  final number = instrumentNumber(value);
  return number == null ? '—' : '${(number * scale).toStringAsFixed(2)}%';
}

/// A presentation snapshot shared by all sections of one ticker.
class InstrumentDetailData {
  InstrumentDetailData(this.instrument, this.raw)
    : quote = instrumentMap(raw['quote']),
      summary = instrumentMap(raw['summary']),
      chart = instrumentMap(raw['chart']),
      actions = instrumentMap(raw['dividends_and_splits']),
      holders = instrumentMap(raw['holders']),
      chains = instrumentMap(instrumentMap(raw['options'])['chains']),
      recommendations = instrumentRows(
        raw['recommendations'] ?? raw['analyst_recommendations'],
      ),
      candles = _readCandles(
        instrumentRows(instrumentMap(raw['chart'])['data']),
      );

  final MarketInstrument instrument;
  final InstrumentRow raw, quote, summary, chart, actions, holders, chains;
  final List<InstrumentRow> recommendations;
  final List<UiCandle> candles;

  String get companyName =>
      instrument.name.toUpperCase() != instrument.symbol.toUpperCase() &&
          instrument.name.trim().isNotEmpty
      ? instrument.name
      : instrumentText(summary['name']) ??
            instrumentText(quote['name']) ??
            instrument.symbol;

  String get currency =>
      instrumentText(quote['currency']) ??
      instrumentText(instrument.currency) ??
      '';
  String? get exchange =>
      instrumentText(summary['exchange']) ??
      instrumentText(quote['exchange']) ??
      instrumentText(instrument.market);
  String? get sector => instrumentText(summary['sector']);

  UiCandle? get lastCandle => candles.lastOrNull;
  double? get _listPrice => _nonzero(instrumentNumber(instrument.price));
  double? get _detailPrice => _nonzero(instrumentNumber(quote['price']));
  DateTime? get _detailTime => DateTime.tryParse('${quote['updated_at']}');

  bool get _useDetail =>
      _detailPrice != null &&
      (_listPrice == null ||
          (_detailTime != null &&
              (instrument.updatedAt == null ||
                  _detailTime!.isAfter(instrument.updatedAt!))));

  bool get hasQuote => _useDetail || _listPrice != null;
  InstrumentRow get quoteStatistics => _useDetail
      ? quote
      : hasQuote
      ? instrument.raw
      : const {};
  bool get useHistoricalClose => !hasQuote && price != null;
  double? get price => _useDetail
      ? _detailPrice
      : _listPrice ?? instrumentNumber(lastCandle?.close);
  double? get change => _useDetail
      ? instrumentNumber(quote['change_pct'])
      : hasQuote
      ? instrumentNumber(instrument.raw['change_pct'])
      : null;
  double? get previousClose => _useDetail
      ? instrumentNumber(quote['previous_close'])
      : hasQuote
      ? instrumentNumber(instrument.previousClose)
      : null;
  DateTime? get quoteTime => _useDetail
      ? _detailTime
      : hasQuote
      ? instrument.updatedAt
      : lastCandle?.time;

  String formatPrice(num? number, {bool includeCurrency = true}) {
    if (number == null || !number.isFinite) return '—';
    final digits = number != 0 && number.abs() < 1 ? 4 : 2;
    return uiGrouped(
      number,
      decimals: digits,
      prefix: includeCurrency && currency.isNotEmpty ? '$currency ' : '',
    );
  }

  String formatCapital(Object? value) {
    final number = instrumentNumber(value);
    if (number == null) return '—';
    return [
      if (currency.isNotEmpty) currency,
      if (number.abs() >= 1e12)
        '${(number / 1e12).toStringAsFixed(2)}T'
      else
        uiCompactNumber(number),
    ].join(' ');
  }

  static double? _nonzero(double? value) => value == 0 ? null : value;

  static List<UiCandle> _readCandles(List<InstrumentRow> rows) {
    final result = <UiCandle>[];
    for (final row in rows) {
      final date = DateTime.tryParse('${row['date']}');
      final open = instrumentNumber(row['open']);
      final high = instrumentNumber(row['high']);
      final low = instrumentNumber(row['low']);
      final close = instrumentNumber(row['close']);
      if (date == null ||
          open == null ||
          high == null ||
          low == null ||
          close == null ||
          high < low) {
        continue;
      }
      result.add(
        UiCandle(
          time: date,
          open: open,
          high: high,
          low: low,
          close: close,
          volume: instrumentNumber(row['volume']) ?? 0,
        ),
      );
    }
    return result..sort((a, b) => a.time.compareTo(b.time));
  }
}
