import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_composer_trigger_card.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_engagement_bar.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_post_card.dart';

void main() {
  group('Community mobile improvements and skeleton tests', () {
    testWidgets('CommunityComposerTriggerCard hides Post button on mobile', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844); // mobile
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommunityComposerTriggerCard(onTap: (_) {})),
        ),
      );
      await tester.pumpAndSettle();

      // On mobile, the "Post" button must be hidden
      expect(find.widgetWithText(UiButton, 'Post'), findsNothing);
      expect(find.text('Trade Setup'), findsOneWidget);
      expect(find.text('Market Thesis'), findsOneWidget);
    });

    testWidgets(
      'CommunityComposerTriggerCard displays Post button on desktop',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800); // desktop
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: CommunityComposerTriggerCard(onTap: (_) {})),
          ),
        );
        await tester.pumpAndSettle();

        // On desktop, the "Post" button must be present
        expect(find.widgetWithText(UiButton, 'Post'), findsOneWidget);
      },
    );

    testWidgets(
      'CommunityPostCardSkeleton renders stunning shimmer layout without errors',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    CommunityPostCardSkeleton(hasMedia: true),
                    CommunityPostCardSkeleton(hasMedia: false),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(CommunityPostCardSkeleton), findsNWidgets(2));
        expect(find.byType(UiSkeleton), findsWidgets);
      },
    );

    testWidgets(
      'CommunityEngagementBar long press triggers reaction overlay on mobile',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        String? selectedReaction;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: CommunityEngagementBar(
                    comments: 3,
                    likes: 5,
                    liked: false,
                    reposted: false,
                    onReact: (rx) => selectedReaction = rx,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the like button (first engagement button or button with thumb up icon)
        final likeButton = find.byIcon(Icons.thumb_up_alt_outlined);
        expect(likeButton, findsOneWidget);

        // Long press like button
        await tester.longPress(likeButton);
        await tester.pumpAndSettle();

        // Overlay emojis should now be visible: 👍, 🚀, 💡, 🔥, ❤️
        expect(find.text('🚀'), findsOneWidget);
        expect(find.text('🔥'), findsOneWidget);
        expect(find.text('❤️'), findsOneWidget);

        // Tap an emoji
        await tester.tap(find.text('🚀'));
        await tester.pumpAndSettle();

        expect(selectedReaction, '🚀');
      },
    );
  });
}
