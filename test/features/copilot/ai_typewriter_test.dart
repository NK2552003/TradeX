import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/app-ui/motion/ai_typewriter.dart';
import 'package:alphajournal/core/app-ui/motion/ai_typing_indicator.dart';
import 'package:alphajournal/core/markdown_kit/markdown_preview.dart';

void main() {
  testWidgets('incoming chunks extend the queue without resetting progress', (
    tester,
  ) async {
    final writer = AiTypewriter(minGraphemesPerTick: 1, catchUpDivisor: 0);
    addTearDown(writer.dispose);
    writer.reset('Hello', animate: true);
    expect(writer.visibleText, '');
    await tester.pump(aiTypingCharacterInterval);
    expect(writer.visibleText, 'H');
    writer.update('Hello world');
    expect(writer.visibleText, 'H');
    await tester.pump(aiTypingCharacterInterval);
    expect(writer.visibleText, 'He');
    await tester.pump(const Duration(seconds: 1));
    expect(writer.visibleText, 'Hello world');
    expect(writer.isTyping, isFalse);
  });
  testWidgets(
    'default typewriter matches fast real-AI streaming speed and adaptive catch-up',
    (tester) async {
      final writer = AiTypewriter();
      addTearDown(writer.dispose);
      final longAnswer = List.filled(
        50,
        'Strong earnings momentum across AI infra. ',
      ).join();
      writer.reset(longAnswer, animate: true);
      expect(writer.visibleText, '');
      await tester.pump(aiTypingCharacterInterval);
      expect(
        writer.visibleText.length,
        greaterThanOrEqualTo(aiTypingMinGraphemesPerTick),
      );
      expect(writer.visibleText.length, lessThan(longAnswer.length));
      await tester.pump(const Duration(milliseconds: 1600));
      expect(writer.visibleText, longAnswer);
      expect(writer.isTyping, isFalse);
    },
  );
  testWidgets('skip flushes queued content and subsequent chunks immediately', (
    tester,
  ) async {
    final writer = AiTypewriter();
    addTearDown(writer.dispose);
    writer.reset('Partial answer', animate: true);
    writer.skip();
    expect(writer.visibleText, 'Partial answer');
    writer.update('Partial answer plus another chunk');
    expect(writer.visibleText, 'Partial answer plus another chunk');
    expect(writer.isTyping, isFalse);
  });
  testWidgets('reduced motion reveals instantly and graphemes remain whole', (
    tester,
  ) async {
    final writer = AiTypewriter(minGraphemesPerTick: 1, catchUpDivisor: 0);
    addTearDown(writer.dispose);
    writer.reset('👩🏽‍💻éX', animate: true);
    await tester.pump(aiTypingCharacterInterval);
    expect(writer.visibleText, '👩🏽‍💻');
    writer.reducedMotion = true;
    expect(writer.visibleText, '👩🏽‍💻éX');
    writer.update('👩🏽‍💻éXYZ');
    expect(writer.isTyping, isFalse);
    expect(writer.visibleText, '👩🏽‍💻éXYZ');
  });
  testWidgets('saved answers show immediately and new message resets skip', (
    tester,
  ) async {
    final writer = AiTypewriter();
    addTearDown(writer.dispose);
    writer.reset('Saved answer', animate: false);
    expect(writer.visibleText, 'Saved answer');
    writer.skip();
    writer.reset('New answer', animate: true);
    expect(writer.visibleText, '');
    expect(writer.skipped, isFalse);
    writer.skip();
  });
  testWidgets(
    'markdown and code reveal progressively, Skip finishes, cursor disappears',
    (tester) async {
      const body =
          '## Deep Quantitative Analysis\n\n'
          '**Clear institutional accumulation evidence** across semiconductor supply chains and hyperscaler capital expenditure revisions.\n\n'
          '- Data center revenue expanded +78% YoY with resilient gross margins.\n'
          '- Forward guidance exceeded consensus estimates across every segment.\n\n'
          '```dart\nprint("hello");\n```';
      Future<void> render({required bool pending, bool reduced = false}) =>
          tester.pumpWidget(
            MaterialApp(
              theme: UiTheme.dark().toThemeData(),
              home: MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: AppAiMessageBubble(
                      message: AppAiMessage(
                        id: 'typing',
                        role: AppAiRole.assistant,
                        body: body,
                        pending: pending,
                      ),
                      minimal: true,
                    ),
                  ),
                ),
              ),
            ),
          );
      await render(pending: true);
      await tester.pump(const Duration(milliseconds: 48));
      expect(find.byType(AiTypingCursor), findsOneWidget);
      final preview = tester.widget<RichMarkdownPreview>(
        find.byType(RichMarkdownPreview),
      );
      expect(preview.data.length, lessThan(body.length));
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(
        tester
            .widget<RichMarkdownPreview>(find.byType(RichMarkdownPreview))
            .data,
        contains('print("hello")'),
      );
      await render(pending: false);
      await tester.pump();
      expect(find.byType(AiTypingCursor), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'reduced-motion output has neither animation nor blinking cursor',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(
              body: AppAiMessageBubble(
                message: AppAiMessage(
                  id: 'reduced',
                  role: AppAiRole.assistant,
                  body: 'Entire response appears immediately.',
                  pending: true,
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<RichMarkdownPreview>(find.byType(RichMarkdownPreview))
            .data,
        contains('Entire response appears immediately.'),
      );
      expect(find.byType(AiTypingCursor), findsNothing);
      expect(find.text('Skip'), findsNothing);
    },
  );
  testWidgets(
    'auto-scroll follows typed output but preserves a reader scrolling up',
    (tester) async {
      tester.view.physicalSize = const Size(600, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final body = List.filled(30, 'A growing line of research.').join('\n\n');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppAiChatBlock(
              onSend: (_) {},
              composer: const SizedBox(height: 40),
              messages: [
                for (var i = 0; i < 8; i++)
                  AppAiMessage(
                    id: 'old-$i',
                    role: AppAiRole.user,
                    body: 'Earlier question $i',
                  ),
                AppAiMessage(
                  id: 'scrolling',
                  role: AppAiRole.assistant,
                  body: body,
                  pending: true,
                ),
              ],
            ),
          ),
        ),
      );
      Future<void> advanceFrames(Duration total) async {
        const step = Duration(milliseconds: 50);
        final ticks = (total.inMilliseconds / step.inMilliseconds).ceil();
        for (int i = 0; i < ticks; i++) {
          await tester.pump(step);
        }
      }

      await advanceFrames(const Duration(milliseconds: 300));
      final list = find.byType(ListView);
      final scroll = tester.widget<ListView>(list).controller!;
      await advanceFrames(const Duration(milliseconds: 2200));
      expect(scroll.position.extentAfter, lessThan(5));
      await tester.drag(list, const Offset(0, 300));
      await advanceFrames(const Duration(milliseconds: 300));
      final readingOffset = scroll.offset;
      await advanceFrames(const Duration(milliseconds: 2200));
      expect(scroll.offset, closeTo(readingOffset, 1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'streaming unclosed code fences and trailing blocks do not trip _inlines.isEmpty',
    (tester) async {
      Future<void> pumpPreview(String data, {required bool streaming}) =>
          tester.pumpWidget(
            MaterialApp(
              theme: UiTheme.dark().toThemeData(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: RichMarkdownPreview(
                    data: data,
                    emptyPlaceholder: '',
                    selectable: !streaming,
                    showTypingCursor: streaming,
                  ),
                ),
              ),
            ),
          );

      final samples = <String>[
        'Analysis:\n```dart\nvoid main() {',
        'Analysis:\n```chart\n{"type": "bar"',
        'Analysis:\n~~~python\nprint("hi")',
        'Analysis:\n````markdown\ninner ```',
        '> ```dart\n> final x = 1;',
        '- [ ] ',
        'Summary\n\n---',
        '| A | B |\n| --- | --- |\n| 1 | 2 |',
        'Analysis:\n```dart\nvoid main() {}\n```',
      ];

      for (final sample in samples) {
        await pumpPreview(sample, streaming: true);
        expect(tester.takeException(), isNull);
        await pumpPreview(sample, streaming: false);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'research_panel JSON renders as ResearchPanel across research_panel, json, untagged, and bare forms',
    (tester) async {
      const jsonBody = '''{
  "title": "Intel Bull/Bear Scenarios",
  "summary": "Evaluating potential outcomes for Intel based on strategic and market conditions.",
  "columns": ["Scenario", "Trigger", "Assumptions", "Consequence"],
  "rows": [
    [
      "Bull Case",
      "Successful 7nm and 5nm rollouts, demand surge in data centers",
      "Growth in AI, cloud computing, and recovery in PC demand",
      "Potential upside to \$50-\$60 range, driven by innovation and performance leadership"
    ],
    [
      "Base Case",
      "Steady improvements in process technology, stable demand",
      "Managed competitive pressure and operational enhancements",
      "Maintains current trajectory, target range \$40-\$45"
    ]
  ]
}''';

      for (final md in <String>[
        '```research_panel\n$jsonBody\n```',
        '```json\n$jsonBody\n```',
        '```\n$jsonBody\n```',
        jsonBody,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: UiTheme.dark().toThemeData(),
            home: Scaffold(
              body: SingleChildScrollView(child: RichMarkdownPreview(data: md)),
            ),
          ),
        );
        expect(find.text('Intel Bull/Bear Scenarios'), findsOneWidget);
        expect(find.text('Bull Case'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'followups and research_steps blocks render as structured UI in RichMarkdownPreview',
    (tester) async {
      const md = '''
Summary text.

```research_steps
[{"title": "Fetched Intel filings", "detail": "10-K & Q3 earnings"}]
```

```followups
["Compare INTC vs AMD margins", "Show INTC capex breakdown"]
```
''';
      await tester.pumpWidget(
        MaterialApp(
          theme: UiTheme.dark().toThemeData(),
          home: const Scaffold(
            body: SingleChildScrollView(child: RichMarkdownPreview(data: md)),
          ),
        ),
      );
      expect(find.text('Research Steps (1)'), findsOneWidget);
      expect(find.text('Related Questions'), findsOneWidget);
      expect(find.text('Compare INTC vs AMD margins'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'AppAiMessageBubble renders json-fenced and bare ResearchPanel payloads as ResearchPanel',
    (tester) async {
      const jsonBody = '''{
  "title": "Intel Bull/Bear Scenarios",
  "summary": "Evaluating potential outcomes for Intel based on strategic and market conditions.",
  "columns": ["Scenario", "Trigger", "Assumptions", "Consequence"],
  "rows": [
    [
      "Bull Case",
      "Successful 7nm and 5nm rollouts, demand surge in data centers",
      "Growth in AI, cloud computing, and recovery in PC demand",
      "Potential upside to \$50-\$60 range, driven by innovation and performance leadership"
    ]
  ]
}''';

      for (final body in <String>[
        '```scenario_tree\n$jsonBody\n```',
        '```json\n$jsonBody\n```',
        jsonBody,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: UiTheme.dark().toThemeData(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: AppAiMessageBubble(
                  message: AppAiMessage(
                    id: 'msg-${body.hashCode}',
                    role: AppAiRole.assistant,
                    body: body,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Intel Bull/Bear Scenarios'), findsOneWidget);
        expect(find.text('Bull Case'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'PerplexityNewsCard inside AppAiChatBlock renders all stories without layout or SelectionArea errors',
    (tester) async {
      const newsMarkdown = '''
Here are the latest updates on Intel Corporation (INTC):

```news
{
  "title": "Intel Corporation – Latest News & Insights",
  "articles": [
    {"headline": "Intel Reports Q3 Earnings", "publisher": "intc.com", "url": "https://intc.com/1"},
    {"headline": "Foundry Momentum Builds", "publisher": "intc.com", "url": "https://intc.com/2"},
    {"headline": "AI PC Shipments Accelerate", "publisher": "intc.com", "url": "https://intc.com/3"},
    {"headline": "Data Center Segment Growth", "publisher": "intc.com", "url": "https://intc.com/4"}
  ]
}
```
''';
      await tester.pumpWidget(
        MaterialApp(
          theme: UiTheme.dark().toThemeData(),
          home: Scaffold(
            body: AppAiChatBlock(
              onSend: (_) {},
              composer: const SizedBox(height: 40),
              messages: const [
                AppAiMessage(
                  id: 'news-1',
                  role: AppAiRole.assistant,
                  body: newsMarkdown,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Intel Corporation – Latest News & Insights'),
        findsOneWidget,
      );
      expect(find.text('4 stories'), findsOneWidget);
      expect(find.text('Intel Reports Q3 Earnings'), findsOneWidget);
      expect(find.text('Data Center Segment Growth'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'large markdown documents render progressively and support Show more / Show less fold',
    (tester) async {
      final largeDoc = List.generate(
        18,
        (i) =>
            '## Section $i\n\nLong institutional analysis paragraph $i covering revenue growth, margins, capex, and valuation multiples across semiconductor peers.\n',
      ).join('\n');

      await tester.pumpWidget(
        MaterialApp(
          theme: UiTheme.dark().toThemeData(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RichMarkdownPreview(data: largeDoc),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Section 0'), findsOneWidget);
      expect(find.text('Section 17'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: UiTheme.dark().toThemeData(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RichMarkdownPreview(
                data: largeDoc,
                maxCollapsedChars: 400,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Show more'), findsOneWidget);
      expect(find.text('Section 17'), findsNothing);
      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();
      expect(find.text('Show less'), findsOneWidget);
      expect(find.text('Section 17'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'PerplexityCompanyCard formats nested price object instead of printing raw Map literal',
    (tester) async {
      const md = '''
```company
{
  "name": "Intel Corporation",
  "ticker": "INTC",
  "exchange": "NASDAQ",
  "sector": "Semiconductors",
  "price": {"value": 55.47, "currency": "USD", "changePercent": "-7.0%"},
  "marketCap": "~\$295B"
}
```
''';
      await tester.pumpWidget(
        MaterialApp(
          theme: UiTheme.dark().toThemeData(),
          home: const Scaffold(
            body: SingleChildScrollView(child: RichMarkdownPreview(data: md)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('\$55.47'), findsOneWidget);
      expect(find.text('Bearish · -7.00%'), findsOneWidget);
      final Rect priceRect = tester.getRect(find.text('\$55.47'));
      final Rect sentimentRect = tester.getRect(find.text('Bearish · -7.00%'));
      expect(sentimentRect.top, greaterThan(priceRect.bottom));
      expect(find.textContaining('{value:'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
