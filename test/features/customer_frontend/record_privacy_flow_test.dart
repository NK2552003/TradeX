import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/core/config/record_access.dart';
import 'package:tradex/core/data/owned_record_writer.dart';
import 'package:tradex/features/community/data/community_post_writer.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/data/workspace_attachment_service.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/public_workspace_attachment.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/features/notes/ui/notes_screen.dart';
import 'package:tradex/features/notes/ui/note_preview_screen.dart';

class NotesFixture extends Fake implements NotesRepository {
  NotesFixture(this.note);
  AppNote note;
  final changes = StreamController<List<AppNote>>.broadcast();
  @override
  Stream<List<AppNote>> watchAll() async* {
    yield [note];
    yield* changes.stream;
  }

  @override
  Stream<List<AppNote>> watchPublic() =>
      watchAll().map((items) => items.where((note) => note.isPublic).toList());
  @override
  Future<List<AppNote>> fetchAll() async => [note];
  @override
  Future<AppNote?> getById(String id) async => id == note.id ? note : null;
  @override
  Future<AppNote> recordView(String id) async => note;
}

void main() {
  final private = AppNote(
    id: 'foreign-note',
    userId: 'another-user',
    title: 'Confidential plan',
    content: 'PRIVATE THESIS',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  test(
    'record access depends on ownership and visibility, never route flags',
    () {
      CustomerDataPolicy.allowDemo = false;
      addTearDown(() => CustomerDataPolicy.allowDemo = true);
      expect(RecordAccess.canRead('owner', false, actorId: 'owner'), isTrue);
      expect(RecordAccess.canRead('owner', false, actorId: 'viewer'), isFalse);
      expect(RecordAccess.canRead('owner', false, actorId: ''), isFalse);
      expect(
        RecordAccess.canRead(
          'owner',
          false,
          actorId: 'owner',
          publicContext: true,
        ),
        isFalse,
      );
      expect(RecordAccess.canRead('owner', true, actorId: 'viewer'), isTrue);
      expect(RecordAccess.owns('owner', actorId: 'viewer'), isFalse);
    },
  );
  for (final published in [false, true]) {
    testWidgets(
      'forged owner URL cannot edit another user note (public=$published)',
      (tester) async {
        final fixture = NotesFixture(private.copyWith(isPublic: published));
        NotesRepositoryScope.override(fixture);
        addTearDown(() async {
          NotesRepositoryScope.override(null);
          await fixture.changes.close();
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NotesScreen(
                openRequest: AppLinkOpenRequest(
                  kind: AppLinkKind.note,
                  id: private.id,
                  seq: 1,
                  publicContext: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (published) {
          expect(find.byType(NotePreviewScreen), findsOneWidget);
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is UiIconButton && widget.tooltip == 'Edit note',
            ),
            findsNothing,
          );
          final visibility = tester.widget<UiIconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is UiIconButton &&
                  (widget.tooltip?.startsWith('Public note') ?? false),
            ),
          );
          expect(visibility.onPressed, isNull);
        } else {
          expect(find.text('Note unavailable'), findsOneWidget);
          expect(find.text('PRIVATE THESIS'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'public attachment reveals no stale title or excerpt after revocation',
    (tester) async {
      final fixture = NotesFixture(private);
      NotesRepositoryScope.override(fixture);
      addTearDown(() async {
        NotesRepositoryScope.override(null);
        await fixture.changes.close();
      });
      final stale = AppWritingPostAttachment.note(
        private.copyWith(isPublic: true),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PublicWorkspaceAttachment(attachment: stale)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Attachment unavailable'), findsOneWidget);
      expect(find.text('Confidential plan'), findsNothing);
      expect(find.textContaining('PRIVATE THESIS'), findsNothing);
      expect(await WorkspaceAttachmentService().resolve(stale.source), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'an already visible attachment disappears when its source becomes private',
    (tester) async {
      final fixture = NotesFixture(private.copyWith(isPublic: true));
      NotesRepositoryScope.override(fixture);
      addTearDown(() async {
        NotesRepositoryScope.override(null);
        await fixture.changes.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PublicWorkspaceAttachment(
              attachment: AppWritingPostAttachment.note(fixture.note),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Confidential plan'), findsWidgets);
      fixture.note = fixture.note.copyWith(isPublic: false);
      fixture.changes.add([fixture.note]);
      await tester.pumpAndSettle();
      expect(find.text('Attachment unavailable'), findsOneWidget);
      expect(find.text('Confidential plan'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'owner-filtered writes require a confirmed row and reject zero-row results',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'code': 'PGRST116',
              'message': 'No row returned',
              'details': '0 rows',
              'hint': null,
            }),
            406,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await expectLater(
        OwnedRecordWriter(
          client: client,
          actorId: 'owner',
        ).update('trader_notes', 'note-id', {'is_public': true}),
        throwsA(isA<PostgrestException>()),
      );
      expect(requests.single.url.queryParameters['user_id'], 'eq.owner');
      expect(requests.single.url.queryParameters['id'], 'eq.note-id');
    },
  );
  test('failed attachment write never publishes the staged post', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('community_post_attachments')) {
          return http.Response(
            jsonEncode({
              'code': '42501',
              'message': 'denied',
              'details': '',
              'hint': null,
            }),
            403,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'id': 'post-id'}),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await expectLater(
      CommunityPostWriter(client, 'owner').create(
        CommunityPost(
          id: 'post-id',
          author: const CommunityAuthor(
            id: 'owner',
            handle: 'owner',
            displayName: 'Owner',
            userRole: UserRole.customer,
          ),
          body: 'Public post',
          createdAt: DateTime(2026),
          imageUrls: const ['https://example.com/chart.png'],
        ),
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect((jsonDecode(requests.first.body) as Map)['is_public'], isFalse);
    expect(requests.any((request) => request.method == 'PATCH'), isFalse);
    expect(requests.last.method, 'DELETE');
  });
  test(
    'quick-created attachments persist as private workspace records',
    () async {
      final service = WorkspaceAttachmentService();
      final created = await service.createNote(
        title: 'Persisted attachment',
        content: 'Reviewed source',
      );
      final saved = await NotesRepositoryScope.repository.getById(
        created.source.id,
      );
      expect(saved, isNotNull);
      expect(saved!.isPublic, isFalse);
      expect(await service.resolve(created.source), isNull);
      expect(
        await service.resolve(created.source, requireOwner: true),
        isNotNull,
      );
      await NotesRepositoryScope.repository.delete(saved.id);
    },
  );

  test('refreshing attachable records removes stale sources', () {
    final repo = CommunityRepository();
    repo.replaceAttachableRecords([AppWritingPostAttachment.note(private)]);
    expect(repo.attachableRecords, hasLength(1));
    repo.replaceAttachableRecords([]);
    expect(repo.attachableRecords, isEmpty);
    repo.dispose();
  });

  test('publishing occurs only after attachment writes succeed', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'id': 'post-id'}),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await CommunityPostWriter(client, 'owner').create(
      CommunityPost(
        id: 'post-id',
        author: const CommunityAuthor(
          id: 'owner',
          handle: 'owner',
          displayName: 'Owner',
          userRole: UserRole.customer,
        ),
        body: 'Reviewed post',
        createdAt: DateTime(2026),
        imageUrls: const ['https://example.com/chart.png'],
      ),
    );
    expect(requests.map((r) => r.method), ['POST', 'POST', 'PATCH']);
    expect((jsonDecode(requests.first.body) as Map)['is_public'], isFalse);
    expect((jsonDecode(requests.last.body) as Map)['is_public'], isTrue);
    expect(requests.last.url.queryParameters['author_id'], 'eq.owner');
  });

  test(
    'private posts disappear from public feeds but remain on the owner profile',
    () async {
      final repo = CommunityRepository();
      final post = repo.forYouPosts.firstWhere(
        (post) => post.author.id == repo.currentAuthor.id,
      );
      await repo.setPostVisibility(post.id, false);
      expect(repo.forYouPosts.any((item) => item.id == post.id), isFalse);
      expect(
        repo
            .postsForAuthor(repo.currentAuthor.id)
            .any((item) => item.id == post.id),
        isTrue,
      );
      await repo.setPostVisibility(post.id, true);
      repo.dispose();
    },
  );
}
