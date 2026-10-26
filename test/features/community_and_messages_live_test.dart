import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart' hide CommunityPostCard;
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_card.dart';
import 'package:tradex/core/widgets/app_notifications_overlay.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/settings/presentation/pages/shared/trader_profile_preview_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Community & Messages Live Suite', () {
    late CommunityRepository communityRepo;
    late MessagesRepository messagesRepo;

    setUp(() {
      communityRepo = CommunityRepository();
      messagesRepo = MessagesRepository();
    });

    test('1. Create and manage standard, image, setup with chart data, and poll posts', () async {
      const author = CommunityAuthor(
        id: 'usr_test_1',
        handle: 'live_trader',
        displayName: 'Live Trader',
        userRole: UserRole.customer,
      );

      // Simple post
      await communityRepo.createPost(
        body: 'Simple momentum breakout on #NIFTY',
        tickers: ['NIFTY'],
        tags: ['breakout'],
        author: author,
      );
      expect(communityRepo.forYouPosts, isNotEmpty);
      expect(communityRepo.forYouPosts.first.body, contains('breakout on #NIFTY'));

      // Image post
      await communityRepo.createPost(
        body: 'Chart breakout pattern attached',
        imageUrls: ['https://example.com/charts/nifty.png'],
        author: author,
      );
      expect(communityRepo.forYouPosts.first.imageUrls, contains('https://example.com/charts/nifty.png'));

      // Trade setup post with candlestick chart data
      final candleDate = DateTime(2026, 10, 26);
      final candles = [
        UiCandle(time: candleDate, open: 180.0, high: 186.0, low: 179.0, close: 185.5, volume: 10000),
        UiCandle(time: candleDate.add(const Duration(minutes: 15)), open: 185.5, high: 188.0, low: 184.0, close: 187.0, volume: 15000),
      ];

      await communityRepo.createPost(
        body: 'Long setup on AAPL with 15m candle chart',
        tradeSetup: CommunityTradeSetup(
          ticker: 'AAPL',
          side: 'LONG',
          entry: '185.50',
          stopLoss: '180.00',
          target: '195.00',
          candles: candles,
        ),
        author: author,
      );
      expect(communityRepo.forYouPosts.first.tradeSetup?.ticker, equals('AAPL'));
      expect(communityRepo.forYouPosts.first.tradeSetup?.candles.length, equals(2));
      expect(communityRepo.signalPosts, isNotEmpty);

      // Poll post (MCQ)
      final poll = CommunityPoll(
        id: 'poll_test_1',
        question: 'Will BankNifty cross 53,000 this week?',
        options: const [
          CommunityPollOption(id: 'opt_1', text: 'Yes, strong momentum 🚀', votes: 12),
          CommunityPollOption(id: 'opt_2', text: 'No, resistance ahead 📉', votes: 5),
        ],
      );
      await communityRepo.createPost(
        body: 'Weekly bias poll',
        poll: poll,
        author: author,
      );
      final pollPost = communityRepo.forYouPosts.first;
      expect(pollPost.poll?.question, equals('Will BankNifty cross 53,000 this week?'));
      expect(pollPost.poll?.options.length, equals(2));

      // Vote on poll
      communityRepo.votePoll(pollPost.id, 0);
      final votedPost = communityRepo.forYouPosts.firstWhere((p) => p.id == pollPost.id);
      expect(votedPost.poll?.hasVoted, isTrue);
      expect(votedPost.poll?.options.first.votes, equals(13));
    });

    test('2. Social engagement: Likes, Reposts, Bookmarks, and Comments', () async {
      const author = CommunityAuthor(
        id: 'usr_test_author',
        handle: 'alpha_pro',
        displayName: 'Alpha Pro',
        userRole: UserRole.customer,
      );

      await communityRepo.createPost(
        body: 'Key level reclaim at 24,800',
        author: author,
      );
      final targetPost = communityRepo.forYouPosts.first;

      // Like
      expect(targetPost.liked, isFalse);
      communityRepo.toggleLike(targetPost.id);
      final likedPost = communityRepo.forYouPosts.firstWhere((p) => p.id == targetPost.id);
      expect(likedPost.liked, isTrue);
      expect(likedPost.likes, equals(targetPost.likes + 1));

      // Repost
      expect(likedPost.reposted, isFalse);
      communityRepo.toggleRepost(targetPost.id);
      final repostedPost = communityRepo.forYouPosts.firstWhere((p) => p.id == targetPost.id);
      expect(repostedPost.reposted, isTrue);
      expect(repostedPost.reposts, equals(targetPost.reposts + 1));

      // Bookmark
      expect(repostedPost.bookmarked, isFalse);
      communityRepo.toggleBookmark(targetPost.id);
      final bookmarkedPost = communityRepo.forYouPosts.firstWhere((p) => p.id == targetPost.id);
      expect(bookmarkedPost.bookmarked, isTrue);
      expect(communityRepo.bookmarkedPosts.any((p) => p.id == targetPost.id), isTrue);

      // Comment
      await communityRepo.addComment(
        targetPost.id,
        'Great level analysis!',
        author: author,
      );
      final comments = communityRepo.commentsForPost(targetPost.id);
      expect(comments, isNotEmpty);
      expect(comments.first.body, equals('Great level analysis!'));
    });

    test('3. Live trader search in MessagesRepository', () async {
      final traders = await messagesRepo.searchLiveTraders('trader');
      expect(traders, isA<List<AppTrader>>());
    });

    test('4. Fetch Activity History for Instagram-style profile history', () async {
      final history = await communityRepo.fetchUserActivityHistory('usr_test_1');
      expect(history, isA<List<CommunityActivityItem>>());
    });

    testWidgets('5. CommunityPostCard renders all post types and interactions cleanly', (tester) async {
      final post = CommunityPost(
        id: 'post_card_test_1',
        createdAt: DateTime.now(),
        author: const CommunityAuthor(
          id: 'author_1',
          displayName: 'Quant Trader',
          handle: 'quant_pro',
          userRole: UserRole.customer,
          verified: true,
        ),
        body: 'Market thesis on #NIFTY breakout with \$AAPL trade setup',
        tickers: const ['AAPL', 'NIFTY'],
        tags: const ['breakout', 'trading'],
        tradeSetup: const CommunityTradeSetup(
          ticker: 'AAPL',
          side: 'LONG',
          entry: '185.00',
          stopLoss: '180.00',
          target: '195.00',
        ),
        poll: const CommunityPoll(
          id: 'p_1',
          question: 'Are you bullish or bearish?',
          options: [
            CommunityPollOption(id: 'opt1', text: 'Bullish 🚀', votes: 10),
            CommunityPollOption(id: 'opt2', text: 'Bearish 📉', votes: 4),
          ],
        ),
        likes: 42,
        comments: 7,
        reposts: 3,
        views: 890,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommunityPostCard(
                post: post,
                repository: communityRepo,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check author header
      expect(find.text('Quant Trader'), findsOneWidget);
      expect(find.text('@quant_pro'), findsOneWidget);

      // Check body and setup
      expect(find.textContaining('Market thesis'), findsOneWidget);
      expect(find.text('AAPL'), findsOneWidget);
      expect(find.text('LONG'), findsOneWidget);

      // Check poll
      expect(find.text('Are you bullish or bearish?'), findsOneWidget);
      expect(find.text('Bullish 🚀'), findsOneWidget);

      // Check engagement
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('6. TraderProfilePreviewPage renders Trader Profile when viewing admin or affiliate', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: TraderProfilePreviewPage(
              displayName: 'Admin Trader',
              handle: 'super_admin',
              userRole: UserRole.userAdmin,
              isCurrentUser: false, // Viewer is another user
              forceTraderView: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show Trader Profile tabs, NOT internal Admin Command Center
      expect(find.text('Command Center'), findsNothing);
      expect(find.text('Posts'), findsOneWidget);
      expect(find.text('Journal'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
    });

    testWidgets('7. AppNotificationsOverlay renders live notification items, filters, and follow back actions', (tester) async {
      final now = DateTime.now();
      final notifications = [
        CommunityNotificationItem(
          id: 'notif_sec_1',
          type: CommunityNotificationType.security,
          createdAt: now.subtract(const Duration(minutes: 1)),
          title: 'Security Alert',
          body: "Someone's trying to log into TradeX. Let us know if it's you.",
          read: false,
        ),
        CommunityNotificationItem(
          id: 'notif_follow_1',
          actor: const CommunityAuthor(
            id: 'actor_prerna',
            displayName: 'Prerna Foundation',
            handle: 'prern_afoundation',
            userRole: UserRole.customer,
          ),
          type: CommunityNotificationType.follow,
          createdAt: now.subtract(const Duration(days: 6)),
          title: 'New Follower',
          body: 'prern_afoundation started following you.',
          isFollowingBack: false,
          read: false,
        ),
        CommunityNotificationItem(
          id: 'notif_like_1',
          actor: const CommunityAuthor(
            id: 'actor_x8n',
            displayName: 'x8n.03',
            handle: 'x8n.03',
            userRole: UserRole.customer,
          ),
          type: CommunityNotificationType.like,
          createdAt: now.subtract(const Duration(days: 12)),
          title: 'New Like',
          body: 'x8n.03 and 12 others liked your comment.',
          postSnippet: 'Got mine just for 800 rs.',
          postId: 'post_1',
          read: true,
        ),
      ];

      // Inject notifications
      communityRepo.setNotificationsForTesting(notifications);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: AppNotificationsOverlay(
              repository: communityRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Header
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Mark all read'), findsOneWidget);

      // Check Filter Chips (All, People you follow, Comments, Follows, System)
      expect(find.text('All'), findsOneWidget);
      expect(find.text('People you follow'), findsOneWidget);
      expect(find.text('Comments'), findsOneWidget);
      expect(find.text('Follows'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);

      // Check Time Groupings
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('This month'), findsOneWidget);

      // Check Security Notification matching screenshot
      expect(find.textContaining("Someone's trying to log into TradeX"), findsOneWidget);

      // Check Follow Notification with "Follow Back" button
      expect(find.text('Follow Back'), findsOneWidget);

      // Tap "Follow Back" and verify it toggles to "Following"
      await tester.tap(find.text('Follow Back'));
      await tester.pumpAndSettle();
      expect(find.text('Following'), findsOneWidget);

      // Test Live Notification Callback
      CommunityNotificationItem? received;
      communityRepo.onLiveNotificationReceived = (item) => received = item;
      communityRepo.onLiveNotificationReceived?.call(notifications.first);
      expect(received?.id, equals('notif_sec_1'));
    });
  });
}
