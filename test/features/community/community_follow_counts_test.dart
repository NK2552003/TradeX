import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/presentation/views/community_follow_view.dart';
import 'package:tradex/features/community/presentation/widgets/community_trader_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CommunityRepository repo;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = CommunityRepository();
  });
  tearDown(() => repo.dispose());

  test('authoritative zero counts replace stale profile totals', () {
    final counts = CommunityRepository.resolveAuthorFollowCounts(
      authorId: 'author',
      dbFollowers: 100,
      dbFollowing: 80,
      graphFollowersByAuthor: {'author': 0},
      graphFollowingByAuthor: {'author': 0},
      hasFullFollowCounts: true,
    );
    expect(counts, (followers: 0, following: 0));
  });

  test('partial graph preserves stored totals', () {
    final counts = CommunityRepository.resolveAuthorFollowCounts(
      authorId: 'author',
      dbFollowers: 100,
      dbFollowing: 80,
      graphFollowersByAuthor: {'author': 1},
      graphFollowingByAuthor: {},
      hasFullFollowCounts: false,
    );
    expect(counts, (followers: 100, following: 80));
  });

  test(
    'profile sync and follow toggles update cards and post authors',
    () async {
      final post = repo.forYouPosts.firstWhere(
        (p) => p.author.id != repo.currentAuthor.id,
      );
      final id = post.author.id;
      repo.syncAuthorFollowStats(
        id,
        followers: 20,
        following: 3,
        isFollowing: false,
      );
      final myFollowing = repo.followingCount;
      expect(repo.findPost(post.id)!.author.followers, 20);
      expect(await repo.toggleFollow(id), isTrue);
      expect(repo.authorById(id)!.followers, 21);
      expect(repo.findPost(post.id)!.author.followers, 21);
      expect(repo.findPost(post.id)!.author.isFollowing, isTrue);
      expect(repo.followingCount, myFollowing + 1);
      expect(repo.currentAuthor.following, myFollowing + 1);
      expect(await repo.toggleFollow(id), isTrue);
      expect(repo.findPost(post.id)!.author.followers, 20);
      expect(repo.findPost(post.id)!.author.isFollowing, isFalse);
      expect(repo.followingCount, myFollowing);
    },
  );

  for (final width in [320.0, 390.0, 700.0, 1400.0]) {
    testWidgets('network tabs and counts fit $width px', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommunityFollowView(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UiTabs), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.text('Following (${repo.followingCount})').first,
      );
      await tester.tap(find.text('Following (${repo.followingCount})').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.widget<UiTabs>(find.byType(UiTabs).first).index, 1);
    });
  }

  testWidgets('mobile trader row displays follower and following totals', (
    tester,
  ) async {
    final trader = repo.suggestedTraders.first.copyWith(
      followers: 23,
      following: 7,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CommunityTraderRow(trader: trader)),
      ),
    );
    expect(find.text('23 Followers · 7 Following'), findsOneWidget);
  });
}
