// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/market_data/models/market_snapshot.dart';
import 'package:alphajournal/features/market_data/presentation/market_instrument_contact.dart';
import 'package:alphajournal/features/market_data/presentation/market_instrument_data.dart';
import 'package:alphajournal/features/market_data/presentation/market_instrument_fundamentals.dart';
import 'package:alphajournal/features/market_data/presentation/market_instrument_ownership.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _RecordingLauncher extends UrlLauncherPlatform {
  Uri? opened;

  @override
  get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened = Uri.parse(url);
    return true;
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  InstrumentDetailData instrument(InstrumentRow details) =>
      InstrumentDetailData(
        MarketInstrument.fromJson({
          'ticker': 'TEST',
          'price': 20,
          'currency': 'USD',
        }, {}),
        details,
      );

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    required double width,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (width, columns) in [(320.0, 1), (820.0, 2), (1150.0, 3)]) {
    testWidgets('holder cards align within every row at $width', (
      tester,
    ) async {
      const names = [
        'BlackRock Inc.',
        'State Street Corporation and Affiliated Investment Management Funds',
        'Vanguard Capital Management, LLC',
        'Geode Capital Management, LLC',
        'Susquehanna International Group, LLP',
        'Vanguard Portfolio Management LLC',
      ];
      await mount(
        tester,
        InstrumentOwnership(
          data: instrument({
            'holders': {
              'institutional_holders': [
                for (final (index, name) in names.indexed)
                  {
                    'Holder': name,
                    'pctHeld': (6 - index) / 100,
                    'Shares': 210000,
                    'Value': 4200000,
                    'Date Reported': '2026-09-30',
                  },
              ],
            },
          }),
        ),
        width: width,
      );
      final cards = [
        for (final name in names)
          tester.getRect(
            find.byWidgetPredicate(
              (widget) => widget is UiCard && widget.title == name,
            ),
          ),
      ];
      for (var start = 0; start < cards.length; start += columns) {
        for (final adjacent in cards.skip(start + 1).take(columns - 1)) {
          expect(adjacent.top, closeTo(cards[start].top, 0.1));
          expect(adjacent.bottom, closeTo(cards[start].bottom, 0.1));
          expect(adjacent.width, closeTo(cards[start].width, 0.1));
        }
        if (start > 0) {
          expect(cards[start].top, greaterThan(cards[start - 1].bottom));
        }
      }
      final marketValues = find.text('USD 4.2M');
      expect(marketValues, findsNWidgets(names.length));
      for (final value in tester.renderObjectList<RenderParagraph>(
        marketValues,
      )) {
        expect(value.didExceedMaxLines, isFalse);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'fundamental previews format the values and launch contact actions',
    (tester) async {
      final launcher = _RecordingLauncher();
      final previous = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = previous);
      await mount(
        tester,
        InstrumentFundamentals(
          data: instrument({
            'summary': {
              'website': 'https://company.example/investors',
              'phone': '+1 (212) 555-0100',
              'total_cash': 134711008,
              'free_cashflow': -14919625,
              'target_mean_price': 32.5,
              'recommendation': 'strong_buy',
              'held_percent_institutions': 0.34919,
              'updated_at': '2026-11-18T01:07:36.686299+00:00',
            },
          }),
        ),
        width: 320,
      );
      for (final value in [
        'company.example',
        'USD 134.7M',
        'USD -14.9M',
        'USD 32.50',
        'Strong buy',
        '34.92%',
        '2026-11-18',
      ]) {
        expect(find.text(value), findsOneWidget, reason: value);
      }
      await tester.tap(find.text('Call company'));
      expect(launcher.opened.toString(), 'tel:+12125550100');
      await tester.tap(find.text('Open website'));
      expect(launcher.opened.toString(), 'https://company.example/investors');
      expect(tester.takeException(), isNull);
    },
  );

  for (final found in [true, false]) {
    testWidgets(
      'map preview ${found ? 'places a pin' : 'keeps the address link when lookup fails'}',
      (tester) async {
        final address = found ? '7 Times Square' : '123 Missing Address';
        var lookups = 0;
        await http.runWithClient(
          () async {
            await mount(
              tester,
              InstrumentContact(
                summary: {
                  'address': address,
                  'city': 'New York',
                  'country': 'United States',
                },
              ),
              width: 320,
            );
            expect(lookups, 0);
            await tester.tap(find.text('Preview map'));
            await tester.pumpAndSettle();
            expect(lookups, 1);
            expect(find.text('Open in OpenStreetMap'), findsOneWidget);
            if (found) {
              final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
              expect(map.options.initialCenter.latitude, 40.7555);
              expect(map.options.initialCenter.longitude, -73.9869);
              expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
            } else {
              expect(find.byType(FlutterMap), findsNothing);
              expect(find.text('Map preview unavailable'), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
          () => MockClient((request) async {
            if (request.url.host == 'tile.openstreetmap.org') {
              final tile = base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a8ZkAAAAASUVORK5CYII=',
              );
              return http.Response.bytes(
                tile,
                200,
                headers: {'content-type': 'image/png'},
              );
            }
            expect(
              request.url.queryParameters['q'],
              '$address, New York, United States',
            );
            lookups++;
            return found
                ? http.Response(
                    '''{"features":[{"geometry":{"type":"Point","coordinates":[-73.9869,40.7555]},"properties":{"type":"house","name":"Times Square Tower"}}]}''',
                    200,
                  )
                : http.Response('{}', 503);
          }),
        );
      },
    );
  }
}
