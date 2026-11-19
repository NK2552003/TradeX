import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/features/copilot/models/research_format.dart';
import 'package:alphajournal/features/copilot/models/research_router.dart';

void main() {
  test(
    'routes natural questions to suitable native cards or research formats',
    () {
      for (final entry in {
        'Give me a market briefing for today': 'session_brief',
        'Review my trade from yesterday': 'trade_debrief',
        'Help with position sizing for my portfolio': 'position_sizing',
        'What are the biggest risks for this company?': 'risk_register',
        'Show a worked example of compound returns': 'worked_example',
        'Compare NVDA with its peers': 'peer_benchmark',
        'Find stale data in this answer': 'freshness_audit',
      }.entries) {
        expect(
          ResearchRouter.select(entry.key).format?.id,
          entry.value,
          reason: entry.key,
        );
      }
      expect(
        ResearchRouter.select('Analyze NVDA earnings').nativeCard,
        'earnings',
      );
      expect(
        ResearchRouter.select('Compare Apple vs Microsoft').nativeCard,
        'compare',
      );
      expect(
        ResearchRouter.select('Latest news about the RBI').nativeCard,
        'news',
      );
    },
  );
  test('explicit studio formats beat topic heuristics for all 60 formats', () {
    for (final format in ResearchFormat.values) {
      final route = ResearchRouter.select(
        format.prompt('Latest earnings, risks and macro news'),
      );
      expect(route.format?.id, format.id);
      expect(route.explicit, isTrue);
    }
  });
  test(
    'plain output, code, skill commands and ambiguous queries are respected',
    () {
      expect(
        ResearchRouter.select('Explain earnings in one sentence').label,
        'Direct answer',
      );
      expect(
        ResearchRouter.select(
          'Write a Python function to compare prices',
        ).label,
        'Code & explanation',
      );
      expect(
        ResearchRouter.select('/risk analyze this portfolio').label,
        'Trader skill',
      );
      expect(ResearchRouter.select('Hello').format, isNull);
      expect(
        ResearchRouter.select('What about that?').instructions,
        contains('conversation context'),
      );
    },
  );
}
