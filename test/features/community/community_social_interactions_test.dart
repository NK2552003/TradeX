import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/ai/unified_ai_service.dart';
import 'package:tradex/core/app-ui/app_ui.dart' hide CommunityPostCard;
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/data/community_writing_assistant.dart';
import 'package:tradex/features/community/models/community_activity.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_card.dart';
import 'package:tradex/features/community/presentation/widgets/community_composer_card.dart';
import 'package:tradex/features/community/presentation/widgets/community_discussion_comment.dart';
import 'package:tradex/features/community/presentation/widgets/community_emoji_picker.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_discussion.dart';
import 'package:tradex/features/community/presentation/widgets/community_reactions_dialog.dart';

const author = CommunityAuthor(
  id: 'author',
  handle: 'priya',
  displayName: 'Priya Sharma',
  userRole: UserRole.customer,
  bio: 'Price action trader · Indian equities',
);
const viewer = CommunityAuthor(
  id: 'viewer',
  handle: 'me',
  displayName: 'My account',
  userRole: UserRole.customer,
);
CommunityComment comment(
  String id, {
  String? parent,
  int likes = 0,
  int day = 1,
  List<CommunityComment> replies = const [],
}) => CommunityComment(
  id: id,
  postId: 'post',
  author: author,
  body: 'Comment $id',
  createdAt: DateTime(2026, 11, day),
  parentCommentId: parent,
  likes: likes,
  replies: replies,
);

class FakeAi extends UnifiedAiService {
  String response = '{}';
  Future<String>? pending;
  bool? fallback;
  String? prompt;
  @override
  Future<String> complete({
    required String prompt,
    String? systemPrompt,
    double temperature = .3,
    int maxTokens = 2048,
    bool allowLocalFallback = true,
  }) async {
    fallback = allowLocalFallback;
    this.prompt = prompt;
    return pending ?? response;
  }
}

Widget host(Widget child) => MaterialApp(
  theme: UiTheme.light().toThemeData(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['TRADEX_CAPTURE_UI'] == '1') {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader(
        'NotoSans',
      )..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('flat replies and optimistic nested replies become one stable tree', () {
    final reply = comment('reply', parent: 'root');
    final roots = buildCommunityCommentTree([
      reply,
      comment('root', replies: [reply]),
      comment('grandchild', parent: 'reply'),
    ]);
    expect(roots.map((c) => c.id), ['root']);
    expect(roots.single.replies.map((c) => c.id), ['reply']);
    expect(roots.single.replies.single.replies.single.id, 'grandchild');
    expect(
      buildCommunityCommentTree([
        comment('orphan', parent: 'missing'),
      ]).single.id,
      'orphan',
    );
    expect(
      buildCommunityCommentTree([
        comment('a', parent: 'b'),
        comment('b', parent: 'a'),
      ]),
      hasLength(1),
    );
  });

  test('AI extracts supplied prices and refuses invented levels', () async {
    final ai = FakeAi()
      ..response = jsonEncode({
        'body': 'NIFTY breakout plan',
        'tickers': ['nifty', 'NIFTY'],
        'setup': {'entry': '24,820', 'stopLoss': '24000', 'target': '-1'},
      });
    final result = await CommunityWritingAssistant(service: ai).suggest(
      action: CommunityWritingAction.setup,
      draft: 'NIFTY entry 24820',
      setup: {},
    );
    expect(result.setup, {'entry': '24820'});
    expect(result.tickers, ['NIFTY']);
    expect(ai.fallback, isFalse);
    expect(ai.prompt, contains('NIFTY entry 24820'));
  });

  test(
    'empty drafts and malformed AI output fail without a replacement draft',
    () async {
      final ai = FakeAi();
      final assistant = CommunityWritingAssistant(service: ai);
      await expectLater(
        assistant.suggest(
          action: CommunityWritingAction.polish,
          draft: ' ',
          setup: {},
        ),
        throwsStateError,
      );
      expect(ai.prompt, isNull);
      await expectLater(
        assistant.suggest(
          action: CommunityWritingAction.polish,
          draft: 'My thesis',
          setup: {},
        ),
        throwsFormatException,
      );
    },
  );

  for (final editsDuringRequest in [false, true]) {
    testWidgets('AI suggestion review preserves edits: $editsDuringRequest', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = CommunityRepository();
      addTearDown(repo.dispose);
      final completer = Completer<String>();
      final ai = FakeAi()..pending = completer.future;
      await tester.pumpWidget(
        host(
          CommunityComposerCard(
            author: viewer,
            repository: repo,
            writingAssistant: CommunityWritingAssistant(service: ai),
          ),
        ),
      );
      final editor = find.descendant(
        of: find.byType(UiTextarea).first,
        matching: find.byType(EditableText),
      );
      await tester.enterText(editor, 'Original draft');
      await tester.pump();
      await tester.ensureVisible(find.text('Polish Thesis'));
      await tester.tap(find.text('Polish Thesis'));
      await tester.pump();
      if (editsDuringRequest) {
        await tester.enterText(editor, 'My newer draft');
        await tester.pump();
      }
      completer.complete(
        jsonEncode({'body': 'Polished draft', 'tickers': [], 'setup': {}}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Review AI suggestion'), findsOneWidget);
      expect(
        tester.widget<EditableText>(editor).controller.text,
        editsDuringRequest ? 'My newer draft' : 'Original draft',
      );
      await tester.tap(find.text('Apply suggestion'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(editor).controller.text,
        editsDuringRequest ? 'My newer draft' : 'Polished draft',
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [390.0, 1440.0]) {
    testWidgets('comment action expands in feed without navigation at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = CommunityRepository()..currentAuthor = viewer;
      addTearDown(repo.dispose);
      repo.setCommentsForPost('post', [
        comment('root', replies: [comment('reply', parent: 'root')]),
      ]);
      var navigations = 0;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        host(
          RepaintBoundary(
            key: boundary,
            child: ColoredBox(
              color: UiTheme.light().colors.background,
              child: CommunityPostCard(
                post: CommunityPost(
                  id: 'post',
                  author: author,
                  body:
                      'Watching the breakout. Waiting for confirmation before entry.',
                  createdAt: DateTime(2026, 11, 14),
                  comments: 2,
                  likes: 2,
                  reactions: const ['👍', '💡'],
                ),
                repository: repo,
                currentUser: viewer,
                onTap: () => navigations++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reply').first);
      await tester.pumpAndSettle();
      expect(find.byType(CommunityPostDiscussion), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('compact-comment-composer')))
            .height,
        inInclusiveRange(36, 52),
      );
      expect(find.text('Comment root'), findsOneWidget);
      expect(find.text('Comment reply'), findsOneWidget);
      expect(navigations, 0);
      expect(tester.takeException(), isNull);
      if (Platform.environment['TRADEX_CAPTURE_UI'] == '1') {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 1.5);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/tradex-comments-${width.toInt()}.png',
          ).writeAsBytes(data!.buffer.asUint8List());
        });
      }
      await tester.tap(find.byTooltip('Reply').first);
      await tester.pumpAndSettle();
      expect(find.byType(CommunityPostDiscussion), findsNothing);
    });
  }

  testWidgets('sorting and see more change the visible comments', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        CommunityPostDiscussion(
          comments: [
            for (var i = 1; i <= 7; i++)
              comment('$i', day: i, likes: i == 1 ? 20 : 0),
          ],
          currentUser: viewer,
          onAddComment: (_, {parentCommentId, sentiment}) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Comment 1')).dy,
      lessThan(tester.getTopLeft(find.text('Comment 7')).dy),
    );
    expect(find.text('Comment 2'), findsNothing);
    await tester.ensureVisible(find.text('See 2 more comments'));
    await tester.tap(find.text('See 2 more comments'));
    await tester.pumpAndSettle();
    expect(find.text('Comment 2'), findsOneWidget);
    await tester.ensureVisible(find.text('Most relevant'));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .ancestor(
            of: find.text('Most relevant'),
            matching: find.byType(UiDropdownMenu),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Newest'));
    await tester.pumpAndSettle();
    expect(find.text('Comment 1'), findsNothing);
  });

  testWidgets(
    'failed comment preserves draft and successful reply uses correct parent',
    (tester) async {
      var fail = true;
      String? parent;
      await tester.pumpWidget(
        host(
          CommunityPostDiscussion(
            comments: [comment('root')],
            currentUser: viewer,
            onAddComment: (text, {parentCommentId, sentiment}) async {
              parent = parentCommentId;
              if (fail) throw StateError('offline');
            },
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText), 'Keep this draft');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Keep this draft'), findsOneWidget);
      expect(find.text('Comment not published'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('reply-editor-root')),
          matching: find.byType(EditableText),
        ),
        'A threaded reply',
      );
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('reply-editor-root')),
          matching: find.text('Reply'),
        ),
      );
      await tester.pumpAndSettle();
      expect(parent, 'root');
      expect(find.text('A threaded reply'), findsNothing);
    },
  );

  for (final width in [320.0, 390.0, 1200.0]) {
    testWidgets(
      'comment controls align and reactions form a horizontal palette at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = CommunityRepository()..currentAuthor = viewer;
        addTearDown(repo.dispose);
        final item = comment(
          'aligned',
          likes: 3,
        ).copyWith(reactions: ['👍', '🔥']);
        repo.setCommentsForPost('post', [item]);
        await tester.pumpWidget(
          host(
            CommunityDiscussionComment(
              comment: item,
              repository: repo,
              currentUserId: viewer.id,
              onReply: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final summary = find.byKey(const ValueKey('comment-reactions-aligned'));
        final like = find.byWidgetPredicate(
          (widget) => widget is UiButton && widget.label == 'Like',
        );
        expect(
          tester.getCenter(summary).dy,
          closeTo(tester.getCenter(like).dy, 1),
        );
        expect(tester.getRect(summary).right, closeTo(width, 1));
        final follow = find.byWidgetPredicate(
          (widget) => widget is UiButton && widget.label == 'Follow',
        );
        expect(tester.getRect(follow).right, closeTo(width, 1));
        await tester.tap(find.byType(CommunityEmojiPicker));
        await tester.pumpAndSettle();
        final emojis = ['👍', '🚀', '💡', '🔥', '❤️'];
        final centers = [
          for (final emoji in emojis) tester.getCenter(find.text(emoji)),
        ];
        for (final emoji in emojis) {
          final button = find.byWidgetPredicate(
            (widget) => widget is UiButton && widget.label == emoji,
          );
          final glyph = tester.getRect(find.text(emoji));
          final target = tester.getRect(button);
          expect(glyph.center.dx, closeTo(target.center.dx, 1));
          expect(glyph.center.dy, closeTo(target.center.dy, 1));
          expect(glyph.left, greaterThanOrEqualTo(target.left));
          expect(glyph.right, lessThanOrEqualTo(target.right));
          expect(glyph.top, greaterThanOrEqualTo(target.top));
          expect(glyph.bottom, lessThanOrEqualTo(target.bottom));
        }
        for (var i = 1; i < centers.length; i++) {
          expect(centers[i].dy, closeTo(centers.first.dy, 1));
          expect(centers[i].dx, greaterThan(centers[i - 1].dx));
        }
        await tester.tap(find.text('🚀'));
        await tester.pumpAndSettle();
        expect(repo.commentsForPost('post').single.userReaction, '🚀');
        expect(find.text('🚀'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('reaction dialog filters people and follows from the overlay', (
    tester,
  ) async {
    final repo = ReactionRepository()..currentAuthor = viewer;
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => UiButton(
            label: 'Open reactions',
            onPressed: () => CommunityReactionsDialog.show(
              context,
              repository: repo,
              targetId: 'post',
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open reactions'));
    await tester.pumpAndSettle();
    expect(find.text('All 2'), findsOneWidget);
    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.text('Other trader'), findsOneWidget);
    await tester.tap(find.text('❤️ 1'));
    await tester.pumpAndSettle();
    expect(find.text('Priya Sharma'), findsNothing);
    expect(find.text('Other trader'), findsOneWidget);
    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();
    expect(repo.isFollowing('other'), isTrue);
    expect(find.text('Following'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Reactions'), findsNothing);
  });
}

class ReactionRepository extends CommunityRepository {
  @override
  Future<List<CommunityReaction>> fetchReactions(
    String targetId, {
    bool comment = false,
  }) async => [
    const CommunityReaction(author: author, reaction: '👍'),
    const CommunityReaction(
      author: CommunityAuthor(
        id: 'other',
        handle: 'other',
        displayName: 'Other trader',
        userRole: UserRole.customer,
      ),
      reaction: '❤️',
    ),
  ];
}
