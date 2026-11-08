import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart' show AppLinkKind, AppLinkRef;
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/community_root_screen.dart';
import 'package:tradex/features/community/presentation/views/community_post_detail_view.dart';
import 'package:tradex/features/community/presentation/views/community_profile_view.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_card.dart';

class _Repository extends CommunityRepository {
  final pending = Completer<CommunityPost?>();
  int expansions = 0;
  @override
  CommunityPost? loadPostById(String id) =>
      id == 'pending' ? null : super.loadPostById(id);
  @override
  Future<CommunityPost?> fetchPostById(String id) =>
      id == 'pending' ? pending.future : super.fetchPostById(id);
  @override
  void recordDetailExpand(String id) {
    expansions++;
    super.recordDetailExpand(id);
  }
}

void main() {
  void desktop(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'rapid taps and echoed links open exactly one panel and one detail',
    (tester) async {
      desktop(tester);
      final repo = _Repository();
      addTearDown(repo.dispose);
      AppLinkOpenRequest? request;
      var sequence = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, update) => CommunityRootScreen(
              repository: repo,
              openRequest: request,
              onOpenRecord: (ref) => update(
                () => request = AppLinkOpenRequest(
                  kind: ref.kind,
                  id: ref.id,
                  seq: ++sequence,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = tester.widget<CommunityPostCard>(
        find.byType(CommunityPostCard).first,
      );
      for (var i = 0; i < 5; i++) {
        card.onTap!();
      }
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-side-sheet-surface')),
        findsOneWidget,
      );
      expect(find.byType(CommunityPostDetailView), findsOneWidget);
      expect(repo.expansions, 1);
      final detail = tester.widget<CommunityPostDetailView>(
        find.byType(CommunityPostDetailView),
      );
      final next = repo.forYouPosts.firstWhere((p) => p.id != detail.post.id);
      detail.onPostTap!(next);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-side-sheet-surface')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<CommunityPostDetailView>(
              find.byType(CommunityPostDetailView),
            )
            .post
            .id,
        next.id,
      );
      expect(repo.expansions, 2);
      await tester.tap(find.byTooltip('Close panel'));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityPostDetailView), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a late post fetch cannot replace the card the user just opened',
    (tester) async {
      desktop(tester);
      final repo = _Repository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityRootScreen(
            repository: repo,
            openRequest: const AppLinkOpenRequest(
              kind: AppLinkKind.communityPost,
              id: 'pending',
              seq: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = tester.widget<CommunityPostCard>(
        find.byType(CommunityPostCard).first,
      );
      await tester.tap(find.byType(CommunityPostCard).first);
      await tester.pumpAndSettle();
      repo.pending.complete(
        repo.forYouPosts.firstWhere((p) => p.id != card.post.id),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CommunityPostDetailView>(
              find.byType(CommunityPostDetailView),
            )
            .post
            .id,
        card.post.id,
      );
      expect(
        find.byKey(const ValueKey('settings-side-sheet-surface')),
        findsOneWidget,
      );
      expect(repo.expansions, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'profile post selection reveals the existing panel and ticker navigation dismisses it',
    (tester) async {
      desktop(tester);
      final repo = _Repository();
      addTearDown(repo.dispose);
      AppLinkRef? destination;
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityRootScreen(
            repository: repo,
            onOpenRef: (ref) => destination = ref,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CommunityPostCard).first);
      await tester.pumpAndSettle();
      final detail = tester.widget<CommunityPostDetailView>(
        find.byType(CommunityPostDetailView),
      );
      detail.onAuthorTap!(detail.post.author);
      await tester.pumpAndSettle();
      final profile = tester.widget<CommunityProfileView>(
        find.byType(CommunityProfileView),
      );
      profile.onPostTap!(detail.post);
      await tester.pumpAndSettle();
      expect(find.byType(CommunityProfileView), findsNothing);
      expect(
        find.byKey(const ValueKey('settings-side-sheet-surface')),
        findsOneWidget,
      );
      expect(repo.expansions, 1);
      detail.onTagTap!(r'$AAPL');
      await tester.pumpAndSettle();
      expect(destination?.id, 'AAPL');
      expect(
        find.byKey(const ValueKey('settings-side-sheet-surface')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('a routed mobile post survives its tab animation finishing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repository();
    addTearDown(repo.dispose);
    var index = 0;
    AppLinkOpenRequest? request;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(
              body: CommunityRootScreen(
                repository: repo,
                initialTabIndex: index,
                openRequest: request,
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final post = repo.forYouPosts.first;
    update(() {
      index = 4;
      request = AppLinkOpenRequest(
        kind: AppLinkKind.communityPost,
        id: post.id,
        seq: 1,
      );
    });
    await tester.pumpAndSettle();
    expect(find.byType(CommunityPostDetailView), findsOneWidget);
    expect(repo.expansions, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
