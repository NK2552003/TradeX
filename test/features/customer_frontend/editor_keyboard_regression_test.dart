import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/markdown_kit/markdown_editor_toolbar.dart';
import 'package:alphajournal/features/notes/ui/note_editor_screen.dart';
import 'package:alphajournal/features/notes/ui/note_preview_screen.dart';

void main() {
  final note = AppNote(
    id: 'keyboard-fixture',
    title: 'Keyboard test',
    content: '[Private link](alphajournal://journal/private-trade)',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    isPublic: true,
  );
  testWidgets('editor toolbar clears keyboard once', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteEditorScreen(note: note, onClose: (_) {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final toolbar = find.byType(MarkdownEditorToolbar);
    expect(toolbar, findsOneWidget);
    final bottom = tester.getBottomLeft(toolbar).dy;
    expect(bottom, lessThanOrEqualTo(600));
    expect(
      bottom,
      greaterThan(550),
      reason: 'Keyboard inset must not be applied twice',
    );
    expect(tester.takeException(), isNull);
  });
  for (final publicContext in [false, true]) {
    testWidgets('public note owner link context remains $publicContext', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppLinkRef? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotePreviewScreen(
              note: note,
              onClose: () {},
              onEdit: () {},
              isPublicContext: publicContext,
              onOpenLink: (ref) => opened = ref,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('Private link', findRichText: true));
      await tester.tap(find.text('Private link', findRichText: true));
      await tester.pump();
      expect(opened, isNotNull);
      expect(opened!.isPublicContext, publicContext);
    });
  }
}
