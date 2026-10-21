import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/core/widgets/app_scaffold.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/community_root_screen.dart';
import 'package:tradex/features/community/presentation/views/community_post_detail_view.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/messages/models/messages_models.dart';
import 'package:tradex/features/messages/presentation/widgets/message_bubble.dart';

void main() {
  group('Shared Entity Message Deep Linking Tests', () {
    test('MessagesRepository sends and stores sharedRef on messages', () {
      final repo = MessagesRepository();
      addTearDown(() => repo.dispose());

      const postRef = AppLinkRef(
        kind: AppLinkKind.communityPost,
        id: 'post_poll_1',
        title: 'Post by @marco_silva',
        subtitle: 'Breakout setup on BANKNIFTY',
      );

      final thread = repo.threads.first;
      repo.sendSharedRef(thread.id, postRef, note: 'Check this setup!');

      final messages = repo.messagesFor(thread.id);
      final lastMsg = messages.last;

      expect(lastMsg.body, 'Check this setup!');
      expect(lastMsg.sharedRef, isNotNull);
      expect(lastMsg.sharedRef!.kind, AppLinkKind.communityPost);
      expect(lastMsg.sharedRef!.id, 'post_poll_1');
    });

    testWidgets('MessageBubble renders AppLinkRefTile and triggers onOpenRef when tapped', (
      WidgetTester tester,
    ) async {
      AppLinkRef? openedRef;

      const postRef = AppLinkRef(
        kind: AppLinkKind.communityPost,
        id: 'post_nitish_1',
        title: 'Post by @nitish_trader',
        subtitle: 'Intraday ORB discussion',
      );

      final message = ChatMessage(
        id: 'msg_test_1',
        threadId: 'thread_1',
        body: 'Here is the setup',
        fromMe: false,
        sentAt: DateTime.now(),
        sharedRef: postRef,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              onOpenRef: (ref) {
                openedRef = ref;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppLinkRefTile), findsOneWidget);
      expect(find.text('Post by @nitish_trader'), findsOneWidget);

      await tester.tap(find.byType(AppLinkRefTile));
      await tester.pumpAndSettle();

      expect(openedRef, isNotNull);
      expect(openedRef!.kind, AppLinkKind.communityPost);
      expect(openedRef!.id, 'post_nitish_1');
    });

    testWidgets('CommunityRootScreen applies openRequest and opens exact post detail view', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final communityRepo = CommunityRepository();
      addTearDown(() => communityRepo.dispose());

      const openReq = AppLinkOpenRequest(
        kind: AppLinkKind.communityPost,
        id: 'post_poll_1',
        seq: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CommunityRootScreen(
            repository: communityRepo,
            openRequest: openReq,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should find CommunityPostDetailView mounted as active subpage
      expect(find.byType(CommunityPostDetailView), findsOneWidget);
    });
  });
}
