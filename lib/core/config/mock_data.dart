import 'package:tradex/core/app-ui/app_ui.dart';

final AppTrader mockTrader = AppTrader(
  id: 'u1',
  handle: 'quantqueen',
  displayName: 'Ava Chen',
  avatarUrl: 'https://i.pravatar.cc/150?img=32',
  tier: AppTier.premium,
  verified: true,
  bio: 'Swing trading tech and semis.',
);

final List<UiCandle> mockCandles = List.generate(24, (i) {
  final double open = 220.0 + (i % 5) * 2 - (i % 3) * 1.5;
  final double close = open + (i % 2 == 0 ? 3.5 : -2.5);
  final double high = (open > close ? open : close) + 2.0;
  final double low = (open < close ? open : close) - 1.5;
  return UiCandle(
    time: DateTime.now().subtract(Duration(days: 24 - i)),
    open: open,
    high: high,
    low: low,
    close: close,
    volume: 1000.0 + (i * 200),
  );
});

final AppPost mockPost = AppPost(
  id: 'p1',
  author: mockTrader,
  body: 'Rotated out of TSLA into AAPL today. Structure is incredibly clean on the 4H.',
  createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
  tickers: const <String>['AAPL', 'TSLA'],
  attachments: [
    AppPostChartAttachment(mockCandles),
    const AppPostStrategyAttachment('ORB Breakout Masterclass', locked: true),
  ],
  likes: 214,
  comments: 18,
  liked: true,
);

final AppTrade aaplTrade = AppTrade(
  id: 't_aapl',
  ticker: 'AAPL',
  side: AppSide.long,
  entry: 220.10,
  exit: 227.40,
  size: 100.00,
  pnl: 730.00,
  pnlPercent: 3.30,
  rMultiple: 2.10,
  openedAt: DateTime.now().subtract(const Duration(days: 1)),
  tags: const ['Opening range breakout', 'breakout', 'tech'],
);

final AppTrade tslaTrade = AppTrade(
  id: 't_tsla',
  ticker: 'TSLA',
  side: AppSide.short,
  entry: 182.50,
  exit: 189.20,
  size: 40.00,
  pnl: -268.00,
  pnlPercent: -3.60,
  rMultiple: -0.90,
  openedAt: DateTime.now().subtract(const Duration(days: 1)),
  tags: const ['Fade the gap', 'gap', 'ev'],
);

final AppTrade msftTrade = AppTrade(
  id: 't_msft',
  ticker: 'MSFT',
  side: AppSide.long,
  entry: 411.20,
  exit: 413.20,
  size: 60.00,
  pnl: 96.00,
  pnlPercent: 0.40,
  openedAt: DateTime.now().subtract(const Duration(days: 1)),
  tags: const ['Trend continuation', 'trend'],
);

final AppNewsItem mockNews = AppNewsItem(
  id: 'n1',
  headline: 'RBI Monetary Policy Committee maintains repo rate at 6.50%, highlighting resilient domestic GDP growth.',
  source: 'Economic Times',
  publishedAt: DateTime.now().subtract(const Duration(minutes: 45)),
  sentimentScore: 0.65,
  tickers: const ['NIFTY50', 'BANKNIFTY'],
  summary: 'In its bi-monthly policy meeting, the Reserve Bank of India maintained liquidity stance while projecting 7.2% annual economic growth.',
);

final AppAiInsight mockInsight = AppAiInsight(
  id: 'ai1',
  title: 'Pattern Detected: Bull Flag',
  body: 'RELIANCE is forming a tight bull flag on the 1H chart with decreasing volume. Watch for a breakout above ₹2,950 with high volume confirmation.',
  confidence: 0.88,
  sentimentScore: 0.8,
  tickers: const ['RELIANCE'],
  createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
);

final AppStrategy mockStrategy = AppStrategy(
  id: 's1',
  name: 'ORB Breakout',
  category: 'bullish',
  summary: '',
  isPublic: true,
  trades: 128,
  winRate: 61,
  avgR: 2.1,
  netPnl: 8420,
  updatedAt: DateTime.now(),
  equityCurve: const [2, 3, 4, 3, 5, 6, 8, 7, 9, 12, 11, 15],
);

final AppStrategy mockStrategy2 = AppStrategy(
  id: 's2',
  name: 'Gap Fade',
  category: 'bearish',
  summary: '',
  isPublic: true,
  trades: 40,
  winRate: 35,
  avgR: -0.4,
  netPnl: -1120,
  updatedAt: DateTime.now(),
  equityCurve: const [15, 14, 14.5, 13, 11, 10, 11, 9, 8, 7, 6, 4],
);
