/// Pure currency maths. No Flutter imports, no network calls.
///
/// Rates are bundled statics so the converter works fully offline. Phase 2 can
/// inject live rates through [convertCurrency]'s `rates` parameter without
/// touching any screen.
library;

/// Units of each currency per 1 USD.
const Map<String, double> kFallbackRatesVsUsd = <String, double>{
  'USD': 1.0,
  'INR': 94.73,
  'EUR': 0.86193,
  'GBP': 0.74097,
  'JPY': 158.13,
  'AUD': 1.3964,
  'CAD': 1.3858,
  'SGD': 1.2709,
  'AED': 3.6725,
  'CHF': 0.81144,
  'CNY': 6.7171,
};

/// The day [kFallbackRatesVsUsd] was captured — shown to the user so a stale
/// conversion is never mistaken for a live quote.
const String kRatesDate = '2026-09-04';

/// Display names, kept beside the rates so pickers stay in sync.
const Map<String, String> kCurrencyNames = <String, String>{
  'USD': 'US Dollar',
  'INR': 'Indian Rupee',
  'EUR': 'Euro',
  'GBP': 'British Pound',
  'JPY': 'Japanese Yen',
  'AUD': 'Australian Dollar',
  'CAD': 'Canadian Dollar',
  'SGD': 'Singapore Dollar',
  'AED': 'UAE Dirham',
  'CHF': 'Swiss Franc',
  'CNY': 'Chinese Yuan',
};

class ConversionResult {
  const ConversionResult({
    required this.amount,
    required this.converted,
    required this.rate,
    required this.inverseRate,
    required this.from,
    required this.to,
  });

  final double amount;
  final double converted;

  /// Units of [to] per 1 unit of [from].
  final double rate;
  final double inverseRate;
  final String from;
  final String to;
}

/// Cross-rate conversion via USD. Unknown codes fall back to a rate of 1.
ConversionResult convertCurrency({
  required double amount,
  required String from,
  required String to,
  Map<String, double> rates = kFallbackRatesVsUsd,
}) {
  final double fromRate = rates[from] ?? 1;
  final double toRate = rates[to] ?? 1;
  final double rate = fromRate == 0 ? 0 : toRate / fromRate;
  return ConversionResult(
    amount: amount,
    converted: amount * rate,
    rate: rate,
    inverseRate: rate == 0 ? 0 : 1 / rate,
    from: from,
    to: to,
  );
}

class PipResult {
  const PipResult({
    required this.pipSize,
    required this.valueInQuote,
    required this.valueInInr,
    required this.units,
  });

  /// One pip in price terms — 0.0001 normally, 0.01 for JPY pairs.
  final double pipSize;

  /// Pip value in the quote currency.
  final double valueInQuote;
  final double valueInInr;
  final double units;
}

/// Pip value for a forex position.
///
/// [pair] is a six-letter code such as `EURUSD`; [lotSize] is in units
/// (100000 = one standard lot). JPY quotes use a 0.01 pip.
PipResult calcPipValue({
  required String pair,
  required double lotSize,
  double usdInr = 94.73,
  Map<String, double> rates = kFallbackRatesVsUsd,
}) {
  final String code = pair.toUpperCase().replaceAll('/', '');
  final String quote = code.length >= 6 ? code.substring(3, 6) : 'USD';
  final double pipSize = quote == 'JPY' ? 0.01 : 0.0001;
  final double valueInQuote = pipSize * lotSize;

  // Quote → INR: quote per USD, then USD per INR.
  final double quotePerUsd = rates[quote] ?? 1;
  final double valueInInr = quotePerUsd == 0
      ? 0
      : valueInQuote / quotePerUsd * usdInr;

  return PipResult(
    pipSize: pipSize,
    valueInQuote: valueInQuote,
    valueInInr: valueInInr,
    units: lotSize,
  );
}
