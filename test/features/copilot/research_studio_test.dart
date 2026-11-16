import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/markdown_kit/markdown_kit.dart';
import 'package:tradex/core/markdown_kit/research/research_panel.dart';
import 'package:tradex/features/copilot/models/research_format.dart';
import 'package:tradex/features/copilot/models/research_policy.dart';
import 'package:tradex/features/copilot/presentation/research_format_picker.dart';

void main() {
  test(
    '60 distinct research contracts produce topic-specific grounded prompts',
    () {
      expect(ResearchFormat.values.length, 60);
      expect(ResearchFormat.values.map((f) => f.id).toSet().length, 60);
      expect(ResearchFormat.values.map((f) => f.directive).toSet().length, 60);
      for (final format in ResearchFormat.values) {
        final prompt = format.prompt('RBI rate decision');
        expect(prompt, contains('RBI rate decision'));
        expect(prompt, contains('research_panel'));
        expect(prompt, contains(format.directive));
        expect(prompt, contains('current request date'));
        expect(format.columns.length, inInclusiveRange(2, 6));
      }
    },
  );
  test(
    'Dart worker freshness clock and detection match current query behavior',
    () {
      expect(
        ResearchPolicy.freshnessInstructions(DateTime.utc(2027)),
        contains('2027-01-01'),
      );
      expect(ResearchPolicy.needsFreshResearch('Latest news today'), isTrue);
      expect(
        ResearchPolicy.needsFreshResearch('Explain a moving average'),
        isFalse,
      );
    },
  );
  test(
    'research evidence retains date and source identity even with an inline citation',
    () {
      final meta = PerplexityAnswerParser.parse('''
[Official release](https://example.org/release)
```research_panel
{"title":"Audit","evidence":[{"claim":"Rate unchanged","sourceTitle":"Official release","sourceUrl":"https://example.org/release","publishedAt":"2026-11-16","eventDate":"2026-11-15"}]}
```
''');
      expect(meta.cards.single.tag, 'research_panel');
      expect(meta.sources.single.publishedAt, '2026-11-16');
      expect(meta.sources.single.snippet, 'Rate unchanged');
      expect(meta.steps.any((s) => s.title.startsWith('Verified')), isFalse);
    },
  );
  test('partial structured output shows a loading card instead of JSON', () {
    final meta = PerplexityAnswerParser.parse(
      '```research_panel\n{"title":"Audit",',
      isStreaming: true,
    );
    expect(meta.cleanMarkdown, contains('loading_card'));
    expect(meta.cleanMarkdown, isNot(contains('"title":"Audit"')));
  });
  test('source links reject unsafe and malformed URLs', () {
    for (final url in [
      'javascript:alert(1)',
      'https://',
      'https://user:password@example.com',
    ]) {
      expect(ResearchPanel.safeUrl(url), isFalse);
    }
    expect(ResearchPanel.safeUrl('https://example.org/report'), isTrue);
  });
  for (final width in [390.0, 900.0]) {
    testWidgets('all 60 result formats render at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final format in ResearchFormat.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: UiTheme.dark().toThemeData(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: RichMarkdownPreview(
                  data:
                      '```research_panel\n${jsonEncode({
                        'format': format.id,
                        'title': format.title,
                        'summary': 'Illustrative test data; not market research.',
                        'columns': format.columns,
                        'rows': [List.filled(format.columns.length, 'Not supplied')],
                        'caveats': ['Missing inputs require clarification.'],
                      })}\n```',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ResearchPanel), findsOneWidget);
        expect(find.text(format.title), findsOneWidget);
        expect(tester.takeException(), isNull, reason: format.id);
      }
    });
  }
  testWidgets(
    'format picker filters, previews and returns an editable prompt',
    (tester) async {
      String? chosen;
      await tester.pumpWidget(
        MaterialApp(
          theme: UiTheme.dark().toThemeData(),
          home: Scaffold(
            body: Builder(
              builder: (context) => UiButton(
                label: 'Open studio',
                onPressed: () async {
                  chosen = await pickResearchFormat(
                    context,
                    subject: 'RBI policy',
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open studio'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Freshness audit');
      await tester.pumpAndSettle();
      expect(find.text('1 format'), findsOneWidget);
      await tester.tap(find.text('Freshness audit').last);
      await tester.pumpAndSettle();
      expect(find.text('Your research prompt'), findsOneWidget);
      await tester.tap(find.text('Use prompt'));
      await tester.pumpAndSettle();
      expect(chosen, contains('RBI policy'));
      expect(chosen, contains('freshness_audit'));
    },
  );
  testWidgets('malformed rows and non-string lists degrade without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResearchPanel(
              data: {
                'title': 44,
                'summary': null,
                'columns': ['Name', 'Value'],
                'rows': [
                  null,
                  'bad',
                  ['Only one'],
                  [null, 4],
                ],
                'caveats': [null, 5],
                'evidence': [
                  false,
                  {'sourceUrl': 'javascript:bad'},
                ],
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Not supplied'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
