import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart' show UiAvatar;
import 'package:tradex/features/community/presentation/widgets/community_author_header.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/presentation/community_root_screen.dart';
import 'package:tradex/features/community/presentation/views/community_post_detail_view.dart';
import 'package:tradex/features/community/presentation/views/community_profile_view.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_card.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('post opens once at $width and closing returns to feed', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = CommunityRepository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityRootScreen(repository: repo, embedInScaffold: false),
        ),
      );
      await tester.pumpAndSettle();
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.tap(find.byType(CommunityPostCard).first);
        await tester.pumpAndSettle();
        expect(find.byType(CommunityPostDetailView), findsOneWidget);
        final panel = find.byKey(const ValueKey('settings-side-sheet-surface'));
        if (width >= 905) {
          expect(panel, findsOneWidget);
          final rect = tester.getRect(panel);
          expect(rect.center.dx, greaterThan(width / 2));
          expect(rect.right, lessThanOrEqualTo(width));
          await tester.tap(find.byTooltip('Close panel'));
        } else {
          expect(panel, findsNothing);
          await tester.tap(find.byTooltip('Back to Feed'));
        }
        await tester.pumpAndSettle();
        expect(find.byType(CommunityPostDetailView), findsNothing);
        expect(find.byType(CommunityPostCard), findsWidgets);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('desktop post author opens a panel and back restores the post', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = CommunityRepository();
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityRootScreen(repository: repo, embedInScaffold: false),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byType(CommunityPostCard).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final detail = find.byType(CommunityPostDetailView);
    final authorHeader = find
        .descendant(of: detail, matching: find.byType(CommunityAuthorHeader))
        .first;
    await tester.tap(
      find.descendant(of: authorHeader, matching: find.byType(UiAvatar)).first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CommunityProfileView), findsOneWidget);
    await tester.tap(find.byTooltip('Close panel').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CommunityPostDetailView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
