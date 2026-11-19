import 'dart:io';
import 'package:alphajournal/features/market_data/data/asset_market_repository.dart';
import 'package:alphajournal/features/market_data/models/market_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/notes/data/note_attachments.dart';
import 'package:alphajournal/features/watchlists/data/watchlist_repository.dart';
import 'package:alphajournal/features/watchlists/presentation/watchlists_page.dart';

class WatchlistFixture implements WatchlistRepository {
  final symbols = <String>[];
  @override
  Future<List<AppTicker>> getWatchlistTickers({String? category}) async => [
    for (final symbol in symbols)
      AppTicker(symbol: symbol, name: symbol, price: 125, changePercent: 1),
  ];
  @override
  Future<List<String>> getWatchlists() async => ['Research'];
  @override
  Future<void> addTickerToWatchlist(String watchlistName, String symbol) async {
    symbols.add(symbol);
  }

  @override
  Future<void> createWatchlist(String name) async {}
  @override
  Future<void> removeTickerFromWatchlist(String name, String symbol) async {
    symbols.remove(symbol);
  }

  @override
  Future<void> setPriceAlert({
    required String symbol,
    required double threshold,
    required String direction,
  }) async {}
}

class NewWatchlistFixture extends WatchlistFixture {
  int createCount = 0;
  bool rejectSave = true;
  @override
  Future<List<String>> getWatchlists() async =>
      createCount == 0 ? [] : ['Default Watchlist'];
  @override
  Future<void> createWatchlist(String name) async {
    createCount++;
  }

  @override
  Future<void> addTickerToWatchlist(String watchlistName, String symbol) async {
    if (rejectSave) throw StateError('Save denied');
    if (!symbols.contains(symbol)) symbols.add(symbol);
  }
}

class MarketFixture extends AssetMarketRepository {
  @override
  Future<MarketSnapshot> snapshot({bool refresh = false}) async =>
      MarketSnapshot(
        instruments: [
          MarketInstrument.fromJson(
            {'ticker': 'TEST', 'price': 125.0, 'change_pct': 1},
            {'name': 'Test Company'},
          ),
        ],
        articles: [],
      );
}

void main() {
  test('markdown cannot export an arbitrary local file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'alphajournal-private-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final privateFile = File('${directory.path}/secret.png');
    await privateFile.writeAsBytes([1, 2, 3]);
    expect(await NoteAttachments.bytesFor(Uri.file(privateFile.path)), isNull);
    expect(await NoteAttachments.bytesFor(Uri.parse(privateFile.path)), isNull);
    expect(
      await NoteAttachments.bytesFor(
        Uri.parse('local-image://outside'),
        using: (_) async => privateFile.path,
      ),
      isNull,
    );
  });

  test(
    'only staged repository attachments can be exported, including symlink checks',
    () async {
      final docs = await Directory.systemTemp.createTemp(
        'alphajournal-attachment-test-',
      );
      addTearDown(() => docs.delete(recursive: true));
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'getApplicationDocumentsDirectory'
            ? docs.path
            : null,
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final stage = Directory('${docs.path}/note_attachments');
      await stage.create();
      final safe = File('${stage.path}/chart.png');
      await safe.writeAsBytes([1, 2, 3]);
      final outside = File('${docs.path}/outside.png');
      await outside.writeAsBytes([4, 5, 6]);
      expect(
        await NoteAttachments.bytesFor(
          Uri.parse('local-image://safe-file'),
          using: (_) async => safe.path,
        ),
        [1, 2, 3],
      );
      expect(
        await NoteAttachments.bytesFor(
          Uri.parse('local-image://outside-file'),
          using: (_) async => outside.path,
        ),
        isNull,
      );
      final link = Link('${stage.path}/escape.png');
      await link.create(outside.path);
      expect(
        await NoteAttachments.bytesFor(
          Uri.parse('local-image://symlink-file'),
          using: (_) async => link.path,
        ),
        isNull,
      );
    },
  );

  testWidgets(
    'dropdown icon trigger supports pointer and keyboard activation',
    (tester) async {
      var invoked = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: UiDropdownMenu(
                items: [
                  UiMenuItem(label: 'Run action', onPressed: () => invoked++),
                ],
                child: const UiIconButton(
                  icon: Icons.more_horiz,
                  tooltip: 'Actions',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(UiDropdownMenu));
      await tester.pumpAndSettle();
      expect(find.text('Run action'), findsOneWidget);
      await tester.tap(find.text('Run action'));
      await tester.pumpAndSettle();
      expect(invoked, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Run action'), findsOneWidget);
    },
  );

  testWidgets('dropdown stays inside a narrow viewport above the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: UiDropdownMenu(
              width: 400,
              items: [UiMenuItem(label: 'Visible action', onPressed: () {})],
              child: const UiIconButton(icon: Icons.more_horiz),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(UiDropdownMenu));
    await tester.pumpAndSettle();
    final action = find.text('Visible action');
    expect(action, findsOneWidget);
    final rect = tester.getRect(action);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThan(400));
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(action, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a failed symbol save retains selection and retry does not recreate its new watchlist',
    (tester) async {
      final repository = NewWatchlistFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WatchlistsPage(
              repository: repository,
              marketRepository: MarketFixture(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Symbol'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEST · Test Company'));
      await tester.pump();
      await tester.tap(find.text('Add to watchlist'));
      await tester.pumpAndSettle();
      expect(find.text('Save failed'), findsOneWidget);
      expect(repository.symbols, isEmpty);
      repository.rejectSave = false;
      await tester.ensureVisible(find.text('Add to watchlist'));
      await tester.tap(find.text('Add to watchlist'));
      await tester.pumpAndSettle();
      expect(repository.createCount, 1);
      expect(repository.symbols, ['TEST']);
      await tester.tap(find.byTooltip('Remove TEST from watchlists'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      expect(repository.symbols, isEmpty);
      expect(find.text('Watchlist is empty'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('watchlist Add Symbol opens a real picker at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WatchlistsPage(
              repository: WatchlistFixture(),
              marketRepository: MarketFixture(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Symbol'));
      await tester.pumpAndSettle();
      expect(find.byType(UiDialog), findsOneWidget);
      expect(find.text('Watchlist'), findsOneWidget);
      await tester.tap(find.text('TEST · Test Company'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to watchlist'));
      await tester.pumpAndSettle();
      expect(find.byType(UiDialog), findsNothing);
      expect(find.byType(AppTickerCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
