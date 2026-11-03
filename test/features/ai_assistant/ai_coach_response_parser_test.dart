import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/ai_assistant/models/ai_coach_response.dart';

void main() {
  test('parses the labeled coach contract into five plan steps', () {
    final AiCoachResponse? response = AiCoachResponse.tryParse('''
Label: Swing trade
Title: RELIANCE Institutional Swing Trade Breakdown

Risk/Reward
- Initial: 1:2
- Extended: 1:3

The plan
1. Entry: Wait for the demand zone.
2. Confirmation: Look for volume expansion.
3. Stop: Place it below the invalidation level.
4. Targets: Use T1 and T2.
5. Risk management: Size from fixed equity risk.

Closing line: A close below demand invalidates the setup.
''');

    expect(response, isNotNull);
    expect(response!.title, 'RELIANCE Institutional Swing Trade Breakdown');
    expect(response.initialRiskReward, '1:2');
    expect(response.extendedRiskReward, '1:3');
    expect(response.plan, hasLength(5));
    expect(response.closing, contains('invalidates'));
  });

  test('parses the JSON contract and rejects incomplete output', () {
    final AiCoachResponse? response = AiCoachResponse.tryParse('''
{"label":"Swing trade","title":"TCS Institutional Swing Trade Breakdown","rr_initial":"1:2","rr_extended":"1:4","plan":["one","two","three","four","five"],"closing":"A close below support invalidates the setup."}
''');
    expect(response?.plan.last, 'five');
    expect(
      AiCoachResponse.tryParse('Label: Swing trade\nTitle: Missing plan'),
      isNull,
    );
  });
}
