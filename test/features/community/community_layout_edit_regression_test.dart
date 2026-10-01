import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart' hide CommunityPostCard;
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_space_history.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/settings/presentation/pages/shared/trader_profile_preview_page.dart';
import 'package:tradex/features/community/presentation/views/community_feed_view.dart';
import 'package:tradex/features/community/presentation/views/community_post_detail_view.dart';
import 'package:tradex/features/community/presentation/widgets/community_composer_card.dart';

void main() {
  late CommunityRepository repo;
  setUp(() => repo = CommunityRepository());
  tearDown(() => repo.dispose());
  void viewport(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('editing setup preserves its candle chart and result', (
    tester,
  ) async {
    viewport(tester, 1200);
    final post = repo.forYouPosts.firstWhere(
      (p) => p.tradeSetup?.candles.isNotEmpty ?? false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CommunityComposerCard(
              author: post.author,
              repository: repo,
              postToEdit: post,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pump(const Duration(milliseconds: 300));
    final edited = repo.loadPostById(post.id)!;
    expect(
      edited.tradeSetup!.candles
          .map((c) => [c.time, c.open, c.high, c.low, c.close, c.volume])
          .toList(),
      post.tradeSetup!.candles
          .map((c) => [c.time, c.open, c.high, c.low, c.close, c.volume])
          .toList(),
    );
    expect(edited.tradeSetup!.rMultiple, post.tradeSetup!.rMultiple);
    expect(edited.tradeSetup!.pnl, post.tradeSetup!.pnl);
  });
  testWidgets('setup editor saves chart input and rejects malformed OHLC', (
    tester,
  ) async {
    viewport(tester, 1200);
    final post = repo.forYouPosts.firstWhere((p) => p.tradeSetup != null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CommunityComposerCard(
              author: post.author,
              repository: repo,
              postToEdit: post,
            ),
          ),
        ),
      ),
    );
    final input = find.descendant(
      of: find.byKey(const ValueKey<String>('setup-candles-input')),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(input);
    await tester.enterText(
      input,
      '[{"time":"2026-09-30T09:15:00+05:30","open":100,"high":105,"low":99,"close":103,"volume":1200}]',
    );
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pump(const Duration(milliseconds: 200));
    final saved = repo.loadPostById(post.id)!;
    expect(saved.tradeSetup!.candles, hasLength(1));
    expect(saved.tradeSetup!.candles.single.close, 103);
    await tester.ensureVisible(input);
    await tester.enterText(
      input,
      '[{"time":"2026-09-30T09:15:00+05:30","open":100,"high":90,"low":99,"close":103}]',
    );
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    expect(repo.loadPostById(post.id)!.tradeSetup!.candles.single.close, 103);
    expect(
      find.textContaining('High and low must contain open and close'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  test('ended spaces retain their history and current host identity', () {
    final host = repo.suggestedTraders.first;
    repo.currentAuthor = host;
    final room = repo.createLiveRoom(
      title: 'History session',
      topic: 'Review',
      category: 'Equities',
    );
    expect(room.host.id, host.id);
    repo.endLiveRoom(room.id);
    final completed = repo.allLiveRooms.firstWhere(
      (item) => item.id == room.id,
    );
    expect(completed.status, LiveRoomStatus.ended);
    expect(completed.endedAt, isNotNull);
    expect(repo.isTunedIntoLiveRoom, isFalse);
    expect(repo.liveRooms.any((item) => item.id == room.id), isFalse);
  });
  testWidgets('profile history contains only that host and updates on ending', (
    tester,
  ) async {
    viewport(tester, 390);
    final room = repo.createLiveRoom(
      title: 'My completed session',
      topic: 'Review',
      category: 'Equities',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CommunitySpaceHistory(
              handle: repo.currentAuthor.handle,
              authorId: repo.currentAuthor.id,
              repository: repo,
            ),
          ),
        ),
      ),
    );
    expect(find.text(room.title), findsOneWidget);
    expect(find.text(repo.liveRooms.last.title), findsNothing);
    repo.endLiveRoom(room.id);
    await tester.pump();
    expect(find.text('ENDED'), findsOneWidget);
    expect(find.text('Tune In'), findsNothing);
  });
  testWidgets('post thread has one setup presentation', (tester) async {
    viewport(tester, 1400);
    final post = repo.forYouPosts.firstWhere((p) => p.tradeSetup != null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityPostDetailView(
            post: post,
            repository: repo,
            currentUser: repo.currentAuthor,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(UiCandleChart), findsOneWidget);
    expect(find.text('Setup Blueprint'), findsOneWidget);
    expect(tester.getCenter(find.byType(UiCandleChart)).dx, greaterThan(900));
    expect(
      tester.getCenter(find.text(post.author.displayName)).dx,
      greaterThan(900),
    );
    expect(find.text(post.author.displayName), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final role in UserRole.values) {
    testWidgets('profile has spaces history for ${role.name}', (tester) async {
      viewport(tester, 1200);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TraderProfilePreviewPage(
              displayName: repo.currentAuthor.displayName,
              handle: repo.currentAuthor.handle,
              userRole: role,
              repository: repo,
              author: repo.currentAuthor,
            ),
          ),
        ),
      );
      final tabs = tester.widgetList<UiTabs>(find.byType(UiTabs));
      expect(
        tabs.any(
          (tabs) => tabs.items.any((item) => item.label == 'Spaces History'),
        ),
        isTrue,
      );
    });
  }
  for (final width in [320.0, 390.0]) {
    testWidgets('mobile setup editor fits $width px', (tester) async {
      viewport(tester, width);
      final post = repo.forYouPosts.firstWhere((p) => p.tradeSetup != null);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommunityComposerCard(
                author: post.author,
                repository: repo,
                postToEdit: post,
                isDrawerTile: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [320.0, 390.0]) {
    testWidgets('live space cards fit $width px', (tester) async {
      viewport(tester, width);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityFeedView(
              repository: repo,
              currentUser: repo.currentAuthor,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Live Spaces').first);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      await tester.dragFrom(Offset(width / 2, 700), const Offset(0, -550));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  }
}
