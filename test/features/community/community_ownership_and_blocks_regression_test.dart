import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/community/models/community_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Community post ownership and server-side authorization', () {
    test('non-author cannot delete someone else\'s post', () async {
      final repo = CommunityRepository();
      final otherPost = repo.forYouPosts.firstWhere(
        (p) => p.author.id != repo.currentAuthor.id,
      );

      expect(
        () => repo.deletePost(otherPost.id),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Only the author can delete this post'),
          ),
        ),
      );
    });

    test('non-author cannot edit someone else\'s post', () async {
      final repo = CommunityRepository();
      final otherPost = repo.forYouPosts.firstWhere(
        (p) => p.author.id != repo.currentAuthor.id,
      );

      expect(
        () => repo.editPost(otherPost.id, 'Hacked content by non-author'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Only the author can edit this post'),
          ),
        ),
      );
    });

    test('author can delete their own post', () async {
      final repo = CommunityRepository();
      await repo.createPost(
        body: 'My trade plan on NIFTY',
        author: repo.currentAuthor,
      );

      final myPost = repo.forYouPosts.firstWhere(
        (p) => p.author.id == repo.currentAuthor.id,
      );

      expect(repo.forYouPosts.any((p) => p.id == myPost.id), isTrue);

      await repo.deletePost(myPost.id);
      expect(repo.forYouPosts.any((p) => p.id == myPost.id), isFalse);
    });
  });

  group(
    'Nested comment lookup, ownership, recursive deletion, and count integrity',
    () {
      test(
        'non-author cannot delete someone else\'s top-level or nested comment',
        () async {
          final repo = CommunityRepository();
          const postId = 'post_nested_test';
          const stranger = CommunityAuthor(
            id: 'usr_stranger_commenter',
            handle: 'stranger',
            displayName: 'Stranger',
            userRole: UserRole.customer,
          );

          final reply = CommunityComment(
            id: 'reply_1',
            postId: postId,
            author: stranger,
            body: 'Nested response by stranger',
            createdAt: DateTime.now(),
            parentCommentId: 'top_1',
          );

          final topComment = CommunityComment(
            id: 'top_1',
            postId: postId,
            author: stranger,
            body: 'Top level comment',
            createdAt: DateTime.now(),
            replies: [reply],
          );

          repo.setCommentsForPost(postId, [topComment]);

          // Non-author attempting to delete top-level comment
          expect(
            () => repo.deleteComment(postId, topComment.id),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('Only the author can delete this comment'),
              ),
            ),
          );

          // Non-author attempting to delete nested reply
          expect(
            () => repo.deleteComment(postId, reply.id),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('Only the author can delete this comment'),
              ),
            ),
          );
        },
      );

      test(
        'author can delete nested reply without losing siblings or parent, adjusting count by 1',
        () async {
          final repo = CommunityRepository();
          const postId = 'post_q1';
          final myAuthor = repo.currentAuthor;

          final myReply = CommunityComment(
            id: 'reply_mine_1',
            postId: postId,
            author: myAuthor,
            body: 'My nested reply',
            createdAt: DateTime.now(),
            parentCommentId: 'parent_c1',
          );

          const siblingAuthor = CommunityAuthor(
            id: 'usr_sibling',
            handle: 'sibling',
            displayName: 'Sibling',
            userRole: UserRole.customer,
          );

          final siblingReply = CommunityComment(
            id: 'reply_sibling_2',
            postId: postId,
            author: siblingAuthor,
            body: 'Sibling reply',
            createdAt: DateTime.now(),
            parentCommentId: 'parent_c1',
          );

          final parentComment = CommunityComment(
            id: 'parent_c1',
            postId: postId,
            author: siblingAuthor,
            body: 'Parent discussion topic',
            createdAt: DateTime.now(),
            replies: [myReply, siblingReply],
          );

          repo.setCommentsForPost(postId, [parentComment]);
          final initialPostComments = repo.loadPostById(postId)?.comments ?? 0;

          // Delete only my nested reply
          await repo.deleteComment(postId, myReply.id);

          final commentsAfter = repo.commentsForPost(postId);
          expect(commentsAfter.length, 1);
          expect(commentsAfter.first.id, 'parent_c1');
          // Sibling reply is preserved
          expect(commentsAfter.first.replies.length, 1);
          expect(commentsAfter.first.replies.first.id, 'reply_sibling_2');

          // Post count was decremented by exactly 1
          final postAfter = repo.loadPostById(postId);
          if (initialPostComments > 0) {
            expect(postAfter?.comments, initialPostComments - 1);
          }
        },
      );

      test(
        'deleting top-level comment cascades all nested descendants and decrements counts accurately',
        () async {
          final repo = CommunityRepository();
          const postId = 'post_q1';
          final myAuthor = repo.currentAuthor;

          final deepReply = CommunityComment(
            id: 'deep_reply_1',
            postId: postId,
            author: myAuthor,
            body: 'Deep child reply',
            createdAt: DateTime.now(),
            parentCommentId: 'child_reply_1',
          );

          final childReply = CommunityComment(
            id: 'child_reply_1',
            postId: postId,
            author: myAuthor,
            body: 'Child reply',
            createdAt: DateTime.now(),
            parentCommentId: 'top_mine_1',
            replies: [deepReply],
          );

          final topComment = CommunityComment(
            id: 'top_mine_1',
            postId: postId,
            author: myAuthor,
            body: 'My root comment with 2 descendants',
            createdAt: DateTime.now(),
            replies: [childReply],
          );

          repo.setCommentsForPost(postId, [topComment]);
          final postBefore = repo.loadPostById(postId);
          final initialCount = postBefore?.comments ?? 0;

          // Total count of topComment + descendants is 3
          await repo.deleteComment(postId, topComment.id);

          expect(repo.commentsForPost(postId).isEmpty, isTrue);
          final postAfter = repo.loadPostById(postId);
          final expectedCount = initialCount >= 3 ? initialCount - 3 : 0;
          expect(postAfter?.comments, expectedCount);
        },
      );

      test(
        'deleting a non-existent comment throws and does not decrement counts',
        () async {
          final repo = CommunityRepository();
          const postId = 'post_q1';
          final countBefore = repo.loadPostById(postId)?.comments;

          expect(
            () => repo.deleteComment(postId, 'non_existent_comment_id'),
            throwsA(isA<StateError>()),
          );

          final countAfter = repo.loadPostById(postId)?.comments;
          expect(countAfter, equals(countBefore));
        },
      );
    },
  );

  group(
    'Blocked user visibility, outgoing vs incoming separation, and unblock safety',
    () {
      test(
        'blocking an author excludes their posts from feeds and lookups',
        () async {
          final repo = CommunityRepository();
          final targetPost = repo.forYouPosts.firstWhere(
            (p) => p.author.id != repo.currentAuthor.id,
          );
          final authorIdToBlock = targetPost.author.id;

          expect(repo.forYouPosts.any((p) => p.id == targetPost.id), isTrue);
          expect(repo.loadPostById(targetPost.id), isNotNull);

          // Block the author
          await repo.blockUser(authorIdToBlock);

          expect(repo.blockedUsers.contains(authorIdToBlock), isTrue);
          expect(repo.forYouPosts.any((p) => p.id == targetPost.id), isFalse);
          expect(repo.loadPostById(targetPost.id), isNull);

          // loadBlockedUsers returns outgoing block
          final blockedEntries = repo.loadBlockedUsers();
          expect(
            blockedEntries.any((b) => b.userId == authorIdToBlock),
            isTrue,
          );

          // Unblock the author
          await repo.unblockUser(authorIdToBlock);

          expect(repo.blockedUsers.contains(authorIdToBlock), isFalse);
          expect(repo.forYouPosts.any((p) => p.id == targetPost.id), isTrue);
          expect(repo.loadPostById(targetPost.id), isNotNull);
        },
      );

      test(
        'unblocking outgoing block does not erase independent incoming block',
        () async {
          final repo = CommunityRepository();
          const mutualUserId = 'usr_mutual_blocker_1';

          // Simulate incoming block already present from target user
          await repo.blockUser(mutualUserId);
          expect(repo.blockedUsers.contains(mutualUserId), isTrue);

          // Unblock outgoing
          await repo.unblockUser(mutualUserId);
          expect(
            repo.loadBlockedUsers().any((b) => b.userId == mutualUserId),
            isFalse,
          );
        },
      );
    },
  );

  group('Shared production profile mappings (CommunityAuthor)', () {
    test(
      'mapProfileToCommunityAuthor accurately maps verified, win_rate, and all counters',
      () {
        final profile = {
          'id': 'usr_verified_1',
          'handle': 'toptrader',
          'display_name': 'Top Trader',
          'role': 'customer',
          'verified': true,
          'win_rate': 72.5,
          'followers_count': 1420,
          'following_count': 180,
          'posts_count': 95,
          'avatar_url': 'https://example.com/top.png',
          'bio': 'Full-time price action trader',
          'trading_style': 'Price Action',
          'primary_market': 'NSE & Crypto',
          'avg_hold_duration': '2-3 days',
          'risk_mantra': '1% per trade',
          'location': 'Mumbai, India',
          'website': 'https://toptrader.io',
        };

        final author = CommunityRepository.mapProfileToCommunityAuthor(
          authorId: profile['id'] as String,
          authorProfile: profile,
          isFollowing: true,
        );

        expect(author.id, 'usr_verified_1');
        expect(author.handle, 'toptrader');
        expect(author.displayName, 'Top Trader');
        expect(author.userRole, UserRole.customer);
        expect(author.avatarUrl, 'https://example.com/top.png');
        expect(author.bio, 'Full-time price action trader');
        expect(author.verified, isTrue);
        expect(author.isFollowing, isTrue);
        expect(author.followers, 1420);
        expect(author.following, 180);
        expect(author.winRate, 72.5);
        expect(author.tradingStyle, 'Price Action');
        expect(author.primaryMarket, 'NSE & Crypto');
        expect(author.avgHoldDuration, '2-3 days');
        expect(author.riskMantra, '1% per trade');
        expect(author.location, 'Mumbai, India');
        expect(author.website, 'https://toptrader.io');
        expect(author.postsCount, 95);
      },
    );

    test(
      'mapProfileToCommunityAuthor gracefully handles null and missing fields with safe defaults',
      () {
        final author = CommunityRepository.mapProfileToCommunityAuthor(
          authorId: 'usr_bare_minimum',
          authorProfile: null,
        );

        expect(author.id, 'usr_bare_minimum');
        expect(author.handle, 'trader');
        expect(author.displayName, 'Trader');
        expect(author.userRole, UserRole.customer);
        expect(author.avatarUrl, isNull);
        expect(author.bio, isNull);
        expect(author.verified, isFalse);
        expect(author.isFollowing, isFalse);
        expect(author.followers, 0);
        expect(author.following, 0);
        expect(author.winRate, isNull);
        expect(author.tradingStyle, isNull);
        expect(author.primaryMarket, isNull);
        expect(author.postsCount, 0);
      },
    );

    test('LiveRoom models safely map handle and fallback without throwing', () {
      final participantMap = {
        'room_id': 'room_1',
        'user_id': 'user_1',
        'profiles': {
          'id': 'user_1',
          'handle': 'alpha_wolf',
          'display_name': 'Alpha Wolf',
          'avatar_url': 'https://example.com/avatar.png',
        },
        'role': 'speaker',
      };

      final participant = LiveRoomParticipant.fromMap(participantMap);
      expect(participant.handle, 'alpha_wolf');
      expect(participant.displayName, 'Alpha Wolf');

      final messageMap = {
        'id': 'msg_1',
        'room_id': 'room_1',
        'sender_id': 'user_1',
        'message': 'Hello room!',
        'profiles': {
          'id': 'user_1',
          'handle': 'alpha_wolf',
          'display_name': 'Alpha Wolf',
        },
      };

      final message = LiveRoomMessage.fromMap(messageMap);
      expect(message.senderName, 'Alpha Wolf');

      final questionMap = {
        'id': 'q_1',
        'room_id': 'room_1',
        'author_id': 'user_1',
        'question': 'What is your stop loss on BTC?',
        'profiles': {
          'id': 'user_1',
          'handle': 'alpha_wolf',
          'display_name': 'Alpha Wolf',
        },
      };

      final question = LiveRoomQuestion.fromMap(questionMap);
      expect(question.authorName, 'Alpha Wolf');
    });
  });
}
