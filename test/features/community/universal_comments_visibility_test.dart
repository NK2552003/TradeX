import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/universal_comments_section.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';

void main() {
  const author = CommunityAuthor(
    id: 'user_1',
    handle: 'pro_trader',
    displayName: 'Pro Trader',
    userRole: UserRole.customer,
  );

  group('UniversalCommentsSection Visibility Tests', () {
    testWidgets('renders public thread indicators and Make Private button', (
      WidgetTester tester,
    ) async {
      bool? toggledTo;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: UniversalCommentsSection(
                targetId: 'note_123',
                targetType: 'note',
                comments: const <CommunityComment>[],
                currentUser: author,
                isPublic: true,
                canToggleVisibility: true,
                onToggleVisibility: (v) => toggledTo = v,
                onAddComment: (text, {parentCommentId, sentiment}) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display Public badge and Make Private button
      expect(find.text('Public'), findsOneWidget);
      expect(find.text('Make Private'), findsOneWidget);

      // Tapping Make Private should trigger onToggleVisibility with false
      await tester.tap(find.text('Make Private'));
      await tester.pumpAndSettle();

      expect(toggledTo, isFalse);
    });

    testWidgets(
      'renders private thread callout banner and Make Public button',
      (WidgetTester tester) async {
        bool? toggledTo;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: UniversalCommentsSection(
                  targetId: 'strategy_456',
                  targetType: 'strategy',
                  comments: const <CommunityComment>[],
                  currentUser: author,
                  isPublic: false,
                  canToggleVisibility: true,
                  onToggleVisibility: (v) => toggledTo = v,
                  onAddComment: (text, {parentCommentId, sentiment}) async {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should display Private badge and Private Discussion banner
        expect(find.text('Private'), findsOneWidget);
        expect(find.text('Private Playbook Discussion'), findsOneWidget);
        expect(find.text('Make Public'), findsWidgets);

        // Tapping Make Public should trigger onToggleVisibility with true
        await tester.tap(find.text('Make Public').first);
        await tester.pumpAndSettle();

        expect(toggledTo, isTrue);
      },
    );
  });

  group('Repository Visibility Tests', () {
    test('NotesRepository setVisibility updates note isPublic flag', () async {
      final repo = NotesRepositoryImpl.instance;
      final notes = await repo.fetchAll();
      expect(notes.isNotEmpty, isTrue);

      final initial = notes.first;
      final toggled = await repo.setVisibility(initial.id, !initial.isPublic);
      expect(toggled.isPublic, equals(!initial.isPublic));

      // Restore
      await repo.setVisibility(initial.id, initial.isPublic);
    });

    test(
      'NotesRepository addComment allows commenting on private note',
      () async {
        final repo = NotesRepositoryImpl.instance;
        final notes = await repo.fetchAll();
        final initial = notes.first;

        // Set to private
        await repo.setVisibility(initial.id, false);
        final updated = await repo.addComment(
          initial.id,
          'My private thesis thought',
        );
        expect(
          updated.comments.any((c) => c.body == 'My private thesis thought'),
          isTrue,
        );

        // Restore
        await repo.setVisibility(initial.id, initial.isPublic);
      },
    );

    test(
      'CommunityRepository setPostVisibility updates post isPublic flag',
      () async {
        final repo = CommunityRepository();
        expect(repo.forYouPosts.isNotEmpty, isTrue);

        final post = repo.forYouPosts.first;
        expect(post.isPublic, isTrue);

        final updated = await repo.setPostVisibility(post.id, false);
        expect(updated, isNotNull);
        expect(updated!.isPublic, isFalse);

        final restored = await repo.setPostVisibility(post.id, true);
        expect(restored!.isPublic, isTrue);
      },
    );
  });
}
