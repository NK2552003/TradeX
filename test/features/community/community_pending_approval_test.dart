import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart' hide CommunityPostCard;
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_post_card.dart';
import 'package:alphajournal/features/settings/presentation/pages/shared/trader_profile_preview_page.dart';

void main() {
  group('Community Post Pending Approval State Tests', () {
    test('CommunityPost and AppPost report correct pending approval state', () {
      final defaultPost = CommunityPost(
        id: 'post-1',
        author: const CommunityAuthor(
          id: 'user-1',
          handle: 'trader1',
          displayName: 'Trader One',
          userRole: UserRole.customer,
        ),
        body: 'Approved post content',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(defaultPost.moderationStatus, 'approved');
      expect(defaultPost.isPendingApproval, isFalse);

      final pendingPost = defaultPost.copyWith(moderationStatus: 'pending');
      expect(pendingPost.moderationStatus, 'pending');
      expect(pendingPost.isPendingApproval, isTrue);

      final appPost = AppPost(
        id: 'app-post-1',
        author: const AppTrader(
          id: 'user-1',
          handle: 'trader1',
          displayName: 'Trader One',
        ),
        body: 'Pending post body',
        createdAt: DateTime(2026, 1, 1),
        moderationStatus: 'pending',
      );
      expect(appPost.isPendingApproval, isTrue);
    });

    test(
      'CommunityRepository createPost auto-approves posts so they are immediately visible',
      () async {
        final repo = CommunityRepository();
        final author = repo.currentAuthor;

        await repo.createPost(
          body: 'New strategy thesis awaiting review',
          tickers: const ['AAPL'],
          author: author,
        );

        // Verify post is auto-approved
        final authorPosts = repo.postsForAuthor(author.id);
        expect(
          authorPosts.any(
            (p) => p.body == 'New strategy thesis awaiting review',
          ),
          isTrue,
        );
        expect(
          authorPosts
              .firstWhere(
                (p) => p.body == 'New strategy thesis awaiting review',
              )
              .moderationStatus,
          'approved',
        );

        // Another user querying this author's posts will see the auto-approved post
        final otherAuthor = const CommunityAuthor(
          id: 'usr_other_trader_999',
          handle: 'othertrader',
          displayName: 'Other Trader',
          userRole: UserRole.customer,
        );
        repo.currentAuthor = otherAuthor;

        final publicViewPosts = repo.postsForAuthor(author.id);
        expect(
          publicViewPosts.any(
            (p) => p.body == 'New strategy thesis awaiting review',
          ),
          isTrue,
          reason: 'Auto-approved post is visible to other users',
        );

        // Feed also displays the auto-approved post
        expect(
          repo.forYouPosts.any(
            (p) => p.body == 'New strategy thesis awaiting review',
          ),
          isTrue,
          reason: 'General feed immediately displays auto-approved posts',
        );
      },
    );

    testWidgets(
      'CommunityPostCard renders Pending Approval badge when post isPendingApproval',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final pendingPost = CommunityPost(
          id: 'post-pending-1',
          author: const CommunityAuthor(
            id: 'user-1',
            handle: 'trader1',
            displayName: 'Trader One',
            userRole: UserRole.customer,
          ),
          body: 'Thesis awaiting moderation',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          moderationStatus: 'pending',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CommunityPostCard(post: pendingPost),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pending Approval'), findsOneWidget);
        expect(
          find.textContaining('Visible only to you until approved'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'CommunityPostCard does not render Pending Approval badge when post is approved',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final approvedPost = CommunityPost(
          id: 'post-approved-1',
          author: const CommunityAuthor(
            id: 'user-1',
            handle: 'trader1',
            displayName: 'Trader One',
            userRole: UserRole.customer,
          ),
          body: 'Thesis approved and live',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          moderationStatus: 'approved',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CommunityPostCard(post: approvedPost),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pending Approval'), findsNothing);
      },
    );

    testWidgets(
      'TraderProfilePreviewPage shows Pending Approval tab only to author',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = CommunityRepository();

        // Case 1: Author viewing self (isCurrentUser: true)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TraderProfilePreviewPage(
                displayName: repo.currentAuthor.displayName,
                handle: repo.currentAuthor.handle,
                userRole: UserRole.customer,
                repository: repo,
                author: repo.currentAuthor,
                isCurrentUser: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pending Approval'), findsOneWidget);

        // Case 2: Another user viewing the profile (isCurrentUser: false)
        const otherAuthor = CommunityAuthor(
          id: 'usr_stranger_123',
          handle: 'stranger_trader',
          displayName: 'Stranger Trader',
          userRole: UserRole.customer,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TraderProfilePreviewPage(
                displayName: otherAuthor.displayName,
                handle: otherAuthor.handle,
                userRole: UserRole.customer,
                repository: repo,
                author: otherAuthor,
                isCurrentUser: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Pending Approval'),
          findsNothing,
          reason:
              'Pending Approval tab must only be visible when author is viewing self',
        );
      },
    );
  });
}
