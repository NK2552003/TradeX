import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Community post ownership and server-side authorization', () {
    test('non-author cannot delete someone else\'s post', () async {
      final repo = CommunityRepository();
      // Find a post authored by someone else in the default seeded posts
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

    test('non-author cannot delete someone else\'s comment', () async {
      final repo = CommunityRepository();
      const postId = 'post_q1';
      const otherAuthor = CommunityAuthor(
        id: 'usr_stranger_commenter',
        handle: 'stranger',
        displayName: 'Stranger',
        userRole: UserRole.customer,
      );

      final strangerComment = CommunityComment(
        id: 'comment_stranger_1',
        postId: postId,
        author: otherAuthor,
        body: 'Intriguing setup',
        createdAt: DateTime.now(),
      );

      repo.setCommentsForPost(postId, [strangerComment]);

      expect(
        () => repo.deleteComment(postId, strangerComment.id),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Only the author can delete this comment'),
          ),
        ),
      );
    });

    test('author can delete their own comment', () async {
      final repo = CommunityRepository();
      const postId = 'post_q1';
      final myAuthor = repo.currentAuthor;

      final myComment = CommunityComment(
        id: 'comment_my_1',
        postId: postId,
        author: myAuthor,
        body: 'My analysis notes',
        createdAt: DateTime.now(),
      );

      repo.setCommentsForPost(postId, [myComment]);
      expect(repo.commentsForPost(postId).length, 1);

      await repo.deleteComment(postId, myComment.id);
      expect(repo.commentsForPost(postId).isEmpty, isTrue);
    });
  });

  group('Blocked user visibility semantics', () {
    test('blocking an author excludes their posts from feeds and lookups', () async {
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

      // Unblock the author
      await repo.unblockUser(authorIdToBlock);

      expect(repo.blockedUsers.contains(authorIdToBlock), isFalse);
      expect(repo.forYouPosts.any((p) => p.id == targetPost.id), isTrue);
      expect(repo.loadPostById(targetPost.id), isNotNull);
    });
  });

  group('Profile selects and mapping reconciliation', () {
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

    test('CommunityAuthor mapping accurately reflects verified, win_rate, and counts', () {
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
      };

      final author = CommunityAuthor(
        id: profile['id'] as String,
        handle: profile['handle'] as String,
        displayName: profile['display_name'] as String,
        userRole: UserRole.customer,
        avatarUrl: profile['avatar_url'] as String?,
        bio: profile['bio'] as String?,
        verified: profile['verified'] as bool? ?? false,
        winRate: (profile['win_rate'] as num?)?.toDouble(),
        followers: (profile['followers_count'] as num?)?.toInt() ?? 0,
        following: (profile['following_count'] as num?)?.toInt() ?? 0,
        postsCount: (profile['posts_count'] as num?)?.toInt() ?? 0,
      );

      expect(author.handle, 'toptrader');
      expect(author.verified, isTrue);
      expect(author.winRate, 72.5);
      expect(author.followers, 1420);
      expect(author.following, 180);
      expect(author.postsCount, 95);
    });
  });
}
