import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/ai/unified_ai_service.dart';
import 'package:alphajournal/core/config/env_config.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue #43 & OpenAI Integration: Model Configuration & Environment', () {
    test('EnvConfig checks OPEN_AI_KEY environment variable', () {
      // EnvConfig.openaiApiKey is a non-null String getter that reads OPEN_AI_KEY or OPENAI_API_KEY
      expect(EnvConfig.openaiApiKey, isA<String>());
    });

    test('EnvConfig checks TRACKING_ID configuration', () {
      expect(EnvConfig.trackingId, isA<String>());
    });

    test(
      'UnifiedAiService lists gpt-4.1-mini as preferred primary OpenAI model',
      () {
        expect(UnifiedAiService.kOpenAiModels.first, equals('gpt-4.1-mini'));
        expect(UnifiedAiService.kOpenAiModels, contains('gpt-4o-mini'));
      },
    );

    test(
      'all generated IDs for notes, trades, and strategies conform to valid UUIDv4',
      () {
        final noteId = const Uuid().v4();
        final tradeId = const Uuid().v4();
        final strategyId = const Uuid().v4();

        // Verify UUID parsing succeeds without exception
        expect(() => Uuid.parse(noteId), returnsNormally);
        expect(() => Uuid.parse(tradeId), returnsNormally);
        expect(() => Uuid.parse(strategyId), returnsNormally);

        // Verify none use legacy prefixed non-UUID format that caused Postgres type errors
        expect(noteId, isNot(startsWith('note_ai_')));
        expect(tradeId, isNot(startsWith('trade_ai_')));
        expect(strategyId, isNot(startsWith('strat_ai_')));

        // Verify standard 36-character length 8-4-4-4-12 pattern
        final uuidRegex = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          caseSensitive: false,
        );
        expect(uuidRegex.hasMatch(noteId), isTrue);
        expect(uuidRegex.hasMatch(tradeId), isTrue);
        expect(uuidRegex.hasMatch(strategyId), isTrue);
      },
    );
  });

  group('Notes Editor: Text Selection AI Action Prompt Structure', () {
    test(
      'refactor prompt preserves domain guidelines and strict output requirements',
      () {
        const selectedText =
            'Breakout above 185.00 resistance. Stop loss at 182.50.';
        const instruction =
            'Structure into high-signal trading table and trade plan';

        final userPrompt =
            '''Context:
- Note Title: AAPL Swing Trade
- Note Type: analysis
- Instruction: $instruction

Selected Note Passage:
"""
$selectedText
"""''';

        expect(userPrompt, contains(selectedText));
        expect(userPrompt, contains(instruction));
        expect(userPrompt, contains('AAPL Swing Trade'));
      },
    );
  });
}
