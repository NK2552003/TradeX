import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/auth/data/repositories/subscription_pricing_repository.dart';
import 'package:alphajournal/features/auth/models/pricing_models.dart';
import 'package:alphajournal/features/auth/presentation/pages/get_started_page.dart';
import 'package:alphajournal/features/auth/presentation/pages/subscription_pricing_page.dart';
import 'package:alphajournal/features/market_data/data/asset_market_repository.dart';
import 'package:alphajournal/features/market_data/presentation/market_sidebar.dart';
import 'package:alphajournal/features/public_site/data/public_site_repository.dart';
import 'package:alphajournal/features/public_site/models/public_site_content.dart';

class FileAssets extends CachingAssetBundle {
  static final List<Map<String, dynamic>> _sampleInstruments = [
    {
      'ticker': 'BTC',
      'price': 65000.0,
      'previous_close': 62984.50,
      'change_pct': 3.2,
      'market': 'CRYPTO',
      'name': 'Bitcoin',
      'volume': 2000000,
    },
    {
      'ticker': 'AAPL',
      'price': 150.0,
      'previous_close': 146.34,
      'change_pct': 2.5,
      'market': 'US',
      'name': 'Apple Inc.',
      'volume': 1000000,
    },
    {
      'ticker': 'MSFT',
      'price': 300.0,
      'previous_close': 303.64,
      'change_pct': -1.2,
      'market': 'US',
      'name': 'Microsoft Corp.',
      'volume': 800000,
    },
    {
      'ticker': 'GOOGL',
      'price': 2800.0,
      'previous_close': 2769.54,
      'change_pct': 1.1,
      'market': 'US',
      'name': 'Alphabet Inc.',
      'volume': 500000,
    },
    {
      'ticker': 'ETH',
      'price': 3500.0,
      'previous_close': 3517.59,
      'change_pct': -0.5,
      'market': 'CRYPTO',
      'name': 'Ethereum',
      'volume': 1200000,
    },
    for (final (i, sym) in [
      'NVDA',
      'AMZN',
      'META',
      'TSLA',
      'AMD',
      'NFLX',
      'AVGO',
      'ORCL',
      'CRM',
      'ADBE',
      'INTC',
      'CSCO',
      'QCOM',
      'TXN',
      'IBM',
      'NOW',
      'INTU',
      'AMAT',
      'MU',
      'LRCX',
      'KLAC',
      'SNPS',
      'CDNS',
      'PANW',
      'CRWD',
      'SNOW',
      'DDOG',
      'NET',
      'MDB',
      'PLTR',
      for (int j = 1; j <= 65; j++) 'EQ${j.toString().padLeft(2, '0')}',
    ].indexed)
      {
        'ticker': sym,
        'price': 120.0 + i * 5.0,
        'previous_close': (120.0 + i * 5.0) * (i.isEven ? 0.99 : 1.01),
        'change_pct': i.isEven ? 1.8 - (i * 0.015) : -0.8 - (i * 0.01),
        'market': 'US',
        'name': '$sym Corp.',
        'volume': 950000 - i * 5000,
      },
  ];

  static final List<Map<String, dynamic>> _sampleCandles = [
    for (int i = 0; i < 45; i++)
      {
        'date': DateTime.utc(
          2026,
          8,
          1,
        ).add(Duration(days: i)).toIso8601String(),
        'open': 142.0 + i * 0.15,
        'high': 145.0 + i * 0.15,
        'low': 141.0 + i * 0.15,
        'close': 144.0 + i * 0.14,
        'volume': 500000 + i * 5000,
      },
  ];

  static final Map<String, String> _memoryFiles = {
    'assets/data/manifest.json': jsonEncode({
      'generated_at': '2026-10-01T00:00:00Z',
      'detail_count': 99,
      'history_count': 2,
      'files': [
        'quotes.json',
        'fundamentals.json',
        'all_news.json',
        'screeners.json',
        'tickers/universe.json',
        'history/AAPL.json',
        'history/BTC.json',
      ],
    }),
    'assets/data/tickers/universe.json': jsonEncode([
      for (final row in _sampleInstruments)
        {
          'ticker': row['ticker'],
          'name': row['name'],
          'market': row['market'],
          'exchange': row['market'] == 'CRYPTO' ? 'CRYPTO' : 'NASDAQ',
          'currency': 'USD',
        },
    ]),
    'assets/data/quotes.json': jsonEncode({
      for (final row in _sampleInstruments) row['ticker'] as String: row,
    }),
    'assets/data/fundamentals.json': jsonEncode({
      for (final row in _sampleInstruments)
        row['ticker'] as String: {
          'name': row['name'],
          'sector': row['market'] == 'CRYPTO' ? 'Digital Assets' : 'Technology',
        },
    }),
    'assets/data/all_news.json': jsonEncode([
      {
        'title': 'Tech Sector Rallies as Markets Open Higher',
        'summary':
            'Major technology stocks posted strong gains on robust earnings reports and easing inflation signals.',
        'publisher': 'Market Wire',
        'link': 'https://example.com/news/1',
        'thumbnail_url': 'https://example.com/thumb/1.png',
        'published_at': '2026-10-01T12:00:00Z',
        'category': 'Markets',
        'related_tickers': ['AAPL', 'MSFT'],
      },
      {
        'title': 'Cloud Enterprise Spending Beats Forecasts',
        'summary':
            'Enterprise software budgets expand on AI workload migrations.',
        'publisher': 'Enterprise Beat',
        'link': 'https://example.com/news/2',
        'published_at': '2026-10-01T11:30:00Z',
        'category': 'Technology',
        'related_tickers': ['MSFT', 'GOOGL'],
      },
      {
        'title': 'Bank Earnings Preview and Rate Outlook',
        'summary':
            'Regional and global banks brace for net interest margin shifts.',
        'publisher': 'Financial Post',
        'link': 'https://example.com/news/3',
        'published_at': '2026-10-01T11:00:00Z',
        'category': 'Finance',
        'related_tickers': ['JPM', 'BAC'],
      },
      {
        'title': 'Crypto Assets Video Breakdown',
        'summary':
            'Video walkthrough of Bitcoin institutional flows and liquidity cycles.',
        'publisher': 'Market Desk Video',
        'content_type': 'VIDEO',
        'link': 'https://example.com/video/1',
        'published_at': '2026-10-01T09:00:00Z',
        'category': 'Crypto',
        'related_tickers': ['BTC'],
      },
      {
        'title': 'Crypto Assets Show Continued Strength',
        'summary':
            'Bitcoin and Ethereum maintained upward trajectories amid growing institutional adoption.',
        'publisher': 'Digital Asset Daily',
        'link': 'https://example.com/news/4',
        'published_at': '2026-10-01T08:30:00Z',
        'category': 'Crypto',
        'related_tickers': ['BTC', 'ETH'],
      },
    ]),
    'assets/data/screeners.json': jsonEncode({
      'top_gainers': [_sampleInstruments[0], _sampleInstruments[1]],
      'most_active': _sampleInstruments,
    }),
    'assets/data/screeners/top_gainers.json': jsonEncode({
      'results': [_sampleInstruments[0], _sampleInstruments[1]],
    }),
    'assets/data/screeners/aggressive_small_caps.json': jsonEncode({
      'results': [_sampleInstruments[1]],
    }),
    'assets/data/screeners/oversold_stocks_by_rsi.json': jsonEncode({
      'results': [_sampleInstruments[2]],
    }),
    'assets/data/by_topic/crypto.json': jsonEncode([
      {
        'title': 'Crypto Insights',
        'summary': 'Detailed crypto analysis for traders and institutions.',
        'link': 'https://example.com/crypto/1',
        'published_at': '2026-10-01T08:00:00Z',
        'related_tickers': ['BTC'],
      },
    ]),
    'assets/data/by_topic/clean_energy.json': jsonEncode([
      {
        'title': 'Energy Sector Trends',
        'summary': 'Clean energy investment updates.',
        'link': 'https://example.com/energy/1',
        'published_at': '2026-10-01T07:00:00Z',
        'related_tickers': [],
      },
    ]),
    'assets/data/stock_detail/AAPL.json': jsonEncode({
      'ticker': 'AAPL',
      'market': 'US',
      'quote': {
        'ticker': 'AAPL',
        'name': 'Apple Inc.',
        'market': 'US',
        'currency': 'USD',
        'price': 150.0,
        'previous_close': 146.34,
        'change_pct': 2.5,
        'day_high': 151.2,
        'day_low': 147.8,
        'volume': 1000000,
      },
      'summary': {
        'name': 'Apple Inc.',
        'sector': 'Technology',
        'industry': 'Consumer Electronics',
        'market_cap': 2450000000000,
        'pe_ratio': 28.4,
        'forward_pe': 25.1,
        'eps': 5.28,
        'beta': 1.18,
        'dividend_yield': 0.0055,
        'fifty_two_week_high': 199.62,
        'fifty_two_week_low': 124.17,
        'longBusinessSummary':
            'Apple Inc. designs, manufactures, and markets smartphones, personal computers, tablets, wearables, and accessories worldwide.',
      },
      'chart': {'ticker': 'AAPL', 'data': _sampleCandles},
      'recommendations': [
        {
          'period': '0m',
          'strongBuy': 14,
          'buy': 20,
          'hold': 6,
          'sell': 1,
          'strongSell': 0,
        },
      ],
      'holders': {
        'institutional_holders': [
          {
            'Holder': 'Vanguard Group',
            'shares': 120000000,
            'pctHeld': 0.082,
            'value': 18000000000,
          },
        ],
        'mutualfund_holders': [
          {
            'Holder': 'Vanguard 500 Index',
            'shares': 45000000,
            'pctHeld': 0.031,
            'value': 6750000000,
          },
        ],
      },
      'dividends_and_splits': {
        'dividends': [
          {'date': '2026-08-10', 'amount': 0.25},
        ],
        'splits': [
          {'date': '2020-08-31', 'ratio': '4:1'},
        ],
      },
      'options': {
        'chains': {
          '2026-11-20': {
            'calls': [
              {
                'strike': 150.0,
                'lastPrice': 3.4,
                'openInterest': 12500,
                'volume': 1800,
              },
            ],
            'puts': [
              {
                'strike': 145.0,
                'lastPrice': 2.1,
                'openInterest': 9200,
                'volume': 1100,
              },
            ],
          },
        },
      },
    }),
    'assets/data/history/AAPL.json': jsonEncode({
      'ticker': 'AAPL',
      'data': _sampleCandles,
    }),
    'assets/data/history/BTC.json': jsonEncode({
      'ticker': 'BTC',
      'data': [
        for (int i = 0; i < 45; i++)
          {
            'date': DateTime.utc(
              2026,
              8,
              1,
            ).add(Duration(days: i)).toIso8601String(),
            'open': 61000.0 + i * 80.0,
            'high': 62000.0 + i * 80.0,
            'low': 60500.0 + i * 80.0,
            'close': 61500.0 + i * 85.0,
            'volume': 1800000 + i * 10000,
          },
      ],
    }),
    'assets/data/landing_page.json': jsonEncode(
      MockPublicSiteRepository.defaultLanding,
    ),
    'assets/data/pricing_catalogue.json': jsonEncode(
      MockPublicSiteRepository.defaultPricing,
    ),
  };

  @override
  Future<ByteData> load(String key) async {
    final content = _memoryFiles[key];
    if (content != null) {
      final bytes = utf8.encode(content);
      return ByteData.sublistView(Uint8List.fromList(bytes));
    }
    throw FlutterError('Unable to load asset: "$key".');
  }
}

class FixtureSite implements PublicSiteRepository {
  final Map<String, dynamic> page = MockPublicSiteRepository.defaultLanding;
  final Map<String, dynamic> catalogue =
      MockPublicSiteRepository.defaultPricing;

  @override
  Future<PublicSiteContent> landing() async => PublicSiteContent.fromJson(page);

  @override
  Future<Map<String, dynamic>> pricing() async =>
      jsonDecode(jsonEncode(catalogue)) as Map<String, dynamic>;
}

void main() {
  test('public site landing and pricing fixtures parse properly', () async {
    final repo = MockPublicSiteRepository();
    final landing = await repo.landing();
    expect(landing.rows('roles'), hasLength(2));
    final catalogue = PricingCatalogueResponse.fromJson(await repo.pricing());
    expect(catalogue.plans, hasLength(3));
    expect(catalogue.copy, isNotEmpty);
  });
  test('pricing rejects unknown plans and billing cycles', () async {
    final repository = SubscriptionPricingRepositoryImpl(
      content: FixtureSite(),
    );
    await expectLater(
      repository.selectPlan(tierId: 'invalid', billingCycle: 'annual'),
      throwsArgumentError,
    );
    await expectLater(
      repository.selectPlan(tierId: 'tier_free', billingCycle: 'invalid'),
      throwsArgumentError,
    );
  });
  for (final (width, scale) in [
    (320.0, 1.0),
    (320.0, 1.5),
    (360.0, 1.5),
    (390.0, 1.0),
    (768.0, 1.0),
    (1024.0, 1.0),
    (1440.0, 1.0),
  ]) {
    testWidgets('dynamic landing and pricing fit $width px at scale $scale', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = Size(width, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = FixtureSite();
      source.page['title'] = 'Editable Landing Title';
      source.catalogue['plans'][1]['monthly_amount'] = 1234;
      source.catalogue['plans'][1]['annual_monthly_amount'] = 987;
      source.catalogue['copy']['title'] = 'Editable Pricing Title';
      source.page['pricing_title'] = 'Editable Pricing Title';
      await tester.pumpWidget(
        MaterialApp(
          home: GetStartedPage(
            repository: source,
            onGetStarted: (_) {},
            onSignIn: () {},
            onViewFullPricing: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      if (width < 768) {
        expect(find.text('Continue as Trader'), findsOneWidget);
        expect(find.text('Join as Affiliate'), findsOneWidget);
      } else {
        expect(find.text('Editable Landing Title'), findsOneWidget);
        expect(find.text('platform'), findsOneWidget);
        expect(find.text('Editable Pricing Title'), findsNothing);
        await tester.ensureVisible(find.text('pricing').first);
        await tester.tap(find.text('pricing').first);
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Editable Pricing Title'), findsOneWidget);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('₹987'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: SubscriptionPricingPage(
            repository: SubscriptionPricingRepositoryImpl(content: source),
            onContinue: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('₹987'), findsOneWidget);
      await tester.ensureVisible(find.text('Monthly'));
      await tester.tap(find.text('Monthly'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('₹1,234'), findsOneWidget);
      expect(tester.takeException(), isNull);
      var selected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: SubscriptionPricingPage(
            repository: SubscriptionPricingRepositoryImpl(content: source),
            onContinue: () => selected = true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('Current Plan'));
      await tester.tap(find.text('Current Plan'));
      await tester.pump();
      await tester.pump();
      expect(selected, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('community market sidebar opens only the limited preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = AssetMarketRepository(bundle: FileAssets());
    await tester.runAsync(() async {
      await source.communityPreview();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: MarketSidebar(repository: source)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    expect(find.text('Top gainers'), findsOneWidget);
    expect(find.text('Top losers'), findsOneWidget);
    expect(find.text('Latest Market News'), findsNothing);
    final symbol = (await tester.runAsync(
      () => source.communityPreview(),
    ))!.gainers.first.symbol;
    await tester.ensureVisible(find.text(symbol));
    await tester.tap(find.text(symbol));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Community market preview'), findsOneWidget);
    expect(find.byType(UiCandleChart), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
