import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart' hide CommunityPostCard;
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/views/community_explore_view.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
    theme: UiTheme.dark().toThemeData(),
    home: Scaffold(body: child),
  );

  testWidgets('Explore shows X-style tabs, trends and who to follow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = CommunityRepository();
    addTearDown(repo.dispose);
    var searchTaps = 0;
    String? topicTapped;
    CommunityAuthor? authorTapped;
    await tester.pumpWidget(
      app(
        CommunityExploreView(
          repository: repo,
          onSearchTap: () => searchTaps++,
          onAuthorTap: (a) => authorTapped = a,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    for (final label in ['For You', 'Trending', 'News']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('Trends for you'), findsOneWidget);
    expect(find.text('Who to follow'), findsOneWidget);
    expect(find.textContaining('1 · '), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('explore-search-bar')));
    expect(searchTaps, 1);

    if (repo.suggestedTraders.isNotEmpty) {
      await tester.tap(
        find.byKey(ValueKey('explore-author-${repo.suggestedTraders.first.id}')),
      );
      expect(authorTapped, isNotNull);
    }

    await tester.tap(find.text('Trending').first);
    await tester.pump();
    expect(find.text('Trending'), findsWidgets);
    expect(topicTapped, isNull);
  });

  testWidgets('category tab shows empty state when nothing matches', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = CommunityRepository();
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      app(CommunityExploreView(repository: repo, searchQuery: 'zzzqqq')),
    );
    await tester.pump();
    await tester.tap(find.text('Futures').first);
    await tester.pump();
    expect(find.byType(UiEmptyState), findsWidgets);
  });
}
