import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alphajournal/core/utils/app_visibility.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/community/presentation/views/community_feed_view.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_new_posts_pill.dart';

class _TestFeedRepository extends CommunityRepository {
  _TestFeedRepository({List<CommunityPost>? initialPosts}) {
    _customPosts = List<CommunityPost>.from(initialPosts ?? const []);
  }

  late List<CommunityPost> _customPosts;
  final Map<String, CommunityPost> remotePendingPosts =
      <String, CommunityPost>{};
  int fullRefreshCalls = 0;
  int checkForNewPostsCalls = 0;
  int loadPendingCalls = 0;
  bool failLoadPending = false;
  bool _loadingPending = false;
  Completer<void>? loadPendingGate;

  @override
  List<CommunityPost> get forYouPosts => _customPosts;

  @override
  List<CommunityPost> get followingPosts => _customPosts;

  @override
  bool get isLoadingNewPosts => _loadingPending;

  @override
  Future<void> fetchFromSupabase() async {
    fullRefreshCalls++;
    notifyListeners();
  }

  @override
  Future<int> checkForNewPosts() async {
    checkForNewPostsCalls++;
    int added = 0;
    for (final entry in remotePendingPosts.entries) {
      if (!_customPosts.any((p) => p.id == entry.key) &&
          !pendingNewPostIds.contains(entry.key)) {
        handleRealtimePostChange(
          eventType: PostgresChangeEvent.insert,
          newRecord: <String, dynamic>{
            'id': entry.key,
            'author_id': entry.value.author.id,
            'is_public': true,
            'moderation_status': 'approved',
            'created_at': entry.value.createdAt.toUtc().toIso8601String(),
          },
        );
        added++;
      }
    }
    return added;
  }

  @override
  Future<List<CommunityPost>> loadPendingNewPosts() async {
    loadPendingCalls++;
    if (pendingNewPostIds.isEmpty) return const <CommunityPost>[];
    _loadingPending = true;
    notifyListeners();
    try {
      if (loadPendingGate != null) {
        await loadPendingGate!.future;
      }
      if (failLoadPending) {
        throw Exception('network_unavailable');
      }
      final ids = List<String>.from(pendingNewPostIds);
      final fetched = <CommunityPost>[];
      for (final id in ids) {
        final post = remotePendingPosts.remove(id);
        if (post != null && !_customPosts.any((p) => p.id == post.id)) {
          fetched.add(post);
        }
      }
      if (fetched.isNotEmpty) {
        _customPosts = <CommunityPost>[...fetched, ..._customPosts]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      // Clear pending IDs via a real delete-style cleanup or super call.
      await super.loadPendingNewPosts();
      return fetched;
    } finally {
      _loadingPending = false;
      notifyListeners();
    }
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppVisibility.instance.setVisibleForTest(true);
  });

  const CommunityAuthor user1 = CommunityAuthor(
    id: '11111111-1111-4111-8111-111111111111',
    handle: 'user1_trader',
    displayName: 'User One',
    userRole: UserRole.customer,
  );
  const CommunityAuthor user2 = CommunityAuthor(
    id: '22222222-2222-4222-8222-222222222222',
    handle: 'user2_viewer',
    displayName: 'User Two',
    userRole: UserRole.customer,
  );

  CommunityPost makePost({
    required String id,
    required CommunityAuthor author,
    required String body,
    required DateTime createdAt,
    int likes = 0,
  }) {
    return CommunityPost(
      id: id,
      author: author,
      body: body,
      createdAt: createdAt,
      isPublic: true,
      moderationStatus: 'approved',
      likes: likes,
    );
  }

  group('CommunityRepository realtime & pending new posts detection', () {
    test(
      'draft INSERT followed by publish UPDATE queues pending post without mutating feed',
      () {
        final repo = CommunityRepository();
        addTearDown(repo.dispose);
        final initialCount = repo.forYouPosts.length;
        const postId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
        final nowIso = DateTime.now().toUtc().toIso8601String();

        // Step 1: User 1 inserts private draft (CommunityPostWriter phase 1)
        repo.handleRealtimePostChange(
          eventType: PostgresChangeEvent.insert,
          newRecord: <String, dynamic>{
            'id': postId,
            'author_id': user1.id,
            'is_public': false,
            'moderation_status': 'approved',
            'created_at': nowIso,
          },
        );
        expect(repo.pendingNewPostsCount, 0);
        expect(repo.forYouPosts.length, initialCount);

        // Step 2: User 1 publishes post (CommunityPostWriter phase 2 UPDATE)
        repo.handleRealtimePostChange(
          eventType: PostgresChangeEvent.update,
          oldRecord: <String, dynamic>{
            'id': postId,
            'is_public': false,
          },
          newRecord: <String, dynamic>{
            'id': postId,
            'author_id': user1.id,
            'is_public': true,
            'moderation_status': 'approved',
            'created_at': nowIso,
          },
        );
        expect(repo.pendingNewPostsCount, 1);
        expect(repo.pendingNewPostIds, <String>[postId]);
        // Existing feed is NOT auto-overwritten before User 2 clicks the pill.
        expect(repo.forYouPosts.length, initialCount);
      },
    );

    test(
      'ignores counter-bump UPDATEs on older already-public posts and updates loaded posts in place',
      () {
        final repo = CommunityRepository();
        addTearDown(repo.dispose);
        final existing = repo.forYouPosts.first;
        final initialLikes = existing.likes;

        // Counter update on an already-loaded post updates in place (no pill).
        repo.handleRealtimePostChange(
          eventType: PostgresChangeEvent.update,
          oldRecord: <String, dynamic>{
            'id': existing.id,
            'is_public': true,
          },
          newRecord: <String, dynamic>{
            'id': existing.id,
            'author_id': existing.author.id,
            'is_public': true,
            'moderation_status': 'approved',
            'likes_count': initialLikes + 5,
            'created_at': existing.createdAt.toUtc().toIso8601String(),
          },
        );
        expect(repo.pendingNewPostsCount, 0);
        expect(
          repo.forYouPosts.firstWhere((p) => p.id == existing.id).likes,
          initialLikes + 5,
        );

        // Counter update on an old unpaginated post (oldRecord.is_public == true) is ignored.
        repo.handleRealtimePostChange(
          eventType: PostgresChangeEvent.update,
          oldRecord: <String, dynamic>{
            'id': 'old-post-1',
            'is_public': true,
          },
          newRecord: <String, dynamic>{
            'id': 'old-post-1',
            'author_id': user1.id,
            'is_public': true,
            'moderation_status': 'approved',
            'likes_count': 42,
            'created_at': DateTime.now()
                .subtract(const Duration(days: 3))
                .toUtc()
                .toIso8601String(),
          },
        );
        expect(repo.pendingNewPostsCount, 0);

        // Even with empty oldRecord, an old created_at outside the grace window is ignored.
        repo.handleRealtimePostChange(
          eventType: PostgresChangeEvent.update,
          newRecord: <String, dynamic>{
            'id': 'old-post-2',
            'author_id': user1.id,
            'is_public': true,
            'moderation_status': 'approved',
            'created_at': DateTime.now()
                .subtract(const Duration(days: 2))
                .toUtc()
                .toIso8601String(),
          },
        );
        expect(repo.pendingNewPostsCount, 0);
      },
    );

    test(
      'deduplicates multiple arrivals, removes deleted pending posts, and ignores own local posts',
      () async {
        final repo = CommunityRepository();
        addTearDown(repo.dispose);
        final nowIso = DateTime.now().toUtc().toIso8601String();

        // Locally created post by current tab is never queued as pending.
        await repo.createPost(author: user2, body: 'My own fresh thesis');
        final ownPost = repo.forYouPosts.first;
        repo.handleRealtimePostChange(
          eventType: PostgresChangeEvent.insert,
          newRecord: <String, dynamic>{
            'id': ownPost.id,
            'author_id': user2.id,
            'is_public': true,
            'moderation_status': 'approved',
            'created_at': nowIso,
          },
        );
        expect(repo.pendingNewPostsCount, 0);

        // Two posts from User 1 arrive (with duplicate event).
        repo.handleRealtimePostChange(
          eventType: PostgresChangeEvent.insert,
          newRecord: <String, dynamic>{
            'id': 'post-a',
            'author_id': user1.id,
            'is_public': true,
            'moderation_status': 'approved',
            'created_at': nowIso,
          },
        );
        repo.handleRealtimePostChange(
          eventType: PostgresChangeEvent.insert,
          newRecord: <String, dynamic>{
            'id': 'post-a',
            'author_id': user1.id,
            'is_public': true,
            'moderation_status': 'approved',
            'created_at': nowIso,
          },
        );
        repo.handleRealtimePostChange(
          eventType: PostgresChangeEvent.insert,
          newRecord: <String, dynamic>{
            'id': 'post-b',
            'author_id': user1.id,
            'is_public': true,
            'moderation_status': 'approved',
            'created_at': nowIso,
          },
        );
        expect(repo.pendingNewPostsCount, 2);
        expect(repo.pendingNewPostIds, <String>['post-b', 'post-a']);

        // Deleting post-a removes it from pending.
        repo.handleRealtimePostChange(
          eventType: PostgresChangeEvent.delete,
          newRecord: const <String, dynamic>{},
          oldRecord: const <String, dynamic>{'id': 'post-a'},
        );
        expect(repo.pendingNewPostsCount, 1);
        expect(repo.pendingNewPostIds, <String>['post-b']);
      },
    );

    test(
      'periodic new-posts polling runs while visible, pauses when hidden, and resumes on return',
      () async {
        final repo = _TestFeedRepository(
          initialPosts: <CommunityPost>[
            makePost(
              id: 'existing-1',
              author: user1,
              body: 'Existing feed post',
              createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
            ),
          ],
        )
          ..enablePollingWithoutSupabase = true
          ..newPostsPollIntervalOverride = const Duration(milliseconds: 40);
        addTearDown(repo.dispose);

        repo.beginNewPostsPolling();
        await Future<void>.delayed(const Duration(milliseconds: 95));
        final countWhileVisible = repo.checkForNewPostsCalls;
        expect(countWhileVisible, greaterThanOrEqualTo(1));

        // Hide tab: polling pauses.
        AppVisibility.instance.setVisibleForTest(false);
        final countAtHide = repo.checkForNewPostsCalls;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(repo.checkForNewPostsCalls, countAtHide);

        // Return to tab: triggers an immediate check.
        AppVisibility.instance.setVisibleForTest(true);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(repo.checkForNewPostsCalls, greaterThan(countAtHide));

        // Stop watching: timer stops cleanly.
        repo.endNewPostsPolling();
        final countAfterStop = repo.checkForNewPostsCalls;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(repo.checkForNewPostsCalls, countAfterStop);
      },
    );
  });

  group('CommunityFeedView New Posts Pill UI & end-to-end flow', () {
    void setViewport(WidgetTester tester, double width) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    for (final double width in <double>[390, 820, 1280]) {
      testWidgets(
        'displays new posts pill cleanly below floating toggle bar at ${width.toInt()}px and fetches remaining posts without full refresh',
        (WidgetTester tester) async {
          setViewport(tester, width);

          final existingPost = makePost(
            id: 'post-existing',
            author: user1,
            body: 'Initial post already loaded for User 2',
            createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          );
          final uploadedByUser1 = makePost(
            id: 'post-new-1',
            author: user1,
            body: 'Fresh breakout uploaded by User 1',
            createdAt: DateTime.now(),
          );

          final repo = _TestFeedRepository(
            initialPosts: <CommunityPost>[existingPost],
          );
          addTearDown(repo.dispose);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: CommunityFeedView(
                  repository: repo,
                  currentUser: user2,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Initially no new posts -> pill hidden.
          expect(find.byType(CommunityNewPostsPill), findsNothing);
          expect(
            find.text('Initial post already loaded for User 2'),
            findsOneWidget,
          );
          expect(
            find.text('Fresh breakout uploaded by User 1'),
            findsNothing,
          );

          // User 1 uploads a post -> User 2 receives notification without full reload.
          repo.remotePendingPosts[uploadedByUser1.id] = uploadedByUser1;
          await repo.checkForNewPosts();
          await tester.pumpAndSettle();

          final pillFinder = find.byType(CommunityNewPostsPill);
          expect(pillFinder, findsOneWidget);
          expect(find.text('1 new post'), findsOneWidget);

          // Verify pill is strictly BELOW the floating toggle tab bar (never hidden behind it!).
          final Rect tabBarRect = tester.getRect(find.byType(TabBar));
          final Rect pillRect = tester.getRect(pillFinder);
          expect(
            pillRect.top,
            greaterThanOrEqualTo(tabBarRect.bottom),
            reason:
                'New posts pill must sit visibly below the floating toggle options bar',
          );
          // Minimum 44px touch target requirement.
          expect(pillRect.height, greaterThanOrEqualTo(44.0));

          // Verify feed has NOT been refreshed yet and new post is not auto-injected.
          expect(repo.fullRefreshCalls, 0);
          expect(
            find.text('Fresh breakout uploaded by User 1'),
            findsNothing,
          );

          // Tapping the pill shows loading state, fetches ONLY pending posts, and
          // prepends them without calling fetchFromSupabase().
          final gate = Completer<void>();
          repo.loadPendingGate = gate;

          await tester.tap(pillFinder);
          await tester.pump();
          expect(find.text('Loading new posts...'), findsOneWidget);

          gate.complete();
          await tester.pumpAndSettle();

          expect(repo.loadPendingCalls, 1);
          expect(repo.fullRefreshCalls, 0);
          expect(find.byType(CommunityNewPostsPill), findsNothing);
          expect(
            find.text('Fresh breakout uploaded by User 1'),
            findsOneWidget,
          );
          // Existing post remains in feed without whole-page reload.
          expect(
            find.text('Initial post already loaded for User 2'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'pill stays visible on top scroll, scales safely at 2.0x text scale, and retries on load failure',
      (WidgetTester tester) async {
        setViewport(tester, 360);

        final existingPost = makePost(
          id: 'post-existing-2',
          author: user1,
          body: 'Existing timeline item',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        );
        final uploadedByUser1 = makePost(
          id: 'post-new-retry',
          author: user1,
          body: 'Retryable new post from User 1',
          createdAt: DateTime.now(),
        );

        final repo = _TestFeedRepository(
          initialPosts: <CommunityPost>[existingPost],
        );
        addTearDown(repo.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: child!,
            ),
            home: Scaffold(
              body: CommunityFeedView(
                repository: repo,
                currentUser: user2,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        repo.remotePendingPosts[uploadedByUser1.id] = uploadedByUser1;
        await repo.checkForNewPosts();
        await tester.pumpAndSettle();

        expect(find.byType(CommunityNewPostsPill), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Nudging scroll near the top must NOT silently dismiss the pill.
        await tester.dragFrom(const Offset(180, 600), const Offset(0, -40));
        await tester.pumpAndSettle();
        expect(find.byType(CommunityNewPostsPill), findsOneWidget);

        // Switching to Market News hides the post pill; returning to For you shows it again.
        await tester.ensureVisible(find.text('Market News'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Market News'));
        await tester.pumpAndSettle();
        expect(find.byType(CommunityNewPostsPill), findsNothing);
        await tester.ensureVisible(find.text('For you'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('For you'));
        await tester.pumpAndSettle();
        expect(find.byType(CommunityNewPostsPill), findsOneWidget);

        // Simulate failure on first click: pill stays visible so User 2 can retry.
        repo.failLoadPending = true;
        await tester.tap(find.byType(CommunityNewPostsPill));
        await tester.pumpAndSettle();
        expect(find.byType(CommunityNewPostsPill), findsOneWidget);
        expect(repo.pendingNewPostsCount, 1);

        // Retry succeeds without full-page refresh.
        repo.failLoadPending = false;
        await tester.tap(find.byType(CommunityNewPostsPill));
        await tester.pumpAndSettle();
        expect(find.byType(CommunityNewPostsPill), findsNothing);
        expect(
          find.text('Retryable new post from User 1'),
          findsOneWidget,
        );
        expect(repo.fullRefreshCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
