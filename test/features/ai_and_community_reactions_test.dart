import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tradex/core/ai/unified_ai_service.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/notes/data/real_note_ai_refactor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UnifiedAiService Multi-Provider Fallback Tests', () {
    test('OpenRouter free models complete prompt successfully', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'openrouter.ai') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['models'], isNotNull);
          expect(body['models'], contains('openrouter/free'));
          expect(body['models'], contains('nvidia/nemotron-3.5-lightning:free'));
          return http.Response(
            jsonEncode({
              'id': 'gen-12345',
              'choices': [
                {
                  'message': {
                    'role': 'assistant',
                    'content': 'OpenRouter Free Model: Trade Setup on NIFTY',
                  }
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final aiService = UnifiedAiService(
        clientFactory: () => mockClient,
        openrouterApiKey: () => 'mock-openrouter-key',
      );
      final reply = await aiService.complete(prompt: 'Give me a NIFTY setup');

      expect(reply, contains('OpenRouter Free Model'));
      expect(reply, contains('Trade Setup on NIFTY'));
    });

    test('Strips <think> tags from model reasoning output', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content':
                      '<think>User wants technical analysis on AAPL.</think>### Swing Structure: AAPL\nBuy at \$180.',
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final aiService = UnifiedAiService(
        clientFactory: () => mockClient,
        openrouterApiKey: () => 'mock-openrouter-key',
      );
      final reply = await aiService.complete(prompt: 'Analyze AAPL');

      expect(reply, isNot(contains('<think>')));
      expect(reply, isNot(contains('</think>')));
      expect(reply, contains('### Swing Structure: AAPL'));
    });

    test('Falls back to dynamic local trading engine if all providers fail', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Rate Limited', 429);
      });

      final aiService = UnifiedAiService(clientFactory: () => mockClient);
      final reply = await aiService.complete(prompt: 'Analyze RELIANCE breakout');

      expect(reply, isNotEmpty);
      expect(reply, contains('RELIANCE'));
      expect(reply, contains('Key Structural & Liquidity Levels'));
      expect(reply, contains('Trade Execution Blueprint'));
    });

    test('Note AI refactoring rejects unauthenticated requests when no keys are configured', () async {
      const refactor = RealNoteAiRefactor();
      expect(
        () async => await refactor.enhance(
          selectedText: 'Watched NVDA hit 128 resistance today with heavy tape volume.',
          noteType: AppNoteType.analysis,
          contextTitle: 'NVDA Journal',
          instruction: 'Turn into trading plan',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Community Post Card Reactions and Storage Tests', () {
    late CommunityRepository repo;

    setUp(() {
      repo = CommunityRepository();
    });

    tearDown(() {
      repo.dispose();
    });

    test('toggleLike updates standard like on post card', () {
      expect(repo.forYouPosts, isNotEmpty);
      final post = repo.forYouPosts.first;
      final initialLikes = post.likes;
      final wasLiked = post.liked;

      repo.toggleLike(post.id);

      final updated = repo.findPost(post.id);
      expect(updated, isNotNull);
      expect(updated!.liked, !wasLiked);
      expect(updated.likes, wasLiked ? initialLikes - 1 : initialLikes + 1);
    });

    test('toggleLike with emoji reaction stores reaction on post card', () {
      final post = repo.forYouPosts.first;

      // 1. React with 🚀
      repo.toggleLike(post.id, reaction: '🚀');
      var updated = repo.findPost(post.id);
      expect(updated!.liked, isTrue);
      expect(updated.userReaction, '🚀');

      // 2. Switch reaction to 🔥
      repo.toggleLike(post.id, reaction: '🔥');
      updated = repo.findPost(post.id);
      expect(updated!.liked, isTrue);
      expect(updated.userReaction, '🔥');

      // 3. Tapping same reaction again toggles it off
      repo.toggleLike(post.id, reaction: '🔥');
      updated = repo.findPost(post.id);
      expect(updated!.liked, isFalse);
      expect(updated.userReaction, isNull);
    });

    test('findPost finds post across all buckets (Following, Signals, Bookmarks)', () {
      final post = repo.forYouPosts.first;
      expect(repo.findPost(post.id), isNotNull);

      // Bookmark it and verify finding by ID
      repo.toggleBookmark(post.id);
      final bookmarked = repo.bookmarkedPosts.firstWhere((p) => p.id == post.id);
      expect(bookmarked.bookmarked, isTrue);
      expect(repo.findPost(bookmarked.id), isNotNull);
    });

    test('likeComment updates comment reactions and stores reaction on comment', () {
      expect(repo.forYouPosts, isNotEmpty);
      final postId = repo.forYouPosts.first.id;

      repo.addComment(postId, 'Great analysis!');
      final comments = repo.commentsForPost(postId);
      expect(comments, isNotEmpty);
      final comment = comments.first;

      // React with 💡
      repo.likeComment(postId, comment.id, reaction: '💡');
      var updated = repo.commentsForPost(postId).firstWhere((c) => c.id == comment.id);
      expect(updated.liked, isTrue);
      expect(updated.userReaction, '💡');

      // Toggle off
      repo.likeComment(postId, comment.id, reaction: '💡');
      updated = repo.commentsForPost(postId).firstWhere((c) => c.id == comment.id);
      expect(updated.liked, isFalse);
      expect(updated.userReaction, isNull);
    });
  });
}
