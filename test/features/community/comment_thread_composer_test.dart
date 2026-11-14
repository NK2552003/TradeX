import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_comment_composer.dart';
import 'package:tradex/features/community/presentation/widgets/community_discussion_comment.dart';
import 'package:tradex/features/community/presentation/widgets/universal_comments_section.dart';

const author = CommunityAuthor(
  id: 'author',
  handle: 'author',
  displayName: 'Post Author',
  userRole: UserRole.customer,
);
const viewer = CommunityAuthor(
  id: 'viewer',
  handle: 'viewer',
  displayName: 'Me',
  userRole: UserRole.customer,
);

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets(
    'space reaches the text editor without activating its surrounding card',
    (tester) async {
      var activations = 0;
      await tester.pumpWidget(
        host(
          UiInteractive(
            onTap: () => activations++,
            builder: (context, _) => CommunityCommentComposer(
              author: viewer,
              onSubmit: (_) async {},
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText), 'Hello');
      await tester.pump();
      final handled = await tester.sendKeyEvent(
        LogicalKeyboardKey.space,
        character: ' ',
      );
      expect(
        handled,
        isFalse,
        reason: 'The platform text editor must receive the space key.',
      );
      expect(activations, 0);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Hello world',
          selection: TextSelection.collapsed(offset: 11),
        ),
      );
      await tester.pump();
      expect(find.text('Hello world'), findsOneWidget);
    },
  );

  testWidgets('focused buttons still activate with Space and Enter', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var presses = 0;
    await tester.pumpWidget(
      host(
        UiButton(label: 'Action', focusNode: focus, onPressed: () => presses++),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(presses, 2);
  });

  for (final type in ['post', 'note', 'journal', 'strategy']) {
    testWidgets('$type keeps root drafts above indented reply editors', (
      tester,
    ) async {
      tester.view.physicalSize = Size(type == 'post' ? 390 : 1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final child = CommunityComment(
        id: 'child',
        postId: 'record',
        parentCommentId: 'root',
        author: author,
        body: 'Nested reply body',
        createdAt: DateTime(2026),
      );
      final root = CommunityComment(
        id: 'root',
        postId: 'record',
        author: author,
        body: 'Root comment body',
        createdAt: DateTime(2026),
        likes: 4,
        replies: [child],
      );
      final sibling = CommunityComment(
        id: 'sibling',
        postId: 'record',
        author: author,
        body: 'Other root body',
        createdAt: DateTime(2026),
      );
      String? sentParent;
      String? sentBody;
      await tester.pumpWidget(
        host(
          UniversalCommentsSection(
            targetId: 'record',
            targetType: type,
            comments: [root, sibling],
            currentUser: viewer,
            onAddComment: (text, {parentCommentId, sentiment}) async {
              sentParent = parentCommentId;
              sentBody = text;
            },
          ),
        ),
      );
      final rootEditor = find.byKey(const ValueKey('root-comment-editor'));
      final rootInput = find.descendant(
        of: rootEditor,
        matching: find.byType(EditableText),
      );
      await tester.enterText(rootInput, 'Keep my root draft');
      await tester.pump();
      final rootTile = find.byWidgetPredicate(
        (widget) =>
            widget is CommunityDiscussionComment && widget.comment.id == 'root',
      );
      final replyButton = find
          .descendant(
            of: rootTile,
            matching: find.byWidgetPredicate(
              (widget) => widget is UiButton && widget.label == 'Reply',
            ),
          )
          .first;
      await tester.ensureVisible(replyButton);
      await tester.tap(replyButton);
      await tester.pumpAndSettle();
      final inline = find.byKey(const ValueKey('reply-editor-root'));
      expect(inline, findsOneWidget);
      expect(
        tester.getTopLeft(inline).dx,
        greaterThan(tester.getTopLeft(rootEditor).dx),
      );
      expect(
        tester.getTopLeft(inline).dy,
        greaterThan(tester.getBottomLeft(find.text('Nested reply body')).dy),
      );
      expect(
        tester.getBottomLeft(inline).dy,
        lessThan(tester.getTopLeft(find.text('Other root body')).dy),
      );
      expect(
        tester.widget<EditableText>(rootInput).controller.text,
        'Keep my root draft',
      );
      await tester.tap(find.byTooltip('Cancel reply'));
      await tester.pumpAndSettle();
      final childTile = find.byWidgetPredicate(
        (widget) =>
            widget is CommunityDiscussionComment &&
            widget.comment.id == 'child',
      );
      final childReply = find
          .descendant(
            of: childTile,
            matching: find.byWidgetPredicate(
              (widget) => widget is UiButton && widget.label == 'Reply',
            ),
          )
          .first;
      await tester.ensureVisible(childReply);
      await tester.tap(childReply);
      await tester.pumpAndSettle();
      final nestedEditor = find.byKey(const ValueKey('reply-editor-child'));
      expect(
        tester.getTopLeft(nestedEditor).dx,
        greaterThan(tester.getTopLeft(childTile).dx),
      );
      final nestedInput = find.descendant(
        of: nestedEditor,
        matching: find.byType(EditableText),
      );
      await tester.enterText(nestedInput, 'Reply with spaces');
      await tester.pump();
      expect(
        await tester.sendKeyEvent(LogicalKeyboardKey.space, character: ' '),
        isFalse,
      );
      await tester.tap(
        find.descendant(of: nestedEditor, matching: find.text('Reply')),
      );
      await tester.pumpAndSettle();
      expect(sentParent, 'child');
      expect(sentBody, 'Reply with spaces');
      expect(find.byKey(const ValueKey('reply-editor-child')), findsNothing);
      expect(
        tester.widget<EditableText>(rootInput).controller.text,
        'Keep my root draft',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
