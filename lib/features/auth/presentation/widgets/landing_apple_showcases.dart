import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/data/demo_data_source.dart';
import 'package:alphajournal/core/markdown_kit/markdown_kit.dart';
import 'package:alphajournal/features/auth/presentation/widgets/apple_device_frames.dart';
import 'package:alphajournal/features/settings/presentation/widgets/settings_side_sheet.dart';

// ---------------------------------------------------------------------------
// Partitioned, rich Indian-market mock data so every single landing section
// looks detailed, vivid, realistic, and 100% unique (zero duplication).
// ---------------------------------------------------------------------------
final DemoDataSource _demo = DemoDataSource.instance;
final List<AppPost> _posts = _demo.posts(limit: 5);
final List<AppTicker> _tickers = _demo.tickers();
final List<AppStrategy> _strategies = _demo.strategies().take(3).toList();
final List<AppNewsItem> _news = _demo.news(limit: 4);
final List<AppAiInsight> _insights = _demo.insights(limit: 3);
final List<AppNote> _notes = _demo.notes(limit: 4);
final List<AppSeriesPoint> _equitySeries = _demo.equitySeries(points: 20);
final List<UiCandle> _relianceCandles = _demo
    .candles('RELIANCE', count: 24)
    .map(
      (AppCandle c) => UiCandle(
        time: c.time,
        open: c.open,
        high: c.high,
        low: c.low,
        close: c.close,
        volume: c.volume,
      ),
    )
    .toList(growable: false);

AppTicker _tickerBySymbol(String symbol, {int fallbackIndex = 0}) =>
    _tickers.firstWhere(
      (AppTicker t) => t.symbol == symbol,
      orElse: () => _tickers[fallbackIndex % _tickers.length],
    );

// Explicit realistic closed profitable trades (never ₹0.00 open placeholders!)
final AppTrade _iciciClosedTrade = AppTrade(
  id: 'landing_trade_icici',
  ticker: 'ICICIBANK',
  side: AppSide.long,
  entry: 1242.50,
  exit: 1288.20,
  size: 400,
  pnl: 18280,
  pnlPercent: 3.68,
  rMultiple: 2.4,
  openedAt: DateTime.now().subtract(const Duration(hours: 6)),
  closedAt: DateTime.now().subtract(const Duration(hours: 2)),
  strategy: 'Opening Range Pullback',
  tags: const <String>['vwap', 'a-plus', 'bank'],
  outcome: AppOutcome.win,
);

final AppTrade _tataMotorsClosedTrade = AppTrade(
  id: 'landing_trade_tatamotors',
  ticker: 'TATAMOTORS',
  side: AppSide.long,
  entry: 968.20,
  exit: 1006.60,
  size: 1000,
  pnl: 38400,
  pnlPercent: 3.96,
  rMultiple: 2.6,
  openedAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
  closedAt: DateTime.now().subtract(const Duration(days: 1)),
  strategy: 'Liquidity Sweep Breakout',
  tags: const <String>['auto', 'breakout'],
  outcome: AppOutcome.win,
);

final AppTrade _sbinBestTrade = AppTrade(
  id: 'landing_trade_sbin',
  ticker: 'SBIN',
  side: AppSide.long,
  entry: 786.40,
  exit: 824.90,
  size: 1200,
  pnl: 46200,
  pnlPercent: 4.89,
  rMultiple: 3.1,
  openedAt: DateTime.now().subtract(const Duration(days: 3)),
  closedAt: DateTime.now().subtract(const Duration(days: 2)),
  strategy: 'PSU Bank Momentum',
  tags: const <String>['psu', 'trend'],
  outcome: AppOutcome.win,
);

final AppTrade _linkedRelianceTrade = AppTrade(
  id: 'landing_trade_rel_linked',
  ticker: 'RELIANCE',
  side: AppSide.long,
  entry: 2874.00,
  exit: 2928.50,
  size: 500,
  pnl: 27250,
  pnlPercent: 1.90,
  rMultiple: 2.2,
  openedAt: DateTime.now().subtract(const Duration(days: 2)),
  closedAt: DateTime.now().subtract(const Duration(days: 1, hours: 18)),
  strategy: 'VWAP Reclaim',
  tags: const <String>['energy', 'linked'],
  outcome: AppOutcome.win,
);

final AppTrade _mmRiskTrade = AppTrade(
  id: 'landing_trade_mm',
  ticker: 'M&M',
  side: AppSide.long,
  entry: 2948.00,
  exit: 3026.40,
  size: 250,
  pnl: 19600,
  pnlPercent: 2.66,
  rMultiple: 2.1,
  openedAt: DateTime.now().subtract(const Duration(days: 1, hours: 6)),
  closedAt: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
  strategy: 'Auto Sector Breakout',
  tags: const <String>['auto', 'momentum'],
  outcome: AppOutcome.win,
);

// Linked knowledge graph data for Phone 3 (Mobile Knowledge Graph) & Spotlight Slide 1
const List<UiGraphNode> _mobileGraphNodes = <UiGraphNode>[
  UiGraphNode(
    id: 'n_orb',
    label: 'ORB Note',
    group: 'Note',
    intent: UiIntent.primary,
    weight: 1.35,
  ),
  UiGraphNode(
    id: 's_pullback',
    label: 'ORB v2.4',
    group: 'Playbook',
    intent: UiIntent.info,
    weight: 1.2,
  ),
  UiGraphNode(
    id: 'j_rel',
    label: 'RELIANCE +2.2R',
    group: 'Trade',
    intent: UiIntent.bullish,
    weight: 1.15,
  ),
  UiGraphNode(
    id: 't_nifty',
    label: r'$NIFTY50',
    group: 'Ticker',
    intent: UiIntent.warning,
    weight: 1.1,
  ),
  UiGraphNode(
    id: 'n_vix',
    label: 'VIX Map',
    group: 'Note',
    intent: UiIntent.primary,
    weight: 1.0,
  ),
  UiGraphNode(
    id: 'j_bnf',
    label: 'BANKNIFTY +1.9R',
    group: 'Trade',
    intent: UiIntent.bullish,
    weight: 1.05,
  ),
];

const List<UiGraphEdge> _mobileGraphEdges = <UiGraphEdge>[
  UiGraphEdge(from: 'n_orb', to: 's_pullback', label: 'defines'),
  UiGraphEdge(from: 'n_orb', to: 'j_rel', label: 'logged'),
  UiGraphEdge(from: 'n_orb', to: 't_nifty', label: 'tracks'),
  UiGraphEdge(from: 'n_orb', to: 'n_vix', label: 'cites'),
  UiGraphEdge(from: 's_pullback', to: 'j_bnf', label: 'executed'),
  UiGraphEdge(from: 'n_vix', to: 't_nifty', label: 'filter'),
];

const AppLinkBundle _mobileNestedLinkBundle = AppLinkBundle(
  notes: <AppLinkRef>[
    AppLinkRef(
      kind: AppLinkKind.note,
      id: 'note_vix',
      title: 'India VIX Regime Filter',
      subtitle: 'Linked inside ORB Note · 6 backlinks',
      meta: '2h ago',
    ),
    AppLinkRef(
      kind: AppLinkKind.note,
      id: 'note_gap',
      title: 'Gap-Up Liquidity Checklist',
      subtitle: 'Linked inside ORB Note · 4 backlinks',
      meta: '1d ago',
    ),
  ],
  strategies: <AppLinkRef>[
    AppLinkRef(
      kind: AppLinkKind.strategy,
      id: 'stg_orb',
      title: 'Opening Range Pullback v2.4',
      subtitle: '66% win rate · 2.4R avg',
      meta: 'Active',
    ),
  ],
  journal: <AppLinkRef>[
    AppLinkRef(
      kind: AppLinkKind.journal,
      id: 'j_rel',
      title: 'RELIANCE Long · +₹27,250',
      subtitle: 'Entry ₹2,874 → Exit ₹2,928.50',
      meta: '+2.2R',
      intent: UiIntent.bullish,
    ),
  ],
  tickers: <AppLinkRef>[
    AppLinkRef(
      kind: AppLinkKind.ticker,
      id: 'NIFTY50',
      title: r'$NIFTY50',
    ),
    AppLinkRef(
      kind: AppLinkKind.ticker,
      id: 'BANKNIFTY',
      title: r'$BANKNIFTY',
    ),
    AppLinkRef(
      kind: AppLinkKind.ticker,
      id: 'RELIANCE',
      title: r'$RELIANCE',
    ),
  ],
);

// Unique rendered AI message #1 — Section 1 (Feature Carousel: HDFCBANK Verdict + 3 Source Cards)
final AppAiMessage _aiFeatureVerdict = AppAiMessage(
  id: 'landing_ai_hdfc_1',
  role: AppAiRole.assistant,
  mode: 'Deep Research',
  focus: 'HDFCBANK 15m',
  sentAt: DateTime.now().subtract(const Duration(minutes: 3)),
  body: '''
### HDFCBANK — Institutional Setup Verdict

> **Bullish FVG Retest** above VWAP with **1 : 2.9 R:R** and clean liquidity sweep.

| Level | Price | Role |
| --- | --- | --- |
| Entry | ₹1,684.50 | Demand FVG |
| Stop | ₹1,666.00 | -1.0R |
| Target | ₹1,738.00 | +2.9R |
''',
  structuredSources: const <AppAiSource>[
    AppAiSource(
      url: 'https://www.nseindia.com',
      title: 'NSE Bank Breadth & Orderflow',
      domain: 'nseindia.com',
      snippet: 'Private banking basket +1.42% on opening hour volume.',
    ),
    AppAiSource(
      url: 'https://alphajournal.in/markets',
      title: 'AlphaJournal VWAP Liquidity Map',
      domain: 'alphajournal.in',
      snippet: 'Institutional bid absorption confirmed at ₹1,682 zone.',
    ),
    AppAiSource(
      url: 'https://economictimes.indiatimes.com',
      title: 'HDFC Bank Q3 Credit Growth Note',
      domain: 'economictimes.com',
      snippet: 'Deposit momentum outpaces peer average by 180 bps.',
    ),
  ],
);

// Unique rendered AI message #3 — Section 4 Phone 2 (Rich Formatted Mobile AI Chat + 3 Source Cards)
final AppAiMessage _aiMobileRichReply = AppAiMessage(
  id: 'landing_ai_mobile_rich_3',
  role: AppAiRole.assistant,
  mode: 'Deep Research',
  focus: 'F&O Risk Sizing',
  sentAt: DateTime.now().subtract(const Duration(minutes: 1)),
  body: '''
### BANKNIFTY — 1% Risk Execution Plan

> **Preferred:** Directional pullback long — **+2.56R** expectancy vs short straddle gamma risk ahead of RBI policy.

| Parameter | Value | Guardrail |
| --- | --- | --- |
| Max Risk (1%) | ₹5,000 | Hard Cap |
| Size | 4 Lots (60) | 82 pt SL |
| Target Zone | +210 pts | +₹12,600 |

- Linked note: **India VIX Regime Filter** (`VIX < 14.5`)
- Est. brokerage + STT + GST: `₹148`
''',
  structuredSources: const <AppAiSource>[
    AppAiSource(
      url: 'https://alphajournal.in/calculators',
      title: 'AlphaJournal F&O Margin Engine',
      domain: 'alphajournal.in',
      snippet: 'Lot size 15 · NSE weekly expiry margin validated.',
    ),
    AppAiSource(
      url: 'https://alphajournal.in/notes',
      title: 'Note: India VIX Regime Filter',
      domain: 'alphajournal.in',
      snippet: 'Directional setups outperform straddles by 1.8R below VIX 15.',
    ),
    AppAiSource(
      url: 'https://www.rbi.org.in',
      title: 'RBI MPC Policy Schedule & Rates',
      domain: 'rbi.org.in',
      snippet: 'Repo rate unchanged at 6.50%; neutral liquidity stance.',
    ),
  ],
);

// Unique rendered AI message #4 — Section 6 Center iPhone (Quant Formula + Python Snippet + 3 Source Cards)
final AppAiMessage _aiQuantSynthesisMessage = AppAiMessage(
  id: 'landing_ai_quant_synth_4',
  role: AppAiRole.assistant,
  mode: 'Quant Lab',
  focus: 'Kelly Sizing & Signal',
  sentAt: DateTime.now().subtract(const Duration(minutes: 2)),
  body: r'''
### Half-Kelly Capital Allocation

Optimal fraction for your **66% win rate** at **2.4R** payoff:

$$f^* = \frac{p \cdot b - q}{b} = 0.518 \;\Rightarrow\; \tfrac{1}{4}\text{ Kelly} = 1.3\%$$

```python
# AlphaJournal Opening Range Filter
def qualify_entry(vwap_dist, rel_vol, vix):
    return vwap_dist > 0 and rel_vol >= 1.5 and vix < 15.0
```

> **Desk Action:** Cap single-trade risk at **1.25%** until India VIX closes below `14.0`.
''',
  structuredSources: const <AppAiSource>[
    AppAiSource(
      url: 'https://www.nseindia.com/market-data',
      title: 'NSE India VIX & Volatility Term',
      domain: 'nseindia.com',
      snippet: 'Front-month IV percentile 28th vs 1Y historical range.',
    ),
    AppAiSource(
      url: 'https://www.sebi.gov.in',
      title: 'SEBI Peak Margin & F&O Rules',
      domain: 'sebi.gov.in',
      snippet: 'Upfront SPAN + exposure margin compliance guidelines.',
    ),
    AppAiSource(
      url: 'https://alphajournal.in/research',
      title: 'AlphaJournal Quant Expectancy Study',
      domain: 'alphajournal.in',
      snippet: 'Quarter-Kelly sizing reduces peak drawdown by 44%.',
    ),
  ],
);

const List<AppAiPrompt> _mobileAiPromptChips = <AppAiPrompt>[
  AppAiPrompt(
    label: 'Link to ORB Note',
    prompt: 'Link this plan to my ORB Note',
    icon: Icons.hub_outlined,
  ),
  AppAiPrompt(
    label: 'Log draft trade',
    prompt: 'Create journal draft for BANKNIFTY',
    icon: Icons.edit_note_rounded,
  ),
];

const AppPriceAlert _tcsBreakoutAlert = AppPriceAlert(
  id: 'landing_alert_tcs',
  symbol: 'TCS',
  targetPrice: 3960.0,
  currentPrice: 3902.1,
  above: true,
  active: true,
);

const AppPriceAlert _hdfcMobileAlert = AppPriceAlert(
  id: 'landing_alert_hdfc_mob',
  symbol: 'HDFCBANK',
  targetPrice: 1720.0,
  currentPrice: 1684.75,
  above: true,
  active: true,
);

// ===========================================================================
// 1. IMAGE 3 STYLE — Apple Horizontal Feature Cards Carousel
//    6 unique cards + full-width CTA button on expanded detail overlay.
// ===========================================================================
class LandingAppleFeatureCarousel extends StatefulWidget {
  const LandingAppleFeatureCarousel({
    super.key,
    required this.onGetStarted,
    this.onExplorePricing,
  });

  final VoidCallback onGetStarted;
  final VoidCallback? onExplorePricing;

  @override
  State<LandingAppleFeatureCarousel> createState() =>
      _LandingAppleFeatureCarouselState();
}

class _LandingAppleFeatureCarouselState
    extends State<LandingAppleFeatureCarousel> {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<({bool prev, bool next})> _pagerState =
      ValueNotifier<({bool prev, bool next})>((prev: false, next: true));

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_syncArrows);
  }

  @override
  void dispose() {
    _scroll.removeListener(_syncArrows);
    _scroll.dispose();
    _pagerState.dispose();
    super.dispose();
  }

  void _syncArrows() {
    if (!_scroll.hasClients) return;
    final ScrollPosition pos = _scroll.position;
    final bool prev = pos.pixels > 8;
    final bool next = pos.pixels < (pos.maxScrollExtent - 8);
    if (prev != _pagerState.value.prev || next != _pagerState.value.next) {
      _pagerState.value = (prev: prev, next: next);
    }
  }

  void _scrollBy(double delta) {
    if (!_scroll.hasClients) return;
    final double target = (_scroll.offset + delta).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _openDetailModal(BuildContext context, _AppleFeatureCardData item) {
    final UiTheme theme = context.ui;
    showSettingsSideSheet<void>(
      context,
      title: item.eyebrow,
      subtitle: 'AlphaJournal Core Capability',
      desktopWidthRatio: 0.46,
      maxWidth: 680,
      minDesktopWidth: 460,
      scrollable: true,
      child: Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: UiBadge(
                label: item.eyebrow,
                intent: item.badgeIntent,
                variant: UiBadgeVariant.soft,
                size: UiSize.sm,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.md)),
            Text(
              item.headline.replaceAll('\n', ' '),
              style: context.uiText.display.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                height: 1.18,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            Text(
              item.body,
              style: context.uiText.body.copyWith(
                color: theme.colors.foregroundMuted,
                height: 1.55,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.xl)),
            item.expandedPreviewBuilder(context),
            SizedBox(height: context.sp(theme.spacing.xl)),
            SizedBox(
              width: double.infinity,
              child: UiButton(
                label: 'Start Free with AlphaJournal',
                expand: true,
                variant: UiVariant.primary,
                intent: UiIntent.primary,
                size: UiSize.lg,
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onGetStarted();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_AppleFeatureCardData> _buildCards() {
    return <_AppleFeatureCardData>[
      _AppleFeatureCardData(
        eyebrow: 'AI Setup Verdict',
        headline: 'Ask anything.\nRender structured\ntrade verdicts.',
        body:
            'Stream live markdown tables, demand zones, invalidation levels, and grounded market citations.',
        badgeIntent: UiIntent.primary,
        actionIcon: Icons.chevron_right_rounded,
        previewBuilder: (BuildContext ctx) => AppleScaledPreview(
          virtualWidth: 376,
          child: AppAiMessageBubble(
            message: _aiFeatureVerdict,
            minimal: true,
          ),
        ),
        expandedPreviewBuilder: (BuildContext ctx) => AppAiMessageBubble(
          message: _aiFeatureVerdict,
          minimal: false,
        ),
      ),
      _AppleFeatureCardData(
        eyebrow: 'Connected Notes',
        headline: 'Link notes inside\nnotes, trades &\nplaybooks.',
        body:
            'Bidirectional backlinks connect every thesis note, NSE ticker, and execution into a living trading wiki.',
        badgeIntent: UiIntent.info,
        actionIcon: Icons.add_rounded,
        previewBuilder: (BuildContext ctx) => AppleScaledPreview(
          virtualWidth: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppNoteCard(
                note: _notes[0],
                density: AppNoteDensity.comfortable,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final AppLinkRef ref
                      in _mobileNestedLinkBundle.notes.take(2))
                    AppLinkChip(ref: ref, size: UiSize.xs),
                ],
              ),
            ],
          ),
        ),
        expandedPreviewBuilder: (BuildContext ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppNoteCard(note: _notes[0], density: AppNoteDensity.full),
            const SizedBox(height: 12),
            AppLinkedRecordsPanel(
              bundle: _mobileNestedLinkBundle,
              title: 'Backlinks & Connected Records',
              dense: true,
              showEmptyKinds: false,
            ),
          ],
        ),
      ),
      _AppleFeatureCardData(
        eyebrow: 'Verified Community',
        headline: 'High-signal ideas\nfrom disciplined\ntraders.',
        body:
            'Explore thesis-backed setups tagged with live NSE tickers, transparent R-multiples, and peer feedback.',
        badgeIntent: UiIntent.info,
        actionIcon: Icons.add_rounded,
        previewBuilder: (BuildContext ctx) => AppleScaledPreview(
          virtualWidth: 360,
          child: AppPostCard(post: _posts[0]),
        ),
        expandedPreviewBuilder: (BuildContext ctx) =>
            AppPostCard(post: _posts[0]),
      ),
      _AppleFeatureCardData(
        eyebrow: 'Execution Journal',
        headline: 'Log every trade.\nQuantify your\nactual edge.',
        body:
            'Capture entry, exit, size, R-multiple, and strategy tags in seconds with zero spreadsheet upkeep.',
        badgeIntent: UiIntent.bullish,
        actionIcon: Icons.add_rounded,
        previewBuilder: (BuildContext ctx) => AppleScaledPreview(
          virtualWidth: 350,
          child: AppTradeCard(trade: _iciciClosedTrade),
        ),
        expandedPreviewBuilder: (BuildContext ctx) =>
            AppTradeCard(trade: _iciciClosedTrade),
      ),
      _AppleFeatureCardData(
        eyebrow: 'Smart Price Alerts',
        headline: 'Track key levels.\nNever miss a\nbreakout.',
        body:
            'Set directional price triggers across NSE equities and indices with live distance-to-target meters.',
        badgeIntent: UiIntent.warning,
        actionIcon: Icons.add_rounded,
        previewBuilder: (BuildContext ctx) => AppleScaledPreview(
          virtualWidth: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const AppPriceAlertCard(alert: _tcsBreakoutAlert),
              const SizedBox(height: 10),
              AppTickerCard(
                ticker: _tickerBySymbol('TCS', fallbackIndex: 3),
                dense: true,
              ),
            ],
          ),
        ),
        expandedPreviewBuilder: (BuildContext ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const AppPriceAlertCard(alert: _tcsBreakoutAlert),
            const SizedBox(height: 12),
            AppTickerCard(ticker: _tickerBySymbol('TCS', fallbackIndex: 3)),
          ],
        ),
      ),
      _AppleFeatureCardData(
        eyebrow: 'Mindset & Lessons',
        headline: 'Audit psychology.\nCompound good\nhabits.',
        body:
            'Score emotional discipline after every session and turn recurring mistakes into structured playbook rules.',
        badgeIntent: UiIntent.primary,
        actionIcon: Icons.add_rounded,
        previewBuilder: (BuildContext ctx) => const AppleScaledPreview(
          virtualWidth: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppPsychologyCard(
                score: 4,
                note: 'Waited for 15m candle close before scaling in.',
              ),
              SizedBox(height: 10),
              AppLessonCard(
                title: 'Respect afternoon cutoff',
                body:
                    'Avoid chasing extended breakouts after 14:15 IST when liquidity thins.',
                tags: <String>['discipline', 'timing'],
              ),
            ],
          ),
        ),
        expandedPreviewBuilder: (BuildContext ctx) => const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppPsychologyCard(
              score: 4,
              note: 'Waited for 15m candle close before scaling in.',
            ),
            SizedBox(height: 12),
            AppLessonCard(
              title: 'Respect afternoon cutoff',
              body:
                  'Avoid chasing extended breakouts after 14:15 IST when liquidity thins.',
              tags: <String>['discipline', 'timing'],
            ),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final UiResponsive res = context.uiRes;
    final List<_AppleFeatureCardData> cards = _buildCards();
    final double cardWidth = res.isMobile ? 296.0 : 344.0;
    final double cardHeight = res.isMobile ? 464.0 : 504.0;
    final double gap = context.sp(theme.spacing.lg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext ctx, BoxConstraints constraints) {
            final bool stackHeader = constraints.maxWidth < 760;
            final Widget titleBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Why AlphaJournal is the best\nplace to build trading discipline.',
                  style: context.uiText.display.copyWith(
                    fontSize: res.isMobile ? 26.0 : 38.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.0,
                    height: 1.12,
                    color: colors.foreground,
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.lg)),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: context.sz(580)),
                  child: Text(
                    'Structured AI trade verdicts, nested research notes, verified community setups, and automated execution analytics built for active Indian traders.',
                    style: context.uiText.body.copyWith(
                      color: colors.foregroundMuted,
                      fontSize: 14.5,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            );
            final Widget linkAction = _EditorialTextLink(
              label: 'Explore plans',
              onTap: widget.onExplorePricing ?? widget.onGetStarted,
            );

            if (stackHeader) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  titleBlock,
                  SizedBox(height: context.sp(theme.spacing.md)),
                  linkAction,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(child: titleBlock),
                SizedBox(width: context.sp(theme.spacing.lg)),
                linkAction,
              ],
            );
          },
        ),
        SizedBox(height: context.sp(theme.spacing.xxxl)),
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            // Prevent vertical mouse-wheel / trackpad scrolls on desktop from
            // being hijacked left-to-right; desktop uses the < > buttons cleanly.
            physics: res.isMobile
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            clipBehavior: Clip.none,
            itemCount: cards.length,
            separatorBuilder: (_, _) => SizedBox(width: gap),
            itemBuilder: (BuildContext ctx, int idx) {
              final _AppleFeatureCardData card = cards[idx];
              return _AppleFeatureTallCard(
                data: card,
                width: cardWidth,
                height: cardHeight,
                onExpand: () => _openDetailModal(context, card),
              );
            },
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.lg)),
        ValueListenableBuilder<({bool prev, bool next})>(
          valueListenable: _pagerState,
          builder: (BuildContext ctx, ({bool prev, bool next}) pager, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                _CircularPagerButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Previous features',
                  enabled: pager.prev,
                  onPressed: () => _scrollBy(-(cardWidth + gap)),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                _CircularPagerButton(
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Next features',
                  enabled: pager.next,
                  onPressed: () => _scrollBy(cardWidth + gap),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AppleFeatureCardData {
  const _AppleFeatureCardData({
    required this.eyebrow,
    required this.headline,
    required this.body,
    required this.badgeIntent,
    required this.actionIcon,
    required this.previewBuilder,
    required this.expandedPreviewBuilder,
  });

  final String eyebrow;
  final String headline;
  final String body;
  final UiIntent badgeIntent;
  final IconData actionIcon;
  final WidgetBuilder previewBuilder;
  final WidgetBuilder expandedPreviewBuilder;
}

class _AppleFeatureTallCard extends StatefulWidget {
  const _AppleFeatureTallCard({
    required this.data,
    required this.width,
    required this.height,
    required this.onExpand,
  });

  final _AppleFeatureCardData data;
  final double width;
  final double height;
  final VoidCallback onExpand;

  @override
  State<_AppleFeatureTallCard> createState() => _AppleFeatureTallCardState();
}

class _AppleFeatureTallCardState extends State<_AppleFeatureTallCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final bool isDark = theme.brightness == Brightness.dark;
    final BorderRadius cardRadius = BorderRadius.circular(28);

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
        onTap: widget.onExpand,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: widget.width,
          height: widget.height,
          transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: cardRadius,
            border: Border.all(
              color: _hovered
                  ? colors.borderStrong
                  : colors.border.withValues(alpha: isDark ? 0.9 : 1.0),
              width: theme.borders.hairline,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: isDark
                      ? (_hovered ? 0.36 : 0.22)
                      : (_hovered ? 0.12 : 0.07),
                ),
                blurRadius: _hovered ? 30 : 20,
                offset: Offset(0, _hovered ? 14 : 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: cardRadius,
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 26, 26, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.data.eyebrow,
                        style: context.uiText.caption.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: colors.foregroundMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.data.headline,
                        style: context.uiText.display.copyWith(
                          fontSize: 22.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          height: 1.18,
                          color: colors.foreground,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.data.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.body.copyWith(
                          fontSize: 13.5,
                          height: 1.5,
                          color: colors.foregroundMuted,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Expanded(
                        child: Stack(
                          children: <Widget>[
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(18),
                                  ),
                                  child: SingleChildScrollView(
                                    physics: const NeverScrollableScrollPhysics(),
                                    child: widget.data.previewBuilder(context),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: _BottomBlurFadeScrim(
                                color: colors.surface,
                                heightFactor: 0.32,
                                blurSigma: 7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Semantics(
                    button: true,
                    label: 'Inspect ${widget.data.eyebrow}',
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.borderStrong.withValues(alpha: 0.7),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        widget.data.actionIcon,
                        size: 20,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

// ===========================================================================
// Viewport-Aware Ticker Guard + Hero Precision Grid + Traveling Pulses
// Splits static hairline grids into a GPU-cached RepaintBoundary (0 repaints/
// frame) and automatically pauses off-screen pulse controllers during scroll.
// ===========================================================================
mixin _ViewportAwareRepeatMixin<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  AnimationController get viewportController;

  ScrollableState? _verticalScrollable;
  bool _isVisible = true;
  bool _checkScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    var next = Scrollable.maybeOf(context, axis: Axis.vertical);
    while (next != null &&
        next.widget.physics is NeverScrollableScrollPhysics) {
      final outer = Scrollable.maybeOf(next.context, axis: Axis.vertical);
      if (outer == null) break;
      next = outer;
    }
    if (_verticalScrollable != next) {
      _verticalScrollable?.position.removeListener(_scheduleVisibilityCheck);
      _verticalScrollable = next;
      _verticalScrollable?.position.addListener(_scheduleVisibilityCheck);
    }
    _syncTickerState();
    _scheduleVisibilityCheck();
  }

  void _scheduleVisibilityCheck() {
    if (_checkScheduled || !mounted) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted) return;
      final RenderObject? box = context.findRenderObject();
      final RenderObject? vp = _verticalScrollable?.context.findRenderObject();
      bool visible = true;
      if (box is RenderBox &&
          vp is RenderBox &&
          box.hasSize &&
          vp.hasSize &&
          box.attached &&
          vp.attached) {
        final Rect selfRect = box.localToGlobal(Offset.zero) & box.size;
        final Rect vpRect = (vp.localToGlobal(Offset.zero) & vp.size).inflate(
          160,
        );
        visible = selfRect.overlaps(vpRect);
      }
      if (visible != _isVisible) {
        _isVisible = visible;
        _syncTickerState();
      }
    });
  }

  void _syncTickerState() {
    if (!mounted) return;
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      if (viewportController.isAnimating) viewportController.stop();
      viewportController.value = 0.28;
    } else if (_isVisible) {
      if (!viewportController.isAnimating) viewportController.repeat();
    } else {
      if (viewportController.isAnimating) viewportController.stop();
    }
  }

  @override
  void dispose() {
    _verticalScrollable?.position.removeListener(_scheduleVisibilityCheck);
    super.dispose();
  }
}

class LandingHeroGridBackdrop extends StatefulWidget {
  const LandingHeroGridBackdrop({
    super.key,
    this.fadeFromTop = false,
  });

  /// When false (Hero), fades out toward the bottom edge (zero seam below).
  /// When true (Footer + lower thread), fades out toward the top edge
  /// (bottom-to-top fade, zero seam above).
  final bool fadeFromTop;

  @override
  State<LandingHeroGridBackdrop> createState() =>
      _LandingHeroGridBackdropState();
}

class _LandingHeroGridBackdropState extends State<LandingHeroGridBackdrop>
    with SingleTickerProviderStateMixin, _ViewportAwareRepeatMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  AnimationController get viewportController => _controller;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final bool isDark = theme.brightness == Brightness.dark;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Static coordinate grid, crosshairs & vignette — cached ONCE on GPU
          RepaintBoundary(
            child: CustomPaint(
              painter: _HeroStaticGridPainter(
                isDark: isDark,
                fadeFromTop: widget.fadeFromTop,
                gridColor: colors.border,
                backgroundColor: colors.background,
                foregroundMuted: colors.foregroundMuted,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          // Lightweight dynamic pulses, sonar rings & glyphs — pauses off-screen
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext ctx, Widget? _) {
                return CustomPaint(
                  painter: _HeroGridPulsePainter(
                    t: _controller.value,
                    isDark: isDark,
                    fadeFromTop: widget.fadeFromTop,
                    gridColor: colors.border,
                    surfaceColor: colors.surface,
                    primaryAccent: colors.series.first,
                    bullishColor: colors.bullish,
                    bearishColor: colors.bearish,
                    warningColor: colors.warning,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStaticGridPainter extends CustomPainter {
  const _HeroStaticGridPainter({
    required this.isDark,
    required this.fadeFromTop,
    required this.gridColor,
    required this.backgroundColor,
    required this.foregroundMuted,
  });

  final bool isDark;
  final bool fadeFromTop;
  final Color gridColor;
  final Color backgroundColor;
  final Color foregroundMuted;

  static const double _cell = 56.0;

  double _verticalFade(double y, double height) {
    if (height <= 0) return 0;
    final double ratio = fadeFromTop ? (1.0 - y / height) : (y / height);
    if (ratio <= 0.50) return 1.0;
    if (ratio >= 0.88) return 0.0;
    final double p = (ratio - 0.50) / 0.38;
    return (1.0 - p) * (1.0 - p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final int cols = (size.width / _cell).ceil();
    final int rows = (size.height / _cell).ceil();
    final double offsetX = (size.width - cols * _cell) * 0.5;
    final double offsetY = 12.0;
    final double baseGridAlpha = isDark ? 0.34 : 0.68;

    final double vStartY = fadeFromTop ? size.height * 0.12 : 0.0;
    final double vEndY = fadeFromTop ? size.height : size.height * 0.88;
    final Paint vLinePaint = Paint()
      ..shader = LinearGradient(
        begin: fadeFromTop ? Alignment.bottomCenter : Alignment.topCenter,
        end: fadeFromTop ? Alignment.topCenter : Alignment.bottomCenter,
        colors: <Color>[
          gridColor.withValues(alpha: baseGridAlpha),
          gridColor.withValues(alpha: baseGridAlpha),
          gridColor.withValues(alpha: baseGridAlpha * 0.35),
          gridColor.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.50, 0.76, 1.0],
      ).createShader(Rect.fromLTRB(0, vStartY, size.width, vEndY))
      ..strokeWidth = 1.0;

    for (int c = 0; c <= cols; c++) {
      final double x = offsetX + c * _cell;
      canvas.drawLine(Offset(x, vStartY), Offset(x, vEndY), vLinePaint);
    }
    for (int r = 0; r <= rows; r++) {
      final double y = offsetY + r * _cell;
      final double fade = _verticalFade(y, size.height);
      if (fade <= 0.005) continue;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = gridColor.withValues(alpha: baseGridAlpha * fade)
          ..strokeWidth = 1.0,
      );
    }

    for (int c = 0; c <= cols; c += 3) {
      final double x = offsetX + c * _cell;
      for (int r = 0; r <= rows; r += 3) {
        final double y = offsetY + r * _cell;
        final double fade = _verticalFade(y, size.height);
        if (fade <= 0.02) continue;
        final Paint crossPaint = Paint()
          ..color = foregroundMuted.withValues(
            alpha: (isDark ? 0.24 : 0.38) * fade,
          )
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(x - 4, y), Offset(x + 4, y), crossPaint);
        canvas.drawLine(Offset(x, y - 4), Offset(x, y + 4), crossPaint);
      }
    }

    if (!fadeFromTop) {
      final Rect centerRect = Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.44),
        width: size.width * 0.66,
        height: size.height * 0.66,
      );
      canvas.drawOval(
        centerRect,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              backgroundColor.withValues(alpha: isDark ? 0.56 : 0.64),
              backgroundColor.withValues(alpha: isDark ? 0.22 : 0.26),
              backgroundColor.withValues(alpha: 0.0),
            ],
            stops: const <double>[0.0, 0.55, 1.0],
          ).createShader(centerRect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeroStaticGridPainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.fadeFromTop != fadeFromTop ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.backgroundColor != backgroundColor;
}

enum _HeroVectorGlyphKind {
  candlesticks,
  sparkline,
  graphNodes,
  aiSparkle,
  reticle,
  volumeBars,
  trendArrow,
  shieldCheck,
}

class _HeroGridPulsePainter extends CustomPainter {
  const _HeroGridPulsePainter({
    required this.t,
    required this.isDark,
    required this.fadeFromTop,
    required this.gridColor,
    required this.surfaceColor,
    required this.primaryAccent,
    required this.bullishColor,
    required this.bearishColor,
    required this.warningColor,
  });

  final double t;
  final bool isDark;
  final bool fadeFromTop;
  final Color gridColor;
  final Color surfaceColor;
  final Color primaryAccent;
  final Color bullishColor;
  final Color bearishColor;
  final Color warningColor;

  static const double _cell = 56.0;

  /// Smooth vertical fade multiplier:
  /// - Hero (`fadeFromTop == false`): 1.0 in upper half, eases to 0.0 by 88% height.
  /// - Footer (`fadeFromTop == true`): 0.0 in top 12%, eases up to 1.0 by 52% height.
  double _verticalFade(double y, double height) {
    if (height <= 0) return 0;
    final double ratio = fadeFromTop ? (1.0 - y / height) : (y / height);
    if (ratio <= 0.50) return 1.0;
    if (ratio >= 0.88) return 0.0;
    final double p = (ratio - 0.50) / 0.38;
    return (1.0 - p) * (1.0 - p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final int cols = (size.width / _cell).ceil();
    final int rows = (size.height / _cell).ceil();
    final double offsetX = (size.width - cols * _cell) * 0.5;
    final double offsetY = 12.0;

    // 1. Softly breathing highlighted perimeter grid cells
    final List<({double fx, double fy, Color color, double phase})> litCells =
        <({double fx, double fy, Color color, double phase})>[
          (fx: 0.08, fy: 0.26, color: primaryAccent, phase: 0.0),
          (fx: 0.16, fy: 0.60, color: bullishColor, phase: 0.22),
          (fx: 0.84, fy: 0.30, color: bullishColor, phase: 0.45),
          (fx: 0.91, fy: 0.56, color: primaryAccent, phase: 0.68),
          (fx: 0.24, fy: 0.18, color: warningColor, phase: 0.82),
          (fx: 0.76, fy: 0.68, color: primaryAccent, phase: 0.33),
        ];

    for (final cellSpec in litCells) {
      final int col = ((size.width * cellSpec.fx - offsetX) / _cell)
          .floor()
          .clamp(0, math.max(0, cols - 1));
      final int row = ((size.height * cellSpec.fy - offsetY) / _cell)
          .floor()
          .clamp(0, math.max(0, rows - 1));
      final double cellCenterY = offsetY + (row + 0.5) * _cell;
      final double fade = _verticalFade(cellCenterY, size.height);
      if (fade <= 0.02) continue;
      final double wave =
          0.5 + 0.5 * math.sin((t + cellSpec.phase) * math.pi * 2);
      final Rect cellRect = Rect.fromLTWH(
        offsetX + col * _cell + 1,
        offsetY + row * _cell + 1,
        _cell - 2,
        _cell - 2,
      );
      canvas.drawRect(
        cellRect,
        Paint()
          ..color = cellSpec.color.withValues(
            alpha:
                ((isDark ? 0.025 : 0.02) + wave * (isDark ? 0.065 : 0.045)) *
                fade,
          ),
      );
    }

    // 4. Traveling light pulses gliding along grid lines
    _drawHorizontalPulse(
      canvas,
      size,
      y: offsetY + (math.max(2, (rows * 0.28).round())) * _cell,
      progress: t,
      color: primaryAccent,
      beamLength: 170,
    );
    _drawHorizontalPulse(
      canvas,
      size,
      y: offsetY + (math.max(4, (rows * 0.66).round())) * _cell,
      progress: (t + 0.38) % 1.0,
      color: bullishColor,
      beamLength: 150,
      reverse: true,
    );
    _drawVerticalPulse(
      canvas,
      size,
      x: offsetX + (math.max(2, (cols * 0.16).round())) * _cell,
      progress: (t + 0.18) % 1.0,
      color: primaryAccent,
      beamLength: 130,
    );
    _drawVerticalPulse(
      canvas,
      size,
      x: offsetX + (math.max(3, (cols * 0.84).round())) * _cell,
      progress: (t + 0.62) % 1.0,
      color: bullishColor,
      beamLength: 130,
    );

    // 5. Soft expanding radar/sonar pulse rings at two balanced flank nodes
    final double leftSonarY = fadeFromTop ? 0.62 : 0.44;
    final double rightSonarY = fadeFromTop ? 0.56 : 0.48;
    _drawSonarPulse(
      canvas,
      center: _snapToGrid(
        Offset(size.width * 0.15, size.height * leftSonarY),
        offsetX,
        offsetY,
      ),
      progress: t,
      color: primaryAccent,
    );
    _drawSonarPulse(
      canvas,
      center: _snapToGrid(
        Offset(size.width * 0.85, size.height * rightSonarY),
        offsetX,
        offsetY,
      ),
      progress: (t + 0.5) % 1.0,
      color: bullishColor,
    );

    // 6. Scattered precision financial vector glyphs anchored inside flank grid tiles
    final bool wideEnoughForGlyphs = size.width >= 760;
    if (wideEnoughForGlyphs) {
      final List<
        ({
          double fx,
          double fy,
          _HeroVectorGlyphKind kind,
          Color accent,
          double phase,
        })
      >
      glyphSpecs =
          <
            ({
              double fx,
              double fy,
              _HeroVectorGlyphKind kind,
              Color accent,
              double phase,
            })
          >[
            (
              fx: 0.09,
              fy: 0.26,
              kind: _HeroVectorGlyphKind.candlesticks,
              accent: bullishColor,
              phase: 0.0,
            ),
            (
              fx: 0.17,
              fy: 0.48,
              kind: _HeroVectorGlyphKind.graphNodes,
              accent: primaryAccent,
              phase: 0.18,
            ),
            (
              fx: 0.10,
              fy: 0.70,
              kind: _HeroVectorGlyphKind.reticle,
              accent: warningColor,
              phase: 0.36,
            ),
            (
              fx: 0.24,
              fy: 0.78,
              kind: _HeroVectorGlyphKind.volumeBars,
              accent: primaryAccent,
              phase: 0.54,
            ),
            (
              fx: 0.90,
              fy: 0.24,
              kind: _HeroVectorGlyphKind.aiSparkle,
              accent: primaryAccent,
              phase: 0.12,
            ),
            (
              fx: 0.83,
              fy: 0.46,
              kind: _HeroVectorGlyphKind.sparkline,
              accent: bullishColor,
              phase: 0.42,
            ),
            (
              fx: 0.91,
              fy: 0.68,
              kind: _HeroVectorGlyphKind.trendArrow,
              accent: bullishColor,
              phase: 0.64,
            ),
            (
              fx: 0.76,
              fy: 0.77,
              kind: _HeroVectorGlyphKind.shieldCheck,
              accent: warningColor,
              phase: 0.80,
            ),
          ];

      for (final spec in glyphSpecs) {
        final double targetFy = fadeFromTop ? (1.0 - spec.fy) : spec.fy;
        final int col = ((size.width * spec.fx - offsetX) / _cell)
            .floor()
            .clamp(0, math.max(0, cols - 1));
        final int row = ((size.height * targetFy - offsetY) / _cell)
            .floor()
            .clamp(0, math.max(0, rows - 1));
        final double pulse =
            0.5 + 0.5 * math.sin((t * 2 + spec.phase) * math.pi * 2);
        final Offset center = Offset(
          offsetX + (col + 0.5) * _cell,
          offsetY + (row + 0.5) * _cell + (pulse - 0.5) * 2.5,
        );
        final double fade = _verticalFade(center.dy, size.height);
        if (fade <= 0.15) continue;
        _drawGlyphTile(
          canvas,
          center: center,
          kind: spec.kind,
          accent: spec.accent,
          pulse: pulse,
          visibility: fade,
        );
      }
    }
  }

  Offset _snapToGrid(Offset raw, double offsetX, double offsetY) {
    final double x = offsetX + ((raw.dx - offsetX) / _cell).round() * _cell;
    final double y = offsetY + ((raw.dy - offsetY) / _cell).round() * _cell;
    return Offset(x, y);
  }

  void _drawHorizontalPulse(
    Canvas canvas,
    Size size, {
    required double y,
    required double progress,
    required Color color,
    required double beamLength,
    bool reverse = false,
  }) {
    final double fade = _verticalFade(y, size.height);
    if (fade <= 0.02) return;
    const double pad = 24.0;
    final double travelSpan = size.width + beamLength * 2 + pad * 2;
    // Seamless infinite wrap: at progress=0 head is fully off-screen;
    // at progress=1 the ENTIRE tail has exited the opposite edge.
    final double headX = reverse
        ? (size.width + beamLength + pad) - travelSpan * progress
        : -(beamLength + pad) + travelSpan * progress;
    final double tailX = reverse ? headX + beamLength : headX - beamLength;
    final double leftX = math.min(headX, tailX);
    final double rightX = math.max(headX, tailX);
    if (rightX < 0 || leftX > size.width) return;

    final Rect r = Rect.fromLTWH(leftX, y - 1.5, beamLength, 3.0);
    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: reverse ? Alignment.centerRight : Alignment.centerLeft,
        end: reverse ? Alignment.centerLeft : Alignment.centerRight,
        colors: <Color>[
          color.withValues(alpha: 0.0),
          color.withValues(alpha: (isDark ? 0.55 : 0.52) * fade),
          color.withValues(alpha: (isDark ? 0.92 : 0.88) * fade),
          color.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.62, 0.92, 1.0],
      ).createShader(r)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(tailX, y), Offset(headX, y), paint);

    // Leading glow node positioned cleanly at the moving front tip
    final double dotX = reverse ? headX + 8 : headX - 8;
    if (dotX >= -4 && dotX <= size.width + 4) {
      canvas.drawCircle(
        Offset(dotX, y),
        2.6,
        Paint()..color = color.withValues(alpha: (isDark ? 0.85 : 0.84) * fade),
      );
    }
  }

  void _drawVerticalPulse(
    Canvas canvas,
    Size size, {
    required double x,
    required double progress,
    required Color color,
    required double beamLength,
  }) {
    final double minY = fadeFromTop ? size.height * 0.12 : 0.0;
    final double maxY = fadeFromTop ? size.height : size.height * 0.88;
    final double span = maxY - minY;
    if (span <= 1) return;

    // Seamless infinite wrap: head enters from minY, and tail completely exits
    // past maxY (where _verticalFade == 0) before progress wraps back to 0.
    const double pad = 16.0;
    final double travelSpan = span + beamLength * 2 + pad * 2;
    final double headY = minY - pad + travelSpan * progress;
    final double rawTailY = headY - beamLength;
    final double tailY = rawTailY.clamp(minY, maxY);
    final double clampedHeadY = headY.clamp(minY, maxY);
    if (clampedHeadY <= tailY + 1.0) return;

    final double headFade = _verticalFade(clampedHeadY, size.height);
    final double midFade = _verticalFade(
      (tailY + clampedHeadY) * 0.5,
      size.height,
    );
    final double segFade = math.max(headFade, midFade);
    if (segFade <= 0.01) return;

    final Rect r = Rect.fromLTWH(
      x - 1.5,
      rawTailY,
      3.0,
      beamLength,
    );
    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          color.withValues(alpha: 0.0),
          color.withValues(alpha: (isDark ? 0.50 : 0.48) * segFade),
          color.withValues(alpha: (isDark ? 0.88 : 0.84) * segFade),
          color.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.62, 0.92, 1.0],
      ).createShader(r)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, tailY), Offset(x, clampedHeadY), paint);

    // Leading glow node smoothly fades in at top & out toward faded edge
    final double dotY = headY - 6;
    if (dotY >= minY && dotY <= maxY) {
      final double enterFade = ((dotY - minY) / 28.0).clamp(0.0, 1.0);
      final double dotAlpha =
          (isDark ? 0.82 : 0.80) *
          _verticalFade(dotY, size.height) *
          enterFade;
      if (dotAlpha > 0.01) {
        canvas.drawCircle(
          Offset(x, dotY),
          2.3,
          Paint()..color = color.withValues(alpha: dotAlpha),
        );
      }
    }
  }

  void _drawSonarPulse(
    Canvas canvas, {
    required Offset center,
    required double progress,
    required Color color,
  }) {
    // Two staggered concentric waves per anchor + continuous sinusoidal core glow
    // so the ripple radiates infinitely with zero reset pop or dead pause.
    for (int wave = 0; wave < 2; wave++) {
      final double p = (progress + wave * 0.5) % 1.0;
      final double eased = Curves.easeOutCubic.transform(p);
      final double radius = 6.0 + eased * 116.0;
      // Smooth envelope: fades in 0->1 over first 14%, then fades smoothly 1->0
      final double fadeIn = (p / 0.14).clamp(0.0, 1.0);
      final double fadeOut = (1.0 - eased);
      final double alpha = fadeIn * fadeOut * (isDark ? 0.38 : 0.44);
      if (alpha <= 0.008) continue;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.25
          ..color = color.withValues(alpha: alpha),
      );
    }

    // Smooth periodic breathing core dot (C-infinity continuous at 0.0 == 1.0)
    final double breath = 0.5 + 0.5 * math.sin(progress * math.pi * 2);
    canvas.drawCircle(
      center,
      2.6 + breath * 0.8,
      Paint()
        ..color = color.withValues(
          alpha: (isDark ? 0.34 : 0.40) + breath * (isDark ? 0.32 : 0.34),
        ),
    );
  }

  void _drawGlyphTile(
    Canvas canvas, {
    required Offset center,
    required _HeroVectorGlyphKind kind,
    required Color accent,
    required double pulse,
    double visibility = 1.0,
  }) {
    const double tileSize = 40.0;
    final RRect tile = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: tileSize, height: tileSize),
      const Radius.circular(11),
    );

    canvas.drawRRect(
      tile,
      Paint()
        ..color = surfaceColor.withValues(
          alpha: (isDark ? 0.68 : 0.94) * visibility,
        ),
    );
    canvas.drawRRect(
      tile,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Color.lerp(
          gridColor,
          accent,
          0.18 + 0.24 * pulse,
        )!.withValues(alpha: (isDark ? 0.72 : 0.92) * visibility),
    );

    final double iconAlpha =
        (isDark ? (0.68 + 0.26 * pulse) : (0.78 + 0.20 * pulse)) * visibility;
    final Paint stroke = Paint()
      ..color = accent.withValues(alpha: iconAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Paint fill = Paint()
      ..color = accent.withValues(alpha: iconAlpha * 0.85)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    switch (kind) {
      case _HeroVectorGlyphKind.candlesticks:
        // Bullish candle left + bearish candle right
        final Paint bullStroke = Paint()
          ..color = bullishColor.withValues(alpha: iconAlpha)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        final Paint bearStroke = Paint()
          ..color = bearishColor.withValues(alpha: iconAlpha)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(-5, -9), const Offset(-5, 9), bullStroke);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-7.5, -4.5, 5, 9),
            const Radius.circular(1.2),
          ),
          Paint()..color = bullishColor.withValues(alpha: iconAlpha),
        );
        canvas.drawLine(const Offset(5, -7), const Offset(5, 8), bearStroke);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2.5, -2.5, 5, 7),
            const Radius.circular(1.2),
          ),
          Paint()..color = bearishColor.withValues(alpha: iconAlpha),
        );
      case _HeroVectorGlyphKind.sparkline:
        final Path p = Path()
          ..moveTo(-10, 6)
          ..lineTo(-5, 2)
          ..lineTo(-1, 5)
          ..lineTo(4, -3)
          ..lineTo(9, -7);
        canvas.drawPath(p, stroke);
        canvas.drawCircle(const Offset(9, -7), 2.3, fill);
      case _HeroVectorGlyphKind.graphNodes:
        const Offset a = Offset(-7, -5);
        const Offset b = Offset(8, -3);
        const Offset c = Offset(-1, 7);
        final Paint edgePaint = Paint()
          ..color = accent.withValues(alpha: iconAlpha * 0.6)
          ..strokeWidth = 1.2;
        canvas.drawLine(a, b, edgePaint);
        canvas.drawLine(a, c, edgePaint);
        canvas.drawLine(b, c, edgePaint);
        canvas.drawCircle(a, 2.7, fill);
        canvas.drawCircle(b, 2.4, stroke);
        canvas.drawCircle(c, 2.4, stroke);
      case _HeroVectorGlyphKind.aiSparkle:
        final Path star = Path()
          ..moveTo(0, -9)
          ..quadraticBezierTo(1.2, -1.2, 9, 0)
          ..quadraticBezierTo(1.2, 1.2, 0, 9)
          ..quadraticBezierTo(-1.2, 1.2, -9, 0)
          ..quadraticBezierTo(-1.2, -1.2, 0, -9)
          ..close();
        canvas.drawPath(star, stroke);
        canvas.drawCircle(const Offset(6.5, -6.5), 1.4, fill);
      case _HeroVectorGlyphKind.reticle:
        canvas.drawCircle(Offset.zero, 6.8, stroke);
        canvas.drawLine(const Offset(-10, 0), const Offset(-4.5, 0), stroke);
        canvas.drawLine(const Offset(4.5, 0), const Offset(10, 0), stroke);
        canvas.drawLine(const Offset(0, -10), const Offset(0, -4.5), stroke);
        canvas.drawLine(const Offset(0, 4.5), const Offset(0, 10), stroke);
        canvas.drawCircle(Offset.zero, 1.8, fill);
      case _HeroVectorGlyphKind.volumeBars:
        final List<double> heights = <double>[5, 9, 7, 13];
        for (int i = 0; i < heights.length; i++) {
          final double x = -9.0 + i * 5.2;
          final double h = heights[i];
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 7.5 - h, 3.2, h),
              const Radius.circular(1.0),
            ),
            i == 3 ? fill : (Paint()..color = accent.withValues(alpha: iconAlpha * 0.45)),
          );
        }
      case _HeroVectorGlyphKind.trendArrow:
        canvas.drawLine(const Offset(-7, 7), const Offset(7, -7), stroke);
        final Path head = Path()
          ..moveTo(1, -7)
          ..lineTo(7, -7)
          ..lineTo(7, -1);
        canvas.drawPath(head, stroke);
      case _HeroVectorGlyphKind.shieldCheck:
        final Path shield = Path()
          ..moveTo(0, -9)
          ..lineTo(7.5, -5.5)
          ..lineTo(7.5, 1.0)
          ..quadraticBezierTo(7.5, 6.8, 0, 9.5)
          ..quadraticBezierTo(-7.5, 6.8, -7.5, 1.0)
          ..lineTo(-7.5, -5.5)
          ..close();
        canvas.drawPath(shield, stroke);
        final Path check = Path()
          ..moveTo(-3.2, 0.2)
          ..lineTo(-0.8, 2.8)
          ..lineTo(3.8, -2.4);
        canvas.drawPath(check, stroke);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HeroGridPulsePainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.isDark != isDark ||
      oldDelegate.fadeFromTop != fadeFromTop ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.primaryAccent != primaryAccent;
}

// ===========================================================================
// All-4-Sides Faded Precision Grid Patch (balances left- & right-aligned
// section headers using the exact Hero coordinate grid, live traveling track
// pulses, sonar ring, and scattered vector trading glyphs — mathematically
// faded to 0.0 on TOP, BOTTOM, LEFT, and RIGHT with zero seams).
// ===========================================================================
class LandingFadedGridAccent extends StatefulWidget {
  const LandingFadedGridAccent({
    super.key,
    this.height = 160,
    this.seed = 0,
  });

  final double height;
  final int seed;

  @override
  State<LandingFadedGridAccent> createState() => _LandingFadedGridAccentState();
}

class _LandingFadedGridAccentState extends State<LandingFadedGridAccent>
    with SingleTickerProviderStateMixin, _ViewportAwareRepeatMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  @override
  AnimationController get viewportController => _controller;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final bool isDark = theme.brightness == Brightness.dark;

    return IgnorePointer(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Static 4-side faded grid & crosshairs — cached ONCE on GPU
            RepaintBoundary(
              child: CustomPaint(
                painter: _FadedStaticGridPainter(
                  isDark: isDark,
                  gridColor: colors.border,
                  foregroundMuted: colors.foregroundMuted,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            // Lightweight dynamic pulse beam, sonar & glyphs — pauses off-screen
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext ctx, Widget? _) {
                  return CustomPaint(
                    painter: _AllSidesFadedGridPainter(
                      t: _controller.value,
                      seed: widget.seed,
                      isDark: isDark,
                      gridColor: colors.border,
                      surfaceColor: colors.surface,
                      primaryAccent: colors.series.first,
                      bullishColor: colors.bullish,
                      bearishColor: colors.bearish,
                      warningColor: colors.warning,
                    ),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FadedStaticGridPainter extends CustomPainter {
  const _FadedStaticGridPainter({
    required this.isDark,
    required this.gridColor,
    required this.foregroundMuted,
  });

  final bool isDark;
  final Color gridColor;
  final Color foregroundMuted;

  static const double _cell = 44.0;

  double _axisFade(double pos, double span) {
    if (span <= 0) return 0.0;
    final double u = (pos / span).clamp(0.0, 1.0);
    if (u <= 0.06 || u >= 0.94) return 0.0;
    if (u < 0.28) {
      final double p = (u - 0.06) / 0.22;
      return p * p * (3 - 2 * p);
    }
    if (u > 0.72) {
      final double p = (0.94 - u) / 0.22;
      return p * p * (3 - 2 * p);
    }
    return 1.0;
  }

  double _edgeFade(Offset pt, Size size) =>
      _axisFade(pt.dx, size.width) * _axisFade(pt.dy, size.height);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final int cols = (size.width / _cell).ceil();
    final int rows = (size.height / _cell).ceil();
    final double offsetX = (size.width - cols * _cell) * 0.5;
    final double offsetY = (size.height - rows * _cell) * 0.5;
    final double baseGridAlpha = isDark ? 0.36 : 0.68;

    for (int c = 0; c <= cols; c++) {
      final double x = offsetX + c * _cell;
      final double xf = _axisFade(x, size.width);
      if (xf <= 0.01) continue;
      final double a = baseGridAlpha * xf;
      final Paint p = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            gridColor.withValues(alpha: 0.0),
            gridColor.withValues(alpha: a),
            gridColor.withValues(alpha: a),
            gridColor.withValues(alpha: 0.0),
          ],
          stops: const <double>[0.04, 0.28, 0.72, 0.96],
        ).createShader(Rect.fromLTWH(x - 1, 0, 2, size.height))
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(x, size.height * 0.04),
        Offset(x, size.height * 0.96),
        p,
      );
    }

    for (int r = 0; r <= rows; r++) {
      final double y = offsetY + r * _cell;
      final double yf = _axisFade(y, size.height);
      if (yf <= 0.01) continue;
      final double a = baseGridAlpha * yf;
      final Paint p = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            gridColor.withValues(alpha: 0.0),
            gridColor.withValues(alpha: a),
            gridColor.withValues(alpha: a),
            gridColor.withValues(alpha: 0.0),
          ],
          stops: const <double>[0.04, 0.26, 0.74, 0.96],
        ).createShader(Rect.fromLTWH(0, y - 1, size.width, 2))
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(size.width * 0.04, y),
        Offset(size.width * 0.96, y),
        p,
      );
    }

    for (int c = 1; c < cols; c += 2) {
      final double x = offsetX + c * _cell;
      for (int r = 1; r < rows; r += 2) {
        final double y = offsetY + r * _cell;
        final double f = _edgeFade(Offset(x, y), size);
        if (f <= 0.08) continue;
        final Paint cp = Paint()
          ..color = foregroundMuted.withValues(
            alpha: (isDark ? 0.26 : 0.40) * f,
          )
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(x - 3.5, y), Offset(x + 3.5, y), cp);
        canvas.drawLine(Offset(x, y - 3.5), Offset(x, y + 3.5), cp);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FadedStaticGridPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.gridColor != gridColor;
}

class _AllSidesFadedGridPainter extends CustomPainter {
  const _AllSidesFadedGridPainter({
    required this.t,
    required this.seed,
    required this.isDark,
    required this.gridColor,
    required this.surfaceColor,
    required this.primaryAccent,
    required this.bullishColor,
    required this.bearishColor,
    required this.warningColor,
  });

  final double t;
  final int seed;
  final bool isDark;
  final Color gridColor;
  final Color surfaceColor;
  final Color primaryAccent;
  final Color bullishColor;
  final Color bearishColor;
  final Color warningColor;

  static const double _cell = 44.0;

  double _axisFade(double pos, double span) {
    if (span <= 0) return 0.0;
    final double u = (pos / span).clamp(0.0, 1.0);
    if (u <= 0.06 || u >= 0.94) return 0.0;
    if (u < 0.28) {
      final double p = (u - 0.06) / 0.22;
      return p * p * (3 - 2 * p);
    }
    if (u > 0.72) {
      final double p = (0.94 - u) / 0.22;
      return p * p * (3 - 2 * p);
    }
    return 1.0;
  }

  double _edgeFade(Offset pt, Size size) =>
      _axisFade(pt.dx, size.width) * _axisFade(pt.dy, size.height);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final int cols = (size.width / _cell).ceil();
    final int rows = (size.height / _cell).ceil();
    final double offsetX = (size.width - cols * _cell) * 0.5;
    final double offsetY = (size.height - rows * _cell) * 0.5;

    // 1. Softly breathing highlighted cells inside the interior
    final double phaseShift = seed * 0.27;
    final List<({double fx, double fy, Color color, double phase})> cells =
        <({double fx, double fy, Color color, double phase})>[
          (fx: 0.30, fy: 0.34, color: primaryAccent, phase: 0.0 + phaseShift),
          (fx: 0.56, fy: 0.62, color: bullishColor, phase: 0.35 + phaseShift),
          (fx: 0.72, fy: 0.36, color: warningColor, phase: 0.70 + phaseShift),
        ];
    for (final spec in cells) {
      final int col = ((size.width * spec.fx - offsetX) / _cell)
          .floor()
          .clamp(0, math.max(0, cols - 1));
      final int row = ((size.height * spec.fy - offsetY) / _cell)
          .floor()
          .clamp(0, math.max(0, rows - 1));
      final Offset center = Offset(
        offsetX + (col + 0.5) * _cell,
        offsetY + (row + 0.5) * _cell,
      );
      final double f = _edgeFade(center, size);
      if (f <= 0.1) continue;
      final double wave =
          0.5 + 0.5 * math.sin((t + spec.phase) * math.pi * 2);
      canvas.drawRect(
        Rect.fromCenter(center: center, width: _cell - 2, height: _cell - 2),
        Paint()
          ..color = spec.color.withValues(
            alpha: ((isDark ? 0.03 : 0.025) + wave * (isDark ? 0.07 : 0.05)) * f,
          ),
      );
    }

    // 5. Seamless infinite traveling pulse beam gliding across a mid-height grid track
    final double pulseProgress = (t + phaseShift) % 1.0;
    final bool reverseBeam = seed.isOdd;
    final double trackY = offsetY + (math.max(1, (rows * 0.5).round())) * _cell;
    final double trackFadeY = _axisFade(trackY, size.height);
    if (trackFadeY > 0.1) {
      const double beamLen = 110.0;
      final double minX = size.width * 0.04;
      final double maxX = size.width * 0.96;
      // Travel spans beyond both faded margins so head enters from 0 alpha and
      // the ENTIRE tail exits into 0 alpha before wrapping — zero snap/reset!
      final double travelSpan = (maxX - minX) + beamLen * 2;
      final double rawHeadX = reverseBeam
          ? (maxX + beamLen) - travelSpan * pulseProgress
          : (minX - beamLen) + travelSpan * pulseProgress;
      final double rawTailX = reverseBeam
          ? rawHeadX + beamLen
          : rawHeadX - beamLen;
      final double drawLeft = math.min(rawHeadX, rawTailX).clamp(minX, maxX);
      final double drawRight = math.max(rawHeadX, rawTailX).clamp(minX, maxX);
      if (drawRight > drawLeft + 1.0) {
        final double segFade =
            _axisFade((drawLeft + drawRight) * 0.5, size.width) * trackFadeY;
        if (segFade > 0.01) {
          final Color beamColor = seed.isEven ? primaryAccent : bullishColor;
          final double shaderLeft = math.min(rawHeadX, rawTailX);
          canvas.drawLine(
            Offset(drawLeft, trackY),
            Offset(drawRight, trackY),
            Paint()
              ..shader = LinearGradient(
                begin: reverseBeam
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                end: reverseBeam ? Alignment.centerLeft : Alignment.centerRight,
                colors: <Color>[
                  beamColor.withValues(alpha: 0.0),
                  beamColor.withValues(alpha: (isDark ? 0.52 : 0.52) * segFade),
                  beamColor.withValues(alpha: (isDark ? 0.88 : 0.86) * segFade),
                  beamColor.withValues(alpha: 0.0),
                ],
                stops: const <double>[0.0, 0.62, 0.92, 1.0],
              ).createShader(
                Rect.fromLTWH(shaderLeft, trackY - 1.5, beamLen, 3.0),
              )
              ..strokeWidth = 1.8
              ..strokeCap = StrokeCap.round,
          );
          final double dotX = reverseBeam ? rawHeadX + 6 : rawHeadX - 6;
          if (dotX >= minX && dotX <= maxX) {
            final double dotFade = _edgeFade(Offset(dotX, trackY), size);
            if (dotFade > 0.02) {
              canvas.drawCircle(
                Offset(dotX, trackY),
                2.3,
                Paint()
                  ..color = beamColor.withValues(
                    alpha: (isDark ? 0.85 : 0.84) * dotFade,
                  ),
              );
            }
          }
        }
      }
    }

    // 6. Seamless infinite dual-wave sonar pulse at a centered-ish intersection
    final Offset sonarCenter = Offset(
      offsetX +
          ((size.width * (seed.isEven ? 0.54 : 0.46) - offsetX) / _cell)
                  .round() *
              _cell,
      offsetY + ((size.height * 0.50 - offsetY) / _cell).round() * _cell,
    );
    final double sonarFade = _edgeFade(sonarCenter, size);
    if (sonarFade > 0.2) {
      final Color sonarColor = seed % 3 == 1 ? bullishColor : primaryAccent;
      final double baseP = (t + phaseShift) % 1.0;
      for (int wave = 0; wave < 2; wave++) {
        final double p = (baseP + wave * 0.5) % 1.0;
        final double eased = Curves.easeOutCubic.transform(p);
        final double radius = 5.0 + eased * 64.0;
        final double fadeIn = (p / 0.14).clamp(0.0, 1.0);
        final double alpha =
            fadeIn * (1.0 - eased) * (isDark ? 0.42 : 0.46) * sonarFade;
        if (alpha <= 0.008) continue;
        canvas.drawCircle(
          sonarCenter,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = sonarColor.withValues(alpha: alpha),
        );
      }
      final double breath = 0.5 + 0.5 * math.sin(baseP * math.pi * 2);
      canvas.drawCircle(
        sonarCenter,
        2.2 + breath * 0.7,
        Paint()
          ..color = sonarColor.withValues(
            alpha:
                ((isDark ? 0.34 : 0.40) + breath * (isDark ? 0.34 : 0.34)) *
                sonarFade,
          ),
      );
    }

    // 7. 3 scattered crisp vector trading glyphs anchored inside grid cells
    final List<
      ({double fx, double fy, _HeroVectorGlyphKind kind, Color accent, double phase})
    >
    glyphSets = switch (seed % 3) {
      0 => <({double fx, double fy, _HeroVectorGlyphKind kind, Color accent, double phase})>[
        (fx: 0.28, fy: 0.42, kind: _HeroVectorGlyphKind.candlesticks, accent: bullishColor, phase: 0.0),
        (fx: 0.52, fy: 0.62, kind: _HeroVectorGlyphKind.graphNodes, accent: primaryAccent, phase: 0.34),
        (fx: 0.74, fy: 0.38, kind: _HeroVectorGlyphKind.aiSparkle, accent: primaryAccent, phase: 0.68),
      ],
      1 => <({double fx, double fy, _HeroVectorGlyphKind kind, Color accent, double phase})>[
        (fx: 0.26, fy: 0.56, kind: _HeroVectorGlyphKind.volumeBars, accent: primaryAccent, phase: 0.12),
        (fx: 0.50, fy: 0.38, kind: _HeroVectorGlyphKind.sparkline, accent: bullishColor, phase: 0.46),
        (fx: 0.73, fy: 0.58, kind: _HeroVectorGlyphKind.reticle, accent: warningColor, phase: 0.78),
      ],
      _ => <({double fx, double fy, _HeroVectorGlyphKind kind, Color accent, double phase})>[
        (fx: 0.28, fy: 0.48, kind: _HeroVectorGlyphKind.shieldCheck, accent: bullishColor, phase: 0.08),
        (fx: 0.52, fy: 0.38, kind: _HeroVectorGlyphKind.trendArrow, accent: primaryAccent, phase: 0.42),
        (fx: 0.74, fy: 0.56, kind: _HeroVectorGlyphKind.aiSparkle, accent: warningColor, phase: 0.74),
      ],
    };

    for (final spec in glyphSets) {
      final int col = ((size.width * spec.fx - offsetX) / _cell)
          .floor()
          .clamp(0, math.max(0, cols - 1));
      final int row = ((size.height * spec.fy - offsetY) / _cell)
          .floor()
          .clamp(0, math.max(0, rows - 1));
      final double pulse =
          0.5 + 0.5 * math.sin((t * 2 + spec.phase) * math.pi * 2);
      final Offset center = Offset(
        offsetX + (col + 0.5) * _cell,
        offsetY + (row + 0.5) * _cell + (pulse - 0.5) * 2.2,
      );
      final double f = _edgeFade(center, size);
      if (f <= 0.15) continue;
      _paintVectorGlyphTile(
        canvas,
        center: center,
        tileSize: 34.0,
        kind: spec.kind,
        accent: spec.accent,
        pulse: pulse,
        visibility: f,
        isDark: isDark,
        gridColor: gridColor,
        surfaceColor: surfaceColor,
        bullishColor: bullishColor,
        bearishColor: bearishColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AllSidesFadedGridPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.seed != seed ||
      oldDelegate.isDark != isDark ||
      oldDelegate.gridColor != gridColor;
}

void _paintVectorGlyphTile(
  Canvas canvas, {
  required Offset center,
  required double tileSize,
  required _HeroVectorGlyphKind kind,
  required Color accent,
  required double pulse,
  required double visibility,
  required bool isDark,
  required Color gridColor,
  required Color surfaceColor,
  required Color bullishColor,
  required Color bearishColor,
}) {
  final RRect tile = RRect.fromRectAndRadius(
    Rect.fromCenter(center: center, width: tileSize, height: tileSize),
    const Radius.circular(10),
  );

  canvas.drawRRect(
    tile,
    Paint()
      ..color = surfaceColor.withValues(
        alpha: (isDark ? 0.68 : 0.94) * visibility,
      ),
  );
  canvas.drawRRect(
    tile,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Color.lerp(
        gridColor,
        accent,
        0.18 + 0.24 * pulse,
      )!.withValues(alpha: (isDark ? 0.72 : 0.92) * visibility),
  );

  final double scale = tileSize / 40.0;
  final double iconAlpha =
      (isDark ? (0.68 + 0.26 * pulse) : (0.78 + 0.20 * pulse)) * visibility;
  final Paint stroke = Paint()
    ..color = accent.withValues(alpha: iconAlpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint fill = Paint()
    ..color = accent.withValues(alpha: iconAlpha * 0.85)
    ..style = PaintingStyle.fill;

  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(scale, scale);

  switch (kind) {
    case _HeroVectorGlyphKind.candlesticks:
      final Paint bullStroke = Paint()
        ..color = bullishColor.withValues(alpha: iconAlpha)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      final Paint bearStroke = Paint()
        ..color = bearishColor.withValues(alpha: iconAlpha)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(-5, -9), const Offset(-5, 9), bullStroke);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-7.5, -4.5, 5, 9),
          const Radius.circular(1.2),
        ),
        Paint()..color = bullishColor.withValues(alpha: iconAlpha),
      );
      canvas.drawLine(const Offset(5, -7), const Offset(5, 8), bearStroke);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(2.5, -2.5, 5, 7),
          const Radius.circular(1.2),
        ),
        Paint()..color = bearishColor.withValues(alpha: iconAlpha),
      );
    case _HeroVectorGlyphKind.sparkline:
      final Path p = Path()
        ..moveTo(-10, 6)
        ..lineTo(-5, 2)
        ..lineTo(-1, 5)
        ..lineTo(4, -3)
        ..lineTo(9, -7);
      canvas.drawPath(p, stroke);
      canvas.drawCircle(const Offset(9, -7), 2.3, fill);
    case _HeroVectorGlyphKind.graphNodes:
      const Offset a = Offset(-7, -5);
      const Offset b = Offset(8, -3);
      const Offset c = Offset(-1, 7);
      final Paint edgePaint = Paint()
        ..color = accent.withValues(alpha: iconAlpha * 0.6)
        ..strokeWidth = 1.2;
      canvas.drawLine(a, b, edgePaint);
      canvas.drawLine(a, c, edgePaint);
      canvas.drawLine(b, c, edgePaint);
      canvas.drawCircle(a, 2.7, fill);
      canvas.drawCircle(b, 2.4, stroke);
      canvas.drawCircle(c, 2.4, stroke);
    case _HeroVectorGlyphKind.aiSparkle:
      final Path star = Path()
        ..moveTo(0, -9)
        ..quadraticBezierTo(1.2, -1.2, 9, 0)
        ..quadraticBezierTo(1.2, 1.2, 0, 9)
        ..quadraticBezierTo(-1.2, 1.2, -9, 0)
        ..quadraticBezierTo(-1.2, -1.2, 0, -9)
        ..close();
      canvas.drawPath(star, stroke);
      canvas.drawCircle(const Offset(6.5, -6.5), 1.4, fill);
    case _HeroVectorGlyphKind.reticle:
      canvas.drawCircle(Offset.zero, 6.8, stroke);
      canvas.drawLine(const Offset(-10, 0), const Offset(-4.5, 0), stroke);
      canvas.drawLine(const Offset(4.5, 0), const Offset(10, 0), stroke);
      canvas.drawLine(const Offset(0, -10), const Offset(0, -4.5), stroke);
      canvas.drawLine(const Offset(0, 4.5), const Offset(0, 10), stroke);
      canvas.drawCircle(Offset.zero, 1.8, fill);
    case _HeroVectorGlyphKind.volumeBars:
      final List<double> heights = <double>[5, 9, 7, 13];
      for (int i = 0; i < heights.length; i++) {
        final double x = -9.0 + i * 5.2;
        final double h = heights[i];
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 7.5 - h, 3.2, h),
            const Radius.circular(1.0),
          ),
          i == 3
              ? fill
              : (Paint()..color = accent.withValues(alpha: iconAlpha * 0.45)),
        );
      }
    case _HeroVectorGlyphKind.trendArrow:
      canvas.drawLine(const Offset(-7, 7), const Offset(7, -7), stroke);
      final Path head = Path()
        ..moveTo(1, -7)
        ..lineTo(7, -7)
        ..lineTo(7, -1);
      canvas.drawPath(head, stroke);
    case _HeroVectorGlyphKind.shieldCheck:
      final Path shield = Path()
        ..moveTo(0, -9)
        ..lineTo(7.5, -5.5)
        ..lineTo(7.5, 1.0)
        ..quadraticBezierTo(7.5, 6.8, 0, 9.5)
        ..quadraticBezierTo(-7.5, 6.8, -7.5, 1.0)
        ..lineTo(-7.5, -5.5)
        ..close();
      canvas.drawPath(shield, stroke);
      final Path check = Path()
        ..moveTo(-3.2, 0.2)
        ..lineTo(-0.8, 2.8)
        ..lineTo(3.8, -2.4);
      canvas.drawPath(check, stroke);
  }

  canvas.restore();
}

// ===========================================================================
// 4. IMAGE 7 STYLE — 5 Vector iPhone SVG Gallery Showcase
//    Rich, full-height AlphaJournal mobile interfaces with ZERO empty black
//    gaps, linked knowledge graphs, notes-inside-notes backlinks, multiple
//    posts, rich AI markdown/tables, live tickers, calculators & QuietDock.
// ===========================================================================
class LandingAppleIphoneGallery extends StatelessWidget {
  const LandingAppleIphoneGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final UiResponsive res = context.uiRes;

    final List<Widget> phones = <Widget>[
      // Phone 1: Rich Mobile Community Feed (2 unique posts + trader strip + Community Dock)
      AppleIphoneSvgFrame(
        width: 244,
        communityDock: true,
        dockActiveIndex: 0,
        screen: _RealMobileInterfaceShell(
          title: 'Community',
          trailingIcon: Icons.notifications_none_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              UiToggleGroup<String>(
                expand: true,
                variant: UiToggleGroupVariant.segmented,
                value: 'for_you',
                options: const <UiToggleOption<String>>[
                  UiToggleOption<String>(label: 'For You', value: 'for_you'),
                  UiToggleOption<String>(label: 'Following', value: 'following'),
                  UiToggleOption<String>(label: 'Setups', value: 'setups'),
                ],
                onChanged: (_) {},
              ),
              const SizedBox(height: 10),
              AppPostCard(post: _posts[1]),
              const SizedBox(height: 10),
              AppPostCard(post: _posts[2]),
            ],
          ),
        ),
      ),

      // Phone 2: Rich Mobile AI Copilot Chat (User Prompt + Formatted Markdown Table + Citations + Chips + Composer)
      AppleIphoneSvgFrame(
        width: 244,
        dockActiveIndex: 1,
        rightFabIcon: Icons.auto_awesome_rounded,
        screen: _RealMobileInterfaceShell(
          title: 'AI Copilot',
          statusPill: 'DEEP AI',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 270),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    'Compare BANKNIFTY weekly straddle vs breakout at 1% risk.',
                    style: context.uiText.body.copyWith(fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              AppAiMessageBubble(
                message: _aiMobileRichReply,
                minimal: true,
              ),
              const SizedBox(height: 10),
              AppAiPromptChips(
                prompts: _mobileAiPromptChips,
                onSelect: (_) {},
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: colors.borderStrong),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.add_circle_outline_rounded,
                      size: 18,
                      color: colors.foregroundMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ask about any NSE setup...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.caption.copyWith(
                          color: colors.foregroundSubtle,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_upward_rounded,
                      size: 16,
                      color: colors.foreground,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // Phone 3 (CENTER HERO): Connected Knowledge Graph + Notes-inside-Notes + Linked Journal & Tickers!
      AppleIphoneSvgFrame(
        width: 260,
        dockActiveIndex: 0,
        screen: _RealMobileInterfaceShell(
          title: 'Linked Notes',
          statusPill: 'GRAPH',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              UiCard(
                padding: const EdgeInsets.all(10),
                title: 'Knowledge Connectivity',
                trailing: const UiBadge(
                  label: '6 nodes',
                  intent: UiIntent.primary,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
                child: const UiGraphCanvas(
                  nodes: _mobileGraphNodes,
                  edges: _mobileGraphEdges,
                  selectedId: 'n_orb',
                  height: 148,
                ),
              ),
              const SizedBox(height: 10),
              AppNoteCard(
                note: _notes[2],
                density: AppNoteDensity.comfortable,
              ),
              const SizedBox(height: 10),
              AppLinkedRecordsPanel(
                bundle: _mobileNestedLinkBundle,
                title: 'Links Inside Note',
                dense: true,
                maxVisiblePerKind: 2,
                showEmptyKinds: false,
              ),
              const SizedBox(height: 10),
              AppLinkedJournalCard(trade: _linkedRelianceTrade),
            ],
          ),
        ),
      ),

      // Phone 4: Rich Mobile Markets Terminal (NIFTY50 + Sector Mini Heat + Macro News + HDFC Alert)
      AppleIphoneSvgFrame(
        width: 244,
        dockActiveIndex: 2,
        screen: _RealMobileInterfaceShell(
          title: 'Markets',
          statusPill: 'NSE LIVE',
          statusIntent: UiIntent.bullish,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              UiToggleGroup<String>(
                expand: true,
                variant: UiToggleGroupVariant.segmented,
                value: 'indices',
                options: const <UiToggleOption<String>>[
                  UiToggleOption<String>(label: 'Indices', value: 'indices'),
                  UiToggleOption<String>(label: 'Equities', value: 'equities'),
                  UiToggleOption<String>(label: 'World', value: 'world'),
                ],
                onChanged: (_) {},
              ),
              const SizedBox(height: 10),
              AppTickerCard(
                ticker: _tickerBySymbol('NIFTY50', fallbackIndex: 4),
                dense: true,
              ),
              const SizedBox(height: 10),
              const Row(
                children: <Widget>[
                  Expanded(
                    child: AppHeatTile(label: 'SBIN', changePercent: 1.84),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: AppHeatTile(label: 'RELIANCE', changePercent: 1.42),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AppNewsCard(item: _news[0]),
              const SizedBox(height: 10),
              const AppPriceAlertCard(alert: _hdfcMobileAlert),
              const SizedBox(height: 10),
              const UiCard(
                title: 'Global & Volatility Cues',
                padding: EdgeInsets.all(12),
                child: UiKeyValueTable(
                  showShareBars: false,
                  valueWidth: 96,
                  rows: <UiKeyValueRow>[
                    UiKeyValueRow(
                      label: 'GIFT NIFTY',
                      value: '24,512 (+0.48%)',
                      intent: UiIntent.bullish,
                    ),
                    UiKeyValueRow(
                      label: 'INDIA VIX',
                      value: '13.42 (-4.1%)',
                      intent: UiIntent.bullish,
                    ),
                    UiKeyValueRow(label: 'USD / INR', value: '₹84.38'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // Phone 5: Rich Mobile Journal + Position Sizing Calculator (Profitable Trade + StatStrip + Sizer + Linked Execution)
      AppleIphoneSvgFrame(
        width: 244,
        dockActiveIndex: 2,
        screen: _RealMobileInterfaceShell(
          title: 'Journal & Risk',
          statusPill: '+ LOG',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const UiStatStrip(
                columns: 2,
                showSpark: false,
                stats: <UiStat>[
                  UiStat(
                    label: 'Month P&L',
                    value: '+₹1.48L',
                    intent: UiIntent.bullish,
                  ),
                  UiStat(
                    label: 'Expectancy',
                    value: '+2.4R',
                    intent: UiIntent.primary,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AppTradeCard(trade: _tataMotorsClosedTrade, dense: true),
              const SizedBox(height: 10),
              UiCard(
                title: 'Position Sizer',
                subtitle: '1.0% Risk Guardrail',
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const UiKeyValueTable(
                      showShareBars: false,
                      valueWidth: 88,
                      rows: <UiKeyValueRow>[
                        UiKeyValueRow(label: 'Capital', value: '₹5,00,000'),
                        UiKeyValueRow(
                          label: 'Max Risk',
                          value: '₹5,000',
                          intent: UiIntent.warning,
                        ),
                        UiKeyValueRow(
                          label: 'Qty (₹20 SL)',
                          value: '250 sh',
                          intent: UiIntent.bullish,
                          emphasis: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    UiRangeMeter(
                      min: 0,
                      max: 3,
                      minLabel: '0%',
                      maxLabel: '3% Cap',
                      valueFormatter: (num v) => '${v.toStringAsFixed(1)}%',
                      zones: const <UiRangeZone>[
                        UiRangeZone(
                          start: 0,
                          end: 1.5,
                          intent: UiIntent.bullish,
                        ),
                        UiRangeZone(
                          start: 1.5,
                          end: 2.2,
                          intent: UiIntent.warning,
                        ),
                        UiRangeZone(
                          start: 2.2,
                          end: 3.0,
                          intent: UiIntent.bearish,
                        ),
                      ],
                      markers: const <UiRangeMarker>[
                        UiRangeMarker(
                          value: 1.0,
                          label: 'Risk',
                          intent: UiIntent.bullish,
                          strong: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AppLinkedJournalCard(trade: _mmRiskTrade),
              const SizedBox(height: 10),
              const UiStatStrip(
                columns: 2,
                showSpark: false,
                stats: <UiStat>[
                  UiStat(label: 'Est. STT & Fees', value: '₹148'),
                  UiStat(
                    label: 'Daily Loss Cap',
                    value: '₹15,000',
                    intent: UiIntent.warning,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.xl),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.sz(1400)),
              child: LayoutBuilder(
                builder: (BuildContext ctx, BoxConstraints headerConstraints) {
                  final Widget headingBlock = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Your entire trading desk.\nConnected in your pocket.',
                        textAlign: TextAlign.left,
                        style: context.uiText.display.copyWith(
                          fontSize: res.isMobile ? 26.0 : 38.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.0,
                          height: 1.12,
                          color: colors.foreground,
                        ),
                      ),
                      SizedBox(height: context.sp(theme.spacing.lg)),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: context.sz(580)),
                        child: Text(
                          'Community feeds, rich AI research, linked knowledge graphs with notes-inside-notes, live NSE markets, and risk calculators — anchored by the frosted floating dock.',
                          textAlign: TextAlign.left,
                          style: context.uiText.body.copyWith(
                            color: colors.foregroundMuted,
                            fontSize: 14.5,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  );

                  if (headerConstraints.maxWidth < 940) {
                    return SizedBox(
                      width: double.infinity,
                      child: headingBlock,
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(flex: 6, child: headingBlock),
                      const SizedBox(width: 28),
                      const Expanded(
                        flex: 5,
                        child: LandingFadedGridAccent(height: 168, seed: 0),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xxxl) + 8),
        if (res.isMobile)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.xl),
              vertical: context.sp(theme.spacing.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < phones.length; i++) ...<Widget>[
                  if (i > 0) SizedBox(width: context.sp(theme.spacing.lg)),
                  phones[i],
                ],
              ],
            ),
          )
        else
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.xl),
              vertical: context.sp(theme.spacing.md),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    for (int i = 0; i < phones.length; i++) ...<Widget>[
                      if (i > 0) SizedBox(width: context.sp(theme.spacing.lg)),
                      phones[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Real floating frosted mobile header shell matching AlphaJournal's mobile UI.
class _RealMobileInterfaceShell extends StatelessWidget {
  const _RealMobileInterfaceShell({
    required this.title,
    required this.child,
    this.statusPill,
    this.statusIntent = UiIntent.primary,
    this.trailingIcon,
  });

  final String title;
  final Widget child;
  final String? statusPill;
  final UiIntent statusIntent;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: colors.borderStrong.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              children: <Widget>[
                Text(
                  title,
                  style: context.uiText.bodyStrong.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.foreground,
                  ),
                ),
                const Spacer(),
                if (statusPill != null)
                  UiBadge(
                    label: statusPill!,
                    intent: statusIntent,
                    variant: UiBadgeVariant.soft,
                    size: UiSize.xs,
                  ),
                if (trailingIcon != null)
                  Icon(
                    trailingIcon,
                    size: 18,
                    color: colors.foregroundMuted,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: IgnorePointer(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 5. IMAGE 8 STYLE — Center Vector iPad Pro + Flanking 2×2 Mosaic Tiles
//    Unique desktop/tablet workspace: Cumulative Equity UiAreaChart +
//    RELIANCE UiCandleChart + Strategy #2, flanked by BANKNIFTY, Best Trade,
//    Macro News #1, ENERGY, TATAMOTORS, Win Rate Radial Gauge, AI Insight #1,
//    and INFRA.
// ===========================================================================
class LandingAppleIpadMosaicSection extends StatelessWidget {
  const LandingAppleIpadMosaicSection({super.key});

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final UiResponsive res = context.uiRes;

    final List<UiChartPoint> equityPoints = _equitySeries
        .map(
          (AppSeriesPoint p) => UiChartPoint(
            label: p.label,
            values: <double>[p.value],
          ),
        )
        .toList(growable: false);

    final Widget ipadHero = AppleIpadSvgFrame(
      width: res.isMobile ? 330 : 492,
      height: res.isMobile ? 410 : 570,
      virtualWidth: 680,
      screen: Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
        child: IgnorePointer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const AppLogo(size: 20, markRounded: false),
                  const Spacer(),
                  const UiBadge(
                    label: 'SBIN ₹812.60',
                    intent: UiIntent.bullish,
                    variant: UiBadgeVariant.soft,
                    size: UiSize.xs,
                  ),
                  const SizedBox(width: 8),
                  const UiBadge(
                    label: 'DESK WORKSPACE',
                    intent: UiIntent.primary,
                    variant: UiBadgeVariant.soft,
                    size: UiSize.xs,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              UiCard(
                title: 'Cumulative Equity Curve',
                subtitle: 'Verified multi-segment performance',
                trailing: const UiBadge(
                  label: '+₹4,12,840',
                  intent: UiIntent.bullish,
                  filled: true,
                ),
                child: UiAreaChart(
                  height: 150,
                  data: equityPoints,
                  showLegend: false,
                  interactive: false,
                  series: <UiChartSeries>[
                    UiChartSeries(
                      name: 'Equity',
                      color: colors.bullish,
                      type: UiChartSeriesType.area,
                      fillOpacity: 0.22,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: UiCard(
                          title: 'RELIANCE · 1D OHLC',
                          subtitle: 'VWAP ₹2,906 · Vol 1.6×',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              UiCandleChart(
                                candles: _relianceCandles,
                                height: 184,
                                interactive: false,
                                showVolume: false,
                              ),
                              const SizedBox(height: 10),
                              const Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: <Widget>[
                                  UiBadge(
                                    label: 'RSI 62.4',
                                    intent: UiIntent.bullish,
                                    variant: UiBadgeVariant.soft,
                                    size: UiSize.xs,
                                  ),
                                  UiBadge(
                                    label: 'EMA 20 Held',
                                    intent: UiIntent.primary,
                                    variant: UiBadgeVariant.soft,
                                    size: UiSize.xs,
                                  ),
                                  UiBadge(
                                    label: 'FVG Filled',
                                    intent: UiIntent.info,
                                    variant: UiBadgeVariant.soft,
                                    size: UiSize.xs,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            AppStrategyPerformanceCard(
                              strategy: _strategies[2],
                            ),
                            const SizedBox(height: 10),
                            const UiCard(
                              title: 'Desk Risk Ratios',
                              padding: EdgeInsets.all(12),
                              child: UiKeyValueTable(
                                showShareBars: false,
                                valueWidth: 88,
                                rows: <UiKeyValueRow>[
                                  UiKeyValueRow(
                                    label: 'Profit Factor',
                                    value: '2.48',
                                    intent: UiIntent.bullish,
                                    emphasis: true,
                                  ),
                                  UiKeyValueRow(
                                    label: 'Sharpe Ratio',
                                    value: '2.14',
                                    intent: UiIntent.primary,
                                  ),
                                  UiKeyValueRow(
                                    label: 'Avg Winner',
                                    value: '+₹24,600',
                                    intent: UiIntent.bullish,
                                  ),
                                  UiKeyValueRow(
                                    label: 'Max Drawdown',
                                    value: '-2.8%',
                                    intent: UiIntent.warning,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const UiStatStrip(
                columns: 4,
                showSpark: false,
                stats: <UiStat>[
                  UiStat(label: 'Trades', value: '42'),
                  UiStat(
                    label: 'Win Rate',
                    value: '66.7%',
                    intent: UiIntent.bullish,
                  ),
                  UiStat(
                    label: 'Profit Factor',
                    value: '2.48',
                    intent: UiIntent.primary,
                  ),
                  UiStat(
                    label: 'Rule Breaks',
                    value: '0',
                    intent: UiIntent.bullish,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final List<Widget> leftTiles = <Widget>[
      _MosaicSquareCard(
        label: 'BANKNIFTY',
        accent: colors.bullish,
        child: AppleScaledPreview(
          virtualWidth: 260,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppTickerCard(
                ticker: _tickerBySymbol('BANKNIFTY', fallbackIndex: 5),
                dense: true,
              ),
              const SizedBox(height: 8),
              const UiProgressBar(
                value: 0.74,
                label: 'Day Range · H 52,380',
                intent: UiIntent.bullish,
                showValue: false,
              ),
            ],
          ),
        ),
      ),
      _MosaicSquareCard(
        label: 'BEST TRADE',
        accent: colors.bullish,
        child: AppleScaledPreview(
          virtualWidth: 260,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppExtremeTradeCard(trade: _sbinBestTrade, best: true),
              const SizedBox(height: 8),
              UiCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Entry',
                          style: context.uiText.caption.copyWith(
                            color: colors.foregroundMuted,
                          ),
                        ),
                        Text('₹786.40', style: context.uiText.numeric),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Exit',
                          style: context.uiText.caption.copyWith(
                            color: colors.foregroundMuted,
                          ),
                        ),
                        Text(
                          '₹824.90',
                          style: context.uiText.numeric.copyWith(
                            color: colors.bullish,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      _MosaicSquareCard(
        label: 'MACRO NEWS',
        accent: colors.info,
        child: AppleScaledPreview(
          virtualWidth: 310,
          child: AppNewsCard(item: _news[1]),
        ),
      ),
      _MosaicSquareCard(
        label: 'ENERGY',
        accent: colors.bullish,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppHeatTile(label: 'NIFTY ENERGY', changePercent: 2.45),
            SizedBox(height: 8),
            AppHeatTile(label: 'OIL & GAS', changePercent: 1.76),
          ],
        ),
      ),
    ];

    final List<Widget> rightTiles = <Widget>[
      _MosaicSquareCard(
        label: 'TATAMOTORS',
        accent: colors.bullish,
        child: AppleScaledPreview(
          virtualWidth: 260,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppTickerCard(
                ticker: _tickerBySymbol('TATAMOTORS', fallbackIndex: 6),
                dense: true,
              ),
              const SizedBox(height: 8),
              const UiProgressBar(
                value: 0.68,
                label: 'Day Range · H 992.40',
                intent: UiIntent.bullish,
                showValue: false,
              ),
            ],
          ),
        ),
      ),
      _MosaicSquareCard(
        label: 'WIN RATE',
        accent: colors.series[0],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 4),
            Center(
              child: UiProgressCircle(
                value: 0.66,
                size: 86,
                intent: UiIntent.bullish,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('66%', style: context.uiText.heading),
                    Text(
                      '28W · 14L',
                      style: context.uiText.caption.copyWith(
                        fontSize: 10,
                        color: colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                UiBadge(
                  label: '2.4R',
                  intent: UiIntent.primary,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
                UiBadge(
                  label: 'PF 2.5',
                  intent: UiIntent.bullish,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
              ],
            ),
          ],
        ),
      ),
      _MosaicSquareCard(
        label: 'AI INSIGHT',
        accent: colors.series[0],
        child: AppleScaledPreview(
          virtualWidth: 310,
          child: AppAiInsightCard(insight: _insights[1]),
        ),
      ),
      _MosaicSquareCard(
        label: 'INFRA',
        accent: colors.bullish,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppHeatTile(label: 'NIFTY INFRA', changePercent: 1.92),
            SizedBox(height: 8),
            AppHeatTile(label: 'NIFTY PSE', changePercent: 1.38),
          ],
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext ctx, BoxConstraints headerConstraints) {
            final bool showCounterweight = headerConstraints.maxWidth >= 940;
            final Widget headingBlock = Column(
              crossAxisAlignment: res.isMobile
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  'Institutional depth on big screens.\nZero friction everywhere.',
                  textAlign: res.isMobile ? TextAlign.left : TextAlign.right,
                  style: context.uiText.display.copyWith(
                    fontSize: res.isMobile ? 26.0 : 38.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.0,
                    height: 1.12,
                    color: colors.foreground,
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.lg)),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: context.sz(560)),
                  child: Text(
                    'Live equity curves, candlestick price action, strategy edge attribution, and sector breadth tiles synchronized across desktop, tablet, and web.',
                    textAlign: res.isMobile ? TextAlign.left : TextAlign.right,
                    style: context.uiText.body.copyWith(
                      color: colors.foregroundMuted,
                      fontSize: 14.5,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            );

            if (!showCounterweight) {
              return headingBlock;
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const Expanded(
                  flex: 5,
                  child: LandingFadedGridAccent(height: 168, seed: 1),
                ),
                const SizedBox(width: 28),
                Expanded(flex: 6, child: headingBlock),
              ],
            );
          },
        ),
        SizedBox(height: context.sp(theme.spacing.xxxl) + 8),
        LayoutBuilder(
          builder: (BuildContext ctx, BoxConstraints constraints) {
            final bool showFlankingGrid = constraints.maxWidth >= 1120;
            if (!showFlankingGrid) {
              return Column(
                children: <Widget>[
                  ipadHero,
                  SizedBox(height: context.sp(theme.spacing.xl)),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      for (final Widget tile in <Widget>[
                        ...leftTiles.take(2),
                        ...rightTiles.take(2),
                      ])
                        SizedBox(width: 168, height: 168, child: tile),
                    ],
                  ),
                ],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(child: _TwoByTwoMosaicGrid(tiles: leftTiles)),
                SizedBox(width: context.sp(theme.spacing.xl)),
                ipadHero,
                SizedBox(width: context.sp(theme.spacing.xl)),
                Expanded(child: _TwoByTwoMosaicGrid(tiles: rightTiles)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TwoByTwoMosaicGrid extends StatelessWidget {
  const _TwoByTwoMosaicGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: tiles[0]),
            const SizedBox(width: 14),
            Expanded(child: tiles[1]),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(child: tiles[2]),
            const SizedBox(width: 14),
            Expanded(child: tiles[3]),
          ],
        ),
      ],
    );
  }
}

class _MosaicSquareCard extends StatelessWidget {
  const _MosaicSquareCard({
    required this.label,
    required this.accent,
    required this.child,
  });

  final String label;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final bool isDark = theme.brightness == Brightness.dark;

    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          constraints: const BoxConstraints(minWidth: 148, maxWidth: 210),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.border,
            width: theme.borders.hairline,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: child,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: _BottomBlurFadeScrim(
                color: colors.surface,
                heightFactor: 0.34,
                blurSigma: 8,
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Row(
                children: <Widget>[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ===========================================================================
// 6. IMAGE 9 STYLE — Center Vector iPhone Pro + Flanking 3+3 Unique AI Formats
//    Matches Apple's full-bleed flanking card strip around a centered iPhone!
//    Center iPhone: Quant Formula + Python Signal + 3 Source Cards (AppAiMessageBubble).
//    Left 3: AI Trade Setup, AI Bull vs Bear, AI Attribution BarList.
//    Right 3: AI Catalyst Timeline, AI Conviction Verdict, AI Allocation Donut.
// ===========================================================================
class LandingAppleCenterPhoneStripSection extends StatelessWidget {
  const LandingAppleCenterPhoneStripSection({super.key});

  static const String _setupCardSpec = '''
{
  "ticker": "BAJFINANCE",
  "title": "BAJFINANCE Breakout Plan",
  "bias": "LONG",
  "timeframe": "1H",
  "entry": "₹7,240 – ₹7,265",
  "stop": "₹7,140 (-1.0R)",
  "targets": ["₹7,460 (+2.0R)", "₹7,610 (+3.4R)"],
  "rr": "1 : 3.4",
  "notes": "Clean reclaim of 20-EMA with expanding delivery volume."
}
''';

  static const String _bullBearCardSpec = '''
{
  "title": "NIFTY IT — Bull vs Bear",
  "mode": "bull_bear",
  "bullCase": [
    "BFSI deal pipeline recovering across Tier-1 IT",
    "Weak rupee adds 40–60 bps EBIT tailwind"
  ],
  "bearCase": [
    "US discretionary tech spend remains selective",
    "Valuations trade at 26× FY26E forward P/E"
  ]
}
''';

  static const String _barListChartSpec = '''
{
  "type": "barlist",
  "title": "Strategy P&L Attribution",
  "items": [
    {"label": "ORB Pullback", "value": 84, "displayValue": "+₹84.2K"},
    {"label": "VWAP Reclaim", "value": 52, "displayValue": "+₹52.4K"},
    {"label": "Gap Fill", "value": 29, "displayValue": "+₹29.1K"}
  ]
}
''';

  static const String _timelineCardSpec = '''
{
  "title": "Macro & Expiry Catalysts",
  "items": [
    {"date": "Thu 10:00", "title": "RBI MPC Rate Decision", "detail": "Repo steady at 6.50%"},
    {"date": "Thu 15:30", "title": "NIFTY Weekly Expiry", "detail": "Max pain 24,400"},
    {"date": "Fri 18:00", "title": "US Core PCE Release", "detail": "Consensus 2.7% YoY"}
  ]
}
''';

  static const String _verdictCardSpec = '''
{
  "title": "SUNPHARMA Conviction",
  "badge": "BULLISH",
  "confidence": 84,
  "summary": "Specialty dermatology ramp & clean weekly base breakout support asymmetric upside.",
  "points": [
    "Relative strength outperforming Nifty by +6.4%",
    "Zero major resistance until ₹1,890"
  ]
}
''';

  static const String _donutChartSpec = '''
{
  "type": "donut",
  "title": "Capital Allocation",
  "slices": [
    {"label": "Banking", "value": 36},
    {"label": "IT", "value": 28},
    {"label": "Auto", "value": 20},
    {"label": "Cash", "value": 16}
  ]
}
''';

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final bool isDark = theme.brightness == Brightness.dark;
    final UiResponsive res = context.uiRes;

    final List<Widget> leftStripCards = <Widget>[
      _StripEditorialTile(
        eyebrow: 'AI TRADE SETUP',
        title: 'BAJFINANCE Plan',
        accent: colors.bullish,
        child: const AppleScaledPreview(
          virtualWidth: 320,
          child: PerplexityCardBlock(tag: 'setup', spec: _setupCardSpec),
        ),
      ),
      _StripEditorialTile(
        eyebrow: 'AI BULL VS BEAR',
        title: 'NIFTY IT Thesis',
        accent: colors.series[0],
        child: const AppleScaledPreview(
          virtualWidth: 330,
          child: PerplexityCardBlock(tag: 'bull_bear', spec: _bullBearCardSpec),
        ),
      ),
      _StripEditorialTile(
        eyebrow: 'AI ATTRIBUTION',
        title: 'Playbook Edge Bars',
        accent: colors.info,
        child: const AppleScaledPreview(
          virtualWidth: 310,
          child: ChartBlock(spec: _barListChartSpec, defaultType: 'barlist'),
        ),
      ),
    ];

    final List<Widget> rightStripCards = <Widget>[
      _StripEditorialTile(
        eyebrow: 'AI CATALYSTS',
        title: 'Event Timeline',
        accent: colors.warning,
        child: const AppleScaledPreview(
          virtualWidth: 320,
          child: PerplexityCardBlock(tag: 'timeline', spec: _timelineCardSpec),
        ),
      ),
      _StripEditorialTile(
        eyebrow: 'AI VERDICT',
        title: 'SUNPHARMA Score',
        accent: colors.bullish,
        child: const AppleScaledPreview(
          virtualWidth: 320,
          child: PerplexityCardBlock(tag: 'verdict', spec: _verdictCardSpec),
        ),
      ),
      _StripEditorialTile(
        eyebrow: 'AI ALLOCATION',
        title: 'Sector Donut Chart',
        accent: colors.series[0],
        child: const AppleScaledPreview(
          virtualWidth: 300,
          child: ChartBlock(spec: _donutChartSpec, defaultType: 'donut'),
        ),
      ),
    ];

    final Widget centerPhone = AppleIphoneSvgFrame(
      width: 266,
      dockActiveIndex: 1,
      rightFabIcon: Icons.auto_awesome_rounded,
      screen: _RealMobileInterfaceShell(
        title: 'AI Quant Lab',
        statusPill: '3 SOURCES',
        statusIntent: UiIntent.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppAiMessageBubble(
              message: _aiQuantSynthesisMessage,
              minimal: true,
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.sp(theme.spacing.xl)),
          child: Column(
            children: <Widget>[
              Text(
                'Every AI answer, rendered in\nthe exact format it deserves.',
                textAlign: TextAlign.center,
                style: context.uiText.display.copyWith(
                  fontSize: res.isMobile ? 26.0 : 38.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.0,
                  height: 1.12,
                  color: colors.foreground,
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.sz(660)),
                child: Text(
                  'Grounded in 3 cited source cards, trade setups, bull/bear matrices, catalyst timelines, LaTeX sizing math, code blocks, and live interactive charts.',
                  textAlign: TextAlign.center,
                  style: context.uiText.body.copyWith(
                    color: colors.foregroundMuted,
                    fontSize: 14.5,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.xxxl) + 8),
        LayoutBuilder(
          builder: (BuildContext ctx, BoxConstraints constraints) {
            final bool showFlankingStrip = constraints.maxWidth >= 940;
            if (!showFlankingStrip) {
              return Column(
                children: <Widget>[
                  centerPhone,
                  SizedBox(height: context.sp(theme.spacing.xl)),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: res.isMobile
                        ? const BouncingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: context.sp(theme.spacing.lg),
                    ),
                    child: Row(
                      children: <Widget>[
                        for (final Widget w in <Widget>[
                          ...leftStripCards,
                          ...rightStripCards,
                        ]) ...<Widget>[
                          SizedBox(width: 196, height: 196, child: w),
                          const SizedBox(width: 12),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }

            // Explicit full width so Positioned(left: 0, right: 0) never collapses
            // to the center iPhone's 266px width!
            return SizedBox(
              width: constraints.maxWidth,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Positioned(
                    top: 68,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Row(
                            children: <Widget>[
                              for (int i = 0; i < leftStripCards.length; i++) ...[
                                if (i > 0) const SizedBox(width: 14),
                                Expanded(
                                  child: AspectRatio(
                                    aspectRatio: 1.0,
                                    child: leftStripCards[i],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 316),
                        Expanded(
                          child: Row(
                            children: <Widget>[
                              for (
                                int i = 0;
                                i < rightStripCards.length;
                                i++
                              ) ...[
                                if (i > 0) const SizedBox(width: 14),
                                Expanded(
                                  child: AspectRatio(
                                    aspectRatio: 1.0,
                                    child: rightStripCards[i],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  centerPhone,
                ],
              ),
            );
          },
        ),
        SizedBox(height: context.sp(theme.spacing.xl)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.sp(theme.spacing.xl)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.sz(680)),
            child: Text(
              'Multi-provider AI synthesis with cited sources, structured trading cards, and native charts across Web, macOS, Windows, iOS, and Android.',
              textAlign: TextAlign.center,
              style: context.uiText.bodyStrong.copyWith(
                fontSize: 13.5,
                color: isDark
                    ? colors.foregroundMuted
                    : colors.foreground.withValues(alpha: 0.78),
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StripEditorialTile extends StatelessWidget {
  const _StripEditorialTile({
    required this.eyebrow,
    required this.title,
    required this.accent,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final bool isDark = theme.brightness == Brightness.dark;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.border,
          width: theme.borders.hairline,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.07),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: child,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: _BottomBlurFadeScrim(
              color: colors.surface,
              heightFactor: 0.36,
              blurSigma: 9,
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption.copyWith(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: accent,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.bodyStrong.copyWith(
                    fontSize: 12.5,
                    color: colors.foreground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ===========================================================================
// Shared Apple-style Controls
// ===========================================================================

/// Progressive bottom-to-top frosted blur + surface fade scrim covering the
/// bottom ~30% of showcase cards so bottom overlay labels sit crisply above
/// dense card content without visual collision.
class _BottomBlurFadeScrim extends StatelessWidget {
  const _BottomBlurFadeScrim({
    required this.color,
    this.heightFactor = 0.34,
    this.blurSigma = 8,
  });

  final Color color;
  final double heightFactor;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          widthFactor: 1.0,
          heightFactor: heightFactor,
          child: ShaderMask(
            shaderCallback: (Rect bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.transparent,
                Colors.black,
                Colors.black,
              ],
              stops: <double>[0.0, 0.45, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: blurSigma,
                  sigmaY: blurSigma,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        color.withValues(alpha: 0.0),
                        color.withValues(alpha: 0.72),
                        color.withValues(alpha: 0.96),
                      ],
                      stops: const <double>[0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircularPagerButton extends StatefulWidget {
  const _CircularPagerButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_CircularPagerButton> createState() => _CircularPagerButtonState();
}

class _CircularPagerButtonState extends State<_CircularPagerButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        label: widget.tooltip,
        child: MouseRegion(
          cursor: widget.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.enabled ? widget.onPressed : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: !widget.enabled
                    ? colors.surfaceMuted.withValues(alpha: 0.45)
                    : (_hovered ? colors.surfaceHover : colors.surfaceMuted),
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.enabled && _hovered
                      ? colors.borderStrong
                      : colors.border,
                  width: theme.borders.hairline,
                ),
              ),
              child: Icon(
                widget.icon,
                size: 22,
                color: widget.enabled
                    ? colors.foreground
                    : colors.foregroundSubtle.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorialTextLink extends StatefulWidget {
  const _EditorialTextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_EditorialTextLink> createState() => _EditorialTextLinkState();
}

class _EditorialTextLinkState extends State<_EditorialTextLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final UiColors colors = context.ui.colors;
    final Color linkColor = colors.series.first;

    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  widget.label,
                  style: context.uiText.bodyStrong.copyWith(
                    fontSize: 15,
                    color: _hovered
                        ? linkColor.withValues(alpha: 0.8)
                        : linkColor,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: linkColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
