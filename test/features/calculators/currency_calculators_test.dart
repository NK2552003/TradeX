import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/calculators/logic/currency_calculators.dart';

void main() {
  group('convertCurrency', () {
    test('USD to INR uses the bundled rate directly', () {
      final ConversionResult r = convertCurrency(
        amount: 1000,
        from: 'USD',
        to: 'INR',
      );

      expect(r.rate, closeTo(94.73, 1e-9));
      expect(r.converted, closeTo(94730, 1e-6));
      expect(r.inverseRate, closeTo(1 / 94.73, 1e-12));
    });

    test('a cross rate goes through USD', () {
      final ConversionResult r = convertCurrency(
        amount: 100,
        from: 'EUR',
        to: 'INR',
      );

      expect(r.rate, closeTo(94.73 / 0.86193, 1e-9));
      expect(r.converted, closeTo(100 * 94.73 / 0.86193, 1e-6));
    });

    test('converting to the same currency is a no-op', () {
      final ConversionResult r = convertCurrency(
        amount: 500,
        from: 'GBP',
        to: 'GBP',
      );

      expect(r.rate, 1);
      expect(r.converted, 500);
    });

    test('round-tripping returns the original amount', () {
      final ConversionResult out = convertCurrency(
        amount: 250,
        from: 'INR',
        to: 'JPY',
      );
      final ConversionResult back = convertCurrency(
        amount: out.converted,
        from: 'JPY',
        to: 'INR',
      );

      expect(back.converted, closeTo(250, 1e-9));
    });

    test('an unknown code falls back to a rate of one', () {
      final ConversionResult r = convertCurrency(
        amount: 100,
        from: 'XXX',
        to: 'USD',
      );

      expect(r.rate, 1);
      expect(r.converted, 100);
    });

    test('injected rates override the bundled ones', () {
      final ConversionResult r = convertCurrency(
        amount: 10,
        from: 'USD',
        to: 'INR',
        rates: const <String, double>{'USD': 1, 'INR': 90},
      );

      expect(r.converted, 900);
    });

    test('every rate has a display name', () {
      for (final String code in kFallbackRatesVsUsd.keys) {
        expect(kCurrencyNames[code], isNotNull, reason: code);
      }
      expect(kRatesDate, isNotEmpty);
    });
  });

  group('calcPipValue', () {
    test(r'a standard EURUSD lot is $10 a pip', () {
      final PipResult r = calcPipValue(pair: 'EURUSD', lotSize: 100000);

      expect(r.pipSize, 0.0001);
      expect(r.valueInQuote, closeTo(10, 1e-9));
      expect(r.valueInInr, closeTo(947.3, 1e-6));
      expect(r.units, 100000);
    });

    test('a JPY quote uses a 0.01 pip', () {
      final PipResult r = calcPipValue(pair: 'USDJPY', lotSize: 100000);

      expect(r.pipSize, 0.01);
      expect(r.valueInQuote, closeTo(1000, 1e-9));
      // 1000 JPY back to INR through USD.
      expect(r.valueInInr, closeTo(1000 / 158.13 * 94.73, 1e-6));
    });

    test('an INR quote needs no conversion beyond the pip', () {
      final PipResult r = calcPipValue(pair: 'USDINR', lotSize: 1000);

      expect(r.valueInQuote, closeTo(0.1, 1e-12));
      expect(r.valueInInr, closeTo(0.1, 1e-9));
    });

    test('a slashed pair is accepted', () {
      final PipResult slashed = calcPipValue(pair: 'EUR/USD', lotSize: 10000);
      final PipResult plain = calcPipValue(pair: 'EURUSD', lotSize: 10000);

      expect(slashed.valueInInr, closeTo(plain.valueInInr, 1e-12));
    });

    test('a custom USD/INR rate changes the rupee value', () {
      final PipResult r = calcPipValue(
        pair: 'EURUSD',
        lotSize: 100000,
        usdInr: 90,
      );

      expect(r.valueInInr, closeTo(900, 1e-6));
    });

    test('lot size scales the pip value linearly', () {
      final PipResult micro = calcPipValue(pair: 'EURUSD', lotSize: 1000);
      final PipResult standard = calcPipValue(pair: 'EURUSD', lotSize: 100000);

      expect(standard.valueInInr, closeTo(micro.valueInInr * 100, 1e-6));
    });
  });
}
