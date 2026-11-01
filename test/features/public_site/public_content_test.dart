import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/data/repositories/subscription_pricing_repository.dart';
import 'package:tradex/features/auth/models/pricing_models.dart';
import 'package:tradex/features/auth/presentation/pages/get_started_page.dart';
import 'package:tradex/features/auth/presentation/pages/subscription_pricing_page.dart';
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/presentation/market_sidebar.dart';
import 'package:tradex/features/public_site/data/public_site_repository.dart';
import 'package:tradex/features/public_site/models/public_site_content.dart';

class FileAssets extends CachingAssetBundle {
  static final Map<String, String> _memoryFiles = {
    'assets/data/manifest.json': jsonEncode({
      'generated_at': '2026-10-01T00:00:00Z',
      'files': [
        'quotes.json',
        'fundamentals.json',
        'all_news.json',
        'screeners.json',
      ],
    }),
    'assets/data/quotes.json': jsonEncode({
      'AAPL': {
        'ticker': 'AAPL',
        'price': 150.0,
        'change_pct': 2.5,
        'market': 'US',
        'name': 'Apple Inc.',
        'volume': 1000000,
      },
      'MSFT': {
        'ticker': 'MSFT',
        'price': 300.0,
        'change_pct': -1.2,
        'market': 'US',
        'name': 'Microsoft Corp.',
        'volume': 800000,
      },
      'GOOGL': {
        'ticker': 'GOOGL',
        'price': 2800.0,
        'change_pct': 1.1,
        'market': 'US',
        'name': 'Alphabet Inc.',
        'volume': 500000,
      },
      'BTC': {
        'ticker': 'BTC',
        'price': 65000.0,
        'change_pct': 3.2,
        'market': 'CRYPTO',
        'name': 'Bitcoin',
        'volume': 2000000,
      },
      'ETH': {
        'ticker': 'ETH',
        'price': 3500.0,
        'change_pct': -0.5,
        'market': 'CRYPTO',
        'name': 'Ethereum',
        'volume': 1200000,
      },
    }),
    'assets/data/fundamentals.json': jsonEncode({
      'AAPL': {'name': 'Apple Inc.', 'sector': 'Technology'},
      'MSFT': {'name': 'Microsoft Corp.', 'sector': 'Technology'},
      'GOOGL': {'name': 'Alphabet Inc.', 'sector': 'Technology'},
    }),
    'assets/data/all_news.json': jsonEncode([
      {
        'title': 'Tech Sector Rallies as Markets Open Higher',
        'summary':
            'Major technology stocks posted strong gains on robust earnings reports and easing inflation signals.',
        'link': 'https://example.com/news/1',
        'published_at': '2026-10-01T12:00:00Z',
        'category': 'Markets',
        'tickers': ['AAPL', 'MSFT'],
      },
      {
        'title': 'Crypto Assets Show Continued Strength',
        'summary':
            'Bitcoin and Ethereum maintained upward trajectories amid growing institutional adoption.',
        'link': 'https://example.com/news/2',
        'published_at': '2026-10-01T10:00:00Z',
        'category': 'Crypto',
        'tickers': ['BTC', 'ETH'],
      },
    ]),
    'assets/data/screeners.json': jsonEncode({
      'top_gainers': [
        {
          'ticker': 'AAPL',
          'price': 150.0,
          'change_pct': 2.5,
          'market': 'US',
          'name': 'Apple Inc.',
          'volume': 1000000,
        },
        {
          'ticker': 'BTC',
          'price': 65000.0,
          'change_pct': 3.2,
          'market': 'CRYPTO',
          'name': 'Bitcoin',
          'volume': 2000000,
        },
      ],
      'most_active': [
        {
          'ticker': 'AAPL',
          'price': 150.0,
          'change_pct': 2.5,
          'market': 'US',
          'name': 'Apple Inc.',
          'volume': 1000000,
        },
      ],
    }),
    'assets/data/screeners/top_gainers.json': jsonEncode({
      'results': [
        {
          'ticker': 'AAPL',
          'price': 150.0,
          'change_pct': 2.5,
          'market': 'US',
          'name': 'Apple Inc.',
          'volume': 1000000,
        },
      ],
    }),
    'assets/data/screeners/aggressive_small_caps.json': jsonEncode({
      'results': [
        {
          'ticker': 'AAPL',
          'price': 150.0,
          'change_pct': 2.5,
          'market': 'US',
          'name': 'Apple Inc.',
          'volume': 1000000,
        },
      ],
    }),
    'assets/data/screeners/oversold_stocks_by_rsi.json': jsonEncode({
      'results': [
        {
          'ticker': 'MSFT',
          'price': 300.0,
          'change_pct': -1.2,
          'market': 'US',
          'name': 'Microsoft Corp.',
          'volume': 800000,
        },
      ],
    }),
    'assets/data/by_topic/crypto.json': jsonEncode([
      {
        'title': 'Crypto Insights',
        'summary': 'Detailed crypto analysis for traders and institutions.',
        'link': 'https://example.com/crypto/1',
        'published_at': '2026-10-01T08:00:00Z',
        'tickers': ['BTC'],
      },
    ]),
    'assets/data/by_topic/clean_energy.json': jsonEncode([
      {
        'title': 'Energy Sector Trends',
        'summary': 'Clean energy investment updates.',
        'link': 'https://example.com/energy/1',
        'published_at': '2026-10-01T07:00:00Z',
        'tickers': [],
      },
    ]),
    'assets/data/stock_detail/AAPL.json': jsonEncode({
      'ticker': 'AAPL',
      'name': 'Apple Inc.',
      'chart': {
        'data': [
          {
            'date': '2026-09-01T09:30:00Z',
            'open': 146.0,
            'high': 149.0,
            'low': 145.0,
            'close': 148.0,
            'volume': 500000,
          },
          {
            'date': '2026-09-02T09:30:00Z',
            'open': 148.0,
            'high': 151.0,
            'low': 147.0,
            'close': 150.0,
            'volume': 600000,
          },
        ],
      },
    }),
    'assets/data/history/AAPL.json': jsonEncode({
      'ticker': 'AAPL',
      'data': [
        {
          'date': '2026-09-01T09:30:00Z',
          'open': 146.0,
          'high': 149.0,
          'low': 145.0,
          'close': 148.0,
          'volume': 500000,
        },
        {
          'date': '2026-09-02T09:30:00Z',
          'open': 148.0,
          'high': 151.0,
          'low': 147.0,
          'close': 150.0,
          'volume': 600000,
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
    return ByteData(0);
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
  testWidgets('market sidebar reads asset tickers and opens full chart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = AssetMarketRepository(bundle: FileAssets());
    await tester.runAsync(() async {
      await source.snapshot();
      await source.detail((await source.snapshot()).gainers.first.symbol);
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
      () => source.snapshot(),
    ))!.gainers.first.symbol;
    await tester.ensureVisible(find.text(symbol));
    await tester.tap(find.text(symbol));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final detail = await tester.runAsync(() => source.detail(symbol));
    final hasHistory = ((detail!['chart'] as Map)['data'] as List).isNotEmpty;
    expect(
      find.byType(UiCandleChart),
      hasHistory ? findsOneWidget : findsNothing,
    );
    if (!hasHistory) {
      expect(find.text('No price history in this snapshot'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
