import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/app-ui/motion/ai_typing_indicator.dart';
import 'package:tradex/core/markdown_kit/markdown_kit.dart';

const String _fullPerplexityAnswer = '''
NVIDIA remains the dominant accelerator supplier for hyperscale AI training and inference, backed by Blackwell rack-scale ramps [NVIDIA IR](https://investor.nvidia.com/q4) and sovereign cloud capex [Reuters](https://www.reuters.com/tech/nvda-ai).

```company
{
  "name": "NVIDIA Corporation",
  "ticker": "NVDA",
  "exchange": "NASDAQ",
  "sector": "Semiconductors",
  "industry": "AI Accelerators",
  "price": 138.60,
  "changePercent": 4.25,
  "marketCap": "\$3.39T",
  "pe": "48.2x",
  "eps": "\$2.95",
  "revenue": "\$130.5B",
  "margin": "55.8%",
  "high52w": 153.13,
  "low52w": 75.60,
  "analystConsensus": {"rating": "Strong Buy", "target": "\$172.00", "buy": 48, "hold": 6, "sell": 1},
  "sparkline": [112, 118, 121, 129, 134, 138.6],
  "summary": "Full-stack GPU, CUDA software, and NVLink networking leader powering global generative AI infrastructure.",
  "highlights": ["Blackwell ultra ramp accelerating", "CUDA software moat deepens retention"],
  "risks": ["Hyperscaler custom ASIC competition", "Export licensing restrictions"]
}
```

```person
{
  "name": "Jensen Huang",
  "role": "Co-Founder & CEO",
  "organization": "NVIDIA",
  "location": "Santa Clara, CA",
  "netWorth": "\$119B",
  "bio": "Co-founded NVIDIA in 1993 and architected its pivot from 3D graphics into accelerated computing and AI factories.",
  "metrics": [{"label": "Tenure", "value": "32 yrs"}, {"label": "Ownership", "value": "3.5%"}],
  "highlights": ["Pioneered CUDA ecosystem in 2006", "Steered multi-trillion AI data-center cycle"],
  "tickers": ["\$NVDA", "\$TSM"],
  "timeline": [
    {"date": "1993", "title": "Co-founded NVIDIA", "description": "Launched GPU compute roadmap."},
    {"date": "2024", "title": "Blackwell Unveiled", "description": "Scaled rack-level AI factories."}
  ],
  "links": [{"title": "NVIDIA Leadership", "url": "https://www.nvidia.com/en-us/about-nvidia/executive-team/"}]
}
```

```news
{
  "title": "Latest Market Headlines",
  "items": [
    {
      "headline": "Hyperscalers raise 2026 AI data center capex guidance",
      "publisher": "Financial Times",
      "publishedAt": "2h ago",
      "sentiment": "bullish",
      "summary": "Cloud providers cited tight GPU cluster utilization across inference workloads.",
      "tickers": ["\$NVDA", "\$AVGO"],
      "url": "https://www.ft.com/content/ai-capex-guidance"
    }
  ]
}
```

```compare
{
  "mode": "swot",
  "title": "SWOT Strategic Breakdown",
  "strengths": ["CUDA ecosystem lock-in", "Annual cadence execution"],
  "weaknesses": ["Customer concentration"],
  "opportunities": ["Enterprise NIM inference"],
  "threats": ["Custom hyperscaler silicon"]
}
```

```compare
{
  "mode": "versus",
  "title": "AI Accelerator Peer Matrix",
  "columns": ["NVIDIA", "AMD", "Broadcom"],
  "rows": [
    {"criterion": "Gross Margin", "values": ["75%", "52%", "66%"], "winnerIndex": 0},
    {"criterion": "Forward P/E", "values": ["33x", "28x", "31x"], "winnerIndex": 1}
  ]
}
```

```timeline
{
  "title": "Key Catalysts Roadmap",
  "items": [
    {"date": "Q1", "title": "Blackwell Volume Ramp", "description": "GB200 NVL72 shipments scale", "status": "done", "impact": "bullish"},
    {"date": "Q3", "title": "Rubin Architecture Preview", "description": "Next-gen HBM4 interconnect update", "status": "upcoming", "impact": "neutral"}
  ]
}
```

```setup
{
  "ticker": "\$NVDA",
  "bias": "long",
  "timeframe": "Swing (4H / Daily)",
  "entry": "\$135.50 - \$138.00",
  "stop": "\$128.40",
  "targets": ["\$152.00", "\$165.00"],
  "riskReward": "1 : 2.8",
  "confidence": 82,
  "invalidation": "Daily close below the 21 EMA and high-volume gap shelf.",
  "confluences": ["RS New High", "Institutional Accumulation"]
}
```

```verdict
{
  "title": "Executive Verdict",
  "badge": "Constructive",
  "summary": "Risk-reward favors staggered accumulation near pullback support ahead of rack deliveries.",
  "confidence": 85,
  "bullets": ["Track hyperscaler capex commentary", "Monitor gross margin guidance"]
}
```

```factbox
{
  "title": "CUDA Moat Explained",
  "description": "Software abstraction layer locking millions of developers into GPU libraries.",
  "facts": [
    {"label": "Launched", "value": "2006"},
    {"label": "Ecosystem", "value": "5M+ Developers"}
  ]
}
```

```faq
{
  "title": "Key Questions",
  "items": [
    {"q": "What could slow data center growth?", "a": "Pause in cloud capex digestion or supply chain bottlenecks."}
  ]
}
```

```checklist
{
  "title": "Pre-Trade Diligence Checklist",
  "items": [
    {"title": "Confirm earnings date volatility", "done": true},
    {"title": "Verify position sizing <= 1% risk", "done": false}
  ]
}
```

```quote
{
  "quote": "Accelerated computing is a new computing platform.",
  "author": "Jensen Huang",
  "source": "Earnings Call"
}
```

```followups
[
  "Compare NVIDIA vs AMD margins over the past 8 quarters",
  "What are the biggest hyperscaler capex risks for \$NVDA?",
  "Show options implied move before next earnings"
]
```
''';

const String _tinyPngDataUrl =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

const String _extendedPerplexityAnswer = '''
Apple delivered resilient Services expansion [Apple IR](https://investor.apple.com/earnings) alongside expanding AI silicon deployment [Bloomberg](https://www.bloomberg.com/markets/aapl).

![Apple Silicon Data Center Architecture]($_tinyPngDataUrl)

```research_steps
{
  "steps": [
    {"title": "Searched SEC EDGAR filings", "detail": "Reviewed FY25 Q4 Form 10-Q segment revenue", "source": "sec.gov"},
    {"title": "Analyzed consensus revisions", "detail": "Aggregated 38 sell-side EPS targets", "source": "bloomberg.com"}
  ]
}
```

```earnings
{
  "ticker": "\$AAPL",
  "company": "Apple Inc.",
  "quarter": "Q4 FY25",
  "status": "Beat",
  "epsActual": "\$1.64",
  "epsEstimate": "\$1.60",
  "epsSurprise": "+2.5%",
  "revenueActual": "\$94.9B",
  "revenueEstimate": "\$94.2B",
  "revenueSurprise": "+0.7%",
  "reaction": "+2.1% AH",
  "guidance": "Services growth guided low-double-digits YoY",
  "highlights": ["Services gross margin reached 74%"],
  "concerns": ["Greater China macro competition"],
  "history": [
    {"quarter": "Q4 FY25", "epsActual": "\$1.64", "epsEstimate": "\$1.60", "surprise": "+2.5%"},
    {"quarter": "Q3 FY25", "epsActual": "\$1.40", "epsEstimate": "\$1.35", "surprise": "+3.7%"}
  ]
}
```

```financials
{
  "ticker": "\$AAPL",
  "title": "Financial Statements Snapshot",
  "subtitle": "TTM Income Statement & Cash Generation",
  "metrics": [
    {"label": "Gross Margin", "value": "46.2%", "yoy": "+120 bps"},
    {"label": "Free Cash Flow", "value": "\$108.8B", "yoy": "+9.4%"}
  ],
  "lineItems": [
    {"label": "Operating Cash Flow", "value": "\$118.2B", "yoy": "+7.1%", "share": 1.0},
    {"label": "Net Debt", "value": "\$51.4B", "yoy": "-6.2%", "share": 0.45}
  ],
  "tableRows": [
    {"label": "P/E Forward", "current": "31.2x", "prior": "28.4x", "change": "+9.8%"}
  ],
  "multiples": [
    {"label": "EV/EBITDA", "value": "24.6x"},
    {"label": "ROIC", "value": "54.2%"}
  ]
}
```

```macro
{
  "title": "Macro & FOMC Liquidity Pulse",
  "regime": "Soft Landing",
  "indicators": [
    {"name": "US Core CPI YoY", "actual": "3.1%", "forecast": "3.1%", "prior": "3.2%"},
    {"name": "10Y Treasury Yield", "actual": "4.18%", "forecast": "4.20%", "prior": "4.25%"}
  ],
  "impacts": [
    {"asset": "Duration Growth Equities", "impact": "bullish"},
    {"asset": "US Dollar Index", "impact": "neutral"}
  ],
  "summary": "Disinflation trajectory keeps Fed rate-cut optionality intact."
}
```

```ratings
{
  "ticker": "\$AAPL",
  "title": "Wall Street Consensus & Targets",
  "consensus": "Buy",
  "targetLow": 185.0,
  "targetMedian": 248.0,
  "targetHigh": 275.0,
  "currentPrice": 229.5,
  "buyCount": 31,
  "holdCount": 11,
  "sellCount": 2,
  "actions": [
    {"firm": "Morgan Stanley", "action": "Overweight", "target": "\$273.00"}
  ]
}
```

```screener
{
  "title": "Mega-Cap Quality & Momentum Screener",
  "criteria": "ROIC > 25% · Rev Growth > 6% · Positive FCF",
  "rows": [
    {"ticker": "\$NVDA", "name": "NVIDIA Corp", "price": "\$138.60", "change": "+4.2%", "score": 96, "signal": "bullish"},
    {"ticker": "\$AAPL", "name": "Apple Inc", "price": "\$229.50", "change": "+1.4%", "score": 88, "signal": "bullish"}
  ]
}
```

```sentiment
{
  "ticker": "\$AAPL",
  "title": "Options Flow & Desk Sentiment",
  "regime": "Bullish",
  "score": 71,
  "bullishPct": 62,
  "neutralPct": 24,
  "bearishPct": 14,
  "putCall": "0.68",
  "shortInterest": "0.75%",
  "drivers": ["Call sweeps concentrated at \$240 monthly strike"]
}
```

```media
{
  "title": "Research Charts & Exhibits",
  "items": [
    {"url": "$_tinyPngDataUrl", "caption": "Gross Margin Expansion Trend", "sourceUrl": "https://investor.apple.com/earnings"}
  ]
}
```

```formula
{
  "title": "Fractional Kelly Position Sizing Formula",
  "expression": "f* = (p * b - q) / b",
  "variables": [
    {"symbol": "p", "meaning": "Historical setup win probability", "unit": "ratio"},
    {"symbol": "b", "meaning": "Average reward-to-risk payoff", "unit": "R"}
  ],
  "example": "With p = 0.55 and b = 2.0, full Kelly f* = 32.5% (half-Kelly 16.25%).",
  "takeaway": "Cap equity risk per trade to stay well inside half-Kelly."
}
```

```product
{
  "name": "AlphaJournal Institutional Terminal",
  "category": "Research Platform",
  "price": "\$49/mo Pro",
  "rating": 4.9,
  "summary": "Unified trading journal, AI Copilot with cited filings, and live market analytics.",
  "pros": ["Cited Perplexity research cards", "Automated drawdown telemetry"],
  "cons": ["Real-time Level 2 requires broker feed"],
  "alternatives": ["Bloomberg Terminal", "Koyfin"],
  "url": "https://alphajournal.in"
}
```
''';

Widget _wrapTestWidget(Widget child, {double textScale = 1.0}) {
  return MaterialApp(
    home: Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

void main() {
  group('PerplexityAnswerParser', () {
    test('extracts deduplicated sources, followups, cards, and tickers', () {
      final meta = PerplexityAnswerParser.parse(
        _fullPerplexityAnswer,
        structuredSources: const [
          (
            url: 'https://investor.nvidia.com/q4',
            title: 'NVIDIA Official Q4',
            domain: 'investor.nvidia.com',
            snippet: 'Official filing.',
          ),
        ],
      );

      expect(meta.hasStructuredBlocks, isTrue);
      expect(meta.sources.length, greaterThanOrEqualTo(4));
      expect(meta.sources.first.index, 1);
      expect(meta.sources.first.url, 'https://investor.nvidia.com/q4');
      expect(
        meta.sources.map((s) => s.domain),
        containsAll(<String>['investor.nvidia.com', 'reuters.com', 'ft.com']),
      );
      expect(meta.followUps.length, 3);
      expect(meta.followUps.first, startsWith('Compare NVIDIA vs AMD'));
      expect(meta.cleanMarkdown, isNot(contains('```followups')));
      expect(meta.tickers, containsAll(<String>['NVDA', 'AVGO', 'TSM']));
      expect(meta.cards.map((c) => c.tag), containsAll(<String>['company', 'person', 'news', 'compare']));
    });

    test('converts unclosed streaming card fences into loading_card placeholders', () {
      const streamingMarkdown = '''
Analyzing fundamentals now.

```company
{"name": "Apple Inc", "ticker": "AAPL"
''';
      final meta = PerplexityAnswerParser.parse(
        streamingMarkdown,
        isStreaming: true,
      );

      expect(meta.cleanMarkdown, contains('```loading_card'));
      expect(meta.cleanMarkdown, contains('Company Dossier'));
    });

    test('extracts trailing Markdown Related section when no fenced followups exist', () {
      const markdownWithRelated = '''
Here is the summary [SEC](https://www.sec.gov/edgar).

## Related
- How does free cash flow compare to peers?
- What is management guidance for next year?
''';
      final meta = PerplexityAnswerParser.parse(markdownWithRelated);
      expect(meta.followUps, <String>[
        'How does free cash flow compare to peers?',
        'What is management guidance for next year?',
      ]);
      expect(meta.cleanMarkdown, isNot(contains('## Related')));
    });

    test('extracts research steps, media items, and extended finance card tags', () {
      final meta = PerplexityAnswerParser.parse(
        _extendedPerplexityAnswer,
        externalSteps: const <String>['Fetched SEC 10-Q filings'],
        focus: 'finance',
      );

      expect(meta.steps.length, greaterThanOrEqualTo(3));
      expect(
        meta.steps.map((s) => s.title),
        containsAll(<String>[
          'Fetched SEC 10-Q filings',
          'Searched SEC EDGAR filings',
        ]),
      );
      expect(meta.media.length, greaterThanOrEqualTo(1));
      expect(
        meta.cards.map((c) => c.tag),
        containsAll(<String>[
          'earnings',
          'financials',
          'macro',
          'ratings',
          'screener',
          'sentiment',
          'media',
          'formula',
          'product',
        ]),
      );
      expect(meta.isRichAnswer, isTrue);
    });
  });

  group('Perplexity UI Cards & Interactive Flows', () {
    testWidgets(
      'renders all domain cards, switches Answer/Sources tabs, toggles checklist, and fires callbacks',
      (WidgetTester tester) async {
        AppLinkRef? openedRef;
        String? tappedUrl;
        String? followedUp;

        await tester.binding.setSurfaceSize(const Size(960, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _wrapTestWidget(
            AppAiMessageBubble(
              message: const AppAiMessage(
                id: 'p1',
                role: AppAiRole.assistant,
                body: _fullPerplexityAnswer,
                mode: 'Research',
              ),
              minimal: true,
              onOpenRef: (ref) => openedRef = ref,
              onSourceTap: (url) => tappedUrl = url,
              onFollowUpTap: (q) => followedUp = q,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Answer header tabs & source rail
        expect(find.text('Answer'), findsOneWidget);
        expect(find.text('Sources'), findsAtLeastNWidgets(1));
        expect(find.text('Research'), findsOneWidget);

        // Domain cards rendered cleanly
        expect(find.text('NVIDIA Corporation'), findsOneWidget);
        expect(find.text('Jensen Huang'), findsOneWidget);
        expect(find.text('Latest Market Headlines'), findsOneWidget);
        expect(find.text('SWOT Strategic Breakdown'), findsOneWidget);
        expect(find.text('AI Accelerator Peer Matrix'), findsOneWidget);
        expect(find.text('Key Catalysts Roadmap'), findsOneWidget);
        expect(find.text('Executive Verdict'), findsOneWidget);
        expect(find.text('CUDA Moat Explained'), findsOneWidget);
        expect(find.text('Pre-Trade Diligence Checklist'), findsOneWidget);
        expect(find.byType(PerplexityTradeSetupCard), findsOneWidget);

        // Interactive checklist toggles checked item count
        expect(find.text('1/2'), findsOneWidget);
        final checklistItem = find.text('Verify position sizing <= 1% risk');
        await tester.ensureVisible(checklistItem);
        await tester.tap(checklistItem);
        await tester.pump();
        expect(find.text('2/2'), findsOneWidget);

        // Related follow-up question click dispatches prompt
        expect(find.text('Related'), findsOneWidget);
        final relatedQ = find.text('Compare NVIDIA vs AMD margins over the past 8 quarters');
        await tester.ensureVisible(relatedQ);
        await tester.tap(relatedQ);
        await tester.pump();
        expect(followedUp, 'Compare NVIDIA vs AMD margins over the past 8 quarters');

        // Company action button dispatches onOpenRef
        final openMarketBtn = find.text('Open \$NVDA in Market');
        await tester.ensureVisible(openMarketBtn);
        await tester.tap(openMarketBtn);
        await tester.pump();
        expect(openedRef?.id, 'NVDA');

        // Switch to Sources tab and tap a source card
        final sourcesTab = find.text('Sources').first;
        await tester.ensureVisible(sourcesTab);
        await tester.tap(sourcesTab);
        await tester.pumpAndSettle();
        final investorTile = find.text('investor.nvidia.com').first;
        await tester.tap(investorTile);
        await tester.pump();
        expect(tappedUrl, isNotNull);
        expect(tappedUrl, contains('http'));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'displays streaming loading skeleton card for incomplete structured block',
      (WidgetTester tester) async {
        const partial = '''
Searching filings…

```company
{"name":"Microsoft","ticker":"MSFT"
''';
        await tester.pumpWidget(
          _wrapTestWidget(
            const AppAiMessageBubble(
              message: AppAiMessage(
                id: 'stream1',
                role: AppAiRole.assistant,
                body: partial,
                pending: true,
              ),
              minimal: true,
            ),
          ),
        );
        // Pump long enough so typewriter reveals the loading_card fence.
        await tester.pump(const Duration(seconds: 2));
        expect(find.byType(AiTypingCursor), findsOneWidget);
        expect(find.byType(UiSkeleton), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    for (final ({String label, Size size, double scale}) vp in const [
      (label: '320px narrow @1.5x text', size: Size(320, 844), scale: 1.5),
      (label: '390px mobile @1.0x text', size: Size(390, 844), scale: 1.0),
      (label: '768px tablet @1.0x text', size: Size(768, 1024), scale: 1.0),
      (label: '1280px desktop @1.0x text', size: Size(1280, 900), scale: 1.0),
    ]) {
      testWidgets('renders all cards without overflow on ${vp.label}', (
        WidgetTester tester,
      ) async {
        await tester.binding.setSurfaceSize(vp.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final prevOnError = FlutterError.onError;
        final List<String> layoutErrors = <String>[];
        FlutterError.onError = (FlutterErrorDetails details) {
          layoutErrors.add('${details.exceptionAsString()}\n${details.informationCollector?.call().map((d) => d.toString()).join('\n') ?? ''}');
        };
        try {
          await tester.pumpWidget(
            _wrapTestWidget(
              AppAiMessageBubble(
                message: const AppAiMessage(
                  id: 'overflow-check',
                  role: AppAiRole.assistant,
                  body: _fullPerplexityAnswer,
                  mode: 'Research',
                ),
                minimal: true,
                onOpenRef: (_) {},
                onSourceTap: (_) {},
                onFollowUpTap: (_) {},
              ),
              textScale: vp.scale,
            ),
          );
          await tester.pumpAndSettle();
        } finally {
          FlutterError.onError = prevOnError;
        }
        expect(layoutErrors, isEmpty, reason: layoutErrors.join('\n---\n'));
      });
    }

    testWidgets(
      'renders all 9 extended cards, 4 tabs, Pro Search steps, Copy citations, Rewrite menu, and Media lightbox',
      (WidgetTester tester) async {
        String? followedUp;

        await tester.binding.setSurfaceSize(const Size(1024, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _wrapTestWidget(
            AppAiMessageBubble(
              message: const AppAiMessage(
                id: 'ext1',
                role: AppAiRole.assistant,
                body: _extendedPerplexityAnswer,
                mode: 'research',
                focus: 'finance',
                steps: <String>['Queried live earnings consensus'],
              ),
              minimal: true,
              onOpenRef: (_) {},
              onSourceTap: (_) {},
              onFollowUpTap: (q) => followedUp = q,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pro Search steps accordion + 4 Perplexity navigation tabs
        expect(find.text('Answer details'), findsOneWidget);
        expect(find.text('Answer'), findsOneWidget);
        expect(find.text('Sources'), findsAtLeastNWidgets(1));
        expect(find.text('Cards'), findsOneWidget);
        expect(find.text('Media'), findsOneWidget);

        // All 9 extended Perplexity & Finance card widgets
        expect(find.byType(PerplexityEarningsCard), findsOneWidget);
        expect(find.byType(PerplexityFinancialsCard), findsOneWidget);
        expect(find.byType(PerplexityMacroCard), findsOneWidget);
        expect(find.byType(PerplexityRatingsCard), findsOneWidget);
        expect(find.byType(PerplexityScreenerCard), findsOneWidget);
        expect(find.byType(PerplexitySentimentCard), findsOneWidget);
        expect(find.byType(PerplexityMediaCard), findsOneWidget);
        expect(find.byType(PerplexityFormulaCard), findsOneWidget);
        expect(find.byType(PerplexityProductPlaceCard), findsOneWidget);

        // Switch through Cards, Media, and Sources tabs
        await tester.ensureVisible(find.text('Cards'));
        await tester.tap(find.text('Cards'));
        await tester.pumpAndSettle();
        expect(find.byType(PerplexityEarningsCard), findsOneWidget);
        expect(find.byType(PerplexityRatingsCard), findsOneWidget);

        await tester.ensureVisible(find.text('Media'));
        await tester.tap(find.text('Media'));
        await tester.pumpAndSettle();
        expect(find.text('Gross Margin Expansion Trend'), findsOneWidget);

        await tester.ensureVisible(find.text('Sources').first);
        await tester.tap(find.text('Sources').first);
        await tester.pumpAndSettle();
        expect(find.text('Copy citations'), findsOneWidget);

        // Switch back to Answer and test Rewrite dropdown + feedback toggles
        await tester.ensureVisible(find.text('Answer'));
        await tester.tap(find.text('Answer'));
        await tester.pumpAndSettle();

        final rewriteTrigger = find.byWidgetPredicate(
          (w) => w is UiDropdownMenu && w.semanticLabel == 'Rewrite answer style',
        );
        await tester.ensureVisible(rewriteTrigger);
        await tester.tap(rewriteTrigger);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Simple explanation (ELI5)'));
        await tester.pumpAndSettle();
        expect(followedUp, contains('Explain your previous answer simply'));

        await tester.tap(find.byTooltip('Helpful answer'));
        await tester.pump();
        await tester.tap(find.byTooltip('Needs improvement'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    for (final ({String label, Size size, double scale}) vp in const [
      (label: '320px narrow @1.5x text', size: Size(320, 844), scale: 1.5),
      (label: '390px mobile @1.0x text', size: Size(390, 844), scale: 1.0),
      (label: '768px tablet @1.0x text', size: Size(768, 1024), scale: 1.0),
      (label: '1280px desktop @1.0x text', size: Size(1280, 900), scale: 1.0),
    ]) {
      testWidgets('renders all extended Perplexity cards without overflow on ${vp.label}', (
        WidgetTester tester,
      ) async {
        await tester.binding.setSurfaceSize(vp.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final prevOnError = FlutterError.onError;
        final List<String> layoutErrors = <String>[];
        FlutterError.onError = (FlutterErrorDetails details) {
          layoutErrors.add('${details.exceptionAsString()}\n${details.informationCollector?.call().map((d) => d.toString()).join('\n') ?? ''}');
        };
        try {
          await tester.pumpWidget(
            _wrapTestWidget(
              AppAiMessageBubble(
                message: const AppAiMessage(
                  id: 'ext-overflow',
                  role: AppAiRole.assistant,
                  body: _extendedPerplexityAnswer,
                  mode: 'research',
                  focus: 'finance',
                  steps: <String>['Queried SEC EDGAR'],
                ),
                minimal: true,
                onOpenRef: (_) {},
                onSourceTap: (_) {},
                onFollowUpTap: (_) {},
              ),
              textScale: vp.scale,
            ),
          );
          await tester.pumpAndSettle();
        } finally {
          FlutterError.onError = prevOnError;
        }
        expect(layoutErrors, isEmpty, reason: layoutErrors.join('\n---\n'));
      });
    }
  });

  group('Real Site Logos, 11 More Perplexity Cards, Inline Media & User Attachments', () {
    const String morePerplexityAnswer = '''
Full Perplexity-grade research bundle for NVIDIA [NVIDIA Investor Relations](https://investor.nvidia.com/overview) and [SEC EDGAR](https://www.sec.gov/edgar).

![NVDA Chart]($_tinyPngDataUrl)

```links
{
  "title": "Primary Research Links",
  "results": [
    {"title": "NVIDIA Q4 FY25 CFO Commentary", "url": "https://investor.nvidia.com/q4-cfo", "snippet": "Blackwell architecture ramped faster than internal guidance.", "publishedAt": "Feb 26, 2026"},
    {"title": "SEC Form 10-K Annual Report", "url": "https://www.sec.gov/ix?doc=/nvda-10k.htm", "snippet": "Complete risk factors and data center segment breakdown."}
  ]
}
```

```video
{
  "title": "GTC Keynote: Blackwell Ultra & Rubin Roadmap",
  "channel": "NVIDIA Official",
  "duration": "1:12:40",
  "views": "2.4M views",
  "publishedAt": "Mar 18, 2026",
  "url": "https://www.youtube.com/watch?v=nvda-gtc",
  "thumbnail": "$_tinyPngDataUrl",
  "chapters": [
    {"time": "00:14:20", "label": "Blackwell Ultra NVL72"},
    {"time": "00:42:10", "label": "Dynamo Inference OS"}
  ]
}
```

```market_pulse
{
  "title": "Global Market Snapshot",
  "asOf": "Live Session",
  "url": "https://www.reuters.com/markets",
  "items": [
    {"label": "S&P 500", "value": "5,982.40", "change": "+0.84%", "positive": true},
    {"label": "NASDAQ 100", "value": "21,140.15", "change": "+1.32%", "positive": true},
    {"label": "VIX", "value": "14.20", "change": "-4.1%", "positive": true}
  ]
}
```

```earnings_calendar
{
  "title": "Upcoming AI & Semi Catalysts",
  "events": [
    {"ticker": "NVDA", "name": "NVIDIA Q1 Release", "date": "May 28", "time": "AMC", "estimate": "EPS \$0.89", "status": "Confirmed", "url": "https://investor.nvidia.com"},
    {"ticker": "AVGO", "name": "Broadcom Earnings", "date": "Jun 05", "time": "AMC", "estimate": "EPS \$1.54", "status": "Scheduled", "url": "https://www.broadcom.com"}
  ]
}
```

```scenarios
{
  "title": "12-Month Return Distribution",
  "scenarios": [
    {"label": "Bull Case", "probability": 35, "target": "\$185", "upside": "+33%", "sentiment": "bullish", "drivers": "Sovereign AI clusters + GB300 ramp"},
    {"label": "Base Case", "probability": 50, "target": "\$160", "upside": "+15%", "sentiment": "neutral", "drivers": "Steady hyperscaler capex"},
    {"label": "Bear Case", "probability": 15, "target": "\$110", "upside": "-21%", "sentiment": "bearish", "drivers": "Digestive pause or export tightening"}
  ]
}
```

```backtest
{
  "title": "Momentum Pullback Backtest",
  "strategy": "20-EMA Institutional Pullback",
  "period": "2021 - 2026",
  "totalReturn": "+184.2%",
  "cagr": "+23.4%",
  "sharpe": "1.92",
  "maxDrawdown": "-11.8%",
  "winRate": "64%",
  "equityCurve": [
    {"label": "2021", "value": 100},
    {"label": "2022", "value": 118},
    {"label": "2023", "value": 164},
    {"label": "2024", "value": 229},
    {"label": "2025", "value": 284}
  ]
}
```

```portfolio
{
  "title": "Core AI & Hedge Sleeve",
  "totalValue": "\$250,000",
  "rebalanceNote": "Quarterly threshold band +/-3%",
  "holdings": [
    {"label": "Semiconductors", "ticker": "NVDA", "weight": 35, "value": "\$87,500", "change": "+4.2%"},
    {"label": "Cloud Platform", "ticker": "MSFT", "weight": 25, "value": "\$62,500", "change": "+1.1%"},
    {"label": "T-Bills Hedge", "ticker": "SGOV", "weight": 40, "value": "\$100,000", "change": "+0.02%"}
  ]
}
```

```filing
{
  "title": "Form 10-K Annual Filing Highlights",
  "issuer": "NVIDIA Corporation",
  "ticker": "NVDA",
  "form": "10-K",
  "filedDate": "Feb 26, 2026",
  "period": "FY2026",
  "url": "https://www.sec.gov/edgar/nvda-10k",
  "highlights": [
    "Data Center represented 88% of consolidated revenue.",
    "Operating cash flow reached \$64.1B for the fiscal year."
  ]
}
```

```wiki
{
  "title": "Gross Margin Durability",
  "category": "Financial Metric",
  "url": "https://www.investopedia.com/terms/g/grossmargin.asp",
  "summary": "Measures pricing power and manufacturing efficiency after direct cost of goods sold.",
  "relatedTopics": ["Operating leverage", "COGS absorption"]
}
```

```risk_plan
{
  "title": "Breakout Execution Plan",
  "ticker": "NVDA",
  "bias": "Bullish Pullback",
  "accountSize": "\$100,000",
  "riskPercent": "1.0% (\$1,000)",
  "entry": "\$135.50 - \$137.00",
  "stopLoss": "\$130.00",
  "targets": ["\$148.00 (1.8R)", "\$158.00 (3.4R)"],
  "positionSize": "165 shares",
  "rrRatio": "2.6R",
  "invalidation": "Daily close below \$129.80 on rising volume."
}
```

```workflow
{
  "title": "Pre-Earnings Due Diligence",
  "steps": [
    {"title": "Pull primary 10-Q footnotes", "detail": "Verify inventory days and purchase commitments."},
    {"title": "Compare implied volatility", "detail": "Check front-month straddle pricing vs realized earnings moves."},
    {"title": "Size position to max risk", "detail": "Cap gap risk inside 1% account equity limit."}
  ]
}
```
''';

    test('SiteLogoResolver extracts clean domains and maps tickers to official domains', () {
      expect(
        SiteLogoResolver.extractDomain('https://www.reuters.com/markets/nvda'),
        'reuters.com',
      );
      expect(SiteLogoResolver.domainForTicker(r'$NVDA'), 'nvidia.com');
      expect(SiteLogoResolver.domainForTicker('RELIANCE'), 'ril.com');
      expect(SiteLogoResolver.domainForTicker('BTC'), 'bitcoin.org');
      expect(
        SiteLogoResolver.resolveLogoUrl(url: 'https://investor.nvidia.com/q4'),
        'https://www.google.com/s2/favicons?domain=investor.nvidia.com&sz=64',
      );
      expect(
        SiteLogoResolver.resolveLogoUrl(ticker: 'AAPL', size: 128),
        'https://www.google.com/s2/favicons?domain=apple.com&sz=128',
      );
    });

    testWidgets(
      'renders all 11 additional Perplexity cards, site logos, inline media, and interactive workflow/risk callbacks',
      (WidgetTester tester) async {
        String? tappedUrl;
        String? prompted;

        await tester.binding.setSurfaceSize(const Size(1024, 3200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _wrapTestWidget(
            AppAiMessageBubble(
              message: const AppAiMessage(
                id: 'more-1',
                role: AppAiRole.assistant,
                body: morePerplexityAnswer,
                mode: 'research',
                focus: 'finance',
              ),
              minimal: true,
              onOpenRef: (_) {},
              onSourceTap: (url) => tappedUrl = url,
              onFollowUpTap: (q) => prompted = q,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AppSiteLogo), findsAtLeastNWidgets(4));
        expect(find.byType(AppSiteLinkChip), findsAtLeastNWidgets(2));
        expect(find.byType(PerplexityLinksCard), findsOneWidget);
        expect(find.byType(PerplexityVideoCard), findsOneWidget);
        expect(find.byType(PerplexityPulseCard), findsOneWidget);
        expect(find.byType(PerplexityScheduleCard), findsOneWidget);
        expect(find.byType(PerplexityScenarioMatrixCard), findsOneWidget);
        expect(find.byType(PerplexityBacktestCard), findsOneWidget);
        expect(find.byType(PerplexityPortfolioCard), findsOneWidget);
        expect(find.byType(PerplexityDocumentCard), findsOneWidget);
        expect(find.byType(PerplexityWikiCard), findsOneWidget);
        expect(find.byType(PerplexityRiskPlanCard), findsOneWidget);
        expect(find.byType(PerplexityWorkflowCard), findsOneWidget);

        // Tap video card and site link chip
        final videoTitle = find.descendant(
          of: find.byType(PerplexityVideoCard),
          matching: find.text('GTC Keynote: Blackwell Ultra & Rubin Roadmap'),
        ).last;
        await tester.ensureVisible(videoTitle);
        await tester.tap(videoTitle);
        await tester.pump();
        expect(tappedUrl, 'https://www.youtube.com/watch?v=nvda-gtc');

        await tester.ensureVisible(find.byType(AppSiteLinkChip).first);
        await tester.tap(find.byType(AppSiteLinkChip).first);
        await tester.pump();

        // Advance interactive UiStepper step in PerplexityWorkflowCard
        expect(find.text('Step 1/3'), findsOneWidget);
        final step2 = find
            .descendant(
              of: find.byType(PerplexityWorkflowCard),
              matching: find.text('2'),
            )
            .first;
        await tester.ensureVisible(step2);
        await tester.tap(step2);
        await tester.pump();
        expect(find.text('Step 2/3'), findsOneWidget);
        expect(
          find.text(
            'Check front-month straddle pricing vs realized earnings moves.',
          ),
          findsOneWidget,
        );

        // Tap related topic chip on Wiki card
        await tester.ensureVisible(find.text('Operating leverage'));
        await tester.tap(find.text('Operating leverage'));
        await tester.pump();
        expect(prompted, contains('Operating leverage'));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'renders user image, web link, and typed file attachments inside AppAiMessageBubble and opens lightbox',
      (WidgetTester tester) async {
        String? tappedLink;
        await tester.binding.setSurfaceSize(const Size(640, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _wrapTestWidget(
            AppAiMessageBubble(
              message: const AppAiMessage(
                id: 'u-att-1',
                role: AppAiRole.user,
                body: 'Analyze my chart screenshot, filing link, and script.',
                attachmentItems: <AppAiAttachment>[
                  AppAiAttachment(
                    name: 'nvda_breakout.png',
                    kind: AppAiAttachmentKind.image,
                    previewUrl: _tinyPngDataUrl,
                    mimeType: 'image/png',
                  ),
                  AppAiAttachment(
                    name: 'NVIDIA Q4 Release',
                    kind: AppAiAttachmentKind.link,
                    previewUrl: 'https://investor.nvidia.com/q4',
                    subtitle: 'investor.nvidia.com',
                  ),
                  AppAiAttachment(
                    name: 'strategy.py',
                    kind: AppAiAttachmentKind.code,
                    subtitle: 'PY',
                  ),
                  AppAiAttachment(
                    name: '10k.pdf',
                    kind: AppAiAttachmentKind.pdf,
                    subtitle: 'PDF',
                  ),
                ],
              ),
              onSourceTap: (url) => tappedLink = url,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('nvda_breakout.png'), findsOneWidget);
        expect(find.text('NVIDIA Q4 Release'), findsOneWidget);
        expect(find.text('strategy.py'), findsOneWidget);
        expect(find.text('10k.pdf'), findsOneWidget);

        // Tap link chip
        await tester.tap(find.text('NVIDIA Q4 Release'));
        await tester.pump();
        expect(tappedLink, 'https://investor.nvidia.com/q4');

        // Tap image attachment to open UiLightbox
        await tester.tap(find.text('nvda_breakout.png'));
        await tester.pumpAndSettle();
        expect(find.byType(UiLightbox), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    for (final ({String label, Size size, double scale}) vp in const [
      (label: '320px narrow @1.5x text', size: Size(320, 844), scale: 1.5),
      (label: '390px mobile @1.0x text', size: Size(390, 844), scale: 1.0),
      (label: '768px tablet @1.0x text', size: Size(768, 1024), scale: 1.0),
      (label: '1280px desktop @1.0x text', size: Size(1280, 900), scale: 1.0),
    ]) {
      testWidgets('renders all 11 more Perplexity cards without overflow on ${vp.label}', (
        WidgetTester tester,
      ) async {
        await tester.binding.setSurfaceSize(vp.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final prevOnError = FlutterError.onError;
        final List<String> layoutErrors = <String>[];
        FlutterError.onError = (FlutterErrorDetails details) {
          layoutErrors.add('${details.exceptionAsString()}\n${details.informationCollector?.call().map((d) => d.toString()).join('\n') ?? ''}');
        };
        try {
          await tester.pumpWidget(
            _wrapTestWidget(
              AppAiMessageBubble(
                message: const AppAiMessage(
                  id: 'more-overflow',
                  role: AppAiRole.assistant,
                  body: morePerplexityAnswer,
                  mode: 'research',
                  focus: 'finance',
                ),
                minimal: true,
                onOpenRef: (_) {},
                onSourceTap: (_) {},
                onFollowUpTap: (_) {},
              ),
              textScale: vp.scale,
            ),
          );
          await tester.pumpAndSettle();
        } finally {
          FlutterError.onError = prevOnError;
        }
        expect(layoutErrors, isEmpty, reason: layoutErrors.join('\n---\n'));
      });
    }

    testWidgets(
      'PerplexityCompanyCard populates 52-week progress zone, parses decorated price, and aligns min/max bounds to both edges',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(680, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _wrapTestWidget(
            const PerplexityCompanyCard(
              data: <String, dynamic>{
                'name': 'Intel Corporation',
                'ticker': 'INTC',
                'exchange': 'NASDAQ',
                'sector': 'Semiconductors',
                'price': 'Approx: \$34.00',
                'changePercent': -0.5,
                'range52w': '24.59 – 44.32',
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final UiRangeMeter meter = tester.widget<UiRangeMeter>(
          find.byType(UiRangeMeter),
        );
        expect(meter.zones, hasLength(1));
        expect(meter.zones.first.start, closeTo(24.59, 0.01));
        expect(meter.zones.first.end, closeTo(34.00, 0.01));
        expect(meter.markers, hasLength(1));
        expect(meter.markers.first.value, closeTo(34.00, 0.01));
        expect(find.text('Current 34.00'), findsOneWidget);

        final Rect meterRect = tester.getRect(find.byType(UiRangeMeter));
        final Rect minRect = tester.getRect(find.text('24.59'));
        final Rect maxRect = tester.getRect(find.text('44.32'));
        expect((minRect.left - meterRect.left).abs(), lessThanOrEqualTo(4));
        expect((meterRect.right - maxRect.right).abs(), lessThanOrEqualTo(4));
      },
    );
  });
}
