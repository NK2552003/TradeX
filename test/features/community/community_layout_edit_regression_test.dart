import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_dock/quiet_dock.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart' hide CommunityPostCard;
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_space_history.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/settings/presentation/pages/shared/trader_profile_preview_page.dart';
import 'package:alphajournal/features/community/presentation/views/community_feed_view.dart';
import 'package:alphajournal/features/community/presentation/views/community_post_detail_view.dart';
import 'package:alphajournal/features/community/presentation/community_root_screen.dart';
import 'package:alphajournal/features/community/presentation/views/community_follow_view.dart';
import 'package:alphajournal/features/community/presentation/views/community_hashtag_page.dart';
import 'package:alphajournal/features/community/presentation/views/community_profile_view.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_article_sheet.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_trader_card.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_sidebar_widgets.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_composer_card.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_quote_card.dart';

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
  test('ended spaces retain their history and current host identity', () async {
    final host = repo.suggestedTraders.first;
    repo.currentAuthor = host;
    final room = await repo.createLiveRoom(
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
    final room = await repo.createLiveRoom(
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
    final original = repo.forYouPosts.firstWhere((p) => p.tradeSetup != null);
    final post = CommunityPost(
      id: 'thread-layout-test',
      author: const CommunityAuthor(
        id: 'thread-author',
        handle: 'thread_author',
        displayName: 'Thread Author',
        userRole: UserRole.customer,
      ),
      body: original.body,
      tradeSetup: original.tradeSetup,
      createdAt: original.createdAt,
    );
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
    expect(find.text(post.author.displayName), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 390.0, 1400.0]) {
    testWidgets('public post author actions work at $width px', (tester) async {
      viewport(tester, width);
      final author = CommunityAuthor(
        id: 'another-author',
        handle: 'another_trader',
        displayName: 'Another Trader',
        userRole: UserRole.customer,
        followers: 7,
      );
      final post = CommunityPost(
        id: 'public-author-actions-$width',
        author: author,
        body: 'A public market update.',
        createdAt: DateTime(2026, 10, 26),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityPostDetailView(
            post: post,
            repository: repo,
            currentUser: repo.currentAuthor,
            showHeader: false,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Follow'));
      await tester.pump();
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(repo.followedAuthorIds, contains(author.id));

      await tester.tap(find.text('Message'));
      await tester.pump();
      expect(find.text('Send Message'), findsOneWidget);
      expect(
        tester
            .widget<UiButton>(find.widgetWithText(UiButton, 'Send'))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
  }
  test('initially followed author can be unfollowed', () {
    final author = repo.suggestedTraders.firstWhere((a) => a.isFollowing);
    repo.toggleFollow(author.id);
    expect(repo.followedAuthorIds, isNot(contains(author.id)));
    expect(repo.authorById(author.id)!.isFollowing, isFalse);
  });
  test('activity history belongs to the selected author', () async {
    final author = repo.suggestedTraders.first;
    final history = await repo.fetchUserActivityHistory(author.id);
    expect(history, isNotEmpty);
    expect(history.every((item) => item.post?.author.id == author.id), isTrue);
    expect(await repo.fetchUserActivityHistory('unknown-author'), isEmpty);
  });
  testWidgets('network card with no bio uses its content height', (
    tester,
  ) async {
    viewport(tester, 700);
    const author = CommunityAuthor(
      id: 'no-bio',
      handle: 'nobio',
      displayName: 'No Bio Trader',
      userRole: UserRole.customer,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 320,
              child: CommunityTraderCard(trader: author),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(CommunityTraderCard)).height,
      lessThan(146),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('sidebar trader row opens the selected profile', (tester) async {
    viewport(tester, 700);
    final author = repo.suggestedTraders.first;
    CommunityAuthor? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityWhoToFollowCard(
            traders: [author],
            onFollow: (_) {},
            onAuthorTap: (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.tap(find.text(author.displayName));
    expect(selected?.id, author.id);
  });
  testWidgets('desktop network profile opens in a partial right panel', (
    tester,
  ) async {
    viewport(tester, 1440);
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityRootScreen(
          repository: repo,
          currentTrader: const AppTrader(id: 'viewer', handle: 'viewer'),
          initialTabIndex: 2,
          embedInScaffold: false,
        ),
      ),
    );
    await tester.pump();
    final networkCard = find
        .descendant(
          of: find.byType(CommunityFollowView),
          matching: find.byType(CommunityTraderCard),
        )
        .first;
    await tester.tap(networkCard);
    await tester.pumpAndSettle();
    final panel = find.byKey(
      const ValueKey<String>('settings-side-sheet-surface'),
    );
    expect(panel, findsOneWidget);
    expect(tester.getSize(panel).width, lessThan(1000));
    expect(find.byType(CommunityProfileView), findsOneWidget);
    expect(find.byType(CommunityFollowView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('desktop news opens a partial right panel', (tester) async {
    viewport(tester, 1440);
    final article = CommunityNewsItem(
      id: 'news-panel-test',
      headline: 'Market update for panel testing',
      source: 'alphajournal Wire',
      publishedAt: DateTime(2026, 10, 26),
      summary: 'A public market update.',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UiButton(
            label: 'Read news',
            onPressed: () => CommunityArticleSheet.show(
              tester.element(find.text('Read news')),
              article: article,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Read news'));
    await tester.pumpAndSettle();
    final panel = find.byKey(
      const ValueKey<String>('settings-side-sheet-surface'),
    );
    expect(panel, findsOneWidget);
    expect(tester.getSize(panel).width, lessThan(1000));
    expect(find.byType(CommunityArticleSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty topic does not show unrelated posts or traders', (
    tester,
  ) async {
    viewport(tester, 700);
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityHashtagPage(
          tag: '#topic_with_no_posts',
          repository: repo,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('No posts in this feed yet'), findsOneWidget);
    await tester.tap(find.text('Traders'));
    await tester.pump();
    expect(find.text('No traders for this topic yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('message opens the other author conversation when connected', (
    tester,
  ) async {
    viewport(tester, 1400);
    final author = CommunityAuthor(
      id: 'message-author',
      handle: 'message_trader',
      displayName: 'Message Trader',
      userRole: UserRole.customer,
    );
    AppTrader? recipient;
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPostDetailView(
          post: CommunityPost(
            id: 'public-message-post',
            author: author,
            body: 'A public post.',
            createdAt: DateTime(2026, 10, 26),
          ),
          repository: repo,
          currentUser: repo.currentAuthor,
          onStartDirectMessage: (trader) => recipient = trader,
          showHeader: false,
        ),
      ),
    );
    await tester.tap(find.text('Message'));
    expect(recipient?.id, author.id);
    expect(find.text('Send Message'), findsNothing);
  });
  testWidgets('own public post has no follow or message actions', (
    tester,
  ) async {
    viewport(tester, 1400);
    final author = repo.currentAuthor;
    final post = CommunityPost(
      id: 'own-public-post',
      author: author,
      body: 'My public market update.',
      createdAt: DateTime(2026, 10, 26),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPostDetailView(
          post: post,
          repository: repo,
          currentUser: author,
          showHeader: false,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Follow'), findsNothing);
    expect(find.text('Message'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('post detail shows one primary composer at each screen width', (
    tester,
  ) async {
    viewport(tester, 390);
    final author = repo.currentAuthor;
    final post = CommunityPost(
      id: 'composer-layout',
      author: author,
      body: 'Market update',
      createdAt: DateTime(2026, 10, 26),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPostDetailView(
          post: post,
          repository: repo,
          currentUser: author,
          showHeader: false,
        ),
      ),
    );
    final inline = find.text('Add a comment…');
    final sticky = find.text(
      'Reply to @${author.handle.replaceFirst('@', '')}...',
    );
    for (final width in [390.0, 800.0, 1400.0, 390.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      expect(inline, width == 390 ? findsNothing : findsOneWidget);
      expect(sticky, width == 390 ? findsOneWidget : findsNothing);
      expect(find.text('Trader Discussion'), findsOneWidget);
    }
    await tester.tap(find.byTooltip('Reply').first);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
  });
  testWidgets(
    'own post on mobile does not duplicate author name or show follow card',
    (tester) async {
      viewport(tester, 390);
      final author = CommunityAuthor(
        id: 'me',
        handle: '@nk2552003',
        displayName: 'nk2552003',
        userRole: UserRole.customer,
        followers: 0,
      );
      final post = CommunityPost(
        id: 'own-mobile-post',
        author: author,
        body: 'none of the thing is happening properly fix it',
        createdAt: DateTime(2026, 10, 26),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityPostDetailView(
            post: post,
            repository: repo,
            currentUser: author,
            showHeader: false,
          ),
        ),
      );
      await tester.pump();

      // Author display name should only appear on the post card, not duplicated in a follow card
      expect(find.text('nk2552003'), findsOneWidget);

      // Follow and Win Rate stats cards should not be shown on mobile for author's own post
      expect(find.text('Win Rate'), findsNothing);
      expect(find.text('Followers'), findsNothing);

      // Floating pill header should not be present
      expect(find.text('Post Thread'), findsNothing);

      // Handle should not duplicate @
      expect(find.textContaining('@@'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('desktop view does not render floating pill header Post Thread', (
    tester,
  ) async {
    viewport(tester, 1400);
    final author = CommunityAuthor(
      id: 'any-author',
      handle: 'trader1',
      displayName: 'Trader 1',
      userRole: UserRole.customer,
    );
    final post = CommunityPost(
      id: 'desktop-header-test',
      author: author,
      body: 'Testing desktop header visibility',
      createdAt: DateTime(2026, 10, 26),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPostDetailView(
          post: post,
          repository: repo,
          currentUser: repo.currentAuthor,
          showHeader: true,
        ),
      ),
    );
    await tester.pump();

    // On desktop, the floating header "Post Thread" should be hidden
    expect(find.text('Post Thread'), findsNothing);
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
    testWidgets('community feed tabs fit $width px with Live Spaces disabled', (
      tester,
    ) async {
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
      expect(find.text('Live Spaces'), findsNothing);
      await tester.tap(find.text('Following').first);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'post detail author companion card hides profile icon, name, and handle on mobile and desktop',
    (tester) async {
      for (final width in [390.0, 1400.0]) {
        viewport(tester, width);
        final author = CommunityAuthor(
          id: 'other-author-123',
          handle: 'unique_handle_test',
          displayName: 'Unique Display Name Test',
          userRole: UserRole.customer,
          followers: 42,
          winRate: 68.5,
        );
        final post = CommunityPost(
          id: 'other-author-post-1',
          author: author,
          body: 'Post content here.',
          createdAt: DateTime(2026, 10, 26),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CommunityPostDetailView(
              post: post,
              repository: repo,
              currentUser: repo.currentAuthor,
              showHeader: false,
            ),
          ),
        );
        await tester.pump();

        // Author companion card should NOT display profile icon/avatar or username/handle
        // The author companion card has semanticLabel 'Post author ...'
        final companionCard = find.byWidgetPredicate(
          (w) =>
              w is UiCard &&
              w.semanticLabel == 'Post author Unique Display Name Test',
        );
        expect(companionCard, findsOneWidget);
        expect(
          find.descendant(
            of: companionCard,
            matching: find.text('Unique Display Name Test'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: companionCard,
            matching: find.textContaining('unique_handle_test'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(of: companionCard, matching: find.byType(UiAvatar)),
          findsNothing,
        );

        // But Win Rate, Followers, and action buttons in the companion card are displayed
        expect(
          find.descendant(of: companionCard, matching: find.text('Win Rate')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: companionCard, matching: find.text('68.5%')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: companionCard, matching: find.text('Followers')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: companionCard, matching: find.text('42')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: companionCard, matching: find.text('Follow')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: companionCard, matching: find.text('Message')),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets(
    'mobile post detail reply bar floats above dock when revealed and moves down when dock hides',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppDockVisibility.hidden.value = false;
      addTearDown(() => AppDockVisibility.hidden.value = false);

      final author = CommunityAuthor(
        id: 'dev-admin',
        handle: 'dev_admin',
        displayName: 'Dev Admin',
        userRole: UserRole.userAdmin,
      );
      final longBody = List<String>.filled(
        40,
        'Detailed execution note and risk review paragraph for mobile scroll.',
      ).join('\n\n');
      final post = CommunityPost(
        id: 'floating-reply-mobile-post',
        author: author,
        body: longBody,
        createdAt: DateTime(2026, 11, 21),
      );
      const navItems = <AppNavItem>[
        AppNavItem(
          id: 'community_feed',
          label: 'Feed',
          icon: Icons.dynamic_feed_outlined,
        ),
        AppNavItem(
          id: 'community_explore',
          label: 'Explore',
          icon: Icons.explore_outlined,
        ),
      ];

      await tester.pumpWidget(
        UiApp(
          theme: UiTheme.dark(),
          builder: (_) => MaterialApp(
            home: AppShell(
              sections: const <AppNavSection>[
                AppNavSection(title: 'Community', items: navItems),
              ],
              mobilePrimaryItems: navItems,
              selectedId: 'community_feed',
              onSelect: (_) {},
              child: CommunityPostDetailView(
                post: post,
                repository: repo,
                currentUser: repo.currentAuthor,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder replyBar = find.byKey(
        const ValueKey<String>('community-mobile-floating-reply-bar'),
      );
      final Finder dock = find.byType(QuietDock);
      expect(replyBar, findsOneWidget);
      expect(dock, findsOneWidget);

      // Reply bar is floating inside the Stack, not pinned as Scaffold.bottomNavigationBar.
      final Scaffold detailScaffold = tester.widget<Scaffold>(
        find.descendant(
          of: find.byType(CommunityPostDetailView),
          matching: find.byType(Scaffold),
        ),
      );
      expect(detailScaffold.bottomNavigationBar, isNull);

      // When dock is revealed, reply bar floats cleanly above the dock.
      final Rect dockRect = tester.getRect(dock);
      final Rect revealedReplyRect = tester.getRect(replyBar);
      expect(revealedReplyRect.bottom, lessThan(dockRect.top));

      // Scroll down to hide the dock -> reply bar smoothly moves down toward the bottom.
      await tester.drag(
        find.descendant(
          of: find.byType(CommunityPostDetailView),
          matching: find.byType(SingleChildScrollView),
        ).first,
        const Offset(0, -320),
      );
      await tester.pumpAndSettle();
      expect(AppDockVisibility.hidden.value, isTrue);

      final Rect hiddenReplyRect = tester.getRect(replyBar);
      expect(hiddenReplyRect.bottom, greaterThan(revealedReplyRect.bottom + 30));

      // Scroll up to reveal the dock -> reply bar moves back above the dock.
      await tester.drag(
        find.descendant(
          of: find.byType(CommunityPostDetailView),
          matching: find.byType(SingleChildScrollView),
        ).first,
        const Offset(0, 200),
      );
      await tester.pumpAndSettle();
      expect(AppDockVisibility.hidden.value, isFalse);

      final Rect reRevealedReplyRect = tester.getRect(replyBar);
      expect(reRevealedReplyRect.bottom, lessThan(dockRect.top));
      expect(
        reRevealedReplyRect.bottom,
        closeTo(revealedReplyRect.bottom, 1.0),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CommunityQuoteCard renders attached sub-post concisely on narrow mobile screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final author = CommunityAuthor(
        id: 'quote-author',
        handle: 'very_long_quantitative_trader_handle',
        displayName: 'Quantitative Desk Analyst With Long Name',
        userRole: UserRole.customer,
        tier: AppTier.enterprise,
      );
      final longMarkdown = List<String>.filled(
        12,
        '## Breakout Thesis\n- Entry above **VWAP** with strict risk cap and multi-timeframe confirmation.',
      ).join('\n\n');
      final quotedPost = CommunityPost(
        id: 'quoted-long-post',
        author: author,
        body: longMarkdown,
        createdAt: DateTime(2026, 11, 21),
        tradeSetup: const CommunityTradeSetup(
          ticker: 'NIFTY',
          side: 'Long',
          entry: '24500',
          stopLoss: '24380',
          target: '24800',
          pnl: '+2.4R',
          isWin: true,
        ),
      );

      var tapped = false;
      await tester.pumpWidget(
        UiApp(
          theme: UiTheme.dark(),
          builder: (_) => MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: CommunityQuoteCard(
                  post: quotedPost,
                  onTap: () => tapped = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder card = find.byKey(
        const ValueKey<String>('community-quote-card-quoted-long-post'),
      );
      expect(card, findsOneWidget);
      // Concise sub-post stays compact despite a 12-paragraph markdown source post.
      expect(tester.getSize(card).height, lessThan(130));
      expect(find.text('NIFTY · Long · +2.4R'), findsOneWidget);

      await tester.tap(card);
      await tester.pump();
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
