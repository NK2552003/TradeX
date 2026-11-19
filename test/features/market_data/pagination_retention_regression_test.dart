import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/market_data/models/market_snapshot.dart';
import 'package:alphajournal/features/market_data/presentation/market_news_widgets.dart';
import 'package:alphajournal/features/market_data/presentation/market_catalogue_view.dart';

List<MarketArticle> articles(int count) => List.generate(
  count,
  (i) => MarketArticle.fromJson({
    'title': 'News story $i',
    'summary': 'Market news $i',
    'publisher': 'News',
    'link': 'https://example.com/$i',
  }),
);

void main() {
  void viewport(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Finder pageText(String label) => find.descendant(
    of: find.byType(UiPagination),
    matching: find.text(label),
  );

  for (final width in [320.0, 1440.0]) {
    for (final useNext in [false, true]) {
      testWidgets(
        'news retains last page after loading more at $width using ${useNext ? 'Next' : 'number'}',
        (tester) async {
          viewport(tester, width);
          var rows = articles(25);
          var loads = 0;
          late StateSetter update;
          var query = '';
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      update = setState;
                      return MarketNewsView(
                        snapshot: MarketSnapshot(
                          instruments: const [],
                          articles: rows,
                        ),
                        searchQuery: query,
                        onArticle: (_) {},
                        onMore: () {
                          loads++;
                          setState(() => rows = articles(45));
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (useNext) {
            for (var i = 0; i < 2; i++) {
              final next = find.descendant(
                of: find.byType(UiPagination),
                matching: find.byTooltip('Next'),
              );
              await tester.ensureVisible(next);
              await tester.tap(next);
              await tester.pumpAndSettle();
            }
          } else {
            await tester.ensureVisible(pageText('3'));
            await tester.tap(pageText('3'));
            await tester.pumpAndSettle();
          }
          expect(loads, 1);
          expect(
            tester.widget<UiPagination>(find.byType(UiPagination)).page,
            2,
          );
          expect(
            find.text('Showing 21–30 of 45 stories · Page 3 of 5'),
            findsOneWidget,
          );
          update(() => rows = articles(45).reversed.toList());
          await tester.pumpAndSettle();
          expect(
            tester.widget<UiPagination>(find.byType(UiPagination)).page,
            2,
          );
          update(() => query = 'News');
          await tester.pumpAndSettle();
          expect(
            tester.widget<UiPagination>(find.byType(UiPagination)).page,
            0,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'shared table preserves page when rows grow and clamps when they shrink',
    (tester) async {
      var rows = List.generate(30, (i) => i);
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return UiTable<int>(
                    rows: rows,
                    pageSize: 10,
                    columns: [
                      UiTableColumn(
                        header: 'Value',
                        cell: (_, row) => Text('Row $row'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pump();
      }
      expect(find.text('Page 3 of 3'), findsOneWidget);
      update(() => rows = List.generate(40, (i) => i));
      await tester.pump();
      expect(find.text('Page 3 of 4'), findsOneWidget);
      expect(find.text('Row 20'), findsOneWidget);
      update(() => rows = List.generate(15, (i) => i));
      await tester.pump();
      expect(find.text('Page 2 of 2'), findsOneWidget);
      expect(find.text('Row 10'), findsOneWidget);
      update(() => rows = List.generate(40, (i) => i));
      await tester.pump();
      expect(find.text('Page 2 of 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile quotes retain page when more quotes arrive', (
    tester,
  ) async {
    viewport(tester, 390);
    List<MarketInstrument> quotes(int n) => List.generate(
      n,
      (i) => MarketInstrument.fromJson({
        'ticker': 'SYM$i',
        'name': 'Instrument $i',
        'price': 100.0,
        'market': 'US',
        'currency': 'USD',
      }, const {}),
    );
    var rows = quotes(45);
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return MarketQuoteResults(quotes: rows, onInstrument: (_) {});
              },
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(pageText('3'));
    await tester.tap(pageText('3'));
    await tester.pump();
    update(() => rows = quotes(65));
    await tester.pump();
    expect(tester.widget<UiPagination>(find.byType(UiPagination)).page, 2);
    expect(find.text('SYM40'), findsOneWidget);
    update(() => rows = quotes(25));
    await tester.pump();
    expect(tester.widget<UiPagination>(find.byType(UiPagination)).page, 1);
    expect(tester.takeException(), isNull);
  });
}
