import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/markdown_kit/markdown_kit.dart';
import 'package:tradex/features/community/presentation/widgets/community_highlighted_text.dart';
import 'package:tradex/features/messages/models/messages_models.dart';
import 'package:tradex/features/messages/presentation/widgets/message_bubble.dart';

void main() {
  group('Ticker Syntax & Cashtag Unit Tests', () {
    test('TickerInlineSyntax matches tickers and ignores currency/math', () {
      final syntax = TickerInlineSyntax();
      final text = 'Watching \$AAPL and \$TSLA and \$^NSEI, but not \$100 or \$50.25 or \$\$x\$\$';

      final matches = syntax.pattern.allMatches(text).toList();
      final matchedSymbols = matches.map((m) => m.group(1)).toList();

      expect(matchedSymbols, containsAll(<String>['AAPL', 'TSLA', '^NSEI']));
      expect(matchedSymbols, isNot(contains('100')));
      expect(matchedSymbols, isNot(contains('50')));
    });

    test('CommunityHighlightedText regex matches cashtags and tags, ignoring prices', () {
      const text = 'Bought \$AAPL at \$150 and \$MSFT at \$200 with #breakout and @trader';
      final matches = CommunityHighlightedText.tagRegex.allMatches(text).toList();
      final tags = matches.map((m) => m.group(0)).toList();

      expect(tags, contains('\$AAPL'));
      expect(tags, contains('\$MSFT'));
      expect(tags, contains('#breakout'));
      expect(tags, contains('@trader'));
      expect(tags, isNot(contains('\$150')));
      expect(tags, isNot(contains('\$200')));
    });
  });

  group('Markdown Preview Ticker Linking Widget Tests', () {
    testWidgets('RichMarkdownPreview renders clickable ticker badge and dispatches onOpenRef', (
      WidgetTester tester,
    ) async {
      AppLinkRef? openedRef;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichMarkdownPreview(
              data: 'Check out \$NVDA for earnings.',
              onOpenRef: (ref) => openedRef = ref,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('\$NVDA'), findsOneWidget);
      expect(find.byIcon(Icons.candlestick_chart_outlined), findsOneWidget);

      await tester.tap(find.text('\$NVDA'));
      await tester.pumpAndSettle();

      expect(openedRef, isNotNull);
      expect(openedRef!.kind, AppLinkKind.ticker);
      expect(openedRef!.id, 'NVDA');
    });

    testWidgets('RichMarkdownPreview handles deep link tradex://ticker/BTCUSDT', (
      WidgetTester tester,
    ) async {
      AppLinkRef? openedRef;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichMarkdownPreview(
              selectable: false,
              data: '[Bitcoin](tradex://ticker/BTCUSDT)',
              onOpenRef: (ref) => openedRef = ref,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Bitcoin'), findsOneWidget);
      await tester.tap(find.textContaining('Bitcoin'));
      await tester.pumpAndSettle();

      expect(openedRef, isNotNull);
      expect(openedRef!.kind, AppLinkKind.ticker);
      expect(openedRef!.id, 'BTCUSDT');
    });
  });

  group('Messages Ticker Linking Tests', () {
    testWidgets('MessageBubble renders interactive ticker span and dispatches onOpenRef', (
      WidgetTester tester,
    ) async {
      AppLinkRef? openedRef;
      final message = ChatMessage(
        id: 'msg_test_1',
        threadId: 'th_test_1',
        body: 'Scalping \$RELIANCE now!',
        sentAt: DateTime.now(),
        fromMe: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              onOpenRef: (ref) => openedRef = ref,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('\$RELIANCE'), findsOneWidget);

      // Tap on the ticker span
      await tester.tap(find.textContaining('\$RELIANCE'));
      await tester.pumpAndSettle();

      expect(openedRef, isNotNull);
      expect(openedRef!.kind, AppLinkKind.ticker);
      expect(openedRef!.id, 'RELIANCE');
    });
  });

  group('AI Assistant Ticker Linking Tests', () {
    testWidgets('AppAiMessageBubble renders interactive ticker in user message', (
      WidgetTester tester,
    ) async {
      AppLinkRef? openedRef;
      final message = AppAiMessage(
        id: 'ai_user_msg',
        role: AppAiRole.user,
        body: 'What is your analysis on \$INFY today?',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppAiMessageBubble(
              message: message,
              onOpenRef: (ref) => openedRef = ref,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('\$INFY'), findsOneWidget);

      final Text textWidget = tester.widget<Text>(find.textContaining('\$INFY'));
      final TextSpan span = textWidget.textSpan! as TextSpan;
      bool tapped = false;
      for (final InlineSpan child in span.children!) {
        if (child is TextSpan && child.recognizer is TapGestureRecognizer) {
          (child.recognizer as TapGestureRecognizer).onTap?.call();
          tapped = true;
          break;
        }
      }
      expect(tapped, isTrue);
      await tester.pumpAndSettle();

      expect(openedRef, isNotNull);
      expect(openedRef!.kind, AppLinkKind.ticker);
      expect(openedRef!.id, 'INFY');
    });

    testWidgets('AppAiMessageBubble renders interactive ticker in assistant markdown message', (
      WidgetTester tester,
    ) async {
      AppLinkRef? openedRef;
      final message = AppAiMessage(
        id: 'ai_assistant_msg',
        role: AppAiRole.assistant,
        body: 'Strong breakout detected on \$TATAMOTORS above the 20 EMA.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppAiMessageBubble(
              message: message,
              onOpenRef: (ref) => openedRef = ref,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('\$TATAMOTORS'), findsOneWidget);
      expect(find.byIcon(Icons.candlestick_chart_outlined), findsOneWidget);

      await tester.tap(find.text('\$TATAMOTORS'));
      await tester.pumpAndSettle();

      expect(openedRef, isNotNull);
      expect(openedRef!.kind, AppLinkKind.ticker);
      expect(openedRef!.id, 'TATAMOTORS');
    });
  });
}
