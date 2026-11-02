import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_engagement_bar.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_card.dart';

void main() {
  group('Community Multi-Reactions Display & Interaction Tests', () {
    test('CommunityPost.displayReactions aggregates unique reactions with userReaction first', () {
      final post = CommunityPost(
        id: 'post_1',
        author: const CommunityAuthor(
          id: 'author_1',
          displayName: 'Trader Alex',
          handle: 'alex',
          userRole: UserRole.customer,
        ),
        body: 'Testing multi reactions',
        createdAt: DateTime.now(),
        likes: 2,
        liked: true,
        userReaction: '🚀',
        reactions: const <String>['👍', '🚀'],
      );

      final displayRx = post.displayReactions;
      expect(displayRx.length, 2);
      expect(displayRx[0], '🚀');
      expect(displayRx[1], '👍');
    });

    testWidgets('CommunityEngagementBar renders multiple distinct emoji reactions (e.g. 🚀 👍 2)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: CommunityEngagementBar(
                  comments: 0,
                  reposts: 0,
                  likes: 2,
                  views: 150,
                  liked: true,
                  userReaction: '🚀',
                  reactions: const <String>['🚀', '👍'],
                  reposted: false,
                  bookmarked: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify both emojis are rendered together in the engagement bar
      expect(find.text('🚀'), findsOneWidget);
      expect(find.text('👍'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('CommunityPostCard displays multi-reaction cluster and updates on interaction',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final post = CommunityPost(
        id: 'post_test_multi',
        author: const CommunityAuthor(
          id: 'author_2',
          displayName: 'Trader Priya',
          handle: 'priya',
          userRole: UserRole.customer,
        ),
        body: 'Post with multiple reactions',
        createdAt: DateTime.now(),
        likes: 1,
        liked: false,
        reactions: const <String>['👍'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommunityPostCard(
                post: post,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially has 1 like with 👍
      expect(find.text('👍'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Long press like button to open reaction pill
      final thumbFinder = find.text('👍');
      expect(thumbFinder, findsOneWidget);
      await tester.longPress(thumbFinder);
      await tester.pumpAndSettle();

      // Reaction pill appears with emojis
      final rocketPillFinder = find.text('🚀');
      expect(rocketPillFinder, findsOneWidget);

      // Tap rocket to react with 🚀
      await tester.tap(rocketPillFinder);
      await tester.pumpAndSettle();

      // Now both 🚀 and 👍 should be visible, and like count should be 2!
      expect(find.text('🚀'), findsOneWidget);
      expect(find.text('👍'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });
  });
}
