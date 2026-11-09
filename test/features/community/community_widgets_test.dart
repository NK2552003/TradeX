import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/core/app-ui/app_ui.dart' hide CommunityPostCard;
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/views/community_hashtag_page.dart';
import 'package:tradex/features/community/presentation/views/community_inbox_view.dart';
import 'package:tradex/features/community/presentation/views/community_moderation_list_page.dart';
import 'package:tradex/features/community/presentation/views/community_notification_settings_page.dart';
import 'package:tradex/features/community/presentation/views/community_search_page.dart';
import 'package:tradex/features/community/presentation/widgets/community_widgets.dart';

void main() {
  group('CommunityAttachmentTile Tests', () {
    testWidgets('renders Note attachment correctly', (
      WidgetTester tester,
    ) async {
      final now = DateTime.now().subtract(const Duration(hours: 2));
      final note = AppNote(
        id: 'note-101',
        title: 'Q3 Liquidity & Gamma Exposure Thesis',
        content:
            'Fed balance sheet runoff is slowing down while Treasury general account balances stabilise.',
        createdAt: now,
        updatedAt: now,
        isPublic: true,
        tags: const <String>['macro', 'liquidity'],
        noteType: AppNoteType.analysis,
        linkedTickers: const <String>['SPY'],
      );
      final attachment = AppWritingPostAttachment.note(note);

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityAttachmentTile(
              attachment: attachment,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Q3 Liquidity & Gamma Exposure Thesis'), findsOneWidget);
      expect(find.text('Analysis'), findsOneWidget);
      expect(find.textContaining('Fed balance sheet runoff'), findsOneWidget);
      expect(find.text('\$SPY'), findsOneWidget);
      expect(find.text('Public'), findsOneWidget);

      await tester.tap(find.byType(CommunityAttachmentTile));
      expect(tapped, isTrue);
    });

    testWidgets('renders Trade Journal attachment correctly', (
      WidgetTester tester,
    ) async {
      final now = DateTime.now().subtract(const Duration(minutes: 45));
      final trade = AppTrade(
        id: 'journal-202',
        ticker: 'NVDA',
        side: AppSide.long,
        entry: 128.5,
        exit: 134.2,
        openedAt: now,
        closedAt: now,
        outcome: AppOutcome.win,
        title: 'Long Breakout - Asian Session Range High',
        content: 'Patient execution at key level.',
        isPublic: true,
      );
      final attachment = AppWritingPostAttachment.journal(trade);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommunityAttachmentTile(attachment: attachment)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Long Breakout - Asian Session Range High'),
        findsOneWidget,
      );
      expect(find.text('\$NVDA'), findsOneWidget);
      expect(find.text('Closed trade'), findsOneWidget);
    });

    testWidgets('renders Strategy attachment correctly', (
      WidgetTester tester,
    ) async {
      final now = DateTime.now().subtract(const Duration(days: 1));
      final strategy = AppStrategy(
        id: 'strategy-303',
        name: 'Opening Range Breakout (ORB-15)',
        summary: 'Algorithmic intraday momentum playbook',
        content: 'Rules for trading the first 15m breakout.',
        updatedAt: now,
        isPublic: true,
        tags: const <String>['orb', 'momentum'],
        linkedTickers: const <String>['QQQ'],
      );
      final attachment = AppWritingPostAttachment.strategy(strategy);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommunityAttachmentTile(attachment: attachment)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Opening Range Breakout (ORB-15)'), findsOneWidget);
      expect(find.text('\$QQQ'), findsOneWidget);
    });
  });

  group('Community post attachment linking', () {
    testWidgets('opens the attached record source instead of the post', (
      WidgetTester tester,
    ) async {
      final now = DateTime.now();
      final attachment = AppWritingPostAttachment.note(
        await NotesRepositoryScope.repository.create(
          AppNote(
            id: 'linked-note-42',
            title: 'Risk plan',
            content: 'Reduce exposure into the event.',
            createdAt: now,
            updatedAt: now,
            isPublic: true,
          ),
        ),
      );
      const author = CommunityAuthor(
        id: 'author-link',
        displayName: 'Link Tester',
        handle: 'link_tester',
        userRole: UserRole.customer,
      );
      final post = CommunityPost(
        id: 'post-link-42',
        author: author,
        body: 'Attached my risk plan.',
        createdAt: now,
        attachment: attachment,
      );
      AppLinkRef? opened;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityPostCard(
              post: post,
              onOpenRef: (AppLinkRef ref) => opened = ref,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CommunityAttachmentTile));

      expect(opened, isNotNull);
      expect(opened!.id, 'linked-note-42');
      expect(opened!.kind, AppLinkKind.note);
    });
  });

  group('CommunityCommentCard Tests', () {
    testWidgets('renders author, body with highlight, and like counter', (
      WidgetTester tester,
    ) async {
      const author = CommunityAuthor(
        id: 'author-1',
        displayName: 'Sarah Connor',
        handle: 'sarah_c',
        verified: true,
        userRole: UserRole.customer,
      );

      final comment = CommunityComment(
        id: 'c-1',
        postId: 'p-1',
        author: author,
        body: 'Great risk management on \$TSLA setup #breakout',
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        likes: 5,
        liked: true,
      );

      bool liked = false;
      bool replied = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityCommentCard(
              comment: comment,
              onLike: () => liked = true,
              onReply: () => replied = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sarah Connor'), findsOneWidget);
      expect(find.text('@sarah_c'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Reply'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_rounded));
      expect(liked, isTrue);

      await tester.tap(find.text('Reply'));
      expect(replied, isTrue);
    });
  });

  group('CommunityTraderCard & Row Tests', () {
    const trader = CommunityAuthor(
      id: 'trader-1',
      displayName: 'Alex Mercer',
      handle: 'alex_m',
      verified: true,
      userRole: UserRole.customer,
      bio:
          'Quantitative trader focusing on mean reversion and volatility arbitrage.',
      followers: 12400,
      following: 380,
      winRate: 72.5,
    );

    testWidgets('CommunityTraderCard renders on desktop', (
      WidgetTester tester,
    ) async {
      bool followed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityTraderCard(
              trader: trader,
              onFollow: () => followed = true,
              showWinRate: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alex Mercer'), findsOneWidget);
      expect(find.text('@alex_m'), findsOneWidget);
      expect(find.byType(UiIconButton), findsOneWidget);
      expect(find.text('73% Win Rate'), findsOneWidget);
      expect(find.textContaining('12.4K Followers'), findsOneWidget);

      await tester.tap(find.byType(UiIconButton));
      expect(followed, isTrue);
    });

    testWidgets('CommunityTraderRow renders in leaderboard mode with rank', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommunityTraderRow(trader: trader, rank: 1, winRate: 72.5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('#1'), findsOneWidget);
      expect(find.text('Alex Mercer'), findsOneWidget);
      expect(find.text('72.5% Win'), findsOneWidget);
    });
  });

  group('CommunityPostGrid Responsive Tests', () {
    const author = CommunityAuthor(
      id: 'author-test',
      displayName: 'Tester',
      handle: 'tester',
      userRole: UserRole.customer,
    );

    final posts = List.generate(
      4,
      (i) => CommunityPost(
        id: 'post-$i',
        author: author,
        body: 'Post content $i with interesting market observation',
        createdAt: DateTime.now().subtract(Duration(minutes: i * 5)),
      ),
    );

    testWidgets('renders multiple posts in grid layout', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: CommunityPostGrid(posts: posts)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CommunityPostCard), findsNWidgets(4));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CommunityHighlightedText &&
              w.text.contains('Post content 0'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CommunityHighlightedText &&
              w.text.contains('Post content 1'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CommunityHighlightedText &&
              w.text.contains('Post content 2'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CommunityHighlightedText &&
              w.text.contains('Post content 3'),
        ),
        findsOneWidget,
      );
    });
  });

  group('Community Interactive Tiles & Sidebar Tests', () {
    testWidgets('CommunityPollTile renders question and allows voting', (
      WidgetTester tester,
    ) async {
      int? votedIdx;
      final poll = CommunityPoll(
        id: 'poll-test-1',
        question: 'Will NIFTY breach 25,000 this week?',
        options: const [
          CommunityPollOption(id: 'opt1', text: 'Bullish (Yes)', votes: 120),
          CommunityPollOption(id: 'opt2', text: 'Bearish (No)', votes: 40),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityPollTile(
              poll: poll,
              onVote: (idx) => votedIdx = idx,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Will NIFTY breach 25,000 this week?'), findsOneWidget);
      expect(find.text('Bullish (Yes)'), findsOneWidget);
      expect(find.text('Bearish (No)'), findsOneWidget);

      await tester.tap(find.text('Bullish (Yes)'));
      expect(votedIdx, equals(0));
    });

    testWidgets(
      'CommunityTradeSetupTile renders ticker, side, entry and target',
      (WidgetTester tester) async {
        const setup = CommunityTradeSetup(
          ticker: 'RELIANCE',
          side: 'LONG',
          entry: '2980.50',
          stopLoss: '2930.00',
          target: '3080.00',
          pnl: '+3.3%',
          isWin: true,
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: CommunityTradeSetupTile(setup: setup)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('RELIANCE'), findsOneWidget);
        expect(find.text('LONG'), findsOneWidget);
        expect(find.text('2980.50'), findsOneWidget);
        expect(find.text('3080.00'), findsOneWidget);
      },
    );

    testWidgets(
      'CommunityDisclaimerCard renders SEBI disclaimer and guidelines trigger',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: CommunityDisclaimerCard())),
        );
        await tester.pumpAndSettle();

        expect(find.text('Regulatory Disclaimer'), findsOneWidget);
        expect(find.text('Guidelines'), findsOneWidget);
      },
    );

    testWidgets('CommunityLiveRoomWidget renders LIVE floor and topic', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommunityLiveRoomWidget(
              title: 'Live Expiry Floor',
              host: 'Test Host',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SIMULATED AUDIO (BETA)'), findsOneWidget);
      expect(find.textContaining('Live Expiry Floor'), findsOneWidget);
    });
  });

  group('Community Sub-Pages Tests', () {
    testWidgets(
      'CommunityNotificationSettingsPage renders preferences and saves',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: CommunityNotificationSettingsPage()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Notification Preferences'), findsOneWidget);
        expect(find.text('Push Notifications'), findsOneWidget);
        expect(find.text('Trade Setup & Signal Alerts'), findsOneWidget);
        expect(find.text('Save Preferences'), findsOneWidget);
      },
    );

    testWidgets('CommunityModerationListPage renders tabs and empty states', (
      WidgetTester tester,
    ) async {
      final repo = CommunityRepository();
      await tester.pumpWidget(
        MaterialApp(home: CommunityModerationListPage(repository: repo)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Moderation & Safety'), findsOneWidget);
      expect(find.text('Muted'), findsOneWidget);
      expect(find.text('Blocked'), findsOneWidget);
      expect(find.text('No Muted Accounts'), findsOneWidget);
    });

    testWidgets('CommunityHashtagPage renders topic header and tabs', (
      WidgetTester tester,
    ) async {
      final repo = CommunityRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityHashtagPage(tag: 'NIFTY', repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('#NIFTY'), findsWidgets);
      expect(find.text('Top Posts'), findsOneWidget);
      expect(find.text('Latest'), findsOneWidget);
      expect(find.text('Traders'), findsOneWidget);
    });

    testWidgets(
      'CommunitySearchPage renders search bar, filters and empty state',
      (WidgetTester tester) async {
        final repo = CommunityRepository();
        await tester.pumpWidget(
          MaterialApp(home: CommunitySearchPage(repository: repo)),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Search community, tickers, traders...'),
          findsOneWidget,
        );
        expect(find.text('Recent Searches'), findsOneWidget);
        expect(find.text('NIFTY'), findsWidgets);
      },
    );

    testWidgets('CommunityInboxView renders messages center and empty state', (
      WidgetTester tester,
    ) async {
      final repo = CommunityRepository();
      await tester.pumpWidget(
        MaterialApp(home: CommunityInboxView(repository: repo)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Direct Messages'), findsOneWidget);
    });

    testWidgets('CommunityArticleSheet renders headline, source and summary', (
      WidgetTester tester,
    ) async {
      final item = CommunityNewsItem(
        id: 'news-test',
        headline: 'RBI Maintains Repo Rate at 6.5%',
        source: 'Bloomberg Quint',
        summary: 'MPC voted unanimously with cautious outlook on inflation.',
        publishedAt: DateTime.now(),
        sentimentScore: 0.1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommunityArticleSheet(article: item)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RBI Maintains Repo Rate at 6.5%'), findsOneWidget);
      expect(find.textContaining('Bloomberg Quint'), findsOneWidget);
    });

    testWidgets('CommunityGuidelinesDialog renders compliance rules', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CommunityGuidelinesDialog())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Community Code of Conduct'), findsOneWidget);
      expect(find.text('No Front-Running or Pump & Dump'), findsOneWidget);
    });
  });

  group('CommunityEngagementBar desktop layout', () {
    testWidgets('keeps all primary metrics on one horizontal row', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              child: CommunityEngagementBar(
                comments: 12,
                reposts: 8,
                likes: 56,
                views: 1400,
                liked: false,
                reposted: false,
                bookmarked: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttons = find.byType(CommunityEngagementButton);
      expect(buttons, findsNWidgets(6));

      final double firstMetricY = tester.getCenter(buttons.at(0)).dy;
      for (int index = 1; index < 4; index++) {
        expect(
          tester.getCenter(buttons.at(index)).dy,
          closeTo(firstMetricY, 0.1),
        );
      }
    });
  });

  group('Post Card Real Sharing Tests', () {
    testWidgets(
      'CommunityPostCard share button opens CommunityShareSheet, copies link, records share count, and clips post to Trader Notes',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = CommunityRepository();
        const author = CommunityAuthor(
          id: 'author-share-1',
          displayName: 'Elena Rostova',
          handle: 'elena_quant',
          verified: true,
          userRole: UserRole.customer,
        );
        final post = CommunityPost(
          id: 'post-share-101',
          author: author,
          body: 'Watching \$NVDA breakout above 140 resistance with strong volume.',
          tickers: const <String>['NVDA'],
          tags: const <String>['breakout'],
          createdAt: DateTime.now(),
          tradeSetup: const CommunityTradeSetup(
            ticker: 'NVDA',
            side: 'LONG',
            entry: '140.50',
            target: '152.00',
            stopLoss: '136.00',
            rMultiple: '2.5R',
          ),
        );

        bool shareCallbackFired = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CommunityPostCard(
                  post: post,
                  repository: repo,
                  onShare: () => shareCallbackFired = true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(repo.shareCountFor('post-share-101'), 0);

        // Tap the Share button on the engagement bar
        await tester.tap(find.byIcon(Icons.ios_share_rounded).last);
        await tester.pumpAndSettle();

        // Verify CommunityShareSheet opened with post preview, URL, and external share options
        expect(find.text('Share Post'), findsOneWidget);
        expect(
          find.text('https://alphajournal.in/community/post/post-share-101?public=true'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('share-sheet-whatsapp')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('share-sheet-x')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('share-sheet-telegram')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('share-sheet-native')),
          findsOneWidget,
        );

        // Tap Copy Link inside the share sheet
        await tester.tap(
          find.byKey(const ValueKey('share-sheet-copy-link-btn')),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 4));

        expect(repo.shareCountFor('post-share-101'), 1);
        expect(shareCallbackFired, isTrue);

        // Tap Save Post to Trader Notes
        final int notesBefore =
            (await NotesRepositoryScope.repository.fetchAll()).length;
        await tester.tap(find.byKey(const ValueKey('share-sheet-save-note')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 4));

        expect(
          (await NotesRepositoryScope.repository.fetchAll()).length,
          greaterThan(notesBefore),
        );
        expect(repo.shareCountFor('post-share-101'), 2);
      },
    );

    testWidgets(
      'AppPostCard has a working built-in Share button even when onShare is null',
      (WidgetTester tester) async {
        final appPost = AppPost(
          id: 'app-post-77',
          author: const AppTrader(
            id: 'trader-77',
            displayName: 'Marcus Vance',
            handle: '@mvance',
          ),
          body: 'Macro liquidity remains supportive for tech leaders.',
          tickers: const <String>['QQQ', 'MSFT'],
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AppPostCard(post: appPost),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the Share button on AppPostCard
        await tester.tap(find.byIcon(Icons.ios_share));
        await tester.pumpAndSettle();

        expect(find.text('Share Post'), findsOneWidget);
        expect(
          find.text('https://alphajournal.in/community/post/app-post-77?public=true'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('app-post-share-copy-link')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('app-post-share-whatsapp')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('app-post-share-x')),
          findsOneWidget,
        );
      },
    );
  });
}
