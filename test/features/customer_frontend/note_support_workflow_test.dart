import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/markdown_kit/markdown_editor_field.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/features/notes/ui/note_editor_screen.dart';
import 'package:tradex/features/settings/presentation/pages/shared/help_about_page.dart';

class CapturingNotes extends Fake implements NotesRepository {
  AppNote? saved;
  @override
  Stream<List<AppNote>> watchAll() => Stream.value([]);
  @override
  Future<AppNote> create(AppNote draft) async {
    saved = draft.copyWith(id: 'saved-note').withDerivedCounts();
    return saved!;
  }
}

void main() {
  testWidgets(
    'saving immediately after a large paste keeps the latest complete content',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = CapturingNotes();
      NotesRepositoryScope.override(repository);
      addTearDown(() => NotesRepositoryScope.override(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteEditorScreen(
              note: AppNote(
                id: '',
                title: 'Pasted research',
                content: '',
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
              onClose: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      final latest = List.filled(1500, 'Review risk before entry.').join('\n');
      tester
              .widget<RichMarkdownEditorField>(
                find.byType(RichMarkdownEditorField),
              )
              .controller
              .text =
          latest;
      await tester.pump();
      await tester.tap(find.widgetWithText(UiButton, 'Save'));
      await tester.pump();
      expect(repository.saved, isNotNull);
      expect(repository.saved!.content, latest);
      expect(repository.saved!.wordCount, 6000);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'support failure preserves fields and success waits for the delivery callback',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var reject = true;
      var attempts = 0;
      final accepted = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HelpAboutPage(
              submitTicket: (category, subject, message) async {
                attempts++;
                if (reject) throw StateError('Service unavailable');
                await accepted.future;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'A real support subject');
      await tester.enterText(fields.at(1), 'Keep this message until accepted');
      await tester.ensureVisible(find.text('Send Support Ticket'));
      await tester.tap(find.text('Send Support Ticket'));
      await tester.pumpAndSettle();
      expect(attempts, 1);
      expect(
        tester.widget<TextField>(fields.at(0)).controller!.text,
        'A real support subject',
      );
      expect(
        tester.widget<TextField>(fields.at(1)).controller!.text,
        'Keep this message until accepted',
      );
      reject = false;
      await tester.tap(find.text('Send Support Ticket'));
      await tester.pump();
      expect(attempts, 2);
      expect(
        tester.widget<TextField>(fields.at(1)).controller!.text,
        'Keep this message until accepted',
      );
      accepted.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(fields.at(0)).controller!.text, isEmpty);
      expect(tester.widget<TextField>(fields.at(1)).controller!.text, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
