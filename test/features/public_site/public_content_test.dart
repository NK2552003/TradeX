import 'dart:convert';
import 'dart:io';
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
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());
}

class FixtureSite implements PublicSiteRepository {
  final Map<String, dynamic> page =
      jsonDecode(File('assets/data/landing_page.json').readAsStringSync())
          as Map<String, dynamic>;
  final Map<String, dynamic> catalogue =
      jsonDecode(File('assets/data/pricing_catalogue.json').readAsStringSync())
          as Map<String, dynamic>;
  @override
  Future<PublicSiteContent> landing() async => PublicSiteContent.fromJson(page);
  @override
  Future<Map<String, dynamic>> pricing() async =>
      jsonDecode(jsonEncode(catalogue)) as Map<String, dynamic>;
}

void main() {
  test('assets parse and market data matches exported JSON', () async {
    final source = AssetMarketRepository(bundle: FileAssets());
    final result = await source.snapshot();
    final quotes =
        jsonDecode(File('assets/data/quotes.json').readAsStringSync()) as Map;
    expect(result.instruments.length, quotes.length);
    for (final item in result.instruments) {
      expect(item.price, quotes[item.symbol]['price']);
      final detail = await source.detail(item.symbol);
      expect(detail['ticker'], item.symbol);
      expect((detail['chart'] as Map)['data'], isNotEmpty);
    }
    expect(result.articles, isNotEmpty);
    expect(
      result.articles.map((a) => a.link).toSet().length,
      result.articles.length,
    );
    expect(
      result.articles.first.publishedAt!.isBefore(
        result.articles.last.publishedAt!,
      ),
      isFalse,
    );
    final repo = MockPublicSiteRepository(bundle: FileAssets());
    expect((await repo.landing()).rows('roles'), hasLength(2));
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
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('dynamic landing and pricing fit $width px', (tester) async {
      tester.view.physicalSize = Size(width, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = FixtureSite();
      source.page['title'] = 'Editable Landing Title';
      source.catalogue['plans'][1]['monthly_amount'] = 1234;
      source.catalogue['plans'][1]['annual_monthly_amount'] = 987;
      source.catalogue['copy']['title'] = 'Editable Pricing Title';
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
      expect(find.text('Editable Landing Title'), findsOneWidget);
      expect(find.text('Editable Pricing Title'), findsOneWidget);
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
    expect(find.byType(UiCandleChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
