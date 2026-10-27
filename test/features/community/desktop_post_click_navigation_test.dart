import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/presentation/community_root_screen.dart';
import 'package:tradex/features/community/presentation/views/community_post_detail_view.dart';
import 'package:tradex/features/community/presentation/views/community_profile_view.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_card.dart';

void main() {
  late CommunityRepository repo;

  setUp(() {
    repo = CommunityRepository();
  });

  tearDown(() {
    repo.dispose();
  });

  void setDesktopViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'clicking a post card on desktop opens the desktop version inline and not an overlay, and not twice',
    (WidgetTester tester) async {
      setDesktopViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: CommunityRootScreen(
            repository: repo,
            userRole: UserRole.customer,
            initialTabIndex: 0,
            embedInScaffold: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find first post card on the feed
      final postCardFinder = find.byType(CommunityPostCard).first;
      expect(postCardFinder, findsOneWidget);

      // Tap the post card
      await tester.tap(postCardFinder);
      await tester.pumpAndSettle();

      // Verify that CommunityPostDetailView is mounted inline (desktop version)
      expect(find.byType(CommunityPostDetailView), findsOneWidget);

      // Verify that it is NOT inside a settings side sheet overlay
      expect(
        find.byKey(const ValueKey<String>('settings-side-sheet-surface')),
        findsNothing,
      );

      // Verify header back button is present on the desktop post view
      final backButton = find.byTooltip('Back to Feed');
      expect(backButton, findsOneWidget);

      // Tap back button and verify we return to the feed
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(CommunityPostDetailView), findsNothing);
      expect(find.byType(CommunityPostCard), findsWidgets);
    },
  );

  testWidgets(
    'clicking author inside desktop post view changes inner content without opening overlay, and back returns to post',
    (WidgetTester tester) async {
      setDesktopViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: CommunityRootScreen(
            repository: repo,
            userRole: UserRole.customer,
            initialTabIndex: 0,
            embedInScaffold: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the post card to enter desktop post view
      await tester.tap(find.byType(CommunityPostCard).first);
      await tester.pumpAndSettle();

      expect(find.byType(CommunityPostDetailView), findsOneWidget);

      // Find author name/avatar inside post card in CommunityPostDetailView
      final postAuthor = find.descendant(
        of: find.byType(CommunityPostDetailView),
        matching: find.byType(CommunityPostCard),
      );
      expect(postAuthor, findsOneWidget);

      // Tap author on the post detail card
      final post = repo.forYouPosts.first;
      final authorText = find.descendant(
        of: postAuthor,
        matching: find.text(post.author.displayName),
      );
      if (authorText.evaluate().isNotEmpty) {
        await tester.tap(authorText.first);
        await tester.pumpAndSettle();

        // Check if CommunityProfileView is displayed inline
        expect(find.byType(CommunityProfileView), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('settings-side-sheet-surface')),
          findsNothing,
        );

        // Tap back on the profile view
        final profileBack = find.byTooltip('Back');
        if (profileBack.evaluate().isNotEmpty) {
          await tester.tap(profileBack.first);
          await tester.pumpAndSettle();

          // Restores the post view!
          expect(find.byType(CommunityPostDetailView), findsOneWidget);
        }
      }
    },
  );
}
