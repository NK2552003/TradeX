import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/features/calculators/logic/tax_calculators.dart';
import 'package:alphajournal/features/calculators/logic/trading_calculators.dart';

void main() {
  test('current listed equity rates and annual exemption', () {
    expect(calcStcg(gain: 100000).tax, 20000);
    expect(calcLtcg(gain: 125000).totalTax, 0);
    expect(calcLtcg(gain: 225000).tax, 12500);
    expect(calcLtcg(gain: 225000, exemptionAlreadyUsed: 125000).tax, 28125);
  });
  test('historical rates retain financial-year exemption rules', () {
    expect(
      calcStcg(gain: 100000, period: EquityTaxPeriod.beforeApril2024).tax,
      15000,
    );
    expect(
      calcLtcg(gain: 125000, period: EquityTaxPeriod.beforeApril2024).tax,
      2500,
    );
    expect(
      calcLtcg(gain: 125000, period: EquityTaxPeriod.aprilToJuly2024).tax,
      0,
    );
    expect(
      calcLtcg(gain: 225000, period: EquityTaxPeriod.aprilToJuly2024).tax,
      10000,
    );
  });
  test(
    'invalid risk/reward input never reaches rendering as nonfinite values',
    () {
      for (final entry in [double.infinity, double.nan, 100.0]) {
        final result = calcRiskReward(entry: entry, sl: entry, target: 110);
        expect(result.ratio.isFinite, isTrue);
        expect(result.risk.isFinite, isTrue);
        expect(result.reward.isFinite, isTrue);
      }
    },
  );
}
