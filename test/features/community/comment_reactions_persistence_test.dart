import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/universal_comments_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Comment reactions persistence in CommunityRepository', () {
    test('likeComment toggles like and sets userReaction and displayReactions', () async {
      final repo = CommunityRepository();
      const postId = 'test_post_1';
      const commentId = 'test_comment_1';

      final comment = CommunityComment(
        id: commentId,
        postId: postId,
        author: const CommunityAuthor(
          id: 'user_author_1',
          handle: 'marketwizard',
          displayName: 'Market Wizard',
          userRole: UserRole.customer,
        ),
        body: 'Great setup on NVDA!',
        createdAt: DateTime.now(),
        likes: 0,
        liked: false,
      );

      repo.setCommentsForPost(postId, [comment]);

      expect(repo.commentsForPost(postId).first.liked, isFalse);
      expect(repo.commentsForPost(postId).first.likes, 0);

      // 1. Like with default thumbs-up
      repo.likeComment(postId, commentId);

      var updated = repo.commentsForPost(postId).first;
      expect(updated.liked, isTrue);
      expect(updated.likes, 1);
      expect(updated.userReaction, '👍');
      expect(updated.displayReactions, contains('👍'));

      // 2. React with bullish rocket
      repo.likeComment(postId, commentId, reaction: '🚀');

      updated = repo.commentsForPost(postId).first;
      expect(updated.liked, isTrue);
      expect(updated.likes, 1); // was already liked, so count remains 1
      expect(updated.userReaction, '🚀');
      expect(updated.displayReactions, contains('🚀'));

      // 3. React with same rocket again to toggle off
      repo.likeComment(postId, commentId, reaction: '🚀');

      updated = repo.commentsForPost(postId).first;
      expect(updated.liked, isFalse);
      expect(updated.likes, 0);
      expect(updated.userReaction, isNull);

      repo.dispose();
    });

    test('reactions are persisted into SharedPreferences and survive reloads', () async {
      SharedPreferences.setMockInitialValues({});

      final repo = CommunityRepository();
      const postId = 'p_100';
      const commentId = 'c_100';

      final comment = CommunityComment(
        id: commentId,
        postId: postId,
        author: const CommunityAuthor(
          id: 'author_2',
          handle: '@alpha_trader',
          displayName: 'Alpha Trader',
          userRole: UserRole.customer,
        ),
        body: 'Volume spike confirmed.',
        createdAt: DateTime.now(),
      );

      repo.setCommentsForPost(postId, [comment]);

      // React with Fire 🔥
      repo.likeComment(postId, commentId, reaction: '🔥');

      // Wait a tick for unawaited async save
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final prefs = await SharedPreferences.getInstance();
      // Since no user is logged in, saved under guest key
      const guestKey = 'tradex_comment_rx_guest';
      final raw = prefs.getString(guestKey);
      expect(raw, isNotNull);

      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded[commentId], '🔥');

      repo.dispose();
    });
  });

  group('UniversalCommentsSection double @ fix & reaction interactions', () {
    testWidgets('author headline strips leading @ so it never shows @@handle', (
      WidgetTester tester,
    ) async {
      const authorWithAt = CommunityAuthor(
        id: 'user_at_1',
        handle: '@nk2552003',
        displayName: 'Nitish Kumar',
        userRole: UserRole.customer,
      );

      final comment = CommunityComment(
        id: 'cmt_1',
        postId: 'post_1',
        author: authorWithAt,
        body: 'Checking reaction storage and persistence',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalCommentsSection(
              targetId: 'post_1',
              targetType: 'post',
              comments: [comment],
              currentUser: const CommunityAuthor(
                id: 'current_user',
                handle: 'tester',
                displayName: 'Tester',
                userRole: UserRole.customer,
              ),
              onAddComment: (_, {parentCommentId, sentiment}) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure '@@nk2552003' is NOT found
      expect(find.textContaining('@@nk2552003'), findsNothing);

      // Ensure proper single '@nk2552003' headline is present
      expect(
        find.textContaining(
          '@nk2552003 · Quantitative Trader · hejournal.in Community',
        ),
        findsOneWidget,
      );
    });

    testWidgets('clicking like or emoji reaction triggers onLikeComment callback', (
      WidgetTester tester,
    ) async {
      String? reactedCommentId;
      String? reactionType;

      final comment = CommunityComment(
        id: 'cmt_action',
        postId: 'post_1',
        author: const CommunityAuthor(
          id: 'author_1',
          handle: 'trader1',
          displayName: 'Trader 1',
          userRole: UserRole.customer,
        ),
        body: 'Breakout above 200 EMA',
        createdAt: DateTime.now(),
        likes: 0,
        liked: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalCommentsSection(
              targetId: 'post_1',
              targetType: 'post',
              comments: [comment],
              currentUser: const CommunityAuthor(
                id: 'current_user',
                handle: 'tester',
                displayName: 'Tester',
                userRole: UserRole.customer,
              ),
              onAddComment: (_, {parentCommentId, sentiment}) async {},
              onLikeComment: (commentId, {reaction}) {
                reactedCommentId = commentId;
                reactionType = reaction;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Like button
      final likeBtnFinder = find.text('Like');
      expect(likeBtnFinder, findsOneWidget);

      await tester.tap(likeBtnFinder);
      await tester.pumpAndSettle();

      expect(reactedCommentId, 'cmt_action');
      expect(reactionType, isNull); // Default like tap

      // Open emoji reaction picker
      final emojiPickerBtn = find.byIcon(Icons.add_reaction_outlined);
      expect(emojiPickerBtn, findsOneWidget);
      await tester.tap(emojiPickerBtn);
      await tester.pumpAndSettle();

      // Tap 🚀 (Bullish)
      final rocketFinder = find.text('🚀');
      expect(rocketFinder, findsOneWidget);
      await tester.tap(rocketFinder);
      await tester.pumpAndSettle();

      expect(reactedCommentId, 'cmt_action');
      expect(reactionType, '🚀');
    });
  });
}
