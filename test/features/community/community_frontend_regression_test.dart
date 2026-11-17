import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/views/community_search_page.dart';
import 'package:tradex/features/community/presentation/views/community_follow_view.dart';
import 'package:tradex/features/market_data/presentation/market_world_indices_card.dart';

class SearchRepository extends CommunityRepository {
  bool loading = false;
  int refreshes = 0;
  void publish() => notifyListeners();
  @override
  bool get isLoading => loading;
  @override
  Future<void> fetchFromSupabase() async {
    refreshes++;
    refreshError = null;
    loading = false;
    notifyListeners();
  }

  @override
  List<CommunityAuthor> searchUsers(String query) => [];
  @override
  List<CommunityPost> searchPosts(String query, {String? category}) => [
    CommunityPost(
      id: 'search-result',
      author: const CommunityAuthor(
        id: 'result-author',
        handle: 'a_very_long_trader_handle',
        displayName: 'A very long trader display name that should fit',
        userRole: UserRole.customer,
      ),
      body: 'Search result body',
      createdAt: DateTime(2026),
    ),
  ];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  void viewport(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('search author fits 320px at text scale $scale', (
      tester,
    ) async {
      final repo = SearchRepository();
      addTearDown(repo.dispose);
      viewport(tester, 320);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: CommunitySearchPage(repository: repo, initialQuery: 'audit'),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Search result body'), findsOneWidget);
    });
  }

  testWidgets('Traders category explains no matches when posts match', (
    tester,
  ) async {
    final repo = SearchRepository();
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CommunitySearchPage(repository: repo, initialQuery: 'audit'),
      ),
    );
    await tester.tap(find.text('Traders'));
    await tester.pump();
    expect(find.text('No matching traders'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search follow and unfollow update without typing again', (
    tester,
  ) async {
    final repo = CommunityRepository();
    addTearDown(repo.dispose);
    final author = repo.suggestedTraders.firstWhere((a) => !a.isFollowing);
    await tester.pumpWidget(
      MaterialApp(
        home: CommunitySearchPage(
          repository: repo,
          initialQuery: author.handle,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Follow ${author.displayHandle}'));
    await tester.pump();
    expect(repo.isFollowing(author.id), isTrue);
    expect(find.byTooltip('Following ${author.displayHandle}'), findsOneWidget);
    await tester.tap(find.byTooltip('Following ${author.displayHandle}'));
    await tester.pump();
    expect(repo.isFollowing(author.id), isFalse);
    expect(find.byTooltip('Follow ${author.displayHandle}'), findsOneWidget);
  });

  testWidgets('history contains submitted searches only and can be cleared', (
    tester,
  ) async {
    final repo = CommunityRepository();
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      MaterialApp(home: CommunitySearchPage(repository: repo)),
    );
    expect(find.text('Search your community'), findsOneWidget);
    expect(find.textContaining('1,200'), findsNothing);
    expect(find.text('Trending Topics Today'), findsNothing);
    final input = find.byType(TextField);
    await tester.enterText(input, 'N');
    await tester.enterText(input, 'NIFTY');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    tester.widget<UiInput>(find.byType(UiInput)).onClear!();
    await tester.pump();
    expect(find.widgetWithText(UiButton, 'NIFTY'), findsOneWidget);
    expect(find.widgetWithText(UiButton, 'N'), findsNothing);
    await tester.tap(find.text('Clear all'));
    await tester.pump();
    expect(find.text('Search your community'), findsOneWidget);
    expect(find.widgetWithText(UiButton, 'NIFTY'), findsNothing);
  });

  testWidgets('All and Posts use the supplied post navigation', (tester) async {
    final repo = SearchRepository();
    addTearDown(repo.dispose);
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: CommunitySearchPage(
          repository: repo,
          initialQuery: 'audit',
          onPostTap: (p) => opened.add(p.id),
        ),
      ),
    );
    await tester.tap(find.text('Search result body'));
    await tester.pump();
    expect(opened, ['search-result']);
    await tester.tap(find.text('Posts').first);
    await tester.pump();
    await tester.tap(find.text('Search result body'));
    await tester.pump();
    expect(opened, ['search-result', 'search-result']);
  });

  for (final tab in ['Following', 'Followers']) {
    testWidgets('$tab distinguishes a search miss from an empty network', (
      tester,
    ) async {
      final repo = CommunityRepository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityFollowView(
              repository: repo,
              searchQuery: 'no-match-xyz',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final label =
          '$tab (${tab == 'Following' ? repo.followingCount : repo.followersCount})';
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text('No matching traders'), findsOneWidget);
      expect(find.text('Not following anyone yet'), findsNothing);
      expect(find.text('No followers yet'), findsNothing);
    });
  }

  testWidgets('network shows loading then an actionable error and retries', (
    tester,
  ) async {
    final repo = SearchRepository()..loading = true;
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CommunityFollowView(repository: repo)),
      ),
    );
    await tester.pump();
    expect(find.byType(UiSkeleton), findsWidgets);
    repo.loading = false;
    repo.refreshError = 'Internal server details';
    repo.publish();
    await tester.pump();
    expect(find.text('Could not refresh your network'), findsOneWidget);
    expect(find.text('Internal server details'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repo.refreshes, 1);
    expect(find.text('Could not refresh your network'), findsNothing);
  });

  testWidgets('market shows all sections without inactive paging controls', (
    tester,
  ) async {
    viewport(tester, 1400);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: MarketWorldIndicesCard()),
        ),
      ),
    );
    expect(find.text('Americas'), findsOneWidget);
    expect(find.text('Europe'), findsOneWidget);
    expect(find.text('Asia'), findsOneWidget);
    expect(find.byTooltip('Previous'), findsNothing);
    expect(find.byTooltip('Next'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
