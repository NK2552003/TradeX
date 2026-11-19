import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart'
    show UiAvatar, UiAvatarGroup, UiButton;
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_engagement_bar.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_post_card.dart';

void main() {
  group('Community Multi-Reactions Display & Interaction Tests', () {
    test(
      'CommunityPost.displayReactions aggregates unique reactions with userReaction first',
      () {
        final post = CommunityPost(
          id: 'post_1',
          author: const CommunityAuthor(
            id: 'author_1',
            displayName: 'Trader Alex',
            handle: 'alex',
            userRole: UserRole.customer,
          ),
          body: 'Testing multi reactions',
          createdAt: DateTime.now(),
          likes: 2,
          liked: true,
          userReaction: '🚀',
          reactions: const <String>['👍', '🚀'],
        );

        final displayRx = post.displayReactions;
        expect(displayRx.length, 2);
        expect(displayRx[0], '🚀');
        expect(displayRx[1], '👍');
      },
    );

    testWidgets(
      'CommunityEngagementBar renders distinct outline icons for post reactions',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: CommunityEngagementBar(
                    comments: 0,
                    likes: 2,
                    liked: true,
                    userReaction: '🚀',
                    reactions: const <String>['🚀', '👍'],
                    reposted: false,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The summary uses outline icons while the picker uses emoji.
        expect(find.byIcon(Icons.rocket_launch_outlined), findsOneWidget);
        expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
      },
    );

    testWidgets(
      'keeps four actions and three reaction badges on a narrow phone',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: CommunityEngagementBar(
                  likes: 250,
                  comments: 29,
                  liked: false,
                  reposted: false,
                  reactions: ['👍', '❤️', '🚀', '🔥'],
                ),
              ),
            ),
          ),
        );
        final buttons = find.byType(CommunityEngagementButton);
        expect(buttons, findsNWidgets(4));
        expect(find.text('250'), findsOneWidget);
        expect(find.text('29'), findsOneWidget);
        expect(find.byIcon(Icons.local_fire_department_outlined), findsNothing);
        final first = tester.getCenter(buttons.first);
        for (var i = 0; i < 4; i++) {
          expect(tester.getCenter(buttons.at(i)).dy, closeTo(first.dy, 0.1));
          expect(
            tester.getSize(buttons.at(i)).shortestSide,
            greaterThanOrEqualTo(44),
          );
        }
        expect(
          tester.getCenter(find.byIcon(Icons.thumb_up_outlined)).dx,
          greaterThan(tester.getRect(buttons.last).right),
        );
        final group = find.byType(UiAvatarGroup);
        final bounds = tester.getRect(group);
        final badges = find.descendant(
          of: group,
          matching: find.byType(Positioned),
        );
        expect(badges, findsNWidgets(3));
        for (final badge in badges.evaluate()) {
          final circle = find.byWidget(badge.widget);
          final rect = tester.getRect(circle);
          final icon = find.descendant(of: circle, matching: find.byType(Icon));
          expect(tester.getCenter(icon).dx, closeTo(rect.center.dx, 0.01));
          expect(tester.getCenter(icon).dy, closeTo(rect.center.dy, 0.01));
          expect(rect.bottom, lessThanOrEqualTo(bounds.bottom + 0.01));
          expect(rect.right, lessThanOrEqualTo(bounds.right + 0.01));
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('uses legible outline badges on pale fills in both themes', (
      tester,
    ) async {
      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: CommunityEngagementBar(
                comments: 0,
                likes: 3,
                liked: false,
                reposted: false,
                reactions: ['🔥', '💡', '👍'],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final badges = tester.widgetList<UiAvatar>(find.byType(UiAvatar));
        expect(badges.map((badge) => (badge.child! as Icon).icon), [
          Icons.local_fire_department_outlined,
          Icons.lightbulb_outline_rounded,
          Icons.thumb_up_outlined,
        ]);
        for (final badge in badges) {
          final fill = badge.backgroundColor!.computeLuminance();
          final stroke = (badge.child! as Icon).color!.computeLuminance();
          expect(fill, greaterThan(0.65));
          expect((fill + 0.05) / (stroke + 0.05), greaterThanOrEqualTo(3));
        }
      }
    });

    testWidgets(
      'hovering Like opens the picker and lets the pointer select a reaction',
      (tester) async {
        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: CommunityEngagementBar(
                  likes: 0,
                  comments: 0,
                  liked: false,
                  reposted: false,
                  onReact: (emoji) => selected = emoji,
                ),
              ),
            ),
          ),
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer();
        addTearDown(mouse.removePointer);
        await mouse.moveTo(
          tester.getCenter(find.byIcon(Icons.thumb_up_alt_outlined)),
        );
        await tester.pumpAndSettle();
        final rocket = tester.getCenter(find.byTooltip('Bullish'));
        for (final emoji in ['👍', '🚀', '💡', '🔥', '❤️']) {
          final button = find.byWidgetPredicate(
            (widget) => widget is UiButton && widget.label == emoji,
          );
          final glyph = tester.getRect(find.text(emoji));
          final target = tester.getRect(button);
          expect(glyph.center.dx, closeTo(target.center.dx, 1));
          expect(glyph.center.dy, closeTo(target.center.dy, 1));
          expect(glyph.width, lessThan(target.width));
          expect(glyph.height, lessThan(target.height));
        }
        await mouse.moveTo(rocket);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byTooltip('Bullish'), findsOneWidget);
        expect(selected, isNull);
        await mouse.down(rocket);
        await mouse.up();
        await tester.pumpAndSettle();
        expect(selected, '🚀');
        expect(find.byTooltip('Bullish'), findsNothing);
      },
    );

    testWidgets('More options preserves bookmarks and opens post insights', (
      tester,
    ) async {
      final post = CommunityPost(
        id: 'menu-post',
        author: const CommunityAuthor(
          id: 'author',
          displayName: 'Priya',
          handle: 'priya',
          userRole: UserRole.customer,
        ),
        body: 'Test post',
        createdAt: DateTime(2026),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: CommunityPostCard(post: post)),
          ),
        ),
      );
      final more = find.byTooltip('More options');
      await tester.tap(more);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bookmark post'));
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.text('Remove bookmark'), findsOneWidget);
      final insights = find.text('View Post Insights');
      await tester.ensureVisible(insights);
      await tester.tap(insights);
      await tester.pumpAndSettle();
      expect(find.text('Post Analytics & Insights'), findsOneWidget);
    });

    testWidgets(
      'CommunityPostCard displays multi-reaction cluster and updates on interaction',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final post = CommunityPost(
          id: 'post_test_multi',
          author: const CommunityAuthor(
            id: 'author_2',
            displayName: 'Trader Priya',
            handle: 'priya',
            userRole: UserRole.customer,
          ),
          body: 'Post with multiple reactions',
          createdAt: DateTime.now(),
          likes: 1,
          liked: false,
          reactions: const <String>['👍'],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: CommunityPostCard(post: post)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially has 1 like with 👍
        expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
        expect(find.text('1'), findsOneWidget);

        // Long press like button to open reaction pill
        final thumbFinder = find.byIcon(Icons.thumb_up_alt_outlined);
        expect(thumbFinder, findsOneWidget);
        await tester.longPress(thumbFinder);
        await tester.pumpAndSettle();

        // Reaction pill appears with emojis
        final rocketPillFinder = find.text('🚀');
        expect(rocketPillFinder, findsOneWidget);

        // Tap rocket to react with 🚀
        await tester.tap(rocketPillFinder);
        await tester.pumpAndSettle();

        // Now both 🚀 and 👍 should be visible, and like count should be 2!
        expect(find.byIcon(Icons.rocket_launch_outlined), findsOneWidget);
        expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
      },
    );
  });
}
