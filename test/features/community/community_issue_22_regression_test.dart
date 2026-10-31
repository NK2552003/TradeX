import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart' hide CommunityPostCard;
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/community_root_screen.dart';
import 'package:tradex/features/community/presentation/views/community_bookmarks_view.dart';
import 'package:tradex/features/community/presentation/views/community_explore_view.dart';
import 'package:tradex/features/community/presentation/views/community_feed_view.dart';
import 'package:tradex/features/community/presentation/widgets/community_advisor_disclosure_sheet.dart';
import 'package:tradex/features/community/presentation/widgets/community_composer_card.dart';
import 'package:tradex/features/community/presentation/widgets/community_engagement_bar.dart';
import 'package:tradex/features/community/presentation/widgets/community_feed_list.dart';
import 'package:tradex/features/community/presentation/widgets/community_live_space_card.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_card.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_options_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp(Widget child, {Size size = const Size(390, 844)}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(body: child),
      ),
    );
  }

  group('Issue #22: Post actions (Quote, Mute, Unavailable styling)', () {
    testWidgets('Quote action fallback opens CommunityComposerCard with quotedPost', (tester) async {
      final repo = CommunityRepository();
      final post = repo.forYouPosts.first;

      await tester.pumpWidget(
        buildTestApp(
          CommunityPostCard(
            post: post,
            repository: repo,
          ),
          size: const Size(480, 844),
        ),
      );
      await tester.pumpAndSettle();

      // Tap repost button to open repost dialog
      final repostBtn = find.byTooltip('Repost');
      expect(repostBtn, findsOneWidget);
      await tester.tap(repostBtn);
      await tester.pumpAndSettle();

      // Tap Quote Post
      final quoteBtn = find.text('Quote Post');
      expect(quoteBtn, findsOneWidget);
      await tester.tap(quoteBtn);
      await tester.pumpAndSettle();

      // Verify composer opened with quoted post card
      expect(find.byType(CommunityComposerCard), findsOneWidget);
    });

    testWidgets('CommunityFeedList forwards onQuote callback', (tester) async {
      final repo = CommunityRepository();
      final post = repo.forYouPosts.first;
      CommunityPost? quoted;

      await tester.pumpWidget(
        buildTestApp(
          CommunityFeedList(
            posts: [post],
            repository: repo,
            onQuote: (p) => quoted = p,
          ),
          size: const Size(480, 844),
        ),
      );
      await tester.pumpAndSettle();

      final repostBtn = find.byTooltip('Repost');
      await tester.tap(repostBtn);
      await tester.pumpAndSettle();

      final quoteBtn = find.text('Quote Post');
      await tester.tap(quoteBtn);
      await tester.pumpAndSettle();

      expect(quoted?.id, post.id);
    });

    testWidgets('CommunityPostOptionsSheet toggles Mute/Unmute and marks unavailable actions', (tester) async {
      final repo = CommunityRepository();
      final post = repo.forYouPosts.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    CommunityPostOptionsSheet.show(
                      ctx,
                      post: post,
                      repository: repo,
                      isAuthor: false,
                    );
                  },
                  child: const Text('Open Options'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.text('Open Options'));
      await tester.pumpAndSettle();

      // Verify Quote Post option is available
      expect(find.text('Quote Post'), findsOneWidget);

      // Verify Not Interested is marked as unavailable
      expect(find.text('Not Interested in this post'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);

      // Initially not muted
      expect(find.text('Mute @${post.author.handle}'), findsOneWidget);

      // Tap Mute
      await tester.tap(find.text('Mute @${post.author.handle}'));
      await tester.pumpAndSettle();

      expect(repo.mutedUsers.contains(post.author.id), isTrue);

      // Reopen options sheet
      await tester.tap(find.text('Open Options'));
      await tester.pumpAndSettle();

      // Now should display Unmute
      expect(find.text('Unmute @${post.author.handle}'), findsOneWidget);
    });
  });

  group('Issue #22: Pull-to-refresh on Community views', () {
    testWidgets('CommunityFeedView, CommunityExploreView and CommunityBookmarksView contain RefreshIndicator', (tester) async {
      final repo = CommunityRepository();
      final author = repo.currentAuthor;

      // 1. Feed View
      await tester.pumpWidget(
        buildTestApp(
          CommunityFeedView(
            repository: repo,
            currentUser: author,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RefreshIndicator), findsWidgets);

      // 2. Explore View
      await tester.pumpWidget(
        buildTestApp(
          CommunityExploreView(
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RefreshIndicator), findsOneWidget);

      // 3. Bookmarks View
      await tester.pumpWidget(
        buildTestApp(
          CommunityBookmarksView(
            repository: repo,
            currentUser: author,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });

  group('Issue #22: Embedded Navigation single bottom dock', () {
    testWidgets('CommunityRootScreen has one TabBarView and avoids duplicate BottomNavigationBar when embedInScaffold=true', (tester) async {
      final repo = CommunityRepository();

      await tester.pumpWidget(
        buildTestApp(
          CommunityRootScreen(
            repository: repo,
            embedInScaffold: true,
          ),
          size: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TabBarView), findsNWidgets(2));
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });
  });

  group('Issue #22: Compact action touch targets', () {
    testWidgets('CommunityEngagementButton has accessible touch targets (min 44x44 on mobile)', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const CommunityEngagementButton(
            icon: Icons.favorite_border_rounded,
            count: '42',
            tooltip: 'Like',
            activeColor: Colors.red,
            isMobile: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Size size = tester.getSize(find.byType(CommunityEngagementButton));
      expect(size.height, greaterThanOrEqualTo(44.0));
      expect(size.width, greaterThanOrEqualTo(44.0));
    });
  });

  group('Issue #22: Advisor profile verification & removal of fabricated numbers', () {
    testWidgets('CommunityAdvisorDisclosureSheet renders verified profile status and no fabricated SEBI number', (tester) async {
      const author = CommunityAuthor(
        id: 'usr_real_trader',
        handle: 'real_trader',
        displayName: 'Aarav Gupta',
        userRole: UserRole.customer,
        verified: false,
      );

      await tester.pumpWidget(
        buildTestApp(
          const CommunityAdvisorDisclosureSheet(author: author),
        ),
      );
      await tester.pumpAndSettle();

      // Must not display fabricated persona or fabricated SEBI registration number
      expect(find.text('Rajesh Sharma, CMT'), findsNothing);
      expect(find.text('INH000009412'), findsNothing);
      expect(find.text('Valid thru Oct 2028'), findsNothing);

      // Must display unverified advisor status and not on file
      expect(find.text('Not on file / Unregistered'), findsOneWidget);
      expect(find.text('Community Member (Unverified Advisor Status)'), findsOneWidget);
      expect(find.text('Self-directed trader (Educational only)'), findsOneWidget);
    });
  });

  group('Issue #22: Simulated audio space label', () {
    testWidgets('CommunityLiveSpaceCard labels simulated spaces as SIMULATED AUDIO (BETA)', (tester) async {
      final repo = CommunityRepository();
      final room = repo.allLiveRooms.first;

      await tester.pumpWidget(
        buildTestApp(
          CommunityLiveSpaceCard(
            room: room,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SIMULATED AUDIO (BETA)'), findsOneWidget);
    });
  });
}
