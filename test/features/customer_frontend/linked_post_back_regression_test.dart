import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/navigation/customer_routes.dart';
import 'package:tradex/core/widgets/app_scaffold.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/presentation/community_root_screen.dart';
import 'package:tradex/features/community/presentation/views/community_post_detail_view.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/features/notes/ui/note_preview_screen.dart';

void main() {
  for (final systemBack in [false, true]) {
    testWidgets(
      'post → linked note → ${systemBack ? "system" : "button"} back restores post on mobile',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final source = CommunityRepository();
        final post = source.forYouPosts.first;
        var notes = await NotesRepositoryScope.repository.fetchAll();
        if (!notes.any((note) => note.isPublic)) {
          if (notes.isNotEmpty) {
            await NotesRepositoryScope.repository.update(
              notes.first.copyWith(isPublic: true),
            );
          } else {
            await NotesRepositoryScope.repository.create(
              AppNote(
                id: 'test_public_note_1',
                title: 'Test Public Note',
                content: 'Test content',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                isPublic: true,
              ),
            );
          }
          notes = await NotesRepositoryScope.repository.fetchAll();
        }
        final note = notes.firstWhere((note) => note.isPublic);
        final location = ValueNotifier<CustomerRoute>(
          CustomerRoute.parse(Uri(path: '/community/post/${post.id}')),
        );
        addTearDown(location.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: ValueListenableBuilder<CustomerRoute>(
              valueListenable: location,
              builder: (context, route, _) => AppScaffold(
                initialDestination: route.destination!,
                initialOpenRequest: route.request,
                onDestinationChanged: (id) =>
                    location.value = CustomerRoute.parse(Uri(path: '/$id')),
                onOpenRecord: (ref) => location.value = CustomerRoute.parse(
                  CustomerRoute.forRecord(ref),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final community = tester.widget<CommunityRootScreen>(
          find.byType(CommunityRootScreen),
        );
        community.onOpenRef!(
          AppLinkRef(
            kind: AppLinkKind.note,
            id: note.id,
            title: note.title,
            isPublicContext: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(NotePreviewScreen), findsOneWidget);
        expect(location.value.request?.id, note.id);
        final backButtons = find.byWidgetPredicate(
          (w) =>
              w is UiIconButton &&
              (w.tooltip == 'Back' || w.tooltip == 'Back to notes'),
        );
        expect(
          backButtons,
          findsOneWidget,
          reason: 'Mobile must have one record back control',
        );
        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(backButtons);
        }
        await tester.pumpAndSettle();
        expect(find.byType(CommunityPostDetailView), findsOneWidget);
        expect(location.value.request?.id, post.id);
        expect(
          tester
              .widget<CommunityPostDetailView>(
                find.byType(CommunityPostDetailView),
              )
              .post
              .id,
          post.id,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        source.dispose();
      },
    );
  }
}
